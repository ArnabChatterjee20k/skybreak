class_name BeamClashPrompt
extends Control
## Beam clash rhythm prompts (GAME_DESIGN §5.8): the coming beats scroll right
## to left onto a hit line, each a key letter (Q/E/F/R) in a circle, over a
## push bar that shows who is winning. Reads a BeamClash; draws nothing without one.

const LANE_SIZE := Vector2(520, 64)
## Seconds of beats visible ahead of the hit line.
const LOOKAHEAD_TICKS := 80
const KEY_LETTERS := {
	FighterInput.Action.KI_BLAST: "Q", FighterInput.Action.BLOCK: "E",
	FighterInput.Action.GRAB: "F", FighterInput.Action.CHARGE: "R",
}
const KEY_COLORS := {
	FighterInput.Action.KI_BLAST: Color(1.0, 0.75, 0.3), FighterInput.Action.BLOCK: Color(0.45, 0.8, 1.0),
	FighterInput.Action.GRAB: Color(0.6, 1.0, 0.55), FighterInput.Action.CHARGE: Color(1.0, 0.5, 0.85),
}

var _clash: BeamClash
var _tick: int = 0
var _side: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows clash (or hides with null) as seen by fighter 0 at the sim's current tick.
func show_clash(sim: CombatSim, clash: BeamClash) -> void:
	_clash = clash
	_tick = sim.current_tick
	_side = maxi(clash.side_of(0), 0) if clash != null else 0
	visible = clash != null
	queue_redraw()


## The key bound to a beat's action (rebindable), else the default letter.
static func letter_for(button: int) -> String:
	var action: StringName = InputBindings.FIGHTER_ACTIONS.get(button, &"")
	if action != &"" and InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key != null:
				return OS.get_keycode_string(key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)
	return KEY_LETTERS.get(button, "?")


## The beats still to come as [ticks until the beat, letter], for tests.
func upcoming() -> Array:
	var out: Array = []
	if _clash == null:
		return out
	for k in _clash.beat_ticks.size():
		var until := _clash.beat_ticks[k] - _tick
		if until >= -4 and until <= LOOKAHEAD_TICKS:
			out.append([until, letter_for(_clash.beat_buttons[k])])
	return out


func _draw() -> void:
	if _clash == null:
		return
	var view := get_viewport_rect().size
	var origin := Vector2((view.x - LANE_SIZE.x) * 0.5, view.y * 0.76)
	var lane := Rect2(origin, LANE_SIZE)
	draw_rect(lane, Color(0.05, 0.06, 0.1, 0.72))
	var hit_x := origin.x + 70.0
	draw_line(Vector2(hit_x, origin.y - 6), Vector2(hit_x, origin.y + LANE_SIZE.y + 6), Color.WHITE, 4.0)
	var font := get_theme_default_font()
	var span := LANE_SIZE.x - 90.0
	for k in _clash.beat_ticks.size():
		var until := _clash.beat_ticks[k] - _tick
		if until < -6 or until > LOOKAHEAD_TICKS:
			continue
		var x := hit_x + span * float(until) / LOOKAHEAD_TICKS
		var centre := Vector2(x, origin.y + LANE_SIZE.y * 0.5)
		var button := _clash.beat_buttons[k]
		var done := (_clash.judged[_side] & (1 << k)) != 0
		var color: Color = KEY_COLORS.get(button, Color.WHITE)
		if done:
			color = color.darkened(0.6)
		draw_circle(centre, 24.0, color)
		draw_arc(centre, 24.0, 0.0, TAU, 32, Color.WHITE, 3.0)
		var letter := letter_for(button)
		draw_string(font, centre + Vector2(-24, 11), letter, HORIZONTAL_ALIGNMENT_CENTER, 48, 30 if letter.length() == 1 else 16,
			Color(0.05, 0.05, 0.08))
	# Push bar: your side fills from the left.
	var bar := Rect2(origin + Vector2(0, LANE_SIZE.y + 12), Vector2(LANE_SIZE.x, 14))
	draw_rect(bar, Color(0.2, 0.2, 0.25, 0.8))
	var mine := float(_clash.push if _side == 0 else -_clash.push)
	var share := clampf(0.5 + mine / 200.0, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), Color(1.0, 0.7, 0.3))
	draw_line(bar.position + Vector2(bar.size.x * 0.5, -3), bar.position + Vector2(bar.size.x * 0.5, 17),
		Color.WHITE, 2.0)
	draw_rect(Rect2(origin + Vector2(0, -34), Vector2(LANE_SIZE.x, 30)), Color(0.05, 0.06, 0.1, 0.72))
	draw_string(font, origin + Vector2(10, -11), "BEAM CLASH: hit the keys on the line", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 22, Color(1.0, 0.9, 0.6))
