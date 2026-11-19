extends QaScenario
## Light string, launcher, vanish follow-up, air light, spike: the full air route on every legend.

## The route ends this long after the start at most.
const ROUTE_TICKS := 400
## Air lights before the spike.
const AIR_STRING := 2


## Plays the route against an idle Kael standing gap metres ahead and checks every link.
func _air_route(legend: StringName, gap_metres := 1.5) -> void:
	start([legend, &"kael"], [Vector3.ZERO, Vector3(0, 0, -gap_metres)])
	fighter(0).ki = sim.meter_tuning.ki_max * UNIT
	var me := fighter(0)
	var them := fighter(1)
	var kit := me.stats.move_set
	var stage := 0
	var deepest_combo := 0
	var bounced := false
	tap(0, A.LIGHT)
	for _i in ROUTE_TICKS:
		deepest_combo = maxi(deepest_combo, them.combo_hits)
		match stage:
			0: # Ground string: a second light in rhythm, then cancel into the launcher.
				moves[0] = Vector2.ZERO
				if me.string_index >= 2 and me.contact_hit and me.hitstop_ticks == 0 and sim.can_cancel_into(0, MoveData.CancelLevel.HEAVY):
					moves[0] = BACK
					tap(0, A.HEAVY)
					stage = 1
					continue
				if me.string_index == 1 and in_string_window(0):
					tap(0, A.LIGHT)
					continue
			1: # Launcher hit: vanish along with the target.
				if me.move == kit.launcher and me.contact_hit \
						and sim.can_cancel_into(0, MoveData.CancelLevel.VANISH) and them.state == S.HITSTUN:
					# A star-step leaves Lyra far off: vanish toward the target instead of beside it.
					moves[0] = FORWARD if planar_gap(0, 1) > 3.0 else Vector2.ZERO
					held[0] = A.DASH | A.BLOCK
					stage = 2
			2: # Free in the air beside the target: match its height, close in, light.
				if me.state != S.ATTACKING:
					held[0] = 0
				if me.state == S.VANISHING:
					moves[0] = Vector2.ZERO
				if is_free(0):
					var ahead := them.position
					ahead.y = _height_at_hit(them, kit.light_string[0].startup_ticks)
					var rise := ahead.y - me.position.y
					verticals[0] = 0 if absf(rise) < 0.3 else (1 if rise > 0.0 else -1)
					moves[0] = FORWARD if planar_gap(0, 1) > 1.2 else Vector2.ZERO
					if me.position.distance_to(ahead) <= 1.8:
						moves[0] = Vector2.ZERO
						verticals[0] = 0
						tap(0, A.LIGHT)
						stage = 3
						continue
			3: # An air string of up to two lights, then cancel into the spike.
				if is_free(0) and not me.contact_hit:
					stage = 2
				var goal := _air_goal(kit)
				if me.string_index < goal and me.contact_hit and me.hitstop_ticks == 0 and not me.string_queued \
						and me.move_tick > me.move.string_window_start_tick:
					tap(0, A.LIGHT)
					continue
				if me.string_index >= goal and me.contact_hit and me.hitstop_ticks == 0 \
						and sim.can_cancel_into(0, MoveData.CancelLevel.HEAVY):
					verticals[0] = -1
					tap(0, A.HEAVY)
					stage = 4
					continue
			4:
				if me.move == kit.spike:
					verticals[0] = 0
				bounced = bounced or them.spike_bounced
				if them.state == S.KNOCKDOWN:
					break
		tick()
	deepest_combo = maxi(deepest_combo, them.combo_hits)
	gut.p("%s: combo %d, hits %s" % [legend, deepest_combo,
		move_ids(of(seen, E.HIT).filter(func(e: Dictionary) -> bool: return e.attacker == 0))])
	_check_route(kit, deepest_combo, bounced)


## Air lights before the spike: up to two, never the string's ender (it knocks the target away).
func _air_goal(kit: MoveSet) -> int:
	return mini(AIR_STRING, kit.light_string.size() - 1)


## Where the target will be, height-wise, after ticks of juggle gravity.
func _height_at_hit(them: FighterState, ticks: int) -> float:
	if them.state != S.HITSTUN:
		return them.position.y
	var seconds := float(ticks) / CombatSim.TICKS_PER_SECOND
	return them.position.y + them.velocity.y * seconds - 0.5 * sim.hit_tuning.juggle_gravity * seconds * seconds


func _check_route(kit: MoveSet, deepest_combo: int, bounced: bool) -> void:
	var hits := of(seen, E.HIT).filter(func(e: Dictionary) -> bool: return e.attacker == 0)
	var ids := move_ids(hits)
	assert_has(ids, kit.light_string[0].id, "the first light lands")
	assert_has(ids, kit.light_string[1].id, "the second light lands")
	assert_has(ids, kit.launcher.id, "the launcher lands")
	assert_has(ids, kit.spike.id, "the spike lands")
	var launched_at := ids.find(kit.launcher.id)
	var spiked_at := ids.find(kit.spike.id)
	assert_gt(spiked_at, launched_at + 1, "an air hit between launcher and spike")
	if launched_at >= 0 and spiked_at > launched_at + 1:
		var air_hit: Dictionary = hits[launched_at + 1]
		assert_gt(air_hit.position.y, 2.5, "the follow-up connects in the air")
	assert_gte(deepest_combo, 4 + _air_goal(kit), "one unbroken combo, launcher to spike")
	assert_true(bounced, "the spike slams it off the floor")
	assert_false(fighter(0).is_knocked_out())


func test_kael_lands_lights_launcher_air_light_and_spike_as_one_combo() -> void:
	_air_route(&"kael")


func test_vexa_lands_lights_launcher_air_light_and_spike_as_one_combo() -> void:
	_air_route(&"vexa")


func test_lyra_lands_lights_launcher_air_light_and_spike_as_one_combo() -> void:
	if not QaKnownIssues.has_pushboxes() and known_issue(&"T-D29",
			"after the star-step a vanish toward Lyra's target ends inside it, her air lights step through it and the spike whiffs"):
		return
	_air_route(&"lyra")


func test_brann_lands_lights_launcher_air_light_and_spike_as_one_combo() -> void:
	_air_route(&"brann")
