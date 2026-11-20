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


# --- T-UX1: descend key and double-tap dive ---

func test_descend_defaults_to_c_and_never_ctrl_on_the_web() -> void:
	assert_eq(InputBindings.default_keys(InputBindings.DESCEND, true), [KEY_C])
	assert_false(KEY_CTRL in InputBindings.default_keys(InputBindings.DESCEND, true))
	assert_eq(InputBindings.default_keys(InputBindings.DESCEND, false), [KEY_C, KEY_CTRL], "Ctrl is a desktop alternate")


func test_default_keys_never_share_a_key_between_actions() -> void:
	var owner_of := {}
	for action: StringName in InputBindings.DEFAULT_KEYS:
		for key in InputBindings.default_keys(action, false):
			assert_false(owner_of.has(key), "%s used by %s and %s" % [OS.get_keycode_string(key), owner_of.get(key), action])
			owner_of[key] = action


func test_no_default_key_is_a_browser_modifier() -> void:
	for action: StringName in InputBindings.DEFAULT_KEYS:
		for key in InputBindings.default_keys(action, true):
			assert_false(InputBindings.is_blocked_key(key, true), "%s on %s" % [OS.get_keycode_string(key), action])


func test_ctrl_cmd_and_alt_are_blocked_only_on_the_web() -> void:
	for key in [KEY_CTRL, KEY_META, KEY_ALT]:
		assert_true(InputBindings.is_blocked_key(key, true))
		assert_false(InputBindings.is_blocked_key(key, false))
	assert_false(InputBindings.is_blocked_key(KEY_C, true))


func test_holding_descend_flies_down_and_letting_go_stops() -> void:
	assert_eq(_reader.vertical_for_tick(false, true, false), -1)
	assert_eq(_reader.vertical_for_tick(false, false, false), 0)
	assert_false(_reader.is_diving(), "one tap is not a dive")


func test_double_tap_descend_keeps_diving_until_landing() -> void:
	_reader.vertical_for_tick(false, true, false)
	_reader.vertical_for_tick(false, false, false)
	assert_eq(_reader.vertical_for_tick(false, true, false), -1)
	assert_true(_reader.is_diving())
	for i in 100:
		assert_eq(_reader.vertical_for_tick(false, false, false), -1, "still diving after release")
	assert_eq(_reader.vertical_for_tick(false, false, true), 0, "landing ends the dive")
	assert_false(_reader.is_diving())


func test_ascend_cancels_a_dive() -> void:
	_reader.vertical_for_tick(false, true, false)
	_reader.vertical_for_tick(false, false, false)
	_reader.vertical_for_tick(false, true, false)
	_reader.vertical_for_tick(false, false, false)
	assert_eq(_reader.vertical_for_tick(true, false, false), 1)
	assert_false(_reader.is_diving())


func test_slow_taps_are_not_a_dive() -> void:
	_reader.vertical_for_tick(false, true, false)
	for i in KeyboardMouseInput.DOUBLE_TAP_TICKS + 2:
		_reader.vertical_for_tick(false, false, false)
	_reader.vertical_for_tick(false, true, false)
	assert_eq(_reader.vertical_for_tick(false, false, false), 0)
	assert_false(_reader.is_diving())


func test_double_tap_on_the_ground_is_not_a_dive() -> void:
	_reader.vertical_for_tick(false, true, true)
	_reader.vertical_for_tick(false, false, true)
	_reader.vertical_for_tick(false, true, true)
	assert_false(_reader.is_diving())


func test_dive_drives_the_tick_input_through_read_tick() -> void:
	Input.action_press(InputBindings.DESCEND)
	_reader.read_tick(0.0, Vector2.ZERO)
	Input.action_release(InputBindings.DESCEND)
	_reader.read_tick(0.0, Vector2.ZERO)
	Input.action_press(InputBindings.DESCEND)
	_reader.read_tick(0.0, Vector2.ZERO)
	Input.action_release(InputBindings.DESCEND)
	assert_eq(_reader.read_tick(0.0, Vector2.ZERO).vertical, -1)
	assert_eq(_reader.read_tick(0.0, Vector2.ZERO, true).vertical, 0)
