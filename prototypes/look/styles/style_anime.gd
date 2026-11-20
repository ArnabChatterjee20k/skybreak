extends LookStyle
## Style B: 3D anime arena. Cel fighters with a hard rim and ink, painted terrain and
## props, a set-dressed compact arena, filmic grade with bloom, a close cinematic
## camera of its own and a depth-aware impact frame. View only: the sim is untouched.

const TERRAIN_SHADER := preload("res://prototypes/look/shaders/terrain_painted.gdshader")
const PROP_SHADER := preload("res://prototypes/look/shaders/prop_painted.gdshader")
const POST_SHADER := preload("res://prototypes/look/shaders/look_post.gdshader")
const TOON_SHADER := preload("res://game/view/shaders/toon.gdshader")
const OUTLINE_SHADER := preload("res://game/view/shaders/outline.gdshader")
const GAME_PROP_SHADER := preload("res://game/world/shaders/prop_toon.gdshader")
const SMOKE_SHADER := preload("res://prototypes/look/shaders/smoke_card.gdshader")

## 0 = anime, 1 = painterly (style C reuses this rig).
var painterly := 0.0
var cam := Camera3D.new()
var post := ColorRect.new()
var post_material := ShaderMaterial.new()
var dressing := Node3D.new()
var rng := RandomNumberGenerator.new()
var fight_centre := Vector3.ZERO
var palette := {}
var _side := 1.0
var _cam_pos := Vector3.ZERO
var _look := Vector3.ZERO
var _snapped := false
var _impact := 0.0
## Camera framing: fighter height share of the screen and lens.
var fov := 50.0
var distance_scale := 1.0


func setup(zone_match: ZoneMatch) -> void:
	super.setup(zone_match)
	rng.seed = 99
	palette = zone_palette(zone_match.zone_id)
	var spawns := zone_match.spawn_positions()
	fight_centre = (spawns[0] + spawns[1]) * 0.5
	cam.fov = fov
	cam.far = 4000.0
	cam.near = 0.1
	zone_match.add_child(cam)
	cam.current = true
	zone_match.opponent_marker.camera = cam
	_build_post()
	_restyle_world()
	_restyle_fighters()
	zone_match.add_child(dressing)
	if zone_match.zone_id == &"ember_rift":
		_dress_ember()
	else:
		_dress_heartbloom()


## Palette and light per zone.
func zone_palette(zone: StringName) -> Dictionary:
	if zone == &"ember_rift":
		return {
			"ground_a": Color(0.46, 0.37, 0.36), "ground_b": Color(0.7, 0.52, 0.42), "ground_c": Color(0.36, 0.35, 0.44),
			"rock_a": Color(0.3, 0.25, 0.3), "rock_b": Color(0.62, 0.45, 0.4), "seam": 1.0,
			"shadow": Color(0.36, 0.38, 0.62), "sky_top": Color(0.1, 0.12, 0.3), "sky_horizon": Color(0.95, 0.55, 0.42),
			"fog": Color(0.58, 0.46, 0.55), "sun": Color(1.0, 0.86, 0.72), "sun_energy": 1.5, "sun_dir": Vector3(-0.45, -0.85, 0.5),
			"ambient": Color(0.46, 0.46, 0.62), "rim": Color(1.0, 0.6, 0.35), "fog_begin": 35.0, "fog_end": 560.0,
		}
	return {
		"ground_a": Color(0.36, 0.6, 0.3), "ground_b": Color(0.7, 0.8, 0.38), "ground_c": Color(0.24, 0.47, 0.42),
		"rock_a": Color(0.5, 0.46, 0.55), "rock_b": Color(0.8, 0.72, 0.7), "seam": 0.0,
		"shadow": Color(0.5, 0.48, 0.75), "sky_top": Color(0.26, 0.48, 0.92), "sky_horizon": Color(1.0, 0.84, 0.86),
		"fog": Color(0.95, 0.8, 0.88), "sun": Color(1.0, 0.92, 0.8), "sun_energy": 2.0, "sun_dir": Vector3(-0.5, -0.55, 0.65),
		"ambient": Color(0.62, 0.6, 0.78), "rim": Color(1.0, 0.75, 0.85), "fog_begin": 40.0, "fog_end": 700.0,
	}


func _build_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	match_node.add_child(layer)
	post_material.shader = POST_SHADER
	post.material = post_material
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(post)
	grade()


## Colour grade on the post pass; style C overrides.
func grade() -> void:
	post_material.set_shader_parameter("saturation", 1.04)
	post_material.set_shader_parameter("contrast", 1.06)
	post_material.set_shader_parameter("vignette", 0.35)
	post_material.set_shader_parameter("gain", Vector3(1.02, 1.0, 0.98))
	post_material.set_shader_parameter("impact_dark", Vector3(0.08, 0.02, 0.04))


func _restyle_world() -> void:
	var world := match_node.world
	var terrain: Node = world.get_node("Terrain")
	for m: ShaderMaterial in terrain.get("materials"):
		m.shader = TERRAIN_SHADER
		_palette_to(m)
		m.set_shader_parameter("seam_amount", palette.seam)
		m.set_shader_parameter("arena_centre", Vector2(fight_centre.x, fight_centre.z))
		m.set_shader_parameter("arena_radius", 34.0)
		m.set_shader_parameter("base_height", fight_centre.y - 6.0)
	var seen := {}
	for node in _all(world):
		for m in _materials_of(node):
			if seen.has(m):
				continue
			seen[m] = true
			if m is ShaderMaterial and (m as ShaderMaterial).shader == GAME_PROP_SHADER:
				var sm := m as ShaderMaterial
				sm.shader = PROP_SHADER
				sm.set_shader_parameter("painterly", painterly)
				var rim_now: Variant = sm.get_shader_parameter("rim_strength")
				sm.set_shader_parameter("rim_strength", minf(rim_now if rim_now is float else 0.15, 0.15))
				var tint: Variant = sm.get_shader_parameter("shadow_tint")
				if tint is Color and (tint as Color).is_equal_approx(Color(0.5, 0.52, 0.66)):
					sm.set_shader_parameter("ground_mode", 1.0)
					_palette_to(sm)
					sm.set_shader_parameter("arena_centre", Vector2(fight_centre.x, fight_centre.z))
					sm.set_shader_parameter("arena_radius", 30.0)
				if sm.next_pass is ShaderMaterial:
					(sm.next_pass as ShaderMaterial).set_shader_parameter("outline_width", 1.4 * (1.0 - painterly))
	_light_world()


func _palette_to(m: ShaderMaterial) -> void:
	for key in ["ground_a", "ground_b", "ground_c", "rock_a", "rock_b"]:
		m.set_shader_parameter(key, palette[key])
	m.set_shader_parameter("shadow_tint", palette.shadow)
	m.set_shader_parameter("painterly", painterly)


func _light_world() -> void:
	var world := match_node.world
	world.get_node("Atmosphere").set_process(false)
	var env: Environment = world.environment_node.environment
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	for level in 7:
		env.set_glow_level(level, 1.0 if level in [1, 2, 3, 4] else 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = palette.ambient
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = palette.fog
	env.fog_density = 1.0
	env.fog_depth_begin = palette.fog_begin
	env.fog_depth_end = palette.fog_end
	env.fog_depth_curve = 1.6
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.35
	env.fog_height = fight_centre.y - 4.0
	env.fog_height_density = 0.0
	var sky: ShaderMaterial = env.sky.sky_material
	sky.set_shader_parameter("top_color", palette.sky_top)
	sky.set_shader_parameter("horizon_color", palette.sky_horizon)
	sky.set_shader_parameter("fog_color", palette.fog)
	sky.set_shader_parameter("ground_color", palette.fog)
	var sun := world.sun
	sun.light_color = palette.sun
	sun.light_energy = palette.sun_energy
	var dir: Vector3 = (palette.sun_dir as Vector3).normalized()
	sun.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3.ZERO)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	var rim := world.rim_light
	rim.light_color = palette.rim
	rim.light_energy = 1.6
	rim.global_transform = Transform3D(Basis.looking_at(Vector3(-dir.x, -0.25, -dir.z).normalized(), Vector3.UP), Vector3.ZERO)


## Stronger rim and thicker ink on the fighters' toon materials.
func _restyle_fighters() -> void:
	var seen := {}
	for view in match_node.fighter_views:
		for node in _all(view):
			for m in _materials_of(node):
				if seen.has(m) or not m is ShaderMaterial:
					continue
				seen[m] = true
				var sm := m as ShaderMaterial
				if sm.shader == TOON_SHADER:
					_toon(sm)
				var next := sm.next_pass as ShaderMaterial
				if next and next.shader == OUTLINE_SHADER:
					_ink(next)


func _toon(sm: ShaderMaterial) -> void:
	sm.set_shader_parameter("rim_width", 0.42)
	sm.set_shader_parameter("rim_softness", 0.02)
	sm.set_shader_parameter("rim_strength", 1.1)
	sm.set_shader_parameter("rim_color", palette.rim.lightened(0.3))
	sm.set_shader_parameter("shadow_tint", Color(palette.shadow).lightened(0.25))
	sm.set_shader_parameter("band_count", 2)
	sm.set_shader_parameter("shadow_threshold", 0.2)
	sm.set_shader_parameter("band_softness", 0.015)


func _ink(next: ShaderMaterial) -> void:
	next.set_shader_parameter("outline_width", 3.2)
	next.set_shader_parameter("outline_color", Color(0.09, 0.04, 0.08))
	next.set_shader_parameter("outline_fade_distance", 40.0)


func _all(root_node: Node) -> Array[Node]:
	var out: Array[Node] = [root_node]
	var i := 0
	while i < out.size():
		out.append_array(out[i].get_children(true))
		i += 1
	return out


func _materials_of(node: Node) -> Array[Material]:
	var out: Array[Material] = []
	if node is GeometryInstance3D and (node as GeometryInstance3D).material_override:
		out.append((node as GeometryInstance3D).material_override)
	var mesh: Mesh = null
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mesh = mi.mesh
		for s in mi.get_surface_override_material_count():
			if mi.get_surface_override_material(s):
				out.append(mi.get_surface_override_material(s))
	elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh:
		mesh = (node as MultiMeshInstance3D).multimesh.mesh
	if mesh:
		for s in mesh.get_surface_count():
			if mesh.surface_get_material(s):
				out.append(mesh.surface_get_material(s))
	return out


# --- Set dressing: silhouettes close to the fight (view only, no collision). ---

func _ground_y(x: float, z: float) -> float:
	return match_node.world.ground_height_at(x, z, fight_centre.y + 60.0)


func painted(color: Color, params: Dictionary = {}, ink := true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PROP_SHADER
	m.set_shader_parameter("albedo_color", color)
	m.set_shader_parameter("shadow_tint", palette.shadow)
	m.set_shader_parameter("painterly", painterly)
	m.set_shader_parameter("sun_scale", 0.55)
	m.set_shader_parameter("rim_color", palette.rim)
	m.set_shader_parameter("rim_strength", 0.25)
	for p in params:
		m.set_shader_parameter(p, params[p])
	if ink and painterly < 0.5:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE_SHADER
		o.set_shader_parameter("outline_color", Color(0.12, 0.06, 0.1))
		o.set_shader_parameter("outline_width", 1.6)
		o.set_shader_parameter("outline_fade_distance", 50.0)
		o.set_shader_parameter("outline_min_width", 0.5)
		m.next_pass = o
	return m


func _multi(mesh: Mesh, material: Material, xforms: Array[Transform3D], colors: PackedColorArray = PackedColorArray()) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
	dressing.add_child(node)
	return node


## Ring position around the fight, keeping the lane between the spawns clear.
func _ring(r_min: float, r_max: float) -> Vector3:
	for attempt in 40:
		var a := rng.randf() * TAU
		var d := rng.randf_range(r_min, r_max)
		var x := fight_centre.x + cos(a) * d
		var z := fight_centre.z + sin(a) * d
		var y := _ground_y(x, z)
		if is_finite(y) and absf(y - fight_centre.y) < 40.0:
			return Vector3(x, y, z)
	return Vector3(INF, 0, 0)


func _xf(at: Vector3, scale: Vector3, yaw: float, tilt := Vector3.ZERO) -> Transform3D:
	var b := Basis.from_euler(Vector3(tilt.x, yaw, tilt.z)).scaled_local(scale)
	return Transform3D(b, at)


func _dress_ember() -> void:
	var basalt := painted(Color(0.24, 0.17, 0.2), {"strata": 0.5, "strata_spacing": 1.1, "rim_strength": 0.5})
	var boulder := painted(Color(0.4, 0.27, 0.24), {"rim_strength": 0.3})
	var hex := CylinderMesh.new()
	hex.radial_segments = 6
	hex.rings = 1
	hex.top_radius = 0.5
	hex.bottom_radius = 0.55
	hex.height = 1.0
	# Basalt column clusters: tall silhouettes framing the fight.
	var cols: Array[Transform3D] = []
	for cluster in 10:
		var at := _ring(22.0, 75.0)
		if not is_finite(at.x):
			continue
		var count := rng.randi_range(5, 12)
		var tall := rng.randf_range(3.0, 11.0)
		for k in count:
			var off := Vector3(rng.randf_range(-3.5, 3.5), 0, rng.randf_range(-3.5, 3.5))
			var p := at + off
			p.y = _ground_y(p.x, p.z)
			var h := tall * rng.randf_range(0.35, 1.0)
			var r := rng.randf_range(0.7, 1.3)
			cols.append(_xf(p + Vector3(0, h * 0.5 - 0.5, 0), Vector3(r * 2.0, h, r * 2.0), rng.randf() * TAU,
				Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08))))
	_multi(hex, basalt, cols)
	# Boulders and rubble.
	var rock := SphereMesh.new()
	rock.radial_segments = 7
	rock.rings = 4
	var rocks: Array[Transform3D] = []
	for i in 90:
		var at := _ring(9.0, 80.0)
		if not is_finite(at.x):
			continue
		var s := rng.randf_range(0.3, 1.0)
		s = s * s * 2.2 + 0.2
		rocks.append(_xf(at + Vector3(0, s * 0.15, 0), Vector3(s * rng.randf_range(1.0, 1.8), s * 0.8, s), rng.randf() * TAU,
			Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))))
	_multi(rock, boulder, rocks)
	# Lava pools with a glow.
	var pool := painted(Color(0.2, 0.06, 0.03), {"emission_color": Color(1.0, 0.42, 0.08), "emission_strength": 3.0}, false)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.1
	disc.radial_segments = 14
	var pools: Array[Transform3D] = []
	for i in 7:
		var at := _ring(20.0, 60.0)
		if not is_finite(at.x):
			continue
		var r := rng.randf_range(2.0, 5.0)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.45, 0.15)
		light.light_energy = 3.0
		light.omni_range = r * 3.5
		light.position = at + Vector3(0, 1.5, 0)
		dressing.add_child(light)
	_multi(disc, pool, pools)
	_smoke(Color(0.45, 0.3, 0.32, 0.55), 10, 90.0, 260.0, 30.0, 70.0)


func _dress_heartbloom() -> void:
	var bark := painted(Color(0.36, 0.24, 0.26), {"strata": 0.3, "strata_spacing": 0.8})
	var blossom := painted(Color(1.0, 0.72, 0.84), {"shadow_tint": Color(0.82, 0.46, 0.7), "rim_strength": 0.45,
		"rim_color": Color(1.0, 0.9, 0.95)})
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.35
	trunk.height = 1.0
	trunk.radial_segments = 7
	var ball := SphereMesh.new()
	ball.radial_segments = 10
	ball.rings = 6
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var crown_colors := PackedColorArray()
	for i in 22:
		var at := _ring(14.0, 55.0)
		if not is_finite(at.x):
			continue
		var h := rng.randf_range(4.0, 8.0)
		var lean := Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
		trunks.append(_xf(at + Vector3(0, h * 0.5, 0), Vector3(1.5, h, 1.5), rng.randf() * TAU, lean))
		var top := at + Vector3(lean.z * -h * 0.5, h, lean.x * h * 0.5)
		for k in rng.randi_range(5, 9):
			var s := rng.randf_range(1.6, 3.2)
			var o := Vector3(rng.randf_range(-2.6, 2.6), rng.randf_range(-0.8, 1.6), rng.randf_range(-2.6, 2.6))
			crowns.append(_xf(top + o, Vector3(s * 1.2, s * 0.85, s * 1.2), rng.randf() * TAU))
			crown_colors.append(Color(1.0, 0.9, 0.92).lerp(Color(1.0, 0.75, 0.86), rng.randf()))
	_multi(trunk, bark, trunks)
	_multi(ball, blossom, crowns, crown_colors)
	# Grass and flower tufts near the fight: small cones in clumps.
	var blade := SphereMesh.new()
	blade.radial_segments = 8
	blade.rings = 4
	var grass := painted(Color(1, 1, 1), {"shadow_tint": Color(0.4, 0.5, 0.62), "rim_strength": 0.0}, false)
	var tufts: Array[Transform3D] = []
	var tuft_colors := PackedColorArray()
	for i in 70:
		var at := _ring(6.0, 45.0)
		if not is_finite(at.x):
			continue
		for k in 4:
			var p := at + Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
			var w := rng.randf_range(0.5, 1.3)
			tufts.append(_xf(p, Vector3(w * 1.4, w * 0.8, w * 1.4), rng.randf() * TAU))
			tuft_colors.append(Color(0.25, 0.5, 0.25).lerp(Color(0.45, 0.66, 0.3), rng.randf()))
	_multi(blade, grass, tufts, tuft_colors)
	var flower := painted(Color(1, 1, 1), {"rim_strength": 0.1}, false)
	var bud := SphereMesh.new()
	bud.radial_segments = 6
	bud.rings = 3
	var buds: Array[Transform3D] = []
	var bud_colors := PackedColorArray()
	var flower_palette := [Color(1.0, 0.95, 0.7), Color(1.0, 0.6, 0.75), Color(0.85, 0.75, 1.0), Color(1.0, 1.0, 1.0)]
	for i in 500:
		var at := _ring(3.0, 38.0)
		if not is_finite(at.x):
			continue
		buds.append(_xf(at + Vector3(0, 0.3, 0), Vector3.ONE * rng.randf_range(0.12, 0.22), 0.0))
		bud_colors.append(flower_palette[rng.randi() % flower_palette.size()])
	_multi(bud, flower, buds, bud_colors)
	# Stone lantern posts and arches give mid-ground silhouettes.
	var stone := painted(Color(0.82, 0.76, 0.78), {"strata": 0.2, "strata_spacing": 0.6})
	var box := BoxMesh.new()
	var posts: Array[Transform3D] = []
	for i in 10:
		var at := _ring(12.0, 32.0)
		if not is_finite(at.x):
			continue
		var yaw := rng.randf() * TAU
		posts.append(_xf(at + Vector3(0, 1.1, 0), Vector3(0.5, 2.2, 0.5), yaw))
		posts.append(_xf(at + Vector3(0, 2.35, 0), Vector3(0.9, 0.3, 0.9), yaw))
	_multi(box, stone, posts)
	_smoke(Color(1.0, 0.94, 0.97, 0.55), 12, 80.0, 300.0, -40.0, 20.0)


## Soft billboard cloud / smoke cards in the mid and far distance for depth.
func _smoke(color: Color, count: int, r_min: float, r_max: float, y_min: float, y_max: float) -> void:
	var m := ShaderMaterial.new()
	m.shader = SMOKE_SHADER
	m.set_shader_parameter("tint", color)
	for i in count:
		var q := QuadMesh.new()
		var s := rng.randf_range(40.0, 90.0)
		q.size = Vector2(s * 1.6, s)
		var card := MeshInstance3D.new()
		card.mesh = q
		card.material_override = m
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := rng.randf() * TAU
		var d := rng.randf_range(r_min, r_max)
		card.position = fight_centre + Vector3(cos(a) * d, rng.randf_range(y_min, y_max), sin(a) * d)
		card.set_instance_shader_parameter("seed", rng.randf() * 100.0)
		dressing.add_child(card)


# --- Camera and per-frame overrides. ---

func on_hit(event: Dictionary) -> void:
	var sim := match_node.sim
	var where := MatchVfx.spark_point(event, sim.fighters)
	# The hit is drawn next frame; aim the frame at it.
	_impact = 1.0
	post_material.set_shader_parameter("impact_uv", cam.unproject_position(where) / Vector2(match_node.get_viewport().get_visible_rect().size))
	var gap := match_node.fighter_views[0].position.distance_to(match_node.fighter_views[1].position)
	var size := 2.2 / maxf(cam.global_position.distance_to(where) * tan(deg_to_rad(cam.fov * 0.5)) * 2.0, 0.1)
	post_material.set_shader_parameter("impact_keep", clampf(size * 0.55 + gap * 0.02, 0.08, 0.4))


func _process(delta: float) -> void:
	if match_node == null:
		return
	_frame_camera(delta)
	for view in match_node.fighter_views:
		view.fade_for_camera(cam.global_position)
	post_material.set_shader_parameter("impact", _impact)
	_impact = maxf(_impact - delta * 20.0, 0.0)


func _frame_camera(delta: float) -> void:
	var views := match_node.fighter_views
	var me := views[match_node.player].position
	var target := match_node.sim.fighters[match_node.player].lock_on_target
	var them := views[target if target >= 0 else 1].position
	var axis := Vector3(them.x - me.x, 0, them.z - me.z)
	if axis.length() < 0.5:
		axis = Vector3.FORWARD
	axis = axis.normalized()
	var side := Vector3.UP.cross(axis).normalized()
	var mid := me.lerp(them, 0.45)
	var spread := me.distance_to(them)
	if moment == "ffa":
		mid = centre()
		spread = 0.0
		for v in views:
			spread = maxf(spread, v.position.distance_to(mid) * 2.0)
	var dist := clampf(4.6 + spread * 0.8, 6.0, 34.0) * distance_scale
	var dir := (-axis * 0.55 + side * 0.83 * _side).normalized()
	var goal := mid + dir * dist + Vector3.UP * (0.6 + dist * 0.12)
	var look := mid + Vector3.UP * 0.35
	if wide:
		goal = mid + dir * 38.0 + Vector3.UP * 11.0
		look = mid + Vector3.UP * 2.0
	var floor_y := match_node.world.ground_height_at(goal.x, goal.z, goal.y + 50.0)
	if is_finite(floor_y):
		goal.y = maxf(goal.y, floor_y + 1.4)
	if not _snapped:
		_cam_pos = goal
		_look = look
		_snapped = true
	var k := 1.0 - exp(-delta * 3.5)
	_cam_pos = _cam_pos.lerp(goal, k)
	_look = _look.lerp(look, 1.0 - exp(-delta * 6.0))
	cam.fov = 56.0 if wide else fov
	cam.global_transform = Transform3D(Basis.looking_at(_look - _cam_pos, Vector3.UP), _cam_pos)
