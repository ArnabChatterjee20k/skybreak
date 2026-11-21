class_name QaViewChecks
extends RefCounted
## View invariants checked on every presented frame of a soak match: feet on the
## visible ground, held weapons outside the body, the bow string clear of the head,
## finite bones, pops, and the lock-on camera framing. Also gathers feel metrics
## (pops, foot slide, camera jerk). One instance per match.

## Grounded sole height error allowed against the visible terrain (m).
const FOOT_TOLERANCE := 0.05
## Bone rotation change in one frame that counts as a pop (rad).
const POP_ANGLE := 1.2
## Pops allowed per fighter-minute before the budget fails.
const POP_BUDGET_PER_MINUTE := 2.0
## Torso capsule radius (m) a weapon may not sink into; small so only deep clipping counts.
const TORSO_RADIUS := 0.10
## Share of a weapon's sample points inside the torso that counts as through the body.
const WEAPON_INSIDE_SHARE := 0.25
## Head sphere the bow string must stay out of: centre above the Head bone, radius (m).
const HEAD_LIFT := 0.10
const HEAD_RADIUS := 0.10
## Lock-on framing: both fighters on screen in at least this share of frames.
const ON_SCREEN_SHARE := 0.95
## A fighter's screen box may cover at most this share of the screen.
const MAX_SCREEN_COVER := 0.60
const SCREEN := Vector2(1920, 1080)
## States in which a planted foot must touch the ground; MOVING only may not sink.
const STANDING_STATES: Array[FighterState.State] = [FighterState.State.IDLE,
	FighterState.State.BLOCKING, FighterState.State.CHARGING]
# Foot slide: a foot within FOOT_TOLERANCE of the ground in two consecutive presented
# frames of IDLE counts; floating, sinking or hidden frames break the chain.
## Frames after a match or round start in which slide is not measured (spawn settle).
const SLIDE_SETTLE_FRAMES := 10
## A sim move this large between two frames is a teleport (vanish, reset), not a slide (m).
const TELEPORT_DISTANCE := 0.5
const FOOT_BONES: Array[StringName] = [&"LeftFoot", &"RightFoot"]
const TORSO_BONES: Array[StringName] = [&"Hips", &"UpperChest"]

var level: ZoneMatch
## Per fighter: {skeleton, feet, sole, head, torso, rotations}.
var _rigs: Array[Dictionary] = []
var _weapon_points := {}

# Frame counters for the share-based checks and metrics.
var frames := 0
var locked_frames := 0
var locked_on_screen_frames := 0
var pops := 0
## Finger and thumb pops, kept out of the budget (small on screen) but reported.
var finger_pops := 0
var fighter_frames := 0
var grounded_frames := 0
var foot_errors: Array[float] = []
var foot_slide_sum := 0.0
var foot_slide_frames := 0
## IDLE frames whose lowest foot was off the ground, so left out of the slide.
var foot_slide_skipped := 0
var camera_jerk: Array[float] = []
var _camera_forward: Array[Vector3] = []
## Per fighter: {bone, at, frame, body} of the planted foot last frame.
var _planted_previous := {}
var _settle_until := SLIDE_SETTLE_FRAMES
var _phase := -1


func _init(match_level: ZoneMatch) -> void:
	level = match_level
	if level == null:
		return
	for view in level.fighter_views:
		_rigs.append(_rig_of(view))


## Checks the frame the fighters show now; returns violations like QaSimChecks.
func check_frame() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	frames += 1
	var phase: int = level.match_flow.phase
	if phase != _phase and phase == MatchFlow.Phase.INTRO:
		# New round: everyone is put back on a spawn.
		_planted_previous.clear()
		_settle_until = frames + SLIDE_SETTLE_FRAMES
	_phase = phase
	for i in _rigs.size():
		_check_rig(i, out)
	_check_camera(out)
	return out


## Pops over budget for the whole match, as one violation (or none).
func pop_budget() -> Array[Dictionary]:
	var minutes := fighter_frames / 3600.0
	var allowed := POP_BUDGET_PER_MINUTE * maxf(minutes, 1.0 / 60.0)
	if pops > allowed:
		return [{"check": "pop_budget", "fighter": -1, "value": pops, "limit": allowed,
			"detail": "%d pops in %.1f fighter-minutes (budget %.1f/min)" % [pops, minutes, POP_BUDGET_PER_MINUTE]}]
	return []


## Locked frames with both fighters on screen below ON_SCREEN_SHARE, as one violation.
func framing_share() -> Array[Dictionary]:
	if locked_frames == 0:
		return []
	var share := float(locked_on_screen_frames) / locked_frames
	if share < ON_SCREEN_SHARE:
		return [{"check": "camera_on_screen", "fighter": 0, "value": share, "limit": ON_SCREEN_SHARE,
			"detail": "both locked fighters on screen in %.1f%% of %d locked frames" % [share * 100.0, locked_frames]}]
	return []


func metrics() -> Dictionary:
	var minutes := fighter_frames / 3600.0
	return {
		"pops_per_fighter_minute": pops / maxf(minutes, 0.0001),
		"finger_pops_per_fighter_minute": finger_pops / maxf(minutes, 0.0001),
		"foot_error_p95_cm": _p95(foot_errors) * 100.0,
		"foot_slide_cm_per_frame": foot_slide_sum / maxf(foot_slide_frames, 1) * 100.0,
		"foot_slide_frames": foot_slide_frames,
		"foot_slide_skipped_frames": foot_slide_skipped,
		"camera_jerk_p95": _p95(camera_jerk),
		"locked_on_screen_share": float(locked_on_screen_frames) / maxf(locked_frames, 1),
	}


func _rig_of(view: FighterView) -> Dictionary:
	var rig := {"skeleton": null}
	if view._character == null:
		return rig
	var skeleton := view._character.model.get_node_or_null("%GeneralSkeleton") as Skeleton3D
	if skeleton == null:
		return rig
	rig.skeleton = skeleton
	rig.feet = FOOT_BONES.map(func(n: StringName) -> int: return skeleton.find_bone(n))
	rig.head = skeleton.find_bone(&"Head")
	rig.torso = TORSO_BONES.map(func(n: StringName) -> int: return skeleton.find_bone(n))
	rig.rotations = []
	# Skeleton modifiers (MotionLayers) are undone after each skeleton update, so get_bone_global_pose
	# between frames is the unmodified pose; keep the rendered one from skeleton_updated instead.
	rig.poses = [] as Array[Transform3D]
	skeleton.skeleton_updated.connect(_remember_pose.bind(skeleton, rig.poses))
	# Sole below the ankle: rest foot height over the bind-pose mesh bottom, in skeleton space.
	# Skinned body meshes only: props hung on bones (Brann's stowed cannon) are not the sole.
	var bottom := INF
	for mesh: MeshInstance3D in view._character.model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or mesh.skin == null:
			continue
		var box := skeleton.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bottom = minf(bottom, box.position.y)
	var ankle := INF
	for bone: int in rig.feet:
		if bone >= 0:
			ankle = minf(ankle, skeleton.get_bone_global_rest(bone).origin.y)
	rig.sole = (ankle - bottom) * skeleton.global_basis.get_scale().y if is_finite(ankle - bottom) else 0.0
	return rig


static func _remember_pose(skeleton: Skeleton3D, poses: Array[Transform3D]) -> void:
	poses.resize(skeleton.get_bone_count())
	for bone in poses.size():
		poses[bone] = skeleton.get_bone_global_pose(bone)


## A bone's global pose as last rendered (modifiers applied), or the current pose before the first update.
static func _pose(rig: Dictionary, skeleton: Skeleton3D, bone: int) -> Transform3D:
	var poses: Array[Transform3D] = rig.poses
	return poses[bone] if bone < poses.size() else skeleton.get_bone_global_pose(bone)


func _check_rig(i: int, out: Array[Dictionary]) -> void:
	var rig := _rigs[i]
	var skeleton: Skeleton3D = rig.skeleton
	if skeleton == null:
		return
	var fighter := level.sim.fighters[i]
	var view := level.fighter_views[i]
	fighter_frames += 1
	var count := skeleton.get_bone_count()
	var rotations: Array = rig.rotations
	var fresh := rotations.size() != count
	var worst := 0.0
	var worst_bone := -1
	var worst_finger := 0.0
	for bone in count:
		var pose := _pose(rig, skeleton, bone)
		if not pose.is_finite():
			out.append({"check": "bone_nan", "fighter": i, "value": bone, "limit": 0,
				"detail": "bone %s is not finite" % skeleton.get_bone_name(bone)})
			return
		var rotation := pose.basis.get_rotation_quaternion()
		if fresh:
			rotations.append(rotation)
			continue
		var angle := (rotations[bone] as Quaternion).angle_to(rotation)
		rotations[bone] = rotation
		if _is_finger(skeleton.get_bone_name(bone)):
			worst_finger = maxf(worst_finger, angle)
		elif angle > worst:
			worst = angle
			worst_bone = bone
	var settled := fighter.state != FighterState.State.VANISHING and fighter.state_ticks > 1
	if worst_finger > POP_ANGLE and settled:
		finger_pops += 1
	if worst > POP_ANGLE and settled:
		pops += 1
		out.append({"check": "pop", "fighter": i, "value": worst, "limit": POP_ANGLE,
			"detail": "%s turned %.2f rad in one frame (%s, move %s, clip %s)" % [skeleton.get_bone_name(worst_bone),
			worst, FighterState.State.find_key(fighter.state), fighter.move_id(), _clip_of(i)]})
	if not view.visible or fighter.state == FighterState.State.VANISHING:
		_planted_previous.erase(i)
		return
	_check_feet(i, rig, skeleton, fighter, out)
	_check_weapon(i, rig, skeleton, fighter, out)


func _check_feet(i: int, rig: Dictionary, skeleton: Skeleton3D, fighter: FighterState, out: Array[Dictionary]) -> void:
	var standing := fighter.state in STANDING_STATES
	var grounded := (standing or fighter.state == FighterState.State.MOVING) \
		and fighter.position.y - fighter.stand_height < 0.02 and fighter.hitstop_ticks == 0
	if not grounded:
		_planted_previous.erase(i)
		return
	grounded_frames += 1
	var lowest := INF
	var lowest_at := Vector3.ZERO
	var lowest_bone := -1
	for bone: int in rig.feet:
		if bone < 0:
			continue
		var at := skeleton.global_transform * _pose(rig, skeleton, bone).origin
		var sole: float = at.y - float(rig.sole)
		var ground := level.world.ground_height_at(at.x, at.z, fighter.position.y)
		if sole - ground < lowest:
			lowest = sole - ground
			lowest_at = at
			lowest_bone = bone
	if not is_finite(lowest):
		return
	if standing:
		foot_errors.append(absf(lowest))
	# Standing: a foot on the ground. Running lifts both feet, so there only sinking counts.
	if (standing and absf(lowest) > FOOT_TOLERANCE) or lowest < -FOOT_TOLERANCE:
		out.append({"check": "foot_ground", "fighter": i, "value": lowest, "limit": FOOT_TOLERANCE,
			"detail": "lowest sole %+.1f cm off the visible ground (%s, clip %s)" % [lowest * 100.0,
			FighterState.State.find_key(fighter.state), _clip_of(i)]})
	_measure_slide(i, fighter, lowest, lowest_bone, lowest_at)


## Planar travel of the planted foot since the previous frame, when the same foot was
## planted then too, that frame was the one just before, and the fighter did not teleport.
func _measure_slide(i: int, fighter: FighterState, lowest: float, bone: int, at: Vector3) -> void:
	if fighter.state != FighterState.State.IDLE:
		_planted_previous.erase(i)
		return
	if absf(lowest) > FOOT_TOLERANCE:
		foot_slide_skipped += 1
		_planted_previous.erase(i)
		return
	var body := Vector2(fighter.position.x, fighter.position.z)
	var previous: Dictionary = _planted_previous.get(i, {})
	# When the other foot becomes the lowest, that is no slide.
	if previous.get(&"bone", -1) == bone and previous.frame == frames - 1 and frames > _settle_until \
			and body.distance_to(previous.body) < TELEPORT_DISTANCE:
		var was: Vector3 = previous.at
		foot_slide_sum += Vector2(at.x - was.x, at.z - was.z).length()
		foot_slide_frames += 1
	_planted_previous[i] = {&"bone": bone, &"at": at, &"frame": frames, &"body": body}


func _check_weapon(i: int, rig: Dictionary, skeleton: Skeleton3D, fighter: FighterState, out: Array[Dictionary]) -> void:
	var held: Dictionary = level.weapon_layer._held[i]
	if held.kind <= 0 or (held.nodes as Array).is_empty():
		return
	var hips: int = rig.torso[0]
	var chest: int = rig.torso[1]
	if hips < 0 or chest < 0:
		return
	var a := skeleton.global_transform * _pose(rig, skeleton, hips).origin
	var b := skeleton.global_transform * _pose(rig, skeleton, chest).origin
	var inside := 0
	var total := 0
	for node: Node in held.nodes:
		if not is_instance_valid(node):
			continue
		for point in _points_of(node as Node3D):
			total += 1
			if _segment_distance(point, a, b) < TORSO_RADIUS:
				inside += 1
	if total > 0 and float(inside) / total > WEAPON_INSIDE_SHARE:
		out.append({"check": "weapon_in_body", "fighter": i, "value": float(inside) / total,
			"limit": WEAPON_INSIDE_SHARE, "detail": "%s: %d%% of the weapon inside the torso (%s, move %s)" % [
			Weapon.weapon_name(held.kind), roundi(100.0 * inside / total),
			FighterState.State.find_key(fighter.state), fighter.move_id()]})
	if Weapon.is_bow(held.kind) and rig.head >= 0:
		var head := skeleton.global_transform * _pose(rig, skeleton, rig.head)
		var centre := head.origin + head.basis.y.normalized() * HEAD_LIFT
		for node: Node in held.nodes:
			var string := _bow_string(node)
			if string == null:
				continue
			var half := string.global_basis.y * ((string.mesh as CylinderMesh).height * 0.5)
			var distance := _segment_distance(centre, string.global_position - half, string.global_position + half)
			if distance < HEAD_RADIUS:
				out.append({"check": "bow_string_head", "fighter": i, "value": distance, "limit": HEAD_RADIUS,
					"detail": "bow string %.1f cm from the head centre (draw %d, %s)" % [distance * 100.0,
					fighter.draw_level(), FighterState.State.find_key(fighter.state)]})


func _check_camera(out: Array[Dictionary]) -> void:
	var camera: FighterCamera = level.camera
	var view := camera.global_transform
	var forward := -view.basis.z.normalized()
	_camera_forward.append(forward)
	if _camera_forward.size() > 4:
		_camera_forward.pop_front()
	if _camera_forward.size() == 4:
		# Third difference of the view direction: angular jerk in rad/frame^3.
		var f := _camera_forward
		camera_jerk.append(((f[3] - f[2] * 3.0) + (f[1] * 3.0 - f[0])).length())
	var sim := level.sim
	var me := sim.fighters[level.player]
	for i in sim.fighters.size():
		var fighter := sim.fighters[i]
		# A body the view faded for a camera this close is see-through by design (T-D29).
		if fighter.state == FighterState.State.VANISHING \
				or level.fighter_views[i].camera_fade() >= FighterView.FADED - 0.01:
			continue
		var box := FlightPlaytest._screen_box(view, camera.fov, SCREEN, level.fighter_views[i].position)
		var cover := box.intersection(Rect2(Vector2.ZERO, SCREEN)).get_area() / (SCREEN.x * SCREEN.y)
		if cover > MAX_SCREEN_COVER:
			out.append({"check": "camera_cover", "fighter": i, "value": cover, "limit": MAX_SCREEN_COVER,
				"detail": "fighter %d covers %.0f%% of the screen" % [i, cover * 100.0]})
	if me.lock_on_target < 0 or me.is_ko_state() or sim.fighters[me.lock_on_target].is_ko_state():
		return
	locked_frames += 1
	var both := true
	for index in [level.player, me.lock_on_target]:
		var at: Vector3 = level.fighter_views[index].position
		if not OpponentMarker.placement(view, camera.fov, SCREEN, at).on_screen:
			both = false
	if both:
		locked_on_screen_frames += 1


func _points_of(model: Node3D) -> PackedVector3Array:
	var key := model.get_instance_id()
	var local: Array = _weapon_points.get(key, [])
	if local.is_empty():
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null:
				continue
			var faces := mesh.mesh.get_faces()
			var step := maxi(faces.size() / 24, 1)
			for k in range(0, faces.size(), step):
				local.append([mesh, faces[k]])
		_weapon_points[key] = local
	var out := PackedVector3Array()
	for entry: Array in local:
		var mesh := entry[0] as MeshInstance3D
		if is_instance_valid(mesh) and mesh.is_visible_in_tree():
			out.append(mesh.global_transform * (entry[1] as Vector3))
	return out


func _clip_of(i: int) -> String:
	var character := level.fighter_views[i]._character
	return String(character.current_clip()) if character != null else ""


static func _is_finger(bone_name: String) -> bool:
	for part in ["Thumb", "Index", "Middle", "Ring", "Little"]:
		if bone_name.contains(part):
			return true
	return false


static func _bow_string(node: Node) -> MeshInstance3D:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var cylinder := mesh.mesh as CylinderMesh
		if cylinder != null and cylinder.height > 1.0 and cylinder.bottom_radius < 0.02:
			return mesh
	return null


static func _segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	return p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, b))


static func _p95(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(int(sorted.size() * 0.95), sorted.size() - 1)]
