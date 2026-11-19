extends GutTest
## T-D29: fighters' bodies never pass through or sink into each other.

const State := FighterState.State
const Event := CombatSim.EventType
const DASH := FighterInput.Action.DASH
const BLOCK := FighterInput.Action.BLOCK
const LIGHT := FighterInput.Action.LIGHT
const HEAVY := FighterInput.Action.HEAVY
const GRAB := FighterInput.Action.GRAB
const BRANN := preload("res://game/combat/moves/brann/brann_fighter_stats.tres")
const LYRA := preload("res://game/combat/moves/lyra/lyra_fighter_stats.tres")
const VEXA := preload("res://game/combat/vexa_fighter_stats.tres")
## Bodies may overlap by at most this much (m) after a tick.
const TOLERANCE := 0.01

var _sim: CombatSim
var _previous: Array[FighterInput] = []


func _start(positions: Array[Vector3], stats: Array = [], tuning: MovementTuning = null,
		lock := true) -> void:
	_sim = CombatSim.new(7, tuning)
	for i in positions.size():
		_sim.add_fighter(positions[i], stats[i] if i < stats.size() else null)
	if lock:
		_sim.lock_everyone_onto_nearest()
	_previous = []
	for _i in positions.size():
		_previous.append(FighterInput.new())


## One tick; each entry of plans is [held, move, vertical] for that fighter (missing = neutral).
func _tick(plans: Array = []) -> void:
	var inputs: Array[FighterInput] = []
	for f in _sim.fighters.size():
		var plan: Array = plans[f] if f < plans.size() else [0, Vector2.ZERO, 0]
		var input := FighterInput.from_held(plan[0], _previous[f])
		input.move = plan[1]
		input.vertical = plan[2]
		inputs.append(input)
	_sim.tick(inputs)
	_previous = inputs


## Smallest surface gap between any two fighters that block each other (negative = overlap).
func _worst_gap() -> float:
	var worst := INF
	for a in _sim.fighters.size():
		for b in range(a + 1, _sim.fighters.size()):
			if Pushboxes.collide(_sim, a, b):
				var first := _sim.fighters[a]
				var second := _sim.fighters[b]
				worst = minf(worst, Pushboxes.gap(first, first.position, second, second.position))
	return worst


## A seeded brawl: everyone runs, flies, dashes, rushes and attacks at its target.
## Returns [state hash, worst gap, ticks spent in contact].
func _brawl(seed_value: int, count: int, ticks: int) -> Array:
	var positions: Array[Vector3] = []
	var roster := [null, VEXA, BRANN, LYRA]
	for i in count:
		positions.append(Basis(Vector3.UP, TAU * i / count) * Vector3(0, 0, 5))
	_start(positions, roster)
	var bot := RandomNumberGenerator.new()
	bot.seed = seed_value
	var plans: Array = []
	var hold: Array[int] = []
	for _i in count:
		plans.append([0, Vector2.ZERO, 0])
		hold.append(0)
	var worst := INF
	var contact_ticks := 0
	for _t in ticks:
		for i in count:
			hold[i] -= 1
			if hold[i] > 0:
				continue
			hold[i] = bot.randi_range(4, 30)
			var held: int = [0, 0, DASH, DASH, LIGHT, HEAVY, BLOCK, GRAB, DASH | BLOCK, LIGHT][bot.randi_range(0, 9)]
			# Mostly straight at the target, to force body contact.
			var move := Vector2(0, 1) if bot.randf() < 0.7 else Vector2(bot.randf_range(-1, 1), bot.randf_range(-1, 1))
			plans[i] = [held, move, bot.randi_range(-1, 1) if bot.randf() < 0.3 else 0]
		_tick(plans)
		if _sim.round_over:
			_sim.start_round()
			continue
		var gap := _worst_gap()
		worst = minf(worst, gap)
		if gap < 0.05:
			contact_ticks += 1
	return [_sim.state_hash(), worst, contact_ticks]


func test_two_fighters_brawling_for_a_minute_never_overlap_and_it_is_deterministic() -> void:
	var first := _brawl(3, 2, 3600)
	assert_gte(first[1], -TOLERANCE, "worst overlap %.3f m" % -first[1])
	assert_gt(first[2], 20, "they were in contact for %d ticks" % first[2])
	assert_eq(first[0], _brawl(3, 2, 3600)[0], "same seed and inputs, same hash")


func test_four_fighters_brawling_for_a_minute_never_overlap_and_it_is_deterministic() -> void:
	var first := _brawl(11, 4, 3600)
	assert_gte(first[1], -TOLERANCE, "worst overlap %.3f m" % -first[1])
	assert_gt(first[2], 20, "they were in contact for %d ticks" % first[2])
	assert_eq(first[0], _brawl(11, 4, 3600)[0], "same seed and inputs, same hash")


func test_walking_into_each_other_stops_at_contact() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -4)])
	for _i in 120:
		_tick([[0, Vector2(0, 1), 0], [0, Vector2(0, 1), 0]])
	var distance := _sim.fighters[0].position.distance_to(_sim.fighters[1].position)
	assert_almost_eq(distance, 1.0, 0.02, "two default bodies touch at 1 m")
	assert_gt(_sim.fighters[0].position.z, _sim.fighters[1].position.z, "nobody passed through")
	# Pressed together they stand still, so the view does not lean them into each other.
	assert_almost_eq(_sim.fighters[0].velocity.z, 0.0, 0.01)
	assert_almost_eq(_sim.fighters[1].velocity.z, 0.0, 0.01)


func _assert_no_tunnelling(name: String, start_a: Vector3, start_b: Vector3, tuning: MovementTuning,
		plan: Array, lock: bool) -> void:
	_start([start_a, start_b], [], tuning, lock)
	var worst := INF
	for _i in 90:
		_tick([plan])
		worst = minf(worst, _worst_gap())
	assert_gte(worst, -TOLERANCE, "%s: overlap %.3f m" % [name, -worst])
	assert_gt(_sim.fighters[0].position.z, _sim.fighters[1].position.z, "%s: passed through" % name)
	var distance := _sim.fighters[0].position.distance_to(_sim.fighters[1].position)
	assert_lt(distance, 1.06, "%s: stopped at contact (%.2f m)" % [name, distance])


func test_no_tunnelling_at_rush_speed() -> void:
	var tuning := (CombatSim.DEFAULT_TUNING as MovementTuning).duplicate() as MovementTuning
	# Rush straight into the target at well over the real top speed.
	tuning.rush_stop_distance = 0.0
	tuning.rush_brake_ticks = 0
	tuning.rush_speed = 150.0
	_assert_no_tunnelling("rush", Vector3(0, 0, 20), Vector3.ZERO, tuning, [DASH, Vector2(0, 1), 0], true)
	assert_eq(_sim.fighters[0].dash_kind, FighterState.DashKind.RUSH, "it was a rush")


func test_no_tunnelling_at_sustained_dash_and_flight_speed() -> void:
	var tuning := (CombatSim.DEFAULT_TUNING as MovementTuning).duplicate() as MovementTuning
	tuning.sustained_dash_speed = 150.0
	tuning.fly_speed = 150.0
	tuning.fly_acceleration = 100_000.0
	# Unlocked, so the dash is a straight sustained dash, not a rush.
	_assert_no_tunnelling("dash", Vector3(0, 0, 20), Vector3.ZERO, tuning, [DASH, Vector2(0, 1), 0], false)
	_assert_no_tunnelling("flight", Vector3(0, 6, 20), Vector3(0, 6, 0), tuning, [0, Vector2(0, 1), 0], false)


func test_the_heavier_fighter_gives_way_less() -> void:
	# Brann walks into a standing Lyra: she is shoved; Lyra walks into Brann: he barely moves.
	_start([Vector3.ZERO, Vector3(0, 0, -1.3)], [BRANN, LYRA])
	for _i in 60:
		_tick([[0, Vector2(0, 1), 0]])
	var lyra_shoved := -1.3 - _sim.fighters[1].position.z
	_start([Vector3.ZERO, Vector3(0, 0, -1.3)], [LYRA, BRANN])
	for _i in 60:
		_tick([[0, Vector2(0, 1), 0]])
	var brann_shoved := -1.3 - _sim.fighters[1].position.z
	assert_gt(lyra_shoved, 0.5, "Lyra shoved %.2f m" % lyra_shoved)
	assert_lt(brann_shoved, lyra_shoved * 0.5, "Brann shoved %.2f m" % brann_shoved)
	assert_gte(_worst_gap(), -TOLERANCE)


## Fighter 0 hits a blocking fighter 1 with a light; returns how far each moved
## from the block until 30 ticks later.
func _block_pushback(defender_z: float, arena_half_size: float) -> Vector2:
	var tuning := (CombatSim.DEFAULT_TUNING as MovementTuning).duplicate() as MovementTuning
	tuning.arena_half_size = arena_half_size
	_start([Vector3(0, 0, defender_z + 1.1), Vector3(0, 0, defender_z)], [], tuning)
	# Guard held long past the perfect-block window, so it is a plain block.
	for _i in 30:
		_tick([[0, Vector2.ZERO, 0], [BLOCK, Vector2.ZERO, 0]])
	_tick([[LIGHT, Vector2.ZERO, 0], [BLOCK, Vector2.ZERO, 0]])
	var blocked := false
	for _i in 30:
		_tick([[0, Vector2.ZERO, 0], [BLOCK, Vector2.ZERO, 0]])
		if _sim.events.any(func(e: Dictionary) -> bool: return e.type == Event.BLOCK):
			blocked = true
			break
	assert_true(blocked, "the light was blocked")
	var attacker_at := _sim.fighters[0].position.z
	var defender_at := _sim.fighters[1].position.z
	for _i in 30:
		_tick([[0, Vector2.ZERO, 0], [BLOCK, Vector2.ZERO, 0]])
	return Vector2(_sim.fighters[0].position.z - attacker_at, defender_at - _sim.fighters[1].position.z)


func test_a_block_pushes_the_defender_back_in_the_open() -> void:
	var moved := _block_pushback(-1.0, 300.0)
	assert_almost_eq(moved.y, _sim.hit_tuning.block_pushback_distance, 0.02, "defender slid back")
	assert_almost_eq(moved.x, 0.0, 0.02, "attacker stayed")


func test_a_defender_pinned_to_the_wall_pushes_the_attacker_back_instead() -> void:
	var moved := _block_pushback(-5.0, 5.0)
	assert_almost_eq(moved.y, 0.0, 0.001, "defender is against the wall")
	assert_almost_eq(moved.x, _sim.hit_tuning.block_pushback_distance, 0.02, "attacker slid back")
	assert_gte(_worst_gap(), -TOLERANCE)


func test_walking_into_a_pinned_fighter_cannot_push_it_through_the_wall() -> void:
	var tuning := (CombatSim.DEFAULT_TUNING as MovementTuning).duplicate() as MovementTuning
	tuning.arena_half_size = 5.0
	_start([Vector3(0, 0, -3), Vector3(0, 0, -4.9)], [BRANN, LYRA], tuning)
	for _i in 60:
		_tick([[0, Vector2(0, 1), 0]])
	assert_almost_eq(_sim.fighters[1].position.z, -5.0, 0.001, "Lyra stays at the wall")
	assert_gte(_worst_gap(), -TOLERANCE, "Brann stops at her body")


func test_vanished_fighters_pass_through_bodies() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -3)])
	_tick([[DASH | BLOCK, Vector2.ZERO, 0]])
	assert_eq(_sim.fighters[0].state, State.VANISHING)
	assert_false(Pushboxes.collide(_sim, 0, 1))
	# Sitting inside the other's body while vanished is not resolved.
	_sim.fighters[0].vanish_offset = Vector3(0, 0, 0.2)
	_tick()
	var distance := _sim.fighters[0].position.distance_to(_sim.fighters[1].position)
	assert_almost_eq(distance, 0.2, 0.001)


func test_lyras_star_step_passes_through_a_fighter_behind_her() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, 1.5)], [LYRA], null, false)
	var lyra := _sim.fighters[0]
	lyra.facing_yaw = 0.0
	lyra.begin_move(LYRA.move_set.launcher)
	for _i in lyra.move.startup_ticks:
		_tick()
	assert_true(LYRA.move_set.launcher.ignores_pushbox)
	assert_gt(lyra.position.z, 3.0, "she stepped back past the fighter at 1.5 m")


func test_a_grab_still_connects_at_body_contact() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -3)])
	for _i in 60:
		_tick([[0, Vector2(0, 1), 0], [0, Vector2(0, 1), 0]])
	assert_lt(_worst_gap(), 0.02, "touching")
	var grabbed := false
	_tick([[GRAB, Vector2.ZERO, 0]])
	for _i in 30:
		_tick()
		if _sim.events.any(func(e: Dictionary) -> bool: return e.type == Event.GRAB):
			grabbed = true
			break
	assert_true(grabbed, "the grab connected")
	assert_false(Pushboxes.collide(_sim, 0, 1), "the held pair does not push each other")


func test_a_light_string_still_connects_at_body_contact() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -3)])
	for _i in 60:
		_tick([[0, Vector2(0, 1), 0], [0, Vector2(0, 1), 0]])
	var hits := 0
	for i in 90:
		_tick([[LIGHT if i % 8 < 2 else 0, Vector2.ZERO, 0]])
		hits += _sim.events.filter(func(e: Dictionary) -> bool: return e.type == Event.HIT).size()
	assert_gte(hits, 3, "the string connected %d times" % hits)


func test_state_hash_covers_pushback() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -3)])
	var before := _sim.state_hash()
	_sim.fighters[1].pushback_ticks = 3
	assert_ne(_sim.state_hash(), before)


func test_strafing_point_blank_circles_no_faster_than_the_orbit_cap() -> void:
	_start([Vector3.ZERO, Vector3(0, 0, -1.0)])
	var cap := deg_to_rad(_sim.tuning.max_orbit_turn_speed) * CombatSim.TICK_SECONDS
	var fastest := 0.0
	for _i in 60:
		var before := _sim.fighters[0].position - _sim.fighters[1].position
		_tick([[0, Vector2(1, 0.3), 0]])
		var after := _sim.fighters[0].position - _sim.fighters[1].position
		fastest = maxf(fastest, absf(Vector2(before.x, before.z).angle_to(Vector2(after.x, after.z))))
	assert_gt(fastest, cap * 0.9, "it did circle")
	assert_lte(fastest, cap + 0.0001, "%.1f deg in a tick" % rad_to_deg(fastest))
