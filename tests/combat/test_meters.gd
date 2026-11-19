extends GutTest

const DASH := FighterInput.Action.DASH
const BLOCK := FighterInput.Action.BLOCK
const CHARGE := FighterInput.Action.CHARGE
const LOCK := FighterInput.Action.LOCK_TOGGLE
const RIGHT := Vector2(1, 0)
const FORWARD := Vector2(0, 1)
const UNIT := FighterState.METER_UNIT

var _sim: CombatSim
var _meters: MeterTuning
var _previous: Array[FighterInput] = []


## Starts a 1v1 sim: fighter 0 under test at the origin, fighter 1 far ahead.
func _start() -> void:
	_sim = CombatSim.new()
	_meters = _sim.meter_tuning
	_sim.add_fighter(Vector3.ZERO)
	_sim.add_fighter(Vector3(0, 0, -60))
	_previous = [FighterInput.new(), FighterInput.new()]


## Runs ticks with fighter 0 holding these controls; fighter 1 stands still.
func _drive(ticks: int, held: int = 0, move: Vector2 = Vector2.ZERO) -> void:
	for _i in ticks:
		var inputs: Array[FighterInput] = [
			FighterInput.from_held(held, _previous[0]),
			FighterInput.from_held(0, _previous[1]),
		]
		inputs[0].move = move
		_sim.tick(inputs)
		_previous = inputs


func _fighter() -> FighterState:
	return _sim.fighters[0]


# Fixed point

func test_a_fighter_starts_with_full_health_and_guard_half_ki_and_no_burst() -> void:
	_start()
	assert_eq(_fighter().health, 10_000 * UNIT)
	assert_eq(_fighter().guard, 100 * UNIT)
	assert_eq(_fighter().ki, 50 * UNIT)
	assert_eq(_fighter().burst, 0)
	assert_eq(_fighter().health_display(), 10_000.0)
	assert_eq(_fighter().ki_display(), 50.0)


func test_passive_ki_gains_exactly_its_rate_over_60_ticks() -> void:
	_start()
	_drive(60)
	assert_eq(_fighter().ki, (50 + _meters.ki_passive_per_second) * UNIT)
	assert_eq(_fighter().ki_display(), 52.0)


func test_grey_regen_and_guard_regen_are_exact_per_tick_over_60_ticks() -> void:
	_start()
	_sim.apply_damage(0, 1, 1_000)
	_sim.apply_guard_damage(0, 90)
	_drive(_meters.grey_regen_delay_ticks)
	var health_before := _fighter().health
	var guard_before := _fighter().guard
	_drive(60)
	assert_eq(_fighter().health - health_before, _meters.grey_regen_per_second * UNIT)
	assert_eq(_fighter().guard - guard_before, _meters.guard_regen_per_second * UNIT)


func test_ki_never_goes_above_the_maximum() -> void:
	_start()
	_fighter().ki = 100 * UNIT - 1
	_drive(5)
	assert_eq(_fighter().ki, _meters.ki_max * UNIT)


# Health and grey part

func test_damage_removes_health_and_turns_40_percent_of_it_grey() -> void:
	_start()
	_sim.apply_damage(0, 1, 1_000)
	assert_eq(_fighter().health, 9_000 * UNIT)
	assert_eq(_fighter().grey_health, 400 * UNIT)
	assert_eq(_fighter().grey_health_display(), 400.0)


func test_the_grey_part_regenerates_only_after_180_quiet_ticks() -> void:
	_start()
	_sim.apply_damage(0, 1, 1_000)
	_drive(_meters.grey_regen_delay_ticks)
	assert_eq(_fighter().health, 9_000 * UNIT, "nothing back during the 180 quiet ticks")
	_drive(1)
	assert_eq(_fighter().health, 9_000 * UNIT + _meters.grey_regen_per_second)
	_drive(400 * UNIT / _meters.grey_regen_per_second)
	assert_eq(_fighter().health, 9_400 * UNIT, "all of the grey part comes back")
	assert_eq(_fighter().grey_health, 0)


func test_a_new_hit_restarts_the_grey_regen_wait() -> void:
	_start()
	_sim.apply_damage(0, 1, 1_000)
	_drive(_meters.grey_regen_delay_ticks - 1)
	_sim.apply_damage(0, 1, 500)
	_drive(_meters.grey_regen_delay_ticks)
	assert_eq(_fighter().health, 8_500 * UNIT, "the wait started over")


func test_the_grey_part_is_lost_when_a_new_combo_starts() -> void:
	_start()
	_sim.apply_damage(0, 1, 1_000)
	_drive(_meters.grey_regen_delay_ticks + 10)
	_sim.apply_damage(0, 1, 500)
	var health_after_hit := 9_000 * UNIT + 10 * _meters.grey_regen_per_second - 500 * UNIT
	assert_eq(_fighter().health, health_after_hit)
	assert_eq(_fighter().grey_health, 200 * UNIT, "only the new hit's grey part is left")


func test_the_grey_part_builds_up_across_hits_while_in_hitstun() -> void:
	_start()
	_sim.apply_damage(0, 1, 1_000)
	_fighter().enter_state(FighterState.State.HITSTUN)
	_sim.apply_damage(0, 1, 500)
	assert_eq(_fighter().health, 8_500 * UNIT)
	assert_eq(_fighter().grey_health, 600 * UNIT, "40% of the whole combo")


# Charging

func test_holding_charge_charges_ki_at_25_per_second_and_stops_movement() -> void:
	_start()
	_drive(30, 0, FORWARD)
	_drive(1, CHARGE, FORWARD)
	assert_eq(_fighter().state, FighterState.State.CHARGING)
	assert_eq(_fighter().velocity, Vector3.ZERO)
	var ki_before := _fighter().ki
	var position_before := _fighter().position
	_drive(60, CHARGE, FORWARD)
	assert_eq(_fighter().ki - ki_before, _meters.ki_charge_per_second * UNIT)
	assert_eq(_fighter().position, position_before)


func test_charging_in_flight_hovers_in_place() -> void:
	_start()
	_fighter().position.y = 40.0
	_fighter().enter_state(FighterState.State.FLYING)
	_drive(1, CHARGE)
	assert_eq(_fighter().state, FighterState.State.CHARGING)
	_drive(60, CHARGE)
	assert_eq(_fighter().position.y, 40.0)


func test_releasing_charge_ends_charging() -> void:
	_start()
	_drive(10, CHARGE)
	_drive(1)
	assert_eq(_fighter().state, FighterState.State.IDLE)


func test_a_hit_cancels_charging() -> void:
	_start()
	_drive(10, CHARGE)
	_sim.apply_damage(0, 1, 100)
	assert_eq(_fighter().state, FighterState.State.IDLE)
	_drive(5, CHARGE)
	assert_eq(_fighter().state, FighterState.State.IDLE, "holding on does not restart it")


func test_pressing_another_action_cancels_charging() -> void:
	_start()
	_drive(10, CHARGE)
	_drive(1, CHARGE | FighterInput.Action.TRANSFORM)
	assert_eq(_fighter().state, FighterState.State.IDLE)


func test_a_dash_pressed_while_charging_cancels_it_and_dashes() -> void:
	_start()
	_drive(10, CHARGE)
	_drive(1, CHARGE | DASH, RIGHT)
	assert_eq(_fighter().state, FighterState.State.DASHING)


func test_toggling_lock_on_does_not_cancel_charging() -> void:
	_start()
	_drive(10, CHARGE)
	_drive(1, CHARGE | LOCK)
	assert_eq(_fighter().state, FighterState.State.CHARGING)


# Ki costs on movement

func test_a_dash_costs_its_ki() -> void:
	_start()
	_drive(1, DASH, RIGHT)
	assert_eq(_fighter().dash_kind, FighterState.DashKind.STEP)
	assert_eq(_fighter().ki, (50 - _meters.dash_ki_cost) * UNIT + _meters.ki_passive_per_second)


func test_a_rush_dash_costs_its_ki() -> void:
	_start()
	_sim.lock_everyone_onto_nearest()
	_drive(1, DASH, FORWARD)
	assert_eq(_fighter().dash_kind, FighterState.DashKind.RUSH)
	assert_eq(_fighter().ki, (50 - _meters.rush_dash_ki_cost) * UNIT + _meters.ki_passive_per_second)


func test_a_vanish_step_costs_its_ki() -> void:
	_start()
	_drive(1, DASH | BLOCK, RIGHT)
	assert_eq(_fighter().state, FighterState.State.VANISHING)
	assert_eq(_fighter().ki, (50 - _meters.vanish_step_ki_cost) * UNIT + _meters.ki_passive_per_second)


func test_a_dash_is_refused_without_enough_ki() -> void:
	_start()
	_fighter().ki = _meters.dash_ki_cost * UNIT - 1
	_drive(1, DASH, RIGHT)
	assert_ne(_fighter().state, FighterState.State.DASHING)
	assert_eq(_fighter().ki, _meters.dash_ki_cost * UNIT - 1 + _meters.ki_passive_per_second)


func test_a_rush_dash_is_refused_without_enough_ki() -> void:
	_start()
	_sim.lock_everyone_onto_nearest()
	_fighter().ki = _meters.rush_dash_ki_cost * UNIT - 1
	_drive(1, DASH, FORWARD)
	assert_ne(_fighter().state, FighterState.State.DASHING)


func test_a_vanish_step_is_refused_without_enough_ki_and_does_not_dash_instead() -> void:
	_start()
	_fighter().ki = _meters.vanish_step_ki_cost * UNIT - 1
	_drive(1, DASH | BLOCK, RIGHT)
	assert_ne(_fighter().state, FighterState.State.VANISHING)
	assert_ne(_fighter().state, FighterState.State.DASHING)
	assert_eq(_fighter().ki, _meters.vanish_step_ki_cost * UNIT - 1 + _meters.ki_passive_per_second)


func test_a_refused_dash_comes_out_once_ki_arrives_inside_the_buffer() -> void:
	_start()
	_fighter().ki = _meters.dash_ki_cost * UNIT - _meters.ki_passive_per_second
	_drive(1, DASH, RIGHT)
	assert_ne(_fighter().state, FighterState.State.DASHING)
	_drive(1, DASH, RIGHT)
	assert_eq(_fighter().state, FighterState.State.DASHING)


func test_try_spend_ki_spends_only_when_there_is_enough() -> void:
	_start()
	assert_true(_sim.try_spend_ki(0, 25))
	assert_eq(_fighter().ki, 25 * UNIT)
	assert_false(_sim.try_spend_ki(0, 40))
	assert_eq(_fighter().ki, 25 * UNIT)


func test_landed_and_blocked_hits_give_ki() -> void:
	_start()
	_sim.add_landed_hit_ki(0)
	assert_eq(_fighter().ki, (50 + _meters.ki_per_landed_hit) * UNIT)
	_sim.add_blocked_hit_ki(0)
	assert_eq(_fighter().ki, (50 + _meters.ki_per_landed_hit + _meters.ki_per_blocked_hit) * UNIT)


# Guard

func test_guard_damage_lowers_guard() -> void:
	_start()
	_sim.apply_guard_damage(0, 18)
	assert_eq(_fighter().guard, 82 * UNIT)
	assert_eq(_fighter().guard_display(), 82.0)


func test_guard_regenerates_only_after_60_ticks_without_blocking() -> void:
	_start()
	_sim.apply_guard_damage(0, 30)
	_drive(_meters.guard_regen_delay_ticks)
	assert_eq(_fighter().guard, 70 * UNIT)
	_drive(1)
	assert_eq(_fighter().guard, 70 * UNIT + _meters.guard_regen_per_second)


func test_blocking_holds_guard_regeneration_back() -> void:
	_start()
	_sim.apply_guard_damage(0, 30)
	_drive(200, BLOCK)
	assert_true(_fighter().blocking)
	assert_eq(_fighter().guard, 70 * UNIT)
	_drive(1)
	assert_false(_fighter().blocking)
	_drive(_meters.guard_regen_delay_ticks - 1)
	assert_eq(_fighter().guard, 70 * UNIT)
	_drive(1)
	assert_gt(_fighter().guard, 70 * UNIT)


func test_guard_regenerates_up_to_its_maximum() -> void:
	_start()
	_sim.apply_guard_damage(0, 1)
	_drive(_meters.guard_regen_delay_ticks + 200)
	assert_eq(_fighter().guard, 100 * UNIT)


func test_breaking_the_guard_gives_60_ticks_of_guard_broken() -> void:
	_start()
	_sim.apply_guard_damage(0, 100)
	assert_eq(_fighter().guard, 0)
	assert_eq(_fighter().state, FighterState.State.GUARD_BROKEN)
	_drive(_meters.guard_break_ticks, DASH, RIGHT)
	assert_eq(_fighter().state, FighterState.State.GUARD_BROKEN, "stunned: no dash, no movement")
	assert_eq(_fighter().position, Vector3(0, 1, 0))
	_drive(1)
	assert_eq(_fighter().state, FighterState.State.IDLE)


func test_a_fighter_with_lower_guard_max_starts_with_less_guard() -> void:
	_sim = CombatSim.new()
	var stats := FighterStats.new()
	stats.guard_max = 80
	stats.max_health = 8_500
	var fighter := _sim.add_fighter(Vector3.ZERO, stats)
	assert_eq(fighter.guard, 80 * UNIT)
	assert_eq(fighter.health, 8_500 * UNIT)


# Burst

func test_dealing_and_taking_damage_build_burst() -> void:
	_start()
	_sim.apply_damage(1, 0, 1_000)
	assert_eq(_sim.fighters[0].burst, 10 * UNIT, "+1 per 100 dealt")
	assert_eq(_sim.fighters[1].burst, 15 * UNIT, "+1.5 per 100 taken")


func test_a_perfect_block_builds_burst() -> void:
	_start()
	_sim.add_perfect_block_burst(0)
	assert_eq(_fighter().burst, 15 * UNIT)


func test_burst_is_capped_at_three_stocks() -> void:
	_start()
	for _i in 30:
		_sim.add_perfect_block_burst(0)
	assert_eq(_fighter().burst, 300 * UNIT)
	assert_eq(_fighter().burst_display(), 300.0)


func test_try_spend_burst_spends_whole_stocks_only_when_there_are_enough() -> void:
	_start()
	_fighter().burst = 150 * UNIT
	assert_false(_sim.try_spend_burst(0, 2))
	assert_eq(_fighter().burst, 150 * UNIT)
	assert_true(_sim.try_spend_burst(0, 1))
	assert_eq(_fighter().burst, 50 * UNIT)


# Last Stand

func test_last_stand_gives_one_free_stock_once_per_match() -> void:
	_start()
	_sim.apply_damage(0, 1, 8_400)
	assert_false(_fighter().last_stand_used, "16% health is not below 15%")
	var burst_before := _fighter().burst
	_sim.apply_damage(0, 1, 200)
	assert_true(_fighter().last_stand_used)
	assert_eq(_fighter().burst - burst_before, 100 * UNIT + 200 * UNIT * 15 / 1000)
	_sim.start_round()
	_fighter().burst = 0
	_sim.apply_damage(0, 1, 8_600)
	assert_eq(_fighter().burst, 8_600 * UNIT * 15 / 1000, "no second free stock")


# Rounds

func test_start_round_resets_everything_except_burst() -> void:
	_start()
	_sim.apply_damage(0, 1, 3_000)
	_sim.apply_guard_damage(0, 100)
	assert_true(_sim.try_spend_ki(0, 40))
	_fighter().blocking = true
	var burst := _fighter().burst
	_sim.start_round()
	assert_eq(_fighter().health, 10_000 * UNIT)
	assert_eq(_fighter().grey_health, 0)
	assert_eq(_fighter().ki, 50 * UNIT)
	assert_eq(_fighter().guard, 100 * UNIT)
	assert_false(_fighter().blocking)
	assert_eq(_fighter().state, FighterState.State.IDLE, "out of guard break")
	assert_eq(_fighter().burst, burst)
	assert_gt(burst, 0)


func test_a_knockout_ends_the_round_and_names_the_winner() -> void:
	_start()
	assert_false(_sim.round_over)
	assert_eq(_sim.round_winner, -1)
	_sim.apply_damage(0, 1, 20_000)
	assert_eq(_fighter().health, 0)
	assert_eq(_fighter().grey_health, 0)
	assert_true(_fighter().is_knocked_out())
	assert_true(_sim.round_over)
	assert_eq(_sim.round_winner, 1)


func test_damage_past_zero_counts_only_the_health_that_was_left() -> void:
	_start()
	_sim.apply_damage(1, 0, 20_000)
	assert_eq(_sim.fighters[0].burst, 100 * UNIT, "10,000 dealt, not 20,000")


func test_inputs_and_meters_freeze_after_a_knockout() -> void:
	_start()
	_sim.apply_damage(1, 0, 20_000)
	var ki_before := _fighter().ki
	_drive(30, DASH, RIGHT)
	assert_ne(_fighter().state, FighterState.State.DASHING)
	assert_eq(_fighter().position, Vector3(0, 1, 0))
	assert_eq(_fighter().ki, ki_before)
	_sim.apply_damage(0, 1, 500)
	assert_eq(_fighter().health, 10_000 * UNIT, "no damage after the round ends")


func test_start_round_after_a_knockout_lets_the_fight_continue() -> void:
	_start()
	_sim.apply_damage(1, 0, 20_000)
	_sim.start_round()
	assert_false(_sim.round_over)
	assert_eq(_sim.round_winner, -1)
	_drive(1, DASH, RIGHT)
	assert_eq(_fighter().state, FighterState.State.DASHING)


func test_state_hash_covers_the_meters() -> void:
	_start()
	var before := _sim.state_hash()
	_sim.add_perfect_block_burst(0)
	var after_burst := _sim.state_hash()
	assert_ne(after_burst, before)
	_fighter().blocking = true
	assert_ne(_sim.state_hash(), after_burst)


func test_a_custom_meter_tuning_changes_the_costs() -> void:
	var meters := MeterTuning.new()
	meters.dash_ki_cost = 50
	_sim = CombatSim.new(0, null, meters)
	_meters = meters
	_sim.add_fighter(Vector3.ZERO)
	_sim.add_fighter(Vector3(0, 0, -60))
	_previous = [FighterInput.new(), FighterInput.new()]
	_drive(1, DASH, RIGHT)
	assert_eq(_fighter().ki, _meters.ki_passive_per_second)


func test_a_press_buffered_before_a_knockout_does_not_come_out_after_it() -> void:
	_start()
	_fighter().ki = 0
	_drive(1, DASH, RIGHT)
	_fighter().ki = 50 * UNIT
	_sim.apply_damage(1, 0, 20_000)
	_drive(3, DASH, RIGHT)
	assert_ne(_fighter().state, FighterState.State.DASHING)
