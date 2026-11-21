extends SceneTree
## Look-dev stills and clips of a character on the neutral stage
## (.claude/skills/voxel-character-lookdev/SKILL.md, step 3).
##   godot --path . --disable-vsync -s res://game/lookdev/lookdev_capture.gd -- <out dir>
##       [quick|turntable|closeups|knockdown|feet|spin|idle|compare|all]
##       --scene=res://game/characters/<name>_voxel/<name>_voxel.tscn
##       [--compare=<old scene>] [--hand=RightHand] [--hand-yaw=0]
## Needs a GPU (not headless); renders at exactly 1920x1080 through a
## SubViewport. spin and idle write numbered PNG frames (30 fps) for ffmpeg;
## compare renders the old scene at the same angles (skipped without --compare).

const USAGE := "lookdev_capture.gd -- <out dir> [mode] --scene=<character scene> [--compare=<old scene>] [--hand=RightHand] [--hand-yaw=0] [--hide-stowed]"
const CLIP_FPS := 30
## The knockdown still: stun length and the tick she lies on the floor.
const KNOCKDOWN_TICKS := 90
const KNOCKDOWN_LIE_TICK := 30

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
	if what in ["knockdown", "all"]:
		await _knockdown()
	if what in ["feet", "all"]:
		await _feet()
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


## Knocked down and lying on the floor (the game's KNOCKDOWN state), seen
## low from the side and from a 3/4 angle, so the hat's floor contact shows.
func _knockdown() -> void:
	_fighter.enter_state(FighterState.State.KNOCKDOWN)
	_fighter.stun_ticks = KNOCKDOWN_TICKS
	for t in KNOCKDOWN_LIE_TICK:
		_fighter.state_ticks += 1
		_fighter.stun_ticks -= 1
		_view.apply_state(_fighter, 1.0 / 60.0)
		await process_frame
	for shot: Vector2 in [Vector2(90.0, -3.0), Vector2(35.0, -12.0)]:
		_pivot.rotation.y = deg_to_rad(shot.x)
		_stage.frame(Vector3(0, 0.25, 0), 0.9, 0.5, shot.y)
		await _save("knockdown_%03d" % int(shot.x))
	await _spawn(_scene)


## Standing in guard, seen low at the boots from the side and a 3/4 angle, so the soles'
## contact with the floor shows.
func _feet() -> void:
	_fighter.enter_state(FighterState.State.BLOCKING)
	_fighter.blocking = true
	await _advance(40)
	for shot: Vector2 in [Vector2(90.0, -2.0), Vector2(35.0, -8.0)]:
		_pivot.rotation.y = deg_to_rad(shot.x)
		_stage.frame(Vector3(0, 0.12, 0), 0.45, 0.5, shot.y)
		await _save("feet_%03d" % int(shot.x))
	await _spawn(_scene)


func _head(name: String) -> void:
	_pivot.rotation.y = deg_to_rad(-28.0)
	var head := _bone_position(&"Head") + Vector3(0, 0.17, 0)
	# Frame from the chin to the figure's real top (tall ears, hats, hair
	# spikes), and wide enough for a brim; a normal head keeps the 0.62 m span.
	var chin := head.y - 0.4  # below the chin: the -6° pitch eats the bottom margin
	var extent := _figure_top_and_width(head)
	var top := maxf(head.y + 0.31, extent.x + 0.04)
	var span := maxf(top - chin, extent.y / (16.0 / 9.0) * 1.15)
	var centre := Vector3(head.x, (chin + top) * 0.5, head.z)
	_stage.camera.fov = 24.0
	_stage.frame(centre, maxf(span, 0.62), 0.9, -6.0)
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


## The figure's highest point (x) and its widest extent around the head (y),
## in world space: the rest-pose vertices above the neck and within 0.6 m of
## the head (ears, hat, hair; not the T-posed arms), carried by the Head pose.
func _figure_top_and_width(head: Vector3) -> Vector2:
	var skeleton := _view.model.get_node("%GeneralSkeleton") as Skeleton3D
	var hb := skeleton.find_bone(&"Head")
	var rest := skeleton.get_bone_global_rest(hb).origin
	var pose := skeleton.global_transform * skeleton.get_bone_global_pose(hb) 		* skeleton.get_bone_global_rest(hb).affine_inverse()
	var top := head.y
	var width := 0.0
	for mi: MeshInstance3D in skeleton.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.visible:
			continue
		for si in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for v in verts:
				if v.y < rest.y - 0.08 or Vector2(v.x - rest.x, v.z - rest.z).length() > 0.6:
					continue
				var w := pose * v
				top = maxf(top, w.y)
				width = maxf(width, absf(w.x - head.x) * 2.0)
	return Vector2(top, width)


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
