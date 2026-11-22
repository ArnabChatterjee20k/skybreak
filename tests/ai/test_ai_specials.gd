extends GutTest
## T-SP1: the AI uses its legend's specials, more at higher levels, never at Easy.


## SPECIAL_START slots seen for slot 0 over a seeded bout of max_ticks.
func _specials_used(level: int, legend: StringName, other: StringName, seed_value: int, max_ticks: int = 3600) -> Array[int]:
	var bout := AIBout.new(seed_value, [level, 3], false, [legend, other])
	var used: Array[int] = []
	while bout.ticks < max_ticks and not bout.sim.round_over:
		bout.step()
		for event in bout.sim.events:
			if event.type == CombatSim.EventType.SPECIAL_START and event.fighter == 0:
				used.append(event.slot)
	return used


func test_a_hard_kael_ai_uses_his_specials() -> void:
	var used: Array[int] = []
	for seed_value in [1, 2, 3]:
		used.append_array(_specials_used(5, &"kael", &"brann", seed_value))
	assert_gt(used.size(), 0, "Kael's AI throws specials at level 5")


func test_a_hard_vexa_ai_uses_her_specials() -> void:
	var used: Array[int] = []
	for seed_value in [1, 2, 3]:
		used.append_array(_specials_used(5, &"vexa", &"kael", seed_value))
	assert_gt(used.size(), 0, "Vexa's AI throws specials at level 5")


func test_an_easy_ai_never_uses_specials() -> void:
	for legend: StringName in [&"kael", &"vexa"]:
		assert_eq(_specials_used(1, legend, &"brann", 7, 2400).size(), 0, "%s at level 1" % legend)


func test_legends_without_a_kit_never_press_special_keys() -> void:
	assert_eq(_specials_used(5, &"brann", &"kael", 4, 1800).size(), 0)


func test_ai_special_picks_respect_level_range_and_ki() -> void:
	var sim := CombatSim.new()
	sim.add_fighter(Vector3.ZERO, EngagementBand.stats_for(&"kael"))
	sim.add_fighter(Vector3(0, 0, -6), EngagementBand.stats_for(&"brann"))
	assert_eq(SpecialRules.ai_pick(sim, 0, SpecialMove.AiRole.APPROACH, 6.0, 3), 1, "Comet Drive from mid range")
	assert_eq(SpecialRules.ai_pick(sim, 0, SpecialMove.AiRole.APPROACH, 2.0, 3), 0, "too close")
	assert_eq(SpecialRules.ai_pick(sim, 0, SpecialMove.AiRole.COUNTER, 2.0, 2), 0, "Gale Counter needs level 3")
	sim.fighters[0].ki = 0
	assert_eq(SpecialRules.ai_pick(sim, 0, SpecialMove.AiRole.APPROACH, 6.0, 5), 0, "no ki, no special")
