extends GutTest
## T-UX1: in-match control hints and their saved setting.

var _path := "user://test_control_hints.cfg"


func before_each() -> void:
	InputBindings.install_defaults()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))


func test_hints_show_for_the_first_matches_then_hide() -> void:
	var settings := HintSettings.new()
	assert_true(settings.shows_by_default())
	settings.matches_played = HintSettings.FIRST_MATCHES
	assert_false(settings.shows_by_default())


func test_a_toggle_is_remembered_over_the_match_count() -> void:
	var settings := HintSettings.new()
	settings.choose(false)
	assert_false(settings.shows_by_default(), "hidden on purpose stays hidden")
	settings.matches_played = 99
	settings.choose(true)
	assert_true(settings.shows_by_default(), "shown on purpose stays shown")
	settings.save(_path)
	var loaded := HintSettings.load_saved(_path)
	assert_true(loaded.chosen and loaded.shown)
	assert_eq(loaded.matches_played, 99)


func test_keyboard_strip_names_the_descend_key_and_the_dive() -> void:
	var entries := ControlHints.entries_for(false)
	var keys := entries.map(func(e: Array) -> String: return e[0])
	assert_has(keys, "SPACE / C")
	assert_has(keys, "C C")
	assert_has(keys, "H")
	assert_lte(entries.size(), 10, "compact")


func test_gamepad_strip_says_so_while_no_pad_is_bound() -> void:
	var entries := ControlHints.entries_for(true)
	assert_eq(entries.size(), 1)
	assert_eq(entries[0][1], ControlHints.GAMEPAD_UNBOUND)


func test_fly_down_prompt_uses_the_current_key() -> void:
	assert_eq(ControlHints.fly_down_prompt(), "Hold C to fly down  ·  double-tap C to land")


func test_air_idle_counts_only_airborne_without_vertical_input() -> void:
	var idle := 0.0
	for i in 200:
		idle = ControlHints.air_idle_step(idle, true, false, 1.0 / 60.0)
	assert_gt(idle, ControlHints.AIR_IDLE_SECONDS)
	assert_eq(ControlHints.air_idle_step(idle, true, true, 0.016), 0.0, "descend resets")
	assert_eq(ControlHints.air_idle_step(idle, false, false, 0.016), 0.0, "landing resets")


func test_hints_count_the_match_toggle_with_h_and_prompt_in_the_air() -> void:
	var sim := CombatSim.new()
	sim.add_fighter(Vector3(0, 1, 0))
	var hints := ControlHints.new()
	hints.settings_path = _path
	hints.sim = sim
	add_child_autofree(hints)
	assert_true(hints.strip_visible, "first match shows the strip")
	await get_tree().process_frame
	assert_eq(HintSettings.load_saved(_path).matches_played, 1)
	var press := InputEventAction.new()
	press.action = InputBindings.TOGGLE_HINTS
	press.pressed = true
	hints._unhandled_input(press)
	assert_false(hints.strip_visible)
	var saved := HintSettings.load_saved(_path)
	assert_true(saved.chosen and not saved.shown)
	sim.fighters[0].position.y = 30.0
	hints._air_idle = ControlHints.AIR_IDLE_SECONDS
	await get_tree().process_frame
	assert_true(hints.prompt_visible, "fly-down prompt after hovering")


func test_inactive_hints_draw_nothing_and_count_nothing() -> void:
	var hints := ControlHints.new()
	hints.settings_path = _path
	hints.sim = CombatSim.new()
	hints.sim.add_fighter(Vector3(0, 1, 0))
	hints.active = false
	add_child_autofree(hints)
	await get_tree().process_frame
	assert_false(hints.visible)
	assert_eq(HintSettings.load_saved(_path).matches_played, 0)
