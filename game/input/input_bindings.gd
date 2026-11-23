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
## Shows or hides the on-screen control hints (a UI action, not a fighter one).
const TOGGLE_HINTS := &"toggle_hints"

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
	FighterInput.Action.PICKUP: &"fighter_pickup",
	FighterInput.Action.WEAPON_NEXT: &"fighter_weapon_next",
	FighterInput.Action.WEAPON_PREVIOUS: &"fighter_weapon_previous",
	FighterInput.Action.THROW: &"fighter_throw",
	FighterInput.Action.QUICK_SWAP: &"fighter_quick_swap",
}

## Vanish is DASH + BLOCK (Shift+E); the sim reads the combination.
## Light and heavy are on the mouse (DEFAULT_MOUSE_BUTTONS); J/L are their keyboard-only keys,
## and U/I/O mirror Pure Fight's throw/technique/finisher keys.
const DEFAULT_KEYS := {
	MOVE_FORWARD: [KEY_W],
	MOVE_BACK: [KEY_S],
	MOVE_LEFT: [KEY_A],
	MOVE_RIGHT: [KEY_D],
	ASCEND: [KEY_SPACE],
	# C, not Ctrl: Ctrl+W closes a browser tab (T-UX1). Ctrl stays a desktop alternate.
	DESCEND: [KEY_C],
	&"fighter_light": [KEY_J],
	&"fighter_heavy": [KEY_L],
	&"fighter_block": [KEY_E],
	&"fighter_dash": [KEY_SHIFT],
	&"fighter_grab": [KEY_F, KEY_U],
	&"fighter_ki_blast": [KEY_Q],
	&"fighter_charge": [KEY_R],
	&"fighter_special_1": [KEY_1, KEY_I],
	&"fighter_special_2": [KEY_2],
	&"fighter_special_3": [KEY_3],
	&"fighter_ultimate": [KEY_4, KEY_O],
	&"fighter_transform": [KEY_T],
	&"fighter_breaker": [KEY_X],
	&"fighter_lock_toggle": [KEY_TAB],
	# Weapons (T-D14): G picks up, or throws with nothing in reach; the wheel stays target switch.
	&"fighter_pickup": [KEY_G],
	# Y quick-swaps to the last weapon (§5.11); C is descend since T-UX1.
	&"fighter_quick_swap": [KEY_Y],
	&"fighter_weapon_next": [KEY_B],
	&"fighter_weapon_previous": [KEY_Z],
	&"fighter_throw": [KEY_V],
	TOGGLE_HINTS: [KEY_H],
}

## Extra keys only off the web, where Ctrl+key would trigger browser shortcuts.
const DESKTOP_ALTERNATE_KEYS := {
	DESCEND: [KEY_CTRL],
}

## Mouse buttons (a Mac trackpad's two-finger click arrives as the right button).
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
		for keycode in default_keys(action_name):
			var key_event := InputEventKey.new()
			key_event.physical_keycode = keycode
			InputMap.action_add_event(action_name, key_event)
		for button in DEFAULT_MOUSE_BUTTONS.get(action_name, []):
			InputMap.action_add_event(action_name, mouse_event(button))


## A mouse button event for the InputMap (any modifiers, any device).
static func mouse_event(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event


## Short label of a mouse button, e.g. "LMB".
static func mouse_label(button: MouseButton) -> String:
	const NAMES := {
		MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB",
		MOUSE_BUTTON_WHEEL_UP: "Wheel up", MOUSE_BUTTON_WHEEL_DOWN: "Wheel down",
		MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5",
	}
	return NAMES.get(button, "Mouse %d" % button)


## Default keys of one action on this platform (no Ctrl alternate on the web).
static func default_keys(action_name: StringName, web: bool = OS.has_feature("web")) -> Array:
	var keys: Array = DEFAULT_KEYS.get(action_name, []).duplicate()
	if not web:
		keys.append_array(DESKTOP_ALTERNATE_KEYS.get(action_name, []))
	return keys


## Keys a player may not bind on this platform: modifiers that make browser shortcuts.
static func is_blocked_key(keycode: Key, web: bool = OS.has_feature("web")) -> bool:
	return web and keycode in [KEY_CTRL, KEY_META, KEY_ALT]


static func _all_action_names() -> Array[StringName]:
	var names: Array[StringName] = [
		MOVE_FORWARD, MOVE_BACK, MOVE_LEFT, MOVE_RIGHT,
		ASCEND, DESCEND, TARGET_NEXT, TARGET_PREVIOUS, TOGGLE_HINTS,
	]
	for action_name in FIGHTER_ACTIONS.values():
		names.append(action_name)
	return names
