extends GutTest
## T-D27: pooled VFX layer. Event and state mappings, spawn/despawn, bounded pools.

const E := CombatSim.EventType
const S := FighterState.State
const TICK := 1.0 / 60.0


func _event(type: int, hitstop: int = 4, move_id: StringName = &"light_1") -> Dictionary:
	return {"type": type, "attacker": 0, "target": 1, "position": Vector3(0, 2, -3),
		"hitstop": hitstop, "move_id": move_id}


func _vfx_with_sim(zone: StringName = &"skyhold_ruins") -> MatchVfx:
	var sim := CombatSim.new(7)
	sim.zone = zone
	sim.add_fighter(Vector3(0, 1, 6))
	sim.add_fighter(Vector3(0, 1, -6))
	var vfx := MatchVfx.new()
	vfx.sim = sim
	add_child_autofree(vfx)
	var none: Array[Dictionary] = []
	vfx.react(none)
	return vfx


func _react(vfx: MatchVfx, events: Array[Dictionary] = []) -> void:
	vfx.react(events)


func test_light_hits_add_nothing_on_top_of_the_feedback_spark() -> void:
	assert_eq(MatchVfx.effects_for(_event(E.HIT, 4), &"skyhold_ruins"), [] as Array[StringName])
	assert_eq(MatchVfx.screen_for(_event(E.HIT, 4)), &"")


func test_plain_heavies_add_nothing_and_only_heavy_counters_or_long_combo_enders_earn_an_impact_frame() -> void:
	for type in [E.HIT, E.THROW]:
		assert_eq(MatchVfx.effects_for(_event(type, 8), &""), [] as Array[StringName], "#77: the heavy spark is enough")
		assert_eq(MatchVfx.screen_for(_event(type, 8)), &"")
		assert_eq(MatchVfx.screen_for(_event(type, 8), ImpactFrameGate.LONG_COMBO), &"impact")
	assert_eq(MatchVfx.effects_for(_event(E.COUNTER, 4), &""), [&"anime_burst"] as Array[StringName])
	assert_eq(MatchVfx.screen_for(_event(E.COUNTER, 4)), &"", "a light counter")
	assert_eq(MatchVfx.screen_for(_event(E.COUNTER, 9)), &"impact")


func test_guard_break_shatters_with_burst_lines() -> void:
	assert_eq(MatchVfx.effects_for(_event(E.GUARD_BREAK, 14), &""), [&"guard_shatter"] as Array[StringName])
	assert_eq(MatchVfx.screen_for(_event(E.GUARD_BREAK, 14)), &"lines")


func test_ko_gets_the_finisher_and_lightning_only_in_stormfall() -> void:
	assert_eq(MatchVfx.effects_for(_event(E.KO, 20), &"skyhold_ruins"), [&"ko_dome"] as Array[StringName])
	assert_eq(MatchVfx.effects_for(_event(E.KO, 20), &"stormfall_city"), [&"ko_dome", &"lightning"] as Array[StringName])
	assert_eq(MatchVfx.screen_for(_event(E.KO, 20)), &"ko")


func test_heartbloom_hits_sparkle_and_heavy_ones_shed_petals() -> void:
	var light := MatchVfx.effects_for(_event(E.HIT, 4), &"heartbloom_gardens")
	var heavy := MatchVfx.effects_for(_event(E.HIT, 8), &"heartbloom_gardens")
	assert_eq(light, [&"sparkles"] as Array[StringName])
	assert_true(heavy.has(&"petals") and heavy.has(&"sparkles") and not heavy.has(&"anime_burst"))
	assert_false(MatchVfx.effects_for(_event(E.BLOCK, 4), &"heartbloom_gardens").has(&"sparkles"), "blocks are not hits")


func test_ki_blast_and_beam_hits_get_a_blast_impact() -> void:
	for id in [&"ki_blast", &"charged_blast", &"beam_kamehame"]:
		assert_true(MatchVfx.effects_for(_event(E.HIT, 4, id), &"").has(&"blast_impact"), id)


func test_other_events_play_no_extra_world_effect() -> void:
	for type in [E.BLOCK, E.ARMOR, E.PERFECT_BLOCK, E.GRAB, E.GRAB_TECH, E.PUSH_BLOCK, E.PICKUP, E.FIRE]:
		assert_true(MatchVfx.effects_for(_event(type, 8), &"").is_empty(), E.find_key(type))
		assert_eq(MatchVfx.screen_for(_event(type, 8)), &"", E.find_key(type))


func test_every_melee_weapon_has_its_own_smear_and_ranged_ones_none() -> void:
	var seen := {}
	for kind in Weapon.MELEE:
		var smear := MatchVfx.smear_for(kind, &"x/light_1")
		assert_ne(smear, &"", Weapon.Kind.find_key(kind))
		seen[smear] = true
	assert_eq(seen.size(), Weapon.MELEE.size(), "one style per weapon class")
	for kind in [Weapon.Kind.KI_BOW, Weapon.Kind.ARC_REVOLVER, Weapon.Kind.STORM_REPEATER, Weapon.Kind.SCATTER_CANNON]:
		assert_eq(MatchVfx.smear_for(kind, &"x/fire"), &"")


func test_unarmed_smears_only_on_heavies() -> void:
	assert_eq(MatchVfx.smear_for(Weapon.Kind.NONE, &"light_2"), &"")
	assert_eq(MatchVfx.smear_for(Weapon.Kind.NONE, &"grab"), &"")
	assert_eq(MatchVfx.smear_for(Weapon.Kind.NONE, &"smash"), &"smear_fist")


func test_launchers_sweep_up_and_spikes_sweep_down() -> void:
	var up := MatchVfx.swing_tilt(&"launcher", 0) * Vector3.RIGHT
	var down := MatchVfx.swing_tilt(&"spike", 0) * Vector3.RIGHT
	assert_lt(up.y, -0.9, "the swing starts low")
	assert_gt(down.y, 0.9, "the swing starts high")


func test_landing_dust_differs_by_zone() -> void:
	var colors := {}
	for zone: StringName in MatchVfx.ZONE_GROUND:
		colors[MatchVfx.ground_for(zone)[0]] = true
	assert_eq(colors.size(), MatchVfx.ZONE_GROUND.size())
	assert_eq(MatchVfx.ground_for(&"heartbloom_gardens")[2], &"petals")
	assert_eq(MatchVfx.ground_for(&"unknown"), MatchVfx.ground_for(&"skyhold_ruins"))


func test_every_effect_spawns_plays_and_despawns() -> void:
	var vfx := _vfx_with_sim()
	for kind in VfxCatalog.kinds():
		var effect := vfx.spawn(kind, Vector3(1, 2, 3))
		assert_true(effect.is_playing() and effect.visible, kind)
		assert_false(effect.meshes().is_empty() and effect.particles().is_empty(), "%s draws something" % kind)
		for i in int(effect.lifetime / TICK) + 2:
			effect.advance(TICK)
		assert_false(effect.is_playing() or effect.visible, "%s despawned" % kind)


func test_pools_recycle_the_oldest_and_never_grow_past_capacity() -> void:
	var vfx := _vfx_with_sim()
	var pool := vfx.pool(&"afterimage")
	var first := vfx.spawn(&"afterimage", Vector3.ZERO)
	for i in pool.capacity * 3:
		vfx.spawn(&"afterimage", Vector3.ZERO)
	assert_eq(pool.size(), pool.capacity)
	assert_true(first.is_playing(), "the oldest got restarted, not leaked")


func test_react_plays_the_ko_finisher_and_screen_pop() -> void:
	var vfx := _vfx_with_sim(&"stormfall_city")
	var events: Array[Dictionary] = [_event(E.KO, 20)]
	vfx.react(events)
	assert_eq(vfx.pool(&"ko_dome").playing_count(), 1)
	assert_eq(vfx.pool(&"lightning").playing_count(), 1)
	assert_true(vfx.screen().is_active(VfxScreen.Mode.POP))
	assert_true(vfx.screen().is_active(VfxScreen.Mode.FLASH))
	for i in 120:
		vfx.advance(TICK)
	assert_eq(vfx.pool(&"ko_dome").playing_count(), 0)
	assert_false(vfx.screen().is_active(VfxScreen.Mode.POP), "the pop fades out")


func test_a_heavy_counter_shows_a_two_frame_impact_frame() -> void:
	var vfx := _vfx_with_sim()
	var events: Array[Dictionary] = [_event(E.COUNTER, 9)]
	vfx.react(events)
	assert_true(vfx.screen().is_active(VfxScreen.Mode.IMPACT))
	assert_true(vfx.screen().is_active(VfxScreen.Mode.LINES))
	vfx.advance(TICK)
	vfx.advance(TICK)
	assert_false(vfx.screen().is_active(VfxScreen.Mode.IMPACT))


func test_dashing_leaves_stretched_afterimages() -> void:
	var vfx := _vfx_with_sim()
	var fighter := vfx.sim.fighters[0]
	fighter.state = S.DASHING
	fighter.velocity = Vector3(0, 0, -40)
	_react(vfx)
	assert_eq(vfx.pool(&"afterimage").playing_count(), 1)
	var ghost := vfx.pool(&"afterimage").effects()[0]
	assert_gt(ghost.global_basis.z.length(), 1.1, "stretched along the dash")


func test_vanish_leaves_a_ghost_and_bursts_at_both_ends() -> void:
	var vfx := _vfx_with_sim()
	var fighter := vfx.sim.fighters[0]
	fighter.state = S.VANISHING
	_react(vfx)
	assert_eq(vfx.pool(&"afterimage").playing_count(), 1)
	assert_eq(vfx.pool(&"vanish_burst").playing_count(), 1)
	fighter.state = S.FLYING
	fighter.position = Vector3(0, 3, -8)
	_react(vfx)
	assert_eq(vfx.pool(&"vanish_burst").playing_count(), 2)


func test_powering_up_flares_the_aura() -> void:
	var vfx := _vfx_with_sim()
	vfx.sim.fighters[1].state = S.CHARGING
	_react(vfx)
	assert_eq(vfx.pool(&"aura_flare").playing_count(), 1)
	_react(vfx)
	assert_eq(vfx.pool(&"aura_flare").playing_count(), 1, "once per power-up")


func test_breaking_the_speed_line_fires_one_sonic_ring() -> void:
	var vfx := _vfx_with_sim()
	var fighter := vfx.sim.fighters[0]
	fighter.state = S.DASHING
	fighter.velocity = Vector3(MatchVfx.SONIC_SPEED + 5.0, 0, 0)
	_react(vfx)
	_react(vfx)
	assert_eq(vfx.pool(&"sonic_ring").playing_count(), 1)
	var ring := vfx.pool(&"sonic_ring").effects()[0]
	assert_almost_eq(ring.global_basis.z.normalized().x, 1.0, 0.01, "the ring faces the flight")


func test_hard_landings_kick_up_zone_dust() -> void:
	var vfx := _vfx_with_sim(&"heartbloom_gardens")
	var fighter := vfx.sim.fighters[0]
	fighter.state = S.FALLING
	fighter.velocity = Vector3(0, -20, 0)
	_react(vfx)
	fighter.state = S.IDLE
	fighter.velocity = Vector3.ZERO
	_react(vfx)
	assert_eq(vfx.pool(&"landing_dust").playing_count(), 1)
	assert_eq(vfx.pool(&"petals").playing_count(), 1, "heartbloom landings shed petals")


func test_soft_landings_stay_clean() -> void:
	var vfx := _vfx_with_sim()
	var fighter := vfx.sim.fighters[0]
	fighter.state = S.FALLING
	fighter.velocity = Vector3(0, -2, 0)
	_react(vfx)
	fighter.state = S.IDLE
	_react(vfx)
	assert_eq(vfx.pool(&"landing_dust").playing_count(), 0)


func test_a_weapon_swing_smears_on_its_first_active_tick() -> void:
	var vfx := _vfx_with_sim()
	var fighter := vfx.sim.fighters[0]
	fighter.weapons[0] = Weapon.Kind.STORM_BLADE
	fighter.active_slot = 0
	var move: MoveData = load("res://game/combat/moves/kael/smash.tres")
	fighter.begin_move(move)
	fighter.state = S.ATTACKING
	fighter.move_tick = move.startup_ticks
	assert_eq(fighter.attack_phase(), FighterState.AttackPhase.ACTIVE)
	_react(vfx)
	assert_eq(vfx.pool(&"smear_blade").playing_count(), 1)
	_react(vfx)
	assert_eq(vfx.pool(&"smear_blade").playing_count(), 1, "one smear per swing")


func test_ki_blast_flies_then_bursts_and_despawns() -> void:
	var vfx := _vfx_with_sim()
	var blast := vfx.play_ki_blast(Vector3.ZERO, Vector3(0, 0, -9), Color.CYAN, 45.0)
	for i in 6:
		blast.advance(TICK)
	assert_lt(blast.head().z, -2.0, "it travels")
	for i in 60:
		blast.advance(TICK)
	assert_false(blast.is_playing())
	assert_almost_eq(blast.head().z, -9.0, 0.8, "it stopped where it hit")


func test_beam_charges_fires_and_lights_the_scene() -> void:
	var vfx := _vfx_with_sim()
	var beam := vfx.play_beam(Vector3.ZERO, Vector3(0, 0, -20), Color.CYAN, 0.5, 1.0, true)
	beam.advance(0.25)
	var light := beam.find_children("*", "OmniLight3D", false, false)[0] as OmniLight3D
	assert_false(beam.find_children("*", "MeshInstance3D", false, false).any(
		func(m: Node) -> bool: return m.visible and (m as MeshInstance3D).mesh is ArrayMesh), "no body while charging")
	beam.advance(0.4)
	assert_gt(light.light_energy, 1.0, "the beam lights its surroundings")
	assert_true(beam.find_children("*", "MeshInstance3D", false, false).any(
		func(m: Node) -> bool: return m.visible and (m as MeshInstance3D).mesh is ArrayMesh), "the body is out")
	beam.advance(1.2)
	assert_false(beam.is_playing())


func test_a_3600_tick_bot_fight_keeps_pools_bounded_and_spawns_nothing_new() -> void:
	var vfx := _vfx_with_sim(&"heartbloom_gardens")
	var sim := CombatSim.new(11)
	sim.zone = &"heartbloom_gardens"
	sim.pickups_enabled = true
	sim.add_fighter(Vector3(0, 1, 6))
	sim.add_fighter(Vector3(0, 1, -6))
	sim.lock_everyone_onto_nearest()
	vfx.sim = sim
	var bots: Array[WeaponBot] = [WeaponBot.new(0, 34), WeaponBot.new(1, 35)]
	var plays := {}
	var nodes_after_warmup := 0
	# Pools may grow lazily up to capacity; fill them so only real leaks count.
	for pool in vfx.pools():
		pool.fill(pool.capacity)
	for tick in 3600:
		var inputs: Array[FighterInput] = []
		for bot in bots:
			inputs.append(bot.next_input(sim))
		sim.tick(inputs)
		vfx.react(sim.events)
		vfx.advance(TICK)
		for pool in vfx.pools():
			assert_lte(pool.size(), pool.capacity, pool.kind)
			if pool.playing_count() > 0:
				plays[pool.kind] = true
		if tick == 1800:
			nodes_after_warmup = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	gut.p("effects seen: %s" % [plays.keys()])
	assert_true(plays.has(&"smear_fist") or plays.has(&"smear_chakram"), "swings smeared")
	assert_true(plays.size() >= 5, "a real fight shows a spread of effects")
	assert_lte(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), nodes_after_warmup + 8,
		"no node growth in the second half")
	for i in 180:
		vfx.advance(TICK)
	for pool in vfx.pools():
		assert_eq(pool.playing_count(), 0, "%s all despawned" % pool.kind)


func test_ko_flash_lasts_at_most_four_rendered_frames_even_in_slow_mo() -> void:
	var vfx := _vfx_with_sim()
	var events: Array[Dictionary] = [_event(E.KO, 20)]
	vfx.react(events)
	var lit := 0
	# Slow-mo shrinks delta; the flash counts frames, not seconds.
	for i in 30:
		if vfx.screen().is_active(VfxScreen.Mode.FLASH):
			lit += 1
		vfx.advance(TICK * 0.3)
	assert_between(lit, 1, VfxScreen.MAX_FLASH_FRAMES)


func test_ko_colour_pop_is_capped_and_subtle() -> void:
	var screen := VfxScreen.new()
	add_child_autofree(screen)
	screen.color_pop(VfxScreen.SKY_POP, 0.6, 0.9)
	var rect := screen.get_child(VfxScreen.Mode.POP) as ColorRect
	assert_lte(float((rect.material as ShaderMaterial).get_shader_parameter("amount")), VfxScreen.MAX_POP)


func test_ko_dome_is_an_outline_drawn_behind_the_fighters() -> void:
	var dome := VfxCatalog.build(&"ko_dome")
	autofree(dome)
	var looks: Array = []
	for mesh in dome.meshes():
		looks.append(mesh.material_override.get_meta(&"look"))
		if mesh.material_override.get_meta(&"look") == &"dome":
			var material := mesh.material_override as ShaderMaterial
			assert_true(material.get_shader_parameter("back_faces_only"), "only the far half draws")
			assert_gte(float(material.get_shader_parameter("rim_power")), 4.0, "a thin rim, not a filled bubble")
	assert_true(looks.has(&"dome"))
	assert_false(looks.has(&"flash") or looks.has(&"spikes"), "nothing bright sits on the bodies")


func test_hit_effects_are_short_and_sized_to_the_fighters() -> void:
	# A fighter is about 2 m tall; heavy effects last at most 10 frames.
	for kind: StringName in [&"anime_burst"]:
		var effect := VfxCatalog.build(kind)
		autofree(effect)
		assert_lte(effect.lifetime, 10.0 / 60.0 + 0.001, kind)
		for mesh in effect.meshes():
			assert_lte((mesh.mesh as QuadMesh).size.x, 1.2, "%s sprite size" % kind)
	for scene: PackedScene in [CombatFeedback.SPARK_LIGHT, CombatFeedback.SPARK_HEAVY, CombatFeedback.COUNTER]:
		var spark := scene.instantiate() as ImpactEffect
		autofree(spark)
		assert_lte(spark.lifetime, 10.0 / 60.0 + 0.001, scene.resource_path)
		for mesh in spark.find_children("*", "MeshInstance3D", true, false):
			assert_lte(((mesh as MeshInstance3D).mesh as QuadMesh).size.x, 0.75, scene.resource_path)


func test_hit_effects_sit_beside_the_target_not_on_its_torso() -> void:
	var fighters: Array[FighterState] = []
	var sim := CombatSim.new(1)
	fighters.append(sim.add_fighter(Vector3(0, 1, 1)))
	fighters.append(sim.add_fighter(Vector3(0, 1, -1)))
	var contact := Vector3(0, 1.3, -0.58)
	var hit := {"type": E.HIT, "attacker": 0, "target": 1, "position": contact}
	var point := MatchVfx.spark_point(hit, fighters)
	assert_almost_eq(point.distance_to(contact), MatchVfx.SPARK_STANDOFF, 0.001)
	assert_gt(Vector2(point.x, point.z).distance_to(Vector2(0, -1)), Vector2(contact.x, contact.z).distance_to(Vector2(0, -1)), "pushed away from the target")
	var throw := {"type": E.THROW, "attacker": 0, "target": 1, "position": fighters[1].position}
	assert_gt(MatchVfx.spark_point(throw, fighters).z, fighters[1].position.z, "a throw at the body centre falls back toward the attacker")
	var pickup := {"type": E.PICKUP, "position": contact}
	assert_eq(MatchVfx.spark_point(pickup, fighters), contact)


func test_ffa_shrinks_effects_and_the_feedback_caps_live_sparks() -> void:
	var vfx := _vfx_with_sim()
	assert_eq(vfx.crowd_scale(), 1.0)
	vfx.sim.add_fighter(Vector3(6, 1, 0))
	assert_eq(vfx.crowd_scale(), MatchVfx.CROWD_SCALE)
	var feedback := CombatFeedback.new()
	add_child_autofree(feedback)
	var blocks: Array[Dictionary] = []
	for i in 20:
		blocks.append({"type": E.BLOCK, "attacker": 0, "target": 1, "position": Vector3(0, 2, -3), "hitstop": 4})
	feedback.react(blocks)
	assert_eq(feedback.live_sparks(), CombatFeedback.MAX_LIVE_SPARKS, "minor sparks stop at the cap")
	var hit: Array[Dictionary] = [_event(E.HIT, 9)]
	feedback.react(hit)
	assert_eq(feedback.live_sparks(), CombatFeedback.MAX_LIVE_SPARKS + 1, "a real hit always shows")


func test_speed_lines_skip_tapped_dashes_and_keep_long_dashes_boost_and_top_speed() -> void:
	var tuning := MovementTuning.new()
	var fighter := FighterState.new()
	fighter.state = S.DASHING
	fighter.dash_kind = FighterState.DashKind.STEP
	fighter.state_ticks = 3
	fighter.velocity = Vector3(48, 0, 0)
	assert_false(MatchVfx.wants_speed_lines(fighter, tuning), "a tapped dash")
	fighter.dash_kind = FighterState.DashKind.SUSTAINED
	assert_true(MatchVfx.wants_speed_lines(fighter, tuning), "a flight boost")
	fighter.dash_kind = FighterState.DashKind.RUSH
	assert_false(MatchVfx.wants_speed_lines(fighter, tuning), "a short rush")
	fighter.state_ticks = tuning.dash_step_ticks
	assert_true(MatchVfx.wants_speed_lines(fighter, tuning), "a long rush")
	fighter.state = S.FLYING
	fighter.velocity = Vector3(tuning.fly_speed * 0.8, 0, 0)
	assert_false(MatchVfx.wants_speed_lines(fighter, tuning), "cruising flight")
	fighter.velocity = Vector3(tuning.fly_speed, 0, 0)
	assert_true(MatchVfx.wants_speed_lines(fighter, tuning), "top speed")


func test_speed_lines_are_rate_limited_fainter_and_short_lived() -> void:
	var trail := FlightTrail.new()
	add_child_autofree(trail)
	var fast := Vector3(50, 0, 0)
	var frame := 1.0 / 60.0
	# Dash on and off every 6 frames for two seconds.
	for i in 120:
		trail.follow(Vector3.ZERO, fast if (i / 6) % 2 == 0 else Vector3.ZERO, Color.WHITE, frame)
	assert_lte(trail.starts, ceili(2.0 / FlightTrail.RESTART_SECONDS) + 1, "at most one stream per restart window")
	assert_gt(trail.starts, 0)
	assert_lt(trail.lifetime, 0.28, "shorter than the old 0.28 s")
	var tint: Color = (trail.material_override as ShaderMaterial).get_shader_parameter(&"tint")
	assert_almost_eq(tint.a, FlightTrail.OPACITY, 0.001, "lower opacity")
	assert_lt(FlightTrail.OPACITY, 1.0)
