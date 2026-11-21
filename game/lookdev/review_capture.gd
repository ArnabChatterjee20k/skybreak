extends SceneTree
## A self-review set for a voxel character on the look-dev stage: 8 angles,
## head, both fists, both pauldrons, the front gear, the back, and posed
## stills (guard plus named moves at their active frame), each pose from the
## front 3/4 and from above the shoulder. Lavapipe is fine for shape review.
##   godot --path . --disable-vsync -s res://game/lookdev/review_capture.gd -- <out dir>
##       --scene=<character scene> [--moves=res://game/combat/moves/<name>/] [--poses=smash,grab]
## Close-ups frame bones, so it fits any humanoid rig.

const USAGE := "review_capture.gd -- <out dir> --scene=<character scene> [--moves=<folder>] [--poses=a,b]"

var _out := ""
var _viewport: SubViewport
var _stage: LookdevStage
var _pivot: Node3D
var _view: CharacterView
var _f := FighterState.new()


func _initialize() -> void:
	var args := LookdevArgs.parse()
	_out = args.pos(0)
	var scene := args.need("scene", USAGE)
	if scene == "" or _out == "":
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_stage = LookdevStage.new()
	_viewport.add_child(_stage)
	var poses := args.get_option("poses", "")
	_run.call_deferred(scene, args.get_option("moves", ""), poses.split(",", false))


func _run(scene: String, moves: String, poses: PackedStringArray) -> void:
	_pivot = Node3D.new()
	_stage.add_child(_pivot)
	var facing := Node3D.new()
	facing.rotation.y = PI
	_pivot.add_child(facing)
	_view = (load(scene) as PackedScene).instantiate() as CharacterView
	var body := Node3D.new()
	body.position = Vector3(0, 1, 0)
	facing.add_child(body)
	body.add_child(_view)
	_f.enter_state(FighterState.State.IDLE)
	await _advance(40)
	for k in 8:
		await _shot(k * 45.0, Vector3(0, 0.93, 0), 1.9, 0.82, -4.0, "angle_%03d" % (k * 45))
	await _close(-28.0, _bone(&"Head") + Vector3(0, 0.12, 0), 0.62, "head")
	await _close(0.0, _bone(&"Head") + Vector3(0, -0.05, 0), 0.75, "head_front", 2.0)
	await _close(-90.0, _bone(&"Head") + Vector3(0, 0.0, 0), 0.8, "head_side", 0.0)
	await _close(30.0, _bone(&"Neck").lerp(_bone(&"Hips"), 0.6), 0.75, "beard_braid", 0.0)
	await _close(-10.0, _bone(&"RightHand"), 0.45, "fist_right", -8.0)
	await _close(150.0, _bone(&"LeftHand"), 0.45, "fist_left_back", -8.0)
	await _close(30.0, _bone(&"LeftShoulder") + Vector3(0, 0.2, 0), 0.6, "boulder_left", -25.0)
	await _close(-30.0, _bone(&"RightShoulder") + Vector3(0, 0.2, 0), 0.6, "boulder_right", -25.0)
	await _close(0.0, _bone(&"Hips") + Vector3(0, -0.15, 0), 0.8, "apron_tools", -6.0)
	await _close(180.0, _bone(&"Chest"), 1.1, "back", -8.0)
	# Poses: guard, then each named move at the middle of its active frames.
	_f = FighterState.new()
	_f.enter_state(FighterState.State.BLOCKING)
	await _advance(30)
	await _pose_shots("guard")
	var dir := moves if moves.ends_with("/") else moves + "/"
	for name in poses:
		var move := load(dir + name + ".tres") as MoveData
		if move == null:
			push_error("no move " + name)
			continue
		for phase: String in ["windup", "active"]:
			_f = FighterState.new()
			_f.enter_state(FighterState.State.IDLE)
			await _advance(4)
			_f.begin_move(move)
			var stop := maxi(move.startup_ticks - 3, 1) if phase == "windup" else move.startup_ticks + move.active_ticks / 2
			while _f.move_tick < stop:
				_f.move_tick += 1
				await _advance(1)
			await _pose_shots("%s_%s" % [name, phase])
	quit()


func _pose_shots(name: String) -> void:
	await _shot(35.0, Vector3(0, 0.95, 0), 2.0, 0.8, -4.0, "pose_" + name)
	await _shot(-60.0, _bone(&"Head") + Vector3(0, -0.15, 0), 0.9, 0.85, -30.0, "pose_%s_top" % name)


func _advance(ticks: int) -> void:
	for t in ticks:
		_f.state_ticks += 1
		_view.apply_state(_f, 1.0 / 60.0)
		await process_frame
	if ticks == 0:
		_view.apply_state(_f, 1.0 / 60.0)


func _shot(yaw: float, target: Vector3, height: float, fill: float, pitch: float, name: String) -> void:
	_pivot.rotation.y = deg_to_rad(yaw)
	await process_frame
	_stage.camera.fov = 30.0
	_stage.frame(_pivot.global_transform * target, height, fill, pitch)
	await _save(name)


func _close(yaw: float, target: Vector3, height: float, name: String, pitch := -6.0) -> void:
	_pivot.rotation.y = deg_to_rad(yaw)
	await process_frame
	await process_frame
	# Bones were read before the turn: re-read the same point after it.
	_stage.camera.fov = 24.0
	_stage.frame(_pivot.global_transform * target, height, 0.9, pitch)
	await _save(name)
	_stage.camera.fov = 30.0


## A bone's position in the pivot's space (independent of the turntable yaw).
func _bone(bone: StringName) -> Vector3:
	var skeleton := _view.model.get_node("%GeneralSkeleton") as Skeleton3D
	var world := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
	return _pivot.global_transform.affine_inverse() * world


func _save(name: String) -> void:
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(_out.path_join(name + ".png"))
