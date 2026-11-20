extends GutTest
## T-UI1: the match HUD and round text share the menus' design language.


func _sim(count: int = 2) -> CombatSim:
	var sim := CombatSim.new()
	for i in count:
		sim.add_fighter(Vector3(i * 4.0, 1, 0))
	return sim


func _screen_share(rects: Array[Rect2]) -> float:
	var area := MatchHud.CLOCK_SIZE.x * MatchHud.CLOCK_SIZE.y
	for r in rects:
		area += r.get_area()
	return area / (MatchHud.DESIGN.x * MatchHud.DESIGN.y)


func test_hud_colours_come_from_the_menu_palette() -> void:
	assert_eq(MatchHud.INK, MenuTheme.INK)
	assert_eq(Color(MatchHud.PANEL, 1.0), Color(MenuTheme.PANEL, 1.0))
	assert_almost_eq(MatchHud.PANEL.a, 0.9, 0.001, "panel fill at about 0.9 alpha")
	assert_eq(MatchHud.KI, MenuTheme.CYAN)
	assert_eq(MatchHud.BANNER, MenuTheme.GOLD)
	assert_eq(ComboCounter.COLOR, MenuTheme.GOLD)
	assert_eq(ControlHints.CAP, MenuTheme.GOLD)
	assert_eq(ReadPop.OUTLINE, MenuTheme.INK)


func test_bars_lean_like_the_menu_panels() -> void:
	var points := MatchHud.slant_points(Rect2(100, 50, 200, 40))
	var lean := MenuTheme.SKEW * 40 * 0.5
	assert_eq(points.size(), 4)
	assert_almost_eq(points[0].x, 100.0 + lean, 0.001, "top edge shifted right")
	assert_almost_eq(points[3].x, 100.0 - lean, 0.001, "bottom edge shifted left")
	assert_almost_eq(points[1].x - points[0].x, 200.0, 0.001, "width kept")


func test_fight_is_hot_orange_and_ko_and_count_are_gold() -> void:
	assert_eq(MatchHud.banner_color("FIGHT!"), MenuTheme.HOT)
	assert_eq(MatchHud.banner_color("K.O.!"), MenuTheme.GOLD)
	assert_eq(MatchHud.banner_color("3"), MenuTheme.GOLD)
	assert_eq(MatchHud.banner_color("ROUND 2"), MenuTheme.TEXT)


func test_banners_pop_in_and_settle_in_0_15_seconds() -> void:
	assert_almost_eq(MatchHud.banner_pop(0.0), MatchHud.BANNER_POP, 0.001)
	assert_gt(MatchHud.banner_pop(0.05), 1.0, "still settling")
	assert_lt(MatchHud.banner_pop(0.05), MatchHud.BANNER_POP)
	assert_almost_eq(MatchHud.banner_pop(0.15), 1.0, 0.001)
	assert_almost_eq(MatchHud.banner_pop(3.0), 1.0, 0.001)


func test_low_health_pulse_stays_between_zero_and_one() -> void:
	var low := 1.0
	var high := 0.0
	for i in 120:
		var p := MatchHud.low_health_pulse(i / 60.0)
		low = minf(low, p)
		high = maxf(high, p)
	assert_between(low, 0.0, 0.1, "dips")
	assert_between(high, 0.9, 1.0, "peaks")


func test_footprint_stays_inside_the_art_bible_budget() -> void:
	var duel := _screen_share(MatchHud.plate_layout(2, 0, [0, 1] as Array[int]))
	var ffa := _screen_share(MatchHud.plate_layout(4, 0, [0, 1, 2, 3] as Array[int]))
	assert_lt(duel, 0.12, "1v1 at most 12% of the screen")
	assert_lt(ffa, 0.18, "FFA-4 at most 18% of the screen")


func test_a_hit_flashes_the_lost_health_then_it_trails() -> void:
	var hud := MatchHud.new()
	hud.sim = _sim()
	hud.flow = MatchFlow.new(2)
	add_child_autofree(hud)
	hud.set_deferred("size", MatchHud.DESIGN)
	await wait_process_frames(2)
	hud.sim.apply_damage(1, 0, hud.sim.fighters[1].stats.max_health / 4)
	await wait_process_frames(1)
	assert_gt(hud._flash[1], 0.0, "flash just after the hit")
	assert_eq(hud._flash[0], 0.0, "no flash for the unhurt fighter")
	assert_almost_eq(hud.trail_of(1), 1.0, 0.05, "the trail still shows the lost health")


func test_hud_draws_portraits_and_every_banner_without_errors() -> void:
	var hud := MatchHud.new()
	hud.sim = _sim()
	hud.flow = MatchFlow.new(2)
	hud.names.assign(["LYRA", "VEXA"])
	hud.team_colors.assign([MenuTheme.team_color(0), MenuTheme.team_color(1)])
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	hud.portraits.assign([ImageTexture.create_from_image(image), null])
	add_child_autofree(hud)
	hud.set_deferred("size", MatchHud.DESIGN)
	for ticks in [10, MatchFlow.INTRO_ROUND_TICKS + 1, MatchFlow.INTRO_TICKS + 1]:
		hud.flow.phase_ticks = 0
		hud.flow.phase = MatchFlow.Phase.INTRO
		for t in ticks:
			hud.flow.step(hud.sim)
		await wait_process_frames(1)
	hud.sim.fighters[0].health = 1
	await wait_process_frames(2)
	assert_ne(hud.flow.banner(hud.names).title, "", "a banner was up")


func test_combo_counter_uses_the_display_font_and_scales_with_the_window() -> void:
	var counter := ComboCounter.new()
	add_child_autofree(counter)
	assert_eq(counter.get_theme_font("font"), MenuTheme.font())
	var fighter := FighterState.new()
	fighter.combo_hits = 3
	counter.show_combo([fighter], 1.0)
	var view := counter.get_viewport_rect().size
	assert_almost_eq(counter.scale.x, MatchHud.design_scale(view), 0.001, "settled pop at the design scale")
