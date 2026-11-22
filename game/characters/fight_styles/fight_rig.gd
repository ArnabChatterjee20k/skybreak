class_name FightRig
extends RefCounted
## Puts a fight pose (FightStyle) on a humanoid voxel skeleton: hips, spine, chest and head
## by rotation; hands and feet by two-bone IK to targets, so fists land where the hitbox is
## and planted feet stay planted. Pose space is the skeleton's: +Z forward, +X the
## character's left, +Y up, origin on the floor between the feet, in Kael-sized metres
## (scaled to each legend by hip height).

const REFERENCE_HIP := 0.8
const SPINE := [&"Hips", &"Spine", &"Chest", &"UpperChest", &"Neck", &"Head"]

var skeleton: Skeleton3D
var scale := 1.0
## Model-space positions of the last applied pose (strike limbs, tests): hands, toes, head.
var points: Dictionary = {}
var _bone: Dictionary = {}
var _rest: Dictionary = {}
var _parent: Dictionary = {}
var _len: Dictionary = {}
var _fingers: Array[int] = []


func setup(target: Skeleton3D) -> void:
	skeleton = target
	for name in SPINE + [&"LeftShoulder", &"LeftUpperArm", &"LeftLowerArm", &"LeftHand",
			&"RightShoulder", &"RightUpperArm", &"RightLowerArm", &"RightHand", &"LeftUpperLeg",
			&"LeftLowerLeg", &"LeftFoot", &"LeftToes", &"RightUpperLeg", &"RightLowerLeg",
			&"RightFoot", &"RightToes"]:
		var index := skeleton.find_bone(name)
		_bone[name] = index
		_rest[name] = skeleton.get_bone_global_rest(index) if index >= 0 else Transform3D.IDENTITY
		var parent := skeleton.get_bone_parent(index) if index >= 0 else -1
		_parent[name] = skeleton.get_bone_global_rest(parent) if parent >= 0 else Transform3D.IDENTITY
	scale = (_rest[&"Hips"] as Transform3D).origin.y / REFERENCE_HIP
	for side in ["Left", "Right"]:
		_len[side + "Arm1"] = _o(side + "LowerArm").distance_to(_o(side + "UpperArm"))
		_len[side + "Arm2"] = _o(side + "Hand").distance_to(_o(side + "LowerArm"))
		_len[side + "Leg1"] = _o(side + "LowerLeg").distance_to(_o(side + "UpperLeg"))
		_len[side + "Leg2"] = _o(side + "Foot").distance_to(_o(side + "LowerLeg"))
	for i in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(i)
		if ("Proximal" in bone_name or "Intermediate" in bone_name or "Distal" in bone_name) \
				and not "Thumb" in bone_name:
			_fingers.append(i)


func _o(name: String) -> Vector3:
	return (_rest[StringName(name)] as Transform3D).origin


## Ankle height of the rest pose over the floor (Kael-sized metres).
func ankle_height() -> float:
	return _o("LeftFoot").y / scale


static func euler(degrees: Vector3) -> Basis:
	return Basis.from_euler(degrees * (PI / 180.0))


## Rotation taking the rest frame (direction, bend axis) onto the target frame.
static func frame_turn(rest_dir: Vector3, rest_axis: Vector3, dir: Vector3, axis: Vector3) -> Basis:
	var a := rest_dir.normalized()
	var b := (rest_axis - a * rest_axis.dot(a)).normalized()
	var c := dir.normalized() if dir.length_squared() > 1e-10 else a
	var d := axis - c * axis.dot(c)
	if d.length_squared() < 1e-6:
		d = b - c * b.dot(c)
	if d.length_squared() < 1e-6:
		d = c.cross(Vector3.RIGHT if absf(c.x) < 0.9 else Vector3.FORWARD)
	d = d.normalized()
	var from := Basis(a, b, a.cross(b))
	var to := Basis(c, d, c.cross(d))
	return to * from.transposed()


func apply(pose: Dictionary) -> void:
	var rot: Dictionary = {}
	var pos: Dictionary = {}
	var hips_rot := euler(pose.get("hipr", Vector3.ZERO))
	rot[&"Hips"] = hips_rot
	pos[&"Hips"] = _o("Hips") + (pose.get("hip", Vector3.ZERO) as Vector3) * scale
	var spine: Vector3 = pose.get("sp", Vector3.ZERO)
	var chest: Vector3 = pose.get("ch", Vector3.ZERO)
	var head: Vector3 = pose.get("hd", Vector3.ZERO)
	var parts := {&"Spine": spine, &"Chest": chest * 0.5, &"UpperChest": chest * 0.5,
		&"Neck": head * 0.4, &"Head": head * 0.6}
	var previous := &"Hips"
	for name in SPINE.slice(1):
		rot[name] = (rot[previous] as Basis) * euler(parts[name])
		pos[name] = _fk(pos, rot, previous, name)
		previous = name
	for side in ["Left", "Right"]:
		var key := "l" if side == "Left" else "r"
		var mirror := 1.0 if side == "Left" else -1.0
		var shoulder := StringName(side + "Shoulder")
		rot[shoulder] = (rot[&"UpperChest"] as Basis) * euler(pose.get(key + "sh", Vector3.ZERO))
		pos[shoulder] = _fk(pos, rot, &"UpperChest", shoulder)
		var upper := StringName(side + "UpperArm")
		pos[upper] = _fk(pos, rot, shoulder, upper)
		var hand_target: Vector3 = (pose.get(key + "h", Vector3(0.2 * mirror, 1.0, 0.1)) as Vector3) * scale
		var elbow_hint: Vector3 = pose.get(key + "e", Vector3(0.4 * mirror, -0.3, -1.0))
		_limb(pos, rot, upper, StringName(side + "LowerArm"), StringName(side + "Hand"),
			hand_target, elbow_hint, Vector3(0, -mirror, 0), _len[side + "Arm1"], _len[side + "Arm2"])
		var hand := StringName(side + "Hand")
		rot[hand] = (rot[StringName(side + "LowerArm")] as Basis) * euler(pose.get(key + "w", Vector3.ZERO))
		points[key + "hand"] = (pos[hand] as Vector3) / scale
		var thigh := StringName(side + "UpperLeg")
		pos[thigh] = _fk(pos, rot, &"Hips", thigh)
		var foot_target: Vector3 = (pose.get(key + "f", Vector3(0.13 * mirror, 0.13, 0)) as Vector3) * scale
		var knee_hint: Vector3 = pose.get(key + "k", Vector3(0.15 * mirror, 0, 1))
		_limb(pos, rot, thigh, StringName(side + "LowerLeg"), StringName(side + "Foot"),
			foot_target, knee_hint, Vector3(1, 0, 0), _len[side + "Leg1"], _len[side + "Leg2"])
		var foot := StringName(side + "Foot")
		var shin := (pos[foot] as Vector3) - (pos[StringName(side + "LowerLeg")] as Vector3)
		var toe_dir: Vector3 = pose.get(key + "t", Vector3(0.12 * mirror, 0, 1))
		var up := Vector3.UP if toe_dir.y > -0.5 else -shin
		rot[foot] = frame_turn(Vector3(0, 0, 1), Vector3.UP, toe_dir, up)
		var toes := StringName(side + "Toes")
		rot[toes] = rot[foot]
		pos[toes] = _fk(pos, rot, foot, toes)
		points[key + "foot"] = (pos[foot] as Vector3) / scale
		points[key + "toe"] = (pos[toes] as Vector3) / scale
		points[key + "knee"] = (pos[StringName(side + "LowerLeg")] as Vector3) / scale
		points[key + "elbow"] = (pos[StringName(side + "LowerArm")] as Vector3) / scale
	points["head"] = (pos[&"Head"] as Vector3) / scale
	points["hips"] = (pos[&"Hips"] as Vector3) / scale
	points["chest"] = (pos[&"UpperChest"] as Vector3) / scale
	_write(rot, pos, float(pose.get("fist", 1.0)))


## Global position of child from its parent's posed transform.
func _fk(pos: Dictionary, rot: Dictionary, parent: StringName, child: StringName) -> Vector3:
	var offset := (_rest[child] as Transform3D).origin - (_rest[parent] as Transform3D).origin
	return (pos[parent] as Vector3) + (rot[parent] as Basis) * offset


func _limb(pos: Dictionary, rot: Dictionary, upper: StringName, lower: StringName, end: StringName,
		target: Vector3, hint: Vector3, rest_axis: Vector3, l1: float, l2: float) -> void:
	var root: Vector3 = pos[upper]
	var to := target - root
	var reach := clampf(to.length(), absf(l1 - l2) + 0.01, (l1 + l2) * 0.999)
	var dir := to.normalized() if to.length_squared() > 1e-8 else Vector3.DOWN
	var a := (l1 * l1 - l2 * l2 + reach * reach) / (2.0 * reach)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var perp := hint - dir * hint.dot(dir)
	if perp.length_squared() < 1e-8:
		perp = Vector3.FORWARD.cross(dir)
	perp = perp.normalized()
	var mid := root + dir * a + perp * h
	var tip := root + dir * reach
	var upper_dir := mid - root
	var lower_dir := tip - mid
	var axis := upper_dir.cross(lower_dir)
	var rest_upper := (_rest[lower] as Transform3D).origin - (_rest[upper] as Transform3D).origin
	var rest_lower := (_rest[end] as Transform3D).origin - (_rest[lower] as Transform3D).origin
	rot[upper] = frame_turn(rest_upper, rest_axis, upper_dir, axis)
	rot[lower] = frame_turn(rest_lower, rest_axis, lower_dir, axis)
	pos[lower] = mid
	pos[end] = tip


func _write(rot: Dictionary, pos: Dictionary, fist: float) -> void:
	for name in rot:
		var index: int = _bone.get(name, -1)
		if index < 0:
			continue
		var rest: Transform3D = _rest[name]
		var parent_rest: Transform3D = _parent[name]
		var global_basis: Basis = (rot[name] as Basis) * rest.basis
		var parent_name := _posed_parent(name)
		var parent_basis: Basis = parent_rest.basis
		if parent_name != &"":
			parent_basis = (rot[parent_name] as Basis) * parent_rest.basis
		var local := (parent_basis.inverse() * global_basis).orthonormalized()
		skeleton.set_bone_pose_rotation(index, local.get_rotation_quaternion())
		if name == &"Hips":
			var parent_xf := parent_rest
			skeleton.set_bone_pose_position(index, parent_xf.affine_inverse() * (pos[name] as Vector3))
	for index in _fingers:
		var rest := skeleton.get_bone_rest(index)
		var curl := Quaternion(Vector3.RIGHT, deg_to_rad(70.0 * fist))
		skeleton.set_bone_pose_rotation(index, rest.basis.get_rotation_quaternion() * curl)


func _posed_parent(name: StringName) -> StringName:
	match name:
		&"Hips":
			return &""
		&"Spine":
			return &"Hips"
		&"Chest":
			return &"Spine"
		&"UpperChest":
			return &"Chest"
		&"Neck", &"LeftShoulder", &"RightShoulder":
			return &"UpperChest"
		&"Head":
			return &"Neck"
		&"LeftUpperArm":
			return &"LeftShoulder"
		&"RightUpperArm":
			return &"RightShoulder"
		&"LeftLowerArm":
			return &"LeftUpperArm"
		&"RightLowerArm":
			return &"RightUpperArm"
		&"LeftHand":
			return &"LeftLowerArm"
		&"RightHand":
			return &"RightLowerArm"
		&"LeftUpperLeg", &"RightUpperLeg":
			return &"Hips"
		&"LeftLowerLeg":
			return &"LeftUpperLeg"
		&"RightLowerLeg":
			return &"RightUpperLeg"
		&"LeftFoot":
			return &"LeftLowerLeg"
		&"RightFoot":
			return &"RightLowerLeg"
		&"LeftToes":
			return &"LeftFoot"
		&"RightToes":
			return &"RightFoot"
	return &""
