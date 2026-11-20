extends SceneTree
## Look-dev renders of a voxel zone (docs/lookdev/heartbloom.md): hero shots at
## the zone's three times of day, voxel Kael for scale, a slow fly-through.
##   godot --path . --disable-vsync -s res://game/lookdev/zone_capture.gd -- <out dir> [draft|heroes|flythrough|all]
##       [--time=dusk|day|night] [--kael=res://game/characters/kael_voxel/kael_voxel.tscn]
## Renders at exactly 1920x1080 through a SubViewport; the fly-through writes
## numbered JPG frames at 60 fps. Prints GPU frame time per shot (the
## viewport's measured render time, which the presentation throttle doesn't
## touch).

const TIMES := {"day": 0, "dusk": 1, "night": 2}
## Look-dev sky and fog per time of day (proposed values for the zone data):
## pink stays the accent, so the sky runs lavender-blue to warm gold, the fog
## is neutral and light (distance only), and the cloud sea below is white.
const SKY_TOP := [Color("#86aee6"), Color("#7d83c2"), Color("#1c1a3e")]
const SKY_HORIZON := [Color("#f4e4c8"), Color("#f5c27e"), Color("#4a3d6e")]
const SKY_BELOW := [Color("#f5f3f2"), Color("#f2e9e4"), Color("#3a3552")]
const FOG := [Color("#e8ecf0"), Color("#ece2d8"), Color("#3c3858")]

var _out := ""
var _viewport: SubViewport
var _zone_node: HeartbloomVoxel
var _env: Environment
var _sun: DirectionalLight3D
var _rim: DirectionalLight3D
var _camera: Camera3D
var _kael: CharacterView
var _kael_body: Node3D
var _kael_f := FighterState.new()
var _petals: GPUParticles3D
var _time := "dusk"


func _initialize() -> void:
	var args := LookdevArgs.parse()
	_out = args.pos(0)
	var what := args.pos(1, "draft")
	_time = args.get_option("time", "dusk")
	DirAccess.make_dir_recursive_absolute(_out)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	RenderingServer.viewport_set_measure_render_time(_viewport.get_viewport_rid(), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	_run.call_deferred(what, args.get_option("kael", "res://game/characters/kael_voxel/kael_voxel.tscn"))


func _run(what: String, kael_scene: String) -> void:
	var t := Time.get_ticks_msec()
	_zone_node = HeartbloomVoxel.new()
	_viewport.add_child(_zone_node)
	_zone_node.build()
	print("zone built in %d ms: %s" % [Time.get_ticks_msec() - t, _zone_node.stats])
	_lights()
	_set_time(_time)
	_petal_river()
	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.near = 0.1
	_camera.far = 4000.0
	_viewport.add_child(_camera)
	_camera.make_current()
	_spawn_kael(kael_scene)
	for i in 30:
		await _step()
	if what in ["draft", "heroes", "all"]:
		await _heroes(what == "draft")
	if what in ["flythrough", "all"]:
		await _flythrough()
	quit()


# ---------------------------------------------------------------- environment

func _lights() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://game/world/voxel_zone/voxel_sky.gdshader")
	sky.sky_material = sky_mat
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_white = 6.0
	_env.ssao_enabled = true
	_env.ssao_radius = 1.2
	_env.ssao_intensity = 1.6
	_env.ssao_power = 1.4
	_env.ssao_light_affect = 0.1
	_env.ssil_enabled = false
	_env.glow_enabled = true
	_env.glow_intensity = 0.35
	_env.glow_hdr_threshold = 1.2
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	_env.fog_height_density = 0.0
	_env.adjustment_enabled = true
	_env.adjustment_contrast = 1.08
	var world := WorldEnvironment.new()
	world.environment = _env
	_viewport.add_child(world)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.light_angular_distance = 1.5
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.directional_shadow_max_distance = 260.0
	_sun.shadow_bias = 0.05
	_sun.shadow_normal_bias = 1.2
	_viewport.add_child(_sun)
	_rim = DirectionalLight3D.new()
	_viewport.add_child(_rim)


## The zone's preset (sun, ambient, sky, fog, rim) with the miniature stack's
## energies (the sheet's numbers are for the game's toon shader).
func _set_time(time: String) -> void:
	_time = time
	var zone := _zone_node.zone
	var k: int = TIMES[time]
	var dir: Vector3 = zone.sun_directions[k].normalized()
	_sun.look_at_from_position(Vector3.ZERO, dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	_sun.light_color = zone.sun_colors[k]
	_sun.light_energy = zone.sun_energies[k] * 3.0
	_rim.look_at_from_position(Vector3.ZERO, Vector3(-dir.x, -0.35, -dir.z), Vector3.UP)
	_rim.light_color = zone.rim_colors[k]
	_rim.light_energy = zone.rim_energies[k] * 1.2
	_env.ambient_light_color = zone.ambient_colors[k]
	_env.ambient_light_energy = [0.5, 0.42, 0.4][k]
	_env.fog_light_color = FOG[k]
	_env.fog_density = [0.0011, 0.0013, 0.0015][k]
	_env.fog_aerial_perspective = 0.35
	_env.fog_sun_scatter = 0.25
	_env.tonemap_exposure = zone.exposures[k]
	var sky_mat := _env.sky.sky_material as ShaderMaterial
	sky_mat.set_shader_parameter("top_color", SKY_TOP[k])
	sky_mat.set_shader_parameter("horizon_color", SKY_HORIZON[k])
	sky_mat.set_shader_parameter("below_color", SKY_BELOW[k])
	sky_mat.set_shader_parameter("sun_size", [0.0, 0.035, 0.0][k])
	sky_mat.set_shader_parameter("moon", k == 2)


## A slow river of voxel petals drifting from Blossom Crown over Heart Isle.
func _petal_river() -> void:
	_petals = GPUParticles3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.022, 0.022, 0.011) * 1.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#F7CCD8")
	mat.roughness = 0.8
	box.material = mat
	_petals.draw_pass_1 = box
	_petals.amount = 6000
	_petals.lifetime = 40.0
	_petals.preprocess = 40.0
	_petals.visibility_aabb = AABB(Vector3(-200, -60, -200), Vector3(400, 160, 400))
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(40, 12, 40)
	p.direction = Vector3(0.75, -0.12, 0.62)
	p.spread = 12.0
	p.initial_velocity_min = 2.2
	p.initial_velocity_max = 3.4
	p.gravity = Vector3(0, -0.12, 0)
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	p.turbulence_enabled = true
	p.turbulence_noise_strength = 1.5
	p.turbulence_noise_scale = 6.0
	p.particle_flag_rotate_y = true
	_petals.process_material = p
	_petals.position = Vector3(-80, 305, -70)
	_viewport.add_child(_petals)


# ---------------------------------------------------------------- Kael

func _spawn_kael(scene: String) -> void:
	_kael_body = Node3D.new()
	_viewport.add_child(_kael_body)
	_kael = (load(scene) as PackedScene).instantiate() as CharacterView
	_kael_body.add_child(_kael)
	_kael_f.enter_state(FighterState.State.IDLE)
	_place_kael(_zone_node.arch_base + Vector2(4.0, 9.0), PI * 1.15)


## Stands Kael on the voxel ground at (x, z), facing yaw.
func _place_kael(at: Vector2, yaw: float) -> void:
	var y := _zone_node.field.surface_at(at.x, at.y)
	# The visible top is the T1 terrace: round to the cell like the mesh does.
	y = roundf(y / HeartbloomVoxel.T1) * HeartbloomVoxel.T1
	_kael_body.position = Vector3(at.x, y + 1.0, at.y)
	_kael_body.rotation.y = yaw


func _step() -> void:
	_kael_f.state_ticks += 1
	_kael.apply_state(_kael_f, 1.0 / 60.0)
	await process_frame


# ---------------------------------------------------------------- shots

func _look(from: Vector3, at: Vector3, fov := 50.0) -> void:
	_camera.fov = fov
	_camera.global_position = from
	_camera.look_at(at, Vector3.UP)


func _shot(name: String) -> void:
	for i in 3:
		await _step()
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(_out.path_join(name + ".png"))
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(_viewport.get_viewport_rid())
	print("%s: gpu %.2f ms" % [name, gpu])


func _heroes(draft: bool) -> void:
	var a := _zone_node.arch_base
	var g := _zone_node.arch_ground
	var times := ["dusk"] if draft else ["dusk", "day", "night"]
	for time: String in times:
		_set_time(time)
		# The key image: the Heart Arch from the lawn, Kael at its foot.
		_place_kael(a + Vector2(4.0, 9.0), PI * 1.1)
		_look(Vector3(a.x + 22, g + 4.5, a.y + 52), Vector3(a.x - 2, g + 20, a.y), 50.0)
		await _shot("arch_%s" % time)
		# Wide overview of Heart Isle and the inner ring.
		_look(Vector3(110, 345, 150), Vector3(-10, 280, -10), 55.0)
		await _shot("overview_%s" % time)
		# Kael for scale against the lawn, blossoms and sky (gameplay-ish camera).
		_place_kael(a + Vector2(-10.0, 30.0), PI * 0.85)
		var k := _kael_body.position
		_look(k + Vector3(3.2, 1.4, 5.0), k + Vector3(0, 0.3, 0), 55.0)
		await _shot("kael_scale_%s" % time)
		# The Wishing Fountain with the bridge from Heart Isle, Kael at the rim.
		var fc: Vector3 = _zone_node.zone.get_meta("wishing_fountain").centre
		_place_kael(Vector2(fc.x + 5.0, fc.z + 5.2), PI * 0.25)
		_look(Vector3(fc.x + 26, fc.y + 9, fc.z + 24), Vector3(fc.x, fc.y + 3, fc.z), 50.0)
		await _shot("fountain_%s" % time)
		# Kael on the Heart Isle - Wishing Isle bridge.
		var hi := _zone_node.field.index_of("Heart Isle")
		var wi := _zone_node.field.index_of("Wishing Isle")
		var dir := (_zone_node.field.centres[wi] - _zone_node.field.centres[hi]).normalized()
		var s0 := _zone_node.field.top_point(hi, atan2(dir.y, dir.x), 0.92)
		var s1 := _zone_node.field.top_point(wi, atan2(dir.y, dir.x) + PI, 0.92)
		var mid := s0.lerp(s1, 0.35)
		var sag := s0.distance_to(s1) * 0.07 * 4.0 * 0.35 * 0.65
		_kael_body.position = mid + Vector3(0, 1.0 + 0.1 - sag, 0)
		_kael_body.rotation.y = atan2(-dir.x, -dir.y)
		var side := Vector3(-dir.y, 0, dir.x)
		_look(mid + side * 9.0 + Vector3(0, 2.5, 0) - Vector3(dir.x, 0, dir.y) * 6.0, mid + Vector3(0, 0.5, 0), 50.0)
		await _shot("bridge_%s" % time)
	_set_time("dusk")


## A slow 60 s fly-through (filled in after the drafts).
func _flythrough() -> void:
	pass
