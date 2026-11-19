extends GutTest
## T-128: in-match pause menu and the results screen.

const FakeLevel := preload("res://tests/ui/menus/fake_level.gd")

var level: Node3D
var session: MatchSession
var _saved: Dictionary


func before_each() -> void:
	var config := get_node(^"/root/MatchConfig")
	_saved = config.to_dictionary()
	config.set_config(MatchRules.build_vs_ai(&"kael", [{"character": &"vexa", "ai_level": 4}], &"ember_rift"))
	level = FakeLevel.new()
	add_child_autofree(level)
	session = MatchSession.new()
	level.add_child(session)


func after_each() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_node(^"/root/MatchConfig").set_config(_saved)


func test_pause_freezes_the_tree_and_resume_releases_it() -> void:
	session.pause()
	assert_true(get_tree().paused)
	assert_true(session.pause_menu.visible)
	session.pause_menu.buttons[&"resume"].pressed.emit()
	assert_false(get_tree().paused)
	assert_false(session.pause_menu.visible)


func test_pause_menu_has_every_entry() -> void:
	for id in [&"resume", &"restart", &"settings", &"quit"]:
		assert_true(session.pause_menu.buttons.has(id), String(id))


func test_pause_settings_open_and_escape_backs_out_first() -> void:
	session.pause()
	session.pause_menu.open_settings()
	assert_true(session.pause_menu.settings.visible)
	session.pause_menu.back_or_resume()
	assert_false(session.pause_menu.settings.visible)
	assert_true(get_tree().paused, "still paused after leaving settings")
	session.pause_menu.back_or_resume()
	assert_false(get_tree().paused)


func test_results_appear_after_the_match_is_over() -> void:
	level.match_flow.phase = MatchFlow.Phase.MATCH_OVER
	level.match_flow.last_winner = 0
	# Stepped by hand: GUT's own timers stop while the tree is paused.
	for i in roundi((MatchSession.RESULTS_DELAY + 0.3) / 0.1):
		session._process(0.1)
	assert_true(session.results.visible)
	assert_eq(session.results.winner, 0)
	assert_eq(session.results._banner.text, "VICTORY!")
	assert_eq(session.results.turntable.legend, &"kael")
	assert_true(get_tree().paused)


func test_results_say_defeat_when_an_ai_wins() -> void:
	session.show_results(1)
	assert_eq(session.results._banner.text, "DEFEAT")
	assert_string_contains(session.results._winner_name.text, "VEXA")
	assert_eq(session.results.turntable.pose, FighterState.State.CHARGING)


func test_no_results_before_the_delay() -> void:
	level.match_flow.phase = MatchFlow.Phase.MATCH_OVER
	session._process(0.1)
	session._process(MatchSession.RESULTS_DELAY * 0.5)
	assert_false(session.results.visible)


func test_match_finished_signal_reports_the_winner() -> void:
	level.match_finished.emit(1)
	assert_true(session.match_over)
	assert_eq(session.winner_index(), 1)


func test_results_offer_rematch_character_select_and_main_menu() -> void:
	var results := ResultsScreen.new()
	add_child_autofree(results)
	results.open(get_node(^"/root/MatchConfig").fighters, 0)
	for id in [&"rematch", &"character_select", &"main"]:
		assert_true(results.buttons.has(id), String(id))
	watch_signals(results)
	results.buttons[&"character_select"].pressed.emit()
	assert_signal_emitted(results, "character_select_requested")
