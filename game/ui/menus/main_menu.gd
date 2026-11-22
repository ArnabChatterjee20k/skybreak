class_name MainMenu
extends MenuScreen
## Title menu: Play (Vs AI), Free-for-All, Duo (online), Training, Settings, Quit,
## with a blurb panel that follows the focused entry.

signal mode_chosen(mode: StringName)
signal quit_requested

## Online lobby scenes the Duo entry opens once a net lane adds one.
const LOBBY_SCENES: Array[String] = ["res://game/net/lobby.tscn", "res://game/net/duo_lobby.tscn"]
const ENTRIES := [
	{"id": &"vs_ai", "text": "Play", "tag": "VS AI", "blurb": "Fight 1 to 3 AI legends. One AI is a classic duel; more is an all-out brawl."},
	{"id": &"pure_fight", "text": "Pure Fight", "tag": "1V1", "blurb": "Hand to hand, side-on, on a platform in any zone. No ki, no flight: just martial arts. Vs AI or a friend on the same keyboard."},
	{"id": &"ffa", "text": "Free-for-All", "tag": "2-4", "blurb": "Every legend for themselves. Set each seat to human or AI, pick levels and teams."},
	{"id": &"duo", "text": "Duo", "tag": "ONLINE", "blurb": "You and a partner against AI legends, each on your own device."},
	{"id": &"training", "text": "Training", "tag": "", "blurb": "A quiet sky and a patient dummy. Practise strings, vanishes and weapons."},
	{"id": &"settings", "text": "Settings", "tag": "", "blurb": "Audio, graphics, camera sensitivity and key bindings."},
	{"id": &"quit", "text": "Quit", "tag": "", "blurb": "Leave the arena. The sky will be here when you get back."},
]

var buttons: Dictionary = {}
var _blurb: Label
var _blurb_title: Label
var _toast: Label


func _ready() -> void:
	var shade := TextureRect.new()
	shade.texture = _side_gradient()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var logo := SkybreakLogo.new(0.62)
	logo.position = Vector2(60, 50)
	add_child(logo)

	var column := VBoxContainer.new()
	column.position = Vector2(120, 330)
	column.custom_minimum_size = Vector2(620, 0)
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	for entry: Dictionary in entries():
		var b := make_button(entry.text, _choose.bind(entry.id), 50)
		b.custom_minimum_size = Vector2(560 - column.get_child_count() * 14, 86)
		b.focus_entered.connect(_show_blurb.bind(entry))
		if entry.id == &"duo" and not duo_available():
			b.add_theme_color_override("font_color", MenuTheme.DISABLED)
			b.tooltip_text = "Coming soon"
		column.add_child(b)
		if not String(entry.tag).is_empty():
			var tag := _tag(entry.tag if entry.id != &"duo" or duo_available() else "COMING SOON", entry.id == &"duo")
			b.add_child(tag)
		buttons[entry.id] = b

	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", MenuTheme.box(Color(MenuTheme.PANEL, 0.85), MenuTheme.INK, 6))
	info.position = Vector2(1180, 700)
	info.custom_minimum_size = Vector2(640, 220)
	add_child(info)
	var info_rows := VBoxContainer.new()
	info.add_child(info_rows)
	_blurb_title = MenuTheme.label("", 44, MenuTheme.GOLD, 10)
	info_rows.add_child(_blurb_title)
	_blurb = MenuTheme.label("", 28, MenuTheme.TEXT, 6)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(580, 0)
	info_rows.add_child(_blurb)

	_toast = MenuTheme.label("", 34, MenuTheme.INK, 0)
	_toast.position = Vector2(760, 560)
	_toast.visible = false
	add_child(_toast)

	var hints := MenuScreen.key_hints([["W/S", "Navigate"], ["Enter", "Select"], ["Esc", "Back"]])
	hints.position = Vector2(120, 1000)
	add_child(hints)
	var version := MenuTheme.label("T-128 BUILD  ·  GODOT 4.7", 20, MenuTheme.TEXT_DIM, 4)
	version.position = Vector2(1560, 1020)
	add_child(version)


func enter() -> void:
	_toast.visible = false
	var column := buttons[&"vs_ai"].get_parent() as Control
	for i in column.get_child_count():
		var b := column.get_child(i) as Control
		b.modulate.a = 0.0
		var tween := b.create_tween()
		tween.tween_interval(0.03 * i)
		tween.tween_property(b, "modulate:a", 1.0, 0.12)


func first_focus() -> Control:
	return buttons[&"vs_ai"]


func go_back() -> void:
	pass  # Nothing behind the title menu.


## The menu entries; the web build has no Quit (closing the tab does that).
static func entries(is_web: bool = OS.has_feature("web")) -> Array:
	return ENTRIES.filter(func(entry: Dictionary) -> bool: return not (is_web and entry.id == &"quit"))


## True once an online lobby scene exists.
static func duo_available() -> bool:
	for path in LOBBY_SCENES:
		if ResourceLoader.exists(path):
			return true
	return false


func _choose(id: StringName) -> void:
	match id:
		&"vs_ai", &"ffa", &"training", &"pure_fight":
			mode_chosen.emit(id)
			navigate.emit(&"character_select")
		&"duo":
			if duo_available():
				mode_chosen.emit(id)
				navigate.emit(&"duo_lobby")
			else:
				show_toast("DUO IS COMING SOON - ONLINE PLAY IS STILL BEING BUILT")
		&"settings":
			navigate.emit(&"settings")
		&"quit":
			quit_requested.emit()


func show_toast(text: String) -> void:
	_toast.text = "  %s  " % text
	var style := MenuTheme.box(MenuTheme.GOLD, MenuTheme.INK, 5)
	_toast.add_theme_stylebox_override("normal", style)
	_toast.visible = true
	_toast.modulate.a = 1.0
	var tween := _toast.create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.3)


func _show_blurb(entry: Dictionary) -> void:
	play_cue(&"move")
	_blurb_title.text = String(entry.text).to_upper()
	_blurb.text = entry.blurb
	if entry.id == &"duo" and not duo_available():
		_blurb.text += "  Coming soon."


func _tag(text: String, muted: bool) -> Control:
	var chip := Label.new()
	chip.text = " %s " % text
	chip.add_theme_font_size_override("font_size", 22)
	chip.add_theme_color_override("font_color", MenuTheme.INK)
	chip.add_theme_constant_override("outline_size", 0)
	chip.add_theme_stylebox_override("normal", MenuTheme.box(MenuTheme.TEXT_DIM if muted else MenuTheme.CYAN, MenuTheme.INK, 3))
	chip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	chip.offset_left = -230 if muted else -150
	chip.offset_right = -18
	chip.offset_top = -22
	chip.offset_bottom = 22
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chip


## Dark on the left (menu column), clear on the right (backdrop).
static func _side_gradient() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(MenuTheme.INK, 0.88))
	gradient.set_color(1, Color(MenuTheme.INK, 0.0))
	gradient.add_point(0.45, Color(MenuTheme.INK, 0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(1, 0)
	texture.width = 256
	texture.height = 4
	return texture
