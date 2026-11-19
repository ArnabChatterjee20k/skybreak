extends GutTest

## Held-action sets the scripted match picks from, so dashes can be held long
## enough to sustain and vanishes, lock-ons, charging, attacks and charged smashes all happen.
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
	FighterInput.Action.HEAVY,
	FighterInput.Action.HEAVY,
	FighterInput.Action.LIGHT,
]
## Chance per tick that light is tapped on top of the intent, so strings chain and drop.
const LIGHT_TAP_CHANCE := 0.15
## Heavy hold lengths (min, max ticks): a tap, then releases at charge levels 1, 2 and 3
## with the scripted fighter's thresholds (12, 20, 28).
const CHARGE_HOLDS: Array[Vector2i] = [Vector2i(1, 11), Vector2i(13, 19), Vector2i(21, 27), Vector2i(29, 80)]
## Chance that a new intent also steers toward the opponent, so fighters meet and hits land.
const APPROACH_CHANCE := 0.9
## An approaching fighter stops pushing in once this close, in metres.
const APPROACH_REACH := 1.8
const SCRIPTED_MOVES: Array[Vector2] = [
	Vector2.ZERO, Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-0.6, 0.8),
]


## Plays a scripted 2-fighter match: each fighter keeps a random intent for a
## random stretch of ticks, often steering toward the other, taps light now and
## then and now and then toggles blocking, so hits, combos, blocks and
## knockbacks happen. A KO starts the next round. Records states, dash kinds,
## moves, cancels, KOs and hit events seen.
func _run_match(seed_value: int, ticks: int, visited: Dictionary) -> int:
	var sim := CombatSim.new(seed_value)
	# A Kael variant with less health and guard, a faster charge and a Breaker
	# that is armored through startup and wall-splats, so KOs, guard breaks,
	# every charge level, armored hits and splats come often in random play.
	var stats := (CombatSim.DEFAULT_FIGHTER_STATS as FighterStats).duplicate() as FighterStats
	stats.max_health = 3_000
	stats.guard_max = 20
	stats.move_set = stats.move_set.duplicate() as MoveSet
	stats.move_set.smash = stats.move_set.smash.duplicate() as MoveData
	stats.move_set.smash.charge_level_ticks = PackedInt32Array([12, 20, 28])
	var breaker := stats.move_set.breaker.duplicate() as MoveData
	breaker.armor_end_tick = breaker.startup_ticks
	breaker.knockback_type = MoveData.KnockbackType.WALL_SPLAT
	stats.move_set.breaker = breaker
	sim.add_fighter(Vector3(0, 1, 6), stats)
	sim.add_fighter(Vector3(0, 1, -6), stats)
	sim.lock_everyone_onto_nearest()
	var scripted := RandomNumberGenerator.new()
	scripted.seed = 1234
	var previous: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]
	var intents: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]
	var approaching: Array[bool] = [false, false]
	var ticks_left: Array[int] = [0, 0]
	for _tick in ticks:
		var inputs: Array[FighterInput] = []
		for i in 2:
			if ticks_left[i] == 0:
				intents[i] = _random_intent(scripted)
				approaching[i] = scripted.randf() < APPROACH_CHANCE
				ticks_left[i] = scripted.randi_range(1, 40)
				if intents[i].held_actions == FighterInput.Action.HEAVY:
					# A hold that releases at each charge level, or none.
					var bucket := scripted.randi_range(0, CHARGE_HOLDS.size() - 1)
					ticks_left[i] = scripted.randi_range(CHARGE_HOLDS[bucket].x, CHARGE_HOLDS[bucket].y)
			ticks_left[i] -= 1
			var held := intents[i].held_actions
			if scripted.randf() < LIGHT_TAP_CHANCE:
				held ^= FighterInput.Action.LIGHT
			var plan := FighterInput.new()
			plan.held_actions = held
			plan.move = intents[i].move
			plan.vertical = intents[i].vertical
			plan.view_yaw = intents[i].view_yaw
			# Two thousand ticks of close combat, then a thousand of far-apart play.
			if approaching[i] and (_tick / 1000) % 3 != 2:
				_steer_toward(plan, sim.fighters[i], sim.fighters[1 - i], previous[i])
			var input := FighterInput.from_held(plan.held_actions, previous[i])
			input.move = plan.move
			input.vertical = plan.vertical
			input.view_yaw = plan.view_yaw
			input.target_switch = scripted.randi_range(-1, 1) if scripted.randf() < 0.01 else 0
			inputs.append(input)
		_script_meter_events(sim, scripted)
		var before: Array = sim.fighters.map(func(f: FighterState) -> Array: return [f.move, f.move_tick])
		sim.tick(inputs)
		previous = inputs
		_record_events(sim, visited)
		if sim.round_over:
			visited["ko"] = true
			sim.start_round()
		for i in sim.fighters.size():
			var fighter := sim.fighters[i]
			visited["state %d" % fighter.state] = true
			visited["dash %d" % fighter.dash_kind] = true
			visited["move %s" % fighter.move_id()] = true
			visited["string %d" % fighter.string_index] = true
			visited["charge %d" % fighter.charge_level] = true
			visited["combo %d" % mini(fighter.combo_hits, 4)] = true
			if fighter.state == FighterState.State.HITSTUN and fighter.combo_hits >= 2 \
					and fighter.position.y > sim.tuning.ground_height + 1.0:
				visited["juggle"] = true
			if fighter.spike_bounced:
				visited["spike bounce"] = true
			_record_cancel(before[i], fighter, visited)
	return sim.state_hash()


## Changes a planned input to look at the opponent. Out of reach it moves in,
## climbing or diving to the opponent's height, and holds new attacks back; in reach
## it keeps the planned direction, so heavies pick every direction, and presses
## light in the window after a light that hit, as a player continuing a string.
func _steer_toward(plan: FighterInput, fighter: FighterState, opponent: FighterState,
		previous: FighterInput) -> void:
	const ATTACKS := FighterInput.Action.LIGHT | FighterInput.Action.HEAVY
	var to_opponent := opponent.position - fighter.position
	plan.view_yaw = atan2(-to_opponent.x, -to_opponent.z)
	if to_opponent.length() > APPROACH_REACH:
		plan.move = Vector2(0, 1)
		plan.vertical = signi(int(to_opponent.y)) if absf(to_opponent.y) > 1.0 else 0
		if fighter.state != FighterState.State.ATTACKING:
			plan.held_actions &= ~ATTACKS
	elif _continues_string(fighter):
		# Released for a tick first if it was held, so the next tick is a press.
		if previous.is_held(FighterInput.Action.LIGHT):
			plan.held_actions &= ~FighterInput.Action.LIGHT
		else:
			plan.held_actions |= FighterInput.Action.LIGHT


## True when a light that hit can queue the next one right now, as a player would.
func _continues_string(fighter: FighterState) -> bool:
	return fighter.state == FighterState.State.ATTACKING and fighter.contact_hit \
		and fighter.string_index > 0 and not fighter.string_queued and not fighter.string_dropped \
		and fighter.move_tick >= fighter.move.string_window_start_tick


## Marks each event type and the knockback of each landed hit.
func _record_events(sim: CombatSim, visited: Dictionary) -> void:
	for event in sim.events:
		visited["event %d" % event.type] = true
		if event.type in [CombatSim.EventType.HIT, CombatSim.EventType.COUNTER]:
			visited["knockback %d" % event.knockback_type] = true


## Marks a cancel: the previous move was cut short by a heavy or a vanish step.
func _record_cancel(before: Array, fighter: FighterState, visited: Dictionary) -> void:
	var old_move: MoveData = before[0]
	if old_move == null or before[1] + 1 >= old_move.total_ticks() or old_move.can_charge():
		return
	if fighter.state == FighterState.State.VANISHING:
		visited["cancel vanish"] = true
	elif old_move.cancel_level == MoveData.CancelLevel.LIGHT and fighter.move != null \
			and fighter.move.cancel_level == MoveData.CancelLevel.HEAVY:
		visited["cancel heavy"] = true


## Stand-ins for what T-D05 will produce: blocking on and off, perfect blocks.
func _script_meter_events(sim: CombatSim, scripted: RandomNumberGenerator) -> void:
	for i in 2:
		var roll := scripted.randf()
		var fighter := sim.fighters[i]
		# Blocks in short spells (about a fifth of the time), so heavies are not all push-blocks.
		if roll < (0.04 if fighter.blocking else 0.01):
			fighter.blocking = not fighter.blocking
		elif roll > 0.999:
			sim.add_perfect_block_burst(i)
			sim.try_spend_burst(i, 1)


func _random_intent(scripted: RandomNumberGenerator) -> FighterInput:
	var intent := FighterInput.new()
	intent.held_actions = SCRIPTED_HOLDS[scripted.randi_range(0, SCRIPTED_HOLDS.size() - 1)]
	intent.move = SCRIPTED_MOVES[scripted.randi_range(0, SCRIPTED_MOVES.size() - 1)]
	intent.vertical = scripted.randi_range(-1, 1)
	intent.view_yaw = scripted.randf_range(-PI, PI)
	if intent.held_actions == FighterInput.Action.HEAVY and scripted.randf() < 0.5:
		# A neutral hold: the charged smash.
		intent.move = Vector2.ZERO
		intent.vertical = 0
	return intent


func test_same_seed_and_inputs_give_identical_state_after_10k_ticks() -> void:
	assert_eq(_run_match(42, 10_000, {}), _run_match(42, 10_000, {}))


func test_the_scripted_10k_tick_match_covers_every_kael_move_strings_charge_and_cancels() -> void:
	var visited := {}
	_run_match(42, 10_000, visited)
	var moves: MoveSet = (CombatSim.DEFAULT_FIGHTER_STATS as FighterStats).move_set
	var ids: Array[StringName] = []
	for move in moves.light_string:
		ids.append(move.id)
	for move: MoveData in [moves.smash, moves.breaker, moves.launcher, moves.rising, moves.spike,
			moves.sweep, moves.push_block]:
		ids.append(move.id)
	for move in moves.charged_smash:
		ids.append(move.id)
	for id in ids:
		assert_true(visited.has("move %s" % id), "performed %s" % id)
	assert_true(visited.has("string 4"), "a full light string")
	assert_true(visited.has("charge 3"), "a level 3 charged smash")
	assert_true(visited.has("cancel heavy"), "a light cancelled into a heavy")
	assert_true(visited.has("cancel vanish"), "an attack cancelled into a vanish step")


func test_the_scripted_10k_tick_match_lands_hits_combos_blocks_counters_and_every_knockback() -> void:
	var visited := {}
	_run_match(42, 10_000, visited)
	for type in CombatSim.EventType.values():
		assert_true(visited.has("event %d" % type), "a %s event" % CombatSim.EventType.keys()[type])
	for kind in [MoveData.KnockbackType.NONE, MoveData.KnockbackType.BLOWBACK,
			MoveData.KnockbackType.LAUNCH, MoveData.KnockbackType.SPIKE,
			MoveData.KnockbackType.SWEEP, MoveData.KnockbackType.WALL_SPLAT]:
		assert_true(visited.has("knockback %d" % kind), "a %s hit" % MoveData.KnockbackType.keys()[kind])
	assert_true(visited.has("combo 4"), "a combo of 4 or more hits")
	assert_true(visited.has("juggle"), "an airborne juggle")
	assert_true(visited.has("spike bounce"), "a spike bounce")


func test_the_scripted_10k_tick_match_covers_every_movement_mode_and_a_knockout() -> void:
	var visited := {}
	_run_match(42, 10_000, visited)
	assert_true(visited.has("ko"), "a round ended by KO")
	for state in [
		FighterState.State.IDLE, FighterState.State.MOVING, FighterState.State.FLYING,
		FighterState.State.DASHING, FighterState.State.VANISHING,
		FighterState.State.CHARGING, FighterState.State.GUARD_BROKEN, FighterState.State.ATTACKING,
		FighterState.State.HITSTUN, FighterState.State.BLOCKSTUN, FighterState.State.KNOCKDOWN,
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
	var input := FighterInput.from_held(FighterInput.Action.TRANSFORM, FighterInput.new())
	var inputs: Array[FighterInput] = [input]
	sim.tick(inputs)
	var before := sim.state_hash()
	sim.consume_buffered(0, FighterInput.Action.TRANSFORM)
	assert_ne(sim.state_hash(), before)
