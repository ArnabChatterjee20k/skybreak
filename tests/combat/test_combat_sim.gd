extends GutTest

## Held-action sets the scripted match picks from, so dashes can be held long
## enough to sustain and vanishes, lock-ons and other buttons all happen.
const SCRIPTED_HOLDS: Array[int] = [
	0,
	FighterInput.Action.DASH,
	FighterInput.Action.DASH,
	FighterInput.Action.DASH | FighterInput.Action.BLOCK,
	FighterInput.Action.BLOCK,
	FighterInput.Action.LOCK_TOGGLE,
	FighterInput.Action.LIGHT | FighterInput.Action.HEAVY,
]
const SCRIPTED_MOVES: Array[Vector2] = [
	Vector2.ZERO, Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-0.6, 0.8),
]


## Plays a scripted 2-fighter match: each fighter keeps a random intent for a
## random stretch of ticks. Records every state and dash kind seen in visited.
func _run_match(seed_value: int, ticks: int, visited: Dictionary) -> int:
	var sim := CombatSim.new(seed_value)
	sim.add_fighter(Vector3(0, 1, 6))
	sim.add_fighter(Vector3(0, 1, -6))
	var scripted := RandomNumberGenerator.new()
	scripted.seed = 1234
	var previous: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]
	var intents: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]
	var ticks_left: Array[int] = [0, 0]
	for _tick in ticks:
		var inputs: Array[FighterInput] = []
		for i in 2:
			if ticks_left[i] == 0:
				intents[i] = _random_intent(scripted)
				ticks_left[i] = scripted.randi_range(1, 40)
			ticks_left[i] -= 1
			var input := FighterInput.from_held(intents[i].held_actions, previous[i])
			input.move = intents[i].move
			input.vertical = intents[i].vertical
			input.view_yaw = intents[i].view_yaw
			input.target_switch = scripted.randi_range(-1, 1) if scripted.randf() < 0.01 else 0
			inputs.append(input)
		sim.tick(inputs)
		previous = inputs
		for fighter in sim.fighters:
			visited["state %d" % fighter.state] = true
			visited["dash %d" % fighter.dash_kind] = true
	return sim.state_hash()


func _random_intent(scripted: RandomNumberGenerator) -> FighterInput:
	var intent := FighterInput.new()
	intent.held_actions = SCRIPTED_HOLDS[scripted.randi_range(0, SCRIPTED_HOLDS.size() - 1)]
	intent.move = SCRIPTED_MOVES[scripted.randi_range(0, SCRIPTED_MOVES.size() - 1)]
	intent.vertical = scripted.randi_range(-1, 1)
	intent.view_yaw = scripted.randf_range(-PI, PI)
	return intent


func test_same_seed_and_inputs_give_identical_state_after_10k_ticks() -> void:
	var visited := {}
	assert_eq(_run_match(42, 10_000, visited), _run_match(42, 10_000, {}))


func test_the_scripted_10k_tick_match_covers_every_movement_mode() -> void:
	var visited := {}
	_run_match(42, 10_000, visited)
	for state in [
		FighterState.State.IDLE, FighterState.State.MOVING, FighterState.State.FLYING,
		FighterState.State.DASHING, FighterState.State.VANISHING,
	]:
		assert_true(visited.has("state %d" % state), "reached %s" % FighterState.State.keys()[state])
	for kind in [FighterState.DashKind.STEP, FighterState.DashKind.SUSTAINED, FighterState.DashKind.RUSH]:
		assert_true(visited.has("dash %d" % kind), "reached %s" % FighterState.DashKind.keys()[kind])


func test_tick_advances_current_tick_by_one() -> void:
	var sim := CombatSim.new()
	sim.add_fighter(Vector3.ZERO)
	var inputs: Array[FighterInput] = [FighterInput.new()]
	sim.tick(inputs)
	sim.tick(inputs)
	assert_eq(sim.current_tick, 2)


func test_state_hash_changes_when_a_fighter_moves() -> void:
	var sim := CombatSim.new()
	var fighter := sim.add_fighter(Vector3.ZERO)
	var before := sim.state_hash()
	fighter.position.x = 0.5
	assert_ne(sim.state_hash(), before)


func test_state_hash_changes_when_a_fighter_changes_state() -> void:
	var sim := CombatSim.new()
	var fighter := sim.add_fighter(Vector3.ZERO)
	var before := sim.state_hash()
	fighter.enter_state(FighterState.State.FLYING)
	assert_ne(sim.state_hash(), before)


func test_state_hash_covers_the_input_buffer() -> void:
	var sim := CombatSim.new()
	sim.add_fighter(Vector3.ZERO)
	var input := FighterInput.from_held(FighterInput.Action.LIGHT, FighterInput.new())
	var inputs: Array[FighterInput] = [input]
	sim.tick(inputs)
	var before := sim.state_hash()
	sim.consume_buffered(0, FighterInput.Action.LIGHT)
	assert_ne(sim.state_hash(), before)
