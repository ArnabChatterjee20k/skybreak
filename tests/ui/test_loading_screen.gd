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
