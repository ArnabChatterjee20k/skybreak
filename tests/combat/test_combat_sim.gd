extends GutTest


func _run_match(seed_value: int, ticks: int) -> int:
	var sim := CombatSim.new(seed_value)
	sim.add_fighter(Vector3(0, 1, 6)).velocity = Vector3(1.5, 0.25, -2)
	sim.add_fighter(Vector3(0, 1, -6)).velocity = Vector3(-0.5, 0, 3)
	var scripted := RandomNumberGenerator.new()
	scripted.seed = 1234
	var previous: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]
	for _tick in ticks:
		var inputs: Array[FighterInput] = []
		for i in 2:
			var input := FighterInput.from_held(scripted.randi() & 0x3FFF, previous[i])
			input.move = Vector2(scripted.randf_range(-1, 1), scripted.randf_range(-1, 1)).limit_length(1.0)
			input.vertical = scripted.randi_range(-1, 1)
			inputs.append(input)
		sim.tick(inputs)
		previous = inputs
	return sim.state_hash()


func test_same_seed_and_inputs_give_identical_state_after_10k_ticks() -> void:
	assert_eq(_run_match(42, 10_000), _run_match(42, 10_000))


func test_tick_advances_current_tick_by_one() -> void:
	var sim := CombatSim.new()
	sim.add_fighter(Vector3.ZERO)
	var inputs: Array[FighterInput] = [FighterInput.new()]
	sim.tick(inputs)
	sim.tick(inputs)
	assert_eq(sim.current_tick, 2)


func test_velocity_moves_fighter_by_one_tick_of_travel() -> void:
	var sim := CombatSim.new()
	var fighter := sim.add_fighter(Vector3.ZERO)
	fighter.velocity = Vector3(60, 0, 0)
	var inputs: Array[FighterInput] = [FighterInput.new()]
	sim.tick(inputs)
	assert_almost_eq(fighter.position.x, 1.0, 0.0001)


func test_state_hash_changes_when_a_fighter_moves() -> void:
	var sim := CombatSim.new()
	var fighter := sim.add_fighter(Vector3.ZERO)
	var before := sim.state_hash()
	fighter.position.x = 0.5
	assert_ne(sim.state_hash(), before)
