extends RefCounted
## Scripted human input for net tests: a seeded mix of holds, moves and camera turns.

const HOLDS: Array[int] = [
	0, 0,
	FighterInput.Action.DASH,
	FighterInput.Action.DASH | FighterInput.Action.BLOCK,
	FighterInput.Action.BLOCK,
	FighterInput.Action.LIGHT,
	FighterInput.Action.HEAVY,
	FighterInput.Action.CHARGE,
	FighterInput.Action.GRAB,
	FighterInput.Action.PICKUP,
	FighterInput.Action.LIGHT | FighterInput.Action.HEAVY,
]

var rng := RandomNumberGenerator.new()
var _previous := FighterInput.new()
var _hold := 0
var _move := Vector2.ZERO
var _vertical := 0
var _ticks_left := 0
var _yaw := 0.0


func _init(seed_value: int) -> void:
	rng.seed = seed_value


func next_input() -> FighterInput:
	_ticks_left -= 1
	if _ticks_left <= 0:
		_ticks_left = rng.randi_range(4, 24)
		_hold = HOLDS[rng.randi_range(0, HOLDS.size() - 1)]
		_move = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).limit_length(1.0)
		_vertical = rng.randi_range(-1, 1)
	if _ticks_left % 8 < 2:
		_yaw = wrapf(_yaw + rng.randf_range(-0.05, 0.05), -PI, PI)
	var input := FighterInput.from_held(_hold, _previous)
	input.move = _move
	input.vertical = _vertical
	input.view_yaw = _yaw
	input.camera_offset = Vector2(0.1, -0.05) if _hold == FighterInput.Action.BLOCK else Vector2.ZERO
	_previous = input
	return input
