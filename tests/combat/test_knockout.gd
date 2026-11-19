extends GutTest
## KO physics (fall, one bounce, lie down), N-fighter and team round ends, round reset (T-D16).

const LIGHT := FighterInput.Action.LIGHT
const DASH := FighterInput.Action.DASH
const State := FighterState.State
const Event := CombatSim.EventType
const UNIT := FighterState.METER_UNIT
## A KO from 8 m up must be lying still within this many ticks.
const REST_WITHIN_TICKS := 240

var _sim: CombatSim
var _previous: Array[FighterInput] = []


## Fighter 0 at start_0, the others where given; all locked onto their nearest opponent.
func _start(others: Array[Vector3], start_0 := Vector3.ZERO, seed_value := 0) -> void:
	_sim = CombatSim.new(seed_value)
	_sim.add_fighter(start_0)
	for at in others:
		_sim.add_fighter(at)
	_sim.lock_everyone_onto_nearest()
	_previous = []
	for _i in _sim.fighters.size():
		_previous.append(FighterInput.new())


## Runs ticks with per-fighter held actions (missing entries are neutral); returns every event.
func _tick(ticks := 1, held: Array = []) -> Array[Dictionary]:
	var seen: Array[Dictionary] = []
	for _i in ticks:
		var inputs: Array[FighterInput] = []
		for f in _sim.fighters.size():
			inputs.append(FighterInput.from_held(held[f] if f < held.size() else 0, _previous[f]))
		_sim.tick(inputs)
		_previous = inputs
		seen.append_array(_sim.events)
	return seen


func _fighter(index: int) -> FighterState:
	return _sim.fighters[index]


static func _types(events: Array[Dictionary], fighter: int) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return e.get("fighter", -1) == fighter) \
		.map(func(e: Dictionary) -> int: return e.type)


## Fighter 0 lands a light on fighter 1 with one health left, both hovering 8 m up.
func _knock_out_in_the_air() -> Array[Dictionary]:
	_start([Vector3(0, 8, -2)], Vector3(0, 8, 0))
	_fighter(1).health = 1
	var events := _tick(1, [LIGHT])
	for _i in 30:
		events.append_array(_tick())
		if _fighter(1).is_knocked_out():
			break
	return events


func test_a_knockout_in_the_air_falls_bounces_once_and_lies_down() -> void:
	var events := _knock_out_in_the_air()
	assert_true(_fighter(1).is_knocked_out(), "the light knocked fighter 1 out")
	assert_eq(_fighter(1).state, State.KO_FALL, "no more flight")
	var lowest := INF
	var ticks := 0
	while ticks < REST_WITHIN_TICKS and not (_fighter(1).state == State.KO_DOWN \
			and _fighter(1).velocity == Vector3.ZERO):
		events.append_array(_tick())
		lowest = minf(lowest, _fighter(1).position.y)
		ticks += 1
	assert_lt(ticks, REST_WITHIN_TICKS, "at rest within %d ticks" % REST_WITHIN_TICKS)
	assert_eq(_types(events, 1), [Event.KO_BOUNCE, Event.KO_REST], "exactly one bounce, then rest")
	assert_eq(_fighter(1).state, State.KO_DOWN)
	assert_eq(_fighter(1).position.y, _sim.tuning.ground_height, "lying on the floor")
	assert_gte(lowest, _sim.tuning.ground_height, "never below the floor")
	_tick(120)
	assert_eq(_fighter(1).state, State.KO_DOWN, "stays down until the round ends")


func test_the_bounce_goes_up_and_keeps_part_of_the_slide() -> void:
	_start([Vector3(0, 0, -40)])
	var fighter := _fighter(0)
	fighter.velocity = Vector3(10, 0, 0)
	_sim.apply_damage(0, 1, 20_000)
	var events: Array[Dictionary] = []
	while not events.any(func(e: Dictionary) -> bool: return e.type == Event.KO_BOUNCE):
		events = _tick()
	assert_gt(fighter.velocity.y, 0.0, "bounces up")
	assert_almost_eq(fighter.velocity.x, 10.0 * _sim.hit_tuning.ko_bounce_slide, 0.5, "a damped slide")
	var x_at_bounce := fighter.position.x
	_tick(REST_WITHIN_TICKS)
	assert_eq(fighter.state, State.KO_DOWN)
	assert_gt(fighter.position.x, x_at_bounce, "slid on after the bounce")


func test_a_knockout_carries_the_knockback_it_was_given() -> void:
	_start([Vector3(0, 0, -40)], Vector3(0, 6, 0))
	_fighter(0).velocity = Vector3(0, 0, 12)
	_sim.apply_damage(0, 1, 20_000)
	_tick()
	assert_eq(_fighter(0).state, State.KO_FALL)
	assert_gt(_fighter(0).velocity.z, 11.0, "keeps its knockback")
	assert_lt(_fighter(0).velocity.y, 0.0, "and starts falling")


func test_a_knockout_stops_at_the_arena_wall() -> void:
	_start([Vector3(0, 0, -40)])
	var half := _sim.tuning.arena_half_size
	_fighter(0).position = Vector3(half - 0.5, 5, 0)
	_fighter(0).velocity = Vector3(30, 0, 0)
	_sim.apply_damage(0, 1, 20_000)
	_tick(REST_WITHIN_TICKS)
	assert_eq(_fighter(0).state, State.KO_DOWN)
	assert_lte(_fighter(0).position.x, half, "inside the wall")


func test_the_same_inputs_give_the_same_hash_through_a_knockout() -> void:
	var hashes: Array = []
	for _run in 2:
		_knock_out_in_the_air()
		var run: Array[int] = []
		for _i in REST_WITHIN_TICKS:
			_tick()
			run.append(_sim.state_hash())
		hashes.append(run)
	assert_eq(hashes[0], hashes[1])


func test_state_hash_covers_the_knockout_fields() -> void:
	_start([Vector3(0, 0, -40)])
	var base := _sim.state_hash()
	_fighter(0).ko_bounced = true
	assert_ne(_sim.state_hash(), base, "ko_bounced")
	_fighter(0).ko_bounced = false
	_fighter(0).team = 1
	assert_ne(_sim.state_hash(), base, "team")
	_fighter(0).team = 0
	_sim.winning_team = 0
	assert_ne(_sim.state_hash(), base, "winning_team")


func test_a_knocked_out_fighter_cannot_be_hit() -> void:
	_start([Vector3(0, 0, -2), Vector3(3, 0, -2)])
	_sim.apply_damage(1, 2, 20_000)
	assert_false(_sim.round_over, "two fighters still standing")
	assert_false(_fighter(1).can_be_hit())
	_tick()
	assert_eq(_fighter(1).state, State.KO_FALL)
	_fighter(0).lock_on_target = 1
	var events := _tick(20, [LIGHT])
	assert_false(events.any(func(e: Dictionary) -> bool: return e.get("target", -1) == 1),
		"hits pass through the KO'd fighter")


func test_a_knocked_out_fighter_ignores_its_inputs_and_drops_its_weapons() -> void:
	_start([Vector3(0, 0, -20), Vector3(20, 0, 0)])
	_fighter(0).weapons = PackedInt32Array([Weapon.Kind.STORM_BLADE, 0, 0])
	_fighter(0).active_slot = 0
	_sim.apply_damage(0, 1, 20_000)
	_tick(60, [DASH])
	assert_true(_fighter(0).is_ko_state())
	assert_eq(_fighter(0).weapon_count(), 0)
	assert_eq(_sim.pickups.size(), 1, "the blade lies on the floor")


func test_free_for_all_goes_on_until_one_fighter_is_left() -> void:
	_start([Vector3(0, 0, -20), Vector3(20, 0, 0), Vector3(-20, 0, 0)])
	_sim.apply_damage(1, 0, 20_000)
	assert_false(_sim.round_over)
	_tick()
	assert_ne(_fighter(0).lock_on_target, 1, "lock-on moves off the KO'd fighter")
	_sim.apply_damage(3, 2, 20_000)
	assert_false(_sim.round_over)
	_sim.apply_damage(0, 2, 20_000)
	assert_true(_sim.round_over)
	assert_eq(_sim.round_winner, 2, "the last one standing")
	assert_eq(_sim.winning_team, 2)


func test_a_team_wins_when_the_other_team_is_out() -> void:
	_start([Vector3(0, 0, -20), Vector3(20, 0, 0), Vector3(-20, 0, 0)])
	_fighter(0).team = 0
	_fighter(1).team = 1
	_fighter(2).team = 0
	_fighter(3).team = 1
	_sim.apply_damage(0, 1, 20_000)
	_sim.apply_damage(1, 0, 20_000)
	assert_false(_sim.round_over, "one fighter on each team left")
	_sim.apply_damage(3, 2, 20_000)
	assert_true(_sim.round_over)
	assert_eq(_sim.winning_team, 0)
	assert_eq(_sim.round_winner, 2, "the winning team's fighter still standing")


func test_teammates_do_not_hit_each_other() -> void:
	_start([Vector3(0, 0, -2), Vector3(0, 0, -40)])
	_fighter(1).team = 0
	_fighter(0).lock_on_target = 1
	var events := _tick(30, [LIGHT])
	assert_false(events.any(func(e: Dictionary) -> bool: return e.get("target", -1) == 1))


func test_a_double_knockout_is_a_draw() -> void:
	_start([Vector3(0, 0, -20)])
	_fighter(0).health = 0
	_sim.apply_damage(1, 0, 20_000)
	assert_true(_sim.round_over)
	assert_eq(_sim.round_winner, -1)
	assert_eq(_sim.winning_team, -1)


func test_start_round_resets_fighters_to_their_round_start() -> void:
	_start([Vector3(0, 10, -20)])
	var fighter := _fighter(0)
	fighter.weapons = PackedInt32Array([Weapon.Kind.STORM_BLADE, Weapon.Kind.ARC_REVOLVER, 0])
	fighter.ammo = PackedInt32Array([0, 6, 0])
	fighter.active_slot = 1
	_sim.pickups_enabled = true
	_tick(10, [DASH])
	_sim.apply_damage(1, 0, 20_000)
	_tick(30)
	fighter.smitten_ticks = 20
	fighter.ki = 3 * UNIT
	fighter.guard = 5 * UNIT
	var burst := fighter.burst
	assert_gt(burst, 0)
	_sim.pickups.append(WeaponPickup.new())
	_sim.projectiles.append(Projectile.new())
	_sim.start_round()
	for i in 2:
		var f := _fighter(i)
		assert_eq(f.velocity, Vector3.ZERO, "fighter %d stands still" % i)
		assert_eq(f.health, f.stats.max_health * UNIT)
		assert_eq(f.ki, _sim.meter_tuning.round_start_ki * UNIT)
		assert_eq(f.guard, f.stats.guard_max * UNIT)
		assert_eq(f.hitstop_ticks, 0)
		assert_eq(f.state_ticks, 0)
		assert_false(f.ko_bounced)
		assert_eq(f.weapon_count(), 0, "weapons are cleared each round")
		assert_eq(f.active_slot, -1)
		assert_eq(f.smitten_ticks, 0)
	assert_eq(fighter.position, Vector3(0, 1, 0), "back at its spawn on the floor")
	assert_eq(fighter.state, State.IDLE)
	assert_eq(_fighter(1).position, Vector3(0, 10, -20), "the KO'd fighter is back in the air")
	assert_eq(_fighter(1).state, State.FLYING)
	assert_eq(fighter.facing_yaw, 0.0, "facing the opponent (-Z)")
	assert_almost_eq(absf(_fighter(1).facing_yaw), PI, 0.001, "facing back (+Z)")
	assert_eq(fighter.burst, burst, "burst carries over")
	assert_eq(_sim.pickups.size(), 0)
	assert_eq(_sim.projectiles.size(), 0)
	assert_eq(_sim.next_spawn_tick, -1, "the spawner starts over")
	assert_false(_sim.round_over)
	assert_eq(_sim.winning_team, -1)


func test_start_round_uses_the_spawn_points_given() -> void:
	_start([Vector3(0, 0, -20)])
	var spawns: Array[Vector3] = [Vector3(5, 0, 5), Vector3(-5, 4, -5)]
	_sim.start_round(spawns)
	assert_eq(_fighter(0).position, Vector3(5, 1, 5))
	assert_eq(_fighter(1).position, Vector3(-5, 4, -5))
	assert_eq(_fighter(1).state, State.FLYING)


func test_start_round_gives_the_same_hash_for_the_same_match() -> void:
	var hashes: Array[int] = []
	for _run in 2:
		_knock_out_in_the_air()
		_tick(50)
		_sim.start_round()
		_tick(20)
		hashes.append(_sim.state_hash())
	assert_eq(hashes[0], hashes[1])


func test_match_flow_starts_round_2_at_the_spawn_points() -> void:
	_start([Vector3(0, 0, -6)], Vector3(0, 0, 6))
	var flow := MatchFlow.new(2)
	flow.phase = MatchFlow.Phase.FIGHT
	_fighter(0).position = Vector3(30, 20, 30)
	_fighter(0).enter_state(State.FLYING)
	_sim.apply_damage(1, 0, 20_000)
	for _i in MatchFlow.KO_TICKS + 2:
		_tick()
		flow.step(_sim)
	assert_eq(flow.round_number, 2)
	assert_eq(flow.wins[0], 1)
	assert_eq(_fighter(0).position, Vector3(0, 1, 6), "fighter 0 back at its start")
	assert_eq(_fighter(1).position, Vector3(0, 1, -6), "fighter 1 back at its start")
	assert_eq(_fighter(1).state, State.IDLE, "up again")


func test_match_flow_passes_its_spawn_points_and_credits_the_whole_team() -> void:
	_start([Vector3(0, 0, -6), Vector3(10, 0, 0)], Vector3(0, 0, 6))
	_fighter(2).team = 0
	var flow := MatchFlow.new(3)
	flow.phase = MatchFlow.Phase.FIGHT
	flow.spawn_points = [Vector3(1, 0, 1), Vector3(2, 0, 2), Vector3(3, 0, 3)]
	_sim.apply_damage(1, 0, 20_000)
	for _i in MatchFlow.KO_TICKS + 2:
		_tick()
		flow.step(_sim)
	assert_eq(flow.wins, [1, 0, 1] as Array[int])
	assert_eq(_fighter(2).position, Vector3(3, 1, 3))


## Fighter 0 knocked out where it stands with velocity, then left to settle.
func _knock_out_with(velocity: Vector3, at := Vector3.ZERO) -> Dictionary:
	_start([Vector3(0, 0, -40)], at)
	_fighter(0).velocity = velocity
	_sim.apply_damage(0, 1, 20_000)
	var highest := -INF
	var farthest := 0.0
	for _i in REST_WITHIN_TICKS:
		_tick()
		var offset := _fighter(0).position - at
		highest = maxf(highest, _fighter(0).position.y)
		farthest = maxf(farthest, Vector2(offset.x, offset.z).length())
	return {"highest": highest, "farthest": farthest}


func test_a_huge_knockout_launch_travels_at_most_the_capped_distance() -> void:
	var seen := _knock_out_with(Vector3(80, 0, 60))
	assert_eq(_fighter(0).state, State.KO_DOWN)
	assert_lte(seen.farthest, _sim.hit_tuning.ko_max_travel + 0.01, "no flight into the next biome")
	assert_gt(seen.farthest, 6.0, "still reads big")


func test_a_huge_upward_knockout_peaks_at_most_the_capped_height() -> void:
	var seen := _knock_out_with(Vector3(0, 60, 5))
	var cap := _sim.tuning.ground_height + _sim.hit_tuning.ko_max_apex
	assert_lte(seen.highest, cap + 0.01, "apex within %.1f m of the stand height" % _sim.hit_tuning.ko_max_apex)
	assert_gt(seen.highest, _sim.tuning.ground_height + 3.0, "still a big pop")
	assert_eq(_fighter(0).state, State.KO_DOWN)


func test_a_knockout_into_the_arena_wall_bounces_back_off_it() -> void:
	_start([Vector3(0, 0, -40)])
	var half := _sim.tuning.arena_half_size
	_fighter(0).position = Vector3(half - 1.0, 5, 0)
	_fighter(0).velocity = Vector3(14, 0, 0)
	_sim.apply_damage(0, 1, 20_000)
	var bounced := false
	for _i in REST_WITHIN_TICKS:
		_tick()
		bounced = bounced or _fighter(0).velocity.x < 0.0
		assert_lte(_fighter(0).position.x, half, "never past the wall")
	assert_true(bounced, "rebounds off the wall instead of sticking to it")
	assert_lt(_fighter(0).position.x, half, "comes to rest off the wall")


func test_state_hash_covers_the_knockout_origin() -> void:
	_start([Vector3(0, 0, -40)])
	var base := _sim.state_hash()
	_fighter(0).ko_origin = Vector3(1, 0, 0)
	assert_ne(_sim.state_hash(), base)
