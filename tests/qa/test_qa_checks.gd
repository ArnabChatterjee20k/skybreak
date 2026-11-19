extends GutTest
## The QA harness's own pieces: the soak matrix and the sim invariant checks.


func _sim() -> CombatSim:
	var sim := CombatSim.new(1)
	sim.add_fighter(Vector3(0, 1, 6))
	sim.add_fighter(Vector3(0, 1, -6))
	sim.lock_everyone_onto_nearest()
	return sim


func _checks(found: Array[Dictionary]) -> Array:
	return found.map(func(v: Dictionary) -> String: return v.check)


func test_a_spec_id_parses_back_to_the_same_match() -> void:
	var spec := QaMatchSpec.make(4242, &"ember_rift", &"2v2", 1)
	var again := QaMatchSpec.parse(spec.id())
	assert_eq(again.id(), spec.id())
	assert_eq(again.fighters(), spec.fighters())


func test_two_v_two_puts_slots_zero_and_one_on_one_team() -> void:
	var spec := QaMatchSpec.make(1, &"ember_rift", &"2v2", 0)
	assert_eq(spec.fighters().map(func(f: Dictionary) -> int: return f.team), [0, 0, 1, 1])


func test_the_quick_matrix_covers_every_zone_mode_and_legend() -> void:
	var cells := {}
	var legends := {}
	for spec in QaMatchSpec.quick_matrix():
		cells["%s/%s" % [spec.zone, spec.mode]] = true
		for legend in spec.legends:
			legends[legend] = true
		for level in spec.levels:
			assert_between(level, QaMatchSpec.MIN_LEVEL, QaMatchSpec.MAX_LEVEL)
	assert_eq(cells.size(), ZoneLayout.ZONE_IDS.size() * QaMatchSpec.MODES.size())
	assert_eq(legends.size(), QaMatchSpec.LEGENDS.size())


func test_the_full_matrix_has_every_legend_zone_mode_cell_three_times() -> void:
	var specs := QaMatchSpec.full_matrix()
	assert_eq(specs.size(), 3 * QaMatchSpec.LEGENDS.size() * ZoneLayout.ZONE_IDS.size() * QaMatchSpec.MODES.size())
	var ids := {}
	for spec in specs:
		ids[spec.id()] = true
	assert_eq(ids.size(), specs.size(), "every match is distinct")


func test_a_fresh_sim_passes_every_check() -> void:
	var sim := _sim()
	assert_eq(QaSimChecks.check_tick(sim), [] as Array[Dictionary])
	assert_eq(QaSimChecks.check_overlap(sim), [] as Array[Dictionary])


func test_a_non_finite_position_is_caught() -> void:
	var sim := _sim()
	sim.fighters[0].position.x = NAN
	assert_has(_checks(QaSimChecks.check_tick(sim)), "nan")


func test_a_meter_out_of_range_is_caught() -> void:
	var sim := _sim()
	sim.fighters[1].ki = -1
	assert_has(_checks(QaSimChecks.check_tick(sim)), "meter_range")


func test_a_state_held_past_its_limit_is_caught() -> void:
	var sim := _sim()
	sim.fighters[0].state = FighterState.State.GRABBED
	sim.fighters[0].state_ticks = 10 * CombatSim.TICKS_PER_SECOND
	assert_has(_checks(QaSimChecks.check_tick(sim)), "stuck_state")


func test_leaving_the_arena_box_is_caught() -> void:
	var sim := _sim()
	sim.fighters[0].position.z = sim.tuning.arena_half_size + 5.0
	assert_has(_checks(QaSimChecks.check_tick(sim)), "arena_bounds")


func test_overlapping_bodies_are_caught_but_touching_ones_are_not() -> void:
	var sim := _sim()
	sim.fighters[1].position = sim.fighters[0].position + Vector3(0, 0, 1.0)
	assert_eq(QaSimChecks.check_overlap(sim).size(), 0, "1 m apart: capsules of 0.5 m just touch")
	sim.fighters[1].position = sim.fighters[0].position + Vector3(0, 0, 0.5)
	assert_eq(_checks(QaSimChecks.check_overlap(sim)), ["fighter_overlap"])


func test_a_new_round_away_from_the_spawns_is_caught() -> void:
	var sim := _sim()
	var spawns: Array[Vector3] = [Vector3(0, 1, 6), Vector3(0, 1, -6)]
	assert_eq(QaSimChecks.check_round_reset(sim, spawns), [] as Array[Dictionary])
	sim.fighters[0].position = Vector3(20, 1, 0)
	assert_has(_checks(QaSimChecks.check_round_reset(sim, spawns)), "round_reset")


func test_every_visual_shot_names_a_valid_match() -> void:
	var names := {}
	for shot in QaShots.all():
		var spec := QaMatchSpec.parse(shot.spec)
		assert_has(ZoneLayout.ZONE_IDS, spec.zone)
		names[shot.name] = true
	assert_eq(names.size(), QaShots.all().size())
	assert_between(names.size(), 12, 16)


func _idle_at(x: float) -> FighterState:
	var fighter := FighterState.new()
	fighter.position = Vector3(x, 1.0, 0.0)
	fighter.state = FighterState.State.IDLE
	return fighter


## Feeds one presented frame of fighter 0's planted foot at foot_x to the slide metric.
func _slide_frame(checks: QaViewChecks, frame: int, body_x: float, foot_x: float, lowest := 0.0) -> void:
	checks.frames = frame
	checks._measure_slide(0, _idle_at(body_x), lowest, 7, Vector3(foot_x, 0.0, 0.0))


func test_a_planted_foot_moving_between_two_frames_counts_as_slide() -> void:
	var checks := QaViewChecks.new(null)
	_slide_frame(checks, 20, 0.0, 0.0)
	_slide_frame(checks, 21, 0.0, 0.02)
	assert_eq(checks.foot_slide_frames, 1)
	assert_almost_eq(checks.foot_slide_sum, 0.02, 0.0001)


func test_a_vanish_teleport_is_not_a_slide() -> void:
	var checks := QaViewChecks.new(null)
	_slide_frame(checks, 20, 0.0, 0.0)
	_slide_frame(checks, 21, 5.28, 5.28)
	assert_eq(checks.foot_slide_frames, 0)
	assert_eq(checks.foot_slide_sum, 0.0)


func test_frames_hidden_in_between_break_the_slide_chain() -> void:
	var checks := QaViewChecks.new(null)
	_slide_frame(checks, 20, 0.0, 0.0)
	_slide_frame(checks, 26, 0.3, 0.3)
	assert_eq(checks.foot_slide_frames, 0)


func test_the_first_frames_of_a_match_are_not_measured() -> void:
	var checks := QaViewChecks.new(null)
	_slide_frame(checks, 1, 0.0, 0.0)
	_slide_frame(checks, 2, 0.0, 0.4)
	assert_eq(checks.foot_slide_frames, 0)


func test_a_floating_foot_is_left_out_of_the_slide_and_counted_as_skipped() -> void:
	var checks := QaViewChecks.new(null)
	_slide_frame(checks, 20, 0.0, 0.0)
	_slide_frame(checks, 21, 0.0, 0.1, QaViewChecks.FOOT_TOLERANCE + 0.03)
	_slide_frame(checks, 22, 0.0, 0.1)
	assert_eq(checks.foot_slide_frames, 0)
	assert_eq(checks.foot_slide_skipped, 1)
