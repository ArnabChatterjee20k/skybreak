extends GutTest
## T-D18b: the roster spawns Kael or Vexa per slot, in the view and the sim.


func test_the_roster_has_kael_and_vexa() -> void:
	var ids := Roster.ids()
	assert_eq(ids.slice(0, 2), [&"kael", &"vexa"] as Array[StringName], "Kael and Vexa first; later legends append")
	for id: StringName in [&"lyra", &"brann"]:
		assert_has(ids, id, "the roster lists %s" % id)
	for id in Roster.ids():
		var character := Roster.character(id)
		assert_not_null(character, "%s loads" % id)
		assert_eq(character.id, id)
		assert_not_null(character.scene, "%s has a scene" % id)
		assert_not_null(character.stats.move_set, "%s has moves" % id)
	assert_null(Roster.character(&"nobody"))


func test_kael_and_vexa_fight_with_different_move_sets() -> void:
	var kael := Roster.character(&"kael")
	var vexa := Roster.character(&"vexa")
	assert_ne(kael.stats.move_set, vexa.stats.move_set)
	assert_eq(vexa.stats.move_set.light_string.size(), 5)


func test_slots_past_the_palette_list_use_the_last_palette() -> void:
	var vexa := Roster.character(&"vexa")
	assert_eq(vexa.palette_for(0), {}, "P1 wears her own colours")
	assert_true(vexa.palette_for(1).has("violet"), "P2 has an alt palette")
	assert_eq(vexa.palette_for(3), vexa.palette_for(1))


func test_a_view_with_a_character_id_draws_that_character_and_its_slot_palette() -> void:
	var view := FighterView.new()
	view.character_id = &"vexa"
	view.slot = 1
	view.fighter = FighterState.new()
	add_child_autofree(view)
	assert_eq(view.character, Roster.character(&"vexa"))
	assert_eq(view.palette, Roster.character(&"vexa").palette_for(1))
	assert_eq(view.find_children("*", "VexaView", true, false).size(), 1)
	assert_eq(view.fighter_stats(), Roster.character(&"vexa").stats)


func test_a_view_without_a_character_id_keeps_the_sim_default() -> void:
	var view := FighterView.new()
	view.fighter = FighterState.new()
	add_child_autofree(view)
	assert_null(view.fighter_stats())


func test_the_sim_runs_vexa_moves_for_her_slot() -> void:
	var sim := CombatSim.new(7)
	sim.add_fighter(Vector3(0, 1, 2), Roster.character(&"kael").stats)
	var vexa := sim.add_fighter(Vector3(0, 1, -2), Roster.character(&"vexa").stats)
	sim.lock_everyone_onto_nearest()
	var press := FighterInput.new()
	press.pressed_actions = FighterInput.Action.LIGHT
	press.held_actions = FighterInput.Action.LIGHT
	var inputs: Array[FighterInput] = [FighterInput.new(), press]
	sim.tick(inputs)
	assert_eq(vexa.state, FighterState.State.ATTACKING, "her light press attacks")
	assert_eq(vexa.move, Roster.character(&"vexa").stats.move_set.light_string[0], "with her own jab")
	assert_eq(vexa.stats.max_health, 9500)
	assert_eq(sim.fighters[0].stats.move_set.light_string.size(), 4, "Kael keeps his string")
