extends GutTest
## T-128: building and checking the MatchConfig dictionary.


func _ais(count: int) -> Array:
	var list := []
	for i in count:
		list.append({"character": &"vexa", "ai_level": i + 2})
	return list


func test_vs_ai_takes_one_to_three_ai_opponents() -> void:
	for count in [1, 2, 3]:
		var config := MatchRules.build_vs_ai(&"kael", _ais(count), &"ember_rift")
		assert_eq(config.fighters.size(), count + 1)
		assert_eq(config.mode, MatchRules.MODE_VS_AI)
		assert_false(config.fighters[0].is_ai, "P1 is human")
		for i in range(1, count + 1):
			assert_true(config.fighters[i].is_ai)
			assert_eq(config.fighters[i].team, i, "each AI fights on its own team")
		assert_true(MatchRules.problems(config).is_empty(), str(MatchRules.problems(config)))


func test_vs_ai_never_seats_more_than_three_ais() -> void:
	var config := MatchRules.build_vs_ai(&"kael", _ais(5), &"ember_rift")
	assert_eq(config.fighters.size(), 4)


func test_config_has_every_contract_key() -> void:
	var config := MatchRules.build_vs_ai(&"kael", _ais(1), &"frozen_peaks", 5)
	assert_eq(config.zone, &"frozen_peaks")
	assert_eq(config.rounds, 5)
	for key in ["character", "team", "is_ai", "ai_level"]:
		assert_true(config.fighters[1].has(key), key)
	assert_typeof(config.zone, TYPE_STRING_NAME)
	assert_typeof(config.fighters[0].character, TYPE_STRING_NAME)


func test_ffa_takes_two_to_four_fighters_with_teams() -> void:
	for count in [2, 3, 4]:
		var entries := []
		for i in count:
			entries.append({"character": &"kael", "is_ai": i > 0})
		var config := MatchRules.build_ffa(entries, &"verdant_falls")
		assert_eq(config.fighters.size(), count)
		assert_eq(config.mode, MatchRules.MODE_FFA)
		assert_eq(config.fighters[count - 1].team, count - 1)
		assert_true(MatchRules.problems(config).is_empty())


func test_ffa_keeps_given_teams_for_two_versus_two() -> void:
	var entries := [
		{"character": &"kael", "is_ai": false, "team": 0},
		{"character": &"vexa", "team": 0},
		{"character": &"kael", "team": 1},
		{"character": &"vexa", "team": 1},
	]
	var config := MatchRules.build_ffa(entries, &"verdant_falls")
	assert_eq(config.fighters.map(func(f: Dictionary) -> int: return f.team), [0, 0, 1, 1])
	assert_true(MatchRules.problems(config).is_empty())


func test_ai_level_is_clamped_to_one_through_five() -> void:
	assert_eq(MatchRules.fighter(&"kael", 1, true, 0).ai_level, 1)
	assert_eq(MatchRules.fighter(&"kael", 1, true, 9).ai_level, 5)


func test_problems_catch_bad_setups() -> void:
	var solo: Array[Dictionary] = [MatchRules.fighter(&"kael", 0, false)]
	assert_false(MatchRules.problems(MatchRules.make(&"vs_ai", &"ember_rift", solo, 3)).is_empty(), "one fighter")
	var bots: Array[Dictionary] = [MatchRules.fighter(&"kael", 0, true), MatchRules.fighter(&"vexa", 1, true)]
	assert_false(MatchRules.problems(MatchRules.make(&"ffa", &"ember_rift", bots, 3)).is_empty(), "no human")
	var one_team: Array[Dictionary] = [MatchRules.fighter(&"kael", 0, false), MatchRules.fighter(&"vexa", 0, true)]
	assert_false(MatchRules.problems(MatchRules.make(&"ffa", &"ember_rift", one_team, 3)).is_empty(), "one team")
	var five: Array[Dictionary] = []
	for i in 5:
		five.append(MatchRules.fighter(&"kael", i, i > 0))
	assert_false(MatchRules.problems(MatchRules.make(&"ffa", &"ember_rift", five, 3)).is_empty(), "five fighters")
	var ok: Array[Dictionary] = [MatchRules.fighter(&"kael", 0, false), MatchRules.fighter(&"vexa", 1, true)]
	assert_false(MatchRules.problems(MatchRules.make(&"ffa", &"", ok, 3)).is_empty(), "no zone")
