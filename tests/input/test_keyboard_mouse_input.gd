extends GutTest

var _reader: KeyboardMouseInput


func before_each() -> void:
	_reader = add_child_autofree(KeyboardMouseInput.new())


func after_each() -> void:
	for action_name in InputMap.get_actions():
		Input.action_release(action_name)


func test_defaults_bind_every_fighter_action() -> void:
	for action_name in InputBindings.FIGHTER_ACTIONS.values():
		assert_true(InputMap.has_action(action_name), "%s bound" % action_name)
		assert_false(InputMap.action_get_events(action_name).is_empty(), "%s has an event" % action_name)


func test_held_action_appears_in_tick_input() -> void:
	Input.action_press(&"fighter_heavy")
	var input := _reader.read_tick(0.0, Vector2.ZERO)
	assert_true(input.is_held(FighterInput.Action.HEAVY))
	assert_true(input.is_pressed(FighterInput.Action.HEAVY))


func test_forward_and_ascend_map_to_move_and_vertical() -> void:
	Input.action_press(InputBindings.MOVE_FORWARD)
	Input.action_press(InputBindings.ASCEND)
	var input := _reader.read_tick(0.0, Vector2.ZERO)
	assert_almost_eq(input.move.y, 1.0, 0.001)
	assert_eq(input.vertical, 1)


func test_second_read_of_same_hold_is_not_a_new_press() -> void:
	Input.action_press(&"fighter_light")
	_reader.read_tick(0.0, Vector2.ZERO)
	var second := _reader.read_tick(0.0, Vector2.ZERO)
	assert_true(second.is_held(FighterInput.Action.LIGHT))
	assert_false(second.is_pressed(FighterInput.Action.LIGHT))
