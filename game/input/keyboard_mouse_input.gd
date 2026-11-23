class_name KeyboardMouseInput
extends Node
## Turns the local keyboard and mouse into one FighterInput per combat tick.

## Two descend presses within this many ticks start a dive to the ground.
const DOUBLE_TAP_TICKS := 18
## A dive lets go after this many ticks even if it never lands (a safety net).
const DIVE_MAX_TICKS := 60 * 20

var _previous := FighterInput.new()
var _pending_target_switch: int = 0
var _descend_was_held := false
var _ticks_since_descend_tap := DOUBLE_TAP_TICKS + 1
## Ticks left in a double-tap dive; 0 when not diving.
var _dive_ticks := 0
## Actions pressed since the last tick, so a click shorter than a tick (a trackpad tap) counts.
var _tapped := 0
## Physics frame of the last latched press; a latch older than TAP_FRAMES is dropped (a menu
## or a round intro in between), so a stale click never fires later.
var _tapped_frame := -100
const TAP_FRAMES := 2


func _ready() -> void:
	InputBindings.install_defaults()


func _unhandled_input(event: InputEvent) -> void:
	# Wheel notches arrive as events between ticks, so collect them here.
	if event.is_action_pressed(InputBindings.TARGET_NEXT):
		_pending_target_switch = 1
	elif event.is_action_pressed(InputBindings.TARGET_PREVIOUS):
		_pending_target_switch = -1
	note_event(event)


## Latches a press of a fighter action until the next tick reads it.
func note_event(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	for action: int in InputBindings.FIGHTER_ACTIONS:
		if event.is_action_pressed(InputBindings.FIGHTER_ACTIONS[action]):
			_tapped |= action
			_tapped_frame = Engine.get_physics_frames()


## True while a double-tap dive holds descend for the player.
func is_diving() -> bool:
	return _dive_ticks > 0


## Reads the input for this tick. Call exactly once per combat tick.
## `grounded`: the fighter is standing, which ends a double-tap dive.
func read_tick(view_yaw: float, camera_offset: Vector2, grounded: bool = false) -> FighterInput:
	var held := 0
	for action in InputBindings.FIGHTER_ACTIONS:
		if Input.is_action_pressed(InputBindings.FIGHTER_ACTIONS[action]):
			held |= action
	if Engine.get_physics_frames() - _tapped_frame <= TAP_FRAMES:
		held |= _tapped
	_tapped = 0
	var input := FighterInput.from_held(held, _previous)
	input.move = Input.get_vector(
		InputBindings.MOVE_LEFT, InputBindings.MOVE_RIGHT,
		InputBindings.MOVE_BACK, InputBindings.MOVE_FORWARD)
	input.vertical = vertical_for_tick(Input.is_action_pressed(InputBindings.ASCEND),
		Input.is_action_pressed(InputBindings.DESCEND), grounded)
	input.view_yaw = view_yaw
	input.camera_offset = camera_offset
	input.target_switch = _pending_target_switch
	_pending_target_switch = 0
	_previous = input
	return input


## Ascend minus descend, plus the double-tap dive: tapping descend twice keeps
## flying down until the fighter lands, ascend is pressed or the dive times out.
func vertical_for_tick(ascend: bool, descend: bool, grounded: bool) -> int:
	var tapped := descend and not _descend_was_held
	_descend_was_held = descend
	_ticks_since_descend_tap += 1
	if tapped:
		if _ticks_since_descend_tap <= DOUBLE_TAP_TICKS and not grounded:
			_dive_ticks = DIVE_MAX_TICKS
		_ticks_since_descend_tap = 0
	if _dive_ticks > 0:
		_dive_ticks -= 1
		if ascend or grounded:
			_dive_ticks = 0
		else:
			return -1
	return int(ascend) - int(descend)
