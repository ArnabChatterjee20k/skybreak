extends GutTest
## Ki attacks end to end (T-KI1): a real Q key event through KeyboardMouseInput
## into the sim, a ki projectile, and KiLayer's visual node; beams and the clash
## prompt; ki sounds.

const A := FighterInput.Action
const E := CombatSim.EventType


func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	return event


func _arena() -> Node:
	var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
	arena.match_flow.enabled = false
	arena.sim.pickups_enabled = false
	add_child_autofree(arena)
	return arena


func test_pressing_q_fires_a_sim_ki_blast_that_ki_layer_draws_and_bursts_on_impact() -> void:
	var arena := _arena()
	await wait_physics_frames(2)
	var sim: CombatSim = arena.sim
	sim.fighters[0].ki = 100 * FighterState.METER_UNIT
	var layer: KiLayer = arena.combat_feedback.vfx.ki_layer
	Input.parse_input_event(_key(KEY_Q, true))
	Input.flush_buffered_events()
	await wait_physics_frames(2)
	Input.parse_input_event(_key(KEY_Q, false))
	Input.flush_buffered_events()
	assert_eq(sim.fighters[0].move_id(), &"ki_blast", "Q started the ki blast")
	var fired := false
	for _i in 20:
		await wait_physics_frames(1)
		for projectile in sim.projectiles:
			if projectile.ki == KiRules.Shot.BLAST and layer.shot_count() == 1:
				fired = true
		if fired:
			break
	assert_true(fired, "a ki projectile in the sim with its visual node")
	assert_eq(arena.weapon_layer._projectile_nodes.size(), 0, "the weapon layer leaves ki shots alone")
	for _i in 40:
		await wait_physics_frames(1)
		if sim.projectiles.is_empty():
			break
	await wait_physics_frames(1)
	assert_eq(layer.shot_count(), 0, "gone with the sim projectile")
	assert_gt(sim.fighters[1].combo_hits + int(sim.fighters[1].health < sim.fighters[1].stats.max_health * 60), 0,
		"it hit the dummy")


func test_ki_layer_draws_a_beam_at_sim_thickness_and_the_clash_prompt() -> void:
	var arena := _arena()
	arena.set_physics_process(false)
	await wait_frames(1)
	var sim: CombatSim = arena.sim
	var held := [0, 0]
	var previous: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]
	arena.input_override = func(index: int, _tick: int) -> FighterInput:
		var input := FighterInput.from_held(held[index], previous[index])
		previous[index] = input
		return input
	for fighter in sim.fighters:
		fighter.ki = 100 * FighterState.METER_UNIT
	held.fill(A.SPECIAL_1)
	arena.step_tick()
	held.fill(0)
	var layer: KiLayer = arena.combat_feedback.vfx.ki_layer
	for _i in 60:
		arena.step_tick()
		if not sim.beam_clashes.is_empty():
			break
	assert_eq(layer.beam_effect_count(), 2, "one beam effect per sim beam")
	assert_false(sim.beam_clashes.is_empty(), "the beams clashed")
	assert_true(layer.prompt().visible, "the clash prompt is up")
	assert_gt(layer.prompt().upcoming().size(), 0, "with beats coming")
	for _i in 300:
		arena.step_tick()
	assert_eq(layer.beam_effect_count(), 0, "beams gone")
	assert_false(layer.prompt().visible)


func test_ki_events_ask_for_fire_impact_reflect_beam_and_clash_sounds() -> void:
	var cue := func(event: Dictionary) -> Array:
		return CombatAudioMapper.cues_for_event(event).map(func(r: Dictionary) -> StringName: return r.cue)
	assert_has(cue.call({"type": E.KI_FIRE, "shot": KiRules.Shot.BLAST}), &"ki_blast_fire")
	assert_has(cue.call({"type": E.PROJECTILE_HIT, "weapon": Weapon.Kind.NONE, "reflected": false}), &"ki_blast_impact")
	assert_has(cue.call({"type": E.PROJECTILE_HIT, "weapon": Weapon.Kind.NONE, "reflected": true}), &"perfect_block")
	assert_has(cue.call({"type": E.BEAM_FIRE}), &"beam_fire")
	assert_has(cue.call({"type": E.BEAM_CLASH}), &"beam_clash")
	assert_eq(cue.call({"type": E.PROJECTILE_HIT, "weapon": Weapon.Kind.ARC_REVOLVER, "reflected": false}), [],
		"weapon shots keep their own sounds")


func test_the_charge_hum_rises_through_a_charged_blast_and_beam_startup() -> void:
	var sim := CombatSim.new(3)
	sim.add_fighter(Vector3.ZERO)
	sim.add_fighter(Vector3(0, 0, -12))
	sim.lock_everyone_onto_nearest()
	sim.fighters[0].ki = 100 * FighterState.METER_UNIT
	var mapper := CombatAudioMapper.new()
	var previous := FighterInput.new()
	var levels: Array[float] = []
	for _i in 20:
		var input := FighterInput.from_held(A.KI_BLAST, previous)
		previous = input
		sim.tick([input, FighterInput.new()] as Array[FighterInput])
		for loop in mapper.loops_for(sim):
			if loop.key == &"ki_charge_0" and loop.active:
				levels.append(loop.intensity)
	assert_gt(levels.size(), 5, "the hum plays while charging")
	assert_gt(levels[levels.size() - 1], levels[0], "and rises")
