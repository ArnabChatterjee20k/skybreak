class_name ControlHints
extends Control
## In-match control hints (T-UX1): a compact strip of key caps along the bottom
## edge (keyboard or gamepad, whichever was used last), toggled with H and on by
## default for the first matches (HintSettings). While hidden, a small "H
## Controls" tag stays in the corner. A contextual prompt appears after
## AIR_IDLE_SECONDS airborne without vertical input: how to fly down and land.

## Seconds airborne with no ascend/descend before the fly-down prompt shows.
const AIR_IDLE_SECONDS := 3.0
## Feet higher than this above the ground (m) count as airborne for the prompt.
const AIRBORNE_ABOVE := 2.0
## Sizes in the 1920x1080 design space, scaled with the window like MatchHud.
const FONT_SIZE := 18
const PROMPT_FONT_SIZE := 24
const BOTTOM_MARGIN := 18.0
const CHIP_PADDING := 7.0
const ENTRY_GAP := 20.0
const STRIP_HEIGHT := 34.0
const CAP := Color(0.95, 0.95, 0.92, 0.95)
const INK := Color(0.05, 0.05, 0.08, 0.85)
const STRIP := Color(0.05, 0.05, 0.08, 0.55)
const PROMPT := Color(1.0, 0.85, 0.25)
const GAMEPAD_UNBOUND := "Gamepad controls are coming: play with keyboard + mouse"

## Set by the level.
var sim: CombatSim
var player := 0
## The local keyboard reader, for its double-tap dive (optional).
var keyboard: KeyboardMouseInput
## False hides everything (scripted or all-AI matches); the first active frame
## counts the match in the settings.
var active := true
var settings_path := HintSettings.SAVE_PATH

var strip_visible := true
var prompt_visible := false
var gamepad := false

var _settings: HintSettings
var _counted := false
var _air_idle := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings = HintSettings.load_saved(settings_path)
	strip_visible = _settings.shows_by_default()


func _process(delta: float) -> void:
	visible = active and sim != null and player < sim.fighters.size()
	if not visible:
		return
	if not _counted:
		_counted = true
		_settings.matches_played += 1
		_settings.save(settings_path)
	var vertical_held := Input.is_action_pressed(InputBindings.ASCEND) \
		or Input.is_action_pressed(InputBindings.DESCEND)
	var diving := keyboard != null and keyboard.is_diving()
	var me := sim.fighters[player]
	var high := me.position.y - me.stand_height > AIRBORNE_ABOVE
	_air_idle = air_idle_step(_air_idle, high and not me.is_ko_state(), vertical_held or diving, delta)
	prompt_visible = _air_idle >= AIR_IDLE_SECONDS
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		gamepad = false
	if active and event.is_action_pressed(InputBindings.TOGGLE_HINTS):
		toggle()


## Shows or hides the strip and remembers the choice.
func toggle() -> void:
	strip_visible = not strip_visible
	_settings.choose(strip_visible)
	_settings.save(settings_path)


func _draw() -> void:
	var scale_factor := MatchHud.design_scale(size)
	var font := ThemeDB.fallback_font
	var bottom := size.y - BOTTOM_MARGIN * scale_factor
	if prompt_visible:
		var text := fly_down_prompt()
		var font_size := roundi(PROMPT_FONT_SIZE * scale_factor)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var y := bottom - (STRIP_HEIGHT + 30.0) * scale_factor
		var at := Vector2((size.x - width) / 2.0, y)
		var pad := 12.0 * scale_factor
		draw_rect(Rect2(at.x - pad, y - font_size * 1.05, width + pad * 2.0, font_size * 1.45), STRIP)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(roundi(6 * scale_factor), 2), INK)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, PROMPT)
	var entries := entries_for(gamepad) if strip_visible else [[ControlSettings.key_label(InputBindings.TOGGLE_HINTS), "Controls"]]
	_draw_strip(entries, font, scale_factor, bottom, not strip_visible)


## One row of [key, label] chips, centred (or bottom left when `corner`).
func _draw_strip(entries: Array, font: Font, scale_factor: float, bottom: float, corner: bool) -> void:
	var font_size := maxi(roundi(FONT_SIZE * scale_factor), 9)
	var pad := CHIP_PADDING * scale_factor
	var gap := ENTRY_GAP * scale_factor
	var height := STRIP_HEIGHT * scale_factor
	var widths: Array[Vector2] = []
	var total := 0.0
	for entry: Array in entries:
		var key_w := font.get_string_size(entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + pad * 2.0
		var label_w := font.get_string_size(entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if entry[1] != "" else -pad
		widths.append(Vector2(key_w, label_w))
		total += key_w + pad + label_w + gap
	total -= gap
	var x := gap if corner else (size.x - total) / 2.0
	var top := bottom - height
	draw_rect(Rect2(x - pad * 1.5, top, total + pad * 3.0, height), STRIP)
	var baseline := top + height / 2.0 + font_size * 0.36
	for i in entries.size():
		var entry: Array = entries[i]
		var cap := Rect2(x, top + height * 0.16, widths[i].x, height * 0.68)
		draw_rect(cap, CAP)
		draw_string(font, Vector2(x + pad, baseline), entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
		x += widths[i].x + pad
		if entry[1] != "":
			draw_string_outline(font, Vector2(x, baseline), entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				maxi(roundi(4 * scale_factor), 1), INK)
			draw_string(font, Vector2(x, baseline), entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		x += widths[i].y + gap


## Seconds spent airborne without vertical input, reset by input or landing.
static func air_idle_step(idle: float, airborne: bool, vertical_input: bool, delta: float) -> float:
	return idle + delta if airborne and not vertical_input else 0.0


## "Hold C to fly down · double-tap C to land", with the current descend key.
static func fly_down_prompt() -> String:
	var key := ControlSettings.key_label(InputBindings.DESCEND).to_upper()
	return "Hold %s to fly down  ·  double-tap %s to land" % [key, key]


## [key, label] pairs for the strip, with the current bindings.
static func entries_for(use_gamepad: bool) -> Array:
	if use_gamepad:
		return gamepad_entries()
	var descend := _key(InputBindings.DESCEND)
	return [
		[" ".join([_key(InputBindings.MOVE_FORWARD), _key(InputBindings.MOVE_LEFT),
			_key(InputBindings.MOVE_BACK), _key(InputBindings.MOVE_RIGHT)]), "Move"],
		["%s / %s" % [_key(InputBindings.ASCEND), descend], "Fly up / down"],
		["%s %s" % [descend, descend], "Dive to ground"],
		["LMB", "Light"],
		["RMB", "Heavy"],
		[_key(&"fighter_block"), "Block"],
		[_key(&"fighter_dash"), "Dash"],
		[_key(&"fighter_ki_blast"), "Ki blast"],
		[_key(&"fighter_lock_toggle"), "Lock on"],
		[_key(InputBindings.TOGGLE_HINTS), "Hide"],
	]


## Gamepad pairs from the InputMap's joypad events; one notice while none are bound.
static func gamepad_entries() -> Array:
	var actions := [
		[InputBindings.ASCEND, "Fly up"], [InputBindings.DESCEND, "Fly down"],
		[&"fighter_light", "Light"], [&"fighter_heavy", "Heavy"], [&"fighter_block", "Block"],
		[&"fighter_dash", "Dash"], [&"fighter_ki_blast", "Ki blast"], [&"fighter_lock_toggle", "Lock on"],
	]
	var entries := []
	for pair: Array in actions:
		var label := joypad_label(pair[0])
		if label != "":
			entries.append([label, pair[1]])
	if entries.is_empty():
		return [["PAD", GAMEPAD_UNBOUND]]
	return entries


## Short name of the first joypad button bound to action, or "".
static func joypad_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	const NAMES := {
		JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
		JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
		JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
	}
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return NAMES.get(event.button_index, "B%d" % event.button_index)
		if event is InputEventJoypadMotion:
			return "LT" if event.axis == JOY_AXIS_TRIGGER_LEFT else ("RT" if event.axis == JOY_AXIS_TRIGGER_RIGHT else "Stick")
	return ""


static func _key(action: StringName) -> String:
	return ControlSettings.key_label(action).to_upper()
