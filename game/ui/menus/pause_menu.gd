class_name PauseMenu
extends CanvasLayer
## In-match pause: resume, restart, settings, quit to menu. Runs while the
## tree is paused.

signal resumed
signal restart_requested
signal quit_requested

var settings: SettingsScreen
var buttons: Dictionary = {}

var _main: Control

var _root: Control


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = MenuTheme.theme()
	add_child(root)
	_root = root
	get_viewport().size_changed.connect(_fit)
	_fit()
	var dim := ColorRect.new()
	dim.color = Color(MenuTheme.INK, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	_main = Control.new()
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_main)
	var title := MenuTheme.label("PAUSED", 140, MenuTheme.GOLD, 22)
	title.position = Vector2(140, 150)
	_main.add_child(title)
	var bar := ColorRect.new()
	bar.color = MenuTheme.HOT
	bar.position = Vector2(150, 330)
	bar.size = Vector2(520, 12)
	_main.add_child(bar)
	var column := VBoxContainer.new()
	column.position = Vector2(150, 400)
	column.add_theme_constant_override("separation", 16)
	_main.add_child(column)
	for entry: Array in [["resume", "Resume", resume], ["restart", "Restart", _restart],
			["settings", "Settings", open_settings], ["quit", "Quit to menu", _quit]]:
		var b := MenuTheme.button(entry[1], 48)
		b.custom_minimum_size = Vector2(560, 84)
		var action: Callable = entry[2]
		b.pressed.connect(func() -> void:
			MenuScreen.cue(self, &"confirm")
			action.call())
		b.mouse_entered.connect(b.grab_focus)
		b.focus_entered.connect(MenuScreen.cue.bind(self, &"move"))
		column.add_child(b)
		buttons[StringName(entry[0])] = b
	var hints := MenuScreen.key_hints([["Esc", "Resume"], ["Enter", "Select"]])
	hints.position = Vector2(150, 960)
	_main.add_child(hints)
	settings = SettingsScreen.new()
	settings.visible = false
	settings.back_requested.connect(close_settings)
	root.add_child(settings)


func open() -> void:
	visible = true
	close_settings()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(buttons[&"resume"] as Button).grab_focus()


func close() -> void:
	visible = false
	settings.visible = false


func open_settings() -> void:
	_main.visible = false
	settings.visible = true
	settings.enter()
	settings.first_focus().grab_focus()


func close_settings() -> void:
	settings.visible = false
	_main.visible = true
	if visible:
		(buttons[&"resume"] as Button).grab_focus()


## Esc: leaves settings first, then resumes.
func back_or_resume() -> void:
	if settings.visible:
		close_settings()
	else:
		resume()


func resume() -> void:
	resumed.emit()


func _restart() -> void:
	restart_requested.emit()


func _quit() -> void:
	quit_requested.emit()


func _fit() -> void:
	MenuTheme.fit(_root, get_viewport().get_visible_rect().size)
