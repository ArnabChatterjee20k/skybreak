class_name KiBlastEffect
extends VfxEffect
## Ki blast: a hot core in a soft glow with a streak trail, flying straight, then an
## impact burst where it ends. Pooled like any VfxEffect.

## Seconds of flight before the impact burst.
var flight_time := 0.4
var velocity := Vector3.ZERO

var _flight: Array[MeshInstance3D] = []
var _impact: Array[MeshInstance3D] = []
var _trail: GPUParticles3D
var _impact_sparks: GPUParticles3D
var _impacted := false

const IMPACT_SECONDS := 0.35


func _init() -> void:
	super._init()
	default_color = VfxCatalog.WARM
	_flight.append(add_sprite(&"glow", 2.4))
	_flight.append(add_sprite(&"orb", 0.95))
	_trail = add_particles(&"streak", &"trail", 24, 0.22, Vector2(0.4, 1.8), false)
	_trail.local_coords = false
	_trail.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	_impact.append(add_sprite(&"flash", 2.4))
	_impact.append(add_sprite(&"ring", 2.8))
	_impact.append(add_sprite(&"spikes", 2.2))
	_impact_sparks = add_particles(&"spark", &"burst", 14, 0.3, Vector2(0.08, 0.6))
	lifetime = flight_time + IMPACT_SECONDS


## Fires from `from` along `direction` (m/s when not normalised) for `seconds`.
func launch(from: Vector3, direction: Vector3, color: Color, seconds: float, speed: float = 40.0) -> void:
	flight_time = maxf(seconds, 0.0)
	lifetime = flight_time + IMPACT_SECONDS
	velocity = direction.normalized() * speed
	play_at(from, color)
	_impacted = false
	_impact_sparks.emitting = false
	_set_layers(true)


## Where the blast is now.
func head() -> Vector3:
	return global_position


func _advanced(delta: float) -> void:
	if _age < flight_time:
		global_position += velocity * delta
	elif not _impacted:
		_impacted = true
		_trail.emitting = false
		_impact_sparks.restart()
		_impact_sparks.emitting = true
		_set_layers(false)


func _set_layers(flying: bool) -> void:
	for mesh in _flight:
		mesh.visible = flying
	for mesh in _impact:
		mesh.visible = not flying


func _set_progress(_value: float) -> void:
	var impact := clampf((_age - flight_time) / IMPACT_SECONDS, 0.0, 1.0)
	for mesh in _flight:
		VfxKit.set_param(mesh, &"progress", 0.0)
	for mesh in _impact:
		VfxKit.set_param(mesh, &"progress", impact)
