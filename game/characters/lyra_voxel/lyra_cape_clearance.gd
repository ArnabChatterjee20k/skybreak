class_name LyraCapeClearance
extends ScarfLag
## Lyra's cape chain: ScarfLag's trailing chain that also stays behind her legs
## and forearms (view-only). Every step pushes the simulated joints back wherever
## a thigh, shin, boot or forearm would reach through the cape's inner face
## (LyraVoxelDesign's cape_inner_z), keeping segment lengths and adding no
## velocity, so the turn limit and spring shape every frame of the cape.

## How far the chain runs on past the last bone to the hem (as in the design's weights).
@export var end_extension := 2.4
## Gap kept between a leg's back and the cape's inner face.
@export var clearance := 0.05
## Width over which a limb at the cape's side edge fades in (m), so it never pushes all at once.
@export var edge_fade := 0.04

## Leg capsules: bone, child bone, outer radius (legging, boot shaft, boot).
const LEGS := [
	[&"UpperLeg", &"LowerLeg", 0.075], [&"LowerLeg", &"Foot", 0.065], [&"Foot", &"Toes", 0.065],
	[&"LowerArm", &"Hand", 0.055], [&"Hand", &"MiddleProximal", 0.05],
]
## Furthest a joint is pushed back in one step (m).
const MAX_PUSH := 0.6
## Push passes per step; keeping lengths after a push gives some of it back.
const PASSES := 2

var _chest := -1
var _legs: Array = []
## The chain joints at rest (bone heads, then the hem), in the chest's rest frame.
var _rest_joints := PackedVector3Array()
var _chest_rest := Transform3D()
## This frame's chest pose (world, orthonormal) and limb samples [point in chest frame, radius].
var _chest_world := Transform3D()
var _samples: Array = []


func _begin_frame(skeleton: Skeleton3D, to_world: Transform3D) -> void:
	if not _setup_clearance(skeleton):
		_samples.clear()
		return
	var chest := to_world * skeleton.get_bone_global_pose(_chest)
	_chest_world = Transform3D(chest.basis.orthonormalized(), chest.origin)
	var to_chest := _chest_world.affine_inverse() * to_world
	_samples.clear()
	for l: Array in _legs:
		var a := to_chest * skeleton.get_bone_global_pose(l[0]).origin
		var b := to_chest * skeleton.get_bone_global_pose(l[1]).origin
		var n := maxi(2, ceili(a.distance_to(b) / 0.04))
		for k in n + 1:
			_samples.append([a.lerp(b, float(k) / n), l[2]])


func _setup_clearance(skeleton: Skeleton3D) -> bool:
	if _chest >= 0:
		return true
	if _bone_ids.size() < 2:
		return false
	_chest = skeleton.get_bone_parent(_bone_ids[0])
	for side: String in ["Left", "Right"]:
		for l: Array in LEGS:
			_legs.append([skeleton.find_bone(StringName(side + l[0])), skeleton.find_bone(StringName(side + l[1])), l[2]])
	_chest_rest = skeleton.get_bone_global_rest(_chest)
	var to_chest := _chest_rest.affine_inverse()
	for id in _bone_ids:
		_rest_joints.append(to_chest * skeleton.get_bone_global_rest(id).origin)
	var last := _rest_joints[-1]
	_rest_joints.append(last + (last - _rest_joints[-2]) * end_extension)
	return true


func _constrain() -> void:
	if _samples.is_empty() or _points.size() != _rest_joints.size():
		return
	for _pass in PASSES:
		if not _push_out():
			return


## One pushing pass; false when nothing reached through.
func _push_out() -> bool:
	var to_chest := _chest_world.affine_inverse()
	var count := _points.size()
	# Chain joints in the chest frame, the last tail swapped for the hem.
	var joints := PackedVector3Array()
	for p in _points:
		joints.append(to_chest * p)
	joints[-1] = joints[-2] + (joints[-1] - joints[-2]) * end_extension
	var push := _chain_push(joints)
	if push.is_empty():
		return false
	for k in range(1, count):
		joints[k].z -= push[k]
	joints[-1] = joints[-2] + (joints[-1] - joints[-2]) / end_extension
	# Back to world, keeping each segment's length, and carry _previous along so the push adds
	# no velocity.
	for k in range(1, count):
		var wanted := _chest_world * joints[k]
		var segment := wanted - _points[k - 1]
		if segment.length() > 0.0001:
			wanted = _points[k - 1] + segment.normalized() * _lengths[k - 1]
		_previous[k] += wanted - _points[k]
		_points[k] = wanted
	return true


## How far back (chest -Z) each joint of the chain (chest frame, hem last) must go so
## no limb sample reaches through the cape's inner face; empty when none does.
func _chain_push(joints: PackedVector3Array) -> PackedFloat32Array:
	var push := PackedFloat32Array()
	push.resize(joints.size())
	var any := false
	# The cape between two joints follows both, so a limb point anywhere within a joint's two
	# segments counts, weighted by how close it is to that joint along the cape.
	for s: Array in _samples:
		var reach := _reach(joints, s[0], s[1])
		if reach.z <= 0.0:
			continue
		var k := int(reach.x)
		var f := reach.y
		var rest_y := (_chest_rest * _rest_joints[k].lerp(_rest_joints[k + 1], f)).y
		var follows := 1.0 - LyraVoxelDesign.cape_hips_share(rest_y)
		for j: int in [k, k + 1]:
			var share := (1.0 - f) if j == k else f
			if j == 0 or share <= 0.0:
				continue
			push[j] = minf(maxf(push[j], reach.z / maxf(share * follows, 0.35)), MAX_PUSH)
			any = true
	return push if any else PackedFloat32Array()


## Deepest a limb reaches through the cape's inner face in the skeleton's current pose (m,
## 0 when clear), against this frame's limb samples.
func reach_through(skeleton: Skeleton3D) -> float:
	if _samples.is_empty() or _rest_joints.is_empty():
		return 0.0
	var chest := skeleton.get_bone_global_pose(_chest)
	var to_chest := Transform3D(chest.basis.orthonormalized(), chest.origin).affine_inverse()
	var joints := PackedVector3Array()
	for id in _bone_ids:
		joints.append(to_chest * skeleton.get_bone_global_pose(id).origin)
	var tail := to_chest * (skeleton.get_bone_global_pose(_bone_ids[-1]) * _tails[-1])
	joints.append(joints[-1] + (tail - joints[-1]) * end_extension)
	var deepest := 0.0
	for s: Array in _samples:
		deepest = maxf(deepest, _reach(joints, s[0], s[1]).z)
	return deepest


## Where limb point q (chest frame, radius) falls on the cape (segment k, fraction f) and how
## deep it reaches through the inner face there, as (k, f, depth); depth 0 when clear.
func _reach(joints: PackedVector3Array, q: Vector3, radius: float) -> Vector3:
	# The same spot at rest gives the cape's depth and width from the design.
	var hit := _locate(joints, q.y)
	if hit.x < 0.0:
		return Vector3.ZERO
	var k := int(hit.x)
	var f := hit.y
	var rest := _chest_rest * _rest_joints[k].lerp(_rest_joints[k + 1], f)
	var inside := clampf((LyraVoxelDesign.cape_half_w(rest.y) + radius - absf(q.x)) / edge_fade, 0.0, 1.0)
	if inside <= 0.0:
		return Vector3.ZERO
	var face_z := joints[k].lerp(joints[k + 1], f).z + LyraVoxelDesign.cape_inner_z(q.x, rest.y) - rest.z
	return Vector3(k, f, maxf(0.0, face_z + radius + clearance - q.z) * inside)


## Segment k of the chain spanning height y and how far down it (k = -1 when
## y is above or below the chain).
static func _locate(joints: PackedVector3Array, y: float) -> Vector2:
	for k in joints.size() - 1:
		var top := joints[k].y
		var bottom := joints[k + 1].y
		if y <= top and y >= bottom and top - bottom > 1e-4:
			return Vector2(k, (top - y) / (top - bottom))
	return Vector2(-1, 0)
