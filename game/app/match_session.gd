class_name MatchSession
extends Node
## Added to a running match level: Esc opens the pause menu, and the results
## screen appears once the level's match is over.

## Seconds between the final K.O. and the results screen.
const RESULTS_DELAY := 2.0

var pause_menu: PauseMenu
var results: ResultsScreen
var match_over := false
var _over_for := 0.0
## Winner reported by a level's match_finished signal; -2 = none.
var _reported_winner := -2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu = PauseMenu.new()
	pause_menu.resumed.connect(resume)
	pause_menu.restart_requested.connect(restart)
	pause_menu.quit_requested.connect(_quit_to.bind(&"main"))
	add_child(pause_menu)
	results = ResultsScreen.new()
	results.rematch_requested.connect(restart)
	results.character_select_requested.connect(_quit_to.bind(&"character_select"))
	results.main_menu_requested.connect(_quit_to.bind(&"main"))
	add_child(results)
	if is_online():
		# Online the match never pauses; Restart would desync, so it returns to the lobby instead.
		(pause_menu.buttons[&"restart"] as Button).visible = false
	var level := get_parent()
	if level != null and level.has_signal(&"match_finished"):
		level.connect(&"match_finished", _on_match_finished)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not results.visible:
		if pause_menu.visible:
			pause_menu.back_or_resume()
		else:
			pause()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if match_over:
		if not results.visible:
			_over_for += delta / maxf(Engine.time_scale, 0.01)
			if _over_for >= RESULTS_DELAY:
				show_results(winner_index())
		return
	var flow: Variant = get_parent().get(&"match_flow") if get_parent() != null else null
	if flow is MatchFlow and (flow as MatchFlow).enabled and (flow as MatchFlow).phase == MatchFlow.Phase.MATCH_OVER:
		match_over = true


## True in a Duo match over the network (the level's online flag).
func is_online() -> bool:
	return get_parent() != null and get_parent().get(&"online") == true


func pause() -> void:
	if is_online():
		get_parent().set(&"input_blocked", true)
		pause_menu.open()
		return
	get_tree().paused = true
	pause_menu.open()
	_music(&"set_paused", true)


func resume() -> void:
	pause_menu.close()
	if get_parent() != null and get_parent().get(&"input_blocked") != null:
		get_parent().set(&"input_blocked", false)
	get_tree().paused = false
	_music(&"set_paused", false)
	if uses_mouse_look():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## False for a level without a free camera (Pure Fight): its clicks are attacks, so the
## pointer stays free and the browser is never asked for pointer lock.
func uses_mouse_look() -> bool:
	return get_parent() == null or get_parent().get(&"mouse_look") != false


func restart() -> void:
	if is_online():
		_quit_to(&"duo_lobby")
		return
	_music(&"set_paused", false)
	var config := _config()
	if config != null:
		config.launch()


## The winning fighter's index from the level's match flow, or -1.
func winner_index() -> int:
	if _reported_winner != -2:
		return _reported_winner
	var flow: Variant = get_parent().get(&"match_flow") if get_parent() != null else null
	return (flow as MatchFlow).last_winner if flow is MatchFlow else -1


func show_results(winner: int) -> void:
	match_over = true
	if is_online():
		get_parent().set(&"input_blocked", true)
	else:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var config := _config()
	var fighters: Array = config.fighters if config != null else []
	results.open(fighters, winner)


func _on_match_finished(winner: int) -> void:
	match_over = true
	_reported_winner = winner


func _quit_to(screen: StringName) -> void:
	_music(&"set_paused", false)
	var level := get_parent()
	if level != null and level.get(&"duo_link") is DuoLink:
		var link := level.get(&"duo_link") as DuoLink
		# A Duo match goes back to the Duo lobby while the partner is still there.
		if screen != &"main" and link.is_connected_to_partner():
			screen = &"duo_lobby"
		elif screen == &"main":
			link.leave()
	var config := _config()
	if config != null:
		config.return_to_menu(screen)


func _config() -> Node:
	return get_node_or_null(^"/root/MatchConfig")


func _music(method: StringName, arg: Variant) -> void:
	var music := get_node_or_null(^"/root/MusicDirector")
	if music != null and music.has_method(method):
		music.call(method, arg)
