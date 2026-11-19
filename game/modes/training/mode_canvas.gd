class_name ModeCanvas
extends Control
## Base for the training and tutorial overlays: draws in the match HUD's
## 1920x1080 design space with its colours, outlined text and key caps.
## Text in [brackets] draws as a key cap, e.g. "Press [Shift] + [E]".

const DESIGN := MatchHud.DESIGN
const INK := MatchHud.INK
const PANEL := MatchHud.PANEL
const ACCENT := MatchHud.BANNER
const KI := MatchHud.KI
const GOOD := Color(0.45, 0.95, 0.5)
const BAD := Color(0.95, 0.35, 0.3)
const DIM := Color(0.75, 0.77, 0.82)
const KEY_FILL := Color(0.92, 0.92, 0.88)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_set_transform(MatchHud.design_offset(size), 0.0, Vector2.ONE * MatchHud.design_scale(size))
	_draw_design()
	draw_set_transform(Vector2.ZERO)


## Override: draw in design space.
func _draw_design() -> void:
	pass


func _panel(rect: Rect2, accent: Color = ACCENT) -> void:
	draw_rect(rect, PANEL)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5)), accent)


func _text(at: Vector2, text: String, font_size: int, color: Color = Color.WHITE,
		align := HORIZONTAL_ALIGNMENT_LEFT, outline := 6) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := at.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= width / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= width
	if outline > 0:
		draw_string_outline(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, INK)
	draw_string(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Width of a line with key caps, as _rich_text draws it.
static func rich_width(text: String, font_size: int) -> float:
	var font := ThemeDB.fallback_font
	var width := 0.0
	for part in split_keys(text):
		width += font.get_string_size(part.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if part.key:
			width += font_size * 0.6
	return width


## Draws text with [Key] parts as key caps; at is the left end of the baseline.
func _rich_text(at: Vector2, text: String, font_size: int, color: Color = Color.WHITE) -> void:
	var font := ThemeDB.fallback_font
	var x := at.x
	for part in split_keys(text):
		var width := font.get_string_size(part.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if part.key:
			var pad := font_size * 0.3
			var cap := Rect2(x, at.y - font_size * 0.95, width + pad * 2.0, font_size * 1.25)
			draw_rect(cap, KEY_FILL)
			draw_rect(Rect2(cap.position + Vector2(0, cap.size.y - 4), Vector2(cap.size.x, 4)), Color(0.55, 0.55, 0.6))
			draw_string(font, Vector2(x + pad, at.y), part.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
			x += width + pad * 2.0
		else:
			_text(Vector2(x, at.y), part.text, font_size, color)
			x += width


## Splits "Press [E] now" into [{text, key}] parts.
static func split_keys(text: String) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	var rest := text
	while rest != "":
		var open := rest.find("[")
		var close := rest.find("]", open)
		if open < 0 or close < 0:
			parts.append({"text": rest, "key": false})
			break
		if open > 0:
			parts.append({"text": rest.substr(0, open), "key": false})
		parts.append({"text": rest.substr(open + 1, close - open - 1), "key": true})
		rest = rest.substr(close + 1)
	return parts
