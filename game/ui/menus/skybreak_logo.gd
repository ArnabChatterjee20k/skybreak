class_name SkybreakLogo
extends Control
## The game's wordmark: a slanted gold "SKYBREAK" with a hot-orange crack
## slash behind it and a small "ARENA OF LEGENDS" strap.

var logo_scale := 1.0


func _init(scale_factor := 1.0) -> void:
	logo_scale = scale_factor
	custom_minimum_size = Vector2(1100, 330) * logo_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := logo_scale
	var w := size.x
	# Lightning slash behind the word.
	var slash := PackedVector2Array([
		Vector2(w * 0.08, 210 * s), Vector2(w * 0.55, 120 * s), Vector2(w * 0.5, 165 * s),
		Vector2(w * 0.95, 70 * s), Vector2(w * 0.45, 215 * s), Vector2(w * 0.5, 175 * s)])
	draw_colored_polygon(slash, MenuTheme.HOT)
	draw_polyline(slash + PackedVector2Array([slash[0]]), MenuTheme.INK, 6 * s)
	var font := MenuTheme.font()
	var size_px := int(210 * s)
	var text := "SKYBREAK"
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var origin := Vector2((w - text_w) / 2, 235 * s)
	draw_string_outline(font, origin + Vector2(10, 12) * s, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, int(34 * s), MenuTheme.INK)
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, int(30 * s), MenuTheme.INK)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, MenuTheme.GOLD)
	# Light top half for a two-tone metal look.
	draw_string(font, origin - Vector2(0, 3) * s, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(1, 0.95, 0.7, 0.35))
	var strap := "ARENA OF LEGENDS"
	var strap_px := int(44 * s)
	var strap_w := font.get_string_size(strap, HORIZONTAL_ALIGNMENT_LEFT, -1, strap_px).x
	var strap_rect := Rect2(Vector2((w - strap_w) / 2 - 30 * s, 258 * s), Vector2(strap_w + 60 * s, 58 * s))
	draw_rect(strap_rect, MenuTheme.INK)
	draw_rect(strap_rect.grow(-5 * s), MenuTheme.CYAN)
	draw_string(font, Vector2(strap_rect.position.x + 30 * s, 303 * s), strap, HORIZONTAL_ALIGNMENT_LEFT, -1, strap_px, MenuTheme.INK)
