extends Node
## The match the menus set up, autoloaded as MatchConfig. Holds
## {zone, fighters: [{character, team, is_ai, ai_level}], rounds, mode},
## launches the level and attaches the pause menu and results screen to it.

signal launched(scene_path: String)

const ZONE_MATCH_SCENE := "res://game/levels/zone_match.tscn"
const FALLBACK_SCENE := "res://game/levels/test_arena.tscn"
const FRONT_END_SCENE := "res://game/ui/menus/front_end.tscn"
const PURE_FIGHT_SCENE := "res://game/modes/pure_fight/pure_fight_match.tscn"

var zone: StringName = &"stormfall_city"
var fighters: Array[Dictionary] = []
var rounds: int = MatchRules.DEFAULT_ROUNDS
var mode: StringName = MatchRules.MODE_VS_AI
## Any other config keys (Duo: seed, lives, minutes), passed through to the level.
var extras: Dictionary = {}
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
	extras = {}
	for key: String in config:
		if not key in ["zone", "fighters", "rounds", "mode"]:
			extras[key] = config[key]


func to_dictionary() -> Dictionary:
	var out := {"zone": zone, "fighters": fighters.duplicate(true), "rounds": rounds, "mode": mode}
	out.merge(extras.duplicate(true))
	return out


## zone_match.tscn when another lane has added it, else the test arena.
static func match_scene_path() -> String:
	return ZONE_MATCH_SCENE if ResourceLoader.exists(ZONE_MATCH_SCENE) else FALLBACK_SCENE


## Starts the current config: the level gets configure() before it enters the
## tree (zone_match requires that). A voxel zone's bake loads first on a
## background thread behind a LoadingScreen. Returns the scene path, or "" on
## failure.
func launch() -> String:
	var path := PURE_FIGHT_SCENE if MatchRules.is_pure_fight(mode) else match_scene_path()
	var bake := zone_bake_path()
	if bake != "" and (path == ZONE_MATCH_SCENE or path == PURE_FIGHT_SCENE) and not VoxelZoneBake.preloaded.has(bake) and is_inside_tree():
		_reset_engine_state()
		var screen := LoadingScreen.new()
		screen.title = String(zone).capitalize()
		screen.paths.assign([path, bake])
		if not ResourceLoader.exists(bake):
			screen.download = ZoneBakeDownload.new(bake)
		screen.done = func(loaded: Dictionary) -> void:
			if loaded.get(bake) is PackedScene:
				VoxelZoneBake.preloaded[bake] = loaded[bake]
			_start(path)
		if get_tree().change_scene_to_node(screen) != OK:
			screen.free()
			return _start(path)
		return path
	return _start(path)


## The zone's voxel bake for the saved quality when the match will draw it, else "".
## On the web it is fetched as a pack (ZoneBakePacks) behind the loading screen.
func zone_bake_path() -> String:
	if not ArtStyle.is_voxel() or not VoxelZoneView.supports(zone):
		return ""
	var bake := VoxelZoneBake.path_for(zone, GraphicsSettings.load_saved().quality)
	return bake if ResourceLoader.exists(bake) or ZoneBakePacks.downloadable(bake) else ""


func _start(path: String) -> String:
	var level := prepare_level(load(path) as PackedScene)
	if level == null:
		return ""
	_reset_engine_state()
	launched_scene = path
	if get_tree().change_scene_to_node(level) != OK:
		level.free()
		launched_scene = ""
		return ""
	launched.emit(path)
	return path


## The level instance, configured but not yet in the tree.
func prepare_level(packed: PackedScene) -> Node:
	if packed == null:
		return null
	var level := packed.instantiate()
	if level.has_method(&"configure"):
		level.call(&"configure", to_dictionary())
	return level


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
		_attach_session(node)


func _attach_session(level: Node) -> void:
	var session := MatchSession.new()
	session.name = "MatchSession"
	level.add_child.call_deferred(session)
