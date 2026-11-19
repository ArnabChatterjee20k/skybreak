extends GutTest

const LIGHT := FighterInput.Action.LIGHT

var _sim: CombatSim
var _lights: Array[MoveData] = []
var _previous: Array[FighterInput] = []


## Fighter 0 at the origin locked onto fighter 1 six metres ahead.
func _start(stats: FighterStats = null) -> void:
	_sim = CombatSim.new()
	_sim.add_fighter(Vector3.ZERO, stats)
	_sim.add_fighter(Vector3(0, 0, -6))
	_sim.lock_everyone_onto_nearest()
	_lights = _fighter().stats.move_set.light_string
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


## Neutral ticks, then a light press on the tick the current move reaches move_tick.
func _press_at(move_tick: int) -> void:
	_drive(move_tick - _fighter().move_tick - 1)
	_drive(1, LIGHT)


func test_a_press_at_the_window_opening_queues_the_next_hit_for_recovery_start() -> void:
	_start()
	_drive(1, LIGHT)
	var first := _lights[0]
	_press_at(first.string_window_start_tick)
	assert_eq(_fighter().move_id(), &"light_1", "queued, not yet out")
	assert_true(_fighter().string_queued)
	_drive(first.recovery_start_tick() - first.string_window_start_tick - 1)
	assert_eq(_fighter().move_id(), &"light_1")
	_drive(1)
	assert_eq(_fighter().move_id(), &"light_2", "out on the first recovery tick")
	assert_eq(_fighter().string_index, 2)
	assert_eq(_fighter().move_tick, 0)


func test_a_press_on_the_last_tick_of_the_window_chains_at_once() -> void:
	_start()
	_drive(1, LIGHT)
	var first := _lights[0]
	_press_at(first.string_window_start_tick + first.string_window_ticks - 1)
	assert_eq(_fighter().move_id(), &"light_2")
	assert_eq(_fighter().move_tick, 0)


func test_four_presses_in_rhythm_play_the_whole_string() -> void:
	_start()
	_drive(1, LIGHT)
	for number in range(2, _lights.size() + 1):
		_press_at(_fighter().move.string_window_start_tick)
		while _fighter().string_index < number and _fighter().state == FighterState.State.ATTACKING:
			_drive(1)
		assert_eq(_fighter().string_index, number)
		assert_eq(_fighter().move_id(), _lights[number - 1].id)


func test_an_early_press_drops_the_string() -> void:
	_start()
	_drive(1, LIGHT)
	_press_at(_lights[0].string_window_start_tick - 1)
	assert_true(_fighter().string_dropped)
	_press_at(_lights[0].string_window_start_tick + 2)
	assert_false(_fighter().string_queued, "a later press in the window is ignored")
	_drive(_lights[0].total_ticks() - _fighter().move_tick - 1)
	assert_eq(_fighter().move_id(), &"light_1", "recovers normally")
	_drive(1)
	assert_eq(_fighter().state, FighterState.State.IDLE, "no hit comes out after a dropped string")


func test_a_late_press_after_the_window_starts_a_new_string() -> void:
	_start()
	_drive(1, LIGHT)
	var first := _lights[0]
	var window_end := first.string_window_start_tick + first.string_window_ticks
	_drive(window_end)
	assert_eq(_fighter().state, FighterState.State.IDLE, "light 1 is over when its window closes")
	_drive(1, LIGHT)
	assert_eq(_fighter().move_id(), &"light_1")
	assert_eq(_fighter().string_index, 1)


func test_a_late_press_inside_a_long_recovery_is_ignored() -> void:
	var short_window := _lights_with_short_window()
	_start(short_window)
	_drive(1, LIGHT)
	var first := _fighter().move
	_press_at(first.string_window_start_tick + first.string_window_ticks)
	assert_true(_fighter().string_dropped)
	_drive(first.total_ticks() - _fighter().move_tick - 1)
	assert_eq(_fighter().move_id(), first.id)
	_drive(1)
	assert_eq(_fighter().state, FighterState.State.IDLE)


func test_mashing_light_never_gets_past_the_first_hit() -> void:
	_start()
	var highest := 0
	for tick in 120:
		_drive(1, LIGHT if tick % 4 == 0 else 0)
		highest = maxi(highest, _fighter().string_index)
	assert_eq(highest, 1)


func test_mashing_every_other_tick_never_gets_past_the_first_hit() -> void:
	_start()
	var highest := 0
	for tick in 120:
		_drive(1, LIGHT if tick % 2 == 0 else 0)
		highest = maxi(highest, _fighter().string_index)
	assert_eq(highest, 1)


func test_presses_during_the_ender_do_not_restart_the_string_mid_move() -> void:
	_start()
	_drive(1, LIGHT)
	while _fighter().string_index < _lights.size():
		if _fighter().move_tick + 1 == _fighter().move.string_window_start_tick:
			_drive(1, LIGHT)
		else:
			_drive(1)
	_press_at(5)
	assert_eq(_fighter().move_id(), _lights[-1].id)
	assert_eq(_fighter().string_index, _lights.size())


func test_the_string_chains_without_contact() -> void:
	_start()
	_drive(1, LIGHT)
	_press_at(_lights[0].string_window_start_tick)
	_drive(5)
	assert_eq(_fighter().string_index, 2)
	assert_false(_fighter().contact_hit)


## Stats whose first light's window closes well before its recovery ends.
func _lights_with_short_window() -> FighterStats:
	var stats: FighterStats = (CombatSim.DEFAULT_FIGHTER_STATS as FighterStats).duplicate()
	stats.move_set = stats.move_set.duplicate()
	var first: MoveData = stats.move_set.light_string[0].duplicate()
	first.recovery_ticks = 30
	first.string_window_start_tick = 6
	first.string_window_ticks = 6
	var lights: Array[MoveData] = stats.move_set.light_string.duplicate()
	lights[0] = first
	stats.move_set.light_string = lights
	return stats
