extends GutTest
## VOXEL-LOAD: the loading screen loads its paths on background threads, shows
## progress and hands the loaded resources over; MatchConfig only puts it up
## for a voxel zone that has a bake.

const SMALL := "res://game/world/zones/ember_rift.tres"
const MAIN := "res://game/world/zones/frozen_peaks.tres"


func test_it_loads_every_path_and_hands_them_over() -> void:
	var screen := LoadingScreen.new()
	screen.title = "Ember Rift"
	screen.paths.assign([SMALL, MAIN])
	var got := {}
	screen.done = func(loaded: Dictionary) -> void: got.merge(loaded)
	add_child_autofree(screen)
	var frames := 0
	while got.is_empty() and frames < 600:
		await get_tree().process_frame
		frames += 1
	assert_eq(got.size(), 2, "both loaded")
	assert_true(got[SMALL] is ZoneData)
	assert_almost_eq(screen.progress, 1.0, 0.0001)


func test_it_shows_the_zone_name_and_a_progress_bar() -> void:
	var screen := LoadingScreen.new()
	screen.title = "Frozen Peaks"
	screen.paths.assign([SMALL])
	add_child_autofree(screen)
	var labels := screen.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	assert_has(labels, "FROZEN PEAKS")
	assert_eq(screen.find_children("*", "ProgressBar", true, false).size(), 1)


func test_classic_style_needs_no_zone_bake() -> void:
	var config := get_node(^"/root/MatchConfig")
	var saved := ArtStyle.current()
	ArtStyle.set_current(ArtStyle.Kind.CLASSIC)
	assert_eq(config.zone_bake_path(), "")
	ArtStyle.set_current(saved)


func test_a_live_build_says_so_and_is_drawn_before_done() -> void:
	var screen := LoadingScreen.new()
	screen.paths.assign(["res://game/world/zones/ember_rift.tres"])
	screen.builds_live = true
	var calls := []
	screen.done = func(loaded: Dictionary) -> void: calls.append(loaded)
	add_child_autofree(screen)
	var frames := 0
	while not screen._finished and frames < 600:
		await get_tree().process_frame
		frames += 1
	assert_true(screen._finished)
	assert_eq(calls.size(), 0, "done waits a few frames so the note is on screen")
	var label := screen._label.text
	assert_string_contains(label, "BUILDING THE ZONE")
	for i in LoadingScreen.HOLD_FRAMES + 2:
		await get_tree().process_frame
	assert_eq(calls.size(), 1)


func test_a_zone_level_without_a_bake_still_starts_behind_a_loading_screen() -> void:
	# PF-ZONE-HANG: with no bake the match used to build in the menu's frame, frozen.
	var config := get_node(^"/root/MatchConfig")
	var saved_zone: StringName = config.zone
	var saved_style := ArtStyle.current()
	ArtStyle.set_current(ArtStyle.Kind.VOXEL)
	config.zone = &"verdant_falls"
	for path: String in [MatchConfig.PURE_FIGHT_SCENE, MatchConfig.ZONE_MATCH_SCENE]:
		var screen: LoadingScreen = config.loading_screen(path, "")
		assert_not_null(screen, path)
		if screen != null:
			assert_eq(screen.paths, [path] as Array[String])
			assert_true(screen.builds_live, "it says the zone builds here")
			assert_null(screen.download)
			screen.free()
	assert_null(config.loading_screen(MatchConfig.FALLBACK_SCENE, ""), "the test arena needs none")
	config.zone = saved_zone
	ArtStyle.set_current(saved_style)
