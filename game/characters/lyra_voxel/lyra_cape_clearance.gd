class_name LyraCapeClearance
extends SkeletonModifier3D
## Keeps Lyra's cape behind her legs and forearms (view-only): runs after
## ScarfLag and swings the cape chain back wherever a thigh, shin, boot or
## forearm would reach through the cape's inner face (LyraVoxelDesign's
## cape_inner_z), then re-aims the chain. Pure function of the pose, so the
## same clip frame always gives the same cape.

@export var bones: Array[StringName] = [&"Scarf1", &"Scarf2", &"Scarf3", &"Scarf4", &"Scarf5"]
## How far the chain runs on past the last bone to the hem (as in the design's weights).
@export var end_extension := 2.4
## Gap kept between a leg's back and the cape's inner face.
@export var clearance := 0.05

## Leg capsules: bone, child bone, outer radius (legging, boot shaft, boot).
const LEGS := [
	[&"UpperLeg", &"LowerLeg", 0.075], [&"LowerLeg", &"Foot", 0.065], [&"Foot", &"Toes", 0.065],
	[&"LowerArm", &"Hand", 0.055], [&"Hand", &"MiddleProximal", 0.05],
]

var _ids := PackedInt32Array()
var _hips := -1
var _legs: Array = []
var _tail := Vector3.ZERO
## The chain joints at rest, in the hips' rest frame.
var _rest_joints := PackedVector3Array()
var _hips_rest := Transform3D()


func _setup(skeleton: Skeleton3D) -> bool:
	if _ids.size() == bones.size():
		return true
	_ids.clear()
	for b in bones:
		var id := skeleton.find_bone(b)
		if id < 0:
			return false
		_ids.append(id)
	_hips = skeleton.get_bone_parent(_ids[0])
	for side: String in ["Left", "Right"]:
		for l: Array in LEGS:
			_legs.append([skeleton.find_bone(StringName(side + l[0])), skeleton.find_bone(StringName(side + l[1])), l[2]])
	var last := skeleton.get_bone_global_rest(_ids[-1])
	var before := skeleton.get_bone_global_rest(_ids[-2])
	_tail = last.affine_inverse() * (last.origin + (last.origin - before.origin) * end_extension)
	_hips_rest = skeleton.get_bone_global_rest(_hips)
	var to_hips := _hips_rest.affine_inverse()
	for id in _ids:
		_rest_joints.append(to_hips * skeleton.get_bone_global_rest(id).origin)
	_rest_joints.append(to_hips * (last * _tail))
	return true


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or not _setup(skeleton):
		return
	# Work in the frame of the cape's root (UpperChest): +Y up her body, +Z her
	# front, so a twisted waist doesn't skew the cape's width test.
	var hips := skeleton.get_bone_global_pose(_hips)
	hips = Transform3D(hips.basis.orthonormalized(), hips.origin)
	var to_hips := hips.affine_inverse()
	var fwd := Vector3.BACK
	# Leg sample points (every ~4 cm) with their radii.
	var samples: Array = []
	for l: Array in _legs:
		var a := skeleton.get_bone_global_pose(l[0]).origin
		var b := skeleton.get_bone_global_pose(l[1]).origin
		var n := maxi(2, ceili(a.distance_to(b) / 0.04))
		for k in n + 1:
			samples.append([to_hips * a.lerp(b, float(k) / n), l[2]])
	# Chain joints now (after ScarfLag), the hem end included.
	var joints := PackedVector3Array()
	for id in _ids:
		joints.append(to_hips * skeleton.get_bone_global_pose(id).origin)
	joints.append(to_hips * (skeleton.get_bone_global_pose(_ids[-1]) * _tail))
	# How far each joint must go back: the cape between two joints follows
	# both, so a leg point anywhere within a joint's two segments counts,
	# weighted by how close it is to that joint along the cape.
	var push := PackedFloat32Array()
	push.resize(joints.size())
	for j in range(1, joints.size()):
		var need := 0.0
		for s: Array in samples:
			var q: Vector3 = s[0]
			# Where q's height falls on the chain now (segment k, fraction f),
			# and the same spot at rest, where the design gives the cape's depth.
			var hit := _locate(joints, q.y)
			if hit.x < 0.0:
				continue
			var k := int(hit.x)
			var f := hit.y
			var share := (1.0 - f) if k == j else (f if k == j - 1 else 0.0)
			if share <= 0.0:
				continue
			var rest := _rest_joints[k].lerp(_rest_joints[k + 1], f)
			var rest_y := (_hips_rest * rest).y
			if absf(q.x) > LyraVoxelDesign.cape_half_w(rest_y) + s[1]:
				continue
			var offset := LyraVoxelDesign.cape_inner_z(q.x, rest_y) - (_hips_rest * rest).z
			var face_z := joints[k].lerp(joints[k + 1], f).z + offset
			var want: float = q.z - s[1] - clearance - face_z
			if want < 0.0:
				var follows := 1.0 - LyraVoxelDesign.cape_hips_share(rest_y)
				need = maxf(need, -want / maxf(share * follows, 0.35))
		push[j] = minf(need, 0.6)
	if _no_push_below(push, 1):
		return
	# Re-aim each bone at its pushed tail, top down.
	for i in _ids.size():
		var id := _ids[i]
		var pose := skeleton.get_bone_global_pose(id)
		var tail := hips * (joints[i + 1] - fwd * push[i + 1])
		var cur := (pose * (_child_local(skeleton, i))) - pose.origin
		var want := tail - pose.origin
		if cur.length() < 1e-5 or want.length() < 1e-5:
			continue
		var turn := Quaternion(cur.normalized(), want.normalized())
		var global := Transform3D(Basis(turn) * pose.basis, pose.origin)
		var parent := skeleton.get_bone_parent(id)
		var parent_pose := skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
		skeleton.set_bone_pose_rotation(id, (parent_pose.basis.inverse() * global.basis).get_rotation_quaternion())


## The tail of chain bone i in its own frame.
func _child_local(skeleton: Skeleton3D, i: int) -> Vector3:
	if i + 1 < _ids.size():
		var rest := skeleton.get_bone_global_rest(_ids[i])
		return rest.affine_inverse() * skeleton.get_bone_global_rest(_ids[i + 1]).origin
	return _tail


func _no_push_below(push: PackedFloat32Array, from: int) -> bool:
	for k in range(from, push.size()):
		if push[k] > 0.0:
			return false
	return true


## Segment k of the chain spanning height y and how far down it (k = -1 when
## y is above or below the chain).
static func _locate(joints: PackedVector3Array, y: float) -> Vector2:
	for k in joints.size() - 1:
		var top := joints[k].y
		var bottom := joints[k + 1].y
		if y <= top and y >= bottom and top - bottom > 1e-4:
			return Vector2(k, (top - y) / (top - bottom))
	return Vector2(-1, 0)
