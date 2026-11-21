extends SceneTree
## Look-dev stills and clips of a character on the neutral stage
## (.claude/skills/voxel-character-lookdev/SKILL.md, step 3).
##   godot --path . --disable-vsync -s res://game/lookdev/lookdev_capture.gd -- <out dir>
##       [quick|turntable|closeups|spin|idle|compare|all]
##       --scene=res://game/characters/<name>_voxel/<name>_voxel.tscn
##       [--compare=<old scene>] [--hand=RightHand] [--hand-yaw=0]
## Needs a GPU (not headless); renders at exactly 1920x1080 through a
## SubViewport. spin and idle write numbered PNG frames (30 fps) for ffmpeg;
## compare renders the old scene at the same angles (skipped without --compare).

const USAGE := "lookdev_capture.gd -- <out dir> [mode] --scene=<character scene> [--compare=<old scene>] [--hand=RightHand] [--hand-yaw=0] [--hide-stowed]"
const CLIP_FPS := 30

var _scene := ""
var _compare := ""
## The signature-part close-up: this hand bone, the figure turned by hand_yaw.
var _hand_bone := &"RightHand"
var _hand_yaw_deg := 0.0
var _hide_stowed := false

var _out := ""
## Renders go through a fixed-size viewport so stills and clips are exactly
## 1920x1080 whatever the window's client area is.
var _viewport: SubViewport
var _stage: LookdevStage
var _pivot: Node3D
var _view: CharacterView
var _fighter := FighterState.new()


func _initialize() -> void:
	var args := LookdevArgs.parse()
	_out = args.pos(0)
	var what := args.pos(1, "quick")
	_scene = args.need("scene", USAGE)
	_compare = args.get_option("compare")
	_hand_bone = StringName(args.get_option("hand", "RightHand"))
	_hand_yaw_deg = float(args.get_option("hand-yaw", "0"))
	_hide_stowed = args.options.has("hide-stowed")
	if _scene == "" or _out == "":
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.msaa_3d = root.msaa_3d if root.msaa_3d != Viewport.MSAA_DISABLED else Viewport.MSAA_4X
	_viewport.screen_space_aa = root.screen_space_aa
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_stage = LookdevStage.new()
	_viewport.add_child(_stage)
	_run.call_deferred(what)


func _spawn(scene: String) -> void:
	if _pivot != null:
		_pivot.queue_free()
		await process_frame
	_pivot = Node3D.new()
	_stage.add_child(_pivot)
	# The view's model faces -Z; turn it so yaw 0 faces the camera (+Z).
	var facing := Node3D.new()
	facing.rotation.y = PI
	_pivot.add_child(facing)
	_view = (load(scene) as PackedScene).instantiate() as CharacterView
	var body := Node3D.new()
	body.position = Vector3(0, 1, 0)
	facing.add_child(body)
	body.add_child(_view)
	_hide_weapons(_view)
	_fighter = FighterState.new()
	_fighter.enter_state(FighterState.State.IDLE)
	await _advance(40)


func _advance(ticks: int, delta := 1.0 / 60.0) -> void:
	for t in ticks:
		_fighter.state_ticks += 1
		_view.apply_state(_fighter, delta)
		await process_frame


func _run(what: String) -> void:
	var started := Time.get_ticks_msec()
	await _spawn(_scene)
	print("%s built and posed in %d ms" % [_scene.get_file(), Time.get_ticks_msec() - started])
	if what in ["quick"]:
		for yaw: float in [0.0, 35.0, 90.0, 180.0]:
			await _full(yaw, "quick_%03d" % int(yaw))
		await _head("quick_head")
		await _hand("quick_hand")
	if what in ["turntable", "all"]:
		for k in 8:
			await _full(k * 45.0, "turntable_%03d" % (k * 45))
	if what in ["closeups", "all"]:
		await _head("closeup_head")
		await _hand("closeup_gauntlet")
	if what in ["spin", "all"]:
		DirAccess.make_dir_recursive_absolute(_out.path_join("spin"))
		_stage.frame(Vector3(0, 0.93, 0), 1.9, 0.82, -4.0)
		var frames := CLIP_FPS * 6
		for i in frames:
			_pivot.rotation.y = TAU * i / frames
			await _advance(2)
			await _save("spin/f_%04d" % i)
		_pivot.rotation.y = 0.0
	if what in ["idle", "all"]:
		DirAccess.make_dir_recursive_absolute(_out.path_join("idle"))
		_pivot.rotation.y = deg_to_rad(30.0)
		_stage.frame(Vector3(0, 0.93, 0), 1.9, 0.82, -4.0)
		for i in CLIP_FPS * 6:
			await _advance(2)
			await _save("idle/f_%04d" % i)
	if what in ["compare", "all"] and _compare != "":
		for yaw: float in [0.0, 35.0, 180.0]:
			await _full(yaw, "compare_voxel_%03d" % int(yaw))
		await _spawn(_compare)
		for yaw: float in [0.0, 35.0, 180.0]:
			await _full(yaw, "compare_chunky_%03d" % int(yaw))
	quit()


## The whole figure at a turntable angle (yaw 0 = facing the camera).
func _full(yaw: float, name: String) -> void:
	_pivot.rotation.y = deg_to_rad(yaw)
	_stage.frame(Vector3(0, 0.93, 0), 1.9, 0.82, -4.0)
	await _save(name)


func _head(name: String) -> void:
	_pivot.rotation.y = deg_to_rad(-28.0)
	var head := _bone_position(&"Head") + Vector3(0, 0.17, 0)
	_stage.camera.fov = 24.0
	_stage.frame(head, 0.62, 0.9, -6.0)
	await _save(name)
	_stage.camera.fov = 30.0


func _hand(name: String) -> void:
	_pivot.rotation.y = deg_to_rad(_hand_yaw_deg)
	await _advance(1)
	var forearm := StringName(String(_hand_bone).replace("Hand", "LowerArm"))
	var hand := _bone_position(_hand_bone).lerp(_bone_position(forearm), 0.25)
	_stage.camera.fov = 24.0
	_stage.frame(hand, 0.42, 0.8, -8.0, 0.0)
	await _save(name)
	_stage.camera.fov = 30.0


func _bone_position(bone: StringName) -> Vector3:
	var skeleton := _view.model.get_node("%GeneralSkeleton") as Skeleton3D
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


func _save(name: String) -> void:
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(_out.path_join(name + ".png"))


## --hide-stowed: look-dev only, hides a view's stowed weapons (views with
## stowed_weapons(); they're still the old smooth meshes).
func _hide_weapons(view: CharacterView) -> void:
	if _hide_stowed and view.has_method(&"stowed_weapons"):
		for w: Node3D in view.call(&"stowed_weapons"):
			w.visible = false
