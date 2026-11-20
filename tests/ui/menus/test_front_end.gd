extends GutTest
## T-128: navigating every front-end screen and building configs from the picks.

var front: FrontEnd


func before_each() -> void:
	front = FrontEnd.new()
	front.light_backdrop = true
	front.skip_splash = true
	add_child_autofree(front)


func _main() -> MainMenu:
	return front.screens[&"main"] as MainMenu


func _select() -> CharacterSelect:
	return front.screens[&"character_select"] as CharacterSelect


func test_boots_on_the_splash_then_main_menu() -> void:
	var booting := FrontEnd.new()
	booting.light_backdrop = true
	add_child_autofree(booting)
	assert_eq(booting.current, &"splash")
	(booting.screens[&"splash"] as SplashScreen).finish()
	assert_eq(booting.current, &"main")


func test_splash_moves_on_by_itself() -> void:
	var booting := FrontEnd.new()
	booting.light_backdrop = true
	add_child_autofree(booting)
	await wait_seconds(SplashScreen.HOLD_SECONDS + 0.3)
	assert_eq(booting.current, &"main")


func test_backdrop_is_a_live_3d_scene() -> void:
	assert_eq(front.backdrop.kind, &"stylised")
	assert_gt(front.backdrop.get_child_count(), 2)


func test_main_menu_lists_every_mode() -> void:
	for id in [&"vs_ai", &"ffa", &"duo", &"training", &"settings", &"quit"]:
		assert_true(_main().buttons.has(id), String(id))
	assert_true(_main().first_focus().has_focus(), "Play has keyboard focus")


func test_play_leads_to_vs_ai_character_select_then_zone_select() -> void:
	_main().buttons[&"vs_ai"].pressed.emit()
	assert_eq(front.current, &"character_select")
	assert_eq(_select().mode, &"vs_ai")
	assert_eq(_select().slots.size(), 2)
	_select().confirm()
	assert_eq(front.current, &"zone_select")
	front.back()
	assert_eq(front.current, &"character_select")
	front.back()
	assert_eq(front.current, &"main")


func test_escape_goes_back_a_screen() -> void:
	_main().buttons[&"ffa"].pressed.emit()
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	_select()._unhandled_input(event)
	assert_eq(front.current, &"main")


func test_free_for_all_and_training_open_their_seat_setups() -> void:
	_main().buttons[&"ffa"].pressed.emit()
	assert_eq(_select().mode, &"ffa")
	assert_eq(_select().slots.size(), 4)
	front.back()
	_main().buttons[&"training"].pressed.emit()
	assert_eq(_select().mode, &"training")
	assert_eq(_select().slots.size(), 2)
	assert_eq(_select().slots[1].ai_level, 1)


func test_duo_says_coming_soon_without_a_lobby() -> void:
	if MainMenu.duo_available():
		pass_test("a net lobby exists")
		return
	_main().buttons[&"duo"].pressed.emit()
	assert_eq(front.current, &"main")
	assert_true(_main()._toast.visible)
	assert_string_contains(_main()._toast.text, "COMING SOON")


func test_settings_opens_and_returns() -> void:
	_main().buttons[&"settings"].pressed.emit()
	assert_eq(front.current, &"settings")
	(front.screens[&"settings"] as SettingsScreen).go_back()
	assert_eq(front.current, &"main")


func test_quit_asks_to_quit() -> void:
	_main().quit_requested.disconnect(front.quit)
	watch_signals(_main())
	_main().buttons[&"quit"].pressed.emit()
	assert_signal_emitted(_main(), "quit_requested")


func test_vs_ai_with_three_ais_builds_the_config() -> void:
	_main().buttons[&"vs_ai"].pressed.emit()
	_select().select_legend(&"vexa")
	_select().add_ai()
	_select().add_ai()
	_select().add_ai()
	assert_eq(_select().slots.size(), 4, "3 AIs max")
	_select().set_ai_level(2, 5)
	_select().confirm()
	(front.screens[&"zone_select"] as ZoneSelect).select_zone(&"heartbloom_gardens")
	var config := front.build_config()
	assert_eq(config.mode, &"vs_ai")
	assert_eq(config.zone, &"heartbloom_gardens")
	assert_eq(config.fighters.size(), 4)
	assert_eq(config.fighters[0].character, &"vexa")
	assert_false(config.fighters[0].is_ai)
	assert_eq(config.fighters[2].ai_level, 5)
	assert_true(MatchRules.problems(config).is_empty())


func test_ffa_seats_can_be_humans_or_ais_on_teams() -> void:
	_main().buttons[&"ffa"].pressed.emit()
	_select().toggle_ai(1)
	_select().cycle_team(2)
	_select().remove_slot(3)
	var config := front.build_config()
	assert_eq(config.mode, &"ffa")
	assert_eq(config.fighters.size(), 3)
	assert_false(config.fighters[1].is_ai)
	assert_eq(config.fighters[2].team, 3)


func test_every_zone_card_shows_its_whole_name() -> void:
	front.go(&"zone_select")
	await get_tree().process_frame
	await get_tree().process_frame
	var zones := front.screens[&"zone_select"] as ZoneSelect
	for id: StringName in zones.cards:
		var card: Button = zones.cards[id]
		for child in card.get_children():
			if child is Label:
				var label := child as Label
				var font := label.get_theme_font(&"font")
				var size := label.get_theme_font_size(&"font_size")
				var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				assert_lte(width, label.size.x, "%s fits its card at %d px" % [label.text, size])


func test_zone_select_offers_all_seven_zones_with_art() -> void:
	var zones := front.screens[&"zone_select"] as ZoneSelect
	assert_eq(zones.cards.size(), 7)
	for id: StringName in zones.cards:
		assert_not_null(ZoneCatalog.art(id), String(id))
	zones.select_zone(&"heartbloom_gardens")
	assert_true(zones.is_romantic())
	assert_true(zones._hearts.visible, "Heartbloom's hearts drift")
	zones.select_zone(&"ember_rift")
	assert_false(zones._hearts.visible)


func test_zone_select_cycles_rounds() -> void:
	var zones := front.screens[&"zone_select"] as ZoneSelect
	assert_eq(zones.rounds, 3)
	zones.cycle_rounds()
	assert_eq(zones.rounds, 5)
	zones.cycle_rounds()
	assert_eq(zones.rounds, 1)


func test_returning_from_a_match_reopens_character_select_with_the_same_seats() -> void:
	var config := get_node(^"/root/MatchConfig")
	var saved: Dictionary = config.to_dictionary()
	config.set_config(MatchRules.build_ffa([{"character": &"vexa", "is_ai": false}, {"character": &"kael"}, {"character": &"kael"}], &"frozen_peaks", 5))
	config.return_screen = &"character_select"
	var again := FrontEnd.new()
	again.light_backdrop = true
	add_child_autofree(again)
	assert_eq(again.current, &"character_select")
	var select := again.screens[&"character_select"] as CharacterSelect
	assert_eq(select.mode, &"ffa")
	assert_eq(select.slots.size(), 3)
	assert_eq(select.slots[0].character, &"vexa")
	assert_eq((again.screens[&"zone_select"] as ZoneSelect).selected, &"frozen_peaks")
	assert_eq(config.return_screen, &"")
	config.set_config(saved)


func test_ui_fits_any_window_keeping_the_design_aspect() -> void:
	var probe := Control.new()
	add_child_autofree(probe)
	MenuTheme.fit(probe, Vector2(1600, 900))
	assert_almost_eq(probe.scale.x, 1600.0 / 1920.0, 0.001)
	assert_eq(probe.position, Vector2.ZERO)
