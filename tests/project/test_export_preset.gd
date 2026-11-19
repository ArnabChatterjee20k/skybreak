extends GutTest

const PRESETS_PATH := "res://export_presets.cfg"


func _windows_preset() -> Dictionary:
	var config := ConfigFile.new()
	assert_eq(config.load(PRESETS_PATH), OK, "export_presets.cfg loads")
	for section in config.get_sections():
		if config.get_value(section, "platform", "") == "Windows Desktop":
			return {
				"exclude_filter": config.get_value(section, "exclude_filter", ""),
				"embed_pck": config.get_value(section + ".options", "binary_format/embed_pck", false),
			}
	return {}


func test_windows_preset_exists() -> void:
	assert_false(_windows_preset().is_empty())


func test_windows_build_leaves_out_tests_and_gut() -> void:
	var exclude: String = _windows_preset().get("exclude_filter", "")
	assert_string_contains(exclude, "tests/*")
	assert_string_contains(exclude, "addons/gut/*")


func test_windows_build_is_a_single_exe() -> void:
	assert_true(_windows_preset().get("embed_pck", false))
