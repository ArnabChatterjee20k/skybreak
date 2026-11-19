extends QaScenario
## Round scenarios: knockouts, the next round, the clock, grey health, free-for-all.

const SPAWNS: Array[Vector3] = [Vector3(0, 0, 6), Vector3(0, 0, -6)]
const ISLAND_HALF := 10.0
const ISLAND_TOP := 6.0

var flow: MatchFlow


## Ticks the sim and then the match flow, as a level's _physics_process does.
func flow_tick(ticks := 1) -> void:
	for _i in ticks:
		if not flow.accepts_input():
			held.fill(0)
		tick()
		flow.step(sim)


func _island(x: float, z: float, y: float) -> float:
	if absf(x) <= ISLAND_HALF and absf(z) <= ISLAND_HALF and y >= ISLAND_TOP - 0.5:
		return ISLAND_TOP
	return 0.0


func test_a_knockout_in_the_air_falls_bounces_rests_then_round_two_starts_at_the_spawns() -> void:
	start([&"kael", &"vexa"], [Vector3(0, 8, 0), Vector3(0, 8, -2)])
	flow = MatchFlow.new(2)
	flow.spawn_points = SPAWNS
	flow.phase = MatchFlow.Phase.FIGHT
	fighter(1).health = 1
	tap(0, A.LIGHT)
	flow.step(sim)
	assert_true(tick_until(func() -> bool: return not of(seen, E.KO).is_empty(), 20), "knocked out")
	flow.step(sim)
	assert_eq(flow.phase, MatchFlow.Phase.KO)
	assert_eq(flow.wins, [1, 0] as Array[int])
	for _i in 240:
		flow_tick()
		if fighter(1).state == S.KO_DOWN:
			break
	var order: Array = seen.filter(func(e: Dictionary) -> bool: return e.get("fighter", -1) == 1) \
		.map(func(e: Dictionary) -> int: return e.type)
	assert_eq(order.filter(func(t: int) -> bool: return t in [E.KO_BOUNCE, E.KO_REST]), [E.KO_BOUNCE, E.KO_REST],
		"one bounce, then rest")
	assert_eq(fighter(1).state, S.KO_DOWN)
	assert_almost_eq(fighter(1).position.y, sim.tuning.ground_height, 0.01, "lying on the floor")
	assert_true(tick_until(func() -> bool:
		flow.step(sim)
		return flow.round_number == 2, MatchFlow.KO_TICKS + 10), "round two")
	for index in 2:
		assert_eq(fighter(index).position, SPAWNS[index] + Vector3(0, sim.tuning.ground_height, 0), "back at its spawn")
		assert_eq(fighter(index).state, S.IDLE)
		assert_eq(fighter(index).health, fighter(index).stats.max_health * UNIT)
	assert_false(sim.round_over)
	assert_eq(flow.phase, MatchFlow.Phase.INTRO)
	flow_tick(MatchFlow.INTRO_TICKS)
	assert_eq(flow.phase, MatchFlow.Phase.FIGHT, "fight on")
	assert_true(flow.accepts_input())


func test_a_knockout_on_a_raised_island_rests_on_the_island_top() -> void:
	if known_issue(&"QA-1", "KO bounce/rest snap to the flat floor height and ignore sim.ground_height"):
		return
	start([&"kael", &"vexa"], [Vector3(0, ISLAND_TOP + 1.0, 0), Vector3(0, ISLAND_TOP + 1.0, -1.8)])
	sim.ground_height = _island
	tick()
	var top := sim.tuning.ground_height + ISLAND_TOP
	assert_almost_eq(fighter(1).position.y, top, 0.01, "standing on the island")
	fighter(1).health = 1
	tap(0, A.LIGHT)
	assert_true(tick_until(func() -> bool: return fighter(1).state == S.KO_DOWN, 240), "comes to rest")
	assert_eq(against(seen, E.KO_BOUNCE, 1).size(), 1)
	assert_almost_eq(fighter(1).position.y, top, 0.05, "lies on the island, not inside it")


func test_the_round_clock_running_out_gives_the_round_to_the_healthier_fighter() -> void:
	start([&"lyra", &"brann"], [Vector3.ZERO, Vector3(0, 0, -1.6)])
	flow = MatchFlow.new(2)
	flow.phase = MatchFlow.Phase.FIGHT
	flow.timer_ticks = 90
	tap(0, A.LIGHT)
	flow.step(sim)
	assert_true(tick_until(func() -> bool: return not of(seen, E.HIT).is_empty(), 20))
	held[0] = 0
	while flow.phase == MatchFlow.Phase.FIGHT and sim.current_tick < 200:
		flow_tick()
	assert_eq(flow.phase, MatchFlow.Phase.KO)
	assert_true(flow.timed_out, "time out, not a knockout")
	assert_eq(flow.last_winner, 0)
	assert_eq(flow.wins, [1, 0] as Array[int])
	assert_eq(flow.banner(["LYRA", "BRANN"]).title, "TIME!")
	assert_false(sim.round_over, "nobody was knocked out")


func test_grey_health_from_a_combo_regenerates_after_a_quiet_spell() -> void:
	start([&"vexa", &"kael"], [Vector3.ZERO, Vector3(0, 0, -1.5)])
	tap(0, A.LIGHT)
	for _i in 40:
		if in_string_window(0):
			tap(0, A.LIGHT)
		else:
			tick()
	assert_gte(against(seen, E.HIT, 1).size(), 2, "a two-hit combo")
	tick_until(func() -> bool: return fighter(1).state != S.HITSTUN, 60)
	var them := fighter(1)
	var grey := them.grey_health
	var health := them.health
	assert_gt(grey, 0, "part of the damage is grey")
	tick(sim.meter_tuning.grey_regen_delay_ticks - 20)
	assert_eq(them.health, health, "nothing back before the delay")
	tick(20 + CombatSim.TICKS_PER_SECOND)
	assert_gt(them.health, health, "health comes back")
	assert_lte(them.health, health + grey, "only the grey part")
	assert_lt(them.grey_health, grey)


func test_a_four_fighter_free_for_all_ends_with_the_last_one_standing() -> void:
	var bout := AIBout.new(31, [4, 4, 4, 4])
	sim = bout.sim
	for each in sim.fighters:
		each.health = 1500 * UNIT
	var events: Array[Dictionary] = []
	while bout.ticks < 20_000 and not sim.round_over:
		bout.step()
		events.append_array(sim.events)
	assert_true(sim.round_over, "decided by knockouts")
	var knocked: Array = of(events, E.KO).map(func(e: Dictionary) -> int: return e.target)
	assert_eq(knocked.size(), 3, "three knockouts")
	var winner := sim.round_winner
	assert_between(winner, 0, 3)
	assert_does_not_have(knocked, winner)
	assert_false(sim.fighters[winner].is_knocked_out())
	for index in 4:
		if index != winner:
			assert_true(sim.fighters[index].is_knocked_out(), "fighter %d is out" % index)
	gut.p("FFA: winner %d after %d ticks" % [winner, bout.ticks])
