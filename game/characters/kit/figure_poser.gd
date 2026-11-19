class_name FigurePoser
extends RefCounted
## Poses a humanoid-profile figure from a few numbers (crouch, torso twist and
## lean, hand and foot targets) with two-bone IK, and bakes timed poses into a
## clip. Targets are in model space (feet on y = 0, facing +Z, left on +X).

const LIMBS := {
	&"LeftHand": [&"LeftUpperArm", &"LeftLowerArm", &"LeftHand"],
	&"RightHand": [&"RightUpperArm", &"RightLowerArm", &"RightHand"],
	&"LeftFoot": [&"LeftUpperLeg", &"LeftLowerLeg", &"LeftFoot"],
	&"RightFoot": [&"RightUpperLeg", &"RightLowerLeg", &"RightFoot"],
}
const TORSO: Array[StringName] = [&"Spine", &"Chest", &"UpperChest"]
const SKELETON_PATH := "%GeneralSkeleton"

var _skeleton: Skeleton3D
var _rest_global: Array[Transform3D] = []


## skeleton: the figure's rest skeleton (only its rests are read).
func _init(skeleton: Skeleton3D) -> void:
	_skeleton = skeleton
	for bone in skeleton.get_bone_count():
		_rest_global.append(skeleton.get_bone_global_rest(bone))


## Rest position of a bone's head in model space.
func rest_position(bone: StringName) -> Vector3:
	return _rest_global[_skeleton.find_bone(bone)].origin


## Local pose rotations (bone index -> Quaternion) and the hips position for a pose:
## {crouch, twist, lean (radians), targets: {limb: Vector3}}. Missing limbs rest.
func solve(pose: Dictionary) -> Dictionary:
	var spin: Dictionary = {}  # bone index -> model-space rotation on top of its rest
	var at: Dictionary = {}  # bone index -> model-space head position
	var hips := _skeleton.find_bone(&"Hips")
	var twist: float = pose.get("twist", 0.0)
	var lean: float = pose.get("lean", 0.0)
	spin[hips] = Basis(Vector3.UP, twist * 0.35)
	at[hips] = _rest_global[hips].origin + Vector3.DOWN * float(pose.get("crouch", 0.0))
	var step := Basis(Vector3.UP, twist * 0.65 / TORSO.size()) * Basis(Vector3.RIGHT, lean / TORSO.size())
	var targets: Dictionary = pose.get("targets", {})
	var bent := {}  # middle joints the IK already placed
	for bone in _skeleton.get_bone_count():
		if bone == hips or bent.has(bone):
			continue
		var parent := _skeleton.get_bone_parent(bone)
		if parent < 0:
			spin[bone] = Basis()
			at[bone] = _rest_global[bone].origin
			continue
		var name := _skeleton.get_bone_name(bone)
		var parent_spin: Basis = spin[parent]
		at[bone] = at[parent] + parent_spin * (_rest_global[bone].origin - _rest_global[parent].origin)
		if TORSO.has(name):
			spin[bone] = parent_spin * step
		elif name == &"Head" or name == &"LeftFoot" or name == &"RightFoot":
			spin[bone] = Basis(Vector3.UP, twist * 0.2)
		else:
			spin[bone] = parent_spin
		for limb: StringName in LIMBS:
			var chain: Array = LIMBS[limb]
			if name == chain[0] and (targets.has(limb) or limb.ends_with("Foot")):
				var goal: Vector3 = targets.get(limb, _rest_global[_skeleton.find_bone(limb)].origin)
				_bend(chain, goal, limb.ends_with("Foot"), at, spin)
				bent[_skeleton.find_bone(chain[1])] = true
	var rotations := {}
	for bone in _skeleton.get_bone_count():
		var global := (spin[bone] as Basis) * _rest_global[bone].basis
		var parent := _skeleton.get_bone_parent(bone)
		var parent_global := Basis() if parent < 0 else (spin[parent] as Basis) * _rest_global[parent].basis
		rotations[bone] = (parent_global.inverse() * global).get_rotation_quaternion()
	return {"rotations": rotations, "hips": at[hips], "positions": at}


## Model-space head positions of every bone for a pose (for tests and tuning).
func positions(pose: Dictionary) -> Dictionary:
	var solved := solve(pose)
	var named := {}
	for bone: int in solved.positions:
		named[_skeleton.get_bone_name(bone)] = solved.positions[bone]
	return named


## A clip of the given length from timed poses: [[seconds, pose], ...] in order.
func bake(length: float, keys: Array) -> Animation:
	var animation := Animation.new()
	animation.length = length
	var hips_track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(hips_track, NodePath("%s:Hips" % SKELETON_PATH))
	var tracks := {}
	var profile := SkeletonProfileHumanoid.new()
	for bone in _skeleton.get_bone_count():
		var name := _skeleton.get_bone_name(bone)
		if profile.find_bone(name) < 0 or _skeleton.get_bone_parent(bone) < 0:
			continue
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath("%s:%s" % [SKELETON_PATH, name]))
		tracks[bone] = track
	for key: Array in keys:
		var time := clampf(key[0], 0.0, length)
		var solved := solve(key[1])
		animation.position_track_insert_key(hips_track, time, solved.hips)
		for bone: int in tracks:
			animation.rotation_track_insert_key(tracks[bone], time, solved.rotations[bone])
	return animation


## Two-bone IK: aims the chain's first two bones so its end reaches goal (or as
## close as it can), the middle joint bending toward a pole.
func _bend(chain: Array, goal: Vector3, is_leg: bool, at: Dictionary, spin: Dictionary) -> void:
	var upper := _skeleton.find_bone(chain[0])
	var lower := _skeleton.find_bone(chain[1])
	var end := _skeleton.find_bone(chain[2])
	var a := _rest_global[upper].origin.distance_to(_rest_global[lower].origin)
	var b := _rest_global[lower].origin.distance_to(_rest_global[end].origin)
	var start: Vector3 = at[upper]
	var to_goal := goal - start
	var reach := clampf(to_goal.length(), absf(a - b) + 0.02, (a + b) * 0.999)
	var direction := to_goal.normalized() if to_goal.length() > 0.0001 else Vector3.DOWN
	var side := signf(_rest_global[upper].origin.x)
	var pole := Vector3(0.15 * side, 0.0, 1.0) if is_leg else Vector3(0.5 * side, -1.0, -0.6)
	var bend := (pole - direction * direction.dot(pole)).normalized()
	if bend.length() < 0.5:
		bend = Vector3.FORWARD.cross(direction).normalized()
	var cos_a := clampf((a * a + reach * reach - b * b) / (2.0 * a * reach), -1.0, 1.0)
	var middle := start + direction * (a * cos_a) + bend * (a * sqrt(1.0 - cos_a * cos_a))
	var tip := start + direction * reach
	at[lower] = middle
	spin[upper] = _aim(upper, lower, middle - start, spin[upper])
	spin[lower] = _aim(lower, end, tip - middle, spin[upper])


## Rotation that turns a bone's rest direction (toward child) to point along direction.
func _aim(bone: int, child: int, direction: Vector3, parent_spin: Basis) -> Basis:
	var rest_direction := parent_spin * (_rest_global[child].origin - _rest_global[bone].origin).normalized()
	var turn := Quaternion(rest_direction, direction.normalized())
	return Basis(turn) * parent_spin
