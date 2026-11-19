extends QaScenario
## Movement scenarios: dashes against a body, vanishing behind a guard, islands and walls.

## Half the island's width and depth, and its top height (T-D13 style ground).
const ISLAND_HALF := 10.0
const ISLAND_TOP := 6.0


## A raised island around the origin over flat ground: anything above its top stands on it.
func _island(x: float, z: float, y: float) -> float:
	if absf(x) <= ISLAND_HALF and absf(z) <= ISLAND_HALF and y >= ISLAND_TOP - 0.5:
		return ISLAND_TOP
	return 0.0


func test_a_dash_into_an_opponent_stops_at_contact_without_passing_through() -> void:
	if not QaKnownIssues.has_pushboxes() and known_issue(&"T-D29", "dash passes through"):
		return
	start([&"kael", &"vexa"], [Vector3.ZERO, Vector3(0, 0, -3)])
	fighter(0).lock_on_target = -1
	var bodies := fighter(0).stats.hurtbox_radius + fighter(1).stats.hurtbox_radius
	var closest := INF
	var passed := false
	held[0] = A.DASH
	moves[0] = FORWARD
	for _i in 30:
		tick()
		closest = minf(closest, planar_gap(0, 1))
		passed = passed or fighter(0).position.z < fighter(1).position.z
	assert_false(passed, "the dash never ends up on the far side")
	assert_gte(closest, bodies - 0.05, "bodies touch but do not overlap")


func test_a_locked_rush_brakes_in_front_of_the_opponent() -> void:
	start([&"kael", &"vexa"], [Vector3.ZERO, Vector3(0, 0, -20)])
	moves[0] = FORWARD
	tap(0, A.DASH)
	moves[0] = Vector2.ZERO
	assert_eq(fighter(0).dash_kind, FighterState.DashKind.RUSH)
	var passed := false
	for _i in 60:
		tick()
		passed = passed or fighter(0).position.z < fighter(1).position.z
	assert_false(passed)
	assert_almost_eq(gap(0, 1), sim.tuning.rush_stop_distance, 0.3, "stops at rush distance")
	assert_true(is_free(0), "ready for a follow-up")


func test_a_vanish_behind_an_unturned_blocker_lands_a_light_through_its_guard() -> void:
	start([&"kael", &"vexa"], [Vector3.ZERO, Vector3(0, 0, -4.4)])
	fighter(0).ki = sim.meter_tuning.ki_max * UNIT
	tick()
	# Guarding toward the attacker without tracking it.
	fighter(1).lock_on_target = -1
	held[1] = A.BLOCK
	tick(10)
	assert_eq(fighter(1).state, S.BLOCKING)
	moves[0] = FORWARD
	held[0] = A.DASH | A.BLOCK
	tick()
	held[0] = 0
	moves[0] = Vector2.ZERO
	assert_eq(fighter(0).state, S.VANISHING)
	assert_true(tick_until(func() -> bool: return is_free(0), 30))
	assert_lt(fighter(0).position.z, fighter(1).position.z, "reappears behind the blocker")
	assert_lt(planar_gap(0, 1), 2.0, "in striking range")
	forget_events()
	tap(0, A.LIGHT)
	tick_until(func() -> bool: return not seen.is_empty(), 20)
	assert_eq(against(seen, E.HIT, 1).size(), 1, "the light lands from behind")
	assert_eq(against(seen, E.BLOCK, 1).size(), 0, "not blocked")


func test_walking_off_a_raised_island_falls_then_ascend_takes_flight() -> void:
	start([&"kael", &"vexa"], [Vector3(0, ISLAND_TOP + 1.0, 0), Vector3(150, 1, 150)])
	sim.ground_height = _island
	fighter(0).lock_on_target = -1
	tick()
	assert_eq(fighter(0).state, S.IDLE, "standing on the island")
	assert_almost_eq(fighter(0).position.y, sim.tuning.ground_height + ISLAND_TOP, 0.01)
	moves[0] = FORWARD
	assert_true(tick_until(func() -> bool: return fighter(0).state == S.FALLING, 300), "walks off the rim")
	assert_lt(fighter(0).position.z, -ISLAND_HALF, "off the island")
	var rim_height := fighter(0).position.y
	tick(10)
	assert_eq(fighter(0).state, S.FALLING)
	assert_lt(fighter(0).position.y, rim_height - 0.3, "gravity pulls it down")
	verticals[0] = 1
	tick()
	assert_eq(fighter(0).state, S.FLYING, "ascend takes back flight")
	var caught := fighter(0).position.y
	tick(30)
	assert_eq(fighter(0).state, S.FLYING)
	assert_gt(fighter(0).position.y, caught, "climbs back up")
	assert_gt(fighter(0).position.y, sim.tuning.ground_height + 2.0, "never reached the low ground")


func test_a_push_block_into_the_arena_wall_stops_the_attacker_at_the_wall() -> void:
	var wall := -sim_half()
	start([&"kael", &"vexa"], [Vector3(0, 0, wall + 1.0), Vector3(0, 0, wall + 2.6)])
	held[1] = A.BLOCK
	tick(10)
	tap(0, A.LIGHT)
	assert_true(tick_until(func() -> bool: return not of(seen, E.BLOCK).is_empty(), 20), "the light is blocked")
	tick(sim.hit_tuning.push_block_from_blockstun_tick)
	tap(1, A.HEAVY)
	assert_true(tick_until(func() -> bool: return not of(seen, E.PUSH_BLOCK).is_empty(), 20), "push-block lands")
	for _i in sim.hit_tuning.push_block_stun_ticks + 5:
		tick()
		assert_gte(fighter(0).position.z, wall - 0.001, "never through the wall")
	assert_almost_eq(fighter(0).position.z, wall, 0.01, "pinned against the wall")
	assert_lt(gap(0, 1), sim.hit_tuning.push_block_distance, "the wall cut the push short")
	assert_true(is_free(0), "recovers at the wall")


func test_a_blowback_into_the_arena_wall_stops_the_target_at_the_wall() -> void:
	var wall := -sim_half()
	start([&"kael", &"vexa"], [Vector3(0, 0, wall + 4.0), Vector3(0, 0, wall + 1.0)])
	moves[0] = FORWARD
	tap(0, A.HEAVY)
	moves[0] = Vector2.ZERO
	assert_eq(fighter(0).move_id(), fighter(0).stats.move_set.breaker.id)
	assert_true(tick_until(func() -> bool: return not against(seen, E.HIT, 1).is_empty(), 40), "the breaker lands")
	for _i in 60:
		tick()
		assert_gte(fighter(1).position.z, wall - 0.001, "never through the wall")
	assert_almost_eq(fighter(1).position.z, wall, 0.01, "stopped at the wall")


## The default arena's half size; the tests start the sim afterwards.
func sim_half() -> float:
	return (CombatSim.DEFAULT_TUNING as MovementTuning).arena_half_size
