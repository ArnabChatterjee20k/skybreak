extends QaScenario
## Weapon, power and gadget scenarios: bow pin, tether yank, pickup/switch/throw, drops, gadgets, powers.


func test_a_level_three_bow_arrow_pins_the_target_to_the_wall() -> void:
	var wall := -(CombatSim.DEFAULT_TUNING as MovementTuning).arena_half_size
	start([&"lyra", &"brann"], [Vector3(0, 0, wall + 16.0), Vector3(0, 0, wall + 4.0)])
	arm(K.KI_BOW)
	held[0] = A.LIGHT
	tick(14 + Weapon.DRAW_LEVEL_TICKS[1] + 2)
	assert_eq(fighter(0).draw_level(), 3, "fully drawn")
	held[0] = 0
	tick(30)
	assert_eq(of(seen, E.FIRE).size(), 1)
	assert_eq(of(seen, E.FIRE)[0].level, 3)
	assert_eq(against(seen, E.ARROW_PIN, 1).size(), 1, "pinned")
	var them := fighter(1)
	assert_true(them.pinned)
	var at := them.position
	tick(20)
	assert_almost_eq(them.position, at, Vector3.ONE * 0.1, "stuck to the wall")
	assert_almost_eq(them.position.z, wall, 1.0, "at the wall")
	tick(Weapon.PIN_HOLD_TICKS + 60)
	assert_false(them.pinned, "the pin wears off")
	assert_ne(them.state, S.HITSTUN)


func test_a_heartstring_tether_yanks_the_target_in_for_a_follow_up() -> void:
	start([&"vexa", &"kael"], [Vector3.ZERO, Vector3(0, 0, -10)])
	arm(K.HEARTSTRING_BOW)
	held[0] = A.LIGHT
	tick(16 + Weapon.DRAW_LEVEL_TICKS[1] + 2)
	held[0] = 0
	tick(40)
	assert_eq(of(seen, E.TETHER).size(), 1, "tied")
	assert_eq(fighter(1).tether_partner, 0)
	tap(0, A.HEAVY)
	assert_eq(of(seen, E.TETHER_YANK).size(), 1, "yanked")
	assert_eq(fighter(1).state, S.BLOCKSTUN, "the yanked fighter cannot act")
	tick(Weapon.YANK_TICKS + 1)
	assert_almost_eq(gap(0, 1), Weapon.YANK_DISTANCE, 0.3, "pulled in to striking range")
	assert_eq(fighter(0).tether_partner, -1, "the yank spends the tether")
	forget_events()
	assert_true(tick_until(func() -> bool: return is_free(0), 30))
	tap(0, A.LIGHT)
	assert_true(tick_until(func() -> bool: return not against(seen, E.HIT, 1).is_empty(), 20),
		"a point-blank shot follows up before the target recovers")


func test_pick_up_two_weapons_switch_back_and_throw_one_into_the_opponent() -> void:
	start([&"kael", &"vexa"], [Vector3.ZERO, Vector3(0, 0, -6)])
	var blade := place_weapon(K.STORM_BLADE, Vector3(1.0, 0.6, 0))
	tap(0, A.PICKUP)
	assert_eq(of(seen, E.PICKUP).size(), 1)
	assert_eq(of(seen, E.PICKUP)[0].id, blade.id)
	assert_eq(fighter(0).held_weapon(), K.STORM_BLADE)
	tick(10)
	place_weapon(K.ARC_REVOLVER, Vector3(-1.0, 0.6, 0))
	tap(0, A.PICKUP)
	assert_eq(fighter(0).held_weapon(), K.ARC_REVOLVER, "the new weapon goes in hand")
	assert_eq(fighter(0).weapon_count(), 2, "and the blade is kept")
	tick(40)
	tap(0, A.WEAPON_PREVIOUS)
	assert_eq(of(seen, E.WEAPON_SWITCH).size(), 1)
	assert_eq(fighter(0).held_weapon(), K.STORM_BLADE, "switched back to the blade")
	tick(40)
	var health := fighter(1).health
	tap(0, A.THROW)
	assert_eq(of(seen, E.WEAPON_THROW).size(), 1)
	assert_eq(fighter(0).held_weapon(), K.NONE)
	assert_eq(fighter(0).weapon_count(), 1, "only the revolver left")
	assert_true(tick_until(func() -> bool: return not against(seen, E.PROJECTILE_HIT, 1).is_empty(), 30), "the blade hits")
	assert_lt(fighter(1).health, health)
	tick(60)
	assert_true(sim.pickups.any(func(p: WeaponPickup) -> bool: return p.kind == K.STORM_BLADE), "the blade lies on the floor")


func test_a_knockout_drops_every_weapon_the_loser_carried() -> void:
	start([&"kael", &"brann"], [Vector3.ZERO, Vector3(0, 0, -1.8)])
	arm(K.STORM_BLADE, 1)
	arm(K.SKY_LANCE, 1)
	assert_eq(fighter(1).weapon_count(), 2)
	fighter(1).health = 1
	tap(0, A.LIGHT)
	assert_true(tick_until(func() -> bool: return not of(seen, E.KO).is_empty(), 20), "knocked out")
	assert_eq(against(seen, E.WEAPON_DROP, 1).size(), 2, "both weapons drop")
	assert_eq(fighter(1).weapon_count(), 0)
	var kinds: Array = sim.pickups.map(func(p: WeaponPickup) -> Weapon.Kind: return p.kind)
	assert_has(kinds, K.STORM_BLADE)
	assert_has(kinds, K.SKY_LANCE)


func test_a_thrown_spike_bomb_explodes_on_the_opponent_and_launches_it() -> void:
	start([&"vexa", &"kael"], [Vector3.ZERO, Vector3(0, 0, -8)])
	place_power(P.SPIKE_BOMB, fighter(0).position + Vector3(0, -0.4, 0))
	tap(0, A.PICKUP)
	tick(10)
	assert_eq(fighter(0).powers.gadget, P.SPIKE_BOMB, "the gadget is held")
	var health := fighter(1).health
	tap(0, A.PICKUP)
	assert_eq(of(seen, E.GADGET_THROW).size(), 1)
	tick(30)
	assert_eq(of(seen, E.GADGET_EXPLODE).size(), 1)
	var hits := against(seen, E.HIT, 1)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].knockback_type, MoveData.KnockbackType.LAUNCH)
	assert_lt(fighter(1).health, health)
	assert_eq(fighter(0).health, fighter(0).stats.max_health * UNIT, "spares its owner")


func test_an_aegis_pickup_absorbs_the_next_hit_then_the_one_after_lands() -> void:
	start([&"kael", &"lyra"], [Vector3.ZERO, Vector3(0, 0, -1.6)])
	place_power(P.AEGIS, fighter(1).position + Vector3(0, -0.4, 0))
	tap(1, A.PICKUP)
	assert_eq(against(seen, E.POWER_PICKUP, 1).size(), 1)
	assert_true(fighter(1).powers.aegis)
	tick(10)
	var health := fighter(1).health
	tap(0, A.LIGHT)
	tick(20)
	assert_eq(of(seen, E.AEGIS_BREAK).size(), 1)
	assert_eq(against(seen, E.HIT, 1).size(), 0, "absorbed")
	assert_eq(fighter(1).health, health)
	assert_false(fighter(1).powers.aegis)
	tap(0, A.LIGHT)
	tick(20)
	assert_eq(against(seen, E.HIT, 1).size(), 1, "the next hit lands")
	assert_lt(fighter(1).health, health)
