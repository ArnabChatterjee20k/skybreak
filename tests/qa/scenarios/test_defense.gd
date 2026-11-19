extends QaScenario
## Defense scenarios: perfect block and punish, grabs and techs, guard breaks, counters, armour, star-step.

## Ticks before a strike's first active tick that a perfect-block tap comes (as the tutorial autopilot).
const PERFECT_BLOCK_LEAD := 3


func test_a_perfect_block_then_a_light_punishes_the_attacker_in_its_recovery() -> void:
	start([&"kael", &"vexa"], [Vector3.ZERO, Vector3(0, 0, -2)])
	tick(10)
	tap(0, A.LIGHT)
	var light := fighter(0).move
	assert_true(tick_until(func() -> bool: return fighter(0).move_tick == light.startup_ticks - PERFECT_BLOCK_LEAD, 20))
	tap(1, A.BLOCK)
	assert_true(tick_until(func() -> bool: return not of(seen, E.PERFECT_BLOCK).is_empty(), 10), "perfect block")
	assert_eq(fighter(1).health, fighter(1).stats.max_health * UNIT, "no damage")
	assert_eq(fighter(1).guard, fighter(1).stats.guard_max * UNIT, "no guard lost")
	tick(sim.hit_tuning.perfect_block_hitstop_ticks)
	forget_events()
	tap(1, A.LIGHT)
	assert_true(tick_until(func() -> bool: return not against(seen, E.HIT, 0).is_empty(), 15), "the punish lands")
	assert_eq(fighter(0).state, S.HITSTUN)
	assert_eq(of(seen, E.HIT)[0].attacker, 1)


func test_a_grab_teched_in_time_pushes_both_apart_without_damage() -> void:
	start([&"kael", &"vexa"], [Vector3.ZERO, Vector3(0, 0, -1.5)])
	tick(5)
	tap(0, A.GRAB)
	assert_true(tick_until(func() -> bool: return not of(seen, E.GRAB).is_empty(), 20), "the grab connects")
	assert_eq(fighter(1).state, S.GRABBED)
	tick(4)
	tap(1, A.GRAB)
	assert_eq(of(seen, E.GRAB_TECH).size(), 1, "teched")
	assert_eq(of(seen, E.THROW).size(), 0)
	tick(sim.hit_tuning.grab_tech_push_ticks + 2)
	assert_almost_eq(gap(0, 1), sim.hit_tuning.grab_tech_distance, 0.1)
	assert_eq(fighter(0).health, fighter(0).stats.max_health * UNIT)
	assert_eq(fighter(1).health, fighter(1).stats.max_health * UNIT)
	assert_true(is_free(0) and is_free(1), "both free again")


func test_a_grab_teched_too_late_ends_in_a_throw() -> void:
	start([&"kael", &"vexa"], [Vector3.ZERO, Vector3(0, 0, -1.5)])
	tick(5)
	tap(0, A.GRAB)
	assert_true(tick_until(func() -> bool: return not of(seen, E.GRAB).is_empty(), 20))
	tick(sim.hit_tuning.grab_tech_ticks + 1)
	tap(1, A.GRAB)
	assert_true(tick_until(func() -> bool: return not of(seen, E.THROW).is_empty(), 60), "thrown")
	assert_eq(of(seen, E.GRAB_TECH).size(), 0)
	assert_lt(fighter(1).health, fighter(1).stats.max_health * UNIT, "the throw hurts")


func test_blocking_strike_after_strike_breaks_the_guard_and_the_next_hit_lands() -> void:
	start([&"kael", &"vexa"], [Vector3.ZERO, Vector3(0, 0, -1.8)])
	held[1] = A.BLOCK
	tick(5)
	var broke := false
	for _i in 2400:
		if is_free(0):
			tap(0, A.HEAVY)
		else:
			tick()
		if not of(seen, E.GUARD_BREAK).is_empty():
			broke = true
			break
		# Keep spacing: the smash steps in, and without pushboxes it ends inside the blocker.
		moves[0] = FORWARD if planar_gap(0, 1) > 1.8 else (BACK if planar_gap(0, 1) < 1.3 else Vector2.ZERO)
	assert_true(broke, "the guard breaks")
	assert_eq(fighter(1).guard, 0)
	moves[0] = Vector2.ZERO
	assert_true(tick_until(func() -> bool: return fighter(1).state == S.GUARD_BROKEN, 30))
	assert_true(tick_until(func() -> bool: return is_free(0), 60))
	forget_events()
	# Space out to striking range first (the last strike ended on top of the defender).
	moves[0] = BACK if planar_gap(0, 1) < 1.0 else FORWARD
	tick_until(func() -> bool: return planar_gap(0, 1) >= 1.0 and planar_gap(0, 1) <= 1.6, 30)
	moves[0] = Vector2.ZERO
	assert_eq(fighter(1).state, S.GUARD_BROKEN, "still reeling")
	tap(0, A.LIGHT)
	assert_true(tick_until(func() -> bool: return not against(seen, E.HIT, 1).is_empty(), 15),
		"a guard-broken fighter is hit even while holding block")


func test_a_light_into_a_heavy_startup_is_a_counter_hit_and_stops_the_heavy() -> void:
	start([&"kael", &"vexa"], [Vector3.ZERO, Vector3(0, 0, -1.8)])
	tick(5)
	tap(1, A.HEAVY)
	tick(2)
	assert_eq(fighter(1).attack_phase(), FighterState.AttackPhase.STARTUP)
	tap(0, A.LIGHT)
	assert_true(tick_until(func() -> bool: return not seen.is_empty(), 15))
	var counters := against(seen, E.COUNTER, 1)
	assert_eq(counters.size(), 1, "a counter hit")
	if counters.size() == 1:
		assert_true(counters[0].counter)
		assert_eq(counters[0].hitstop, fighter(0).stats.move_set.light_string[0].hitstop_ticks
			+ sim.hit_tuning.counter_hit_extra_hitstop_ticks)
	assert_eq(fighter(1).state, S.HITSTUN)
	tick(40)
	assert_eq(against(seen, E.HIT, 0).size(), 0, "the interrupted heavy never lands")


func test_brann_armour_absorbs_a_light_and_his_smash_still_lands() -> void:
	start([&"brann", &"kael"], [Vector3.ZERO, Vector3(0, 0, -1.8)])
	tick(5)
	var health := fighter(0).health
	tap(0, A.HEAVY)
	var smash := fighter(0).move
	assert_eq(smash, fighter(0).stats.move_set.smash)
	assert_gt(smash.armor_end_tick, smash.armor_start_tick, "the smash has armour")
	assert_true(tick_until(func() -> bool: return fighter(0).move_tick == smash.armor_start_tick + 1, 20))
	tap(1, A.LIGHT)
	assert_true(tick_until(func() -> bool: return not against(seen, E.ARMOR, 0).is_empty(), 15), "the light hits armour")
	assert_eq(against(seen, E.HIT, 0).size(), 0, "no stun on Brann")
	assert_lt(fighter(0).health, health, "armour still takes the damage")
	assert_eq(fighter(0).state, S.ATTACKING)
	assert_eq(fighter(0).move, smash, "the smash goes on")
	assert_true(tick_until(func() -> bool: return not against(seen, E.HIT, 1).is_empty(), 40), "and lands")
	assert_eq(against(seen, E.HIT, 1)[0].move_id, smash.id)


## Kael fires a level-one bow shot at Lyra 12 m away; with star_step she star-steps as it closes in.
func _shot_at_lyra(star_step: bool) -> Array:
	start([&"kael", &"lyra"], [Vector3.ZERO, Vector3(0, 0, -12)])
	arm(K.KI_BOW)
	forget_events()
	tap(0, A.LIGHT)
	var stepped := false
	for _i in 60:
		var arrow: Projectile = null
		for projectile in sim.projectiles:
			if projectile.owner == 0:
				arrow = projectile
		if star_step and arrow != null and not stepped and is_free(1):
			var ticks_away := (arrow.position.distance_to(fighter(1).position) - 0.6) \
				/ (arrow.velocity.length() / CombatSim.TICKS_PER_SECOND)
			if ticks_away <= 2.0:
				moves[1] = BACK
				tap(1, A.HEAVY)
				moves[1] = Vector2.ZERO
				stepped = true
				assert_eq(fighter(1).move_id(), &"launcher", "the star-step")
				continue
		tick()
	assert_eq(of(seen, E.FIRE).size(), 1)
	return against(seen, E.HIT, 1)


func test_lyra_star_step_passes_through_an_arrow() -> void:
	assert_eq(_shot_at_lyra(false).size(), 1, "standing still, the arrow hits")
	assert_eq(_shot_at_lyra(true).size(), 0, "star-stepping, it passes through")
	assert_eq(against(seen, E.PROJECTILE_HIT, 1).size(), 0)
