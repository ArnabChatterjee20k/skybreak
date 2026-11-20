extends GutTest
## T-SP1: specials on keys 1/2/3 (Kael and Vexa kits), ki costs, cancel rules,
## punishable recovery, Momentum, the afterimage decoy, hooks and rollback.

const SP1 := FighterInput.Action.SPECIAL_1
const SP2 := FighterInput.Action.SPECIAL_2
const SP3 := FighterInput.Action.SPECIAL_3
const ULT := FighterInput.Action.ULTIMATE
const LIGHT := FighterInput.Action.LIGHT
const HEAVY := FighterInput.Action.HEAVY
const GRAB := FighterInput.Action.GRAB
const BLOCK := FighterInput.Action.BLOCK
const DASH := FighterInput.Action.DASH
const State := FighterState.State
const Event := CombatSim.EventType
const UNIT := FighterState.METER_UNIT
const KAEL := preload("res://game/combat/moves/kael/kael_fighter_stats.tres")
const VEXA := preload("res://game/combat/vexa_fighter_stats.tres")
const BRANN := preload("res://game/combat/moves/brann/brann_fighter_stats.tres")
const DUMMY := preload("res://game/combat/default_fighter_stats.tres")

var _sim: CombatSim
var _previous: Array[FighterInput] = []
var _log: Array[Dictionary] = []


## Fighter 0 (stats) at the origin, fighter 1 (other) gap metres ahead (-Z), both locked on.
func _start(stats: FighterStats, gap: float = 2.0, other: FighterStats = DUMMY) -> void:
	_sim = CombatSim.new()
	_sim.add_fighter(Vector3.ZERO, stats)
	_sim.add_fighter(Vector3(0, 0, -gap), other)
	_sim.lock_everyone_onto_nearest()
	_previous = [FighterInput.new(), FighterInput.new()]
	_log = []


func _tick(held0: int = 0, held1: int = 0, vertical0: int = 0, move0: Vector2 = Vector2.ZERO) -> void:
	var a := FighterInput.from_held(held0, _previous[0])
	a.vertical = vertical0
	a.move = move0
	var b := FighterInput.from_held(held1, _previous[1])
	var inputs: Array[FighterInput] = [a, b]
	_sim.tick(inputs)
	_previous = inputs
	_log.append_array(_sim.events)


func _idle(ticks: int) -> void:
	for _i in ticks:
		_tick()


func _me() -> FighterState:
	return _sim.fighters[0]


func _them() -> FighterState:
	return _sim.fighters[1]


func _events(type: CombatSim.EventType) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event in _log:
		if event.type == type:
			out.append(event)
	return out


func _hits_by(move_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event in _log:
		if event.type in [Event.HIT, Event.COUNTER] and event.get("move_id", &"") == move_id:
			out.append(event)
	return out


## Runs until fighter is free again (at most limit ticks); returns the ticks it took.
func _until_free(fighter: int, limit: int = 200) -> int:
	var ticks := 0
	while ticks < limit and _sim.fighters[fighter].state not in [State.IDLE, State.MOVING, State.FLYING]:
		_tick()
		ticks += 1
	return ticks


# Input -> sim -> effect, and ki.

func test_key_one_starts_comet_drive_and_spends_its_ki() -> void:
	_start(KAEL, 7.0)
	var ki := _me().ki
	_tick(SP1)
	assert_eq(_me().state, State.ATTACKING)
	assert_eq(_me().move_id(), &"kael_comet_drive")
	assert_eq(ki - _me().ki, 25 * UNIT - _sim.meter_tuning.ki_passive_per_second, "25 ki, less this tick's passive gain")
	assert_eq(_events(Event.SPECIAL_START).size(), 1)
	assert_eq(_events(Event.SPECIAL_START)[0].slot, 1)


func test_comet_drive_travels_into_the_target_from_mid_range_and_blows_it_back() -> void:
	_start(KAEL, 7.0)
	_tick(SP1)
	_idle(30)
	assert_eq(_hits_by(&"kael_comet_drive").size(), 1, "it reaches a target 7 m away")
	assert_true(_me().position.z < -4.0, "Kael travelled toward the target")


func test_without_the_ki_a_special_is_denied_and_the_press_is_used_up() -> void:
	_start(KAEL, 7.0)
	_me().ki = 10 * UNIT
	_tick(SP1)
	assert_ne(_me().state, State.ATTACKING)
	assert_eq(_events(Event.SPECIAL_DENIED).size(), 1)
	assert_false(_sim.is_buffered(0, SP1), "consumed: no other system reads it")


func test_ascend_and_descend_pick_the_rising_and_diving_variants() -> void:
	_start(KAEL, 7.0)
	_tick(SP1, 0, 1)
	assert_eq(_me().move_id(), &"kael_comet_drive_rise")
	_start(KAEL, 7.0)
	_tick(SP1, 0, -1)
	assert_eq(_me().move_id(), &"kael_comet_drive_dive")


func test_keys_two_and_three_start_kaels_other_specials() -> void:
	_start(KAEL, 3.0)
	_tick(SP2)
	assert_eq(_me().move_id(), &"kael_gale_counter")
	_start(KAEL, 3.0)
	_tick(SP3)
	assert_eq(_me().move_id(), &"kael_skyfall")


func test_vexas_keys_start_her_three_specials() -> void:
	for pair in [[SP1, &"vexa_shade_flicker"], [SP2, &"vexa_mirage_step"], [SP3, &"vexa_razor_waltz"]]:
		_start(VEXA, 4.0)
		_tick(pair[0])
		assert_eq(_me().move_id(), pair[1])


func test_a_legend_without_a_kit_leaves_the_keys_to_other_systems() -> void:
	_start(BRANN, 4.0)
	_tick(SP1)
	assert_ne(_me().state, State.ATTACKING)
	assert_true(_sim.is_buffered(0, SP1), "still buffered for the ki beam (T-KI1)")


# Cancel rules.

func test_a_light_that_hits_cancels_into_a_special() -> void:
	_start(KAEL, 1.5)
	_tick(LIGHT)
	while _me().move_id() == &"light_1" and not _me().contact_hit:
		_tick()
	_tick(SP1)
	_idle(_me().hitstop_ticks + 1)
	assert_eq(_me().move_id(), &"kael_comet_drive", "Light -> Special (after the hitstop)")


func test_a_whiffed_light_cannot_cancel_into_a_special() -> void:
	_start(KAEL, 8.0)
	_tick(LIGHT)
	_idle(7)
	_tick(SP1)
	assert_eq(_me().move_id(), &"light_1", "no contact, no cancel")


func test_a_special_never_cancels_into_another_special_or_back_into_a_heavy() -> void:
	_start(KAEL, 7.0)
	_tick(SP1)
	while not _me().contact_hit and _me().state == State.ATTACKING:
		_tick()
	assert_true(_me().contact_hit)
	_tick(SP3)
	assert_eq(_me().move_id(), &"kael_comet_drive", "Special -> Special is not allowed")
	_tick(HEAVY)
	assert_eq(_me().move_id(), &"kael_comet_drive", "never backwards")
	assert_true(_sim.can_cancel_into(0, MoveData.CancelLevel.VANISH), "Special -> Vanish-step is open")


# Punishable recovery.

func test_a_blocked_comet_drive_leaves_kael_open_long_enough_for_a_light() -> void:
	_start(KAEL, 7.0)
	_tick(SP1, BLOCK)
	while _events(Event.BLOCK).is_empty() and _sim.current_tick < 60:
		_tick(0, BLOCK)
	assert_false(_events(Event.BLOCK).is_empty(), "blocked")
	var defender_free := 0
	var attacker_free := 0
	for tick in 120:
		_tick()
		if defender_free == 0 and _them().state in [State.IDLE, State.MOVING]:
			defender_free = tick
		if attacker_free == 0 and _me().state in [State.IDLE, State.MOVING, State.FLYING]:
			attacker_free = tick
	var startup := (DUMMY.move_set.light_string[0] as MoveData).startup_ticks
	assert_gt(attacker_free - defender_free, startup, "on block it is minus more than a light's startup")


func test_a_whiffed_skyfall_takes_its_full_recovery() -> void:
	_start(KAEL, 12.0)
	_tick(SP3)
	var move := _me().move
	assert_eq(_until_free(0), move.total_ticks())


# Kael: Gale Counter, Skyfall.

func test_gale_counter_catches_a_strike_and_answers_with_the_riposte() -> void:
	_start(KAEL, 1.6)
	_tick(SP2)
	_idle(3)
	var health := _me().health
	_tick(0, LIGHT)
	for _i in 40:
		_tick()
	assert_eq(_events(Event.SPECIAL_COUNTER).size(), 1)
	assert_eq(_me().health, health, "the caught strike does no damage")
	assert_eq(_hits_by(&"kael_gale_riposte").size(), 1, "the riposte lands")


func test_a_grab_beats_gale_counter() -> void:
	_start(KAEL, 1.4)
	_tick(SP2)
	_idle(3)
	_tick(0, GRAB)
	_idle(20)
	assert_eq(_events(Event.SPECIAL_COUNTER).size(), 0)
	assert_eq(_events(Event.GRAB).size(), 1)


func test_skyfall_crushes_a_guard_below_forty() -> void:
	_start(KAEL, 4.0)
	_them().guard = 35 * UNIT
	_tick(SP3, BLOCK)
	for _i in 40:
		_tick(0, BLOCK)
	assert_eq(_events(Event.GUARD_BREAK).size(), 1)


func test_skyfall_on_a_full_guard_takes_forty_guard() -> void:
	_start(KAEL, 4.0)
	_tick(SP3, BLOCK)
	for _i in 30:
		_tick(0, BLOCK)
	assert_eq(_events(Event.BLOCK).size(), 1)
	assert_true(_them().guard <= 60 * UNIT + 20 * 30, "40 guard (plus a little regen at most)")


# Vexa: Shade Flicker, Mirage Step and the afterimage, Razor Waltz.

func test_shade_flicker_reappears_behind_the_target_and_hits() -> void:
	_start(VEXA, 5.0)
	_tick(SP1)
	_idle(10)
	assert_eq(_events(Event.SPECIAL_BLINK).size(), 1)
	assert_true(_me().position.z < _them().position.z, "now behind the target (past it on -Z)")
	_idle(10)
	assert_eq(_hits_by(&"vexa_shade_flicker").size(), 1)


func test_shade_flicker_is_invulnerable_while_vanished() -> void:
	_start(VEXA, 5.0)
	_tick(SP1)
	_idle(7)
	assert_true(_me().is_invincible_to(true) and _me().is_invincible_to(false))


func test_mirage_step_leaves_a_decoy_that_bursts_when_struck() -> void:
	_start(VEXA, 1.6)
	var start := _me().position
	_tick(SP2)
	assert_eq(_events(Event.DECOY_SPAWN).size(), 1)
	assert_true(_me().specials.has_decoy())
	assert_eq(_me().specials.decoy_position, start)
	_tick(0, LIGHT)
	for _i in 20:
		_tick()
	assert_eq(_events(Event.DECOY_BURST).size(), 1, "the light swung at the old spot hit the decoy")
	assert_eq(_hits_by(&"vexa_afterimage_burst").size(), 1, "and the burst hit the attacker")
	assert_false(_me().specials.has_decoy())


func test_mirage_step_slides_sideways_with_a_side_held() -> void:
	_start(VEXA, 3.0)
	_tick(SP2, 0, 0, Vector2(1, 0))
	_idle(14)
	assert_gt(absf(_me().position.x), 3.0, "about 4.5 m to the side")


func test_an_unstruck_decoy_fades() -> void:
	_start(VEXA, 12.0)
	_tick(SP2)
	_idle(VEXA.special_kit.decoy_ticks + 2)
	assert_false(_me().specials.has_decoy())
	assert_eq(_events(Event.DECOY_FADE).size(), 1)
	assert_eq(_events(Event.DECOY_BURST).size(), 0)


func test_razor_waltz_cuts_three_times() -> void:
	_start(VEXA, 2.5)
	_tick(SP3)
	_idle(45)
	assert_eq(_hits_by(&"vexa_razor_waltz").size(), 3)


# Momentum.

func test_momentum_adds_two_percent_per_consecutive_hit_and_is_lost_when_hit() -> void:
	_start(KAEL, 1.5)
	assert_eq(SpecialRules.boosted_damage(_sim, 0, 1000), 1000)
	_me().specials.momentum = 3
	assert_eq(SpecialRules.boosted_damage(_sim, 0, 1000), 1060)
	SpecialRules.on_hit_landed(_sim, 0)
	assert_eq(SpecialRules.momentum_percent(_me()), 8)
	for _i in 20:
		SpecialRules.on_hit_landed(_sim, 0)
	assert_eq(SpecialRules.momentum_percent(_me()), 20, "capped at +20%")
	_sim.apply_damage(0, 1, 100)
	assert_eq(_me().specials.momentum, 0)


func test_landed_hits_build_momentum_in_play() -> void:
	_start(KAEL, 1.5)
	_tick(LIGHT)
	_idle(20)
	assert_eq(_me().specials.momentum, 1)
	assert_eq(SpecialRules.momentum_percent(_me()), 2)


func test_only_kael_has_momentum() -> void:
	_start(VEXA, 1.5)
	SpecialRules.on_hit_landed(_sim, 0)
	assert_eq(SpecialRules.momentum_percent(_me()), 0)


func test_a_new_round_clears_momentum_and_the_decoy() -> void:
	_start(VEXA, 3.0, KAEL)
	_tick(SP2)
	_them().specials.momentum = 5
	_sim.start_round()
	assert_false(_me().specials.has_decoy())
	assert_eq(_them().specials.momentum, 0)


# Ultimate and transform hooks.

func test_a_kit_ultimate_costs_two_burst_stocks() -> void:
	var kit: SpecialKit = KAEL.special_kit.duplicate()
	kit.ultimate = kit.specials[0]
	var stats: FighterStats = KAEL.duplicate()
	stats.special_kit = kit
	_start(stats, 7.0)
	_me().burst = 2 * _sim.meter_tuning.burst_stock_size * UNIT
	_tick(ULT)
	assert_eq(_me().state, State.ATTACKING)
	assert_eq(_me().burst, 0)


func test_without_a_kit_ultimate_key_four_is_left_alone() -> void:
	_start(KAEL, 7.0)
	_me().burst = 2 * _sim.meter_tuning.burst_stock_size * UNIT
	_tick(ULT)
	assert_ne(_me().state, State.ATTACKING)
	assert_true(_sim.is_buffered(0, ULT), "for the ki ultimate (T-KI1)")
	assert_eq(KAEL.special_kit.ultimate_burst_stocks, 2)
	assert_eq(KAEL.special_kit.transform_burst_stocks, 1)


# Determinism and rollback.

func test_rollback_in_the_middle_of_a_special_replays_identically() -> void:
	_start(VEXA, 3.0, KAEL)
	_tick(SP2)
	_idle(4)
	var saved := _sim.snapshot()
	var hash_at_save := _sim.state_hash()
	var script: Array[int] = [0, LIGHT, 0, 0, 0, 0, SP1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	var saved_previous := _previous.duplicate()
	for held in script:
		_tick(0, held)
	var first := _sim.state_hash()
	_sim.restore(saved)
	_previous = saved_previous
	assert_eq(_sim.state_hash(), hash_at_save, "restore puts the special state back")
	for held in script:
		_tick(0, held)
	assert_eq(_sim.state_hash(), first)


func test_special_state_stays_out_of_the_hash_until_used() -> void:
	_start(KAEL, 3.0)
	assert_eq(_me().specials.state_values(), [])
	_tick(SP2)
	assert_ne(_me().specials.state_values(), [])


func test_a_mirrored_special_duel_is_deterministic() -> void:
	var hashes: Array[int] = []
	for run in 2:
		_start(VEXA, 4.0, KAEL)
		for tick in 240:
			var a: int = [SP1, 0, LIGHT, SP2, 0, SP3][tick % 6] if tick % 20 == 0 else 0
			var b: int = [SP2, SP1, SP3, LIGHT][tick % 4] if tick % 25 == 0 else 0
			_tick(a, b)
		hashes.append(_sim.state_hash())
	assert_eq(hashes[0], hashes[1])


func test_the_state_hash_covers_special_state_without_widening_fighter_rows() -> void:
	_start(KAEL, 3.0)
	var width := _me().state_values().size()
	var before := _sim.state_hash()
	_me().specials.momentum = 2
	assert_ne(_sim.state_hash(), before, "Momentum is hashed")
	assert_eq(_me().state_values().size(), width, "golden digest rows keep their width")
