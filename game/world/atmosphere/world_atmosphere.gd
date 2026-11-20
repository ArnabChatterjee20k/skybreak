class_name WorldAtmosphere
extends Node
## Blends fog, ambient, sky and sun between zone presets by camera position, for the
## current time of day, and drives the camera-attached weather.

enum TimeOfDay { DAY, DUSK, NIGHT }
## Fog end distance (m) for fog_density 0 and 1.
const FOG_END_CLEAR := 2600.0
const FOG_END_STORM := 1100.0
## Haze starts this far out: fighters stay crisp, the backdrop recedes behind them.
const HAZE_BEGIN := 150.0
const WEATHER_RAIN := 1
const WEATHER_SNOW := 2
const WEATHER_EMBERS := 3
const WEATHER_PETALS := 4
## Visual layers the rim light reaches (fighters); world geometry sits on WORLD_LAYERS.
const RIM_LAYERS := 1
const WORLD_LAYERS := 1 << 9

## Camera to follow; defaults to the viewport's current camera.
@export var camera: Camera3D
var time_of_day := TimeOfDay.DAY
var environment: Environment
var sun: DirectionalLight3D
## Back light that lifts the fighters off the backdrop; lights only RIM_LAYERS.
var rim: DirectionalLight3D
var sky_material: ShaderMaterial
var layout: ZoneLayout
var weather: Dictionary = {}  # weather type -> GPUParticles3D
## Materials with a `night` uniform (emissive windows, lava glow).
var night_materials: Array[ShaderMaterial] = []
## Last blended preset, for tests and debug.
var current: Dictionary = {}
## Map overview: blend the ground zones only, wherever the camera is.
var ground_only := false
## Zone index whose preset alone applies everywhere (a zone match), or -1 to blend by position.
var pinned_zone := -1
var _applied_weights := PackedFloat32Array()
var _applied_time := -1


func setup(zone_layout: ZoneLayout, env: Environment, light: DirectionalLight3D, sky_shader_material: ShaderMaterial,
		rim_light: DirectionalLight3D = null) -> void:
	layout = zone_layout
	environment = env
	sun = light
	rim = rim_light
	if rim:
		rim.light_cull_mask = RIM_LAYERS
		rim.shadow_enabled = false
		rim.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	sky_material = sky_shader_material
	_build_weather()


func set_time_of_day(id: int) -> void:
	time_of_day = clampi(id, 0, TimeOfDay.size() - 1) as TimeOfDay
	for material in night_materials:
		material.set_shader_parameter("night", 1.0 if time_of_day == TimeOfDay.NIGHT else (0.35 if time_of_day == TimeOfDay.DUSK else 0.0))
	if sky_material:
		sky_material.set_shader_parameter("star_amount", 1.0 if time_of_day == TimeOfDay.NIGHT else 0.0)


## Uses only this zone's fog, light, sky and weather, wherever the camera goes (T-D19).
## Other zones' weather emitters are switched off and hidden.
func pin_zone(index: int) -> void:
	pinned_zone = index
	_applied_weights = PackedFloat32Array()
	var own := layout.zones[index].weather if index >= 0 else -1
	for type in weather:
		var particles: GPUParticles3D = weather[type]
		particles.visible = index < 0 or type == own
		if not particles.visible:
			particles.emitting = false


## Zone weights at a point; one-hot on the pinned zone.
func weights_at(x: float, z: float, y: float = -INF) -> PackedFloat32Array:
	if pinned_zone < 0:
		return layout.weights_at(x, z, y)
	var w := PackedFloat32Array()
	w.resize(layout.zones.size())
	w[pinned_zone] = 1.0
	return w


## Preset blended at (x, z) and altitude `y` for the current time of day.
func blend_at(x: float, z: float, y: float = -INF) -> Dictionary:
	var w := weights_at(x, z, y)
	var t := int(time_of_day)
	var out := {
		"fog_color": Color(0, 0, 0, 0), "fog_end": 0.0, "sun_color": Color(0, 0, 0, 0),
		"sun_energy": 0.0, "sun_direction": Vector3.ZERO, "ambient": Color(0, 0, 0, 0),
		"sky_top": Color(0, 0, 0, 0), "sky_horizon": Color(0, 0, 0, 0), "weather": {},
		"exposure": 0.0, "rim_color": Color(0, 0, 0, 0), "rim_energy": 0.0, "rim_angles": Vector2.ZERO,
	}
	for i in w.size():
		if w[i] <= 0.0:
			continue
		var zone := layout.zones[i]
		out.fog_color += zone.fog_colors[t] * w[i]
		out.fog_end += lerpf(FOG_END_CLEAR, FOG_END_STORM, zone.fog_density) * w[i]
		out.sun_color += zone.sun_colors[t] * w[i]
		out.sun_energy += zone.sun_energies[t] * w[i]
		out.sun_direction += zone.sun_directions[t] * w[i]
		out.ambient += zone.ambient_colors[t] * w[i]
		out.sky_top += zone.sky_top_colors[t] * w[i]
		out.sky_horizon += zone.sky_horizon_colors[t] * w[i]
		out.exposure += zone.exposures[t] * w[i]
		out.rim_color += zone.rim_colors[t] * w[i]
		out.rim_energy += zone.rim_energies[t] * w[i]
		out.rim_angles += zone.rim_angles * w[i]
		if zone.weather != 0:
			out.weather[zone.weather] = out.weather.get(zone.weather, 0.0) + w[i]
	out.sun_direction = (out.sun_direction as Vector3).normalized()
	return out


## Applies the blend for a world position (the camera's, each frame).
func apply_at(position: Vector3) -> void:
	for particles: GPUParticles3D in weather.values():
		particles.global_position = position
	# Skip the writes when nothing changed (most frames, away from borders).
	var y := -INF if ground_only else position.y
	var weights := weights_at(position.x, position.z, y)
	if int(time_of_day) == _applied_time and _same(weights, _applied_weights):
		return
	_applied_weights = weights
	_applied_time = int(time_of_day)
	current = blend_at(position.x, position.z, y)
	if environment:
		environment.fog_light_color = current.fog_color
		environment.fog_depth_end = current.fog_end
		environment.fog_depth_begin = HAZE_BEGIN
		environment.ambient_light_color = current.ambient
		environment.tonemap_exposure = LookGrade.exposure(current.exposure)
	if rim:
		rim.light_color = current.rim_color
		rim.light_energy = current.rim_energy
	if sun:
		sun.light_color = current.sun_color
		sun.light_energy = current.sun_energy
		var dir: Vector3 = current.sun_direction
		sun.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD), Vector3.ZERO)
	if sky_material:
		sky_material.set_shader_parameter("top_color", current.sky_top)
		sky_material.set_shader_parameter("horizon_color", current.sky_horizon)
		sky_material.set_shader_parameter("ground_color", current.fog_color)
		sky_material.set_shader_parameter("fog_color", current.fog_color)
	for type in weather:
		var particles: GPUParticles3D = weather[type]
		var amount: float = current.weather.get(type, 0.0)
		particles.emitting = amount > 0.02 and particles.visible
		particles.amount_ratio = clampf(amount, 0.0, 1.0)


static func _same(a: PackedFloat32Array, b: PackedFloat32Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if absf(a[i] - b[i]) > 0.0005:
			return false
	return true


func _process(_delta: float) -> void:
	var cam := camera if camera else get_viewport().get_camera_3d()
	if cam and layout:
		apply_at(cam.global_position)
		aim_rim(cam.global_transform.basis)


## Points the rim light from behind what the camera looks at, back toward the camera.
func aim_rim(camera_basis: Basis) -> void:
	if rim == null or current.is_empty():
		return
	rim.global_transform = Transform3D(Basis.looking_at(rim_direction(camera_basis, current.rim_angles), Vector3.UP), Vector3.ZERO)


## Direction the rim light travels for a camera basis and (around, down) angles in degrees.
static func rim_direction(camera_basis: Basis, angles: Vector2) -> Vector3:
	var back := camera_basis.z
	back.y = 0.0
	back = back.normalized() if back.length_squared() > 0.0001 else Vector3.BACK
	var flat := back.rotated(Vector3.UP, deg_to_rad(angles.x))
	var down := deg_to_rad(clampf(angles.y, 5.0, 80.0))
	return (flat * cos(down) + Vector3.DOWN * sin(down)).normalized()


func _build_weather() -> void:
	weather[WEATHER_RAIN] = _particles("Rain", 900, Vector3(0, -38, 0), Vector2(0.035, 1.4),
		Color(0.7, 0.8, 1.0, 0.45), 1.0, BaseMaterial3D.BILLBOARD_FIXED_Y, 0.0)
	weather[WEATHER_SNOW] = _particles("Snow", 600, Vector3(2, -3.5, 1), Vector2(0.12, 0.12),
		Color(1, 1, 1, 0.9), 6.0, BaseMaterial3D.BILLBOARD_ENABLED, 0.6)
	weather[WEATHER_EMBERS] = _particles("Embers", 240, Vector3(0, 2.5, 0), Vector2(0.1, 0.1),
		Color(1.0, 0.5, 0.15, 1.0), 6.0, BaseMaterial3D.BILLBOARD_ENABLED, 0.8)
	weather[WEATHER_PETALS] = _particles("Petals", 280, Vector3(1.2, -1.4, 0.5), Vector2(0.26, 0.18),
		Color(1.0, 0.74, 0.84, 1.0), 10.0, BaseMaterial3D.BILLBOARD_PARTICLES, 1.0)


func _particles(node_name: String, count: int, velocity: Vector3, quad: Vector2, color: Color,
		lifetime: float, billboard: BaseMaterial3D.BillboardMode, turbulence: float) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(35, 22, 35)
	process.direction = velocity.normalized()
	process.spread = 8.0
	process.initial_velocity_min = velocity.length() * 0.8
	process.initial_velocity_max = velocity.length() * 1.2
	process.gravity = Vector3.ZERO
	if turbulence > 0.0:
		process.turbulence_enabled = true
		process.turbulence_noise_strength = turbulence
	var draw := StandardMaterial3D.new()
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.albedo_color = color
	draw.billboard_mode = billboard
	draw.billboard_keep_scale = true
	# Fade out particles right at the lens so they never cover the view.
	draw.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	draw.distance_fade_min_distance = 1.5
	draw.distance_fade_max_distance = 6.0
	if node_name == "Petals":
		# Tumbling petals: a soft pointed-oval texture, spun per particle.
		draw.albedo_texture = _petal_texture()
		draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		draw.alpha_scissor_threshold = 0.5
		process.angle_min = -180.0
		process.angle_max = 180.0
		process.angular_velocity_min = -90.0
		process.angular_velocity_max = 90.0
		process.color_initial_ramp = _petal_ramp()
		draw.vertex_color_use_as_albedo = true
	if node_name == "Embers":
		draw.emission_enabled = true
		draw.emission = color
		draw.emission_energy_multiplier = 3.0
	var mesh := QuadMesh.new()
	mesh.size = quad
	mesh.material = draw
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.amount = count
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.local_coords = false
	particles.process_material = process
	particles.draw_pass_1 = mesh
	particles.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false
	add_child(particles)
	return particles


static func _petal_texture() -> ImageTexture:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var p := Vector2((x - 7.5) / 7.5, (y - 7.5) / 7.5)
			var inside := p.x * p.x * 1.6 + absf(p.y) * 0.9 + p.y * p.y * 0.3 < 1.0
			image.set_pixel(x, y, Color(1, 1, 1, 1.0 if inside else 0.0))
	return ImageTexture.create_from_image(image)


# Petals vary from white to deep pink.
static func _petal_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1))
	gradient.set_color(1, Color(0.95, 0.6, 0.78))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture
