class_name MenuTheme
extends RefCounted
## The front end's look: chunky slanted panels, heavy italic type with thick
## ink outlines, gold and hot-orange accents on deep indigo.

const INK := Color(0.05, 0.04, 0.12)
const PANEL := Color(0.11, 0.1, 0.27, 0.94)
const PANEL_LIGHT := Color(0.2, 0.19, 0.45, 0.96)
const GOLD := Color(1.0, 0.8, 0.14)
const HOT := Color(1.0, 0.42, 0.16)
const CYAN := Color(0.25, 0.86, 1.0)
const ROSE := Color(1.0, 0.45, 0.68)
const TEXT := Color(1, 1, 1)
const TEXT_DIM := Color(0.72, 0.74, 0.9)
const DISABLED := Color(0.45, 0.45, 0.58)
## Team colours by team index.
const TEAM_COLORS: Array[Color] = [
	Color(1.0, 0.5, 0.15), Color(0.25, 0.75, 1.0), Color(0.45, 0.95, 0.35), Color(0.95, 0.35, 0.85),
]
const SKEW := 0.18
const OUTLINE := 10
## Seconds for a screen transition (GAME_DESIGN §11: 0.3 s max).
const TRANSITION := 0.22

static var _theme: Theme
static var _fonts: Dictionary = {}


## Heavy display face: Arial Black / Impact on Windows, a black weight elsewhere.
static func font(italic := true) -> Font:
	if _fonts.has(italic):
		return _fonts[italic]
	var base := SystemFont.new()
	base.font_names = PackedStringArray(["Arial Black", "Impact", "Segoe UI Black", "Inter Black", "Inter", "DejaVu Sans"])
	base.font_weight = 900
	base.font_stretch = 100
	var face := FontVariation.new()
	face.base_font = base
	if italic:
		face.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.16, 1), Vector2.ZERO)
	face.spacing_glyph = 1
	_fonts[italic] = face
	return face


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 30
	for type in ["Label", "Button", "CheckBox", "OptionButton", "LineEdit"]:
		t.set_color("font_color", type, TEXT)
		t.set_color("font_outline_color", type, INK)
		t.set_constant("outline_size", type, OUTLINE)
	t.set_stylebox("normal", "Button", box(PANEL, INK, 5))
	t.set_stylebox("hover", "Button", box(GOLD, INK, 5))
	t.set_stylebox("pressed", "Button", box(HOT, INK, 5))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD, 5, true))
	t.set_stylebox("disabled", "Button", box(Color(0.12, 0.12, 0.2, 0.8), INK, 5))
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", DISABLED)
	t.set_color("font_hover_pressed_color", "Button", INK)
	t.set_constant("outline_size", "Button", 8)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, INK, 6))
	t.set_stylebox("panel", "Panel", box(PANEL, INK, 6))
	# Sliders: a thick track and a chunky gold grabber.
	var track := box(INK, INK, 0, false, 0.0)
	track.content_margin_top = 10
	track.content_margin_bottom = 10
	var fill := box(GOLD, INK, 0, false, 0.0)
	fill.content_margin_top = 10
	fill.content_margin_bottom = 10
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", box(HOT, INK, 0, false, 0.0))
	t.set_icon("grabber", "HSlider", _grabber(GOLD))
	t.set_icon("grabber_highlight", "HSlider", _grabber(TEXT))
	t.set_stylebox("normal", "OptionButton", box(PANEL_LIGHT, INK, 4))
	t.set_stylebox("hover", "OptionButton", box(GOLD, INK, 4))
	t.set_stylebox("focus", "OptionButton", box(Color(0, 0, 0, 0), GOLD, 4, true))
	t.set_color("font_hover_color", "OptionButton", INK)
	t.set_stylebox("panel", "PopupMenu", box(PANEL, INK, 4, false, 0.0))
	t.set_font("font", "PopupMenu", font(false))
	t.set_font_size("font_size", "PopupMenu", 26)
	t.set_stylebox("panel", "TooltipPanel", box(INK, GOLD, 3, false, 0.0))
	var scroll := StyleBoxFlat.new()
	scroll.bg_color = Color(INK, 0.5)
	scroll.content_margin_left = 6
	scroll.content_margin_right = 6
	t.set_stylebox("scroll", "VScrollBar", scroll)
	var grab := StyleBoxFlat.new()
	grab.bg_color = GOLD
	grab.content_margin_left = 6
	grab.content_margin_right = 6
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	_theme = t
	return t


## A slanted panel style with a thick ink border.
static func box(fill: Color, border: Color, border_width: int, draw_center_off := false, skew := SKEW) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.draw_center = not draw_center_off
	s.border_color = border
	s.set_border_width_all(border_width)
	s.skew = Vector2(skew, 0)
	s.set_corner_radius_all(4)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s


static func label(text: String, size: int, color := TEXT, outline := OUTLINE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", INK)
	return l


## A big menu button.
static func button(text: String, size := 40) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


## Colour for team `index`.
static func team_color(index: int) -> Color:
	return TEAM_COLORS[posmod(index, TEAM_COLORS.size())]


## Scales a 1920x1080 design control to fit `view`, centred, keeping the aspect.
static func fit(control: Control, view: Vector2) -> void:
	var factor := minf(view.x / 1920.0, view.y / 1080.0)
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.scale = Vector2(factor, factor)
	control.size = Vector2(1920, 1080)
	control.position = (view - Vector2(1920, 1080) * factor) / 2.0


## A soft radial glow in `color`, for the backs of character stages.
static func glow(color: Color) -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color, 0.85))
	gradient.set_color(1, Color(color, 0.0))
	gradient.add_point(0.45, Color(color, 0.35))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.55)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 256
	texture.height = 256
	return texture


static func _grabber(color: Color) -> Texture2D:
	var image := Image.create(30, 40, false, Image.FORMAT_RGBA8)
	image.fill(INK)
	image.fill_rect(Rect2i(5, 5, 20, 30), color)
	return ImageTexture.create_from_image(image)
