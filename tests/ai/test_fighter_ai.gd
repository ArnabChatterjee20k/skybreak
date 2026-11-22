extends GutTest
## FighterAI and AIDriver: determinism, level ordering, punishes, weapons,
## stuck states, defence, free-for-all targets, rollback and CPU cost.

const E := CombatSim.EventType
const S := FighterState.State
const A := FighterInput.Action
const BOUT_TICKS := 5400
const LEVEL_SEEDS := 20


func _record_inputs(bout: AIBout, ticks: int) -> PackedInt64Array:
	var record := PackedInt64Array()
	for _tick in ticks:
		for input in bout.step():
			record.append(hash([input.held_actions, input.move, input.vertical, input.target_switch]))
		if bout.sim.round_over:
			bout.sim.start_round()
	return record


func test_the_same_seed_gives_the_same_inputs_and_state_hash_after_3600_ticks() -> void:
	var first := AIBout.new(77, [5, 3])
	var second := AIBout.new(77, [5, 3])
	var first_inputs := _record_inputs(first, 3600)
	var second_inputs := _record_inputs(second, 3600)
	assert_eq(first_inputs, second_inputs, "same AI inputs every tick")
	assert_eq(first.sim.state_hash(), second.sim.state_hash())
	var other := AIBout.new(78, [5, 3])
	_record_inputs(other, 3600)
	assert_ne(first.sim.state_hash(), other.sim.state_hash(), "a different seed plays differently")


func test_the_ai_never_touches_the_sim_rng() -> void:
	var bout := AIBout.new(5, [4, 4])
	var state := bout.sim.rng.state
	for _tick in 600:
		bout.driver.inputs_for(bout.sim)
		bout.sim.current_tick += 1
	assert_eq(bout.sim.rng.state, state)


func test_each_level_beats_the_level_below_in_most_of_20_seeded_bouts() -> void:
	var lines: Array[String] = []
	for low in range(1, AIProfile.MAX_LEVEL):
		var high := low + 1
		var high_wins := 0
		var low_wins := 0
		for s in LEVEL_SEEDS:
			# Alternate sides so slot order cannot decide it.
			var high_slot := s % 2
			var levels := [low, low]
			levels[high_slot] = high
			var winner := AIBout.new(9000 + 31 * s + low, levels).play(BOUT_TICKS)
			if winner == high_slot:
				high_wins += 1
			elif winner >= 0:
				low_wins += 1
		lines.append("L%d vs L%d: L%d wins %d/%d (%d%%), L%d wins %d, draws %d" % [high, low, high,
			high_wins, LEVEL_SEEDS, high_wins * 100 / LEVEL_SEEDS, low, low_wins,
			LEVEL_SEEDS - high_wins - low_wins])
		assert_gt(high_wins, LEVEL_SEEDS / 2, lines[-1])
	gut.p("Win rates:\n" + "\n".join(lines))


## A dummy that walks in and whiffs a neutral heavy (smash) at max range once.
class WhiffDummy:
	var pressed_at := -1
	var _previous := FighterInput.new()

	func next_input(sim: CombatSim, index: int, ai_index: int) -> FighterInput:
		var me := sim.fighters[index]
		var distance := me.position.distance_to(sim.fighters[ai_index].position)
		var held := 0
		var move := Vector2.ZERO
		if pressed_at < 0 and sim.current_tick > 20 and me.state in [S.IDLE, S.MOVING]:
			if distance < 6.2 and distance > 5.2:
				held = A.HEAVY
				pressed_at = sim.current_tick
			elif distance >= 6.2:
				move = Vector2(0, 0.5)
		var input := FighterInput.from_held(held, _previous)
		input.move = move
		_previous = input
		return input


func test_level_5_punishes_a_whiffed_heavy_at_least_80_percent_of_the_time() -> void:
	var whiffs := 0
	var punished := 0
	for trial in 40:
		var sim := CombatSim.new(500 + trial)
		sim.add_fighter(Vector3(0, 1, 5.0 + 0.1 * (trial % 10)))
		sim.add_fighter(Vector3(0, 1, -5.0))
		sim.lock_everyone_onto_nearest()
		var ai := FighterAI.new(0, 5, FighterAI.seed_for(500 + trial, 0))
		var dummy := WhiffDummy.new()
		var touched := false
		var hit := false
		for _tick in 240:
			var inputs: Array[FighterInput] = [ai.next_input(sim), dummy.next_input(sim, 1, 0)]
			sim.tick(inputs)
			if dummy.pressed_at < 0:
				continue
			var heavy := sim.fighters[1].move_id() == &"smash"
			for event in sim.events:
				if event.get("attacker", -1) == 1:
					touched = true
				elif event.get("attacker", -1) == 0 and event.type in [E.HIT, E.COUNTER] \
						and (heavy or sim.current_tick - dummy.pressed_at <= 42):
					hit = true
			if sim.current_tick - dummy.pressed_at > 60:
				break
		if dummy.pressed_at < 0 or touched:
			continue
		whiffs += 1
		if hit:
			punished += 1
	gut.p("level 5 punished %d of %d whiffed heavies" % [punished, whiffs])
	assert_gte(whiffs, 15, "enough whiffs to judge")
	assert_gte(punished * 100, whiffs * 80, "punished %d of %d" % [punished, whiffs])


func test_the_ai_picks_up_weapons_and_uses_them() -> void:
	var picked := 0
	var used := 0
	for s in 3:
		var bout := AIBout.new(300 + s, [4, 4], true)
		for _tick in 3600:
			bout.step()
			for event in bout.sim.events:
				if event.type == E.PICKUP:
					picked += 1
				elif event.type in [E.FIRE, E.WEAPON_THROW]:
					used += 1
				elif event.type in [E.HIT, E.BLOCK, E.COUNTER] and String(event.move_id).contains("/"):
					used += 1
			if bout.sim.round_over:
				bout.sim.start_round()
	gut.p("pickups %d, weapon uses %d" % [picked, used])
	assert_gt(picked, 0, "picked a weapon up")
	assert_gt(used, 0, "fired, threw or hit with a weapon")


func test_the_ai_goes_for_a_weapon_lying_nearby() -> void:
	var sim := CombatSim.new(41)
	sim.add_fighter(Vector3(0, 1, 30))
	sim.add_fighter(Vector3(0, 1, -30))
	sim.lock_everyone_onto_nearest()
	var pickup := WeaponPickup.new()
	pickup.id = 999
	pickup.kind = Weapon.Kind.KI_BOW
	pickup.ammo = Weapon.full_ammo(Weapon.Kind.KI_BOW)
	pickup.position = Vector3(8, sim.floor_height() + 0.6, 30)
	pickup.phase = WeaponPickup.Phase.GROUNDED
	pickup.ticks_left = 100000
	sim.pickups.append(pickup)
	var ai := FighterAI.new(0, 5, 41)
	var fired := false
	for _tick in 900:
		var inputs: Array[FighterInput] = [ai.next_input(sim), FighterInput.new()]
		sim.tick(inputs)
		for event in sim.events:
			fired = fired or (event.type == E.FIRE and event.fighter == 0)
		if fired:
			break
	assert_eq(sim.fighters[0].weapons.count(Weapon.Kind.KI_BOW), 1, "picked up the bow")
	assert_true(fired, "shot the bow from range")


func test_no_ai_fighter_is_stuck_for_more_than_5_seconds() -> void:
	var limit := 5 * CombatSim.TICKS_PER_SECOND
	for levels in [[1, 5], [3, 3], [5, 5], [2, 4, 5]]:
		var bout := AIBout.new(4242, levels, true)
		var still: Array[int] = []
		var last_state: Array[int] = []
		var last_position: Array[Vector3] = []
		for i in levels.size():
			still.append(0)
			last_state.append(-1)
			last_position.append(Vector3.ZERO)
		var worst := 0
		for _tick in 3600:
			bout.step()
			if bout.sim.round_over:
				bout.sim.start_round()
			for i in levels.size():
				var fighter := bout.sim.fighters[i]
				if fighter.is_knocked_out():
					still[i] = 0
					continue
				var same := fighter.state == last_state[i] \
					and fighter.position.distance_to(last_position[i]) < 0.01
				still[i] = still[i] + 1 if same else 0
				worst = maxi(worst, still[i])
				last_state[i] = fighter.state
				last_position[i] = fighter.position
		assert_lte(worst, limit, "levels %s: longest still spell %d ticks" % [levels, worst])


func test_the_ai_attacks_an_idle_dummy_within_5_seconds_or_10_on_easy() -> void:
	for level in range(1, 6):
		var bout := AIBout.new(60 + level, [level, 0])
		var first_hit := -1
		while bout.ticks < 600 and first_hit < 0:
			bout.step()
			for event in bout.sim.events:
				if event.type in [E.HIT, E.COUNTER, E.GRAB] and event.attacker == 0:
					first_hit = bout.ticks
		var limit := 600 if level == 1 else 300
		assert_between(first_hit, 1, limit, "level %d first hit on tick %d" % [level, first_hit])


## Throws one breaker (18 ticks of startup) as the AI walks into its reach.
class BreakerDummy:
	var pressed_at := -1
	var _previous := FighterInput.new()

	func next_input(sim: CombatSim) -> FighterInput:
		var distance := sim.fighters[1].position.distance_to(sim.fighters[0].position)
		var held := 0
		if pressed_at < 0 and sim.current_tick > 20 and distance < 3.4 \
				and sim.fighters[1].state in [S.IDLE, S.MOVING, S.FLYING]:
			held = A.HEAVY
			pressed_at = sim.current_tick
		var input := FighterInput.from_held(held, _previous)
		input.move = Vector2(0, 1) if held else Vector2.ZERO
		_previous = input
		return input


## [answered (guarded, perfect-blocked or beaten to it), perfect blocks, breakers thrown].
func _answer_breakers(level: int, trials: int) -> Array[int]:
	var result: Array[int] = [0, 0, 0]
	for trial in trials:
		var sim := CombatSim.new(700 + trial)
		sim.add_fighter(Vector3(0, 1, 4.5))
		sim.add_fighter(Vector3(0, 1, -4.5))
		sim.lock_everyone_onto_nearest()
		var ai := FighterAI.new(0, level, FighterAI.seed_for(700 + trial, 0))
		var dummy := BreakerDummy.new()
		var answered := false
		var resolved := false
		for _tick in 200:
			var inputs: Array[FighterInput] = [ai.next_input(sim), dummy.next_input(sim)]
			sim.tick(inputs)
			if dummy.pressed_at < 0:
				continue
			for event in sim.events:
				if event.get("attacker", -1) == 1 and event.move_id == &"breaker":
					resolved = true
					answered = event.type in [E.BLOCK, E.PERFECT_BLOCK]
					if event.type == E.PERFECT_BLOCK:
						result[1] += 1
				elif event.get("attacker", -1) == 0 and event.type == E.COUNTER:
					resolved = true
					answered = true
			if resolved or sim.current_tick - dummy.pressed_at > 45:
				break
		if dummy.pressed_at >= 0 and resolved:
			result[2] += 1
			if answered:
				result[0] += 1
	return result


func test_level_5_answers_seen_heavies_and_level_1_rarely_does() -> void:
	var strong := _answer_breakers(5, 40)
	var easy := _answer_breakers(1, 40)
	gut.p("breakers answered: level 5 %d of %d (perfect %d), level 1 %d of %d (perfect %d)" % [
		strong[0], strong[2], strong[1], easy[0], easy[2], easy[1]])
	assert_gte(strong[2], 20, "enough breakers reached the AI")
	assert_gte(strong[0] * 100, strong[2] * 70, "level 5 guards or beats most seen heavies")
	assert_gt(strong[1], 0, "level 5 perfect-blocks some")
	assert_lt(easy[0] * strong[2], strong[0] * easy[2], "level 1 answers a smaller share")


func test_level_5_techs_most_grabs_and_level_1_few() -> void:
	var teched: Array[int] = [0, 0]
	var grabbed: Array[int] = [0, 0]
	for column in 2:
		var level := 5 if column == 0 else 1
		for trial in 60:
			var sim := CombatSim.new(800 + trial)
			sim.add_fighter(Vector3(0, 1, 1.2))
			sim.add_fighter(Vector3(0, 1, -0.6))
			sim.lock_everyone_onto_nearest()
			var ai := FighterAI.new(0, level, FighterAI.seed_for(800 + trial, 0))
			var previous := FighterInput.new()
			for tick in 60:
				var dummy := FighterInput.from_held(A.GRAB if tick == 1 else 0, previous)
				previous = dummy
				var inputs: Array[FighterInput] = [ai.next_input(sim), dummy]
				sim.tick(inputs)
				for event in sim.events:
					if event.type == E.GRAB and event.attacker == 1:
						grabbed[column] += 1
					elif event.type == E.GRAB_TECH:
						teched[column] += 1
	gut.p("grabs teched: level 5 %d of %d, level 1 %d of %d" % [teched[0], grabbed[0], teched[1], grabbed[1]])
	assert_gte(grabbed[0], 15, "enough grabs landed")
	assert_gt(teched[0] * 2, grabbed[0], "level 5 techs most")
	assert_lt(teched[1] * 4, maxi(grabbed[1], 1), "level 1 techs few")


func test_free_for_all_targets_skip_teammates_and_turn_on_whoever_attacks() -> void:
	var sim := CombatSim.new(9)
	sim.add_fighter(Vector3(0, 1, 0))
	sim.add_fighter(Vector3(0, 1, -4))
	sim.add_fighter(Vector3(0, 1, 12))
	sim.lock_everyone_onto_nearest()
	var driver := AIDriver.for_sim(sim, [
		{"character": &"kael", "team": 0, "is_ai": true, "ai_level": 4},
		{"character": &"kael", "team": 0, "is_ai": false},
		{"character": &"kael", "team": 1, "is_ai": false},
	])
	for _tick in 40:
		sim.tick(driver.inputs_for(sim))
	assert_eq(sim.fighters[0].lock_on_target, 2, "locks onto the opponent, not the nearer teammate")
	# Free-for-all: the far fighter keeps hitting it, so it turns on that one.
	var ffa := CombatSim.new(10)
	ffa.add_fighter(Vector3(0, 1, 0))
	ffa.add_fighter(Vector3(0, 1, -3))
	ffa.add_fighter(Vector3(0, 1, 9))
	ffa.lock_everyone_onto_nearest()
	var ai := FighterAI.new(0, 4, 10)
	for tick in 120:
		ffa.tick([ai.next_input(ffa), FighterInput.new(), FighterInput.new()] as Array[FighterInput])
		if tick == 20:
			assert_eq(ai._target, 1, "the nearest at first")
		if tick % 10 == 0:
			# The far fighter hits it now and then (events are what the AI reads).
			ffa.events = [{"type": E.HIT, "attacker": 2, "target": 0}]
	assert_eq(ai._target, 2, "whoever attacks it")


func test_the_driver_follows_the_menu_contract_and_leaves_humans_alone() -> void:
	var sim := CombatSim.new(3)
	sim.add_fighter(Vector3(0, 1, 6))
	sim.add_fighter(Vector3(0, 1, -6))
	var driver := AIDriver.for_sim(sim, [
		{"character": &"kael", "team": 0, "is_ai": false, "ai_level": 0},
		{"character": &"vexa", "team": 1, "is_ai": true, "ai_level": 5},
	])
	assert_false(driver.is_ai(0))
	assert_true(driver.is_ai(1))
	assert_eq(driver.ais[1].profile.level, 5)
	var human := FighterInput.new()
	human.held_actions = A.LIGHT
	var inputs := driver.inputs_for(sim, [human, null] as Array[FighterInput])
	assert_same(inputs[0], human)
	assert_not_null(inputs[1])
	assert_eq(AIDriver.new([{"is_ai": true, "ai_level": 99}]).ais[0].profile.level, 5, "levels clamp")


func test_a_restored_snapshot_continues_with_the_same_inputs() -> void:
	var bout := AIBout.new(123, [5, 4])
	for _tick in 600:
		bout.step()
	var original: FighterAI = bout.driver.ais[0]
	var copy := FighterAI.new(0, 1, 1)
	copy.restore(original.snapshot())
	copy.profile = original.profile
	for _tick in 300:
		var expected := original.next_input(bout.sim)
		var got := copy.next_input(bout.sim)
		assert_eq([got.held_actions, got.move, got.vertical], [expected.held_actions, expected.move,
			expected.vertical])
		var inputs: Array[FighterInput] = [expected, bout.driver.ais[1].next_input(bout.sim)]
		bout.sim.tick(inputs)
		if bout.sim.round_over:
			break


func test_level_3_and_up_never_open_the_same_string_twice_in_a_row() -> void:
	# #106: one route and length per level replayed the same 2-5 hit string and launcher every exchange.
	for level in [3, 4, 5]:
		var ai := FighterAI.new(0, level, 9)
		var opened: Array[int] = []
		for _i in 8:
			ai.call(&"_start_string", FighterInput.new(), 3)
			opened.append(ai.get(&"_last_string"))
		for i in range(1, opened.size()):
			assert_ne(opened[i], opened[i - 1], "level %d string %d: %s" % [level, i, opened])
	var easy := FighterAI.new(0, 2, 9)
	easy.call(&"_start_string", FighterInput.new(), 3)
	var first: int = easy.get(&"_last_string")
	easy.call(&"_start_string", FighterInput.new(), 3)
	assert_eq(easy.get(&"_last_string"), first, "easy AIs keep one simple string")


func test_an_ai_costs_at_most_0_05_ms_per_tick() -> void:
	var bout := AIBout.new(31, [5, 5], true)
	for _tick in 300:
		bout.step()
	var ticks := 0
	var spent := 0
	for _tick in 3000:
		var start := Time.get_ticks_usec()
		var inputs := bout.driver.inputs_for(bout.sim)
		spent += Time.get_ticks_usec() - start
		bout.sim.tick(inputs)
		ticks += 1
		if bout.sim.round_over:
			bout.sim.start_round()
	var per_ai_ms := float(spent) / ticks / 2.0 / 1000.0
	gut.p("AI cost: %.4f ms per AI per tick" % per_ai_ms)
	assert_lte(per_ai_ms, 0.05)


# --- PB3-1: up close the pickup plan used to lose to PRESSURE every time ---

func _close_duel_with_a_drop(seed_value: int) -> CombatSim:
	var sim := CombatSim.new(seed_value)
	sim.add_fighter(Vector3(0, 1, 0))
	sim.add_fighter(Vector3(0, 1, -3))  # 3 m: well inside PRESSURE range
	sim.lock_everyone_onto_nearest()
	var pickup := WeaponPickup.new()
	pickup.id = 999
	pickup.kind = Weapon.Kind.STORM_BLADE
	pickup.position = Vector3(6, sim.floor_height() + 0.6, 1)  # nearer to fighter 0
	pickup.phase = WeaponPickup.Phase.GROUNDED
	pickup.ticks_left = 100000
	sim.pickups.append(pickup)
	return sim


func test_unarmed_up_close_a_reachable_drop_outscores_pressure() -> void:
	var sim := _close_duel_with_a_drop(5)
	var ai := FighterAI.new(0, 3, 5)
	var me := sim.fighters[0]
	var pressure := ai.profile.aggression + 0.25
	assert_gt(ai._pickup_score(sim, me, sim.fighters[1], 3.0), pressure,
		"an unarmed level-3 fighter goes for a drop it reaches first")


func test_no_pickup_run_while_the_opponent_swings_at_point_blank() -> void:
	var sim := _close_duel_with_a_drop(5)
	var ai := FighterAI.new(0, 5, 5)
	var target := sim.fighters[1]
	target.state = FighterState.State.ATTACKING
	assert_eq(ai._pickup_score(sim, sim.fighters[0], target, 2.0), 0.0, "no suicidal grab mid-combo")


func test_level_3_grabs_a_nearby_drop_in_a_close_duel_on_most_seeds() -> void:
	var grabbed := 0
	for trial in 10:
		var sim := _close_duel_with_a_drop(900 + trial)
		var ai := FighterAI.new(0, 3, FighterAI.seed_for(900 + trial, 0))
		for _tick in 300:  # 5 s
			var inputs: Array[FighterInput] = [ai.next_input(sim), FighterInput.new()]
			sim.tick(inputs)
			if sim.fighters[0].held_weapon() != Weapon.Kind.NONE or sim.fighters[0].weapon_count() > 0:
				grabbed += 1
				break
	assert_gte(grabbed, 7, "grabbed the drop within 5 s in %d of 10 close duels" % grabbed)
