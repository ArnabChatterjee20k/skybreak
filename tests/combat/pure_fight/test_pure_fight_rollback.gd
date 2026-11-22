extends GutTest
## Pure Fight is deterministic and rollback-safe: snapshot/restore covers all of its state,
## and the same seed and inputs replay the same match.


func _ais(seed_value: int) -> Array[PureFightAI]:
	var ais: Array[PureFightAI] = []
	for i in 2:
		var ai := PureFightAI.new()
		ai.setup(i, 4, seed_value)
		ai.explore = 0.3
		ais.append(ai)
	return ais


func _run(seed_value: int, ticks: int) -> Array[int]:
	var sim := PureFightSim.new(seed_value, [&"lyra", &"brann"] as Array[StringName])
	var ais := _ais(seed_value)
	var hashes: Array[int] = []
	for t in ticks:
		sim.tick([ais[0].next_input(sim), ais[1].next_input(sim)] as Array[FighterInput])
		hashes.append(sim.state_hash())
	return hashes


func test_the_same_seed_and_inputs_replay_the_same_match() -> void:
	assert_eq(_run(21, 4000), _run(21, 4000))


func test_restoring_a_snapshot_replays_exactly() -> void:
	var sim := PureFightSim.new(5, [&"kael", &"vexa"] as Array[StringName])
	var ais := _ais(5)
	var recorded: Array = []
	for t in 900:
		var inputs: Array[FighterInput] = [ais[0].next_input(sim), ais[1].next_input(sim)]
		recorded.append(inputs)
		sim.tick(inputs)
	var saved := sim.snapshot()
	var first: Array[int] = []
	var more: Array = []
	for t in 1200:
		var inputs: Array[FighterInput] = [ais[0].next_input(sim), ais[1].next_input(sim)]
		more.append(inputs)
		sim.tick(inputs)
		first.append(sim.state_hash())
	sim.restore(saved)
	var second: Array[int] = []
	for inputs in more:
		sim.tick(inputs)
		second.append(sim.state_hash())
	assert_eq(second, first)


func test_every_fighter_field_is_in_the_hash() -> void:
	var fighter := PureFighter.new()
	var names: Array[String] = []
	for property in fighter.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(property.name)
	assert_eq(fighter.state_values().size(), names.size(), "state_values covers every field")
