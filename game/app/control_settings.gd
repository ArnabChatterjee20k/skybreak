class_name ControlSettings
extends RefCounted
## Camera sensitivity and key / mouse-button rebinds, saved in user://settings.cfg under [controls].

const SAVE_PATH := "user://settings.cfg"
const SECTION := "controls"
## FighterCamera's default radians per pixel; the slider scales it.
const BASE_MOUSE_SENSITIVITY := 0.0025
const MIN_SENSITIVITY := 0.25
const MAX_SENSITIVITY := 3.0
## Actions offered for rebinding, in menu order, with their labels.
const REBINDABLE := {
	&"move_forward": "Move forward",
	&"move_back": "Move back",
	&"move_left": "Move left",
	&"move_right": "Move right",
	&"ascend": "Fly up",
	&"descend": "Fly down",
	&"fighter_light": "Light attack",
	&"fighter_heavy": "Heavy attack",
	&"fighter_lock_toggle": "Lock on",
	&"fighter_dash": "Dodge (tap) / dash (hold)",
	&"fighter_block": "Block",
	&"fighter_grab": "Grab",
	&"fighter_ki_blast": "Ki blast",
	&"fighter_charge": "Charge ki",
	&"fighter_special_1": "Special 1",
	&"fighter_special_2": "Special 2",
	&"fighter_special_3": "Special 3",
	&"fighter_ultimate": "Ultimate",
	&"fighter_transform": "Transform",
	&"fighter_breaker": "Breaker",
	&"fighter_pickup": "Pick up",
	&"fighter_throw": "Throw weapon",
}

## Multiplier on BASE_MOUSE_SENSITIVITY.
var sensitivity: float = 1.0:
	set(value):
		sensitivity = clampf(value, MIN_SENSITIVITY, MAX_SENSITIVITY)
## Action -> physical keycode, only for actions the player rebound.
var key_overrides: Dictionary = {}
## Action -> mouse button (MOUSE_BUTTON_NONE = no button), only for actions the player rebound.
var mouse_overrides: Dictionary = {}


func mouse_sensitivity() -> float:
	return BASE_MOUSE_SENSITIVITY * sensitivity


## Rebinds `action` to one key, replacing its keyboard keys (mouse buttons stay).
## Keys that make browser shortcuts on the web (Ctrl, Cmd, Alt) are refused.
func rebind(action: StringName, keycode: Key) -> bool:
	if InputBindings.is_blocked_key(keycode):
		return false
	key_overrides[action] = keycode
	_apply_key(action, keycode)
	return true


## Rebinds `action` to one mouse button, replacing its mouse buttons (keys stay). The button
## leaves every other rebindable action, so one click never does two things. No wheel.
func rebind_mouse(action: StringName, button: MouseButton) -> bool:
	if not is_bindable_button(button) or not REBINDABLE.has(action):
		return false
	for other: StringName in REBINDABLE:
		if other != action and button in mouse_buttons(other):
			mouse_overrides[other] = MOUSE_BUTTON_NONE
			_apply_mouse(other, MOUSE_BUTTON_NONE)
	mouse_overrides[action] = button
	_apply_mouse(action, button)
	return true


## Rebinds to whatever the player pressed: a key or a mouse button.
func rebind_event(action: StringName, event: InputEvent) -> bool:
	if event is InputEventKey:
		return rebind(action, (event as InputEventKey).physical_keycode)
	if event is InputEventMouseButton:
		return rebind_mouse(action, (event as InputEventMouseButton).button_index)
	return false


## Buttons a hold can be read from: not the wheel, whose notches are press-only.
static func is_bindable_button(button: MouseButton) -> bool:
	return button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE,
		MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]


## Mouse buttons bound to an action now.
static func mouse_buttons(action: StringName) -> Array[MouseButton]:
	var buttons: Array[MouseButton] = []
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			if event is InputEventMouseButton:
				buttons.append((event as InputEventMouseButton).button_index)
	return buttons


## Puts every action back on its InputBindings default.
func reset_bindings() -> void:
	key_overrides.clear()
	mouse_overrides.clear()
	for action: StringName in REBINDABLE:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	InputBindings.install_defaults()


func apply_bindings() -> void:
	for action: StringName in key_overrides:
		if not InputBindings.is_blocked_key(key_overrides[action]):
			_apply_key(action, key_overrides[action])
	for action: StringName in mouse_overrides:
		_apply_mouse(action, mouse_overrides[action])


## The mouse button and key shown for an action, mouse first: "LMB / J", "E", "MMB".
static func binding_label(action: StringName) -> String:
	var parts: Array[String] = []
	for button in mouse_buttons(action):
		if is_bindable_button(button):
			parts.append(InputBindings.mouse_label(button))
	var key := key_label(action)
	if key != "-" or parts.is_empty():
		parts.append(key)
	return " / ".join(parts)


## The key label shown for an action, e.g. "W" or "Shift".
static func key_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "-"
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return OS.get_keycode_string(code)
	return "-"


func save(path: String = SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	config.load(path)  # Keep other sections; a missing file is fine.
	config.set_value(SECTION, "sensitivity", sensitivity)
	if config.has_section_key(SECTION, "keys"):
		config.erase_section_key(SECTION, "keys")
	var keys := {}
	for action: StringName in key_overrides:
		keys[String(action)] = int(key_overrides[action])
	config.set_value(SECTION, "keys", keys)
	var buttons := {}
	for action: StringName in mouse_overrides:
		buttons[String(action)] = int(mouse_overrides[action])
	config.set_value(SECTION, "mouse", buttons)
	return config.save(path)


static func load_saved(path: String = SAVE_PATH) -> ControlSettings:
	var settings := ControlSettings.new()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return settings
	settings.sensitivity = float(config.get_value(SECTION, "sensitivity", 1.0))
	var keys: Variant = config.get_value(SECTION, "keys", {})
	if keys is Dictionary:
		for action: String in keys:
			if REBINDABLE.has(StringName(action)):
				settings.key_overrides[StringName(action)] = int(keys[action]) as Key
	var buttons: Variant = config.get_value(SECTION, "mouse", {})
	if buttons is Dictionary:
		for action: String in buttons:
			var button := int(buttons[action]) as MouseButton
			if REBINDABLE.has(StringName(action)) and (button == MOUSE_BUTTON_NONE or is_bindable_button(button)):
				settings.mouse_overrides[StringName(action)] = button
	return settings


func _apply_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)


func _apply_mouse(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and is_bindable_button((event as InputEventMouseButton).button_index):
			InputMap.action_erase_event(action, event)
	if button != MOUSE_BUTTON_NONE:
		InputMap.action_add_event(action, InputBindings.mouse_event(button))
