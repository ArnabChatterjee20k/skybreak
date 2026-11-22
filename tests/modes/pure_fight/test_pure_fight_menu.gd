extends GutTest
## Pure Fight is reachable from the menus: a Play entry, a two-seat character select with a
## human/AI toggle for the second player, its own level, and a move list in the pause menu.


func test_the_main_menu_offers_pure_fight() -> void:
	var ids := MainMenu.entries(false).map(func(entry: Dictionary) -> StringName: return entry.id)
	assert_true(ids.has(&"pure_fight"))


func test_character_select_seats_two_and_lets_p2_be_human() -> void:
	var select := CharacterSelect.new()
	add_child_autofree(select)
	select.setup(&"pure_fight")
	assert_eq(select.slots.size(), 2)
	assert_eq(select.max_slots(), 2)
	assert_true(select.slots[1].is_ai)
	select.toggle_ai(1)
	assert_false(select.slots[1].is_ai, "a second local player")
	assert_true(select.problems().is_empty())


func test_pure_fight_configs_launch_the_pure_fight_level() -> void:
	assert_true(MatchRules.is_pure_fight(MatchRules.MODE_PURE_FIGHT))
	assert_true(MatchRules.is_pure_fight(MatchRules.MODE_PURE_FIGHT_TRAINING))
	assert_false(MatchRules.is_pure_fight(MatchRules.MODE_VS_AI))
	assert_true(ResourceLoader.exists(MatchConfig.PURE_FIGHT_SCENE))
	var level: Node = (load(MatchConfig.PURE_FIGHT_SCENE) as PackedScene).instantiate()
	assert_true(level is PureFightMatch)
	assert_true(level.has_signal(&"match_finished"), "MatchSession shows results")
	level.free()


func test_the_pause_menu_lists_every_move_in_pure_fight() -> void:
	var level := PureFightMatch.new()
	level.skip_world = true
	level.configure({"fighters": [{"character": &"brann", "is_ai": true}, {"character": &"lyra", "is_ai": true}]})
	add_child_autofree(level)
	var session := Node.new()
	level.add_child(session)
	var menu := PauseMenu.new()
	session.add_child(menu)
	assert_true(menu.buttons.has(&"moves"))
	var text := level.move_list_text()
	for legend in [&"brann", &"lyra"]:
		for id in PureMoves.ids(legend):
			assert_string_contains(text, String(PureMoves.get_move(legend, id).name))


func test_two_players_read_separate_keys() -> void:
	var p1 := PureFightKeys.new(0)
	var p2 := PureFightKeys.new(1)
	assert_true(InputMap.has_action(PureFightKeys.action_name(0, "light")))
	assert_true(InputMap.has_action(PureFightKeys.action_name(1, "light")))
	assert_ne(p1.player, p2.player)
