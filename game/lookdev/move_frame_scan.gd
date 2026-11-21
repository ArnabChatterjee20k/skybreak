extends SceneTree
## Move-frame scan for a voxel character: steps idle, run, flight, a dash, the
## guard, every move in --moves and the reel's procedural poses (kick, guard,
## shot, beam, hover, crouch), and on every --every'th tick checks
##  - cloth through limbs: faces skinned to --cloth bones (the cape chain by
##    default) that sink more than --depth into a leg or forearm capsule,
##  - stretch: faces grown more than 3x from rest (as stretch_scan.gd).
## Headless is fine.
##   godot --headless --path . -s res://game/lookdev/move_frame_scan.gd -- \
##       --scene=<character scene> --moves=res://game/combat/moves/<name>/ [--every=2] [--depth=0.02]
## Prints one line per segment and exits 1 on any clip or stretch.

const MR = preload("res://game/lookdev/moves_reel.gd")
const S := FighterState.State
const DT := 1.0 / 60.0
## Limb capsules (bone, child bone, radius at the bone, at the child): the
## limbs' own voxel radius less a cell, so touching cloth doesn't count.
const LIMBS := [
	[&"LeftUpperLeg", &"LeftLowerLeg", 0.06, 0.045], [&"LeftLowerLeg", &"LeftFoot", 0.045, 0.045],
	[&"LeftFoot", &"LeftToes", 0.04, 0.035],
	[&"RightUpperLeg", &"RightLowerLeg", 0.06, 0.045], [&"RightLowerLeg", &"RightFoot", 0.045, 0.045],
	[&"RightFoot", &"RightToes", 0.04, 0.035],
	[&"LeftLowerArm", &"LeftHand", 0.04, 0.035], [&"RightLowerArm", &"RightHand", 0.04, 0.035],
	[&"LeftHand", &"LeftMiddleProximal", 0.035, 0.03], [&"RightHand", &"RightMiddleProximal", 0.035, 0.03],
]

var _view: CharacterView
var _sk: Skeleton3D
var _pose: LookdevPoseOverride
var _f := FighterState.new()
var _mats: Array = []
var _every := 2
var _depth := 0.02
var _tick_count := 0
# Mesh data: rest positions (face corners), bones and weights.
var _verts := PackedVector3Array()
var _bones := PackedInt32Array()
var _ws := PackedFloat32Array()
var _cloth_faces := PackedInt32Array()
var _limbs := []
var _caps := []
var _segment := ""
var _seg_clip := 0.0
var _seg_clip_frames := 0
var _seg_stretch := 0
var _seg_frames := 0
var _seg_worst := ""
var _seg_stretch_at := Vector3.ZERO
var _failed := false


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args := LookdevArgs.parse()
	var scene := args.need("scene", "move_frame_scan.gd -- --scene=<character scene> --moves=<move dir/>")
	var moves := args.get_option("moves")
	_every = int(args.get_option("every", "2"))
	_depth = float(args.get_option("depth", "0.02"))
	var cloth: PackedStringArray = args.get_option("cloth", "Scarf1,Scarf2,Scarf3,Scarf4,Scarf5").split(",")
	if scene == "":
		return
	_view = load(scene).instantiate()
	root.add_child(_view)
	_sk = _view.model.get_node("%GeneralSkeleton") as Skeleton3D
	_pose = LookdevPoseOverride.new()
	_sk.add_child(_pose)
	# The procedural pose stands in for a clip, so it goes before the cloth modifiers.
	_sk.move_child(_pose, 0)
	_sk.skeleton_updated.connect(_capture)
	var mi: MeshInstance3D = _sk.find_children("*", "MeshInstance3D", false, false)[0]
	var cloth_bones := {}
	for b in cloth:
		cloth_bones[_sk.find_bone(b)] = true
	for si in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(si)
		var base := _verts.size()
		_verts.append_array(arr[Mesh.ARRAY_VERTEX])
		_bones.append_array(arr[Mesh.ARRAY_BONES])
		_ws.append_array(arr[Mesh.ARRAY_WEIGHTS])
		for fi in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 4:
			var v := base + fi * 4
			var on := 0.0
			for j in 4:
				if cloth_bones.has(_bones[v * 4 + j]):
					on += _ws[v * 4 + j]
			if on > 0.5:
				_cloth_faces.append(v)
	for l: Array in LIMBS:
		_limbs.append([_sk.find_bone(l[0]), _sk.find_bone(l[1]), l[2], l[3], l[0]])
	print("faces %d, cloth faces %d" % [_verts.size() / 4, _cloth_faces.size()])
	_f.position = Vector3(0, 1, 0)
	_f.facing_yaw = PI
	_f.enter_state(S.IDLE)
	await _run_ticks("settle", 30, false)
	await _segment_begin("idle")
	await _run_ticks("idle", 90)
	_segment_end()
	await _locomotion("walk", 3.0, 120)
	await _locomotion("run", 9.0, 150)
	await _segment_begin("flight")
	_f.enter_state(S.FLYING)
	for i in 120:
		var v := lerpf(2.0, 11.0, minf(i / 50.0, 1.0))
		_f.velocity = Vector3(0, 0, -v)
		_f.position += _f.velocity * DT
		await _step()
	_segment_end()
	await _segment_begin("flight dash")
	_f.enter_state(S.DASHING)
	_f.dash_kind = FighterState.DashKind.SUSTAINED
	_f.dash_direction = Vector3.FORWARD
	for i in 60:
		_f.velocity = Vector3(0, 0, -lerpf(8.0, 26.0, minf(i / 15.0, 1.0)))
		_f.position += _f.velocity * DT
		await _step()
	_f.dash_kind = FighterState.DashKind.NONE
	_segment_end()
	_f.velocity = Vector3.ZERO
	_f.position = Vector3(0, 1, 0)
	_f.enter_state(S.IDLE)
	await _run_ticks("settle", 30, false)
	await _segment_begin("guard (clip)")
	_f.enter_state(S.BLOCKING)
	_f.blocking = true
	await _run_ticks("guard", 60)
	_f.blocking = false
	_f.enter_state(S.IDLE)
	_segment_end()
	if moves != "":
		if not moves.ends_with("/"):
			moves += "/"
		var names := Array(DirAccess.get_files_at(moves))
		names.sort()
		for file: String in names:
			var res = load(moves + file.trim_suffix(".remap"))
			if not res is MoveData:
				continue
			var move := res as MoveData
			await _segment_begin("move " + file.get_basename())
			_f.begin_move(move)
			while _f.state == S.ATTACKING and _f.move_tick < move.total_ticks():
				_f.move_tick += 1
				await _step()
			_f.enter_state(S.IDLE)
			_segment_end()
			await _run_ticks("settle", 20, false)
	var poses := {
		"pose guard": [MR.GUARD_AIMS, MR.GUARD_TURNS, false], "pose shot": [MR.SHOT_AIMS, MR.SHOT_TURNS, false],
		"pose beam": [MR.BEAM_AIMS, MR.BEAM_TURNS, false], "pose hover": [MR.HOVER_AIMS, MR.HOVER_TURNS, false],
		"pose kick chamber": [MR.KICK_CHAMBER, MR.KICK_TURNS, false],
		"pose kick extend": [MR.KICK_EXTEND, MR.KICK_TURNS, false], "pose crouch": [MR.CROUCH_AIMS, MR.CROUCH_TURNS, true],
	}
	for key: String in poses:
		var p: Array = poses[key]
		_pose.set_pose(p[0], p[1], p[2])
		await _segment_begin(key)
		for i in 24:
			_pose.weight = minf(1.0, i / 12.0)
			await _step()
		_segment_end()
		_pose.weight = 0.0
	print("RESULT ", "FAIL" if _failed else "PASS")
	quit(1 if _failed else 0)


func _locomotion(name: String, speed: float, ticks: int) -> void:
	await _segment_begin(name)
	_f.enter_state(S.MOVING)
	for i in ticks:
		var v := lerpf(0.0, speed, minf(i / 30.0, 1.0))
		_f.velocity = Vector3(0, 0, -v)
		_f.position += _f.velocity * DT
		await _step()
	_f.velocity = Vector3.ZERO
	_f.enter_state(S.IDLE)
	_segment_end()
	await _run_ticks("settle", 20, false)


func _run_ticks(_name: String, ticks: int, check := true) -> void:
	for i in ticks:
		await _step(check)


func _step(check := true) -> void:
	_f.state_ticks += 1
	_view.apply_state(_f, DT)
	await process_frame
	_tick_count += 1
	if check and _tick_count % _every == 0 and not _mats.is_empty():
		_check()


## Bone matrices and limb capsules as the mesh is drawn (after every modifier).
func _capture() -> void:
	_mats.clear()
	for b in _sk.get_bone_count():
		_mats.append(_sk.get_bone_global_pose(b) * _sk.get_bone_global_rest(b).affine_inverse())
	_caps.clear()
	for l: Array in _limbs:
		_caps.append([_sk.get_bone_global_pose(l[0]).origin, _sk.get_bone_global_pose(l[1]).origin, l[2], l[3], l[4]])


func _posed(v: int) -> Vector3:
	var p := Vector3.ZERO
	for j in 4:
		var w := _ws[v * 4 + j]
		if w > 0.0:
			p += (_mats[_bones[v * 4 + j]] * _verts[v]) * w
	return p


func _check() -> void:
	_seg_frames += 1
	var caps := _caps
	var worst := 0.0
	var worst_limb := ""
	var worst_rest := Vector3.ZERO
	for v in _cloth_faces:
		var c := (_posed(v) + _posed(v + 2)) * 0.5
		for cap: Array in caps:
			var a: Vector3 = cap[0]
			var ab: Vector3 = cap[1] - a
			var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
			var depth: float = lerpf(cap[2], cap[3], t) - c.distance_to(a + ab * t)
			if depth > worst:
				worst = depth
				worst_limb = cap[4]
				worst_rest = (_verts[v] + _verts[v + 2]) * 0.5
	if worst > _depth:
		_seg_clip_frames += 1
		if worst > _seg_clip:
			_seg_clip = worst
			_seg_worst = "%s at tick %d (rest %.2f, %.2f, %.2f)" % [worst_limb, _f.state_ticks, worst_rest.x, worst_rest.y, worst_rest.z]
	# Stretch on every face, every fourth checked frame (it's the slow part).
	if _seg_frames % 4 == 1:
		for fi in _verts.size() / 4:
			var v := fi * 4
			var rest_len := _verts[v].distance_to(_verts[v + 2])
			if _posed(v).distance_to(_posed(v + 2)) > rest_len * 3.0 + 0.01:
				if _seg_stretch == 0:
					_seg_stretch_at = (_verts[v] + _verts[v + 2]) * 0.5
					if OS.has_environment("SCAN_VERBOSE"):
						for k in 4:
							var parts := []
							for j in 4:
								if _ws[(v + k) * 4 + j] > 0.01:
									parts.append("%s %.2f" % [_sk.get_bone_name(_bones[(v + k) * 4 + j]), _ws[(v + k) * 4 + j]])
							print("  corner ", _verts[v + k], " ", parts)
				_seg_stretch += 1


func _segment_begin(name: String) -> void:
	_segment = name
	_seg_clip = 0.0
	_seg_clip_frames = 0
	_seg_stretch = 0
	_seg_frames = 0
	_seg_worst = ""
	await process_frame


func _segment_end() -> void:
	var bad := _seg_clip_frames > 0 or _seg_stretch > 0
	_failed = _failed or bad
	print("%-22s frames %3d  cloth-in-limb frames %3d  worst %.3f m %s  stretched faces %d%s  %s" % [
		_segment, _seg_frames, _seg_clip_frames, _seg_clip, _seg_worst, _seg_stretch,
		(" (first at rest %.2f, %.2f, %.2f)" % [_seg_stretch_at.x, _seg_stretch_at.y, _seg_stretch_at.z]) if _seg_stretch > 0 else "",
		"FAIL" if bad else "ok"])
