class_name LookdevPoseOverride
extends SkeletonModifier3D
## Look-dev only: layers a procedural pose over whatever the clips produced,
## for poses the game has no clip for yet (combat hover, crossed guard, ki
## shot, kick, jump crouch, a big flinch). Runs last on the skeleton.
##
## Poses are authored in skeleton space (+Z his front, +X his left, +Y up), so
## they don't depend on the bones' local axes:
## - aims: bone -> direction the bone should point (towards its child joint);
##   applied top-down with a shortest-arc rotation, blended by weight.
## - turns: bone -> Vector3 euler degrees (pitch about X, yaw about Y, roll
##   about Z), a rotation of the bone (and everything below it) about its joint.
## keep_feet lowers the hips by however much the legs' aims lifted the feet,
## so a crouch stays planted on the floor.

const CHILD := {
	&"LeftUpperArm": &"LeftLowerArm", &"LeftLowerArm": &"LeftHand", &"LeftHand": &"LeftMiddleProximal",
	&"RightUpperArm": &"RightLowerArm", &"RightLowerArm": &"RightHand", &"RightHand": &"RightMiddleProximal",
	&"LeftUpperLeg": &"LeftLowerLeg", &"LeftLowerLeg": &"LeftFoot", &"LeftFoot": &"LeftToes",
	&"RightUpperLeg": &"RightLowerLeg", &"RightLowerLeg": &"RightFoot", &"RightFoot": &"RightToes",
}
## Top-down order so each aim sees its parent's new pose.
const ORDER: Array[StringName] = [
	&"Hips", &"Spine", &"Chest", &"UpperChest", &"Neck", &"Head",
	&"LeftShoulder", &"RightShoulder",
	&"LeftUpperArm", &"LeftLowerArm", &"LeftHand", &"RightUpperArm", &"RightLowerArm", &"RightHand",
	&"LeftUpperLeg", &"LeftLowerLeg", &"LeftFoot", &"RightUpperLeg", &"RightLowerLeg", &"RightFoot",
]

var aims: Dictionary = {}
var turns: Dictionary = {}
var weight := 0.0
var keep_feet := false
## Extra hips drop (skeleton units), e.g. a landing squash.
var drop := 0.0


func set_pose(new_aims: Dictionary, new_turns := {}, feet := false) -> void:
	aims = new_aims
	turns = new_turns
	keep_feet = feet


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or weight <= 0.001:
		return
	var feet_before := _feet(skeleton)
	for bone_name in ORDER:
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		if turns.has(bone_name):
			var e: Vector3 = turns[bone_name] * weight
			var q := Quaternion.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))
			var pose := skeleton.get_bone_global_pose(bone)
			pose.basis = Basis(q) * pose.basis
			skeleton.set_bone_global_pose(bone, pose)
		if aims.has(bone_name) and CHILD.has(bone_name):
			var child := skeleton.find_bone(CHILD[bone_name])
			if child < 0:
				continue
			var pose := skeleton.get_bone_global_pose(bone)
			var current := skeleton.get_bone_global_pose(child).origin - pose.origin
			if current.length_squared() < 1e-8:
				continue
			var target: Vector3 = (aims[bone_name] as Vector3).normalized()
			var arc := Quaternion(current.normalized(), target)
			pose.basis = Basis(Quaternion.IDENTITY.slerp(arc, weight)) * pose.basis
			skeleton.set_bone_global_pose(bone, pose)
	var lift := 0.0
	if keep_feet:
		var feet_after := _feet(skeleton)
		lift = (feet_after.x - feet_before.x + feet_after.y - feet_before.y) * 0.5
	if lift != 0.0 or drop != 0.0:
		var hips := skeleton.find_bone(&"Hips")
		var pose := skeleton.get_bone_global_pose(hips)
		pose.origin.y -= lift + drop * weight
		skeleton.set_bone_global_pose(hips, pose)


## Heights of the two feet (skeleton space).
func _feet(skeleton: Skeleton3D) -> Vector2:
	var l := skeleton.find_bone(&"LeftFoot")
	var r := skeleton.find_bone(&"RightFoot")
	if l < 0 or r < 0:
		return Vector2.ZERO
	return Vector2(skeleton.get_bone_global_pose(l).origin.y, skeleton.get_bone_global_pose(r).origin.y)
