extends GutTest
## The zone capture reports the renderer it actually ran on, not a fixed label.

const SOURCE := "res://game/world/voxel_zone_kit/zone_capture.gd"


func test_the_shot_timing_line_names_the_real_video_adapter() -> void:
	var text := FileAccess.get_file_as_string(SOURCE)
	assert_false(text.contains("(software)"), "no hard-coded renderer label")
	assert_true(text.contains("RenderingServer.get_video_adapter_name()"), "prints the adapter name")
