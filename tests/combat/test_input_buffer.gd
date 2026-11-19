extends GutTest

## An action no sim system consumes yet, so the buffer itself is under test.
const PRESS := FighterInput.Action.TRANSFORM
const DASH := FighterInput.Action.DASH
const BLOCK := FighterInput.Action.BLOCK

var _sim: CombatSim
var _previous: FighterInput


func before_each() -> void:
	_sim = CombatSim.new()
	_sim.add_fighter(Vector3.ZERO)
	_previous = FighterInput.new()


## Runs ticks with the fighter holding exactly these actions.
func _hold(held: int, ticks: int = 1) -> void:
	for _i in ticks:
		var input := FighterInput.from_held(held, _previous)
		var inputs: Array[FighterInput] = [input]
		_sim.tick(inputs)
		_previous = input


func _state() -> FighterState.State:
	return _sim.fighters[0].state


func test_a_press_is_buffered_on_the_tick_it_happens() -> void:
	_hold(PRESS)
	assert_true(_sim.is_buffered(0, PRESS))


func test_a_press_can_still_be_consumed_on_the_last_of_its_six_ticks() -> void:
	_hold(PRESS)
	_hold(0, CombatSim.INPUT_BUFFER_TICKS - 1)
	assert_true(_sim.consume_buffered(0, PRESS))


func test_a_press_expires_after_six_ticks() -> void:
	_hold(PRESS)
	_hold(0, CombatSim.INPUT_BUFFER_TICKS)
	assert_false(_sim.is_buffered(0, PRESS))
	assert_false(_sim.consume_buffered(0, PRESS))


func test_a_buffered_press_is_consumed_only_once() -> void:
	_hold(PRESS)
	assert_true(_sim.consume_buffered(0, PRESS))
	assert_false(_sim.consume_buffered(0, PRESS))


func test_holding_a_button_does_not_keep_it_buffered() -> void:
	_hold(PRESS, CombatSim.INPUT_BUFFER_TICKS + 1)
	assert_false(_sim.is_buffered(0, PRESS))


func test_pressing_again_after_consuming_buffers_a_new_press() -> void:
	_hold(PRESS)
	_sim.consume_buffered(0, PRESS)
	_hold(0)
	_hold(PRESS)
	assert_true(_sim.consume_buffered(0, PRESS))


func test_buffering_one_action_leaves_the_others_alone() -> void:
	_hold(PRESS)
	assert_false(_sim.is_buffered(0, FighterInput.Action.HEAVY))


func test_dash_and_block_pressed_on_the_same_tick_start_a_vanish_step() -> void:
	_hold(DASH | BLOCK)
	assert_eq(_state(), FighterState.State.VANISHING)
	assert_false(_sim.has_vanish_input(0), "the vanish input is used up")


func test_block_pressed_within_the_buffer_after_dash_still_vanishes() -> void:
	_hold(DASH)
	assert_eq(_state(), FighterState.State.DASHING)
	_hold(DASH | BLOCK)
	assert_eq(_state(), FighterState.State.VANISHING)


func test_dash_pressed_within_the_buffer_after_block_vanishes() -> void:
	_hold(BLOCK)
	_hold(BLOCK, CombatSim.INPUT_BUFFER_TICKS - 2)
	_hold(BLOCK | DASH)
	assert_eq(_state(), FighterState.State.VANISHING)


func test_dash_and_block_pressed_further_apart_than_the_buffer_do_not_vanish() -> void:
	_hold(BLOCK)
	_hold(0, CombatSim.INPUT_BUFFER_TICKS)
	_hold(DASH)
	assert_eq(_state(), FighterState.State.DASHING)


func test_a_dash_pressed_during_a_vanish_step_comes_out_when_it_ends() -> void:
	var vanish_ticks := _sim.tuning.vanish_step_ticks
	_hold(DASH | BLOCK)
	_hold(0, vanish_ticks - 3)
	_hold(DASH)
	assert_eq(_state(), FighterState.State.VANISHING, "still vanished when dash is pressed")
	_hold(0, 2)
	assert_eq(_state(), FighterState.State.DASHING)
