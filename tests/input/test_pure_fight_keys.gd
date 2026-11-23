extends GutTest
## Pure Fight's two players share one laptop keyboard with no numpad: every default is a main
## keyboard key, P2's arrows and right-hand cluster drive every action, and no key reaches both.

const A := FighterInput.Action
const S := PureFighter.State
const P2_KEYS := {
	"light": KEY_COMMA, "medium": KEY_PERIOD, "heavy": KEY_SLASH, "throw": KEY_SEMICOLON,
	"technique": KEY_APOSTROPHE, "finisher": KEY_BRACKETRIGHT, "block": KEY_BRACKETLEFT,
}

var _held: Array[InputEventKey] = []


func before_each() -> void:
	PureFightKeys.install(0)
	PureFightKeys.install(1)


func after_each() -> void:
	_release_all()


func _key(code: Key, location := KEY_LOCATION_UNSPECIFIED) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.location = location
	return event


func _press(source: InputEventKey) -> void:
	var event := source.duplicate() as InputEventKey
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	_held.append(event)


func _release_all() -> void:
	for event in _held:
		var up := event.duplicate() as InputEventKey
		up.pressed = false
		Input.parse_input_event(up)
	Input.flush_buffered_events()
	_held.clear()


func _hold(codes: Array) -> void:
	_release_all()
	for code: Variant in codes:
		_press(code if code is InputEventKey else _key(code))


func _all_default_keys() -> Array[Key]:
	var keys: Array[Key] = []
	for player in 2:
		for action in PureFightKeys.ACTIONS:
			for event in PureFightKeys.default_events(player, action):
				keys.append(event.physical_keycode)
	for action: StringName in InputBindings.DEFAULT_KEYS:
		for web in [true, false]:
			for code: Key in InputBindings.default_keys(action, web):
				keys.append(code)
	return keys


func test_no_default_binding_uses_a_numpad_key() -> void:
	PureFightKeys.install(0)
	PureFightKeys.install(1)
	InputBindings.install_defaults()
	for code in _all_default_keys():
		assert_false(PureFightKeys.is_numpad_key(code), "default %s is a numpad key" % OS.get_keycode_string(code))
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue  # Godot's built-in menu actions, not fight keys.
		for event in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key != null:
				assert_false(PureFightKeys.is_numpad_key(key.physical_keycode), "%s uses a numpad key" % action)
				assert_false(PureFightKeys.is_numpad_key(key.keycode), "%s uses a numpad key" % action)


func test_the_numpad_check_knows_every_keypad_key() -> void:
	for code in [KEY_KP_0, KEY_KP_5, KEY_KP_9, KEY_KP_ENTER, KEY_KP_PERIOD, KEY_KP_ADD]:
		assert_true(PureFightKeys.is_numpad_key(code))
	for code in [KEY_0, KEY_COMMA, KEY_ENTER, KEY_PERIOD, KEY_SHIFT]:
		assert_false(PureFightKeys.is_numpad_key(code))


func test_defaults_avoid_mac_and_browser_trouble_keys() -> void:
	var banned: Array[Key] = [KEY_CTRL, KEY_META, KEY_ALT, KEY_TAB, KEY_BACKSPACE, KEY_INSERT, KEY_HOME,
		KEY_END, KEY_PAGEUP, KEY_PAGEDOWN, KEY_DELETE, KEY_ESCAPE, KEY_ENTER]
	for player in 2:
		for action in PureFightKeys.ACTIONS:
			for event in PureFightKeys.default_events(player, action):
				var code := event.physical_keycode
				assert_false(code in banned, "P%d %s on %s" % [player + 1, action, OS.get_keycode_string(code)])
				assert_false(code >= KEY_F1 and code <= KEY_F35, "P%d %s on an F-key" % [player + 1, action])


func test_no_key_drives_both_players() -> void:
	for player in 2:
		for action in PureFightKeys.ACTIONS:
			for event in PureFightKeys.default_events(player, action):
				event.pressed = true
				for other in PureFightKeys.ACTIONS:
					var name := PureFightKeys.action_name(1 - player, other)
					assert_false(InputMap.event_is_action(event, name),
						"P%d %s key also drives %s" % [player + 1, action, name])


func test_left_shift_dashes_p1_and_right_shift_dashes_p2() -> void:
	var p1 := PureFightKeys.new(0)
	var p2 := PureFightKeys.new(1)
	_hold([_key(KEY_SHIFT, KEY_LOCATION_LEFT)])
	assert_true(p1.read_tick().is_held(A.DASH))
	assert_false(p2.read_tick().is_held(A.DASH))
	_hold([_key(KEY_SHIFT, KEY_LOCATION_RIGHT)])
	assert_false(p1.read_tick().is_held(A.DASH))
	assert_true(p2.read_tick().is_held(A.DASH))


func test_p2_keys_drive_every_action_and_leave_p1_idle() -> void:
	var p1 := PureFightKeys.new(0)
	var p2 := PureFightKeys.new(1)
	for action: String in P2_KEYS:
		_hold([P2_KEYS[action]])
		var input := p2.read_tick()
		assert_true(input.is_held(PureFightKeys.BITS[action]), "%s on %s" % [action, OS.get_keycode_string(P2_KEYS[action])])
		assert_eq(p1.read_tick().held_actions, 0, "P1 ignores P2's %s key" % action)
	var arrows := {KEY_LEFT: Vector2(-1, 0), KEY_RIGHT: Vector2(1, 0), KEY_UP: Vector2(0, 1), KEY_DOWN: Vector2(0, -1)}
	for code: Key in arrows:
		_hold([code])
		assert_eq(p2.read_tick().move, arrows[code], OS.get_keycode_string(code))
		assert_eq(p1.read_tick().move, Vector2.ZERO)


func test_both_players_hold_a_diagonal_and_two_buttons_at_once() -> void:
	var p1 := PureFightKeys.new(0)
	var p2 := PureFightKeys.new(1)
	_hold([KEY_S, KEY_D, KEY_J, KEY_K, KEY_DOWN, KEY_LEFT, KEY_COMMA, KEY_PERIOD])
	var a := p1.read_tick()
	var b := p2.read_tick()
	assert_eq(a.move, Vector2(1, -1))
	assert_eq(b.move, Vector2(-1, -1))
	assert_true(a.is_held(A.LIGHT) and a.is_held(A.SPECIAL_1))
	assert_true(b.is_held(A.LIGHT) and b.is_held(A.SPECIAL_1))
	assert_false(a.is_held(A.HEAVY) or b.is_held(A.HEAVY))


## Steps a fight with P2 on the keyboard: each step is the keys P2 holds for that tick.
func _p2_plays(steps: Array, sim: PureFightSim = null) -> PureFightSim:
	if sim == null:
		sim = PureFightDriver.fighting([&"kael", &"kael"] as Array[StringName])
	var p2 := PureFightKeys.new(1)
	for keys: Array in steps:
		_hold(keys)
		var inputs: Array[FighterInput] = [FighterInput.new(), p2.read_tick()]
		sim.tick(inputs)
	return sim


func test_p2_does_motion_techniques_on_the_arrows() -> void:
	# P2 stands on the right facing left, so forward is the Left arrow.
	assert_eq(_p2_plays([[KEY_DOWN], [KEY_DOWN, KEY_LEFT], [KEY_LEFT, KEY_COMMA]]).pf[1].move, &"iron_lunge", "236")
	assert_eq(_p2_plays([[KEY_LEFT], [KEY_DOWN], [KEY_DOWN, KEY_LEFT, KEY_COMMA]]).pf[1].move, &"skyward_fist", "623")
	assert_eq(_p2_plays([[KEY_DOWN], [KEY_DOWN, KEY_RIGHT], [KEY_RIGHT, KEY_COMMA]]).pf[1].move, &"ridgeback_kick", "214")
	assert_eq(_p2_plays([[KEY_DOWN, KEY_APOSTROPHE]]).pf[1].move, &"skyward_fist", "technique key + down")


func test_p2_attacks_throws_and_finishes_from_the_right_hand_cluster() -> void:
	for code in [KEY_COMMA, KEY_PERIOD, KEY_SLASH]:
		var sim := _p2_plays([[code]])
		assert_eq(sim.pf[1].state, S.ATTACK, OS.get_keycode_string(code))
	var moves := [_p2_plays([[KEY_COMMA]]).pf[1].move, _p2_plays([[KEY_PERIOD]]).pf[1].move,
		_p2_plays([[KEY_SLASH]]).pf[1].move]
	assert_ne(moves[0], moves[1])
	assert_ne(moves[1], moves[2])
	assert_eq(_p2_plays([[KEY_SEMICOLON]]).pf[1].move, &"throw")
	var sim := PureFightDriver.fighting([&"kael", &"kael"] as Array[StringName])
	sim.pf[1].meter = PureMoves.METER_MAX
	assert_eq(_p2_plays([[KEY_BRACKETRIGHT]], sim).pf[1].move, &"thousand_petal", "finisher key")


func test_p2_dashes_with_right_shift_or_a_double_tap() -> void:
	var right_shift := _key(KEY_SHIFT, KEY_LOCATION_RIGHT)
	assert_eq(_p2_plays([[KEY_LEFT, right_shift]]).pf[1].state, S.DASH, "Right Shift + forward")
	assert_eq(_p2_plays([[KEY_RIGHT, right_shift]]).pf[1].state, S.BACKDASH, "Right Shift + back")
	assert_eq(_p2_plays([[KEY_LEFT], [], [KEY_LEFT]]).pf[1].state, S.DASH, "forward twice")
	var left_shift := _key(KEY_SHIFT, KEY_LOCATION_LEFT)
	assert_ne(_p2_plays([[KEY_LEFT, left_shift]]).pf[1].state, S.DASH, "P1's Left Shift is not P2's dash")


func test_p2_blocks_by_holding_back_or_the_block_key() -> void:
	var sim := _p2_plays([[KEY_RIGHT]])
	assert_true(sim.pf[1].guarding, "holding the back arrow guards")
	var p2 := PureFightKeys.new(1)
	_hold([KEY_BRACKETLEFT])
	assert_true(p2.read_tick().is_held(A.BLOCK))


func test_hints_name_no_numpad_keys() -> void:
	var text := PureFightKeys.controls_text(0) + PureFightKeys.controls_text(1) + PureFightKeys.button_text(1)
	for word in ["Num", "numpad", "Kp ", "keypad"]:
		assert_false(text.containsn(word), "hint mentions %s" % word)
	assert_string_contains(PureFightKeys.controls_text(1), "Right Shift")
