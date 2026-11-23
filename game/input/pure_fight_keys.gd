class_name PureFightKeys
extends RefCounted
## Keyboard and mouse for Pure Fight, one player per laptop or two on one keyboard
## (GAME_DESIGN §16.2). Actions are installed at runtime (rebindable). No numpad, F-keys or
## Ctrl/Cmd/Alt, so it works on a Mac laptop in the browser. P1 (WASD + mouse): left click
## light, middle click or Q medium, right click heavy, F throw, R technique, C finisher, Left
## Shift dash, E block; J/K/L, U, I, O do the same keyboard-only. P2: arrows, , . / attacks,
## ; throw, ' technique, ] finisher, Right Shift dash, [ block.

const ACTIONS := ["left", "right", "up", "down", "light", "medium", "heavy", "throw", "technique",
	"finisher", "dash", "block"]
## Physical keys per action; a [key, location] pair pins a left or right modifier.
const DEFAULTS := [
	{"left": [KEY_A], "right": [KEY_D], "up": [KEY_W, KEY_SPACE], "down": [KEY_S], "light": [KEY_J],
		"medium": [KEY_Q, KEY_K], "heavy": [KEY_L], "throw": [KEY_F, KEY_U], "technique": [KEY_R, KEY_I],
		"finisher": [KEY_C, KEY_O], "dash": [[KEY_SHIFT, KEY_LOCATION_LEFT]], "block": [KEY_E]},
	{"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
		"light": [KEY_COMMA], "medium": [KEY_PERIOD], "heavy": [KEY_SLASH],
		"throw": [KEY_SEMICOLON], "technique": [KEY_APOSTROPHE],
		"finisher": [KEY_BRACKETRIGHT], "dash": [[KEY_SHIFT, KEY_LOCATION_RIGHT]], "block": [KEY_BRACKETLEFT]},
]
## Mouse buttons per player (P1 only: one mouse). A Mac trackpad's two-finger click is RMB.
const MOUSE_DEFAULTS := [
	{"light": [MOUSE_BUTTON_LEFT], "medium": [MOUSE_BUTTON_MIDDLE], "heavy": [MOUSE_BUTTON_RIGHT]},
	{},
]
## Keypad keys: never a default (laptops, Macs among them, have no numpad).
const NUMPAD_KEYS: Array[Key] = [KEY_KP_ENTER, KEY_KP_MULTIPLY, KEY_KP_DIVIDE, KEY_KP_SUBTRACT,
	KEY_KP_PERIOD, KEY_KP_ADD, KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6,
	KEY_KP_7, KEY_KP_8, KEY_KP_9]
## Key labels for hints, per player.
const LABELS := [
	{"move": "A/D", "jump": "W/Space", "crouch": "S", "light": "Left click", "medium": "Middle click or Q",
		"heavy": "Right click", "throw": "F", "technique": "R", "finisher": "C", "dash": "Left Shift",
		"block": "E", "keys": "J/K/L, U throw, I technique, O finisher"},
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
## Buttons pressed since the last tick, so a click shorter than a tick (a trackpad tap) counts.
var _tapped := 0
## Physics frame of the last latched press; a latch older than TAP_FRAMES is dropped (a menu
## or a round intro in between), so a stale click never fires later.
var _tapped_frame := -100
const TAP_FRAMES := 2


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
		for button: MouseButton in MOUSE_DEFAULTS[player_index].get(action, []):
			InputMap.action_add_event(name, InputBindings.mouse_event(button))


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


## Latches a press of one of this player's buttons until the next read_tick().
func note_event(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	for action in BITS:
		if event.is_action_pressed(action_name(player, action)):
			_tapped |= int(BITS[action])
			_tapped_frame = Engine.get_physics_frames()


func read_tick() -> FighterInput:
	var held := _tapped if Engine.get_physics_frames() - _tapped_frame <= TAP_FRAMES else 0
	_tapped = 0
	for action in BITS:
		if Input.is_action_pressed(action_name(player, action)):
			held |= int(BITS[action])
	var input := FighterInput.from_held(held, _previous)
	input.move = Vector2(Input.get_axis(action_name(player, "left"), action_name(player, "right")),
		Input.get_axis(action_name(player, "down"), action_name(player, "up")))
	_previous = input
	return input


## The move list keys for the HUD, e.g. "LMB MMB/Q RMB / F throw / R technique / C finisher".
static func button_text(player_index: int) -> String:
	if player_index == 0:
		return "LMB MMB/Q RMB / F throw / R technique / C finisher  (or J K L / U / I / O)"
	var l: Dictionary = LABELS[player_index]
	return "%s %s %s / %s throw / %s technique / %s finisher" % [l.light, l.medium, l.heavy, l.throw,
		l.technique, l.finisher]


## One player's controls in a few short lines for the move list and menus.
static func controls_text(player_index: int) -> String:
	var l: Dictionary = LABELS[player_index]
	return "\n".join(["P%d  move %s, jump %s, crouch %s" % [player_index + 1, l.move, l.jump, l.crouch],
		"    dash %s + direction (or tap twice), block: hold back or %s" % [l.dash, l.block],
		"    %s light/medium/heavy, %s throw, %s technique, %s finisher" % [
			(" / " if l.has("keys") else " ").join([l.light, l.medium, l.heavy]), l.throw, l.technique, l.finisher]]
		+ (["    keyboard only: %s" % l.keys] if l.has("keys") else []))
