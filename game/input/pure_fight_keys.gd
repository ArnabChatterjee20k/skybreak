class_name PureFightKeys
extends RefCounted
## Keyboard for Pure Fight, one or two players on one keyboard (GAME_DESIGN §16.2). Actions
## are installed at runtime (rebindable). P1: WASD + J/K/L (light/medium/heavy), U throw,
## I technique, O finisher, Shift dash, E block. P2: arrows + numpad 1/2/3, 4 throw,
## 5 technique, 6 finisher, 0 dash (or , . / ; ' ] on laptops).

const ACTIONS := ["left", "right", "up", "down", "light", "medium", "heavy", "throw", "technique",
	"finisher", "dash", "block"]
const DEFAULTS := [
	{"left": [KEY_A], "right": [KEY_D], "up": [KEY_W, KEY_SPACE], "down": [KEY_S], "light": [KEY_J],
		"medium": [KEY_K], "heavy": [KEY_L], "throw": [KEY_U], "technique": [KEY_I],
		"finisher": [KEY_O], "dash": [KEY_SHIFT], "block": [KEY_E]},
	{"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
		"light": [KEY_KP_1, KEY_COMMA], "medium": [KEY_KP_2, KEY_PERIOD], "heavy": [KEY_KP_3, KEY_SLASH],
		"throw": [KEY_KP_4, KEY_SEMICOLON], "technique": [KEY_KP_5, KEY_APOSTROPHE],
		"finisher": [KEY_KP_6, KEY_BRACKETRIGHT], "dash": [KEY_KP_0, KEY_BACKSLASH], "block": [KEY_KP_PERIOD]},
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
	var defaults: Dictionary = DEFAULTS[player_index]
	for action in ACTIONS:
		var name := action_name(player_index, action)
		if InputMap.has_action(name):
			continue
		InputMap.add_action(name)
		for key in defaults[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(name, event)


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


## The move list keys for the HUD, e.g. "J/K/L".
static func button_text(player_index: int) -> String:
	return "J K L / U throw / I technique / O finisher" if player_index == 0 else \
		"Num1 2 3 / Num4 throw / Num5 technique / Num6 finisher"
