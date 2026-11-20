extends GutTest

const Event := CombatSim.EventType
const Knockback := MoveData.KnockbackType
const State := FighterState.State


func _event(type: Event, hitstop := 4, knockback := Knockback.NONE, counter := false) -> Dictionary:
	return {"type": type, "attacker": 0, "target": 1, "position": Vector3(1, 2, 3), "move_id": &"light_1",
		"damage": 300, "hitstop": hitstop, "knockback_type": knockback, "counter": counter}


func _cues(requests: Array[Dictionary]) -> Array:
	return requests.map(func(r: Dictionary) -> StringName: return r.cue)


func test_the_same_event_always_gives_the_same_cues() -> void:
	var event := _event(Event.HIT, 8, Knockback.LAUNCH)
	var first := CombatAudioMapper.cues_for_event(event)
	for _i in 10:
		assert_eq(CombatAudioMapper.cues_for_event(event.duplicate()), first)


func test_hits_sound_light_medium_or_heavy_by_hitstop_and_knockback() -> void:
	assert_eq(_cues(CombatAudioMapper.cues_for_event(_event(Event.HIT, 4))), [&"hit_light"])
	assert_eq(_cues(CombatAudioMapper.cues_for_event(_event(Event.HIT, 6, Knockback.BLOWBACK))), [&"hit_medium"])
	assert_eq(_cues(CombatAudioMapper.cues_for_event(_event(Event.HIT, 8, Knockback.BLOWBACK))), [&"hit_heavy"])
	assert_eq(_cues(CombatAudioMapper.cues_for_event(_event(Event.HIT, 8, Knockback.LAUNCH))), [&"hit_heavy", &"launcher"])
	assert_eq(_cues(CombatAudioMapper.cues_for_event(_event(Event.HIT, 10, Knockback.WALL_SPLAT))),
		[&"hit_heavy", &"wall_splat"])


func test_a_counter_hit_adds_its_sting_without_turning_a_light_into_a_heavy() -> void:
	assert_eq(_cues(CombatAudioMapper.cues_for_event(_event(Event.COUNTER, 8, Knockback.NONE, true))),
		[&"hit_light", &"counter_hit"])


func test_defense_events_have_their_own_sounds() -> void:
	var expected := {
		Event.BLOCK: &"block", Event.PERFECT_BLOCK: &"perfect_block", Event.GUARD_BREAK: &"guard_break",
		Event.PUSH_BLOCK: &"push_block", Event.GRAB: &"grab", Event.THROW: &"throw",
		Event.GRAB_TECH: &"tech", Event.KO: &"ko", Event.ARMOR: &"armor_hit",
	}
	for type: Event in expected:
		assert_eq(_cues(CombatAudioMapper.cues_for_event(_event(type, 10)))[0], expected[type])


func test_heavy_impacts_carry_the_hitstop_so_the_tail_waits_for_it() -> void:
	var request := CombatAudioMapper.cues_for_event(_event(Event.HIT, 12))[0]
	assert_eq(request.position, Vector3(1, 2, 3))
	assert_almost_eq(float(request.params.layer_delay), 12.0 / 60.0, 0.0001)


func test_every_weapon_type_has_its_swing_or_fire_sound() -> void:
	for weapon in [&"ki_gauntlets", &"storm_blade", &"sky_lance", &"titan_hammer", &"orbit_chakram", &"ember_scythe"]:
		assert_ne(CombatAudioMapper.weapon_cue(weapon, &"swing"), &"", "%s swings" % weapon)
	for weapon in [&"ki_bow", &"arc_revolver", &"storm_repeater", &"scatter_cannon", &"heartstring_bow"]:
		assert_ne(CombatAudioMapper.weapon_cue(weapon, &"fire"), &"", "%s fires" % weapon)
	assert_eq(CombatAudioMapper.weapon_cue(&"heartstring_bow", &"fire"), &"heartstring_release")


func _tick(sim: CombatSim, held: Array[int], vertical := [0, 0]) -> void:
	var inputs: Array[FighterInput] = []
	for i in sim.fighters.size():
		var input := FighterInput.new()
		input.held_actions = held[i]
		input.pressed_actions = held[i]
		input.vertical = vertical[i]
		inputs.append(input)
	sim.tick(inputs)


func test_state_changes_give_dash_flight_and_landing_sounds() -> void:
	var sim := CombatSim.new(7)
	sim.add_fighter(Vector3(0, 1, 6))
	sim.add_fighter(Vector3(0, 1, -6))
	var mapper := CombatAudioMapper.new()
	mapper.observe(sim)
	var heard := []
	_tick(sim, [FighterInput.Action.DASH, 0])
	heard.append_array(_cues(mapper.observe(sim)))
	assert_has(heard, &"dash")
	for _i in 30:
		_tick(sim, [0, 0], [1, 0])
		heard.append_array(_cues(mapper.observe(sim)))
	assert_has(heard, &"flight_start")
	var loops := mapper.loops_for(sim)
	assert_true(loops[0].active, "flying fighter has wind")
	assert_eq(loops[0].cue, &"flight_wind_loop")
	assert_false(loops[3].active, "the grounded fighter has none")


func test_lock_on_sounds_only_for_the_listener() -> void:
	var sim := CombatSim.new(1)
	sim.add_fighter(Vector3(0, 1, 6))
	sim.add_fighter(Vector3(0, 1, -6))
	var mapper := CombatAudioMapper.new()
	mapper.observe(sim)
	sim.lock_everyone_onto_nearest()
	_tick(sim, [0, 0])
	assert_eq(_cues(mapper.observe(sim)).count(&"lock_on"), 1)


func test_two_mappers_fed_the_same_match_ask_for_the_same_sounds() -> void:
	var logs := []
	for _run in 2:
		var sim := CombatSim.new(99)
		sim.add_fighter(Vector3(0, 1, 2))
		sim.add_fighter(Vector3(0, 1, -2))
		sim.lock_everyone_onto_nearest()
		var mapper := CombatAudioMapper.new()
		var log := []
		for tick in 600:
			var held: Array[int] = [FighterInput.Action.LIGHT if tick % 7 == 0 else 0,
				FighterInput.Action.BLOCK if tick % 50 < 25 else 0]
			_tick(sim, held)
			log.append(mapper.observe(sim))
			log.append(mapper.loops_for(sim))
		logs.append(log)
	assert_eq(logs[0], logs[1])
	assert_gt(str(logs[0]).count("hit_"), 0, "the scripted match landed hits")


func _weapon_event(type: Event, weapon: Weapon.Kind) -> Dictionary:
	return {"type": type, "fighter": 0, "position": Vector3.ZERO, "weapon": weapon, "id": 1}


func test_ki_blasts_sound_when_fired_and_when_they_land() -> void:
	assert_eq(_cues(CombatAudioMapper.cues_for_event(_weapon_event(Event.KI_BLAST, Weapon.Kind.NONE))),
		[&"ki_blast_fire"])
	assert_eq(_cues(CombatAudioMapper.cues_for_event(_weapon_event(Event.PROJECTILE_HIT, Weapon.Kind.NONE))),
		[&"ki_blast_impact"])
	assert_eq(_cues(CombatAudioMapper.cues_for_event(_weapon_event(Event.PROJECTILE_HIT, Weapon.Kind.ARC_REVOLVER))),
		[], "a bullet hit sounds through its HIT/BLOCK event only")


func test_pickups_switches_throws_and_shots_have_their_cues() -> void:
	var expected := {
		Event.PICKUP_SPAWN: [&"sky_drop_whistle"], Event.PICKUP: [&"pickup"],
		Event.WEAPON_SWITCH: [&"weapon_switch"], Event.WEAPON_THROW: [&"weapon_throw"],
	}
	for type: Event in expected:
		assert_eq(_cues(CombatAudioMapper.cues_for_event(_weapon_event(type, Weapon.Kind.STORM_BLADE))),
			expected[type], Event.find_key(type))
	assert_eq(_cues(CombatAudioMapper.cues_for_event(_weapon_event(Event.FIRE, Weapon.Kind.ARC_REVOLVER))),
		[&"revolver_fire"])
	assert_eq(_cues(CombatAudioMapper.cues_for_event(_weapon_event(Event.FIRE, Weapon.Kind.HEARTSTRING_BOW))),
		[&"heartstring_release"])
	assert_eq(_cues(CombatAudioMapper.cues_for_event(_weapon_event(Event.OVERHEAT, Weapon.Kind.STORM_REPEATER))),
		[&"repeater_overheat"])
