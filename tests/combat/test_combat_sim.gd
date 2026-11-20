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
	FighterInput.Action.GRAB,
]
## Seeds of the 10k-tick matches whose combined record the coverage tests
## check. Several matches keep rare outcomes (one or two per match) from
## depending on one lucky seed when tuning changes.
const COVERAGE_SEEDS: Array[int] = [42, 43, 44, 46, 48, 50]
## Chances of the bots' defensive reads (per incoming strike for the block,
## else per tick), so blocks, perfect blocks, grabs, techs and push-blocks all
## happen: a block tap before a strike lands, a grab against a guard, a light
## against a grab in startup, a tech press while grabbed, a heavy while blocking.
const PERFECT_TAP_CHANCE := 0.3
## The block read presses this many ticks before the strike's first active tick.
const PERFECT_TAP_LEAD_TICKS := 3
const GRAB_GUARD_CHANCE := 0.03
const STRIKE_GRAB_CHANCE := 0.3
const TECH_CHANCE := 0.08
const PUSH_BLOCK_CHANCE := 0.015
## Intents holding block last at most this long, so guards come in short spells.
const BLOCK_HOLD_MAX_TICKS := 12
## Chances per tick that a guard spell (block held) starts and ends: about a fifth of the time.
const GUARD_ON_CHANCE := 0.01
const GUARD_OFF_CHANCE := 0.04
## Reads only happen within this distance, in metres.
const READ_RANGE := 4.0
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

## What the coverage matches did, recorded once in before_all() for the coverage tests.
var _coverage := {}


## Plays a scripted match of count fighters: each keeps a random intent for a
## random stretch of ticks, often steering toward its target, taps light now and
## then and makes defensive reads (block, perfect block, grab, tech, push-block),
## so every exchange happens. A KO starts the next round. Records states, dash
## kinds, moves, cancels, KOs, events and rock-paper-scissors outcomes seen.
func _run_match(seed_value: int, ticks: int, visited: Dictionary, count := 2,
		after_tick := Callable()) -> int:
	var sim := CombatSim.new(seed_value)
	# A Kael variant with less health and guard, a faster charge, a Breaker
	# that is armored through startup and wall-splats, and a slower grab, so KOs,
	# guard breaks, every charge level, armored hits, splats and a strike read
	# beating a grab in startup come often in random play.
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
	var grab := stats.move_set.grab.duplicate() as MoveData
	grab.startup_ticks = 12
	stats.move_set.grab = grab
	var previous: Array[FighterInput] = []
	var intents: Array[FighterInput] = []
	var approaching: Array[bool] = []
	var guarding: Array[bool] = []
	var ticks_left: Array[int] = []
	for i in count:
		sim.add_fighter(DetMath.rotate_y(Vector3(0, 1, 6), TAU * i / count), stats)
		previous.append(FighterInput.new())
		intents.append(FighterInput.new())
		approaching.append(false)
		guarding.append(false)
		ticks_left.append(0)
	sim.lock_everyone_onto_nearest()
	var scripted := RandomNumberGenerator.new()
	scripted.seed = 1234 + seed_value
	for _tick in ticks:
		var inputs: Array[FighterInput] = []
		for i in count:
			if ticks_left[i] == 0:
				intents[i] = _random_intent(scripted)
				approaching[i] = scripted.randf() < APPROACH_CHANCE
				ticks_left[i] = scripted.randi_range(1, 40)
				if intents[i].is_held(FighterInput.Action.BLOCK):
					ticks_left[i] = mini(ticks_left[i], BLOCK_HOLD_MAX_TICKS)
				if intents[i].held_actions == FighterInput.Action.HEAVY:
					# A hold that releases at each charge level, or none.
					var bucket := scripted.randi_range(0, CHARGE_HOLDS.size() - 1)
					ticks_left[i] = scripted.randi_range(CHARGE_HOLDS[bucket].x, CHARGE_HOLDS[bucket].y)
			ticks_left[i] -= 1
			var held := intents[i].held_actions
			if scripted.randf() < LIGHT_TAP_CHANCE:
				held ^= FighterInput.Action.LIGHT
			if scripted.randf() < (GUARD_OFF_CHANCE if guarding[i] else GUARD_ON_CHANCE):
				guarding[i] = not guarding[i]
			if guarding[i]:
				held |= FighterInput.Action.BLOCK
			var plan := FighterInput.new()
			plan.held_actions = held
			plan.move = intents[i].move
			plan.vertical = intents[i].vertical
			plan.view_yaw = intents[i].view_yaw
			var opponent := sim.fighters[_target_of(sim, i)]
			# Two thousand ticks of close combat, then a thousand of far-apart play.
			if approaching[i] and (_tick / 1000) % 3 != 2:
				_steer_toward(plan, sim.fighters[i], opponent, previous[i])
			_read_defense(plan, sim.fighters[i], opponent, previous[i], scripted)
			var input := FighterInput.from_held(plan.held_actions, previous[i])
			input.move = plan.move
			input.vertical = plan.vertical
			input.view_yaw = plan.view_yaw
			input.target_switch = scripted.randi_range(-1, 1) if scripted.randf() < 0.01 else 0
			inputs.append(input)
		var before: Array = sim.fighters.map(
			func(f: FighterState) -> Array: return [f.move, f.move_tick, f.state, f.attack_phase()])
		sim.tick(inputs)
		if after_tick.is_valid():
			after_tick.call(sim)
		previous = inputs
		_record_events(sim, before, visited)
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


## Changes a planned input to look at the opponent. After a light that hit it
## presses light in the window, as a player continuing a string. Otherwise, out
## of reach it moves in, climbing or diving to the opponent's height, and holds
## new attacks back; in reach it keeps the planned direction, so heavies pick
## every direction.
func _steer_toward(plan: FighterInput, fighter: FighterState, opponent: FighterState,
		previous: FighterInput) -> void:
	const ATTACKS := FighterInput.Action.LIGHT | FighterInput.Action.HEAVY
	var to_opponent := opponent.position - fighter.position
	plan.view_yaw = DetMath.atan2(-to_opponent.x, -to_opponent.z)
	if _continues_string(fighter):
		# Released for a tick first if it was held, so the next tick is a press.
		if previous.is_held(FighterInput.Action.LIGHT):
			plan.held_actions &= ~FighterInput.Action.LIGHT
		else:
			plan.held_actions |= FighterInput.Action.LIGHT
	elif to_opponent.length() > APPROACH_REACH:
		plan.move = Vector2(0, 1)
		plan.vertical = signi(int(to_opponent.y)) if absf(to_opponent.y) > 1.0 else 0
		if fighter.state != FighterState.State.ATTACKING:
			plan.held_actions &= ~ATTACKS


## True when a light that hit can queue the next one right now, as a player would.
func _continues_string(fighter: FighterState) -> bool:
	return fighter.state == FighterState.State.ATTACKING and fighter.contact_hit \
		and fighter.string_index > 0 and not fighter.string_queued and not fighter.string_dropped \
		and fighter.move_tick >= fighter.move.string_window_start_tick


## The fighter's lock-on target, or its nearest opponent when unlocked.
func _target_of(sim: CombatSim, index: int) -> int:
	var target := sim.fighters[index].lock_on_target
	if target >= 0:
		return target
	var nearest := -1
	for other in sim.fighters.size():
		if other != index and (nearest < 0 or sim.fighters[index].position.distance_squared_to(
				sim.fighters[other].position) < sim.fighters[index].position.distance_squared_to(
				sim.fighters[nearest].position)):
			nearest = other
	return nearest


## Defensive reads on top of the plan: a block press against a strike in
## startup (a perfect block if it lands in the window, else held as a block),
## a light against a grab in startup, a grab against a raised guard, a tech
## press while grabbed, and a heavy while blocking (push-block).
func _read_defense(plan: FighterInput, fighter: FighterState, opponent: FighterState,
		previous: FighterInput, scripted: RandomNumberGenerator) -> void:
	var roll := scripted.randf()
	if fighter.state == FighterState.State.GRABBED:
		if roll < TECH_CHANCE:
			plan.held_actions = FighterInput.Action.GRAB
		return
	if fighter.state in [FighterState.State.BLOCKING, FighterState.State.BLOCKSTUN]:
		if roll < PUSH_BLOCK_CHANCE:
			plan.held_actions = FighterInput.Action.BLOCK | FighterInput.Action.HEAVY
		return
	if fighter.position.distance_to(opponent.position) > READ_RANGE:
		return
	# One read per incoming strike, a few ticks before it goes active; a raised guard stays up.
	if opponent.attack_phase() == FighterState.AttackPhase.STARTUP \
			and opponent.move.kind == MoveData.Kind.STRIKE \
			and ((opponent.move.startup_ticks - opponent.phase_tick() == PERFECT_TAP_LEAD_TICKS
					and roll < PERFECT_TAP_CHANCE)
				or previous.is_held(FighterInput.Action.BLOCK)):
		plan.held_actions = FighterInput.Action.BLOCK
	elif opponent.attack_phase() == FighterState.AttackPhase.STARTUP \
			and opponent.move.kind == MoveData.Kind.GRAB and roll < STRIKE_GRAB_CHANCE:
		plan.held_actions = FighterInput.Action.LIGHT
	elif opponent.state == FighterState.State.BLOCKING and roll < GRAB_GUARD_CHANCE:
		plan.held_actions = FighterInput.Action.GRAB


## Marks each event type, the knockback of each landed hit and the close-range
## rock-paper-scissors outcomes, reading the target as it was before the tick.
func _record_events(sim: CombatSim, before: Array, visited: Dictionary) -> void:
	for event in sim.events:
		visited["event %d" % event.type] = true
		if event.type in [CombatSim.EventType.HIT, CombatSim.EventType.COUNTER]:
			visited["knockback %d" % event.knockback_type] = true
		if not event.has("target"):
			continue
		var target_before: Array = before[event.target]
		var target_move: MoveData = target_before[0]
		match event.type:
			CombatSim.EventType.GRAB:
				if target_before[2] == FighterState.State.BLOCKING:
					visited["grab beats block"] = true
			CombatSim.EventType.COUNTER:
				if target_move and target_move.kind == MoveData.Kind.GRAB \
						and target_before[3] == FighterState.AttackPhase.STARTUP:
					visited["strike beats grab"] = true
			CombatSim.EventType.BLOCK, CombatSim.EventType.PERFECT_BLOCK:
				visited["block beats strike"] = true


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


func before_all() -> void:
	for seed_value in COVERAGE_SEEDS:
		_run_match(seed_value, 10_000, _coverage)


func test_same_seed_and_inputs_give_identical_state_after_10k_ticks() -> void:
	assert_eq(_run_match(42, 10_000, {}), _run_match(42, 10_000, {}))


func test_a_scripted_4_fighter_free_for_all_is_deterministic_and_has_every_defense() -> void:
	var visited := {}
	var first := _run_match(12, 10_000, visited, 4)
	assert_eq(first, _run_match(12, 10_000, {}, 4))
	# A second match, so a rare defense does not hang on one seed's luck.
	_run_match(11, 10_000, visited, 4)
	for type in [CombatSim.EventType.BLOCK, CombatSim.EventType.PERFECT_BLOCK, CombatSim.EventType.GRAB,
			CombatSim.EventType.THROW, CombatSim.EventType.GRAB_TECH, CombatSim.EventType.PUSH_BLOCK]:
		assert_true(visited.has("event %d" % type), "a %s event" % CombatSim.EventType.keys()[type])


func test_the_scripted_10k_tick_matches_cover_every_kael_move_strings_charge_and_cancels() -> void:
	var visited: Dictionary = _coverage
	var moves: MoveSet = (CombatSim.DEFAULT_FIGHTER_STATS as FighterStats).move_set
	var ids: Array[StringName] = []
	for move in moves.light_string:
		ids.append(move.id)
	for move: MoveData in [moves.smash, moves.breaker, moves.launcher, moves.rising, moves.spike,
			moves.sweep, moves.push_block, moves.grab]:
		ids.append(move.id)
	for move in moves.charged_smash:
		ids.append(move.id)
	for id in ids:
		assert_true(visited.has("move %s" % id), "performed %s" % id)
	assert_true(visited.has("string 4"), "a full light string")
	assert_true(visited.has("charge 3"), "a level 3 charged smash")
	assert_true(visited.has("cancel heavy"), "a light cancelled into a heavy")
	assert_true(visited.has("cancel vanish"), "an attack cancelled into a vanish step")


func test_the_scripted_10k_tick_matches_land_every_event_knockback_and_defense_outcome() -> void:
	var visited: Dictionary = _coverage
	# Weapon events (PICKUP_SPAWN and later) are covered by test_weapons.gd's bot match.
	for type in range(CombatSim.EventType.PICKUP_SPAWN):
		assert_true(visited.has("event %d" % type), "a %s event" % CombatSim.EventType.keys()[type])
	for kind in [MoveData.KnockbackType.NONE, MoveData.KnockbackType.BLOWBACK,
			MoveData.KnockbackType.LAUNCH, MoveData.KnockbackType.SPIKE,
			MoveData.KnockbackType.SWEEP, MoveData.KnockbackType.WALL_SPLAT]:
		assert_true(visited.has("knockback %d" % kind), "a %s hit" % MoveData.KnockbackType.keys()[kind])
	assert_true(visited.has("combo 4"), "a combo of 4 or more hits")
	assert_true(visited.has("grab beats block"), "a grab beating a block")
	assert_true(visited.has("strike beats grab"), "a strike beating a grab in startup")
	assert_true(visited.has("block beats strike"), "a block beating a strike")
	assert_true(visited.has("juggle"), "an airborne juggle")
	assert_true(visited.has("spike bounce"), "a spike bounce")


func test_the_scripted_10k_tick_matches_cover_every_movement_mode_and_a_knockout() -> void:
	var visited: Dictionary = _coverage
	assert_true(visited.has("ko"), "a round ended by KO")
	for state in [
		FighterState.State.IDLE, FighterState.State.MOVING, FighterState.State.FLYING,
		FighterState.State.DASHING, FighterState.State.VANISHING,
		FighterState.State.CHARGING, FighterState.State.GUARD_BROKEN, FighterState.State.ATTACKING,
		FighterState.State.HITSTUN, FighterState.State.BLOCKSTUN, FighterState.State.KNOCKDOWN,
		FighterState.State.BLOCKING, FighterState.State.GRABBED, FighterState.State.THROWING,
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


func test_state_hash_covers_the_vanish_anchor_and_offset() -> void:
	var sim := CombatSim.new()
	var fighter := sim.add_fighter(Vector3.ZERO)
	sim.add_fighter(Vector3(0, 0, -10))
	var before := sim.state_hash()
	fighter.vanish_anchor = 1
	var anchored := sim.state_hash()
	assert_ne(anchored, before)
	fighter.vanish_offset = Vector3(0, 0, 10)
	assert_ne(sim.state_hash(), anchored)
