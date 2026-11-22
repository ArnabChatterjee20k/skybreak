extends SceneTree
## Look-dev stills and clips of the fighter aura on the neutral stage, per hero:
## the ki charge, then power levels 1, 2 and 3. 1920x1080 through a SubViewport.
##   godot --path . --disable-vsync -s res://game/view/shaders/preview/aura_capture.gd -- <out dir>
##       [stills|clip|all] [--heroes=kael,vexa,lyra,brann] [--quality=1.0] [--seconds=6]
##       [--shots=kicharge,level1,level2,level3,close]
## Clips write numbered PNG frames at 30 fps for ffmpeg.

const AURA_SCENE := "res://game/view/shaders/vfx/fighter_aura.tscn"
const HEROES := {
	&"kael": "res://game/characters/kael_voxel/kael_voxel.tscn",
	&"vexa": "res://game/characters/vexa_voxel/vexa_voxel.tscn",
	&"lyra": "res://game/characters/lyra_voxel/lyra_voxel.tscn",
	&"brann": "res://game/characters/brann_voxel/brann_voxel.tscn",
}
const CLIP_FPS := 30
## Seconds the aura plays before a still, so particles are spread out.
const SETTLE_SECONDS := 1.4
## Shot yaw (figure turned toward camera-left, 3/4) and framing.
const YAW_DEG := 28.0

var _out := ""
var _viewport: SubViewport
var _stage: LookdevStage
var _pivot: Node3D
var _view: CharacterView
var _aura: Node3D
var _fighter := FighterState.new()
var _quality := 1.0
var _shots := PackedStringArray()


func _initialize() -> void:
	var args := LookdevArgs.parse()
	_out = args.pos(0)
	var what := args.pos(1, "stills")
	var heroes := args.get_option("heroes", "kael,vexa,lyra,brann").split(",")
	_quality = float(args.get_option("quality", "1.0"))
	var seconds := float(args.get_option("seconds", "6"))
	_shots = args.get_option("shots", "kicharge,level1,level2,level3,close").split(",")
	if _out == "":
		print("usage: aura_capture.gd -- <out dir> [stills|clip|all] [--heroes=...]")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	LookdevStage.configure_viewport(_viewport)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_stage = LookdevStage.new()
	_viewport.add_child(_stage)
	_run.call_deferred(what, heroes, seconds)


func _run(what: String, heroes: PackedStringArray, seconds: float) -> void:
	for hero in heroes:
		var id := StringName(hero)
		await _spawn(id)
		if what in ["stills", "all"]:
			await _stills(id)
		if what in ["clip", "all"]:
			await _clip(id, seconds)
		print("[aura] %s done" % hero)
	print("[aura] finished")
	quit()


func _spawn(id: StringName) -> void:
	if _pivot != null:
		_pivot.queue_free()
		await process_frame
	_pivot = Node3D.new()
	_stage.add_child(_pivot)
	var facing := Node3D.new()
	facing.rotation.y = PI
	_pivot.add_child(facing)
	var body := Node3D.new()
	body.position = Vector3(0, 1, 0)
	facing.add_child(body)
	_view = (load(HEROES[id]) as PackedScene).instantiate() as CharacterView
	body.add_child(_view)
	_aura = (load(AURA_SCENE) as PackedScene).instantiate() as Node3D
	body.add_child(_aura)
	var color := LegendCatalog.color(id)
	_aura.set(&"color", color)
	_aura.set(&"particle_quality", _quality)
	_view.set_energy_color(Color(color, 0.55))
	_fighter = FighterState.new()
	_fighter.enter_state(FighterState.State.IDLE)
	_pivot.rotation.y = deg_to_rad(YAW_DEG)
	await _advance(30)


## Charging ki (CHARGING state, the gather at the chest), then levels 1-3.
func _set_shot(level: float, charging: bool) -> void:
	if _fighter.state != FighterState.State.CHARGING:
		_fighter.enter_state(FighterState.State.CHARGING)
	if &"charging" in _aura:
		_aura.set(&"charging", charging)
	_aura.set(&"power_level", level)


func _stills(id: StringName) -> void:
	var shots := [["kicharge", 1.0, true], ["level1", 1.0, false], ["level2", 2.0, false], ["level3", 3.0, false]]
	for shot: Array in shots:
		if not String(shot[0]) in _shots:
			continue
		_set_shot(shot[1], shot[2])
		_aura.call(&"snap")
		await _advance(int(SETTLE_SECONDS * 60.0))
		_stage.frame(Vector3(0, 1.05, 0), 2.6, 0.78, -6.0)
		await _save("%s_%s" % [id, shot[0]])
	if "close" in _shots:
		_stage.frame(Vector3(0, 1.2, 0), 1.3, 0.8, -6.0)
		await _save("%s_level3_close" % id)


## Off, then the ki charge rising, then levels 1, 2, 3 (eased by the aura itself).
func _clip(id: StringName, seconds: float) -> void:
	var dir := _out.path_join("%s_clip" % id)
	DirAccess.make_dir_recursive_absolute(dir)
	_fighter.enter_state(FighterState.State.IDLE)
	_aura.set(&"power_level", 0.0)
	if &"charging" in _aura:
		_aura.set(&"charging", false)
	_aura.call(&"snap")
	await _advance(20)
	var frames := int(seconds * CLIP_FPS)
	for i in frames:
		var t := float(i) / CLIP_FPS
		var share := t / seconds
		var level := 1.0 if share < 0.45 else (2.0 if share < 0.7 else 3.0)
		_set_shot(level, share < 0.25)
		_stage.frame(Vector3(0, 1.05, 0), 2.6, 0.78, -6.0, 0.0)
		await _advance(2)
		await _save("%s_clip/f_%04d" % [id, i], 0)


func _advance(ticks: int) -> void:
	for t in ticks:
		_fighter.state_ticks += 1
		_view.apply_state(_fighter, 1.0 / 60.0)
		await process_frame


func _save(name: String, settle := LookdevStage.TAA_SETTLE_FRAMES) -> void:
	for i in settle:
		_fighter.state_ticks += 1
		_view.apply_state(_fighter, 1.0 / 60.0)
		await process_frame
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(_out.path_join(name + ".png"))
