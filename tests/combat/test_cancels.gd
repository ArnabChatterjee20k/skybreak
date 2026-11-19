extends GutTest

const LIGHT := FighterInput.Action.LIGHT
const HEAVY := FighterInput.Action.HEAVY
const VANISH := FighterInput.Action.DASH | FighterInput.Action.BLOCK
const Level := MoveData.CancelLevel
const UNIT := FighterState.METER_UNIT

var _sim: CombatSim
var _moves: MoveSet
var _previous: Array[FighterInput] = []


func before_each() -> void:
	_sim = CombatSim.new()
	_sim.add_fighter(Vector3.ZERO)
	_sim.add_fighter(Vector3(0, 0, -6))
	_sim.lock_everyone_onto_nearest()
	_moves = _fighter().stats.move_set
	_previous = [FighterInput.new(), FighterInput.new()]


func _drive(ticks: int, held: int = 0) -> void:
	for _i in ticks:
		var inputs: Array[FighterInput] = [
			FighterInput.from_held(held, _previous[0]),
			FighterInput.from_held(0, _previous[1]),
		]
		_sim.tick(inputs)
		_previous = inputs


func _fighter() -> FighterState:
	return _sim.fighters[0]


## Neutral ticks until the current move is one tick short of move_tick.
func _wait_until(move_tick: int) -> void:
	_drive(move_tick - _fighter().move_tick - 1)


## Starts light 1 and lets it touch the opponent on its first active tick.
func _light_that_hits(blocked := false) -> MoveData:
	_drive(1, LIGHT)
	var light := _moves.light_string[0]
	_wait_until(light.startup_ticks + 1)
	_sim.register_contact(0, blocked)
	return light


func test_a_light_that_hit_cancels_into_a_heavy_inside_its_window() -> void:
	var light := _light_that_hits()
	_wait_until(light.cancel_start_tick + 1)
	_drive(1, HEAVY)
	assert_eq(_fighter().move_id(), &"smash")
	assert_eq(_fighter().move_tick, 0)


func test_a_blocked_light_also_opens_the_cancel_window() -> void:
	var light := _light_that_hits(true)
	_wait_until(light.cancel_start_tick + 1)
	_drive(1, HEAVY)
	assert_eq(_fighter().move_id(), &"smash")


func test_a_whiffed_light_cannot_be_cancelled() -> void:
	_drive(1, LIGHT)
	_wait_until(_moves.light_string[0].cancel_start_tick + 2)
	_drive(1, HEAVY)
	assert_eq(_fighter().move_id(), &"light_1")
	assert_false(_sim.can_cancel_into(0, Level.HEAVY))


func test_a_heavy_pressed_after_the_cancel_window_does_not_cancel() -> void:
	var light := _light_that_hits()
	_wait_until(light.cancel_end_tick)
	_drive(1, HEAVY)
	assert_eq(_fighter().move_id(), &"light_1")


func test_a_heavy_buffered_before_the_window_comes_out_when_it_opens() -> void:
	_drive(1, LIGHT)
	var light := _moves.light_string[0]
	_sim.register_contact(0, false)
	_wait_until(light.cancel_start_tick - 3)
	_drive(1, HEAVY)
	assert_eq(_fighter().move_id(), &"light_1", "window not open yet")
	_drive(2)
	assert_eq(_fighter().move_id(), &"light_1")
	_drive(1)
	assert_eq(_fighter().move_id(), &"smash", "out on the window's first tick")


func test_cancels_go_only_upward() -> void:
	var light := _light_that_hits()
	_wait_until(light.cancel_start_tick + 1)
	_drive(1)
	assert_false(_sim.can_cancel_into(0, Level.LIGHT), "light into light only through the string")
	for level in [Level.HEAVY, Level.SPECIAL, Level.VANISH, Level.ULTIMATE]:
		assert_true(_sim.can_cancel_into(0, level), "light into %s" % Level.keys()[level - 1])
	_drive(1, HEAVY)
	_drive(_moves.smash.startup_ticks)
	_sim.register_contact(0, false)
	_drive(1)
	assert_false(_sim.can_cancel_into(0, Level.LIGHT), "never backwards")
	assert_false(_sim.can_cancel_into(0, Level.HEAVY), "never the same level")
	for level in [Level.SPECIAL, Level.VANISH, Level.ULTIMATE]:
		assert_true(_sim.can_cancel_into(0, level), "heavy into %s" % Level.keys()[level - 1])


func test_a_heavy_cannot_cancel_into_another_heavy() -> void:
	_drive(1, HEAVY)
	_drive(_moves.smash.startup_ticks)
	_sim.register_contact(0, false)
	_drive(1)
	_drive(1, HEAVY)
	assert_eq(_fighter().move_id(), &"smash")
	assert_eq(_fighter().move_tick, _moves.smash.startup_ticks + 2)


func test_a_light_press_does_not_cancel_a_heavy() -> void:
	_drive(1, HEAVY)
	_drive(_moves.smash.startup_ticks)
	_sim.register_contact(0, false)
	_drive(1, LIGHT)
	assert_eq(_fighter().move_id(), &"smash")


func test_a_heavy_that_hit_cancels_into_a_vanish_step_for_its_ki() -> void:
	_drive(1, HEAVY)
	_drive(_moves.smash.startup_ticks)
	_sim.register_contact(0, false)
	var ki_before := _fighter().ki
	_drive(1, VANISH)
	assert_eq(_fighter().state, FighterState.State.VANISHING)
	assert_eq(_fighter().move_id(), &"", "the attack is over")
	var passive := _sim.meter_tuning.ki_passive_per_second
	assert_eq(_fighter().ki, ki_before - _sim.meter_tuning.vanish_step_ki_cost * UNIT + passive)


func test_a_light_that_hit_cancels_into_a_vanish_step() -> void:
	var light := _light_that_hits()
	_wait_until(light.cancel_start_tick + 1)
	_drive(1, VANISH)
	assert_eq(_fighter().state, FighterState.State.VANISHING)


func test_a_whiffed_attack_cannot_vanish() -> void:
	_drive(1, HEAVY)
	_drive(_moves.smash.startup_ticks)
	_drive(1, VANISH)
	assert_eq(_fighter().state, FighterState.State.ATTACKING)


func test_a_vanish_cancel_without_enough_ki_does_nothing() -> void:
	_fighter().ki = 0
	_drive(1, HEAVY)
	_drive(_moves.smash.startup_ticks)
	_sim.register_contact(0, false)
	_drive(1, VANISH)
	assert_eq(_fighter().state, FighterState.State.ATTACKING)


func test_contact_is_ignored_when_not_attacking() -> void:
	_sim.register_contact(0, false)
	assert_false(_fighter().contact_hit)


func test_contact_is_forgotten_when_the_next_move_starts() -> void:
	var light := _light_that_hits()
	_wait_until(light.cancel_start_tick + 1)
	_drive(1, HEAVY)
	assert_false(_fighter().contact_hit)
	assert_false(_sim.can_cancel_into(0, Level.VANISH))


func test_a_light_on_hit_can_cancel_to_a_heavy_and_then_to_a_vanish_step() -> void:
	var light := _light_that_hits()
	_wait_until(light.cancel_start_tick + 1)
	_drive(1, HEAVY)
	_drive(_moves.smash.startup_ticks)
	_sim.register_contact(0, true)
	_drive(1, VANISH)
	assert_eq(_fighter().state, FighterState.State.VANISHING)


func test_state_hash_covers_attack_state() -> void:
	_drive(1, LIGHT)
	var before := _sim.state_hash()
	_sim.register_contact(0, false)
	assert_ne(_sim.state_hash(), before, "contact")
	before = _sim.state_hash()
	_fighter().string_dropped = true
	assert_ne(_sim.state_hash(), before, "string drop")
	before = _sim.state_hash()
	_fighter().move = _moves.smash
	assert_ne(_sim.state_hash(), before, "move")
