class_name ZoneSelect
extends MenuScreen
## Pick one of the seven zones: a big preview of the focused zone with its
## landmarks, a card grid, rounds, and FIGHT!. Heartbloom Gardens gets
## drifting hearts, a rose glow and a ribbon.

signal fight_requested

const ROUND_CHOICES: Array[int] = [1, 3, 5]
## Zone card name size and the smallest it shrinks to for long names.
const CARD_NAME_SIZE := 24
const CARD_NAME_MIN := 16

var zone_ids: Array[StringName] = []
var selected: StringName = &""
var rounds := 3
var cards: Dictionary = {}

var _preview_art: TextureRect
var _preview_name: Label
var _preview_tag: Label
var _preview_marks: Label
var _rose_glow: ColorRect
var _hearts: HeartDrift
var _ribbon: Label
var _rounds_button: Button
var _fight_button: Button


func _ready() -> void:
	zone_ids = ZoneCatalog.ids()
	var shade := ColorRect.new()
	shade.color = Color(MenuTheme.INK, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var head := MenuScreen.heading("Choose your zone")
	head.position = Vector2(80, 40)
	add_child(head)

	# Big preview.
	var frame := PanelContainer.new()
	var frame_style := MenuTheme.box(MenuTheme.INK, MenuTheme.INK, 8, false, 0.0)
	frame_style.set_content_margin_all(8)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.position = Vector2(80, 200)
	frame.size = Vector2(1060, 620)
	add_child(frame)
	var art_holder := Control.new()
	art_holder.clip_contents = true
	frame.add_child(art_holder)
	_preview_art = TextureRect.new()
	_preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art_holder.add_child(_preview_art)
	_rose_glow = ColorRect.new()
	_rose_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rose_glow.color = Color(MenuTheme.ROSE, 0.0)
	_rose_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_holder.add_child(_rose_glow)
	var fade := TextureRect.new()
	fade.texture = _bottom_fade()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_holder.add_child(fade)
	_hearts = HeartDrift.new()
	_hearts.set_anchors_preset(Control.PRESET_FULL_RECT)
	art_holder.add_child(_hearts)
	var text_box := VBoxContainer.new()
	text_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	text_box.offset_left = 36
	text_box.offset_right = 1000
	text_box.offset_top = -210
	text_box.offset_bottom = -20
	text_box.add_theme_constant_override("separation", 0)
	art_holder.add_child(text_box)
	_preview_name = MenuTheme.label("", 80, MenuTheme.TEXT, 16)
	text_box.add_child(_preview_name)
	_preview_tag = MenuTheme.label("", 32, MenuTheme.GOLD, 8)
	text_box.add_child(_preview_tag)
	_preview_marks = MenuTheme.label("", 22, MenuTheme.TEXT_DIM, 6)
	_preview_marks.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_preview_marks.clip_text = true
	text_box.add_child(_preview_marks)
	_ribbon = MenuTheme.label("  ♥  ROMANTIC GETAWAY  ♥  ", 30, MenuTheme.TEXT, 8)
	_ribbon.add_theme_stylebox_override("normal", MenuTheme.box(MenuTheme.ROSE, MenuTheme.INK, 5))
	_ribbon.position = Vector2(560, 26)
	art_holder.add_child(_ribbon)

	# Card grid.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(1180, 200)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	add_child(grid)
	for id in zone_ids:
		grid.add_child(_zone_card(id))
	var random := make_button("Random", pick_random, 30)
	random.custom_minimum_size = Vector2(320, 140)
	random.alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid.add_child(random)

	_rounds_button = make_button("", cycle_rounds, 34)
	_rounds_button.position = Vector2(80, 860)
	_rounds_button.custom_minimum_size = Vector2(420, 72)
	_rounds_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_rounds_button)
	_fight_button = make_button("Fight!", _fight, 64)
	_fight_button.position = Vector2(1460, 930)
	_fight_button.custom_minimum_size = Vector2(400, 110)
	_fight_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fight_button.add_theme_stylebox_override("normal", MenuTheme.box(MenuTheme.HOT, MenuTheme.INK, 7))
	add_child(_fight_button)
	var hints := MenuScreen.key_hints([["Arrows", "Browse"], ["Enter", "Pick"], ["Esc", "Back"]])
	hints.position = Vector2(80, 1000)
	add_child(hints)
	select_zone(zone_ids[0])


func enter() -> void:
	select_zone(selected if not selected.is_empty() else zone_ids[0])


func first_focus() -> Control:
	return cards.get(selected, _fight_button)


func select_zone(id: StringName) -> void:
	if not zone_ids.has(id):
		return
	selected = id
	_preview_art.texture = ZoneCatalog.art(id)
	_preview_name.text = ZoneCatalog.display_name(id).to_upper()
	_preview_tag.text = ZoneCatalog.tagline(id)
	var data := ZoneCatalog.zone(id)
	_preview_marks.text = "LANDMARKS:  " + "  ·  ".join(data.landmark_names).to_upper() if data != null and not data.landmark_names.is_empty() else ""
	var romantic := is_romantic()
	_hearts.active = romantic
	_ribbon.visible = romantic
	_rose_glow.color = Color(MenuTheme.ROSE, 0.16 if romantic else 0.0)
	_preview_tag.add_theme_color_override("font_color", MenuTheme.ROSE.lightened(0.25) if romantic else MenuTheme.GOLD)
	for zone_id: StringName in cards:
		var card: Button = cards[zone_id]
		var on := zone_id == id
		var rose := zone_id == ZoneCatalog.ROMANTIC_ZONE
		card.add_theme_stylebox_override("normal", MenuTheme.box(Color(0, 0, 0, 0),
			(MenuTheme.ROSE if rose else MenuTheme.GOLD) if on else MenuTheme.INK, 8 if on else 4, false, 0.0))
	_rounds_button.text = "BEST OF %d" % rounds if rounds > 1 else "ONE ROUND"


## True while the romantic zone is picked.
func is_romantic() -> bool:
	return selected == ZoneCatalog.ROMANTIC_ZONE


func cycle_rounds() -> void:
	rounds = ROUND_CHOICES[(ROUND_CHOICES.find(rounds) + 1) % ROUND_CHOICES.size()]
	select_zone(selected)


func pick_random() -> void:
	select_zone(zone_ids[randi() % zone_ids.size()])


func _fight() -> void:
	fight_requested.emit()


## Largest card-name font size (CARD_NAME_SIZE down to CARD_NAME_MIN) whose text, outline included, fits width.
static func fitted_font_size(label: Label, width: float) -> int:
	var font := label.get_theme_font(&"font")
	var outline := label.get_theme_constant(&"outline_size")
	for size in range(CARD_NAME_SIZE, CARD_NAME_MIN - 1, -1):
		if font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + outline <= width:
			return size
	return CARD_NAME_MIN


func _zone_card(id: StringName) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(320, 140)
	card.focus_mode = Control.FOCUS_ALL
	card.clip_contents = true
	var art := TextureRect.new()
	art.texture = ZoneCatalog.art(id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 4
	art.offset_top = 4
	art.offset_right = -4
	art.offset_bottom = -4
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.show_behind_parent = true
	card.add_child(art)
	var fade := TextureRect.new()
	fade.texture = _bottom_fade()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.show_behind_parent = true
	card.add_child(fade)
	var name_label := MenuTheme.label(ZoneCatalog.display_name(id).to_upper(), CARD_NAME_SIZE, MenuTheme.TEXT, 8)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_left = 14
	name_label.offset_right = -10
	name_label.offset_top = -44
	name_label.offset_bottom = -6
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_label)
	# Long names (HEARTBLOOM GARDENS) shrink to fit the card instead of trailing off.
	var fit := func() -> void:
		name_label.add_theme_font_size_override("font_size", fitted_font_size(name_label, name_label.size.x))
	name_label.resized.connect(fit)
	visibility_changed.connect(fit)
	if id == ZoneCatalog.ROMANTIC_ZONE:
		name_label.add_theme_color_override("font_color", MenuTheme.ROSE.lightened(0.35))
		var heart := HeartDrift.new()
		heart.active = true
		heart.count = 6
		heart.set_anchors_preset(Control.PRESET_FULL_RECT)
		card.add_child(heart)
	card.pressed.connect(func() -> void:
		play_cue(&"confirm")
		select_zone(id))
	card.focus_entered.connect(func() -> void:
		play_cue(&"move")
		select_zone(id))
	card.mouse_entered.connect(card.grab_focus)
	cards[id] = card
	return card


static func _bottom_fade() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(MenuTheme.INK, 0.0))
	gradient.set_color(1, Color(MenuTheme.INK, 0.85))
	gradient.add_point(0.55, Color(MenuTheme.INK, 0.05))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = 128
	return texture
