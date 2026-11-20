class_name KiBeam
extends RefCounted
## A beam in flight: a capsule from origin along direction whose head grows
## to max_length. Sim state: only KiRules writes it.

var id: int = 0
var owner: int = 0
var move: MoveData
var origin: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.FORWARD
var length: float = 0.0
var max_length: float = 0.0
var speed: float = 0.0
var radius: float = 0.9
## Side rays at +-split_angle yaw (radians), 0 for none.
var split_angle: float = 0.0
var split_radius: float = 0.0
var age: int = 0
## Bit i set once it hit fighter i.
var hit_mask: int = 0
## Ticks it has been pushing on a blocker, for the repeated BLOCK event.
var block_ticks: int = 0
## True once it hit or was blocked (no whiff recovery).
var touched: bool = false
## Id of the clash it is locked in, or -1.
var clash_id: int = -1


## Start and end of each ray (main first, then the side rays).
func rays() -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = [PackedVector3Array([origin, origin + direction * length])]
	if split_angle > 0.0:
		for side in [-1.0, 1.0]:
			var turned := DetMath.axis_angle(Vector3.UP, split_angle * side) * direction
			out.append(PackedVector3Array([origin, origin + turned * length]))
	return out


func head() -> Vector3:
	return origin + direction * length


func state_values() -> Array:
	return [id, owner, move.id if move else &"", origin, direction, length, max_length, speed,
		radius, split_angle, split_radius, age, hit_mask, block_ticks, touched, clash_id]
