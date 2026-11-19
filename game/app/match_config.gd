extends Node
## The match the menus set up, autoloaded as MatchConfig. Holds
## {zone, fighters: [{character, team, is_ai, ai_level}], rounds, mode},
## launches the level and attaches the pause menu and results screen to it.

signal launched(scene_path: String)

const ZONE_MATCH_SCENE := "res://game/levels/zone_match.tscn"
const FALLBACK_SCENE := "res://game/levels/test_arena.tscn"
const FRONT_END_SCENE := "res://game/ui/menus/front_end.tscn"

var zone: StringName = &"stormfall_city"
var fighters: Array[Dictionary] = []
var rounds: int = MatchRules.DEFAULT_ROUNDS
var mode: StringName = MatchRules.MODE_VS_AI
## Screen the front end opens on next: &"" (splash), &"main", &"character_select".
var return_screen: StringName = &""
## Scene path of the last launch.
var launched_scene := ""
var controls: ControlSettings


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputBindings.install_defaults()
	controls = ControlSettings.load_saved()
	controls.apply_bindings()
	get_tree().node_added.connect(_on_node_added)


func set_config(config: Dictionary) -> void:
	zone = config.zone
	fighters.assign(config.fighters)
	rounds = config.rounds
	mode = config.mode


func to_dictionary() -> Dictionary:
	return {"zone": zone, "fighters": fighters.duplicate(true), "rounds": rounds, "mode": mode}


## zone_match.tscn when another lane has added it, else the test arena.
static func match_scene_path() -> String:
	return ZONE_MATCH_SCENE if ResourceLoader.exists(ZONE_MATCH_SCENE) else FALLBACK_SCENE


## Starts the current config. Returns the scene path, or "" if the change failed.
func launch() -> String:
	var path := match_scene_path()
	_reset_engine_state()
	if get_tree().change_scene_to_file(path) != OK:
		return ""
	launched_scene = path
	launched.emit(path)
	return path


## Back to the front end, opening on `screen`.
func return_to_menu(screen: StringName = &"main") -> void:
	return_screen = screen
	_reset_engine_state()
	get_tree().change_scene_to_file(FRONT_END_SCENE)


func _reset_engine_state() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Seats the picked legends in the fallback arena, applies camera sensitivity,
## and gives a match level its pause menu and results screen.
func _on_node_added(node: Node) -> void:
	if launched_scene.is_empty():
		return
	if node is FighterCamera:
		(node as FighterCamera).mouse_sensitivity = controls.mouse_sensitivity()
	elif node is FighterView and launched_scene == FALLBACK_SCENE:
		var slot := int(String(node.name).trim_prefix("Fighter")) - 1
		if slot >= 0 and slot < fighters.size():
			(node as FighterView).character_id = fighters[slot].character
	if node.get_parent() == get_tree().root and node.scene_file_path == launched_scene:
		_configure_level(node)


func _configure_level(level: Node) -> void:
	if level.has_method(&"configure"):
		level.call(&"configure", to_dictionary())
	var session := MatchSession.new()
	session.name = "MatchSession"
	level.add_child.call_deferred(session)
