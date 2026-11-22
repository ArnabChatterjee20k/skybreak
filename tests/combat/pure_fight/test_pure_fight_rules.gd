extends GutTest
## Pure Fight rules (GAME_DESIGN §16): the fight line, walls, rounds and timer, throws,
## blocking, and that nothing from the flight game leaks in.

const S := PureFighter.State


func test_fighters_only_ever_move_along_the_line_inside_the_walls() -> void:
	var sim := PureFightSim.new(4, [&"vexa", &"brann"] as Array[StringName])
	var ais: Array[PureFightAI] = []
	for i in 2:
		var ai := PureFightAI.new()
		ai.setup(i, 5, 9)
		ai.explore = 0.4
		ais.append(ai)
	for t in 6000:
		sim.tick([ais[0].next_input(sim), ais[1].next_input(sim)] as Array[FighterInput])
		for fighter in sim.pf:
			assert_true(absi(fighter.x) <= PureFightSim.WALL, "inside the walls at tick %d" % t)
			assert_true(fighter.y >= 0 and fighter.y < 3000, "above the floor, never flying")
			if absi(fighter.x) > PureFightSim.WALL or fighter.y < 0:
				return
	var world := sim.world_feet(0)
	var along := sim.line_dir * (sim.pf[0].x / 1000.0) + Vector3.UP * (sim.pf[0].y / 1000.0)
	assert_almost_eq(world.distance_to(sim.line_origin + along), 0.0, 0.0001, "world position is on the line")


func test_walking_back_stops_at_the_wall() -> void:
	var sim := PureFightDriver.fighting()
	var driver := PureFightDriver.new(sim)
	driver.hold(500, [4, ""], [6, ""])
	assert_eq(sim.pf[0].x, -PureFightSim.WALL, "the wall holds")
	assert_true(sim.pf[1].x - sim.pf[0].x >= sim.body_gap(), "bodies never overlap")


func test_fighters_cannot_walk_further_apart_than_the_camera_allows() -> void:
	var sim := PureFightDriver.fighting()
	var driver := PureFightDriver.new(sim)
	driver.hold(400, [4, ""], [4, ""])
	assert_true(sim.pf[1].x - sim.pf[0].x <= PureFightSim.MAX_SEPARATION)


func test_pushback_at_the_wall_moves_the_attacker_instead() -> void:
	var sim := PureFightDriver.fighting()
	var driver := PureFightDriver.new(sim)
	sim.pf[1].x = PureFightSim.WALL
	sim.pf[0].x = PureFightSim.WALL - 700
	var before := sim.pf[0].x
	driver.step([5, "H"], [5, ""])
	driver.hold(40)
	assert_eq(sim.pf[1].x, PureFightSim.WALL, "the defender stays at the wall")
	assert_lt(sim.pf[0].x, before, "the attacker is pushed back")


func test_the_timer_runs_99_seconds_and_more_health_wins_the_round() -> void:
	var sim := PureFightDriver.fighting()
	var driver := PureFightDriver.new(sim)
	assert_eq(sim.timer_ticks, PureFightSim.ROUND_SECONDS * 60)
	sim.pf[1].health -= 100
	sim.timer_ticks = 2
	driver.hold(3)
	assert_true(sim.round_over, "time up ends the round")
	assert_eq(sim.round_winner, 0, "the healthier fighter wins")
	assert_eq(sim.pf[0].round_wins, 1)


func test_a_match_is_best_of_three_rounds() -> void:
	var sim := PureFightDriver.fighting()
	var driver := PureFightDriver.new(sim)
	for round in 2:
		while sim.phase != PureFightSim.Phase.FIGHT:
			driver.step()
		sim.pf[1].health = 1
		sim.pf[0].x = -300
		sim.pf[1].x = 300
		driver.step([5, "L"])
		driver.hold(20)
		assert_eq(sim.pf[0].round_wins, round + 1, "a KO wins round %d" % (round + 1))
		driver.hold(PureFightSim.ROUND_END_TICKS)
	assert_true(sim.is_match_over(), "two round wins take the match")
	assert_eq(sim.match_winner, 0)


func test_a_new_round_restores_health_and_marks_but_keeps_meter() -> void:
	var sim := PureFightDriver.fighting()
	var driver := PureFightDriver.new(sim)
	sim.pf[0].meter = 600
	sim.pf[1].health = 1
	sim.pf[0].x = -300
	sim.pf[1].x = 300
	driver.step([5, "L"])
	driver.hold(PureFightSim.ROUND_END_TICKS + 5)
	assert_eq(sim.round_number, 2)
	assert_eq(sim.pf[1].health, sim.pf[1].max_health)
	assert_eq(sim.pf[0].x, -PureFightSim.START_GAP / 2)
	assert_gte(sim.pf[0].meter, 600, "meter carries over")


func test_a_throw_connects_up_close_and_deals_its_damage() -> void:
	var sim := PureFightDriver.fighting([&"kael", &"vexa"] as Array[StringName], 700)
	var driver := PureFightDriver.new(sim)
	driver.step([5, "G"])
	driver.hold(6)
	assert_eq(sim.pf[1].state, S.THROWN)
	driver.hold(PureMoves.THROW_TICKS)
	assert_eq(sim.pf[1].health, sim.pf[1].max_health - int(PureMoves.get_move(&"kael", &"throw").damage))


func test_pressing_throw_inside_the_window_breaks_the_throw() -> void:
	var sim := PureFightDriver.fighting([&"kael", &"vexa"] as Array[StringName], 700)
	var driver := PureFightDriver.new(sim)
	driver.step([5, "G"])
	driver.hold(5)
	assert_eq(sim.pf[1].state, S.THROWN)
	driver.step([5, ""], [5, "G"])
	assert_eq(sim.pf[1].state, S.TECH, "a tech")
	assert_eq(sim.pf[0].state, S.TECH)
	driver.hold(PureMoves.TECH_TICKS + 2)
	assert_eq(sim.pf[1].health, sim.pf[1].max_health, "no damage on a tech")


func test_a_late_throw_break_does_nothing() -> void:
	var sim := PureFightDriver.fighting([&"kael", &"vexa"] as Array[StringName], 700)
	var driver := PureFightDriver.new(sim)
	driver.step([5, "G"])
	driver.hold(5 + PureMoves.THROW_TECH_WINDOW + 2)
	driver.step([5, ""], [5, "G"])
	assert_eq(sim.pf[1].state, S.THROWN)


func test_the_command_grab_cannot_be_broken() -> void:
	var sim := PureFightDriver.fighting([&"brann", &"kael"] as Array[StringName], 800)
	var driver := PureFightDriver.new(sim)
	driver.sequence([[2, ""], [1, ""], [4, "L"]])
	driver.hold(6)
	assert_eq(sim.pf[1].state, S.THROWN)
	driver.step([5, ""], [5, "G"])
	assert_eq(sim.pf[1].state, S.THROWN, "unbreakable")


func test_throws_miss_jumping_and_blockstunned_fighters() -> void:
	var sim := PureFightDriver.fighting([&"kael", &"vexa"] as Array[StringName], 700)
	var driver := PureFightDriver.new(sim)
	driver.hold(5, [5, ""], [8, ""])
	driver.step([5, "G"])
	driver.hold(6)
	assert_ne(sim.pf[1].state, S.THROWN, "airborne fighters can't be thrown")
	sim = PureFightDriver.fighting([&"kael", &"vexa"] as Array[StringName], 700)
	driver = PureFightDriver.new(sim)
	sim.pf[1].state = S.BLOCKSTUN
	sim.pf[1].stun_left = 30
	driver.step([5, "G"])
	driver.hold(6)
	assert_ne(sim.pf[1].state, S.THROWN, "blockstun is throw-proof")


func test_lows_must_be_blocked_crouching_and_overheads_standing() -> void:
	for case in [[&"2L", 1, true], [&"2L", 4, false], [&"6M", 4, true], [&"6M", 1, false], [&"5M", 1, true]]:
		var sim := PureFightDriver.fighting([&"kael", &"vexa"] as Array[StringName], 650)
		var driver := PureFightDriver.new(sim)
		var id: String = case[0]
		var dir := int(id.substr(0, 1))
		var button := id.substr(1)
		var blocked := false
		driver.step([dir, button], [case[1], ""])
		for i in 30:
			driver.step([5, ""], [case[1], ""])
			for e in sim.events:
				if e.type == PureFightSim.Ev.BLOCK or e.type == PureFightSim.Ev.JUST_DEFEND:
					blocked = true
		assert_eq(blocked, case[2], "%s against hold %d" % [id, case[1]])


func test_blocking_just_before_the_hit_is_a_just_defend_with_less_blockstun() -> void:
	var sim := PureFightDriver.fighting([&"kael", &"vexa"] as Array[StringName], 650)
	var driver := PureFightDriver.new(sim)
	driver.step([5, "H"])
	driver.hold(6, [5, ""], [5, ""])
	var just := false
	for i in 6:
		driver.step([5, ""], [4, ""])
		for e in sim.events:
			just = just or e.type == PureFightSim.Ev.JUST_DEFEND
	assert_true(just, "guard raised inside the window")


func test_ki_flight_specials_and_weapons_do_nothing_in_pure_fight() -> void:
	var sim := PureFightDriver.fighting()
	var driver := PureFightDriver.new(sim)
	var A := FighterInput.Action
	for action in [A.KI_BLAST, A.CHARGE, A.SPECIAL_3, A.TRANSFORM, A.BREAKER, A.PICKUP, A.THROW,
			A.WEAPON_NEXT, A.QUICK_SWAP, A.LOCK_TOGGLE]:
		for t in 30:
			var input := FighterInput.from_held(action if t % 2 == 0 else 0, FighterInput.new())
			sim.tick([input, FighterInput.new()] as Array[FighterInput])
			for e in sim.events:
				assert_ne(e.type, PureFightSim.Ev.MOVE, "action %d starts nothing" % action)
	assert_eq(sim.projectiles.size(), 0)
	assert_eq(sim.beams.size(), 0)
	assert_eq(sim.pickups.size(), 0)
	assert_eq(sim.gadgets.size(), 0)
	assert_false(sim.pickups_enabled)
	assert_eq(sim.pf[0].y, 0, "no flight")
	assert_eq(sim.pf[0].meter, 0, "no ki charging builds meter")
