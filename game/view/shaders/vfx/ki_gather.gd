class_name KiGather
extends GPUParticles3D
## Soft ki streaks pulled into a point (the hands while a charged blast or a beam
## charges). One per fighter, built once and moved by KiLayer; view only.

const BUDGET := 20
const RADIUS := 0.95
const LIFE := 0.4
const SPARK_SHADER := preload("res://game/view/shaders/aura_spark.gdshader")

static var _process: ParticleProcessMaterial

var _material: ShaderMaterial


func _init() -> void:
	amount = BUDGET
	lifetime = LIFE
	randomness = 0.3
	local_coords = true
	emitting = false
	process_material = shared_process()
	var streak := QuadMesh.new()
	streak.size = Vector2(0.06, 0.34)
	_material = ShaderMaterial.new()
	_material.shader = SPARK_SHADER
	_material.render_priority = 1
	_material.set_shader_parameter(&"spark_shape", 1)
	_material.set_shader_parameter(&"intensity", 1.0)
	_material.set_shader_parameter(&"core_whiteness", 0.75)
	streak.material = _material
	draw_pass_1 = streak
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))


## Gathers at `where` in `color`; `share` (0-1) scales how many streaks (quality, progress).
func gather(where: Vector3, color: Color, share: float) -> void:
	global_position = where
	_material.set_shader_parameter(&"tint", Color(color, 1.0))
	amount_ratio = clampf(share, 0.0, 1.0)
	emitting = share > 0.001


func stop() -> void:
	emitting = false


func material() -> ShaderMaterial:
	return _material


static func shared_process() -> ParticleProcessMaterial:
	if _process != null:
		return _process
	_process = ParticleProcessMaterial.new()
	_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	_process.emission_sphere_radius = RADIUS
	_process.direction = Vector3.UP
	_process.spread = 0.0
	_process.initial_velocity_min = 0.0
	_process.initial_velocity_max = 0.0
	_process.radial_velocity_min = -RADIUS / LIFE * 1.1
	_process.radial_velocity_max = -RADIUS / LIFE * 0.8
	_process.gravity = Vector3.ZERO
	_process.scale_min = 0.6
	_process.scale_max = 1.0
	_process.particle_flag_align_y = true
	return _process
