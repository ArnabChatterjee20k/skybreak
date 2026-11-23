extends GutTest
## Ki blasts, charged blasts, beams and beam clashes (T-KI1, GAME_DESIGN §5.8).

const A := FighterInput.Action
const E := CombatSim.EventType
const UNIT := FighterState.METER_UNIT
const LYRA_STATS := preload("res://game/combat/moves/lyra/lyra_fighter_stats.tres")
## The ki duel DetCheck chains (tools/diag/det_check_run.gd).
const KI_MATCH_SEED := 2026
const KI_MATCH_TICKS := 3600
## Seeds for the blast count, KI_MATCH_SEED first.
const KI_BLAST_SEEDS: Array[int] = [2026, 2027, 2028, 2029, 2030, 2031, 2032, 2033, 2034, 2035]
## Main bbc45d0f over KI_BLAST_SEEDS: 13,4,3,5,4,2,5,6,7,6 (mean 5.5, sd 3.0); 4.0 is mean - 1.5 standard errors.
const KI_BLAST_MEAN_MIN := 4.0

var _sim: CombatSim
var _previous: Array[FighterInput] = []
var _seen: Array[Dictionary] = []


## Fighter 0 at the origin, fighter 1 at target (-Z is ahead), both locked on with full ki.
func _start(target := Vector3(0, 0, -12), first: FighterStats = null, second: FighterStats = null) -> void:
	_sim = CombatSim.new(7)
	_sim.add_fighter(Vector3.ZERO, first)
	_sim.add_fighter(target, second)
	_sim.lock_everyone_onto_nearest()
	for fighter in _sim.fighters:
		fighter.ki = 100 * UNIT
	_previous = [FighterInput.new(), FighterInput.new()]
	_seen = []


## Runs ticks with fighter 0 holding held and fighter 1 holding other_held; other_move steers fighter 1.
func _drive(ticks: int, held: int = 0, other_held: int = 0, other_move := Vector2.ZERO) -> void:
	for _i in ticks:
		var first := FighterInput.from_held(held, _previous[0])
		var second := FighterInput.from_held(other_held, _previous[1])
		second.move = other_move
		second.view_yaw = PI
		var inputs: Array[FighterInput] = [first, second]
		_sim.tick(inputs)
		_previous = inputs
		_seen.append_array(_sim.events)


func _count(type: E, move_id := &"") -> int:
	var found := 0
	for event in _seen:
		if event.type == type and (move_id == &"" or event.get("move_id", &"") == move_id):
			found += 1
	return found


func _first(type: E) -> Dictionary:
	for event in _seen:
		if event.type == type:
			return event
	return {}


func _ki_shots() -> int:
	var found := 0
	for projectile in _sim.projectiles:
		if projectile.ki != KiRules.Shot.NONE:
			found += 1
	return found


func test_a_tapped_q_fires_one_ki_blast_on_its_startup_tick_for_4_ki() -> void:
	_start()
	var kit := KiRules.kit_of(_sim.fighters[0])
	_drive(1, A.KI_BLAST)
	assert_eq(_sim.fighters[0].ki, 96 * UNIT + 2, "4 ki spent (plus one tick of passive ki)")
	assert_eq(_sim.fighters[0].move_id(), &"ki_blast")
	_drive(kit.blast.startup_ticks - 1)
	assert_eq(_ki_shots(), 0, "nothing before the startup ends")
	_drive(1)
	assert_eq(_ki_shots(), 1, "the blast leaves on tick %d" % kit.blast.startup_ticks)
	assert_eq(_count(E.KI_FIRE), 1)
	assert_eq(_sim.projectiles[0].ki, KiRules.Shot.BLAST)


func test_a_ki_blast_travels_and_hits_with_ranged_scaling_and_hitstop() -> void:
	_start()
	var health := _sim.fighters[1].health
	_drive(1, A.KI_BLAST)
	_drive(40)
	assert_eq(_count(E.HIT, &"ki_blast"), 1, "the blast lands")
	var hit := _first(E.HIT)
	assert_eq(hit.damage, 120 * Weapon.RANGED_COMBO_PERCENT / 100)
	assert_gt(hit.hitstop, 0, "hitstop on impact")
	assert_eq(_sim.fighters[1].health, health - hit.damage * UNIT)
	assert_eq(_ki_shots(), 0, "used up")


func test_holding_q_through_the_tap_startup_fires_a_charged_blast_for_20_ki() -> void:
	_start()
	var kit := KiRules.kit_of(_sim.fighters[0])
	_drive(kit.charged.startup_ticks, A.KI_BLAST)
	assert_eq(_count(E.KI_CHARGE), 1, "the tap turned into a charge")
	assert_eq(_ki_shots(), 0)
	_drive(1, A.KI_BLAST)
	assert_eq(_ki_shots(), 1, "fires %d ticks after the press" % kit.charged.startup_ticks)
	assert_eq(_sim.projectiles[0].ki, KiRules.Shot.CHARGED)
	assert_lt(_sim.fighters[0].ki, 81 * UNIT, "20 ki in total")
	_drive(40)
	assert_eq(_count(E.HIT, &"charged_blast"), 1)


func test_releasing_q_early_keeps_the_tap_blast() -> void:
	_start()
	_drive(4, A.KI_BLAST)
	_drive(20)
	assert_eq(_count(E.KI_CHARGE), 0)
	assert_eq(_count(E.KI_FIRE), 1)
	assert_gt(_sim.fighters[0].ki, 95 * UNIT)


func test_without_ki_q_does_nothing() -> void:
	_start()
	_sim.fighters[0].ki = 3 * UNIT
	_drive(1, A.KI_BLAST)
	assert_ne(_sim.fighters[0].state, FighterState.State.ATTACKING)
	_drive(20)
	assert_eq(_count(E.KI_FIRE), 0)


func test_blocking_a_ki_blast_costs_guard_and_no_health() -> void:
	_start()
	var health := _sim.fighters[1].health
	var guard := _sim.fighters[1].guard
	_drive(1, A.KI_BLAST, A.BLOCK)
	_drive(40, 0, A.BLOCK)
	assert_eq(_count(E.BLOCK), 1)
	assert_eq(_sim.fighters[1].health, health)
	assert_lt(_sim.fighters[1].guard, guard)


func test_a_perfect_block_reflects_a_ki_blast_back_into_its_shooter() -> void:
	_start()
	var shooter_health := _sim.fighters[0].health
	_drive(1, A.KI_BLAST)
	_drive(8)
	# Blast flies 44 m/s from about 0.8 m out: it reaches the defender ~14 ticks after it leaves.
	_drive(10)
	_drive(1, 0, A.BLOCK)
	_drive(40)
	var reflect := {}
	for event in _seen:
		if event.type == E.PROJECTILE_HIT and event.reflected:
			reflect = event
	assert_false(reflect.is_empty(), "the perfect block reflected it")
	assert_lt(_sim.fighters[0].health, shooter_health, "the shooter ate its own blast")


func test_a_dash_toward_a_tap_blast_soaks_it_for_2_ki_but_not_a_charged_one() -> void:
	_start()
	_drive(1, A.KI_BLAST)
	_drive(6)
	var ki := _sim.fighters[1].ki
	_drive(1, 0, A.DASH, Vector2(0, 1))
	_drive(12, 0, A.DASH, Vector2(0, 1))
	assert_eq(_count(E.KI_ABSORB), 1, "dash armour against tap blasts")
	assert_eq(_count(E.HIT), 0)
	assert_lt(_sim.fighters[1].ki, ki, "the soak costs ki")
	_start()
	_drive(22, A.KI_BLAST)
	_drive(2)
	_drive(1, 0, A.DASH, Vector2(0, 1))
	_drive(16, 0, A.DASH, Vector2(0, 1))
	assert_eq(_count(E.KI_ABSORB), 0, "charged blasts go through dash armour")
	assert_eq(_count(E.HIT, &"charged_blast"), 1)


func test_lyras_tap_blasts_home_onto_a_strafing_target() -> void:
	_start(Vector3(0, 0, -18), LYRA_STATS)
	_drive(1, A.KI_BLAST)
	_drive(8)
	_drive(40, 0, 0, Vector2(1, 0))
	assert_eq(_count(E.HIT, &"ki_blast"), 1, "homing catches the strafe")
	_start(Vector3(0, 0, -18))
	_drive(1, A.KI_BLAST)
	_drive(8)
	_drive(40, 0, 0, Vector2(1, 0))
	assert_eq(_count(E.HIT, &"ki_blast"), 0, "Kael's straight blast misses the same strafe")


func test_a_beam_costs_ki_has_a_long_tell_then_hits_hard() -> void:
	_start(Vector3(0, 0, -20))
	var kit := KiRules.kit_of(_sim.fighters[0])
	assert_gte(kit.beam.startup_ticks, 24, "doc: beams have at least 24 f startup")
	_drive(1, A.SPECIAL_1)
	assert_eq(_count(E.BEAM_START), 1)
	assert_lt(_sim.fighters[0].ki, 51 * UNIT, "50 ki")
	_drive(kit.beam.startup_ticks - 1)
	assert_eq(_sim.beams.size(), 0, "still the tell")
	_drive(1)
	assert_eq(_sim.beams.size(), 1, "the beam fires on its startup tick")
	_drive(30)
	assert_eq(_count(E.HIT, &"beam"), 1, "one big hit")
	assert_eq(_sim.fighters[1].state, FighterState.State.HITSTUN)
	assert_eq(_sim.fighters[1].knockback_type, MoveData.KnockbackType.BLOWBACK)


func test_a_sidestepped_beam_whiffs_with_huge_recovery_that_can_be_punished() -> void:
	_start(Vector3(0, 0, -20))
	var kit := KiRules.kit_of(_sim.fighters[0])
	_drive(1, A.SPECIAL_1)
	# The aim locks beam_aim_lock_ticks before firing; moving sideways after that sidesteps it.
	_drive(kit.beam.startup_ticks - _sim.ki_tuning.beam_aim_lock_ticks)
	_drive(30, 0, 0, Vector2(1, 0))
	for _i in kit.beam.active_ticks:
		if _count(E.BEAM_END) > 0:
			break
		_drive(1)
	assert_eq(_count(E.HIT), 0, "the sidestep beat the beam")
	var ended := _first(E.BEAM_END)
	assert_true(ended.get("whiff", false), "a whiff")
	var attacker := _sim.fighters[0]
	assert_eq(attacker.attack_phase(), FighterState.AttackPhase.RECOVERY)
	var left := attacker.move_total_ticks() - attacker.move_tick
	assert_gte(left, kit.beam.recovery_ticks + _sim.ki_tuning.beam_whiff_extra_recovery_ticks - 1,
		"a whiff adds %d ticks of recovery" % _sim.ki_tuning.beam_whiff_extra_recovery_ticks)
	assert_gte(left, 50, "at least 50 ticks to punish after the beam ends")
	# A rush dash from 20 m plus a heavy lands before it recovers.
	_drive(1, 0, A.DASH, Vector2(0, 1))
	_drive(30, 0, A.DASH, Vector2(0, 1))
	_drive(1, 0, A.HEAVY)
	_drive(20)
	assert_gt(_count(E.HIT) + _count(E.COUNTER), 0, "the whiff got punished")


func test_blocking_a_beam_grinds_the_guard_and_pushes_without_a_hit() -> void:
	_start(Vector3(0, 0, -15))
	var guard := _sim.fighters[1].guard
	_drive(1, A.SPECIAL_1, A.BLOCK)
	_drive(60, 0, A.BLOCK)
	assert_eq(_count(E.HIT), 0)
	assert_gt(_count(E.BLOCK), 0)
	assert_lt(_sim.fighters[1].guard, guard - 50 * UNIT, "about 2 guard per tick")
	assert_lt(_sim.fighters[1].position.z, -15.5, "pushed back along the beam")


func test_lyras_beam_splits_into_three_rays() -> void:
	_start(Vector3(0, 0, -20), LYRA_STATS)
	_drive(1, A.SPECIAL_1)
	_drive(KiRules.kit_of(_sim.fighters[0]).beam.startup_ticks + 2)
	assert_eq(_sim.beams.size(), 1)
	assert_eq(_sim.beams[0].rays().size(), 3)


func test_a_beam_eats_oncoming_ki_blasts() -> void:
	_start(Vector3(0, 0, -30))
	_drive(1, A.SPECIAL_1)
	_drive(20, 0, 0)
	_drive(1, 0, A.KI_BLAST)
	_drive(30)
	assert_eq(_count(E.KI_ABSORB), 1)
	assert_eq(_count(E.HIT, &"ki_blast"), 0)


## Both fire beams at each other; fighter 0 presses beat buttons per press_mode.
func _clash(press_mode: StringName) -> BeamClash:
	_start(Vector3(0, 0, -24))
	_drive(1, A.SPECIAL_1, A.SPECIAL_1)
	var clash: BeamClash = null
	for _i in 60:
		_drive(1)
		if not _sim.beam_clashes.is_empty():
			clash = _sim.beam_clashes[0]
			break
	assert_not_null(clash, "the beams clashed")
	if clash == null:
		return null
	var kept := clash
	while _sim.current_tick <= kept.end_tick:
		var held := 0
		var now := _sim.current_tick
		match press_mode:
			&"on_beat":
				for k in kept.beat_ticks.size():
					if kept.beat_ticks[k] == now:
						held = kept.beat_buttons[k]
			&"mash":
				held = KiRules.BEAT_BUTTONS[now % 4] if now % 2 == 0 else 0
		_drive(1, held)
	return kept


func test_on_beat_presses_win_a_beam_clash_for_full_damage_and_50_burst() -> void:
	var clash := _clash(&"on_beat")
	if clash == null:
		return
	var end := _first(E.CLASH_END)
	assert_eq(end.get("winner", -2), 0, "fighter 0 won")
	assert_eq(clash.good[0], _sim.ki_tuning.clash_beats, "every beat hit")
	assert_true(_seen.any(func(e: Dictionary) -> bool: return e.type == E.HIT and e.target == 1),
		"the loser took the beam")
	assert_gte(_sim.fighters[0].burst, 50 * UNIT)


func test_mashing_in_a_beam_clash_loses_ground() -> void:
	var clash := _clash(&"mash")
	if clash == null:
		return
	assert_lt(clash.push, 0, "off-beat presses push the meeting point back")
	assert_eq(_first(E.CLASH_END).get("winner", -2), 1)


func test_ki_play_is_deterministic_through_snapshot_and_restore() -> void:
	_start(Vector3(0, 0, -24), LYRA_STATS)
	_drive(1, A.SPECIAL_1, A.SPECIAL_1)
	for _i in 60:
		if not _sim.beam_clashes.is_empty():
			break
		_drive(1)
	_drive(20)
	assert_false(_sim.beam_clashes.is_empty(), "mid-clash")
	var saved := _sim.snapshot()
	var previous := _previous.duplicate()
	_drive(5, A.KI_BLAST)
	_drive(40, A.BLOCK, A.GRAB)
	var first := _sim.state_hash()
	_sim.restore(saved)
	_previous = previous
	_drive(5, A.KI_BLAST)
	_drive(40, A.BLOCK, A.GRAB)
	assert_eq(_sim.state_hash(), first)


func test_the_state_hash_ignores_ki_while_nothing_ki_is_alive() -> void:
	_start()
	assert_eq(KiRules.state_values(_sim), [])
	var plain := Projectile.new()
	plain.move = MoveData.new()
	assert_eq(plain.state_values().size(), 16, "weapon shots hash as before T-KI1")


## An AI duel built to use ki (level 5 Lyra vs Kael from 24 m, full ki); also a DetCheck scenario.
func _ki_match(seed_value: int, ticks: int, after_tick := Callable()) -> Dictionary:
	var sim := CombatSim.new(seed_value)
	sim.add_fighter(Vector3(0, 1, 12), EngagementBand.stats_for(&"lyra"))
	# Kael without his special kit (T-SP1): this duel measures ki zoning, not Comet Drive rushes.
	var kael := EngagementBand.stats_for(&"kael").duplicate() as FighterStats
	kael.special_kit = null
	sim.add_fighter(Vector3(0, 1, -12), kael)
	sim.lock_everyone_onto_nearest()
	var driver := AIDriver.for_sim(sim, [
		{"character": &"lyra", "team": 0, "is_ai": true, "ai_level": 5},
		{"character": &"kael", "team": 1, "is_ai": true, "ai_level": 5},
	])
	var seen := {}
	for _tick in ticks:
		if sim.round_over:
			sim.start_round()
		if sim.current_tick % 600 == 0:
			for fighter in sim.fighters:
				fighter.ki = 100 * UNIT
		sim.tick(driver.inputs_for(sim))
		for event in sim.events:
			seen[event.type] = int(seen.get(event.type, 0)) + 1
		if after_tick.is_valid():
			after_tick.call(sim)
	return {"hash": sim.state_hash(), "seen": seen}


func test_a_ki_heavy_ai_duel_is_deterministic_and_uses_blasts_and_beams() -> void:
	var first := _ki_match(KI_MATCH_SEED, KI_MATCH_TICKS)
	assert_eq(_ki_match(KI_MATCH_SEED, KI_MATCH_TICKS).hash, first.hash)
	var seen: Dictionary = first.seen
	gut.p("ki duel events: blasts %d, beams %d, clashes %d" % [seen.get(E.KI_FIRE, 0), seen.get(E.BEAM_FIRE, 0),
		seen.get(E.BEAM_CLASH, 0)])
	# Blasts per duel swing 2-13 by seed, so one seed proves nothing: check every seed and the mean.
	var blasts: Array[int] = [int(seen.get(E.KI_FIRE, 0))]
	for seed_value in KI_BLAST_SEEDS.slice(1):
		blasts.append(int(_ki_match(seed_value, KI_MATCH_TICKS).seen.get(E.KI_FIRE, 0)))
	var total := 0
	for i in blasts.size():
		assert_gt(blasts[i], 0, "seed %d: the AIs throw ki blasts" % KI_BLAST_SEEDS[i])
		total += blasts[i]
	var mean := float(total) / blasts.size()
	gut.p("ki blasts per duel, seeds %d-%d: %s, mean %.1f" % [KI_BLAST_SEEDS[0], KI_BLAST_SEEDS[-1], blasts, mean])
	assert_gte(mean, KI_BLAST_MEAN_MIN, "AI ki zoning stays near main's rate")
	# T-KI1-b: one 60 s L5 duel shows a beam only by seed luck (main: 1, 0, 0, 0 for seeds 2026-2029).
	if seen.get(E.BEAM_FIRE, 0) == 0:
		pending("T-KI1-b: no beam in this duel; AI beams are covered by test_ai_ki.gd")
	else:
		assert_gt(seen.get(E.BEAM_FIRE, 0), 0)
