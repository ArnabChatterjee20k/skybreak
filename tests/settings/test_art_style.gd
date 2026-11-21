extends GutTest
## The Voxel / Classic art style setting: saved with the graphics settings,
## Voxel by default, and the switch the views read.

const TEST_PATH := "user://test_art_style.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	ArtStyle.reset()


func test_new_settings_default_to_the_voxel_style() -> void:
	assert_eq(GraphicsSettings.new().art_style, ArtStyle.Kind.VOXEL)
	assert_eq(GraphicsSettings.load_saved("user://does_not_exist.cfg").art_style, ArtStyle.Kind.VOXEL)


func test_the_classic_style_saves_and_loads_back() -> void:
	var settings := GraphicsSettings.new()
	settings.art_style = ArtStyle.Kind.CLASSIC
	assert_eq(settings.save(TEST_PATH), OK)
	assert_eq(GraphicsSettings.load_saved(TEST_PATH).art_style, ArtStyle.Kind.CLASSIC)


func test_an_unknown_saved_style_falls_back_to_voxel() -> void:
	var config := ConfigFile.new()
	config.set_value(GraphicsSettings.SECTION, "art_style", 7)
	config.save(TEST_PATH)
	assert_eq(GraphicsSettings.load_saved(TEST_PATH).art_style, ArtStyle.Kind.VOXEL)


func test_set_current_switches_what_views_read() -> void:
	ArtStyle.set_current(ArtStyle.Kind.CLASSIC)
	assert_false(ArtStyle.is_voxel())
	ArtStyle.set_current(ArtStyle.Kind.VOXEL)
	assert_true(ArtStyle.is_voxel())


func test_saving_the_style_keeps_the_other_graphics_values() -> void:
	var settings := GraphicsSettings.new()
	settings.quality = GraphicsSettings.Quality.LOW
	settings.art_style = ArtStyle.Kind.CLASSIC
	settings.save(TEST_PATH)
	var loaded := GraphicsSettings.load_saved(TEST_PATH)
	assert_eq(loaded.quality, GraphicsSettings.Quality.LOW)
	assert_eq(loaded.art_style, ArtStyle.Kind.CLASSIC)
