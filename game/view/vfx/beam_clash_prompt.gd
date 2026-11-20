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
	# Drawn in MatchHud's 1920x1080 design space, styled like the HUD (T-UI1).
	var view := get_viewport_rect().size
	var scale_factor := MatchHud.design_scale(view)
	var design := view / scale_factor
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)
	var origin := Vector2((design.x - LANE_SIZE.x) * 0.5, design.y * 0.76)
	var lane := Rect2(origin, LANE_SIZE)
	var font := MenuTheme.font()
	# Header chip: gold title.
	var header := Rect2(origin + Vector2(0, -48), Vector2(LANE_SIZE.x, 40))
	draw_style_box(MenuTheme.box(Color(MenuTheme.PANEL, 0.92), MenuTheme.GOLD, 3), header)
	_text(font, header.position + Vector2(24, 30), "BEAM CLASH!", 26, MenuTheme.GOLD, 8)
	_text(MenuTheme.font(false), header.position + Vector2(LANE_SIZE.x - 24, 28), "hit the keys on the line", 18,
		MenuTheme.TEXT, 5, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_style_box(MenuTheme.box(Color(MenuTheme.PANEL, 0.9), MenuTheme.INK, 4), lane)
	var hit_x := origin.x + 70.0
	var lean := MenuTheme.SKEW * (LANE_SIZE.y + 12.0) * 0.5
	draw_line(Vector2(hit_x + lean, origin.y - 6), Vector2(hit_x - lean, origin.y + LANE_SIZE.y + 6), MenuTheme.INK, 10.0, true)
	draw_line(Vector2(hit_x + lean, origin.y - 6), Vector2(hit_x - lean, origin.y + LANE_SIZE.y + 6), MenuTheme.GOLD, 5.0, true)
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
		draw_circle(centre, 25.0, MenuTheme.INK)
		draw_circle(centre, 21.0, color)
		var letter := letter_for(button)
		var letter_size := 30 if letter.length() == 1 else 15
		_text(font, centre + Vector2(1, letter_size * 0.36), letter, letter_size, MenuTheme.INK, 0, HORIZONTAL_ALIGNMENT_CENTER)
	# Push bar: your side (gold) fills from the left against the rival (hot).
	var bar := Rect2(origin + Vector2(0, LANE_SIZE.y + 14), Vector2(LANE_SIZE.x, 16))
	var mine := float(_clash.push if _side == 0 else -_clash.push)
	var share := clampf(0.5 + mine / 200.0, 0.0, 1.0)
	_slant(bar.grow(2.0), MenuTheme.INK)
	_slant(bar, MenuTheme.HOT)
	_slant(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), MenuTheme.GOLD)
	var mid := bar.position + Vector2(bar.size.x * 0.5, 0)
	draw_line(mid + Vector2(2, -4), mid + Vector2(-2, bar.size.y + 4), MenuTheme.TEXT, 3.0, true)
	draw_set_transform(Vector2.ZERO)


func _slant(rect: Rect2, color: Color) -> void:
	draw_colored_polygon(MatchHud.slant_points(rect), color)


func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color, outline: int,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := at.x - (width / 2.0 if align == HORIZONTAL_ALIGNMENT_CENTER else (width if align == HORIZONTAL_ALIGNMENT_RIGHT else 0.0))
	if outline > 0:
		draw_string_outline(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, MenuTheme.INK)
	draw_string(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
