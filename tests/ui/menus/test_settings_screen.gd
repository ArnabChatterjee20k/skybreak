extends GutTest
## T-128: settings apply at once (buses, graphics, controls) and persist.

const PATH := "user://test_menu_settings.cfg"

var screen: SettingsScreen
var _bus_db: Dictionary = {}


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	AudioBuses.ensure()
	for bus in SettingsScreen.AUDIO_BUSES:
		_bus_db[bus] = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))
	screen = SettingsScreen.new()
	screen.save_path = PATH
	add_child_autofree(screen)


func after_each() -> void:
	for bus: StringName in _bus_db:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), _bus_db[bus])
	if screen != null and is_instance_valid(screen):
		screen.reset_keys()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_has_a_slider_per_bus() -> void:
	for bus in [&"Master", &"Music", &"SFX", &"Ambience", &"UI"]:
		assert_true(screen.sliders.has(bus), String(bus))


func test_volume_applies_to_the_bus_and_persists() -> void:
	screen.set_volume(&"Music", 0.5)
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")), linear_to_db(0.5), 0.01)
	screen.set_volume(&"SFX", 0.0)
	assert_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX")), -80.0)
	var loaded := AudioSettings.load_saved(PATH)
	assert_almost_eq(loaded.volume(&"Music"), 0.5, 0.001)
	assert_almost_eq(loaded.volume(&"SFX"), 0.0, 0.001)
	assert_almost_eq(screen.sliders[&"Music"].value, 0.5, 0.001)


func test_slider_drag_sets_the_volume() -> void:
	screen.sliders[&"Ambience"].value = 0.25
	assert_almost_eq(AudioSettings.load_saved(PATH).volume(&"Ambience"), 0.25, 0.001)


func test_graphics_persist() -> void:
	screen.set_quality(GraphicsSettings.Quality.LOW)
	screen.set_resolution_scale(0.75)
	screen.set_vsync(false)
	var loaded := GraphicsSettings.load_saved(PATH)
	assert_eq(loaded.quality, GraphicsSettings.Quality.LOW)
	assert_almost_eq(loaded.resolution_scale, 0.75, 0.001)
	assert_false(loaded.vsync_enabled)


func test_camera_sensitivity_persists_and_is_clamped() -> void:
	screen.set_sensitivity(1.75)
	assert_almost_eq(ControlSettings.load_saved(PATH).sensitivity, 1.75, 0.001)
	screen.set_sensitivity(99.0)
	assert_almost_eq(ControlSettings.load_saved(PATH).sensitivity, ControlSettings.MAX_SENSITIVITY, 0.001)


func test_rebinding_a_key_changes_the_input_map_and_persists() -> void:
	screen.start_rebind(&"fighter_grab")
	assert_eq(screen.rebinding, &"fighter_grab")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_H
	key.pressed = true
	screen._input(key)
	assert_eq(screen.rebinding, &"")
	assert_eq(ControlSettings.key_label(&"fighter_grab"), "H")
	assert_eq(ControlSettings.load_saved(PATH).key_overrides.get(&"fighter_grab"), KEY_H)
	screen.reset_keys()
	assert_eq(ControlSettings.key_label(&"fighter_grab"), "F")


func test_escape_cancels_a_rebind() -> void:
	screen.start_rebind(&"fighter_dash")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	screen._input(key)
	assert_eq(screen.rebinding, &"")
	assert_eq(ControlSettings.key_label(&"fighter_dash"), "Shift")


func test_settings_load_back_into_a_new_screen() -> void:
	screen.set_volume(&"UI", 0.3)
	screen.set_sensitivity(0.5)
	var again := SettingsScreen.new()
	again.save_path = PATH
	add_child_autofree(again)
	assert_almost_eq(again.sliders[&"UI"].value, 0.3, 0.001)
	assert_almost_eq(again.sliders[&"sensitivity"].value, 0.5, 0.001)


func test_tabs_switch_pages() -> void:
	screen.show_tab(&"controls")
	assert_true(screen._pages[&"controls"].visible)
	assert_false(screen._pages[&"audio"].visible)
