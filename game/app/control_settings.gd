class_name ControlSettings
extends RefCounted
## Camera sensitivity and key rebinds, saved in user://settings.cfg under [controls].

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
	&"fighter_dash": "Dash",
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


func mouse_sensitivity() -> float:
	return BASE_MOUSE_SENSITIVITY * sensitivity


## Rebinds `action` to one key, replacing its keyboard keys (mouse buttons stay).
func rebind(action: StringName, keycode: Key) -> void:
	key_overrides[action] = keycode
	_apply_key(action, keycode)


## Puts every action back on its InputBindings default.
func reset_bindings() -> void:
	key_overrides.clear()
	for action: StringName in REBINDABLE:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	InputBindings.install_defaults()


func apply_bindings() -> void:
	for action: StringName in key_overrides:
		_apply_key(action, key_overrides[action])


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
