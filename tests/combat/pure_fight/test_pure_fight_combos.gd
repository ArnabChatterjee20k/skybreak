extends GutTest
## Motion inputs, combos, scaling, juggles, wall/ground bounces, counters and the finisher.

const S := PureFighter.State


func _history(dirs: Array) -> PureFighter:
	var fighter := PureFighter.new()
	for d in dirs:
		fighter.push_dir(d)
	return fighter


func test_quarter_circles_and_dragon_punches_read_leniently() -> void:
	assert_true(MotionInput.matches(_history([5, 2, 3, 6]), &"236"))
	assert_true(MotionInput.matches(_history([2, 2, 5, 6]), &"236"), "the diagonal may be skipped")
	assert_true(MotionInput.matches(_history([2, 1, 4]), &"214"))
	assert_true(MotionInput.matches(_history([6, 5, 2, 3]), &"623"))
	assert_true(MotionInput.matches(_history([2, 3, 6, 2, 3, 6]), &"236236"))
	assert_true(MotionInput.matches(_history([5, 6, 5, 6]), &"66"))
	assert_true(MotionInput.matches(_history([5, 4, 5, 4]), &"44"))


func test_motions_reject_the_wrong_shapes_and_slow_inputs() -> void:
	assert_false(MotionInput.matches(_history([5, 2, 3]), &"236"), "down-forward alone is not a quarter circle")
	assert_false(MotionInput.matches(_history([5, 6, 6, 6]), &"66"), "holding forward is not a dash")
	var slow: Array = [2]
	for i in 20:
		slow.append(5)
	slow.append(6)
	assert_false(MotionInput.matches(_history(slow), &"236"), "too slow")
	var stale: Array = [2, 3, 6]
	for i in 10:
		stale.append(5)
	assert_false(MotionInput.matches(_history(stale), &"236"), "the motion went stale")


func test_a_motion_plus_attack_starts_the_technique_and_the_technique_key_does_too() -> void:
	var sim := PureFightDriver.fighting()
	var driver := PureFightDriver.new(sim)
	driver.sequence([[2, ""], [3, ""], [6, "L"]])
	assert_eq(sim.pf[0].move, &"iron_lunge")
	sim = PureFightDriver.fighting()
	driver = PureFightDriver.new(sim)
	driver.step([2, "T"])
	assert_eq(sim.pf[0].move, &"skyward_fist", "technique key + down")


func test_damage_scales_down_through_a_combo() -> void:
	assert_eq(PureFightSim._scale(1), 100)
	assert_eq(PureFightSim._scale(2), 100)
	assert_eq(PureFightSim._scale(3), 85)
	assert_eq(PureFightSim._scale(10), 30, "never below 30%")
	var sim := PureFightDriver.fighting([&"kael", &"vexa"] as Array[StringName], 650)
	var driver := PureFightDriver.new(sim)
	# 5L > 5M target combo, cancelled into Iron Lunge.
	driver.step([5, "L"])
	driver.hold(9)
	driver.step([5, "M"])
	driver.hold(8)
	driver.sequence([[2, ""], [3, ""], [6, "H"]])
	driver.hold(60)
	var raw := 30 + 45 + 100
	assert_eq(sim.pf[1].combo_hits, 0, "the combo ended")
	var lost := sim.pf[1].max_health - sim.pf[1].health
	assert_true(lost > 0 and lost < raw, "scaled: %d < %d" % [lost, raw])


func test_a_launcher_juggles_and_the_juggle_limit_ends_it() -> void:
	var sim := PureFightDriver.fighting([&"kael", &"vexa"] as Array[StringName], 600)
	var driver := PureFightDriver.new(sim)
	sim._start_move(0, &"2H")
	driver.hold(12)
	assert_eq(sim.pf[1].state, S.JUGGLE, "launched")
	sim.pf[1].juggle_points = PureFightSim.JUGGLE_LIMIT
	assert_true(sim._strike_invulnerable(sim.pf[1]), "past the limit the target falls out")


func test_a_wall_bounce_happens_once_per_combo() -> void:
	var sim := PureFightDriver.fighting([&"kael", &"vexa"] as Array[StringName], 600)
	var driver := PureFightDriver.new(sim)
	sim.pf[0].x = PureFightSim.WALL - 1600
	sim.pf[1].x = PureFightSim.WALL - 1000
	sim._start_move(0, &"6H")
	var bounces := 0
	for t in 120:
		driver.step()
		for e in sim.events:
			bounces += 1 if e.type == PureFightSim.Ev.WALL_BOUNCE else 0
		if t == 40 and sim.pf[1].state == S.JUGGLE:
			sim._start_move(0, &"6H")
	assert_eq(bounces, 1)
	assert_true(sim.pf[1].wall_bounce_used or sim.pf[1].combo_hits == 0)


func test_a_ground_bounce_pops_the_target_back_up_once() -> void:
	var sim := PureFightDriver.fighting([&"kael", &"vexa"] as Array[StringName], 600)
	var driver := PureFightDriver.new(sim)
	sim._start_move(0, &"ridgeback_kick")
	var bounces := 0
	for t in 90:
		driver.step()
		for e in sim.events:
			bounces += 1 if e.type == PureFightSim.Ev.GROUND_BOUNCE else 0
	assert_eq(bounces, 1)


func test_hitting_a_move_in_startup_is_a_counter_hit_with_bonus_damage() -> void:
	var sim := PureFightDriver.fighting([&"kael", &"vexa"] as Array[StringName], 650)
	var driver := PureFightDriver.new(sim)
	sim._start_move(1, &"5H")
	driver.step([5, "L"])
	var counter := false
	for i in 6:
		driver.step()
		for e in sim.events:
			counter = counter or e.type == PureFightSim.Ev.COUNTER
	assert_true(counter)
	assert_eq(sim.pf[1].max_health - sim.pf[1].health, 30 * 12 / 10)


func test_the_finisher_needs_a_full_meter_and_spends_it() -> void:
	var sim := PureFightDriver.fighting([&"lyra", &"kael"] as Array[StringName], 900)
	var driver := PureFightDriver.new(sim)
	driver.step([5, "F"])
	assert_ne(sim.pf[0].move, &"constellation", "no meter, no finisher")
	driver.hold(30)
	sim.pf[0].meter = PureMoves.METER_MAX
	driver.step([5, "F"])
	assert_eq(sim.pf[0].move, &"constellation")
	assert_eq(sim.pf[0].meter, 0)
	var connected := false
	for i in 140:
		driver.step()
		for e in sim.events:
			connected = connected or e.type == PureFightSim.Ev.FINISHER_HIT
	assert_true(connected, "the cinematic plays")
	assert_lt(sim.pf[1].health, sim.pf[1].max_health - 250)


func test_lyras_counter_stance_answers_a_strike() -> void:
	var sim := PureFightDriver.fighting([&"lyra", &"kael"] as Array[StringName], 650)
	var driver := PureFightDriver.new(sim)
	sim._start_move(0, &"starguard")
	driver.hold(2)
	sim._start_move(1, &"5M")
	var countered := false
	for i in 20:
		driver.step()
		for e in sim.events:
			countered = countered or e.type == PureFightSim.Ev.COUNTER_STANCE
	assert_true(countered)
	assert_eq(sim.pf[0].health, sim.pf[0].max_health)
	assert_lt(sim.pf[1].health, sim.pf[1].max_health)


func test_brann_armour_absorbs_one_hit() -> void:
	var sim := PureFightDriver.fighting([&"brann", &"kael"] as Array[StringName], 650)
	var driver := PureFightDriver.new(sim)
	sim._start_move(0, &"6H")
	driver.hold(5)
	sim._start_move(1, &"5L")
	var armored := false
	for i in 8:
		driver.step()
		for e in sim.events:
			armored = armored or e.type == PureFightSim.Ev.ARMOR
	assert_true(armored)
	assert_eq(sim.pf[0].state, S.ATTACK, "Brann keeps going")
