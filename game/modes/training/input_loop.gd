class_name InputLoop
extends RefCounted
## Records up to MAX_TICKS of one fighter's inputs, then plays them back in a
## loop. Playback rebuilds pressed/released from the held bits, so the loop
## seam presses buttons the same way a person would.

## 10 seconds at 60 ticks a second.
const MAX_TICKS := 10 * CombatSim.TICKS_PER_SECOND

var recording := false
var _inputs: Array[FighterInput] = []
var _play_index := 0


func start_recording() -> void:
	_inputs = []
	_play_index = 0
	recording = true


func stop_recording() -> void:
	recording = false
	_play_index = 0


## Stores a copy of input; stops by itself once the loop is full. False once stopped.
func record(input: FighterInput) -> bool:
	if not recording:
		return false
	_inputs.append(copy_of(input))
	if _inputs.size() >= MAX_TICKS:
		stop_recording()
	return true


func has_recording() -> bool:
	return not recording and not _inputs.is_empty()


func length() -> int:
	return _inputs.size()


func rewind() -> void:
	_play_index = 0


## The next input of the loop, wrapping at the end; previous is the last played input.
func play_next(previous: FighterInput) -> FighterInput:
	var stored := _inputs[_play_index]
	_play_index = (_play_index + 1) % _inputs.size()
	var input := FighterInput.from_held(stored.held_actions, previous)
	input.move = stored.move
	input.vertical = stored.vertical
	input.view_yaw = stored.view_yaw
	input.camera_offset = stored.camera_offset
	input.target_switch = stored.target_switch
	return input


## Position in the loop (0-based) of the next input played.
func play_position() -> int:
	return _play_index


static func copy_of(input: FighterInput) -> FighterInput:
	var copy := FighterInput.new()
	copy.held_actions = input.held_actions
	copy.pressed_actions = input.pressed_actions
	copy.released_actions = input.released_actions
	copy.move = input.move
	copy.vertical = input.vertical
	copy.view_yaw = input.view_yaw
	copy.camera_offset = input.camera_offset
	copy.target_switch = input.target_switch
	return copy
