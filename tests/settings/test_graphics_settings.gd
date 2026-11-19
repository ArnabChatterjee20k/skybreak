extends GutTest

const TEST_PATH := "user://test_settings.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_defaults_are_high_quality_at_full_resolution() -> void:
	var settings := GraphicsSettings.new()
	assert_eq(settings.quality, GraphicsSettings.Quality.HIGH)
	assert_eq(settings.resolution_scale, 1.0)


func test_resolution_scale_is_clamped_to_supported_range() -> void:
	var settings := GraphicsSettings.new()
	settings.resolution_scale = 0.1
	assert_eq(settings.resolution_scale, GraphicsSettings.MIN_RESOLUTION_SCALE)
	settings.resolution_scale = 2.0
	assert_eq(settings.resolution_scale, GraphicsSettings.MAX_RESOLUTION_SCALE)


func test_saved_settings_load_back_unchanged() -> void:
	var settings := GraphicsSettings.new()
	settings.quality = GraphicsSettings.Quality.LOW
	settings.resolution_scale = 0.75
	settings.vsync_enabled = false
	settings.fullscreen = false
	assert_eq(settings.save(TEST_PATH), OK)

	var loaded := GraphicsSettings.load_saved(TEST_PATH)
	assert_eq(loaded.quality, GraphicsSettings.Quality.LOW)
	assert_eq(loaded.resolution_scale, 0.75)
	assert_false(loaded.vsync_enabled)
	assert_false(loaded.fullscreen)


func test_missing_file_gives_defaults() -> void:
	var loaded := GraphicsSettings.load_saved("user://does_not_exist.cfg")
	assert_eq(loaded.quality, GraphicsSettings.Quality.HIGH)


func test_unknown_saved_quality_falls_back_to_default() -> void:
	var config := ConfigFile.new()
	config.set_value(GraphicsSettings.SECTION, "quality", 99)
	config.save(TEST_PATH)
	assert_eq(GraphicsSettings.load_saved(TEST_PATH).quality, GraphicsSettings.Quality.HIGH)


func test_apply_sets_viewport_quality_and_scale() -> void:
	var viewport: SubViewport = add_child_autofree(SubViewport.new())
	var settings := GraphicsSettings.new()
	settings.quality = GraphicsSettings.Quality.MEDIUM
	settings.resolution_scale = 0.8
	settings.apply_to(viewport)
	assert_eq(viewport.msaa_3d, Viewport.MSAA_2X)
	assert_almost_eq(viewport.scaling_3d_scale, 0.8, 0.001)


func test_defaults_to_fullscreen() -> void:
	assert_true(GraphicsSettings.new().fullscreen)


func test_windowed_rect_is_1600x900_centred_on_a_big_screen() -> void:
	var rect := GraphicsSettings.windowed_rect(Rect2i(0, 0, 2560, 1400))
	assert_eq(rect.size, Vector2i(1600, 900))
	assert_eq(rect.position, Vector2i(480, 250))


func test_windowed_rect_never_exceeds_the_usable_area() -> void:
	# A 1366x728 usable area (small laptop with taskbar) can't fit 1600x900.
	var usable := Rect2i(0, 0, 1366, 728)
	var rect := GraphicsSettings.windowed_rect(usable)
	assert_true(usable.encloses(rect), "fits: %s" % rect)
	assert_almost_eq(float(rect.size.x) / rect.size.y, 16.0 / 9.0, 0.01, "keeps 16:9")


func test_windowed_rect_respects_a_screen_offset() -> void:
	var usable := Rect2i(1920, 0, 1920, 1040)
	assert_true(usable.encloses(GraphicsSettings.windowed_rect(usable)))


func test_web_builds_default_to_the_web_tier_windowed_at_reduced_scale() -> void:
	var settings := GraphicsSettings.new(true)
	assert_eq(settings.quality, GraphicsSettings.Quality.WEB)
	assert_eq(settings.resolution_scale, GraphicsSettings.WEB_RESOLUTION_SCALE)
	assert_false(settings.fullscreen)


func test_web_default_is_used_when_nothing_is_saved() -> void:
	var loaded := GraphicsSettings.load_saved("user://does_not_exist.cfg", true)
	assert_eq(loaded.quality, GraphicsSettings.Quality.WEB)


func test_saved_quality_wins_over_the_web_default() -> void:
	var settings := GraphicsSettings.new()
	settings.quality = GraphicsSettings.Quality.LOW
	settings.save(TEST_PATH)
	assert_eq(GraphicsSettings.load_saved(TEST_PATH, true).quality, GraphicsSettings.Quality.LOW)
