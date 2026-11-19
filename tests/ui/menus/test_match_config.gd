extends GutTest
## T-128: the MatchConfig autoload: launch target, level configure() and the
## fallback arena seating the picked legends.

const FakeLevel := preload("res://tests/ui/menus/fake_level.gd")

var _config: Node
var _saved: Dictionary
var _saved_scene := ""


func before_each() -> void:
	_config = get_node(^"/root/MatchConfig")
	_saved = _config.to_dictionary()
	_saved_scene = _config.launched_scene


func after_each() -> void:
	_config.set_config(_saved)
	_config.launched_scene = _saved_scene
	get_tree().paused = false


func test_match_config_is_an_autoload() -> void:
	assert_not_null(_config)
	assert_true(_config.has_method(&"launch"))


func test_launch_targets_zone_match_when_present_else_test_arena() -> void:
	var expected: String = _config.ZONE_MATCH_SCENE if ResourceLoader.exists(_config.ZONE_MATCH_SCENE) else _config.FALLBACK_SCENE
	assert_eq(_config.match_scene_path(), expected)
	assert_true(ResourceLoader.exists(_config.match_scene_path()))


func test_fallback_is_the_test_arena_without_zone_match() -> void:
	if ResourceLoader.exists(_config.ZONE_MATCH_SCENE):
		pass_test("zone_match.tscn exists; fallback not used")
		return
	assert_eq(_config.match_scene_path(), "res://game/levels/test_arena.tscn")


func test_set_config_round_trips_the_contract() -> void:
	var config := MatchRules.build_vs_ai(&"vexa", [{"character": &"kael", "ai_level": 5}], &"skyhold_ruins", 1)
	_config.set_config(config)
	assert_eq(_config.to_dictionary(), config)


func test_level_is_configured_before_it_enters_the_tree() -> void:
	_config.set_config(MatchRules.build_vs_ai(&"kael", [{"character": &"vexa", "ai_level": 2}], &"ember_rift"))
	var packed := PackedScene.new()
	var template := FakeLevel.new()
	packed.pack(template)
	template.free()
	var level: Node = _config.prepare_level(packed)
	assert_false(level.is_inside_tree())
	assert_eq(level.config.zone, &"ember_rift")
	assert_eq(level.config.fighters.size(), 2)
	level.free()


func test_zone_match_accepts_the_menu_config() -> void:
	if not ResourceLoader.exists(_config.ZONE_MATCH_SCENE):
		pass_test("zone_match.tscn not merged yet")
		return
	_config.set_config(MatchRules.build_vs_ai(&"lyra", [{"character": &"brann", "ai_level": 4}], &"heartbloom_gardens"))
	var level: Node = _config.prepare_level(load(_config.ZONE_MATCH_SCENE))
	assert_eq(level.get(&"zone_id"), &"heartbloom_gardens")
	level.free()


func test_launched_level_gets_a_match_session() -> void:
	_config.launched_scene = "res://tests/fake_zone_match.tscn"
	var level := FakeLevel.new()
	level.scene_file_path = _config.launched_scene
	get_tree().root.add_child(level)
	await wait_process_frames(2)
	assert_not_null(level.get_node_or_null(^"MatchSession"))
	level.queue_free()
	await wait_process_frames(1)


func test_fallback_arena_seats_the_picked_legends() -> void:
	_config.set_config(MatchRules.build_vs_ai(&"vexa", [{"character": &"kael", "ai_level": 3}], &"ember_rift"))
	_config.launched_scene = _config.FALLBACK_SCENE
	var arena := (load(_config.FALLBACK_SCENE) as PackedScene).instantiate()
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(arena)
	assert_eq((arena.get_node(^"Fighter1") as FighterView).character_id, &"vexa")
	assert_eq((arena.get_node(^"Fighter2") as FighterView).character_id, &"kael")
	await wait_process_frames(1)
	assert_not_null(arena.get_node_or_null(^"MatchSession"))
	arena.queue_free()
	await wait_process_frames(1)


func test_camera_sensitivity_reaches_fighter_cameras() -> void:
	_config.launched_scene = "res://tests/fake_zone_match.tscn"
	_config.controls.sensitivity = 2.0
	var camera := FighterCamera.new()
	add_child_autofree(camera)
	assert_almost_eq(camera.mouse_sensitivity, ControlSettings.BASE_MOUSE_SENSITIVITY * 2.0, 0.00001)
	_config.controls.sensitivity = 1.0
