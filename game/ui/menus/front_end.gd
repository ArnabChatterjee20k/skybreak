class_name FrontEnd
extends Node
## The game's front end (main scene): splash, main menu, character select,
## zone select and settings over a live 3D backdrop. Fast transitions
## (under 0.3 s), keyboard and mouse, then MatchConfig launches the match.

## Tests and tools set this before adding the node: no flythrough, no splash.
var light_backdrop := false
var skip_splash := false
var backdrop: MenuBackdrop
var screens: Dictionary = {}
var current: StringName = &""
var history: Array[StringName] = []
var mode: StringName = &"vs_ai"

var _ui: Control
var _layer: CanvasLayer


func _ready() -> void:
	backdrop = MenuBackdrop.new()
	add_child(backdrop)
	backdrop.build(not light_backdrop)
	_layer = CanvasLayer.new()
	add_child(_layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.theme = MenuTheme.theme()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_ui)
	_add_screen(&"splash", SplashScreen.new())
	_add_screen(&"main", MainMenu.new())
	_add_screen(&"character_select", CharacterSelect.new())
	_add_screen(&"zone_select", ZoneSelect.new())
	_add_screen(&"settings", SettingsScreen.new())
	_add_screen(&"duo_lobby", DuoScreen.new())
	(screens[&"main"] as MainMenu).mode_chosen.connect(_on_mode_chosen)
	(screens[&"main"] as MainMenu).quit_requested.connect(quit)
	(screens[&"zone_select"] as ZoneSelect).fight_requested.connect(start_match)
	get_viewport().size_changed.connect(_fit_ui)
	_fit_ui()
	var config := _config()
	var opening: StringName = config.return_screen if config != null and config.return_screen != &"" else &""
	if config != null:
		config.return_screen = &""
	if opening == &"character_select":
		mode = config.mode
		go(&"main", false)
		_restore_seats(config)
		go(&"character_select")
	elif opening == &"duo_lobby":
		mode = MatchRules.MODE_DUO
		go(&"main", false)
		go(&"duo_lobby")
	elif opening == &"main" or skip_splash:
		go(&"main", false)
	else:
		go(&"splash", false)


## Shows `screen`; `remember` keeps the current one for back().
func go(screen: StringName, remember := true) -> void:
	if not screens.has(screen):
		return
	if remember and current != &"" and current != &"splash":
		history.append(current)
	var previous: MenuScreen = screens.get(current)
	current = screen
	var next: MenuScreen = screens[screen]
	for id: StringName in screens:
		(screens[id] as Control).visible = id == screen
	next.enter()
	_music_for(screen)
	var focus := next.first_focus()
	if focus != null:
		focus.grab_focus()
	if previous != next:
		next.modulate.a = 0.0
		next.position.x = 40.0
		var tween := next.create_tween().set_parallel()
		tween.tween_property(next, "modulate:a", 1.0, MenuTheme.TRANSITION)
		tween.tween_property(next, "position:x", 0.0, MenuTheme.TRANSITION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func back() -> void:
	if history.is_empty():
		return
	go(history.pop_back(), false)


## The config the current picks describe.
func build_config() -> Dictionary:
	var select := screens[&"character_select"] as CharacterSelect
	var zones := screens[&"zone_select"] as ZoneSelect
	var list: Array[Dictionary] = []
	for slot in select.slots:
		list.append(MatchRules.fighter(slot.character, slot.team, slot.is_ai, slot.ai_level))
	return MatchRules.make(select.mode, zones.selected, list, zones.rounds)


## Hands the picks to MatchConfig and launches. Returns the scene path or "".
func start_match() -> String:
	var config_dict := build_config()
	if not MatchRules.problems(config_dict).is_empty():
		return ""
	var config := _config()
	if config == null:
		return ""
	config.set_config(config_dict)
	return config.launch()


func quit() -> void:
	get_tree().quit()


func _add_screen(id: StringName, screen: MenuScreen) -> void:
	screen.name = String(id).to_pascal_case()
	screen.front_end = self
	screen.visible = false
	screen.navigate.connect(go)
	screen.back_requested.connect(back)
	_ui.add_child(screen)
	screens[id] = screen


func _on_mode_chosen(chosen: StringName) -> void:
	mode = chosen
	(screens[&"character_select"] as CharacterSelect).setup(chosen)


func _restore_seats(config: Node) -> void:
	var select := screens[&"character_select"] as CharacterSelect
	select.setup(config.mode)
	select.slots.assign((config.fighters as Array).duplicate(true))
	select.refresh()
	var zones := screens[&"zone_select"] as ZoneSelect
	zones.rounds = config.rounds
	zones.select_zone(config.zone)


func _music_for(screen: StringName) -> void:
	var music := get_node_or_null(^"/root/MusicDirector")
	if music == null:
		return
	if screen == &"main" or screen == &"splash":
		if music.get(&"current_track") != &"menu" and music.has_method(&"play_menu"):
			music.call(&"play_menu")


## Lays the 1920x1080 design out at any window size, keeping the aspect.
func _fit_ui() -> void:
	MenuTheme.fit(_ui, get_viewport().get_visible_rect().size)


func _config() -> Node:
	return get_node_or_null(^"/root/MatchConfig")
