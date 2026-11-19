extends GutTest
## The test arena's optional AI hookup: an AIDriver makes P2 a computer opponent.


func test_an_ai_driver_makes_the_second_fighter_play() -> void:
	var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
	arena.match_flow.enabled = false
	add_child_autofree(arena)
	arena.set_physics_process(false)
	arena.ai_driver = AIDriver.for_sim(arena.sim, [
		{"character": &"kael", "team": 0, "is_ai": false},
		{"character": &"kael", "team": 1, "is_ai": true, "ai_level": 4},
	])
	var start: Vector3 = arena.sim.fighters[1].position
	var acted := false
	for _tick in 240:
		arena.step_tick()
		acted = acted or arena.sim.fighters[1].state == FighterState.State.ATTACKING
	assert_gt(arena.sim.fighters[1].position.distance_to(start), 1.0, "the AI moved")
	assert_true(acted, "the AI attacked")


func test_without_a_driver_the_second_fighter_stays_idle() -> void:
	var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
	arena.match_flow.enabled = false
	add_child_autofree(arena)
	arena.set_physics_process(false)
	var start: Vector3 = arena.sim.fighters[1].position
	for _tick in 60:
		arena.step_tick()
	assert_almost_eq(arena.sim.fighters[1].position.distance_to(start), 0.0, 0.001)
