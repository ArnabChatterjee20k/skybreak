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
const ASPECT := 16.0 / 9.0
## Close-up margins, as a fraction of the frame's half-extent.
const HEAD_PAD := 0.16
const HAND_PAD := 0.14
## How far below the head joint the jaw ends (the head close-up's lower bound).
const JAW_BELOW_HEAD := 0.1
## Widest a head with hair, ears or a brim reaches from the neck (m).
const HEAD_RADIUS := 0.3

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
	LookdevStage.configure_viewport(_viewport)
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
			await _save("spin/f_%04d" % i, 2)
		_pivot.rotation.y = 0.0
	if what in ["idle", "all"]:
		DirAccess.make_dir_recursive_absolute(_out.path_join("idle"))
		_pivot.rotation.y = deg_to_rad(30.0)
		_stage.frame(Vector3(0, 0.93, 0), 1.9, 0.82, -4.0)
		for i in CLIP_FPS * 6:
			await _advance(2)
			await _save("idle/f_%04d" % i, 2)
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


## The head close-up, framed from the head's measured posed vertices (hair,
## ears, hats included) with padding; the camera tilts down further while big
## shoulder pieces would cover the face.
func _head(name: String) -> void:
	_pivot.rotation.y = deg_to_rad(-28.0)
	await _advance(1)
	var head := PackedVector3Array()
	var joint := _bone_position(&"Head")
	# A long beard and parts of big shoulder pieces are skinned to the head
	# too; the face is framed from the jaw up, within HEAD_RADIUS of the neck.
	for p in LookdevFraming.skinned_points(_skeleton(), is_head_bone, 2):
		if p.y >= joint.y - JAW_BELOW_HEAD and Vector2(p.x - joint.x, p.z - joint.z).length() <= HEAD_RADIUS:
			head.append(p)
	var shoulders := LookdevFraming.skinned_points(_skeleton(), is_shoulder_bone, 3)
	_stage.camera.fov = 24.0
	# Swing round toward the front and tilt down until the shoulder pieces
	# stop covering the face; failing that, the clearest view.
	var face := face_marks(head, view_basis(-6.0, 0.0), _bone_position(&"Head").y + 0.1)
	var best := [-INF, -6.0, 0.0]
	for yaw: float in [0.0, 8.0, 16.0, 24.0]:
		for pitch: float in [-6.0, -10.0, -14.0, -18.0]:
			var basis := view_basis(pitch, yaw)
			var eye := LookdevFraming.fit(head, basis, _stage.camera.fov, ASPECT, HEAD_PAD)
			var clear := LookdevFraming.clearance(eye, face, shoulders, 0.01, 0.1)
			if clear > best[0]:
				best = [clear, pitch, yaw]
		if best[0] >= 0.0:
			break
	var pitch: float = best[1]
	_place(head, pitch, best[2], HEAD_PAD)
	print("%s: %d head points, pitch %.0f, yaw %.0f, face clear by %.3f m, inside frame %s" % [name, head.size(), pitch, best[2], best[0], _inside(head)])
	await _save(name)
	_stage.camera.fov = 30.0


## The signature-part close-up (hand, fingers and gauntlet forearm), framed
## from their measured posed vertices with padding, so the fist isn't cropped.
func _hand(name: String) -> void:
	_pivot.rotation.y = deg_to_rad(_hand_yaw_deg)
	await _advance(1)
	var side := "Left" if String(_hand_bone).begins_with("Left") else "Right"
	var hand := LookdevFraming.skinned_points(_skeleton(), LookdevFraming.hand_bones(side), 2)
	_stage.camera.fov = 24.0
	_place(hand, -8.0, 0.0, HAND_PAD)
	print("%s: %d hand points, inside frame %s" % [name, hand.size(), _inside(hand)])
	await _save(name)
	_stage.camera.fov = 30.0


## Puts the camera at `pitch_deg` / `yaw_deg` (as LookdevStage.frame) where
## all `points` fit with `pad` margin.
func _place(points: PackedVector3Array, pitch_deg: float, yaw_deg: float, pad: float) -> void:
	var basis := view_basis(pitch_deg, yaw_deg)
	var eye := LookdevFraming.fit(points, basis, _stage.camera.fov, ASPECT, pad)
	_stage.camera.global_transform = Transform3D(basis, eye)


func _inside(points: PackedVector3Array) -> bool:
	var cam := _stage.camera
	return LookdevFraming.inside_frame(points, cam.global_position, cam.global_basis, cam.fov, ASPECT)


## Camera orientation looking at the subject from yaw (0 = front, +Z) and
## pitch (negative = looking down), like LookdevStage.frame.
static func view_basis(pitch_deg: float, yaw_deg: float) -> Basis:
	var up := deg_to_rad(-pitch_deg)
	var yaw := deg_to_rad(yaw_deg)
	var dir := Vector3(sin(yaw) * cos(up), sin(up), cos(yaw) * cos(up))
	return Basis.looking_at(-dir, Vector3.UP)


static func is_head_bone(bone: String) -> bool:
	for part: String in ["Head", "Jaw", "Eye", "Hair", "Ear"]:
		if bone.contains(part):
			return true
	return false


static func is_shoulder_bone(bone: String) -> bool:
	return bone in ["Chest", "UpperChest", "LeftShoulder", "RightShoulder", "LeftUpperArm", "RightUpperArm"]


## Head points facing the camera at eye height (`eye_y` +- 6 cm): the face
## a big beard or collar mustn't decide the tilt by.
static func face_marks(head: PackedVector3Array, basis: Basis, eye_y: float) -> PackedVector3Array:
	var centre := Vector3.ZERO
	for p in head:
		centre += p
	centre /= maxf(head.size(), 1.0)
	var marks := PackedVector3Array()
	for p in head:
		if absf(p.y - eye_y) < 0.06 and (p - centre).dot(basis.z) > 0.0:
			marks.append(p)
	return marks


func _skeleton() -> Skeleton3D:
	return _view.model.get_node("%GeneralSkeleton") as Skeleton3D


func _bone_position(bone: StringName) -> Vector3:
	var skeleton := _view.model.get_node("%GeneralSkeleton") as Skeleton3D
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


## settle: frames to wait first (TAA converges on a still; clips move on).
func _save(name: String, settle := LookdevStage.TAA_SETTLE_FRAMES) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(_out.path_join(name + ".png"))


## --hide-stowed: look-dev only, hides a view's stowed weapons (views with
## stowed_weapons(); they're still the old smooth meshes).
func _hide_weapons(view: CharacterView) -> void:
	if _hide_stowed and view.has_method(&"stowed_weapons"):
		for w: Node3D in view.call(&"stowed_weapons"):
			w.visible = false
