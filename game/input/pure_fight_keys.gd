class_name PureFightKeys
extends RefCounted
## Keyboard for Pure Fight, one or two players on one laptop keyboard (GAME_DESIGN §16.2).
## Actions are installed at runtime (rebindable). No numpad, F-keys or Ctrl/Cmd/Alt, so it
## works on a Mac laptop in the browser. P1: A/D, W/Space, S, J/K/L, U throw, I technique,
## O finisher, Left Shift dash, E block. P2: arrows, , . / attacks, ; throw, ' technique,
## ] finisher, Right Shift dash, [ block.

const ACTIONS := ["left", "right", "up", "down", "light", "medium", "heavy", "throw", "technique",
	"finisher", "dash", "block"]
## Physical keys per action; a [key, location] pair pins a left or right modifier.
const DEFAULTS := [
	{"left": [KEY_A], "right": [KEY_D], "up": [KEY_W, KEY_SPACE], "down": [KEY_S], "light": [KEY_J],
		"medium": [KEY_K], "heavy": [KEY_L], "throw": [KEY_U], "technique": [KEY_I],
		"finisher": [KEY_O], "dash": [[KEY_SHIFT, KEY_LOCATION_LEFT]], "block": [KEY_E]},
	{"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
		"light": [KEY_COMMA], "medium": [KEY_PERIOD], "heavy": [KEY_SLASH],
		"throw": [KEY_SEMICOLON], "technique": [KEY_APOSTROPHE],
		"finisher": [KEY_BRACKETRIGHT], "dash": [[KEY_SHIFT, KEY_LOCATION_RIGHT]], "block": [KEY_BRACKETLEFT]},
]
## Keypad keys: never a default (laptops, Macs among them, have no numpad).
const NUMPAD_KEYS: Array[Key] = [KEY_KP_ENTER, KEY_KP_MULTIPLY, KEY_KP_DIVIDE, KEY_KP_SUBTRACT,
	KEY_KP_PERIOD, KEY_KP_ADD, KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6,
	KEY_KP_7, KEY_KP_8, KEY_KP_9]
## Key labels for hints, per player.
const LABELS := [
	{"move": "A/D", "jump": "W/Space", "crouch": "S", "light": "J", "medium": "K", "heavy": "L",
		"throw": "U", "technique": "I", "finisher": "O", "dash": "Left Shift", "block": "E"},
	{"move": "Left/Right arrows", "jump": "Up arrow", "crouch": "Down arrow", "light": ",", "medium": ".", "heavy": "/",
		"throw": ";", "technique": "'", "finisher": "]", "dash": "Right Shift", "block": "["},
]
const BITS := {
	"light": FighterInput.Action.LIGHT, "medium": FighterInput.Action.SPECIAL_1,
	"heavy": FighterInput.Action.HEAVY, "throw": FighterInput.Action.GRAB,
	"technique": FighterInput.Action.SPECIAL_2, "finisher": FighterInput.Action.ULTIMATE,
	"dash": FighterInput.Action.DASH, "block": FighterInput.Action.BLOCK,
}

var player := 0
var _previous := FighterInput.new()


func _init(player_index: int = 0) -> void:
	player = player_index
	install(player)


static func action_name(player_index: int, action: String) -> StringName:
	return StringName("pf%d_%s" % [player_index + 1, action])


## Adds this player's actions with their default keys unless they already exist.
static func install(player_index: int) -> void:
	for action in ACTIONS:
		var name := action_name(player_index, action)
		if InputMap.has_action(name):
			continue
		InputMap.add_action(name)
		for event in default_events(player_index, action):
			InputMap.action_add_event(name, event)


## The default key events of one player's action.
static func default_events(player_index: int, action: String) -> Array[InputEventKey]:
	var events: Array[InputEventKey] = []
	for entry: Variant in DEFAULTS[player_index][action]:
		var event := InputEventKey.new()
		if entry is Array:
			event.physical_keycode = entry[0]
			event.location = entry[1]
		else:
			event.physical_keycode = entry
		events.append(event)
	return events


static func is_numpad_key(keycode: Key) -> bool:
	return keycode in NUMPAD_KEYS


func read_tick() -> FighterInput:
	var held := 0
	for action in BITS:
		if Input.is_action_pressed(action_name(player, action)):
			held |= int(BITS[action])
	var input := FighterInput.from_held(held, _previous)
	input.move = Vector2(Input.get_axis(action_name(player, "left"), action_name(player, "right")),
		Input.get_axis(action_name(player, "down"), action_name(player, "up")))
	_previous = input
	return input


## The move list keys for the HUD, e.g. "J K L / U throw / I technique / O finisher".
static func button_text(player_index: int) -> String:
	var l: Dictionary = LABELS[player_index]
	return "%s %s %s / %s throw / %s technique / %s finisher" % [l.light, l.medium, l.heavy, l.throw,
		l.technique, l.finisher]


## One player's controls in three short lines for the move list and menus.
static func controls_text(player_index: int) -> String:
	var l: Dictionary = LABELS[player_index]
	return "\n".join(["P%d  move %s, jump %s, crouch %s" % [player_index + 1, l.move, l.jump, l.crouch],
		"    dash %s + direction (or tap twice), block: hold back or %s" % [l.dash, l.block],
		"    %s %s %s light/medium/heavy, %s throw, %s technique, %s finisher" % [l.light, l.medium,
			l.heavy, l.throw, l.technique, l.finisher]])
