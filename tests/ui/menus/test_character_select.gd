extends GutTest
## T-128: the roster is read dynamically and each seat is set up per mode.

var select: CharacterSelect


func before_each() -> void:
	select = CharacterSelect.new()
	add_child_autofree(select)
	select.setup(&"vs_ai")


func test_roster_comes_from_the_roster_definitions() -> void:
	var ids := LegendCatalog.ids()
	for id in Roster.ids():
		assert_has(ids, id)
	assert_eq(ids[0], &"kael")
	assert_eq(ids[1], &"vexa")
	assert_eq(select.legends, ids)


func test_every_legend_has_a_rendered_portrait_and_a_card() -> void:
	for id in LegendCatalog.ids():
		assert_true(select.legend_cards.has(id), String(id))
		var portrait: LegendTurntable = select.portraits[id]
		assert_not_null(portrait.character_view, "%s portrait has its CharacterView" % id)
		assert_false(portrait.live)


func test_showcase_follows_the_active_seat() -> void:
	select.select_legend(&"vexa")
	assert_eq(select.showcase.legend, &"vexa")
	assert_not_null(select.showcase.character_view)
	select.set_active_slot(1)
	assert_eq(select.showcase.legend, select.slots[1].character)


func test_legend_has_name_title_and_four_stat_bars() -> void:
	for id in LegendCatalog.ids():
		assert_false(LegendCatalog.display_name(id).is_empty())
		assert_false(LegendCatalog.title(id).is_empty())
		var bars := LegendCatalog.stat_bars(id)
		assert_eq(bars.size(), 4)
		for value in bars:
			assert_between(value, 1, 10)


func test_launch_four_have_design_titles() -> void:
	assert_eq(LegendCatalog.title(&"kael"), "Sky-Knight Adventurer")
	assert_eq(LegendCatalog.title(&"brann"), "Stone-Forged Blacksmith")


func test_vs_ai_allows_one_to_three_ais() -> void:
	assert_eq(select.slots.size(), 2)
	select.remove_slot(1)
	assert_eq(select.slots.size(), 2, "at least one AI")
	for i in 5:
		select.add_ai()
	assert_eq(select.slots.size(), 4, "at most three AIs")
	select.remove_slot(3)
	assert_eq(select.slots.size(), 3)


func test_ai_levels_stay_between_one_and_five() -> void:
	select.set_ai_level(1, 9)
	assert_eq(select.slots[1].ai_level, 5)
	select.set_ai_level(1, 0)
	assert_eq(select.slots[1].ai_level, 1)


func test_only_ffa_seats_switch_between_human_and_ai() -> void:
	select.toggle_ai(1)
	assert_true(select.slots[1].is_ai, "Vs AI seats stay AI")
	select.setup(&"ffa")
	select.toggle_ai(1)
	assert_false(select.slots[1].is_ai)
	select.toggle_ai(0)
	assert_false(select.slots[0].is_ai, "P1 stays human")


func test_teams_cycle_through_four() -> void:
	var start: int = select.slots[1].team
	for i in 4:
		select.cycle_team(1)
	assert_eq(select.slots[1].team, start)
	select.cycle_team(1, -1)
	assert_eq(select.slots[1].team, posmod(start - 1, 4))


func test_confirm_refuses_a_single_team() -> void:
	select.cycle_team(1, -1)
	assert_eq(select.slots[1].team, 0)
	watch_signals(select)
	select.confirm()
	assert_signal_not_emitted(select, "navigate")
	select.cycle_team(1)
	select.confirm()
	assert_signal_emitted_with_parameters(select, "navigate", [&"zone_select"])


func test_random_card_picks_a_roster_legend() -> void:
	select.randomize_slot(0)
	assert_has(select.legends, select.slots[0].character)
