extends GutTest

## Held-action sets the scripted match picks from, so dashes can be held long
## enough to sustain and vanishes, lock-ons, charging and other buttons all happen.
const SCRIPTED_HOLDS: Array[int] = [
	0,
	FighterInput.Action.DASH,
	FighterInput.Action.DASH,
	FighterInput.Action.DASH | FighterInput.Action.BLOCK,
	FighterInput.Action.BLOCK,
	FighterInput.Action.LOCK_TOGGLE,
	FighterInput.Action.LIGHT | FighterInput.Action.HEAVY,
	FighterInput.Action.CHARGE,
	FighterInput.Action.CHARGE,
]
const SCRIPTED_MOVES: Array[Vector2] = [
	Vector2.ZERO, Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-0.6, 0.8),
]


## Plays a scripted 2-fighter match: each fighter keeps a random intent for a
## random stretch of ticks and now and then takes damage, guard damage or
## blocks. A KO starts the next round. Records states, dash kinds and KOs seen.
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
		_script_meter_events(sim, scripted)
		sim.tick(inputs)
		previous = inputs
		if sim.round_over:
			visited["ko"] = true
			sim.start_round()
		for fighter in sim.fighters:
			visited["state %d" % fighter.state] = true
			visited["dash %d" % fighter.dash_kind] = true
	return sim.state_hash()


## Stand-ins for the hits and blocks T-D04/T-D05 will produce.
func _script_meter_events(sim: CombatSim, scripted: RandomNumberGenerator) -> void:
	for i in 2:
		var roll := scripted.randf()
		if roll < 0.02:
			sim.apply_damage(i, 1 - i, scripted.randi_range(100, 900))
			sim.add_landed_hit_ki(1 - i)
		elif roll < 0.03:
			sim.apply_guard_damage(i, scripted.randi_range(4, 18))
			sim.add_blocked_hit_ki(1 - i)
		elif roll < 0.035:
			sim.fighters[i].blocking = not sim.fighters[i].blocking
		elif roll < 0.036:
			sim.add_perfect_block_burst(i)
			sim.try_spend_burst(i, 1)


func _random_intent(scripted: RandomNumberGenerator) -> FighterInput:
	var intent := FighterInput.new()
	intent.held_actions = SCRIPTED_HOLDS[scripted.randi_range(0, SCRIPTED_HOLDS.size() - 1)]
	intent.move = SCRIPTED_MOVES[scripted.randi_range(0, SCRIPTED_MOVES.size() - 1)]
	intent.vertical = scripted.randi_range(-1, 1)
	intent.view_yaw = scripted.randf_range(-PI, PI)
	return intent


func test_same_seed_and_inputs_give_identical_state_after_10k_ticks() -> void:
	assert_eq(_run_match(42, 10_000, {}), _run_match(42, 10_000, {}))


func test_the_scripted_10k_tick_match_covers_every_movement_mode_and_a_knockout() -> void:
	var visited := {}
	_run_match(42, 10_000, visited)
	assert_true(visited.has("ko"), "a round ended by KO")
	for state in [
		FighterState.State.IDLE, FighterState.State.MOVING, FighterState.State.FLYING,
		FighterState.State.DASHING, FighterState.State.VANISHING,
		FighterState.State.CHARGING, FighterState.State.GUARD_BROKEN,
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
