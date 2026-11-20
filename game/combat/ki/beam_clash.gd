class_name BeamClash
extends RefCounted
## Two beams locked head to head: a rhythm duel (GAME_DESIGN §5.8). Beats on
## Q/E/F/R come at fixed ticks; on-beat presses of the right button push the
## meeting point toward the other side, wrong or off-beat presses give ground.
## Sim state: only KiRules writes it.

var id: int = 0
## Beam ids and their owners: side 0 wins with push > 0, side 1 with push < 0.
var beams := PackedInt32Array([-1, -1])
var owners := PackedInt32Array([-1, -1])
var start_tick: int = 0
## Where the beams met; the meeting point slides from here along axis by push.
var centre: Vector3 = Vector3.ZERO
## Unit direction from side 0's origin toward side 1's.
var axis: Vector3 = Vector3.FORWARD
var push: int = 0
## Tick of each beat and the FighterInput.Action to press on it.
var beat_ticks := PackedInt32Array()
var beat_buttons := PackedInt32Array()
## Per side: bit k set once beat k was judged for that side.
var judged := PackedInt32Array([0, 0])
## Per side: ki spends used.
var spends := PackedInt32Array([0, 0])
## Per side: on-beat presses, for the view and tests.
var good := PackedInt32Array([0, 0])
var end_tick: int = 0


func side_of(fighter_index: int) -> int:
	return 0 if owners[0] == fighter_index else (1 if owners[1] == fighter_index else -1)


## Where the beams meet now.
func point(metres_per_push: float) -> Vector3:
	return centre + axis * (push * metres_per_push)


func state_values() -> Array:
	return [id, beams, owners, start_tick, centre, axis, push, beat_ticks, beat_buttons, judged,
		spends, good, end_tick]
