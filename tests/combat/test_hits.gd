extends GutTest

const LIGHT := FighterInput.Action.LIGHT
const HEAVY := FighterInput.Action.HEAVY
const State := FighterState.State
const Event := CombatSim.EventType
const UNIT := FighterState.METER_UNIT

var _sim: CombatSim
var _moves: MoveSet
var _previous: Array[FighterInput] = []


## Fighter 0 on the floor at the origin facing -Z, the others where given; all locked on.
func _start(others: Array[Vector3] = [Vector3(0, 0, -2)], stats: Array[FighterStats] = [],
		start_0 := Vector3.ZERO) -> void:
	_sim = CombatSim.new()
	_sim.add_fighter(start_0, stats[0] if stats.size() > 0 else null)
	for i in others.size():
		_sim.add_fighter(others[i], stats[i + 1] if stats.size() > i + 1 else null)
	_sim.lock_everyone_onto_nearest()
	_moves = _sim.fighters[0].stats.move_set
	_previous = []
	for _i in _sim.fighters.size():
		_previous.append(FighterInput.new())


## Runs ticks with per-fighter held actions and vertical input (missing entries are neutral).
func _tick(ticks := 1, held: Array = [], vertical: Array = []) -> void:
	for _i in ticks:
		var inputs: Array[FighterInput] = []
		for f in _sim.fighters.size():
			var input := FighterInput.from_held(held[f] if f < held.size() else 0, _previous[f])
			input.vertical = vertical[f] if f < vertical.size() else 0
			inputs.append(input)
		_sim.tick(inputs)
		_previous = inputs


## Ticks with neutral input until an event comes, at most limit ticks; returns the events.
func _tick_until_event(limit := 60) -> Array[Dictionary]:
	for _i in limit:
		_tick()
		if not _sim.events.is_empty():
			return _sim.events
	return []


func _fighter(index: int) -> FighterState:
	return _sim.fighters[index]


## A move with exact, stepless geometry: one sphere on the given offset.
static func _test_move(id: StringName, offset := Vector3(0, 0, -1.2), startup := 3, active := 2) -> MoveData:
	var move := MoveData.new()
	move.id = id
	move.startup_ticks = startup
	move.active_ticks = active
	move.recovery_ticks = 10
	move.hitbox_offsets = PackedVector3Array([offset])
	move.hitbox_radii = PackedFloat32Array([0.6])
	move.damage = 100
	move.hitstun_ticks = 30
	move.blockstun_ticks = 10
	move.hitstop_ticks = 4
	move.guard_damage = 10
	return move


## Stats whose light string is just this move.
static func _stats_with(move: MoveData) -> FighterStats:
	var stats := FighterStats.new()
	stats.move_set = MoveSet.new()
	stats.move_set.light_string = [move]
	return stats


# Detection

func test_a_light_hits_a_target_inside_its_reach() -> void:
	_start([Vector3(0, 0, -2)])
	_tick(1, [LIGHT])
	var events := _tick_until_event()
	assert_eq(events.size(), 1)
	assert_eq(_fighter(1).state, State.HITSTUN)
	assert_eq(_fighter(1).health, (10_000 - 300) * UNIT)


func test_a_light_does_not_hit_a_target_just_out_of_reach() -> void:
	_start([Vector3(0, 0, -2.5)])
	_tick(1, [LIGHT])
	assert_eq(_tick_until_event(_moves.light_string[0].total_ticks()), [] as Array[Dictionary])
	assert_eq(_fighter(1).health, 10_000 * UNIT)
	assert_ne(_fighter(1).state, State.HITSTUN)


func test_a_move_hits_each_target_only_once_over_its_active_ticks() -> void:
	var move := _test_move(&"long", Vector3(0, 0, -1.2), 3, 6)
	_start([Vector3(0, 0, -2)], [_stats_with(move)])
	_tick(1, [LIGHT])
	var hits := 0
	for _i in move.total_ticks() + 10:
		_tick()
		hits += _sim.events.size()
	assert_eq(hits, 1)
	assert_eq(_fighter(1).health, (10_000 - 100) * UNIT)


func test_a_multi_hit_move_hits_again_on_each_active_tick_after_hitstop() -> void:
	var move := _test_move(&"flurry", Vector3(0, 0, -1.2), 3, 3)
	move.multi_hit = true
	move.hitstop_ticks = 2
	_start([Vector3(0, 0, -2)], [_stats_with(move)])
	_tick(1, [LIGHT])
	var hits := 0
	for _i in move.total_ticks() + 10:
		_tick()
		hits += _sim.events.size()
	assert_eq(hits, 3, "one hit per active tick")
	assert_eq(_fighter(1).combo_hits, 3)


func test_both_fighters_hit_each_other_on_the_same_tick_in_a_trade() -> void:
	_start([Vector3(0, 0, -2)])
	_tick(1, [LIGHT, LIGHT])
	var events := _tick_until_event()
	assert_eq(events.size(), 2)
	assert_eq([events[0].attacker, events[1].attacker], [0, 1], "fighter index order")
	for i in 2:
		assert_eq(_fighter(i).state, State.HITSTUN)
		assert_eq(_fighter(i).health, (10_000 - 300) * UNIT)


# Damage scaling and hitstun decay

func test_combo_scaling_drops_8_percent_per_hit_down_to_a_30_percent_floor() -> void:
	_start()
	var move := _test_move(&"thousand")
	move.damage = 1000
	var damage: Array[int] = []
	for hit in range(1, 13):
		damage.append(_sim.scaled_damage(move, hit))
	assert_eq(damage, [1000, 920, 840, 760, 680, 600, 520, 440, 360, 300, 300, 300] as Array[int])
	assert_eq(_sim.scaled_damage(_moves.light_string[1], 2), 294, "320 x 92% rounds down")


func test_ultimates_keep_at_least_half_their_damage() -> void:
	_start()
	var move := _test_move(&"ultimate")
	move.damage = 1000
	move.cancel_level = MoveData.CancelLevel.ULTIMATE
	assert_eq(_sim.scaled_damage(move, 7), 520)
	assert_eq(_sim.scaled_damage(move, 8), 500)
	assert_eq(_sim.scaled_damage(move, 20), 500)


func test_hitstun_loses_2_ticks_per_hit_after_the_8th_down_to_a_4_tick_floor() -> void:
	_start()
	var move := _test_move(&"stun")
	move.hitstun_ticks = 16
	var stun: Array[int] = []
	for hit in range(1, 17):
		stun.append(_sim.decayed_hitstun(move, hit))
	assert_eq(stun, [16, 16, 16, 16, 16, 16, 16, 16, 14, 12, 10, 8, 6, 4, 4, 4] as Array[int])
	move.hitstun_ticks = 3
	assert_eq(_sim.decayed_hitstun(move, 20), 3, "a hitstun already under the floor stays")


## Presses light once per string hit, when its window opens; returns after the last hit lands.
func _play_light_string(hits: int) -> void:
	_tick(1, [LIGHT])
	var pressed := 1
	for _i in 200:
		var fighter := _fighter(0)
		var press := pressed < hits and fighter.hitstop_ticks == 0 \
			and fighter.string_index == pressed and fighter.move_tick >= fighter.move.string_window_start_tick
		_tick(1, [LIGHT if press else 0])
		if press:
			pressed += 1
		if _fighter(1).combo_hits == hits:
			return


func test_the_full_light_string_deals_its_scaled_damage_as_one_combo() -> void:
	_start()
	_play_light_string(4)
	# 300 + 320 x 92% + 350 x 84% + 450 x 76%
	var expected := 300 + 294 + 294 + 342
	assert_eq(_fighter(1).combo_hits, 4)
	assert_eq(_fighter(1).combo_damage, expected)
	assert_eq(_fighter(1).health, (10_000 - expected) * UNIT)


func test_three_lights_cancelled_into_a_smash_deal_the_scaled_combo_damage() -> void:
	_start()
	_play_light_string(3)
	# The heavy press comes during the third light's hitstop and cancels right after it.
	_tick(1, [HEAVY])
	for _i in 30:
		_tick()
		if _fighter(1).combo_hits == 4:
			break
	var expected := 300 + 294 + 294 + 608
	assert_eq(_fighter(1).combo_hits, 4, "the smash connects as hit 4")
	assert_eq(_fighter(1).combo_damage, expected)
	assert_eq(_fighter(1).health, (10_000 - expected) * UNIT)


# Hitstun, combo counters, grey health

func test_hitstun_lasts_exactly_the_move_hitstun_after_hitstop() -> void:
	_start()
	_tick(1, [LIGHT])
	_tick_until_event()
	var light := _moves.light_string[0]
	_tick(light.hitstop_ticks + light.hitstun_ticks)
	assert_eq(_fighter(1).state, State.HITSTUN, "still stunned on its last tick")
	_tick()
	assert_eq(_fighter(1).state, State.IDLE)


func test_combo_counters_reset_when_hitstun_ends() -> void:
	_start()
	_play_light_string(2)
	assert_eq(_fighter(1).combo_hits, 2)
	assert_eq(_fighter(1).combo_damage, 300 + 294)
	for _i in 60:
		_tick()
	assert_ne(_fighter(1).state, State.HITSTUN)
	assert_eq(_fighter(1).combo_hits, 0)
	assert_eq(_fighter(1).combo_damage, 0)


func test_grey_health_builds_up_across_a_combo_and_a_new_combo_drops_it() -> void:
	_start()
	var grey_percent := _sim.meter_tuning.grey_percent
	_play_light_string(3)
	var combo := 300 + 294 + 294
	assert_eq(_fighter(1).grey_health, combo * UNIT * grey_percent / 100)
	for _i in 60:
		_tick()
	_tick(1, [LIGHT])
	_tick_until_event()
	assert_eq(_fighter(1).grey_health, 300 * UNIT * grey_percent / 100, "only the new combo's grey part")


func test_the_attacker_gains_landed_hit_ki_and_its_cancel_window_opens() -> void:
	_start()
	var ki_before := _fighter(0).ki
	_tick(1, [LIGHT])
	_tick_until_event()
	assert_true(_fighter(0).contact_hit)
	assert_false(_fighter(0).contact_blocked)
	# Passive ki also ran for the 7 ticks before the hit.
	var passive := 7 * _sim.meter_tuning.ki_passive_per_second
	assert_eq(_fighter(0).ki - ki_before, _sim.meter_tuning.ki_per_landed_hit * UNIT + passive)
	assert_true(_sim.can_cancel_into(0, MoveData.CancelLevel.HEAVY))


func test_a_hit_interrupts_the_target_attack() -> void:
	_start()
	_tick(1, [LIGHT, HEAVY])
	_tick_until_event()
	assert_eq(_fighter(1).state, State.HITSTUN)
	assert_eq(_fighter(1).move, null)


# Hitstop

func test_hitstop_freezes_attacker_and_target_for_exactly_n_ticks_and_nobody_else() -> void:
	_start([Vector3(0, 0, -2), Vector3(40, 10, 0)])
	_sim.fighters[2].velocity = Vector3(10, 0, 0)
	_sim.fighters[2].lock_on_target = -1
	_tick(1, [LIGHT])
	_tick_until_event()
	var hitstop := _moves.light_string[0].hitstop_ticks
	var move_tick := _fighter(0).move_tick
	var target_position := _fighter(1).position
	var other_x := _fighter(2).position.x
	for i in hitstop:
		_tick()
		assert_eq(_fighter(0).move_tick, move_tick, "attacker frozen on tick %d" % i)
		assert_eq(_fighter(1).state_ticks, 0, "target frozen on tick %d" % i)
		assert_eq(_fighter(1).position, target_position)
	assert_gt(_fighter(2).position.x, other_x, "the third fighter kept moving")
	_tick()
	assert_eq(_fighter(0).move_tick, move_tick + 1, "the attack runs again")
	assert_eq(_fighter(1).state_ticks, 1)


func test_a_press_during_hitstop_stays_buffered_until_it_ends() -> void:
	var move := _test_move(&"slow_stop")
	move.hitstop_ticks = 12
	move.cancel_start_tick = 0
	move.cancel_end_tick = 15
	var stats := _stats_with(move)
	stats.move_set.smash = (CombatSim.DEFAULT_FIGHTER_STATS as FighterStats).move_set.smash
	_start([Vector3(0, 0, -2)], [stats])
	_tick(1, [LIGHT])
	_tick_until_event()
	_tick(1, [HEAVY])
	_tick(move.hitstop_ticks - 1)
	assert_eq(_fighter(0).move_id(), &"slow_stop", "still frozen")
	_tick()
	assert_eq(_fighter(0).move_id(), &"smash", "the heavy pressed in hitstop cancels right after it")


func test_a_counter_hit_adds_4_hitstop_ticks_and_flags_the_event() -> void:
	_start()
	# Fighter 1's smash is still in startup when the light lands.
	_tick(1, [LIGHT, HEAVY])
	var events := _tick_until_event()
	var light := _moves.light_string[0]
	assert_eq(events[0].type, Event.COUNTER)
	assert_true(events[0].counter)
	assert_eq(events[0].hitstop, light.hitstop_ticks + 4)
	assert_eq(events[0].damage, light.damage, "no extra damage")
	assert_eq(_fighter(0).hitstop_ticks, light.hitstop_ticks + 4)
	assert_eq(_fighter(1).hitstop_ticks, light.hitstop_ticks + 4)


# Armor and invincibility

func test_armor_takes_damage_but_no_stun_or_knockback_and_the_attacker_still_gets_contact() -> void:
	var armored := _test_move(&"armored", Vector3(0, 0, -1.2), 20)
	armored.armor_end_tick = 20
	_start([Vector3(0, 0, -2)], [null, _stats_with(armored)])
	_tick(1, [LIGHT, LIGHT])
	var events := _tick_until_event()
	var light := _moves.light_string[0]
	assert_eq(events[0].type, Event.ARMOR)
	assert_eq(_fighter(1).health, (10_000 - light.damage) * UNIT)
	assert_eq(_fighter(1).state, State.ATTACKING, "the armored move keeps going")
	assert_eq(_fighter(1).velocity, Vector3.ZERO)
	assert_true(_fighter(0).contact_hit)
	assert_eq(_fighter(0).hitstop_ticks, light.hitstop_ticks)
	var move_tick := _fighter(1).move_tick
	_tick(light.hitstop_ticks + 1)
	assert_eq(_fighter(1).move_tick, move_tick + 1)


func test_rising_is_not_hit_high_during_its_invincibility_but_a_low_sweep_hits_it() -> void:
	_start()
	_tick(1, [LIGHT])
	# Rising starts 2 ticks later, so the light's active ticks 6-7 meet Rising ticks 4-5.
	_tick(1)
	_tick(1, [0, HEAVY], [0, 1])
	assert_eq(_fighter(1).move_id(), &"rising")
	for _i in 6:
		_tick()
		assert_eq(_sim.events, [] as Array[Dictionary], "the high light passes through")
	assert_eq(_fighter(1).health, 10_000 * UNIT)

	_start()
	# Sweep (A/D + RMB) is active on ticks 12-16; Rising starts 8 ticks later, invincible on 3-8.
	var sideways := FighterInput.from_held(HEAVY, _previous[0])
	sideways.move = Vector2(1, 0)
	var inputs: Array[FighterInput] = [sideways, FighterInput.new()]
	_sim.tick(inputs)
	_previous = inputs
	assert_eq(_fighter(0).move_id(), &"sweep")
	_tick(7)
	_tick(1, [0, HEAVY], [0, 1])
	var rising_tick := 0
	for _i in 10:
		# The hit is resolved after this tick's advance.
		rising_tick = _fighter(1).move_tick + 1
		_tick()
		if not _sim.events.is_empty():
			break
	assert_eq(_sim.events.size(), 1)
	assert_eq(_sim.events[0].move_id, &"sweep")
	var rising := _moves.rising
	assert_between(rising_tick, rising.invincible_start_tick, rising.invincible_end_tick - 1,
		"hit during the upper-body invincibility")
	assert_eq(_fighter(1).state, State.HITSTUN)


func test_a_hitbox_centre_above_mid_height_is_an_upper_body_hit() -> void:
	_start()
	var target := _fighter(1)
	assert_true(target.is_upper_body(target.position + Vector3(0, 0.01, 0)))
	assert_false(target.is_upper_body(target.position - Vector3(0, 0.01, 0)))


# Aim

func test_a_locked_attack_pitches_its_hitboxes_toward_the_target_clamped_to_45_degrees() -> void:
	_start([Vector3(0, 3, -3)])
	_tick(1, [LIGHT])
	assert_almost_eq(_fighter(0).aim_pitch, atan2(2.0, 3.0), 0.0001, "target 2 m higher, 3 m away")
	_start([Vector3(0, 30, -3)])
	_tick(1, [LIGHT])
	assert_almost_eq(_fighter(0).aim_pitch, PI / 4.0, 0.0001)
	_start([Vector3(0, 30, -3)])
	_fighter(0).lock_on_target = -1
	_tick(1, [LIGHT])
	assert_eq(_fighter(0).aim_pitch, 0.0, "unlocked attacks stay level")


func test_pitch_aimed_hitboxes_connect_air_to_air_where_level_ones_miss() -> void:
	var move := _test_move(&"reach", Vector3(0, 0.2, -1.4))
	for locked in [true, false]:
		_start([Vector3(0, 22.2, -1.6)], [_stats_with(move)], Vector3(0, 20, 0))
		if not locked:
			_fighter(0).lock_on_target = -1
		_tick(1, [LIGHT])
		var events := _tick_until_event(move.total_ticks())
		assert_eq(events.size(), 1 if locked else 0, "locked" if locked else "unlocked")


# Events

func test_a_hit_reports_one_event_with_contact_point_move_damage_and_hitstop() -> void:
	_start()
	_tick(1, [LIGHT])
	var events := _tick_until_event()
	var light := _moves.light_string[0]
	assert_eq(events.size(), 1)
	var event := events[0]
	assert_eq(event.type, Event.HIT)
	assert_eq(event.attacker, 0)
	assert_eq(event.target, 1)
	assert_eq(event.move_id, &"light_1")
	assert_eq(event.damage, light.damage)
	assert_eq(event.hitstop, light.hitstop_ticks)
	assert_eq(event.knockback_type, MoveData.KnockbackType.NONE)
	assert_false(event.counter)
	var contact: Vector3 = event.position
	assert_almost_eq(contact.z, _fighter(1).position.z + 0.5, 0.05, "on the target's front surface")
	assert_almost_eq(contact.y, 1.3, 0.05, "at the hitbox height")
	_tick()
	assert_eq(_sim.events, [] as Array[Dictionary], "cleared on the next tick")


func test_a_knockout_hit_reports_hit_then_ko_with_20_ticks_of_hitstop() -> void:
	_start()
	_fighter(1).health = 100 * UNIT
	_tick(1, [LIGHT])
	var events := _tick_until_event()
	assert_eq(events.map(func(e: Dictionary) -> int: return e.type), [Event.HIT, Event.KO])
	assert_eq(events[1].hitstop, 20)
	assert_true(_sim.round_over)
	assert_eq(_sim.round_winner, 0)


func test_state_hash_covers_the_hit_state() -> void:
	_start()
	var fighter := _fighter(1)
	for change: Callable in [
		func() -> void: fighter.hitstop_ticks = 3,
		func() -> void: fighter.stun_ticks = 9,
		func() -> void: fighter.combo_hits = 2,
		func() -> void: fighter.combo_damage = 500,
		func() -> void: fighter.knockback_type = MoveData.KnockbackType.SPIKE,
		func() -> void: fighter.spike_bounced = true,
		func() -> void: fighter.aim_pitch = 0.3,
		func() -> void: fighter.hit_targets = 1,
		func() -> void: _sim.events.append({"type": Event.HIT}),
	]:
		var before := _sim.state_hash()
		change.call()
		assert_ne(_sim.state_hash(), before)
