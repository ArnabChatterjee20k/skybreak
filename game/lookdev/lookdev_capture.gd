extends SceneTree
## Look-dev stills and clips of a character on the neutral stage
## (.claude/skills/voxel-character-lookdev/SKILL.md, step 3).
##   godot --path . --disable-vsync -s res://game/lookdev/lookdev_capture.gd -- <out dir>
##       [quick|turntable|closeups|knockdown|spin|idle|compare|all]
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
## The hand close-up's fit margin: a little over the 10% safe area (a fifth
## of each half-extent), so the fist sits inside it with room to spare.
const HAND_PAD := 0.24
## The safe area the whole fist must stay inside, as a fraction of the frame.
const HAND_SAFE := 0.1
const HAND_FOV := 24.0
## Frames the test waits to check the fist holds still as a still settles.
const HAND_SETTLE_CHECK := LookdevStage.TAA_SETTLE_FRAMES
## Forearm within this of the wrist joint is the gauntlet's cuff (m).
const HAND_CUFF := 0.12
## Camera angles the hand close-up searches (yaw 0 = front, + = figure's left).
## Past about 45 degrees the frame runs off the cyclorama's side edge.
const HAND_YAWS: Array[float] = [0.0, -15.0, 15.0, -30.0, 30.0, -45.0, 45.0]
const HAND_PITCHES: Array[float] = [-10.0, -20.0, -30.0, 0.0, 10.0]
## Closest the close-up's eye may come to any other part of the body (m).
const HAND_EYE_CLEAR := 0.15
## How far below the head joint the jaw ends (the head close-up's lower bound).
const JAW_BELOW_HEAD := 0.1
## Widest a head with hair, ears or a brim reaches from the neck (m).
const HEAD_RADIUS := 0.3
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
## Set by setup(): the node the capture builds under (tests); else this tree.
var _host: Node
## Renders go through a fixed-size viewport so stills and clips are exactly
## 1920x1080 whatever the window's client area is.
var _viewport: SubViewport
var _stage: LookdevStage
var _pivot: Node3D
var _view: CharacterView
var _fighter := FighterState.new()
## The skeleton's last final pose (modifiers applied), for measuring.
var _poses: Array[Transform3D] = []


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


## Builds the stage under `host` without capturing (tests).
func setup(host: Node, scene: String, hand := &"RightHand") -> void:
	_host = host
	_scene = scene
	_hand_bone = hand
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_host.add_child(_viewport)
	_stage = LookdevStage.new()
	_viewport.add_child(_stage)
	await _spawn(_scene)


func _tree() -> SceneTree:
	return _host.get_tree() if _host != null else self


func _spawn(scene: String) -> void:
	if _pivot != null:
		_pivot.queue_free()
		await _tree().process_frame
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
	_poses.clear()
	var skeleton := _skeleton()
	skeleton.skeleton_updated.connect(func() -> void: _poses = LookdevFraming.pose_snapshot(skeleton))
	_fighter = FighterState.new()
	_fighter.enter_state(FighterState.State.IDLE)
	await _advance(40)


func _advance(ticks: int, delta := 1.0 / 60.0) -> void:
	for t in ticks:
		_fighter.state_ticks += 1
		_view.apply_state(_fighter, delta)
		await _tree().process_frame


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


## Knocked down and lying on the floor (the game's KNOCKDOWN state), seen
## low from the side and from a 3/4 angle, so the hat's floor contact shows.
func _knockdown() -> void:
	_fighter.enter_state(FighterState.State.KNOCKDOWN)
	_fighter.stun_ticks = KNOCKDOWN_TICKS
	for t in KNOCKDOWN_LIE_TICK:
		_fighter.state_ticks += 1
		_fighter.stun_ticks -= 1
		_view.apply_state(_fighter, 1.0 / 60.0)
		await _tree().process_frame
	for shot: Vector2 in [Vector2(90.0, -3.0), Vector2(35.0, -12.0)]:
		_pivot.rotation.y = deg_to_rad(shot.x)
		_stage.frame(Vector3(0, 0.25, 0), 0.9, 0.5, shot.y)
		await _save("knockdown_%03d" % int(shot.x))
	await _spawn(_scene)


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
	for p in _points(is_head_bone, 2):
		if p.y >= joint.y - JAW_BELOW_HEAD and Vector2(p.x - joint.x, p.z - joint.z).length() <= HEAD_RADIUS:
			head.append(p)
	var shoulders := _points(is_shoulder_bone, 3)
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


## The signature-part close-up: the fist and gauntlet cuff, framed from
## their measured posed vertices inside the safe area (hand_shot()).
func _hand(name: String) -> void:
	var r := await hand_shot()
	print("%s: %d fist points, pitch %.0f, yaw %.0f, safe-area margin %.3f, shoulder overlap %.4f, clutter %.2f, eye clear by %.2f m" % [
		name, r["fist"].size(), r["pitch"], r["yaw"], r["margin"], r["overlap"], r["clutter"], r["eye_clear"]])
	await _save(name)
	var after := LookdevFraming.screen_box(_fist_points(), _stage.camera.global_transform, HAND_FOV, ASPECT)
	print("%s: margin after settling %.3f" % [name, LookdevFraming.safe_margin(after, HAND_SAFE)])
	_stage.camera.fov = 30.0


## Places the hand close-up camera: of the searched angles, the one where the
## fist's screen box stays clear of the shoulder pieces (Brann's boulders) and
## least of the body sits behind or in front of it, so it reads against the
## backdrop. Returns the fist points, the angle and the measured margins.
func hand_shot() -> Dictionary:
	_pivot.rotation.y = deg_to_rad(_hand_yaw_deg)
	await _advance(1)
	var side := _hand_side()
	var fist := _fist_points()
	var arm := LookdevFraming.hand_bones(side)
	var shoulders := _points(is_shoulder_piece_bone, 2)
	var clutter := _points(func(b: String) -> bool:
		return not arm.call(b) and not is_shoulder_piece_bone(b), 3)
	clutter.append_array(LookdevFraming.rigid_points(_view.model, 3))
	# What the eye mustn't sit in: everything but the fist itself.
	var body := clutter.duplicate()
	body.append_array(shoulders)
	body.append_array(_points(func(b: String) -> bool: return b == side + "LowerArm", 3))
	_stage.camera.fov = HAND_FOV
	var best := {}
	for pitch: float in HAND_PITCHES:
		for yaw: float in HAND_YAWS:
			var basis := view_basis(pitch, yaw)
			var xf := Transform3D(basis, LookdevFraming.fit(fist, basis, HAND_FOV, ASPECT, HAND_PAD))
			var inside := nearest(xf.origin, body) < HAND_EYE_CLEAR
			var box := LookdevFraming.screen_box(fist, xf, HAND_FOV, ASPECT)
			var overlap := LookdevFraming.cover(box, shoulders, xf, HAND_FOV, ASPECT, 24)
			var covered := LookdevFraming.cover(box, clutter, xf, HAND_FOV, ASPECT)
			# Clear of the shoulders first, then the cleanest backdrop, then
			# the angle nearest the front at a gentle tilt.
			var score := (100.0 if inside else 0.0) + (10.0 if overlap > 0.0 else 0.0) + covered + absf(yaw) * 0.001 + absf(pitch + 10.0) * 0.002
			if best.is_empty() or score < best["score"]:
				best = {"score": score, "pitch": pitch, "yaw": yaw, "xf": xf, "overlap": overlap, "clutter": covered, "eye_clear": nearest(xf.origin, body)}
	_stage.camera.global_transform = best["xf"]
	var cam: Transform3D = best["xf"]
	return {
		"fist": fist, "shoulders": shoulders, "camera": cam, "pitch": best["pitch"], "yaw": best["yaw"],
		"overlap": best["overlap"], "clutter": best["clutter"], "eye_clear": best["eye_clear"],
		"margin": LookdevFraming.safe_margin(LookdevFraming.screen_box(fist, cam, HAND_FOV, ASPECT), HAND_SAFE),
	}


## The fist: every hand and finger vertex plus the forearm's cuff near the wrist.
func _fist_points() -> PackedVector3Array:
	var side := _hand_side()
	var wrist := _bone_position(StringName(side + "Hand"))
	var out := _points(LookdevFraming.hand_bones(side, false), 1)
	for p in _points(func(b: String) -> bool: return b == side + "LowerArm", 1):
		if p.distance_to(wrist) <= HAND_CUFF:
			out.append(p)
	return out


func _hand_side() -> String:
	return "Left" if String(_hand_bone).begins_with("Left") else "Right"


## Distance from `at` to the nearest of `points`.
static func nearest(at: Vector3, points: PackedVector3Array) -> float:
	var best := INF
	for p in points:
		best = minf(best, at.distance_squared_to(p))
	return sqrt(best)


## Shoulder pieces: Brann's boulders, pauldrons, shoulder pads.
static func is_shoulder_piece_bone(bone: String) -> bool:
	return bone in ["LeftShoulder", "RightShoulder"]


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
	for part: String in ["Head", "Jaw", "Eye", "Hair", "Ear", "Hat"]:
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


## Posed vertices whose strongest bone passes `keep`, every `stride`-th.
func _points(keep: Callable, stride := 1) -> PackedVector3Array:
	return LookdevFraming.skinned_points(_skeleton(), keep, stride, _poses)


func _skeleton() -> Skeleton3D:
	return _view.model.get_node("%GeneralSkeleton") as Skeleton3D


func _bone_position(bone: StringName) -> Vector3:
	var skeleton := _skeleton()
	var i := skeleton.find_bone(bone)
	var pose := _poses[i] if i < _poses.size() else skeleton.get_bone_global_pose(i)
	return skeleton.global_transform * pose.origin


## settle: frames to wait first (TAA converges on a still; clips move on).
func _save(name: String, settle := LookdevStage.TAA_SETTLE_FRAMES) -> void:
	for i in settle:
		await _tree().process_frame
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(_out.path_join(name + ".png"))


## --hide-stowed: look-dev only, hides a view's stowed weapons (views with
## stowed_weapons(); they're still the old smooth meshes).
func _hide_weapons(view: CharacterView) -> void:
	if _hide_stowed and view.has_method(&"stowed_weapons"):
		for w: Node3D in view.call(&"stowed_weapons"):
			w.visible = false
