class_name InputBindings
extends RefCounted
## Default keyboard and mouse bindings. Each fighter action maps to one
## InputMap action named "fighter_<action>". Rebinding edits the InputMap.

const MOVE_FORWARD := &"move_forward"
const MOVE_BACK := &"move_back"
const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const ASCEND := &"ascend"
const DESCEND := &"descend"
const TARGET_NEXT := &"target_next"
const TARGET_PREVIOUS := &"target_previous"

## InputMap action name for each FighterInput.Action.
const FIGHTER_ACTIONS := {
	FighterInput.Action.LIGHT: &"fighter_light",
	FighterInput.Action.HEAVY: &"fighter_heavy",
	FighterInput.Action.BLOCK: &"fighter_block",
	FighterInput.Action.DASH: &"fighter_dash",
	FighterInput.Action.GRAB: &"fighter_grab",
	FighterInput.Action.KI_BLAST: &"fighter_ki_blast",
	FighterInput.Action.CHARGE: &"fighter_charge",
	FighterInput.Action.SPECIAL_1: &"fighter_special_1",
	FighterInput.Action.SPECIAL_2: &"fighter_special_2",
	FighterInput.Action.SPECIAL_3: &"fighter_special_3",
	FighterInput.Action.ULTIMATE: &"fighter_ultimate",
	FighterInput.Action.TRANSFORM: &"fighter_transform",
	FighterInput.Action.BREAKER: &"fighter_breaker",
	FighterInput.Action.LOCK_TOGGLE: &"fighter_lock_toggle",
}

## Vanish is DASH + BLOCK (Shift+E); the sim reads the combination.
const DEFAULT_KEYS := {
	MOVE_FORWARD: [KEY_W],
	MOVE_BACK: [KEY_S],
	MOVE_LEFT: [KEY_A],
	MOVE_RIGHT: [KEY_D],
	ASCEND: [KEY_SPACE],
	DESCEND: [KEY_CTRL],
	&"fighter_block": [KEY_E],
	&"fighter_dash": [KEY_SHIFT],
	&"fighter_grab": [KEY_F],
	&"fighter_ki_blast": [KEY_Q],
	&"fighter_charge": [KEY_R],
	&"fighter_special_1": [KEY_1],
	&"fighter_special_2": [KEY_2],
	&"fighter_special_3": [KEY_3],
	&"fighter_ultimate": [KEY_4],
	&"fighter_transform": [KEY_T],
	&"fighter_breaker": [KEY_X],
	&"fighter_lock_toggle": [KEY_TAB],
}

const DEFAULT_MOUSE_BUTTONS := {
	&"fighter_light": [MOUSE_BUTTON_LEFT],
	&"fighter_heavy": [MOUSE_BUTTON_RIGHT],
	&"fighter_lock_toggle": [MOUSE_BUTTON_MIDDLE],
	TARGET_NEXT: [MOUSE_BUTTON_WHEEL_DOWN],
	TARGET_PREVIOUS: [MOUSE_BUTTON_WHEEL_UP],
}


## Adds the default bindings for any action the InputMap does not have yet.
static func install_defaults() -> void:
	for action_name in _all_action_names():
		if InputMap.has_action(action_name):
			continue
		InputMap.add_action(action_name)
		for keycode in DEFAULT_KEYS.get(action_name, []):
			var key_event := InputEventKey.new()
			key_event.physical_keycode = keycode
			InputMap.action_add_event(action_name, key_event)
		for button in DEFAULT_MOUSE_BUTTONS.get(action_name, []):
			var mouse_event := InputEventMouseButton.new()
			mouse_event.button_index = button
			InputMap.action_add_event(action_name, mouse_event)


static func _all_action_names() -> Array[StringName]:
	var names: Array[StringName] = [
		MOVE_FORWARD, MOVE_BACK, MOVE_LEFT, MOVE_RIGHT,
		ASCEND, DESCEND, TARGET_NEXT, TARGET_PREVIOUS,
	]
	for action_name in FIGHTER_ACTIONS.values():
		names.append(action_name)
	return names
