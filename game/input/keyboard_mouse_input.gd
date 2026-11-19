class_name KeyboardMouseInput
extends Node
## Turns the local keyboard and mouse into one FighterInput per combat tick.

var _previous := FighterInput.new()
var _pending_target_switch: int = 0


func _ready() -> void:
	InputBindings.install_defaults()


func _unhandled_input(event: InputEvent) -> void:
	# Wheel notches arrive as events between ticks, so collect them here.
	if event.is_action_pressed(InputBindings.TARGET_NEXT):
		_pending_target_switch = 1
	elif event.is_action_pressed(InputBindings.TARGET_PREVIOUS):
		_pending_target_switch = -1


## Reads the input for this tick. Call exactly once per combat tick.
func read_tick(view_yaw: float, camera_offset: Vector2) -> FighterInput:
	var held := 0
	for action in InputBindings.FIGHTER_ACTIONS:
		if Input.is_action_pressed(InputBindings.FIGHTER_ACTIONS[action]):
			held |= action
	var input := FighterInput.from_held(held, _previous)
	input.move = Input.get_vector(
		InputBindings.MOVE_LEFT, InputBindings.MOVE_RIGHT,
		InputBindings.MOVE_BACK, InputBindings.MOVE_FORWARD)
	input.vertical = int(Input.is_action_pressed(InputBindings.ASCEND)) \
		- int(Input.is_action_pressed(InputBindings.DESCEND))
	input.view_yaw = view_yaw
	input.camera_offset = camera_offset
	input.target_switch = _pending_target_switch
	_pending_target_switch = 0
	_previous = input
	return input
