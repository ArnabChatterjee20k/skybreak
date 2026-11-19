extends GutTest


func test_a_duo_match_has_two_humans_and_the_ai_team() -> void:
	var sim := DuoMatch.new_sim(1, 2)
	assert_eq(sim.fighters.size(), 4)
	assert_eq(DuoMatch.fighter_peers(sim), [0, 1, -1, -1] as Array[int])
	var bots := DuoMatch.new_bots(sim, 1)
	assert_null(bots[0])
	assert_true(bots[2] is WeaponBot)


func test_humans_lock_onto_the_ai_and_the_ai_onto_humans() -> void:
	var sim := DuoMatch.new_sim(1, 2)
	for i in 2:
		assert_gte(sim.fighters[i].lock_on_target, 2)
	for i in range(2, 4):
		assert_lt(sim.fighters[i].lock_on_target, 2)


func test_one_ai_opponent_makes_three_fighters() -> void:
	assert_eq(DuoMatch.new_sim(1, 1).fighters.size(), 3)


func test_the_rules_start_the_next_round_after_a_ko() -> void:
	var sim := DuoMatch.new_sim(1, 1)
	var rules := DuoMatch.new()
	sim.round_over = true
	for i in DuoMatch.NEXT_ROUND_TICKS - 1:
		rules.after_tick(sim)
	assert_true(sim.round_over)
	rules.after_tick(sim)
	assert_false(sim.round_over)
