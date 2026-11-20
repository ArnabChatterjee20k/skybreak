extends GutTest
## The AI's ki game (T-KI1): zoning blasts at range at level-scaled rates,
## occasional beams with their tell, answers to beam tells, clash beats.

const A := FighterInput.Action
const E := CombatSim.EventType
const LYRA := preload("res://game/combat/moves/lyra/lyra_fighter_stats.tres")


## Ki event counts for one AI (fighter 0, legend stats) kept at range (12 m or more) from an idle dummy.
func _zoning(level: int, stats: FighterStats, ticks := 1800, seed_value := 31) -> Dictionary:
	var sim := CombatSim.new(seed_value)
	sim.add_fighter(Vector3(0, 1, 7), stats)
	sim.add_fighter(Vector3(0, 1, -7))
	sim.lock_everyone_onto_nearest()
	var ai := FighterAI.new(0, level, FighterAI.seed_for(seed_value, 0))
	var counts := {"blasts": 0, "charged": 0, "beams": 0}
	for _tick in ticks:
		sim.fighters[1].position = Vector3(0, 1, -7)
		if sim.fighters[0].position.distance_to(sim.fighters[1].position) < 12.0:
			sim.fighters[0].position = Vector3(0, 1, 7)
		sim.fighters[1].health = sim.fighters[1].stats.max_health * FighterState.METER_UNIT
		var inputs: Array[FighterInput] = [ai.next_input(sim), FighterInput.new()]
		sim.tick(inputs)
		for event in sim.events:
			if event.type == E.KI_FIRE:
				counts.blasts += 1
				if event.shot == KiRules.Shot.CHARGED:
					counts.charged += 1
			elif event.type == E.BEAM_START:
				counts.beams += 1
	return counts


func test_a_level_5_lyra_zones_with_blasts_charged_shots_and_beams() -> void:
	var counts := _zoning(5, LYRA, 3600)
	gut.p("L5 Lyra over 60 s at 12-14 m: %s" % counts)
	assert_gt(counts.blasts, 20, "zones with blasts")
	assert_gt(counts.charged, 0, "some charged blasts")
	assert_gt(counts.beams, 0, "an occasional beam")
	assert_lt(counts.beams, 15, "beams stay occasional")


func test_low_levels_zone_less_than_high_levels() -> void:
	var low := _zoning(1, LYRA)
	var high := _zoning(5, LYRA)
	gut.p("Lyra blasts in 30 s: level 1 %d, level 5 %d" % [low.blasts, high.blasts])
	assert_lt(low.blasts, high.blasts)
	assert_eq(low.beams, 0, "Easy never beams")


## Fighter 0 (scripted) fires a beam at the AI; returns what the AI did about it.
func _answer(level: int, seed_value: int) -> Dictionary:
	var sim := CombatSim.new(seed_value)
	sim.add_fighter(Vector3(0, 1, 9))
	sim.add_fighter(Vector3(0, 1, -9))
	sim.lock_everyone_onto_nearest()
	sim.fighters[0].ki = 100 * FighterState.METER_UNIT
	var ai := FighterAI.new(1, level, FighterAI.seed_for(seed_value, 1))
	var previous := FighterInput.new()
	var result := {"hit": false, "blocked": false, "dodged": false, "punished": false}
	for tick in 120:
		var mine := FighterInput.from_held(A.SPECIAL_1 if tick == 0 else 0, previous)
		previous = mine
		var inputs: Array[FighterInput] = [mine, ai.next_input(sim)]
		sim.tick(inputs)
		for event in sim.events:
			if event.type in [E.HIT, E.COUNTER] and event.attacker == 0:
				result.hit = true
			elif event.type == E.BLOCK and event.attacker == 0:
				result.blocked = true
			elif event.type == E.BEAM_END and event.whiff:
				result.dodged = true
			elif event.type in [E.HIT, E.COUNTER] and event.attacker == 1:
				result.punished = true
	return result


func test_a_level_5_ai_reads_beam_tells_by_sidestepping_blocking_or_striking_the_startup() -> void:
	var answered := 0
	var dodged := 0
	for trial in 20:
		var result := _answer(5, 400 + trial)
		if result.blocked or result.dodged or result.punished:
			answered += 1
		if result.dodged:
			dodged += 1
	gut.p("L5 vs 20 beams from 18 m: answered %d, sidestepped %d" % [answered, dodged])
	assert_gte(answered, 15, "most beams are answered")


func test_far_from_a_locked_beam_tell_a_level_5_ai_often_sidesteps() -> void:
	var sidesteps := 0
	for trial in 20:
		var sim := CombatSim.new(trial)
		sim.add_fighter(Vector3(0, 1, 15))
		sim.add_fighter(Vector3(0, 1, -15))
		sim.lock_everyone_onto_nearest()
		var beamer := sim.fighters[0]
		beamer.ki = 100 * FighterState.METER_UNIT
		var kit := KiRules.kit_of(beamer)
		KiRules._begin(sim, 0, kit.beam)
		beamer.move_tick = kit.beam.startup_ticks - AIKi.LATE_SIDESTEP_TICKS
		var ai := FighterAI.new(1, 5, trial)
		var plan := FighterInput.new()
		if ai._ki_game.answer_beams(ai, sim, sim.fighters[1], plan) and (plan.held_actions & A.DASH) != 0:
			sidesteps += 1
	gut.p("L5 sidesteps of 20 locked beam tells at 30 m: %d" % sidesteps)
	assert_gte(sidesteps, 8, "sidestep is its main answer at range")


func test_ai_plays_beam_clash_beats_by_level() -> void:
	var good := [0, 0]
	for column in 2:
		var level := 5 if column == 0 else 1
		var sim := CombatSim.new(77)
		sim.add_fighter(Vector3(0, 1, 12))
		sim.add_fighter(Vector3(0, 1, -12))
		sim.lock_everyone_onto_nearest()
		for fighter in sim.fighters:
			fighter.ki = 100 * FighterState.METER_UNIT
		var ai := FighterAI.new(1, level, FighterAI.seed_for(77, 1))
		var previous := FighterInput.new()
		var clash: BeamClash = null
		for tick in 400:
			var mine := FighterInput.from_held(A.SPECIAL_1 if tick == 0 else 0, previous)
			previous = mine
			var theirs := ai.next_input(sim)
			if tick == 0:
				theirs = FighterInput.from_held(A.SPECIAL_1, FighterInput.new())
			var inputs: Array[FighterInput] = [mine, theirs]
			sim.tick(inputs)
			if clash == null and not sim.beam_clashes.is_empty():
				clash = sim.beam_clashes[0]
		assert_not_null(clash, "clashed")
		if clash != null:
			good[column] = clash.good[1]
	gut.p("clash beats hit: level 5 %d, level 1 %d of %d" % [good[0], good[1], CombatSim.DEFAULT_KI_TUNING.clash_beats])
	assert_gte(good[0], 3, "level 5 hits most beats")
	assert_gt(good[0], good[1])


func test_the_ki_game_survives_snapshot_and_restore() -> void:
	var ai := FighterAI.new(0, 4, 5)
	ai._ki_game._hold_q = 9
	ai._ki_game._last_blast = 123
	var saved := ai.snapshot()
	var other := FighterAI.new(0, 4, 5)
	other.restore(saved)
	assert_eq(other._ki_game.snapshot_values(), ai._ki_game.snapshot_values())


func test_once_a_beam_is_in_its_recovery_the_ai_stops_guarding_it() -> void:
	var sim := CombatSim.new(3)
	sim.add_fighter(Vector3(0, 1, 15))
	sim.add_fighter(Vector3(0, 1, -15))
	sim.lock_everyone_onto_nearest()
	var kit := KiRules.kit_of(sim.fighters[0])
	KiRules._begin(sim, 0, kit.beam)
	sim.fighters[0].move_tick = kit.beam.recovery_start_tick() + 2
	var ai := FighterAI.new(1, 5, 3)
	assert_false(ai._ki_game.answer_beams(ai, sim, sim.fighters[1], FighterInput.new()), "free to punish")


## A beam tell locked at fighter 1 from 30 m, until_fire ticks before it fires; what a level-l AI holds.
func _tell_answer(level: int, until_fire: int, trial: int) -> FighterInput:
	var sim := CombatSim.new(trial)
	sim.add_fighter(Vector3(0, 1, 15))
	sim.add_fighter(Vector3(0, 1, -15))
	sim.lock_everyone_onto_nearest()
	var beamer := sim.fighters[0]
	beamer.ki = 100 * FighterState.METER_UNIT
	var kit := KiRules.kit_of(beamer)
	KiRules._begin(sim, 0, kit.beam)
	beamer.move_tick = kit.beam.startup_ticks - until_fire
	var ai := FighterAI.new(1, level, trial)
	ai._ki_game._beam_answer = 2
	ai._ki_game._beam_key = sim.current_tick - beamer.move_tick # Fighter 0, this tell.
	var plan := FighterInput.new()
	ai._ki_game.answer_beams(ai, sim, sim.fighters[1], plan)
	return plan


func test_a_level_5_ai_holds_its_sidestep_dodge_until_just_before_the_beam_fires() -> void:
	var early := _tell_answer(5, 8, 3)
	assert_eq(early.held_actions & (A.DASH | A.BLOCK), 0, "waits, neither dodging nor blocking")
	var timed := _tell_answer(5, AIKi.LATE_SIDESTEP_TICKS, 3)
	assert_ne(timed.held_actions & A.DASH, 0, "taps Shift for the sidestep dodge")
	assert_ne(timed.move.x, 0.0, "across the beam's line")
	var low := _tell_answer(3, 6, 3)
	assert_ne(low.held_actions & A.DASH, 0, "lower levels dodge as soon as the aim locks")


func test_a_level_5_ai_sidestep_dodges_beams_at_range_and_makes_them_whiff() -> void:
	var dodges := 0
	var whiffs := 0
	var perfect := 0
	for trial in 20:
		var sim := CombatSim.new(700 + trial)
		sim.add_fighter(Vector3(0, 1, 11))
		sim.add_fighter(Vector3(0, 1, -11))
		sim.lock_everyone_onto_nearest()
		var beamer := sim.fighters[0]
		beamer.ki = 100 * FighterState.METER_UNIT
		# The tell is already showing, so the AI reads it at range instead of rushing in first.
		KiRules._begin(sim, 0, KiRules.kit_of(beamer).beam)
		beamer.move_tick = 10
		var ai := FighterAI.new(1, 5, FighterAI.seed_for(700 + trial, 1))
		for tick in 110:
			var inputs: Array[FighterInput] = [FighterInput.new(), ai.next_input(sim)]
			sim.tick(inputs)
			for event in sim.events:
				if event.type == E.DODGE and event.fighter == 1 and event.kind == FighterDodge.Kind.SIDESTEP:
					dodges += 1
				elif event.type == E.BEAM_END and event.whiff:
					whiffs += 1
				elif event.type == E.PERFECT_DODGE and event.target == 1 and event.attacker == 0:
					perfect += 1
	gut.p("L5 vs 20 beams from 22 m: sidestep dodges %d, whiffs %d, perfect dodges %d" % [dodges, whiffs, perfect])
	assert_gte(dodges, 5, "sidestep dodges are an answer at range")
	assert_gte(whiffs, 3, "the dodges make beams whiff")
