extends GutTest
## T-D36: the web export must ship real zone data and no desktop-only extension.

const PRESETS_PATH := "res://export_presets.cfg"


func _web_exclude_filter() -> String:
	var config := ConfigFile.new()
	assert_eq(config.load(PRESETS_PATH), OK, "export_presets.cfg loads")
	for section in config.get_sections():
		if config.get_value(section, "platform", "") == "Web":
			return config.get_value(section, "exclude_filter", "")
	return ""


func test_exports_keep_text_resources_as_text() -> void:
	# Godot 4.7.2's text-to-binary export conversion empties Packed*Array values (zone spawns).
	assert_false(ProjectSettings.get_setting("editor/export/convert_text_resources_to_binary", true))


func test_zone_data_keeps_its_spawn_points() -> void:
	var zone := load("res://game/world/zones/shattered_mesa.tres") as ZoneData
	assert_eq(zone.spawn_points.size(), 2)


func test_web_build_leaves_out_the_webrtc_native_extension() -> void:
	assert_string_contains(_web_exclude_filter(), "addons/webrtc_native/*")


func test_web_main_menu_has_no_quit() -> void:
	var ids := MainMenu.entries(true).map(func(entry: Dictionary) -> StringName: return entry.id)
	assert_false(ids.has(&"quit"))
	assert_true(ids.has(&"vs_ai"))
	assert_true(ids.has(&"duo"), "Duo stays: the web build has WebRTC built in")


func test_desktop_main_menu_keeps_quit() -> void:
	var ids := MainMenu.entries(false).map(func(entry: Dictionary) -> StringName: return entry.id)
	assert_true(ids.has(&"quit"))
