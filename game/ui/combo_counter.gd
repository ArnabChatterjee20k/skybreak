class_name ComboCounter
extends Label
## "5 HITS" when a hit lands in a combo (2+ hits). It holds HOLD_SECONDS after
## the last landed hit, then fades out over FADE_SECONDS; it never counts down
## (issue #80: it lingered through long knockback flights and, in FFA, dropped
## from "3 HITS" to another fighter's "2 HITS").

const HOLD_SECONDS := 0.5
const FADE_SECONDS := 0.25
const COLOR := MenuTheme.GOLD
## Each new count scales in from POP to 1 over POP_SECONDS (as the banners do).
const POP := 1.3
const POP_SECONDS := 0.12

var _hold := 0.0
var _fade := 0.0
var _shown := 0
var _last_hits: Array[int] = []
var _pop_age := POP_SECONDS


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	offset_left = -320.0
	offset_right = -48.0
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	offset_top = -34.0
	offset_bottom = 34.0
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_theme_font_override("font", MenuTheme.font())
	add_theme_font_size_override("font_size", 44)
	add_theme_color_override("font_color", COLOR)
	add_theme_color_override("font_outline_color", MenuTheme.INK)
	add_theme_constant_override("outline_size", 12)
	var chip := MenuTheme.box(Color(MenuTheme.PANEL, 0.88), MenuTheme.INK, 4)
	chip.content_margin_top = 2
	chip.content_margin_bottom = 2
	add_theme_stylebox_override("normal", chip)
	visible = false


## Call every frame with the sim's fighters.
func show_combo(fighters: Array, delta: float) -> void:
	_last_hits.resize(fighters.size())
	var landed := 0
	for i in fighters.size():
		var hits: int = (fighters[i] as FighterState).combo_hits
		if hits > _last_hits[i] and hits >= 2:
			landed = maxi(landed, hits)
		_last_hits[i] = hits
	if landed > 0 and (landed >= _shown or _hold <= 0.0):
		_shown = landed
		text = text_for(landed)
		_hold = HOLD_SECONDS
		_fade = FADE_SECONDS
		_pop_age = 0.0
	elif _hold > 0.0:
		_hold = maxf(_hold - delta, 0.0)
	else:
		_fade = maxf(_fade - delta, 0.0)
		if _fade <= 0.0:
			_shown = 0
	modulate.a = 1.0 if _hold > 0.0 else _fade / FADE_SECONDS
	_pop_age = minf(_pop_age + delta, POP_SECONDS)
	# Scaled with the window like MatchHud, anchored at its right edge.
	pivot_offset = size * Vector2(1.0, 0.5)
	var pop := lerpf(POP, 1.0, 1.0 - pow(1.0 - _pop_age / POP_SECONDS, 3.0))
	var view := get_viewport_rect().size if is_inside_tree() else MatchHud.DESIGN
	scale = Vector2.ONE * pop * MatchHud.design_scale(view)
	visible = _hold > 0.0 or _fade > 0.0


## The counter's text for a hit count; empty below 2 hits.
static func text_for(hits: int) -> String:
	return "%d HITS" % hits if hits >= 2 else ""
