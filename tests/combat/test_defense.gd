extends GutTest

const LIGHT := FighterInput.Action.LIGHT
const HEAVY := FighterInput.Action.HEAVY
const BLOCK := FighterInput.Action.BLOCK
const GRAB := FighterInput.Action.GRAB
const DASH := FighterInput.Action.DASH
const CHARGE := FighterInput.Action.CHARGE
const State := FighterState.State
const Event := CombatSim.EventType
const Phase := FighterState.AttackPhase
const UNIT := FighterState.METER_UNIT
const FORWARD := Vector2(0, 1)

var _sim: CombatSim
var _tuning: HitTuning
var _moves: MoveSet
var _previous: Array[FighterInput] = []
## What each fighter holds on the next ticks.
var _held: Array[int] = []
var _move_input: Array[Vector2] = []
## Every event seen since the last _clear_log(), in order.
var _log: Array[Dictionary] = []


## Fighters at these positions (default: 0 at the origin, 1 two metres ahead), all locked on.
func _start(positions: Array[Vector3] = [Vector3.ZERO, Vector3(0, 0, -2)]) -> void:
	_sim = CombatSim.new()
	_tuning = _sim.hit_tuning
	for position in positions:
		_sim.add_fighter(position)
	_sim.lock_everyone_onto_nearest()
	_moves = _sim.fighters[0].stats.move_set
	_previous = []
	_held = []
	_move_input = []
	for _i in positions.size():
		_previous.append(FighterInput.new())
		_held.append(0)
		_move_input.append(Vector2.ZERO)
	_log = []


func _tick(ticks := 1) -> void:
	for _i in ticks:
		var inputs: Array[FighterInput] = []
		for index in _held.size():
			var input := FighterInput.from_held(_held[index], _previous[index])
			input.move = _move_input[index]
			inputs.append(input)
		_sim.tick(inputs)
		_previous = inputs
		_log.append_array(_sim.events)


## Holds action for one tick on top of what the fighter holds, then lets it go.
func _tap(index: int, action: int) -> void:
	_held[index] |= action
	_tick()
	_held[index] &= ~action


## Ticks until an event of this type; returns it, or an empty dictionary.
func _tick_until(type: Event, limit := 60) -> Dictionary:
	for _i in limit:
		_tick()
		for event in _sim.events:
			if event.type == type:
				return event
	return {}


func _types(events: Array[Dictionary]) -> Array:
	return events.map(func(e: Dictionary) -> int: return e.type)


func _fighter(index: int) -> FighterState:
	return _sim.fighters[index]


## Fighter 1 taps block offset ticks before fighter 0's light lands (negative: after).
## Returns the type of the light's contact event, or -1 if none.
func _light_against_tap(offset: int, hold := false) -> int:
	_start()
	_tick(30)
	var light := _moves.light_string[0]
	# The light pressed on tick 10 lands on tick 10 + startup.
	var hit_tick := 10 + light.startup_ticks
	for tick in hit_tick + 1:
		if tick == 10:
			_held[0] |= LIGHT
		if tick == hit_tick - offset:
			_held[1] |= BLOCK
		elif not hold:
			_held[1] &= ~BLOCK
		_tick()
		_held[0] &= ~LIGHT
		if not _sim.events.is_empty():
			assert_eq(tick, hit_tick, "the light lands on its first active tick")
			return _sim.events[0].type
	return -1


# Holding block

func test_holding_block_enters_blocking_and_blocks_a_hit_from_the_front() -> void:
	_start()
	_held[1] = BLOCK
	_tick(30)
	assert_eq(_fighter(1).state, State.BLOCKING)
	assert_true(_fighter(1).blocking)
	_tap(0, LIGHT)
	var event := _tick_until(Event.BLOCK)
	assert_false(event.is_empty(), "blocked")
	assert_eq(_fighter(1).health, 10_000 * UNIT)


func test_blocking_drifts_slowly_and_cannot_attack() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -40)])
	_held[0] = BLOCK
	_move_input[0] = FORWARD
	_tick(60)
	var drift := _sim.tuning.guard_drift_speed
	assert_almost_eq(_fighter(0).velocity.length(), drift, 0.001, "slow guard drift")
	var planar := Vector2(_fighter(0).position.x, _fighter(0).position.z).length()
	assert_lt(planar, drift * 1.0 + 0.01, "about a second of drift")
	assert_gt(planar, drift * 0.8)
	_tap(0, LIGHT)
	_tick(3)
	assert_eq(_fighter(0).state, State.BLOCKING, "no attack while blocking")
	assert_eq(_fighter(0).move_id(), &"")


func test_releasing_block_returns_to_the_movement_state() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -40)])
	_held[0] = BLOCK
	_tick(5)
	_held[0] = 0
	_tick()
	assert_eq(_fighter(0).state, State.IDLE)
	assert_false(_fighter(0).blocking)
	_move_input[0] = FORWARD
	_held[0] = BLOCK
	_tick(5)
	_held[0] = 0
	_tick()
	assert_eq(_fighter(0).state, State.MOVING, "moving again right away")


func test_blocking_works_in_the_air_and_releases_into_flight() -> void:
	_start([Vector3(0, 20, 0), Vector3(0, 20, -2)])
	_held[1] = BLOCK
	_tick(30)
	assert_eq(_fighter(1).state, State.BLOCKING)
	assert_almost_eq(_fighter(1).position.y, 20.0, 0.001, "hovers while blocking")
	_tap(0, LIGHT)
	assert_false(_tick_until(Event.BLOCK).is_empty(), "blocked in the air")
	_held[1] = 0
	_tick(30)
	assert_eq(_fighter(1).state, State.FLYING)


func test_block_cancels_charging() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -40)])
	_held[0] = CHARGE
	_tick(5)
	assert_eq(_fighter(0).state, State.CHARGING)
	_held[0] = CHARGE | BLOCK
	_tick()
	assert_eq(_fighter(0).state, State.BLOCKING)


func test_blocking_pauses_guard_regeneration() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -40)])
	_sim.apply_guard_damage(0, 30)
	_held[0] = BLOCK
	_tick(200)
	assert_eq(_fighter(0).guard, 70 * UNIT)


# Perfect block

func test_a_block_tap_perfect_blocks_on_every_tick_of_the_window_and_not_after() -> void:
	# The window is 6 ticks counting the press tick: 0-5 ticks before the hit (T-DEF3 S3).
	for offset in _tuning.perfect_block_window_ticks:
		assert_eq(_light_against_tap(offset), Event.PERFECT_BLOCK, "tap %d ticks before the hit" % offset)
	var late := _tuning.perfect_block_window_ticks
	assert_eq(_light_against_tap(late), Event.HIT, "a tap 6 ticks early has passed")
	assert_eq(_light_against_tap(late, true), Event.BLOCK, "holding still blocks normally")


func test_a_perfect_block_costs_no_guard_and_extends_the_attackers_recovery() -> void:
	assert_eq(_light_against_tap(2), Event.PERFECT_BLOCK)
	var light := _moves.light_string[0]
	assert_eq(_fighter(1).guard, 100 * UNIT, "no guard damage")
	assert_eq(_fighter(1).health, 10_000 * UNIT)
	assert_ne(_fighter(1).state, State.BLOCKSTUN, "no blockstun")
	assert_eq(_fighter(0).move_total_ticks(), light.total_ticks() + 16)
	assert_false(_fighter(0).contact_blocked, "no contact, so no cancel")


func test_the_perfect_block_event_hitstop_and_burst() -> void:
	_start()
	_tick(30)
	var burst := _fighter(1).burst
	_tap(0, LIGHT)
	_tick(3)
	_tap(1, BLOCK)
	var event := _tick_until(Event.PERFECT_BLOCK)
	assert_false(event.is_empty())
	assert_eq(_types(_sim.events), [Event.PERFECT_BLOCK])
	assert_eq(event.attacker, 0)
	assert_eq(event.target, 1)
	assert_eq(event.damage, 0)
	assert_eq(event.hitstop, 10)
	assert_eq(event.move_id, _moves.light_string[0].id)
	assert_eq(_fighter(0).hitstop_ticks, 10)
	assert_eq(_fighter(1).hitstop_ticks, 10)
	assert_eq(_fighter(1).burst - burst, _sim.meter_tuning.burst_per_perfect_block * UNIT)
	assert_false(_fighter(1).perfect_block_armed, "used up")


func test_a_light_after_a_perfect_block_punishes_the_extra_recovery() -> void:
	assert_eq(_light_against_tap(0), Event.PERFECT_BLOCK)
	_held[1] = 0
	_tick(_tuning.perfect_block_hitstop_ticks)
	_tap(1, LIGHT)
	var phase := Phase.NONE
	for _i in 10:
		phase = _fighter(0).attack_phase()
		_tick()
		if not _sim.events.is_empty():
			break
	assert_eq(_sim.events[0].type, Event.HIT, "the punish lands")
	assert_eq(_sim.events[0].attacker, 1)
	assert_eq(_sim.events[0].target, 0)
	assert_eq(phase, Phase.RECOVERY, "while the attacker is still recovering")
	assert_eq(_fighter(0).state, State.HITSTUN)


func test_without_the_perfect_block_the_same_light_only_reaches_a_recovered_attacker() -> void:
	assert_eq(_light_against_tap(_tuning.perfect_block_window_ticks + 1, true), Event.BLOCK)
	var light := _moves.light_string[0]
	_held[1] = 0
	_tick(light.hitstop_ticks / 2 + light.blockstun_ticks + 1)
	assert_eq(_fighter(1).state, State.IDLE)
	_tap(1, LIGHT)
	var phase := Phase.NONE
	for _i in 10:
		phase = _fighter(0).attack_phase()
		_tick()
		if not _sim.events.is_empty():
			break
	assert_eq(phase, Phase.NONE, "the attacker was already out of its move")


func test_a_missed_tap_locks_out_perfect_blocks_for_20_ticks() -> void:
	_start()
	_tick(30)
	_tap(1, BLOCK)
	_tick(_tuning.perfect_block_window_ticks - 1)
	assert_true(_fighter(1).perfect_block_armed, "window still open on its last tick")
	_tick()
	assert_false(_fighter(1).perfect_block_armed)
	assert_eq(_fighter(1).perfect_block_lockout, 20)
	# A tap on the last locked tick does not arm.
	_tick(18)
	_tap(1, BLOCK)
	assert_false(_fighter(1).perfect_block_armed, "locked out on its 20th tick")
	assert_eq(_fighter(1).perfect_block_lockout, 1)
	_tick()
	assert_eq(_fighter(1).perfect_block_lockout, 0)
	_tap(1, BLOCK)
	assert_true(_fighter(1).perfect_block_armed, "free again after 20 ticks")


func test_a_block_during_the_lockout_still_blocks_normally() -> void:
	_start()
	_tick(30)
	_tap(1, BLOCK)
	_tick(_tuning.perfect_block_window_ticks)
	assert_gt(_fighter(1).perfect_block_lockout, 0)
	_held[1] = BLOCK
	_tap(0, LIGHT)
	var event := _tick_until(Event.BLOCK, 10)
	assert_false(event.is_empty(), "a normal block, not a perfect one")
	assert_false(_log.any(func(e: Dictionary) -> bool: return e.type == Event.PERFECT_BLOCK))


func test_a_second_tap_inside_the_window_is_mashing_and_locks_out() -> void:
	_start()
	_tick(30)
	_tap(1, BLOCK)
	_tick(2)
	_tap(1, BLOCK)
	assert_false(_fighter(1).perfect_block_armed)
	assert_eq(_fighter(1).perfect_block_lockout, 20)


func test_a_tap_while_an_opponent_is_vanishing_is_sense_and_never_locks_out() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -10)])
	_tick(30)
	_tap(0, DASH | BLOCK)
	assert_eq(_fighter(0).state, State.VANISHING)
	assert_false(_fighter(0).perfect_block_armed, "the vanish press is not a perfect block")
	_tap(1, BLOCK)
	_tick(_tuning.perfect_block_window_ticks + 2)
	assert_eq(_fighter(1).perfect_block_lockout, 0, "Sense: no lockout")
	assert_eq(_fighter(0).perfect_block_lockout, 0)
	_tick(_sim.tuning.vanish_step_ticks)
	_tap(1, BLOCK)
	assert_true(_fighter(1).perfect_block_armed, "a tap after the vanish is a perfect block attempt")


func test_reflects_projectiles_while_a_perfect_block_is_armed_from_the_front() -> void:
	_start()
	_tick(30)
	var front := _fighter(0).position
	assert_false(_sim.reflects_projectiles(1, front))
	_tap(1, BLOCK)
	assert_true(_sim.reflects_projectiles(1, front))
	assert_false(_sim.reflects_projectiles(1, _fighter(1).position + Vector3(0, 0, -3)), "not from behind")
	_tick(_tuning.perfect_block_window_ticks + 1)
	assert_false(_sim.reflects_projectiles(1, front))


# Grab

func test_a_grab_beats_a_block_holds_then_throws() -> void:
	_start()
	_held[1] = BLOCK
	_tick(30)
	_tap(0, GRAB)
	var event := _tick_until(Event.GRAB, 20)
	assert_false(event.is_empty(), "grab beats block")
	assert_eq(event.attacker, 0)
	assert_eq(event.target, 1)
	assert_eq(_fighter(0).state, State.THROWING)
	assert_eq(_fighter(1).state, State.GRABBED)
	assert_eq(_fighter(1).grab_partner, 0)
	assert_eq(_fighter(0).grab_partner, 1)
	_tick(_tuning.grab_hold_ticks)
	assert_eq(_fighter(1).state, State.GRABBED, "held for the whole throw animation")
	var held_at := _fighter(0).position + Vector3(0, 0, -_tuning.grab_hold_distance)
	assert_almost_eq(_fighter(1).position.distance_to(held_at), 0.0, 0.001, "held in front")
	_tick()
	var throw: Array = _sim.events.filter(func(e: Dictionary) -> bool: return e.type == Event.THROW)
	assert_eq(throw.size(), 1, "thrown after the hold")


func test_the_throw_deals_1100_and_blows_back_along_the_aim() -> void:
	_start()
	_tap(0, GRAB)
	_tick_until(Event.GRAB, 20)
	var event := _tick_until(Event.THROW, _tuning.grab_hold_ticks + 2)
	var grab := _moves.grab
	assert_eq(event.damage, 1100)
	assert_eq(event.damage, _sim.scaled_damage(grab, 1))
	assert_eq(event.knockback_type, MoveData.KnockbackType.BLOWBACK)
	assert_eq(event.hitstop, grab.hitstop_ticks)
	assert_eq(_fighter(1).health, (10_000 - 1100) * UNIT)
	assert_eq(_fighter(1).state, State.HITSTUN)
	assert_eq(_fighter(1).combo_hits, 1)
	assert_true(_fighter(1).velocity.is_equal_approx(grab.knockback), "along the aim (-Z)")
	assert_eq(_fighter(0).state, State.IDLE, "the thrower recovers")
	assert_eq(_fighter(1).grab_partner, -1)


func test_a_grab_whiff_has_25_recovery() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -20)])
	_tap(0, GRAB)
	var counts := {Phase.STARTUP: 1, Phase.ACTIVE: 0, Phase.RECOVERY: 0}
	while _fighter(0).state == State.ATTACKING:
		_tick()
		if _fighter(0).move_id() == &"grab":
			counts[_fighter(0).attack_phase()] += 1
	assert_eq(counts[Phase.STARTUP], 7)
	assert_eq(counts[Phase.ACTIVE], 2)
	assert_eq(counts[Phase.RECOVERY], 25)
	assert_eq(_moves.grab.kind, MoveData.Kind.GRAB)


func test_a_strike_during_grab_startup_is_a_counter_and_the_grab_fails() -> void:
	_start()
	_tap(0, LIGHT)
	_tap(1, GRAB)
	var event := _tick_until(Event.COUNTER, 10)
	assert_false(event.is_empty(), "strike beats grab")
	assert_eq(event.target, 1)
	assert_true(event.counter)
	assert_eq(_fighter(1).state, State.HITSTUN)
	_tick(40)
	assert_false(_log.any(func(e: Dictionary) -> bool: return e.type == Event.GRAB))


func test_a_strike_on_the_same_tick_as_an_active_grab_beats_it() -> void:
	_start()
	# Grab active on its 8th tick, light on its 7th: press the light one tick later.
	_tap(1, GRAB)
	_tap(0, LIGHT)
	_tick(10)
	assert_true(_log.any(func(e: Dictionary) -> bool: return e.type == Event.HIT and e.target == 1))
	assert_false(_log.any(func(e: Dictionary) -> bool: return e.type == Event.GRAB))


func test_a_grab_tech_within_10_ticks_escapes_and_not_on_tick_11() -> void:
	for wait in range(1, 12):
		_start()
		_tap(0, GRAB)
		_tick_until(Event.GRAB, 20)
		_tick(wait - 1)
		_tap(1, GRAB)
		var teched := _sim.events.any(func(e: Dictionary) -> bool: return e.type == Event.GRAB_TECH)
		if wait <= 10:
			assert_true(teched, "tech %d ticks after the grab" % wait)
		else:
			assert_false(teched, "no tech on tick 11")
			assert_eq(_fighter(1).state, State.GRABBED)


func test_a_grab_tech_pushes_both_apart_to_3_m_without_damage() -> void:
	_start()
	_tap(0, GRAB)
	_tick_until(Event.GRAB, 20)
	_tap(1, GRAB)
	var event: Dictionary = _sim.events.back()
	assert_eq(event.type, Event.GRAB_TECH)
	assert_eq(event.attacker, 0)
	assert_eq(event.target, 1)
	assert_eq(event.damage, 0)
	assert_eq(_fighter(0).state, State.BLOCKSTUN)
	assert_eq(_fighter(1).state, State.BLOCKSTUN)
	_tick(_tuning.grab_tech_push_ticks)
	assert_almost_eq(_fighter(0).position.distance_to(_fighter(1).position), 3.0, 0.01)
	_tick()
	assert_eq(_fighter(0).state, State.IDLE)
	assert_eq(_fighter(1).state, State.IDLE)
	assert_eq(_fighter(0).velocity, Vector3.ZERO)
	assert_eq(_fighter(1).health, 10_000 * UNIT)
	assert_eq(_fighter(0).health, 10_000 * UNIT)


func test_two_grabs_on_the_same_tick_clash_and_push_apart() -> void:
	_start()
	_held[0] = GRAB
	_held[1] = GRAB
	_tick()
	_held = [0, 0]
	var event := _tick_until(Event.GRAB_TECH, 20)
	assert_false(event.is_empty(), "a grab clash")
	assert_eq(_types(_sim.events), [Event.GRAB_TECH], "one clash, no grab")
	assert_eq(_fighter(0).state, State.BLOCKSTUN)
	assert_eq(_fighter(1).state, State.BLOCKSTUN)
	_tick(_tuning.grab_tech_push_ticks)
	assert_almost_eq(_fighter(0).position.distance_to(_fighter(1).position), 3.0, 0.01)
	assert_eq(_fighter(0).health, 10_000 * UNIT)


func test_a_third_fighter_hitting_the_grabbed_fighter_breaks_the_grab() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -2), Vector3(1.8, 0, -1.2)])
	_fighter(0).lock_on_target = 1
	_fighter(2).lock_on_target = 1
	_tap(0, GRAB)
	_tick_until(Event.GRAB, 20)
	_tap(2, LIGHT)
	var event := _tick_until(Event.HIT, 10)
	assert_eq(event.attacker, 2)
	assert_eq(event.target, 1)
	assert_eq(_fighter(1).state, State.HITSTUN)
	assert_eq(_fighter(1).grab_partner, -1)
	assert_eq(_fighter(0).state, State.IDLE, "the grabber lets go")
	assert_eq(_fighter(0).grab_partner, -1)
	_tick(_tuning.grab_hold_ticks)
	assert_false(_log.any(func(e: Dictionary) -> bool: return e.type == Event.THROW))


func test_a_third_fighter_hitting_the_thrower_frees_the_grabbed_fighter() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -2), Vector3(1.8, 0, 0)])
	_fighter(0).lock_on_target = 1
	_fighter(2).lock_on_target = 0
	_tap(0, GRAB)
	_tick_until(Event.GRAB, 20)
	_tap(2, LIGHT)
	var event := _tick_until(Event.HIT, 10)
	assert_eq(event.target, 0)
	assert_eq(_fighter(0).state, State.HITSTUN)
	assert_eq(_fighter(1).state, State.IDLE)
	assert_eq(_fighter(1).grab_partner, -1)


# Push-block

## Fighter 0's light is blocked by fighter 1; ticks to the end of the hitstop.
func _blocked_light() -> void:
	_start()
	_held[1] = BLOCK
	_tick(30)
	_tap(0, LIGHT)
	_tick_until(Event.BLOCK, 10)
	_tick(_moves.light_string[0].hitstop_ticks / 2)


func test_push_block_costs_10_guard() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -40)])
	_held[0] = BLOCK
	_tick(5)
	_tap(0, HEAVY)
	assert_eq(_fighter(0).move_id(), &"push_block")
	assert_eq(_fighter(0).guard, 90 * UNIT)
	assert_true(_fighter(0).blocking, "the guard stays up during the push")


func test_push_block_shoves_the_attacker_out_to_8_m_with_a_short_stun() -> void:
	_blocked_light()
	var guard := _fighter(1).guard
	_tick(_tuning.push_block_from_blockstun_tick)
	_tap(1, HEAVY)
	assert_eq(_fighter(1).move_id(), &"push_block")
	assert_eq(_fighter(1).guard, guard - 10 * UNIT)
	var event := _tick_until(Event.PUSH_BLOCK, 10)
	assert_eq(event.attacker, 1)
	assert_eq(event.target, 0)
	assert_eq(event.damage, 0)
	assert_eq(_fighter(0).state, State.BLOCKSTUN)
	assert_eq(_fighter(0).stun_ticks, _tuning.push_block_stun_ticks)
	_tap(0, LIGHT)
	assert_eq(_fighter(0).state, State.BLOCKSTUN, "cannot act while pushed")
	_tick(_tuning.push_block_stun_ticks - 1)
	assert_almost_eq(_fighter(0).position.distance_to(_fighter(1).position), 8.0, 0.01)
	_tick()
	assert_eq(_fighter(0).state, State.IDLE)
	assert_eq(_fighter(0).health, 10_000 * UNIT, "no damage")


func test_push_block_starts_from_blockstun_only_after_its_first_4_ticks() -> void:
	for wait in 6:
		_blocked_light()
		_tick(wait)
		assert_eq(_fighter(1).state, State.BLOCKSTUN)
		_tap(1, HEAVY)
		if wait < _tuning.push_block_from_blockstun_tick:
			assert_eq(_fighter(1).state, State.BLOCKSTUN, "not on blockstun tick %d" % wait)
		else:
			assert_eq(_fighter(1).move_id(), &"push_block", "on blockstun tick %d" % wait)


func test_heavy_without_blocking_is_never_a_push_block() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -40)])
	_tap(0, HEAVY)
	assert_eq(_fighter(0).move_id(), &"smash")


func test_push_block_needs_more_guard_than_its_cost() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -40)])
	_sim.apply_guard_damage(0, 90)
	_held[0] = BLOCK
	_tick(5)
	_tap(0, HEAVY)
	assert_eq(_fighter(0).state, State.BLOCKING)
	assert_eq(_fighter(0).guard, 10 * UNIT)


# Guard break

func test_a_guard_broken_fighter_cannot_block_until_it_recovers() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -40)])
	_held[0] = BLOCK
	_tick(5)
	_sim.apply_guard_damage(0, 100)
	_tick(10)
	assert_eq(_fighter(0).state, State.GUARD_BROKEN)
	assert_false(_fighter(0).blocking)
	_tick(_sim.meter_tuning.guard_break_ticks)
	assert_eq(_fighter(0).state, State.BLOCKING, "back on guard once it ends")


# Free-for-all

func test_four_fighters_two_blocked_from_the_front_one_through_from_behind() -> void:
	_start([Vector3(0, 0, -2), Vector3(1.4, 0, -1.4), Vector3(0, 0, 2), Vector3.ZERO])
	for index in 3:
		_fighter(index).lock_on_target = 3
	_fighter(3).lock_on_target = -1
	_fighter(3).facing_yaw = 0.0
	_held[3] = BLOCK
	_tick(30)
	_held[0] = LIGHT
	_held[1] = LIGHT
	_held[2] = LIGHT
	_tick()
	_held = [0, 0, 0, BLOCK]
	_tick_until(Event.BLOCK, 10)
	assert_eq(_types(_sim.events), [Event.BLOCK, Event.BLOCK, Event.HIT])
	assert_eq(_fighter(3).state, State.HITSTUN)
	assert_eq(_fighter(3).guard, (100 - 2 * _moves.light_string[0].guard_damage) * UNIT)


func test_four_fighters_two_grabs_in_separate_pairs_both_throw() -> void:
	_start([Vector3(-20, 0, 0), Vector3(-20, 0, -2), Vector3(20, 0, 0), Vector3(20, 0, -2)])
	_held = [GRAB, BLOCK, GRAB, 0]
	_tick()
	_held = [0, BLOCK, 0, 0]
	var event := _tick_until(Event.GRAB, 20)
	assert_eq(_types(_sim.events), [Event.GRAB, Event.GRAB])
	assert_eq(event.target, 1)
	event = _tick_until(Event.THROW, 40)
	assert_eq(_types(_sim.events), [Event.THROW, Event.THROW])
	assert_eq(_fighter(1).health, (10_000 - 1100) * UNIT)
	assert_eq(_fighter(3).health, (10_000 - 1100) * UNIT)


func test_four_fighters_a_grabbed_grabber_loses_its_own_grab() -> void:
	_start([Vector3(0, 0, 2), Vector3.ZERO, Vector3(0, 0, -2), Vector3(30, 0, 0)])
	_fighter(0).lock_on_target = 1
	_fighter(1).lock_on_target = 2
	_held = [GRAB, GRAB, 0, 0]
	_tick()
	_held = [0, 0, 0, 0]
	_tick_until(Event.GRAB, 20)
	assert_eq(_types(_sim.events), [Event.GRAB], "only the first grab in index order")
	assert_eq(_fighter(1).state, State.GRABBED)
	assert_eq(_fighter(2).state, State.IDLE, "never grabbed")


func test_state_hash_covers_the_defense_state() -> void:
	_start()
	var before := _sim.state_hash()
	_fighter(0).perfect_block_armed = true
	var armed := _sim.state_hash()
	assert_ne(armed, before)
	_fighter(0).perfect_block_lockout = 3
	var locked := _sim.state_hash()
	assert_ne(locked, armed)
	_fighter(0).grab_partner = 1
	var grabbing := _sim.state_hash()
	assert_ne(grabbing, locked)
	_fighter(0).extra_recovery_ticks = 16
	assert_ne(_sim.state_hash(), grabbing)
