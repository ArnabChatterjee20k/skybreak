extends GutTest
## T-121: combat events -> VFX, camera shake and combo counter.

const E := CombatSim.EventType


func _event(type: int, hitstop: int = 4) -> Dictionary:
	return {"type": type, "attacker": 0, "target": 1, "position": Vector3(0, 2, -3), "hitstop": hitstop}


func test_light_hit_gets_a_light_spark_and_a_small_shake() -> void:
	var plan := CombatFeedback.plan_for(_event(E.HIT, 4))
	assert_eq(plan.effects, [CombatFeedback.SPARK_LIGHT])
	assert_between(plan.shake, 0.01, 0.2)


func test_heavy_hit_gets_a_heavy_spark_and_more_shake() -> void:
	var light := CombatFeedback.plan_for(_event(E.HIT, 4))
	var heavy := CombatFeedback.plan_for(_event(E.HIT, 8))
	assert_eq(heavy.effects, [CombatFeedback.SPARK_HEAVY])
	assert_gt(heavy.shake, light.shake)


func test_every_event_type_shows_something() -> void:
	for type in E.values():
		assert_false(CombatFeedback.plan_for(_event(type)).effects.is_empty(), E.find_key(type))


func test_blocks_are_tinted_and_smaller_than_hits() -> void:
	var block := CombatFeedback.plan_for(_event(E.BLOCK))
	assert_eq(block.color, CombatFeedback.BLOCK_COLOR)
	assert_lt(block.scale, 1.0)


func test_ko_and_guard_break_get_the_biggest_shakes_but_leave_impact_frames_to_the_gate() -> void:
	var ko := CombatFeedback.plan_for(_event(E.KO, 20))
	var guard_break := CombatFeedback.plan_for(_event(E.GUARD_BREAK, 14))
	for type in E.values():
		assert_eq(CombatFeedback.plan_for(_event(type, 20)).impact_frames, 0, "%s: MatchVfx rations those" % E.find_key(type))
	assert_gt(ko.shake, CombatFeedback.plan_for(_event(E.HIT, 8)).shake)
	assert_gt(guard_break.shake, CombatFeedback.plan_for(_event(E.HIT, 8)).shake)


func test_react_spawns_effects_at_the_contact_point_and_shakes_the_camera() -> void:
	var camera := FighterCamera.new()
	add_child_autofree(camera)
	var feedback := CombatFeedback.new()
	add_child_autofree(feedback)
	feedback.camera = camera
	var events: Array[Dictionary] = [_event(E.HIT, 8)]
	feedback.react(events)
	assert_eq(feedback.get_child_count(), 1)
	assert_eq((feedback.get_child(0) as Node3D).global_position, Vector3(0, 2, -3))
	assert_gt(camera.shake_trauma(), 0.0)


func test_shake_moves_the_camera_then_settles_back_onto_the_unshaken_pose() -> void:
	var still := FighterCamera.new()
	var shaken := FighterCamera.new()
	add_child_autofree(still)
	add_child_autofree(shaken)
	var player := Vector3(0, 10, 0)
	var target := Vector3(0, 10, -12)
	for i in 30:
		still.follow(player, target, true, 1.0 / 60.0)
		shaken.follow(player, target, true, 1.0 / 60.0)
	shaken.shake(1.0)
	var moved := 0.0
	for i in 6:
		still.follow(player, target, true, 1.0 / 60.0)
		shaken.follow(player, target, true, 1.0 / 60.0)
		moved = maxf(moved, still.global_position.distance_to(shaken.global_position))
	assert_gt(moved, 0.05, "the shake is visible")
	for i in 60:
		still.follow(player, target, true, 1.0 / 60.0)
		shaken.follow(player, target, true, 1.0 / 60.0)
	assert_almost_eq(shaken.shake_trauma(), 0.0, 0.0001)
	assert_lt(still.global_position.distance_to(shaken.global_position), 0.001, "no drift after the shake")


func test_combo_text_starts_at_two_hits() -> void:
	assert_eq(ComboCounter.text_for(1), "")
	assert_eq(ComboCounter.text_for(2), "2 HITS")
	assert_eq(ComboCounter.text_for(7), "7 HITS")


func test_combo_counter_holds_the_last_count_then_hides() -> void:
	var counter := ComboCounter.new()
	add_child_autofree(counter)
	var target := FighterState.new()
	target.combo_hits = 3
	counter.show_combo([FighterState.new(), target], 1.0 / 60.0)
	assert_true(counter.visible)
	assert_eq(counter.text, "3 HITS")
	target.combo_hits = 0
	counter.show_combo([FighterState.new(), target], 0.5)
	assert_true(counter.visible, "held after the combo ends")
	counter.show_combo([FighterState.new(), target], 0.6)
	assert_false(counter.visible)


func test_the_arena_feeds_sim_events_to_the_feedback_every_tick() -> void:
	var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
	add_child_autofree(arena)
	arena.set_physics_process(false)
	arena.set_process(false)
	var bot_hit := func(index: int, tick: int) -> FighterInput:
		var input := FighterInput.new()
		if index == 0:
			input.move = Vector2(0, 1)
			if tick % 12 == 0:
				input.pressed_actions = FighterInput.Action.LIGHT
				input.held_actions = FighterInput.Action.LIGHT
		return input
	arena.input_override = bot_hit
	var spawned := 0
	for i in 600:
		arena.step_tick()
		for event in arena.sim.events:
			if event.type == E.HIT:
				spawned += 1
		if spawned > 0:
			break
	assert_gt(spawned, 0, "the bot landed a hit")
	assert_gt(arena.combat_feedback.get_child_count(), 0, "and the arena spawned its spark")
