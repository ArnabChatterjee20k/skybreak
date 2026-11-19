class_name WorldAtmosphere
extends Node
## Blends fog, ambient, sky and sun between zone presets by camera position, for the
## current time of day, and drives the camera-attached weather.

enum TimeOfDay { DAY, DUSK, NIGHT }
## Fog end distance (m) for fog_density 0 and 1.
const FOG_END_CLEAR := 1200.0
const FOG_END_STORM := 450.0
const WEATHER_RAIN := 1
const WEATHER_SNOW := 2
const WEATHER_EMBERS := 3

## Camera to follow; defaults to the viewport's current camera.
@export var camera: Camera3D
var time_of_day := TimeOfDay.DAY
var environment: Environment
var sun: DirectionalLight3D
var sky_material: ShaderMaterial
var layout: ZoneLayout
var weather: Dictionary = {}  # weather type -> GPUParticles3D
## Materials with a `night` uniform (emissive windows, lava glow).
var night_materials: Array[ShaderMaterial] = []
## Last blended preset, for tests and debug.
var current: Dictionary = {}
var _applied_weights := PackedFloat32Array()
var _applied_time := -1


func setup(zone_layout: ZoneLayout, env: Environment, light: DirectionalLight3D, sky_shader_material: ShaderMaterial) -> void:
	layout = zone_layout
	environment = env
	sun = light
	sky_material = sky_shader_material
	_build_weather()


func set_time_of_day(id: int) -> void:
	time_of_day = clampi(id, 0, TimeOfDay.size() - 1) as TimeOfDay
	for material in night_materials:
		material.set_shader_parameter("night", 1.0 if time_of_day == TimeOfDay.NIGHT else (0.35 if time_of_day == TimeOfDay.DUSK else 0.0))
	if sky_material:
		sky_material.set_shader_parameter("star_amount", 1.0 if time_of_day == TimeOfDay.NIGHT else 0.0)


## Preset blended at (x, z) for the current time of day.
func blend_at(x: float, z: float) -> Dictionary:
	var w := layout.weights_at(x, z)
	var t := int(time_of_day)
	var out := {
		"fog_color": Color(0, 0, 0, 0), "fog_end": 0.0, "sun_color": Color(0, 0, 0, 0),
		"sun_energy": 0.0, "sun_direction": Vector3.ZERO, "ambient": Color(0, 0, 0, 0),
		"sky_top": Color(0, 0, 0, 0), "sky_horizon": Color(0, 0, 0, 0), "weather": {},
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
		if zone.weather != 0:
			out.weather[zone.weather] = out.weather.get(zone.weather, 0.0) + w[i]
	out.sun_direction = (out.sun_direction as Vector3).normalized()
	return out


## Applies the blend for a world position (the camera's, each frame).
func apply_at(position: Vector3) -> void:
	for particles: GPUParticles3D in weather.values():
		particles.global_position = position
	# Skip the writes when nothing changed (most frames, away from borders).
	var weights := layout.weights_at(position.x, position.z)
	if int(time_of_day) == _applied_time and _same(weights, _applied_weights):
		return
	_applied_weights = weights
	_applied_time = int(time_of_day)
	current = blend_at(position.x, position.z)
	if environment:
		environment.fog_light_color = current.fog_color
		environment.fog_depth_end = current.fog_end
		environment.fog_depth_begin = current.fog_end * 0.18
		environment.ambient_light_color = current.ambient
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
		particles.emitting = amount > 0.02
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


func _build_weather() -> void:
	weather[WEATHER_RAIN] = _particles("Rain", 900, Vector3(0, -38, 0), Vector2(0.035, 1.4),
		Color(0.7, 0.8, 1.0, 0.45), 1.0, BaseMaterial3D.BILLBOARD_FIXED_Y, 0.0)
	weather[WEATHER_SNOW] = _particles("Snow", 600, Vector3(2, -3.5, 1), Vector2(0.12, 0.12),
		Color(1, 1, 1, 0.9), 6.0, BaseMaterial3D.BILLBOARD_ENABLED, 0.6)
	weather[WEATHER_EMBERS] = _particles("Embers", 240, Vector3(0, 2.5, 0), Vector2(0.1, 0.1),
		Color(1.0, 0.5, 0.15, 1.0), 6.0, BaseMaterial3D.BILLBOARD_ENABLED, 0.8)


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
