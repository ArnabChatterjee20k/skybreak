class_name FlightTrail
extends GPUParticles3D
## Speed lines that stream off a fighter in fast flight and dashes, denser the faster
## it goes. One per fighter, moved by MatchVfx each frame; idle below min_speed.

## Below this speed (m/s) nothing is emitted; full density at max_speed.
var min_speed := 18.0
var max_speed := 55.0

var _emitter: ParticleProcessMaterial


func _init() -> void:
	amount = 40
	lifetime = 0.28
	local_coords = false
	emitting = false
	_emitter = VfxKit.emitter(&"speed").duplicate() as ParticleProcessMaterial
	process_material = _emitter
	draw_pass_1 = VfxKit.quad(Vector2(0.06, 2.2))
	material_override = VfxKit.layer_material(&"streak")
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))


## Follows the fighter; `velocity` sets the line direction and density.
func follow(where: Vector3, velocity: Vector3, color: Color) -> void:
	global_position = where
	var speed := velocity.length()
	var ratio := density(speed, min_speed, max_speed)
	if ratio <= 0.0:
		emitting = false
		return
	var back := -velocity / speed
	if not _emitter.direction.is_equal_approx(back):
		_emitter.direction = back
	amount_ratio = ratio
	VfxKit.set_param(self, &"tint", color)
	emitting = true


## Share of the line budget at a speed.
static func density(speed: float, low: float, high: float) -> float:
	if speed <= low:
		return 0.0
	return clampf((speed - low) / maxf(high - low, 0.001), 0.15, 1.0)
