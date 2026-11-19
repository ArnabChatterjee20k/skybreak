class_name ComboCounter
extends Label
## "5 HITS" while a fighter is being comboed (2+ hits); the last count stays
## up for HOLD_SECONDS after the combo ends.

const HOLD_SECONDS := 1.0
const COLOR := Color(1.0, 0.85, 0.25)

var _hold := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	offset_left = -320.0
	offset_right = -48.0
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_theme_font_size_override("font_size", 48)
	add_theme_color_override("font_color", COLOR)
	add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	add_theme_constant_override("outline_size", 10)
	visible = false


## Call every frame with the sim's fighters.
func show_combo(fighters: Array, delta: float) -> void:
	var hits := 0
	for fighter: FighterState in fighters:
		hits = maxi(hits, fighter.combo_hits)
	var label := text_for(hits)
	if label != "":
		text = label
		_hold = HOLD_SECONDS
	else:
		_hold = maxf(_hold - delta, 0.0)
	visible = _hold > 0.0


## The counter's text for a hit count; empty below 2 hits.
static func text_for(hits: int) -> String:
	return "%d HITS" % hits if hits >= 2 else ""
