extends GutTest
## WASD + mouse is the default single-player scheme in every mode: left click light, right
## click heavy, the rest under the left hand, with the keyboard-only keys still working.

const A := FighterInput.Action
const S := PureFighter.State
const PATH := "user://test_mouse_controls.cfg"

var _held: Array[InputEvent] = []


func before_each() -> void:
	InputBindings.install_defaults()
	PureFightKeys.install(0)
	PureFightKeys.install(1)


func after_each() -> void:
	_release_all()
	var controls := ControlSettings.new()
	controls.reset_bindings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _key(code: Key, location := KEY_LOCATION_UNSPECIFIED) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.location = location
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event


func _send(source: InputEvent, pressed: bool) -> void:
	var event := source.duplicate() as InputEvent
	event.set(&"pressed", pressed)
	if event is InputEventMouseButton and pressed:
		(event as InputEventMouseButton).button_mask = 1 << ((event as InputEventMouseButton).button_index - 1)
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _press(source: InputEvent) -> void:
	_send(source, true)
	_held.append(source)


func _release(source: InputEvent) -> void:
	_send(source, false)
	_held.erase(source)


func _release_all() -> void:
	for event in _held.duplicate():
		_send(event, false)
	_held.clear()


## Holds exactly these keys / buttons (Key codes or events).
func _hold(sources: Array) -> void:
	_release_all()
	for source: Variant in sources:
		_press(source if source is InputEvent else _key(source))


# --- 3D modes (Versus AI, FFA, training room, Duo): KeyboardMouseInput ---

func _flight_reader() -> KeyboardMouseInput:
	return add_child_autofree(KeyboardMouseInput.new())


func test_left_click_is_light_and_right_click_heavy_in_the_3d_modes() -> void:
	var reader := _flight_reader()
	_hold([_mouse(MOUSE_BUTTON_LEFT)])
	var input := reader.read_tick(0.0, Vector2.ZERO)
	assert_true(input.is_pressed(A.LIGHT), "LMB presses light")
	assert_false(input.is_held(A.HEAVY))
	_hold([_mouse(MOUSE_BUTTON_RIGHT)])
	input = reader.read_tick(0.0, Vector2.ZERO)
	assert_true(input.is_pressed(A.HEAVY), "RMB presses heavy")
	assert_false(input.is_held(A.LIGHT))
	assert_true(input.is_released(A.LIGHT))
	_hold([_mouse(MOUSE_BUTTON_MIDDLE)])
	assert_true(reader.read_tick(0.0, Vector2.ZERO).is_pressed(A.LOCK_TOGGLE), "MMB toggles lock-on")


func test_every_3d_action_has_a_mouse_or_left_hand_default_and_keyboard_only_still_works() -> void:
	var reader := _flight_reader()
	for action: int in InputBindings.FIGHTER_ACTIONS:
		var name: StringName = InputBindings.FIGHTER_ACTIONS[action]
		var events := InputMap.action_get_events(name)
		assert_false(events.is_empty(), "%s bound" % name)
		for event in events:
			_release_all()
			reader.read_tick(0.0, Vector2.ZERO)
			_hold([event])
			assert_true(reader.read_tick(0.0, Vector2.ZERO).is_pressed(action), "%s from %s" % [name, event.as_text()])
	var keyboard_only := {KEY_J: A.LIGHT, KEY_L: A.HEAVY, KEY_U: A.GRAB, KEY_I: A.SPECIAL_1, KEY_O: A.ULTIMATE,
		KEY_TAB: A.LOCK_TOGGLE}
	for code: Key in keyboard_only:
		_release_all()
		reader.read_tick(0.0, Vector2.ZERO)
		_hold([code])
		assert_true(reader.read_tick(0.0, Vector2.ZERO).is_pressed(keyboard_only[code]), OS.get_keycode_string(code))


func test_the_wheel_switches_target_and_nothing_critical() -> void:
	var reader := _flight_reader()
	var notch := _mouse(MOUSE_BUTTON_WHEEL_DOWN)
	notch.pressed = true
	reader._unhandled_input(notch)
	var input := reader.read_tick(0.0, Vector2.ZERO)
	assert_eq(input.target_switch, 1)
	assert_eq(input.held_actions, 0, "a wheel notch is no fighter action")
	for action_name: StringName in InputBindings.FIGHTER_ACTIONS.values():
		for event in InputMap.action_get_events(action_name):
			if event is InputEventMouseButton:
				assert_false((event as InputEventMouseButton).button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN],
					"%s is on the wheel" % action_name)


func test_a_held_click_stays_one_press_while_keys_change() -> void:
	var reader := _flight_reader()
	var lmb := _mouse(MOUSE_BUTTON_LEFT)
	_press(lmb)
	assert_true(reader.read_tick(0.0, Vector2.ZERO).is_pressed(A.LIGHT))
	for code in [KEY_W, KEY_E, KEY_SHIFT]:
		_press(_key(code))
		var input := reader.read_tick(0.0, Vector2.ZERO)
		assert_true(input.is_held(A.LIGHT), "still held with %s" % OS.get_keycode_string(code))
		assert_false(input.is_pressed(A.LIGHT), "no second press from %s" % OS.get_keycode_string(code))
		_release(_key(code))
		assert_false(reader.read_tick(0.0, Vector2.ZERO).is_pressed(A.LIGHT))
	_release(lmb)
	assert_true(reader.read_tick(0.0, Vector2.ZERO).is_released(A.LIGHT))


func test_a_trackpad_tap_shorter_than_a_tick_still_attacks() -> void:
	var reader := _flight_reader()
	var lmb := _mouse(MOUSE_BUTTON_LEFT)
	lmb.pressed = true
	reader.note_event(lmb)
	_send(_mouse(MOUSE_BUTTON_LEFT), false)
	var tap := reader.read_tick(0.0, Vector2.ZERO)
	assert_true(tap.is_pressed(A.LIGHT), "a press and release between two ticks is one light press")
	assert_true(reader.read_tick(0.0, Vector2.ZERO).is_released(A.LIGHT), "and lets go the next tick")
	var p1 := PureFightKeys.new(0)
	var rmb := _mouse(MOUSE_BUTTON_RIGHT)
	rmb.pressed = true
	p1.note_event(rmb)
	assert_true(p1.read_tick().is_pressed(A.HEAVY), "Pure Fight: a tapped right click is a heavy")
	assert_eq(p1.read_tick().held_actions, 0)
	p1.note_event(rmb)
	p1._tapped_frame -= PureFightKeys.TAP_FRAMES + 1
	assert_eq(p1.read_tick().held_actions, 0, "a click from before a menu or round intro never fires later")


func test_mouse_and_keyboard_bindings_never_overlap_in_the_3d_defaults() -> void:
	var owner_of := {}
	for action: StringName in InputBindings.DEFAULT_MOUSE_BUTTONS:
		for button: MouseButton in InputBindings.DEFAULT_MOUSE_BUTTONS[action]:
			assert_false(owner_of.has(button), "mouse %d used twice" % button)
			owner_of[button] = action


func test_a_left_click_starts_a_light_attack_in_the_3d_sim() -> void:
	var sim := CombatSim.new()
	sim.add_fighter(Vector3.ZERO, EngagementBand.stats_for(&"kael"))
	sim.add_fighter(Vector3(0, 0, -3), EngagementBand.stats_for(&"vexa"))
	var reader := _flight_reader()
	_hold([_mouse(MOUSE_BUTTON_LEFT)])
	var started := false
	for i in 6:
		var inputs: Array[FighterInput] = [reader.read_tick(0.0, Vector2.ZERO, true), FighterInput.new()]
		sim.tick(inputs)
		started = started or sim.fighters[0].move != null
	assert_true(started, "LMB starts a move")


# --- Pure Fight (vs AI, training, Duo online): PureFightKeys P1 ---

const PF_MOUSE_SCHEME := {
	"light": MOUSE_BUTTON_LEFT, "medium": MOUSE_BUTTON_MIDDLE, "heavy": MOUSE_BUTTON_RIGHT,
	"throw": KEY_F, "technique": KEY_R, "finisher": KEY_C, "block": KEY_E,
}
const PF_LEFT_HAND_MEDIUM := KEY_Q
const PF_KEYBOARD_ONLY := {
	"light": KEY_J, "medium": KEY_K, "heavy": KEY_L, "throw": KEY_U, "technique": KEY_I, "finisher": KEY_O,
	"block": KEY_E,
}


func _pf_source(value: Variant) -> InputEvent:
	return _mouse(value) if value is int and int(value) <= MOUSE_BUTTON_XBUTTON2 else _key(value)


func test_pure_fight_p1_mouse_scheme_drives_every_button_and_leaves_p2_idle() -> void:
	var p1 := PureFightKeys.new(0)
	var p2 := PureFightKeys.new(1)
	for action: String in PF_MOUSE_SCHEME:
		_hold([_pf_source(PF_MOUSE_SCHEME[action])])
		var input := p1.read_tick()
		assert_eq(input.held_actions, int(PureFightKeys.BITS[action]), "%s alone" % action)
		assert_eq(p2.read_tick().held_actions, 0, "P2 ignores P1's %s" % action)
	_hold([PF_LEFT_HAND_MEDIUM])
	assert_true(p1.read_tick().is_held(A.SPECIAL_1), "Q is medium")
	_hold([_key(KEY_SHIFT, KEY_LOCATION_LEFT)])
	assert_true(p1.read_tick().is_held(A.DASH), "Left Shift dashes")


func test_pure_fight_p1_keyboard_only_keys_still_work() -> void:
	var p1 := PureFightKeys.new(0)
	for action: String in PF_KEYBOARD_ONLY:
		_hold([PF_KEYBOARD_ONLY[action]])
		assert_eq(p1.read_tick().held_actions, int(PureFightKeys.BITS[action]),
			"%s on %s" % [action, OS.get_keycode_string(PF_KEYBOARD_ONLY[action])])
	var moves := {KEY_A: Vector2(-1, 0), KEY_D: Vector2(1, 0), KEY_W: Vector2(0, 1), KEY_SPACE: Vector2(0, 1),
		KEY_S: Vector2(0, -1)}
	for code: Key in moves:
		_hold([code])
		assert_eq(p1.read_tick().move, moves[code], OS.get_keycode_string(code))


func test_pure_fight_mouse_buttons_reach_only_p1() -> void:
	for button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
		var event := _mouse(button)
		event.pressed = true
		for action in PureFightKeys.ACTIONS:
			assert_false(InputMap.event_is_action(event, PureFightKeys.action_name(1, action)),
				"mouse %d drives P2 %s" % [button, action])


func test_pure_fight_left_hand_keys_clash_with_nothing() -> void:
	var owner_of := {}
	for player in 2:
		for action in PureFightKeys.ACTIONS:
			for event in PureFightKeys.default_events(player, action):
				var id := "%d:%d" % [event.physical_keycode, event.location]
				assert_false(owner_of.has(id), "%s used by %s and P%d %s" % [event.as_text(), owner_of.get(id), player + 1, action])
				owner_of[id] = "P%d %s" % [player + 1, action]
	for code in [KEY_Q, KEY_F, KEY_R, KEY_C]:
		assert_false(code in PureFightMatch.DUMMY_KEYS, "%s cycles the training dummy" % OS.get_keycode_string(code))


## Steps a Pure Fight with P1 holding the given keys / buttons each tick.
func _p1_plays(steps: Array, sim: PureFightSim = null) -> PureFightSim:
	if sim == null:
		sim = PureFightDriver.fighting([&"kael", &"kael"] as Array[StringName])
	var p1 := PureFightKeys.new(0)
	for sources: Array in steps:
		_hold(sources)
		var inputs: Array[FighterInput] = [p1.read_tick(), FighterInput.new()]
		sim.tick(inputs)
	return sim


func test_pure_fight_clicks_and_left_hand_keys_start_the_right_moves() -> void:
	var light := _p1_plays([[_mouse(MOUSE_BUTTON_LEFT)]]).pf[0]
	var medium := _p1_plays([[_mouse(MOUSE_BUTTON_MIDDLE)]]).pf[0]
	var heavy := _p1_plays([[_mouse(MOUSE_BUTTON_RIGHT)]]).pf[0]
	for f: PureFighter in [light, medium, heavy]:
		assert_eq(f.state, S.ATTACK)
	assert_eq(light.move, _p1_plays([[KEY_J]]).pf[0].move, "LMB = J")
	assert_eq(medium.move, _p1_plays([[KEY_K]]).pf[0].move, "MMB = K")
	assert_eq(medium.move, _p1_plays([[KEY_Q]]).pf[0].move, "Q = K")
	assert_eq(heavy.move, _p1_plays([[KEY_L]]).pf[0].move, "RMB = L")
	assert_ne(light.move, heavy.move)
	assert_eq(_p1_plays([[KEY_F]]).pf[0].move, &"throw", "F throws")
	assert_eq(_p1_plays([[KEY_S, KEY_R]]).pf[0].move, &"skyward_fist", "R + down = technique 623")
	assert_eq(_p1_plays([[KEY_S, KEY_I]]).pf[0].move, &"skyward_fist", "I + down still works")
	var sim := PureFightDriver.fighting([&"kael", &"kael"] as Array[StringName])
	sim.pf[0].meter = PureMoves.METER_MAX
	assert_eq(_p1_plays([[KEY_C]], sim).pf[0].move, &"thousand_petal", "C is the finisher")


func test_pure_fight_motion_plus_click_does_a_technique() -> void:
	# P1 stands on the left facing right: 236 = S, S+D, D + click.
	var lmb := _mouse(MOUSE_BUTTON_LEFT)
	assert_eq(_p1_plays([[KEY_S], [KEY_S, KEY_D], [KEY_D, lmb]]).pf[0].move, &"iron_lunge", "236 + LMB")


# --- Duo: mouse presses ride the same rollback input stream ---

func test_a_clicked_input_survives_the_wire_unchanged() -> void:
	var p1 := PureFightKeys.new(0)
	_hold([_mouse(MOUSE_BUTTON_RIGHT), KEY_D])
	var clicked := p1.read_tick()
	var decoded := InputCodec.decode(InputCodec.encode(clicked))
	assert_eq(decoded.held_actions, clicked.held_actions)
	assert_eq(decoded.pressed_actions, clicked.pressed_actions)
	assert_eq(decoded.move, clicked.move)
	var by_key := PureFightKeys.new(0)
	_hold([KEY_L, KEY_D])
	assert_eq(InputCodec.encode(by_key.read_tick()), InputCodec.encode(clicked), "RMB and L send the same bytes")
	var reader := _flight_reader()
	_hold([_mouse(MOUSE_BUTTON_LEFT)])
	var flight := reader.read_tick(0.5, Vector2.ZERO)
	assert_eq(InputCodec.decode(InputCodec.encode(flight)).pressed_actions, flight.pressed_actions)


# --- Pointer: Pure Fight has no free camera, so it never asks for pointer lock ---

func test_pure_fight_never_captures_the_pointer_and_the_3d_match_does() -> void:
	var pf := PureFightMatch.new()
	var session := MatchSession.new()
	pf.add_child(session)
	assert_false(session.uses_mouse_look(), "Pure Fight keeps the pointer free")
	var level := Node.new()
	var other := MatchSession.new()
	level.add_child(other)
	assert_true(other.uses_mouse_look(), "a 3D level keeps its mouse look")
	pf.free()
	level.free()


# --- Rebinding: mouse buttons are bindable ---

func test_mouse_buttons_are_bindable_and_move_off_other_actions() -> void:
	var controls := ControlSettings.new()
	assert_eq(ControlSettings.binding_label(&"fighter_light"), "LMB / J")
	assert_eq(ControlSettings.binding_label(&"fighter_heavy"), "RMB / L")
	assert_true(controls.rebind_mouse(&"fighter_heavy", MOUSE_BUTTON_MIDDLE))
	assert_eq(ControlSettings.mouse_buttons(&"fighter_heavy"), [MOUSE_BUTTON_MIDDLE] as Array[MouseButton])
	assert_eq(ControlSettings.mouse_buttons(&"fighter_lock_toggle"), [] as Array[MouseButton], "MMB left lock-on")
	assert_eq(ControlSettings.key_label(&"fighter_heavy"), "L", "keys stay")
	assert_false(controls.rebind_mouse(&"fighter_block", MOUSE_BUTTON_WHEEL_UP), "no wheel holds")
	assert_true(controls.rebind_mouse(&"fighter_block", MOUSE_BUTTON_XBUTTON1))
	controls.save(PATH)
	controls.reset_bindings()
	assert_eq(ControlSettings.mouse_buttons(&"fighter_lock_toggle"), [MOUSE_BUTTON_MIDDLE] as Array[MouseButton])
	var loaded := ControlSettings.load_saved(PATH)
	loaded.apply_bindings()
	assert_eq(ControlSettings.mouse_buttons(&"fighter_heavy"), [MOUSE_BUTTON_MIDDLE] as Array[MouseButton])
	assert_eq(ControlSettings.mouse_buttons(&"fighter_block"), [MOUSE_BUTTON_XBUTTON1] as Array[MouseButton])
	assert_eq(ControlSettings.binding_label(&"fighter_lock_toggle"), "Tab")


func test_the_controls_screen_binds_a_click() -> void:
	var screen := SettingsScreen.new()
	screen.save_path = PATH
	add_child_autofree(screen)
	screen.start_rebind(&"fighter_block")
	var click := _mouse(MOUSE_BUTTON_RIGHT)
	click.pressed = true
	screen._input(click)
	assert_eq(screen.rebinding, &"")
	assert_eq(ControlSettings.binding_label(&"fighter_block"), "RMB / E")
	assert_eq(ControlSettings.mouse_buttons(&"fighter_heavy"), [] as Array[MouseButton], "RMB moved off heavy")
	assert_eq(ControlSettings.load_saved(PATH).mouse_overrides.get(&"fighter_block"), MOUSE_BUTTON_RIGHT)
	for action in [&"fighter_light", &"fighter_heavy", &"fighter_lock_toggle"]:
		assert_true(ControlSettings.REBINDABLE.has(action), "%s on the controls screen" % action)
	screen.reset_keys()
	assert_eq(ControlSettings.binding_label(&"fighter_heavy"), "RMB / L")


# --- Hints and text: mouse first, no numpad ---

func test_hints_show_the_mouse_scheme_first() -> void:
	var entries := ControlHints.entries_for(false)
	var caps: Array = entries.map(func(e: Array) -> String: return e[0])
	assert_has(caps, "LMB")
	assert_has(caps, "RMB")
	assert_true(PureFightKeys.hint_text().begins_with("LEFT CLICK light"), "Pure Fight's in-match hint leads with the mouse")
	assert_string_contains(PureFightKeys.hint_text(), "RIGHT CLICK heavy")
	var p1 := PureFightKeys.controls_text(0)
	assert_lt(p1.find("Left click"), p1.find("J/K/L"), "mouse before the keyboard-only keys")
	assert_string_contains(p1, "Right click")
	for word in ["Num", "numpad", "keypad"]:
		assert_false(p1.containsn(word))


func test_no_default_binding_anywhere_is_a_numpad_key() -> void:
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				assert_false(PureFightKeys.is_numpad_key((event as InputEventKey).physical_keycode), "%s" % action)


func test_pure_fight_shows_the_mouse_hint_then_fades_it() -> void:
	var hud := PureFightHud.new()
	hud.sim = PureFightDriver.fighting([&"kael", &"kael"] as Array[StringName])
	hud.hint = PureFightKeys.hint_text()
	add_child_autofree(hud)
	assert_true(hud._hint.visible)
	assert_eq(hud._hint.text, PureFightKeys.hint_text())
	hud._process(1.0)
	assert_gt(hud._hint.modulate.a, 0.0, "still showing after a second")
	hud._process(PureFightHud.HINT_SECONDS)
	assert_eq(hud._hint.modulate.a, 0.0, "gone after the first seconds")
	var quiet := PureFightHud.new()
	quiet.sim = hud.sim
	add_child_autofree(quiet)
	assert_false(quiet._hint.visible, "no hint without a human on P1's keys")
