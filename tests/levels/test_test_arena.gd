extends GutTest

var _previous: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]


func _climb_for_fighter_one(index: int, _tick: int) -> FighterInput:
	var input := FighterInput.from_held(0, _previous[index])
	input.vertical = 1 if index == 1 else 0
	_previous[index] = input
	return input


func test_input_override_drives_every_fighter() -> void:
	var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
	arena.input_override = _climb_for_fighter_one
	arena.match_flow.enabled = false
	add_child_autofree(arena)
	await wait_physics_frames(30)
	assert_eq(arena.sim.fighters[1].state, FighterState.State.FLYING, "the opponent took off")
	assert_gt(arena.sim.fighters[1].position.y, 3.0)
	assert_almost_eq(arena.sim.fighters[0].position.y, arena.sim.tuning.ground_height, 0.001, "the player stayed down")


func test_both_fighters_start_locked_onto_each_other() -> void:
	var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
	add_child_autofree(arena)
	await wait_physics_frames(1)
	assert_eq(arena.sim.fighters[0].lock_on_target, 1)
	assert_eq(arena.sim.fighters[1].lock_on_target, 0)


func test_the_round_intro_holds_input_until_fight() -> void:
	var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
	arena.input_override = _climb_for_fighter_one
	add_child_autofree(arena)
	arena.set_physics_process(false)
	for i in MatchFlow.INTRO_TICKS - 1:
		arena.step_tick()
	assert_almost_eq(arena.sim.fighters[1].position.y, arena.sim.tuning.ground_height, 0.001, "held during the intro")
	for i in 30:
		arena.step_tick()
	assert_gt(arena.sim.fighters[1].position.y, 2.0, "moves once FIGHT! shows")


func test_the_arena_shows_a_hud_plate_per_fighter_with_names() -> void:
	var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
	add_child_autofree(arena)
	assert_eq(arena.match_hud.names.size(), arena.sim.fighters.size())
	assert_eq(arena.match_hud.names[0], "KAEL")
	assert_true(arena.match_hud.is_inside_tree())


func test_the_hud_fills_the_window() -> void:
	var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
	add_child_autofree(arena)
	await wait_process_frames(1)
	assert_eq(arena.match_hud.size, Vector2(arena.get_viewport().get_visible_rect().size))
