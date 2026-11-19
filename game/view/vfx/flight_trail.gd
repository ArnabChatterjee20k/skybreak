class_name FlightTrail
extends GPUParticles3D
## Speed lines that stream off a fighter in long dashes, flight boost and top speed,
## denser the faster it goes. One per fighter, moved by MatchVfx each frame; idle
## below min_speed. A new stream waits RESTART_SECONDS after the last one ended.

## Below this speed (m/s) nothing is emitted; full density at max_speed.
var min_speed := 18.0
var max_speed := 55.0
## Seconds after a stream ends before another may start (rate limit).
const RESTART_SECONDS := 0.6
## Line opacity (tint alpha): background texture, not a foreground layer.
const OPACITY := 0.55
const LIFETIME := 0.18

var _emitter: ParticleProcessMaterial
## Seconds until a new stream may start.
var _cooldown := 0.0
## Streams started so far, for tests and captures.
var starts := 0


func _init() -> void:
	amount = 40
	lifetime = LIFETIME
	local_coords = false
	emitting = false
	_emitter = VfxKit.emitter(&"speed").duplicate() as ParticleProcessMaterial
	process_material = _emitter
	draw_pass_1 = VfxKit.quad(Vector2(0.06, 2.2))
	material_override = VfxKit.layer_material(&"streak")
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))


## Follows the fighter; `velocity` sets the line direction and density (zero stops it).
func follow(where: Vector3, velocity: Vector3, color: Color, delta: float = 1.0 / 60.0) -> void:
	global_position = where
	_cooldown = maxf(_cooldown - delta, 0.0)
	var speed := velocity.length()
	var ratio := density(speed, min_speed, max_speed)
	if ratio <= 0.0:
		if emitting:
			_cooldown = RESTART_SECONDS
		emitting = false
		return
	if not emitting:
		if _cooldown > 0.0:
			return
		starts += 1
	var back := -velocity / speed
	if not _emitter.direction.is_equal_approx(back):
		_emitter.direction = back
	amount_ratio = ratio
	VfxKit.set_param(self, &"tint", Color(color, color.a * OPACITY))
	emitting = true


## Share of the line budget at a speed.
static func density(speed: float, low: float, high: float) -> float:
	if speed <= low:
		return 0.0
	return clampf((speed - low) / maxf(high - low, 0.001), 0.15, 1.0)
