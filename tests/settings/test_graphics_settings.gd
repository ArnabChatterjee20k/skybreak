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
	assert_eq(settings.save(TEST_PATH), OK)

	var loaded := GraphicsSettings.load_saved(TEST_PATH)
	assert_eq(loaded.quality, GraphicsSettings.Quality.LOW)
	assert_eq(loaded.resolution_scale, 0.75)
	assert_false(loaded.vsync_enabled)


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
