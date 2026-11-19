extends GutTest
## T-126: match flow (rounds, clock, KO) and the HUD's layout and values.


func _sim(count: int = 2) -> CombatSim:
	var sim := CombatSim.new()
	for i in count:
		sim.add_fighter(Vector3(i * 4.0, 1, 0))
	return sim


func _knock_out(sim: CombatSim, index: int) -> void:
	sim.apply_damage(index, 1 - index, sim.fighters[index].stats.max_health)


func _run(flow: MatchFlow, sim: CombatSim, ticks: int) -> void:
	for i in ticks:
		flow.step(sim)


# --- MatchFlow ---

func test_intro_says_round_then_fight_and_holds_input() -> void:
	var flow := MatchFlow.new()
	var sim := _sim()
	assert_eq(flow.banner([]).title, "ROUND 1")
	assert_false(flow.accepts_input())
	_run(flow, sim, MatchFlow.INTRO_ROUND_TICKS)
	assert_eq(flow.banner([]).title, "3")
	_run(flow, sim, MatchFlow.COUNT_TICKS)
	assert_eq(flow.banner([]).title, "2")
	_run(flow, sim, MatchFlow.COUNT_TICKS)
	assert_eq(flow.banner([]).title, "1")
	assert_false(flow.accepts_input(), "held through the count")
	_run(flow, sim, MatchFlow.COUNT_TICKS)
	assert_eq(flow.phase, MatchFlow.Phase.FIGHT)
	assert_true(flow.accepts_input())
	assert_eq(flow.banner([]).title, "FIGHT!", "FIGHT! as input goes live")
	_run(flow, sim, MatchFlow.FIGHT_BANNER_TICKS)
	assert_eq(flow.banner([]).title, "")


func test_disabled_flow_always_accepts_input_and_never_counts_down() -> void:
	var flow := MatchFlow.new()
	flow.enabled = false
	_run(flow, _sim(), 600)
	assert_true(flow.accepts_input())
	assert_eq(flow.seconds_left(), MatchFlow.ROUND_SECONDS)


func test_disabled_flow_shows_no_banner() -> void:
	var flow := MatchFlow.new()
	flow.enabled = false
	assert_eq(flow.banner([]).title, "", "no ROUND 1 stuck on screen in playtests")


func test_clock_counts_down_in_the_fight() -> void:
	var flow := MatchFlow.new()
	var sim := _sim()
	_run(flow, sim, MatchFlow.INTRO_TICKS + 60)
	assert_eq(flow.seconds_left(), MatchFlow.ROUND_SECONDS - 1)


func test_ko_scores_the_round_slows_time_then_starts_round_two() -> void:
	var flow := MatchFlow.new()
	var sim := _sim()
	_run(flow, sim, MatchFlow.INTRO_TICKS)
	_knock_out(sim, 1)
	flow.step(sim)
	assert_eq(flow.phase, MatchFlow.Phase.KO)
	assert_eq(flow.wins, [1, 0] as Array[int])
	assert_eq(flow.banner(["KAEL", "VEXA"]).title, "K.O.!")
	assert_eq(flow.banner(["KAEL", "VEXA"]).subtitle, "KAEL WINS THE ROUND")
	assert_lt(flow.time_scale(), 1.0, "slow motion right after the KO")
	_run(flow, sim, MatchFlow.KO_SLOW_TICKS)
	assert_eq(flow.time_scale(), 1.0)
	_run(flow, sim, MatchFlow.KO_TICKS - MatchFlow.KO_SLOW_TICKS)
	assert_eq(flow.phase, MatchFlow.Phase.INTRO)
	assert_eq(flow.round_number, 2)
	assert_eq(flow.banner([]).title, "ROUND 2")
	assert_false(sim.round_over, "the sim started a new round")
	assert_eq(sim.fighters[1].health, sim.fighters[1].stats.max_health * FighterState.METER_UNIT)


func test_second_win_ends_the_match() -> void:
	var flow := MatchFlow.new()
	var sim := _sim()
	for round_index in 2:
		_run(flow, sim, MatchFlow.INTRO_TICKS)
		_knock_out(sim, 1)
		flow.step(sim)  # sees the KO
		_run(flow, sim, MatchFlow.KO_TICKS)
	assert_eq(flow.phase, MatchFlow.Phase.MATCH_OVER)
	assert_eq(flow.banner(["KAEL", "VEXA"]).title, "KAEL WINS!")


func test_time_out_goes_to_the_fighter_with_more_health() -> void:
	var flow := MatchFlow.new()
	var sim := _sim()
	sim.apply_damage(0, 1, 1000)
	_run(flow, sim, MatchFlow.INTRO_TICKS + MatchFlow.ROUND_SECONDS * MatchFlow.TICKS_PER_SECOND)
	assert_eq(flow.phase, MatchFlow.Phase.KO)
	assert_true(flow.timed_out)
	assert_eq(flow.last_winner, 1)
	assert_eq(flow.banner(["A", "B"]).title, "TIME!")


func test_time_out_with_equal_health_is_a_draw() -> void:
	var flow := MatchFlow.new()
	var sim := _sim()
	_run(flow, sim, MatchFlow.INTRO_TICKS + MatchFlow.ROUND_SECONDS * MatchFlow.TICKS_PER_SECOND)
	assert_eq(flow.last_winner, -1)
	assert_eq(flow.wins, [0, 0] as Array[int])
	assert_eq(flow.banner(["A", "B"]).subtitle, "DRAW")


# --- MatchHud ---

func test_hud_scales_to_fit_any_window() -> void:
	assert_almost_eq(MatchHud.design_scale(Vector2(1920, 1080)), 1.0, 0.0001)
	assert_almost_eq(MatchHud.design_scale(Vector2(1280, 720)), 2.0 / 3.0, 0.0001)
	assert_almost_eq(MatchHud.design_scale(Vector2(1280, 1080)), 1280.0 / 1920.0, 0.0001, "narrow web canvas fits by width")


func test_hud_is_pinned_to_the_top_on_tall_canvases() -> void:
	assert_eq(MatchHud.design_offset(Vector2(1280, 1080)).y, 0.0)
	assert_almost_eq(MatchHud.design_offset(Vector2(2560, 1080)).x, 320.0, 0.001, "centred on ultrawide")


func test_banners_sit_in_the_upper_third_clear_of_plates() -> void:
	for screen in [Vector2(1920, 1080), Vector2(1280, 720), Vector2(1280, 1080)]:
		var at := MatchHud.banner_position(screen)
		var on_screen_y := at.y * MatchHud.design_scale(screen) + MatchHud.design_offset(screen).y
		assert_almost_eq(on_screen_y / screen.y, MatchHud.BANNER_HEIGHT_FRACTION, 0.001, "%s" % screen)
		# Below the second row of plates (132 + 14 + 132 + margin, minus the
		# banner's cap height of ~100 px at 132 pt).
		assert_gt(at.y - 100.0, MatchHud.plate_rect(0, 2).end.y, "clear of the plates on %s" % screen)


func test_plates_for_four_fighters_never_overlap_and_stay_on_screen() -> void:
	var screen := Rect2(Vector2.ZERO, MatchHud.DESIGN)
	var clock := Rect2(MatchHud.DESIGN.x / 2 - 60, MatchHud.MARGIN, 120, 84)
	for i in 4:
		var a := MatchHud.plate_rect(i, 4)
		assert_true(screen.encloses(a), "plate %d on screen" % i)
		assert_false(a.intersects(clock), "plate %d clear of the clock" % i)
		for j in range(i + 1, 4):
			assert_false(a.intersects(MatchHud.plate_rect(j, 4)), "plates %d and %d" % [i, j])
	assert_lt(MatchHud.plate_rect(0, 2).position.x, MatchHud.plate_rect(1, 2).position.x, "P1 left, P2 right")


func test_meter_fractions_follow_the_sim() -> void:
	var sim := _sim()
	var fighter := sim.fighters[0]
	assert_almost_eq(MatchHud.health_fraction(fighter), 1.0, 0.0001)
	sim.apply_damage(0, 1, fighter.stats.max_health / 4)
	assert_almost_eq(MatchHud.health_fraction(fighter), 0.75, 0.0001)
	assert_almost_eq(MatchHud.ki_fraction(fighter, sim.meter_tuning),
		float(sim.meter_tuning.round_start_ki) / sim.meter_tuning.ki_max, 0.0001)
	assert_almost_eq(MatchHud.guard_fraction(fighter), 1.0, 0.0001)


func test_chip_trail_holds_then_drains_to_the_new_health() -> void:
	var step := MatchHud.chip_trail_step(1.0, 1.0, 0.0, 0.016)
	step = MatchHud.chip_trail_step(step.trail, 0.6, step.hold, 0.016)
	assert_eq(step.trail, 1.0, "holds right after the hit")
	for i in 30:  # 0.48 s, still inside the hold
		step = MatchHud.chip_trail_step(step.trail, 0.6, step.hold, 0.016)
	assert_eq(step.trail, 1.0)
	for i in 120:
		step = MatchHud.chip_trail_step(step.trail, 0.6, step.hold, 0.016)
	assert_almost_eq(step.trail, 0.6, 0.0001, "drained to the health")


func test_weapon_shows_unarmed_until_fighters_carry_one() -> void:
	var fighter := FighterState.new()
	assert_eq(MatchHud.weapon_label(fighter), "UNARMED")
	for slot in MatchHud.inventory_slots(fighter):
		assert_false(slot.filled)


func test_weapon_box_names_the_held_weapon_with_ammo_and_reload() -> void:
	var fighter := FighterState.new()
	fighter.weapons = PackedInt32Array([Weapon.Kind.STORM_BLADE, Weapon.Kind.ARC_REVOLVER, 0])
	fighter.ammo = PackedInt32Array([0, 12, 0])
	fighter.active_slot = 0
	assert_eq(MatchHud.weapon_label(fighter), "STORM BLADE", "melee: no ammo")
	fighter.active_slot = 1
	assert_eq(MatchHud.weapon_label(fighter), "ARC REVOLVER 12")
	fighter.reload_ticks = 20
	assert_eq(MatchHud.weapon_label(fighter), "ARC REVOLVER RELOAD")
	var slots := MatchHud.inventory_slots(fighter)
	assert_eq(slots.size(), 3)
	assert_true(slots[0].filled and slots[1].filled and not slots[2].filled)
	assert_true(slots[1].active and not slots[0].active)


func test_hud_draws_in_the_arena_without_errors() -> void:
	var hud := MatchHud.new()
	hud.sim = _sim(4)
	hud.flow = MatchFlow.new(4)
	hud.names.assign(["KAEL", "VEXA", "", ""])
	add_child_autofree(hud)
	hud.set_deferred("size", Vector2(1920, 1080))
	await wait_process_frames(2)
	assert_eq(hud.trail_of(0), 1.0)


func test_chip_trail_starts_at_the_current_health() -> void:
	var hud := MatchHud.new()
	hud.sim = _sim()
	hud.sim.apply_damage(1, 0, hud.sim.fighters[1].stats.max_health / 2)
	add_child_autofree(hud)
	await wait_process_frames(1)
	assert_almost_eq(hud.trail_of(1), 0.5, 0.0001, "no drain animation for damage taken before the HUD existed")
