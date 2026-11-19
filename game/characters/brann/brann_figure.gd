@tool
class_name BrannFigure
extends Node3D
## Brann as a toy action figure, built in code on _ready: a humanoid-profile
## skeleton plus rigid FigureKit parts, merged into one skinned mesh. A hulking
## stone smith: mossy boulder shoulders, forge-ember cracks, a leather apron,
## a braided ember-red beard and anvil-sized fists.

const MATERIALS := {
	&"stone": "res://game/characters/brann/materials/brann_stone.tres",
	&"moss": "res://game/characters/brann/materials/brann_moss.tres",
	&"leather": "res://game/characters/brann/materials/brann_leather.tres",
	&"beard": "res://game/characters/brann/materials/brann_beard.tres",
	&"iron": "res://game/characters/brann/materials/brann_iron.tres",
	&"cloth": "res://game/characters/brann/materials/brann_cloth.tres",
	&"ember": "res://game/characters/brann/materials/brann_ember.tres",
	&"eyes": "res://game/characters/brann/materials/brann_eyes.tres",
}
## Fingers, eyes and jaw come from the profile's reference pose times this.
const PROFILE_SCALE := 1.4
## Secondary bones moved by springs, not by clips.
const BRAID_BONE := &"BeardBraid"
const APRON_BONE := &"ApronFlap"
const SPRING_BONES: Array[StringName] = [BRAID_BONE, APRON_BONE]
## How far crack glows sit proud of the stone.
const CRACK_LIFT := 0.004

@export var design: BrannDesign
@export var assembly := FigureRig.Assembly.MERGED

var skeleton: Skeleton3D
var meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	build()


## (Re)builds the skeleton and every part from the design.
func build() -> void:
	for child in get_children():
		if child.name == FigureRig.SKELETON_NAME:
			remove_child(child)
			child.free()
	var d := design if design else BrannDesign.new()
	skeleton = FigureRig.build_skeleton(joints(d), PROFILE_SCALE, extra_bones(d))
	add_child(skeleton)
	skeleton.owner = self
	skeleton.unique_name_in_owner = true
	var materials := {}
	for key: StringName in MATERIALS:
		materials[key] = load(MATERIALS[key])
	meshes = FigureRig.assemble(skeleton, parts(d), materials, assembly)


## Rest positions of the humanoid joints (T-pose).
static func joints(d: BrannDesign) -> Dictionary:
	var hips := d.hips_height
	var hip_joint := hips - 0.06
	var ankle := 0.11
	var knee := (hip_joint + ankle) * 0.5
	var upper_chest := hips + 0.44
	var arm_y := upper_chest + 0.2
	var j := {
		&"Root": Vector3.ZERO,
		&"Hips": Vector3(0, hips, 0),
		&"Spine": Vector3(0, hips + 0.13, 0),
		&"Chest": Vector3(0, hips + 0.28, 0),
		&"UpperChest": Vector3(0, upper_chest, 0),
		&"Neck": Vector3(0, upper_chest + 0.26, 0.02),
		&"Head": Vector3(0, upper_chest + 0.29, 0.03),
	}
	for side: float in [1.0, -1.0]:
		var s := "Left" if side > 0 else "Right"
		var hand_x := d.shoulder_x + d.upper_arm_length + d.lower_arm_length
		j[StringName(s + "Shoulder")] = Vector3(0.1 * side, arm_y - 0.03, 0)
		j[StringName(s + "UpperArm")] = Vector3(d.shoulder_x * side, arm_y, 0)
		j[StringName(s + "LowerArm")] = Vector3((d.shoulder_x + d.upper_arm_length) * side, arm_y, 0)
		j[StringName(s + "Hand")] = Vector3(hand_x * side, arm_y, 0)
		j[StringName(s + "UpperLeg")] = Vector3(d.leg_x * side, hip_joint, 0)
		j[StringName(s + "LowerLeg")] = Vector3(d.leg_x * side, knee, 0.01)
		j[StringName(s + "Foot")] = Vector3(d.leg_x * side, ankle, 0)
		j[StringName(s + "Toes")] = Vector3(d.leg_x * side, 0.04, d.boot_size.z * 0.5)
	return j


## Where the braid hangs from the chin, and where the apron hangs from the belt.
static func braid_root(d: BrannDesign) -> Vector3:
	return _face(d, joints(d)) + Vector3(0, -d.beard_size.y * 0.5 - 0.1, 0.2)


static func apron_root(d: BrannDesign) -> Vector3:
	return Vector3(0, d.hips_height + 0.08, d.belly_size.z * 0.5 + 0.03)


static func extra_bones(d: BrannDesign) -> Array:
	return [
		{"name": BRAID_BONE, "parent": &"Head", "position": braid_root(d)},
		{"name": APRON_BONE, "parent": &"Hips", "position": apron_root(d)},
	]


## Where each spring bone's tip rests, relative to the bone.
static func spring_tips(d: BrannDesign) -> Dictionary:
	return {
		BRAID_BONE: Vector3(0, -d.braid_length, 0.08),
		APRON_BONE: Vector3(0, -d.apron_length, 0.04),
	}


## Every rigid part, left parts mirrored to the right.
static func parts(d: BrannDesign) -> Array[FigureRig.Part]:
	var j := joints(d)
	var list: Array[FigureRig.Part] = []
	_torso(d, j, list)
	_apron(d, j, list)
	_head(d, j, list)
	for side: float in [1.0, -1.0]:
		_shoulder(d, j, side, list)
		_arm(d, j, side, list)
		_leg(d, j, side, list)
	return list


static func _face(d: BrannDesign, j: Dictionary) -> Vector3:
	return (j[&"Head"] as Vector3) + Vector3(0, d.head_size.y * 0.5, 0.02)


static func _torso(d: BrannDesign, j: Dictionary, list: Array[FigureRig.Part]) -> void:
	var hips: Vector3 = j[&"Hips"]
	var chest: Vector3 = j[&"Chest"]
	var upper: Vector3 = j[&"UpperChest"]
	var neck: Vector3 = j[&"Neck"]
	_add(list, &"Hips", &"cloth", FigureKit.rounded_box(d.pelvis_size, 0.5), hips + Vector3(0, -0.03, 0))
	var belly := FigureKit.rounded_box(d.belly_size, 0.55).transformed(
		Transform3D(Basis(), chest + Vector3(0, -0.02, 0.0)))
	list.append(FigureRig.Part.new(&"Chest", &"stone", belly))
	var torso := FigureKit.rounded_box(d.chest_size, 0.42).transformed(
		Transform3D(Basis(), upper + Vector3(0, 0.06, -0.01)))
	list.append(FigureRig.Part.new(&"UpperChest", &"stone", torso))
	_add(list, &"Neck", &"stone", FigureKit.capsule(neck + Vector3(0, -0.1, -0.02), neck + Vector3(0, 0.08, 0),
		Vector2(0.16, 0.14), Vector2(0.13, 0.12)))
	# Belt with a square iron buckle and tongs hung at the hip.
	var belt_y := hips.y + 0.08
	_add(list, &"Hips", &"leather", FigureKit.torus(d.belly_size.x * 0.46, 0.045, 28, 8, Vector2(1.0, 1.3)),
		Transform3D(Basis.from_scale(Vector3(1, 1, d.belly_size.z / d.belly_size.x * 1.02)), Vector3(0, belt_y, 0)))
	_add(list, &"Hips", &"iron", FigureKit.rounded_box(Vector3(0.14, 0.12, 0.05), 0.35),
		Vector3(0, belt_y, d.belly_size.z * 0.48 + 0.03))
	_add(list, &"Hips", &"leather", FigureKit.rounded_box(Vector3(0.08, 0.06, 0.055), 0.4),
		Vector3(0, belt_y, d.belly_size.z * 0.48 + 0.04))
	for k in 2:
		var x := -d.belly_size.x * 0.45 + 0.04 * k
		_add(list, &"Hips", &"iron", FigureKit.capsule(Vector3(x, belt_y - 0.02, 0.12 + 0.03 * k),
			Vector3(x - 0.05, belt_y - 0.3, 0.16 + 0.05 * k), Vector2(0.018, 0.018), Vector2(0.016, 0.016), 6, 1))
	# Forge-ember cracks across the stone: chest sides, belly and back.
	var front_cracks := [
		[Vector2(0.27, 1.5), Vector2(0.33, 1.41), Vector2(0.28, 1.33), Vector2(0.36, 1.22)],
		[Vector2(0.33, 1.41), Vector2(0.4, 1.38)],
		[Vector2(-0.3, 1.47), Vector2(-0.26, 1.37), Vector2(-0.34, 1.29), Vector2(-0.3, 1.18)],
	]
	for crack: Array in front_cracks:
		_crack(list, &"UpperChest", torso, crack, true, 0.024)
	_crack(list, &"Chest", belly, [Vector2(0.3, 1.1), Vector2(0.26, 1.02), Vector2(0.31, 0.95)], true, 0.02)
	_crack(list, &"Chest", belly, [Vector2(-0.27, 1.06), Vector2(-0.31, 0.98)], true, 0.018)
	var back_cracks := [
		[Vector2(0.04, 1.52), Vector2(-0.06, 1.42), Vector2(0.05, 1.3), Vector2(-0.04, 1.16)],
		[Vector2(-0.06, 1.42), Vector2(-0.2, 1.38), Vector2(-0.26, 1.44)],
		[Vector2(0.05, 1.3), Vector2(0.2, 1.25)],
	]
	for crack: Array in back_cracks:
		_crack(list, &"UpperChest", torso, crack, false, 0.026)


## Leather smith's apron: a bib on the chest with straps over the shoulders and
## a skirt that swings from the belt on a spring bone.
static func _apron(d: BrannDesign, j: Dictionary, list: Array[FigureRig.Part]) -> void:
	var upper: Vector3 = j[&"UpperChest"]
	var top := upper.y + 0.22
	var bottom := d.hips_height + 0.12
	var half_top := d.apron_width * 0.36
	var half_bottom := d.apron_width * 0.5
	var bib := PackedVector2Array([Vector2(-half_bottom, bottom - top), Vector2(half_bottom, bottom - top),
		Vector2(half_top, 0.0), Vector2(-half_top, 0.0)])
	var z := d.chest_size.z * 0.5 + 0.0
	_add(list, &"UpperChest", &"leather", FigureKit.extrude(bib, 0.035, 0.012),
		Transform3D(Basis(Vector3.RIGHT, 0.06), Vector3(0, top, z)))
	# A hammer-and-flame mark burnt into the bib.
	var mark := PackedVector2Array([Vector2(-0.05, 0.03), Vector2(0.05, 0.03), Vector2(0.05, -0.01),
		Vector2(0.015, -0.01), Vector2(0.015, -0.08), Vector2(-0.015, -0.08), Vector2(-0.015, -0.01),
		Vector2(-0.05, -0.01)])
	_add(list, &"UpperChest", &"ember", FigureKit.extrude(mark, 0.012, 0.003),
		Vector3(0, top - 0.12, z + 0.035))
	for side: float in [1.0, -1.0]:
		var strap := PackedVector3Array([
			Vector3(half_top * 0.8 * side, top - 0.01, z + 0.01),
			Vector3(0.2 * side, upper.y + 0.29, 0.14),
			Vector3(0.23 * side, upper.y + 0.3, -0.12),
			Vector3(0.24 * side, upper.y + 0.16, -d.chest_size.z * 0.5 - 0.01),
		])
		var radii := PackedVector2Array()
		for k in strap.size():
			radii.append(Vector2(0.03, 0.03))
		_add(list, &"UpperChest", &"leather", FigureKit.loft(strap, radii, 8, 0.6, strap[0], strap[-1]))
	var root := apron_root(d)
	var tip: Vector3 = root + spring_tips(d)[APRON_BONE]
	_add(list, APRON_BONE, &"leather", FigureKit.cloth_flap(PackedVector3Array([root + Vector3(0, 0.02, -0.01),
		root.lerp(tip, 0.5) + Vector3(0, 0, 0.02), tip]), half_bottom * 2.0, 0.03, 0.85, 6))
	_add(list, APRON_BONE, &"iron", FigureKit.torus(0.03, 0.01, 12, 6),
		Transform3D(Basis(Vector3.RIGHT, PI / 2), root.lerp(tip, 0.75) + Vector3(0.1, 0, 0.035)))


static func _head(d: BrannDesign, j: Dictionary, list: Array[FigureRig.Part]) -> void:
	var face := _face(d, j)
	var skull := FigureKit.rounded_box(d.head_size, 0.5).transformed(Transform3D(Basis(), face))
	list.append(FigureRig.Part.new(&"Head", &"stone", skull))
	var front := face.z + d.head_size.z * 0.5
	# Heavy brow ridge in a shallow V, with glowing eyes in its shadow.
	for side: float in [1.0, -1.0]:
		_add(list, &"Head", &"stone", FigureKit.rounded_box(Vector3(d.brow_size.x * 0.55, d.brow_size.y,
			d.brow_size.z), 0.5, 12, 8), Transform3D(Basis(Vector3.BACK, -0.16 * side),
			face + Vector3(0.1 * side, 0.06, d.head_size.z * 0.42)))
		var eye := PackedVector2Array([Vector2(-0.05, 0.02), Vector2(0.05, 0.004), Vector2(0.045, -0.018),
			Vector2(-0.045, -0.012)])
		var shape := FigureKit.extrude(eye, 0.02, 0.004)
		if side < 0:
			shape = shape.mirrored_x()
		_add(list, &"Head", &"eyes", shape, face + Vector3(0.095 * side, -0.018, front + 0.01))
	_add(list, &"Head", &"stone", FigureKit.rounded_box(Vector3(0.11, 0.12, 0.1), 0.6, 12, 8),
		face + Vector3(0, -0.05, front + 0.02))
	# Cheek crack under the left eye.
	_crack(list, &"Head", skull, [Vector2(0.17, 0.12 + face.y), Vector2(0.13, 0.17 + face.y),
		Vector2(0.15, 0.2 + face.y)], true, 0.014)
	_add(list, &"Head", &"moss", FigureKit.rounded_box(Vector3(0.2, 0.06, 0.18), 0.85, 12, 6),
		Transform3D(Basis(Vector3.BACK, 0.15), face + Vector3(0.07, d.head_size.y * 0.48, -0.04)))
	# Square block beard and a heavy moustache.
	_add(list, &"Head", &"beard", FigureKit.rounded_box(d.beard_size, 0.45),
		face + Vector3(0, -d.head_size.y * 0.5 + 0.03, d.head_size.z * 0.32))
	for side: float in [1.0, -1.0]:
		_add(list, &"Head", &"beard", FigureKit.point(PackedVector3Array([
			face + Vector3(0.01 * side, -0.1, front + 0.02), face + Vector3(0.1 * side, -0.115, front + 0.01),
			face + Vector3(0.17 * side, -0.18, front - 0.02)]), Vector2(0.04, 0.03), 8, 1.0, Vector3.BACK, 1.4))
	# One thick braid with iron rings, swinging on its spring bone.
	var root := braid_root(d)
	var tip: Vector3 = root + spring_tips(d)[BRAID_BONE]
	var lobes := 3
	for k in lobes:
		var t := (k + 0.5) / lobes
		var lobe := root.lerp(tip, t * 0.85)
		var r := d.braid_radius * lerpf(1.25, 0.95, t)
		_add(list, BRAID_BONE, &"beard", FigureKit.rounded_box(Vector3(r * 2.0, r * 2.3, r * 1.8), 0.9, 12, 8),
			Transform3D(Basis(Vector3.BACK, 0.35 * (1 if k % 2 == 0 else -1)), lobe))
	for t: float in [0.33, 0.62]:
		_add(list, BRAID_BONE, &"iron", FigureKit.torus(d.braid_radius * 1.05, 0.02, 14, 6),
			root.lerp(tip, t * 0.85 + 0.04))
	_add(list, BRAID_BONE, &"beard", FigureKit.point(PackedVector3Array([root.lerp(tip, 0.85),
		root.lerp(tip, 0.94) + Vector3(0, 0, 0.01), tip]), Vector2(0.05, 0.045), 8, 1.0, Vector3.BACK, 1.3))


## Mossy boulder on the clavicle, with a smaller rock wedged on top.
static func _shoulder(d: BrannDesign, j: Dictionary, side: float, list: Array[FigureRig.Part]) -> void:
	var s := "Left" if side > 0 else "Right"
	var bone := StringName(s + "Shoulder")
	var arm: Vector3 = j[StringName(s + "UpperArm")]
	var place := Transform3D(Basis(Vector3.UP, 0.2 * side) * Basis(Vector3.BACK, 0.28 * side),
		arm + Vector3(0.03 * side, 0.12, -0.02))
	var b := d.boulder_size
	_add(list, bone, &"stone", FigureKit.rounded_box(b, 0.32), place)
	_add(list, bone, &"stone", FigureKit.rounded_box(Vector3(0.2, 0.17, 0.22), 0.3, 12, 8),
		place * Transform3D(Basis(Vector3.FORWARD, 0.4 * side), Vector3(-0.06 * side, b.y * 0.42, -0.08)))
	_add(list, bone, &"moss", FigureKit.rounded_box(Vector3(b.x * 0.86, 0.07, b.z * 0.82), 0.85, 14, 6),
		place * Transform3D(Basis(), Vector3(0.02 * side, b.y * 0.47, 0.04)))
	_add(list, bone, &"moss", FigureKit.rounded_box(Vector3(0.1, 0.12, 0.1), 0.9, 10, 6),
		place * Transform3D(Basis(), Vector3(0.12 * side, b.y * 0.36, 0.17)))
	var crack_rock := FigureKit.rounded_box(b, 0.32).transformed(place)
	_crack(list, bone, crack_rock, [Vector2(arm.x + 0.06 * side, arm.y + 0.15),
		Vector2(arm.x + 0.12 * side, arm.y + 0.07), Vector2(arm.x + 0.09 * side, arm.y - 0.01)], true, 0.018)


static func _arm(d: BrannDesign, j: Dictionary, side: float, list: Array[FigureRig.Part]) -> void:
	var s := "Left" if side > 0 else "Right"
	var upper: Vector3 = j[StringName(s + "UpperArm")]
	var lower: Vector3 = j[StringName(s + "LowerArm")]
	var hand: Vector3 = j[StringName(s + "Hand")]
	var x := Vector3(side, 0, 0)
	var ra := d.arm_radius
	var rf := d.forearm_radius
	var upper_arm := FigureKit.capsule(upper - x * 0.04, lower, Vector2(ra * 1.1, ra * 1.1), Vector2(ra * 0.9, ra * 0.9))
	list.append(FigureRig.Part.new(StringName(s + "UpperArm"), &"stone", upper_arm))
	_crack(list, StringName(s + "UpperArm"), upper_arm, [Vector2(upper.x + 0.06 * side, upper.y + 0.02),
		Vector2(upper.x + 0.13 * side, upper.y - 0.03), Vector2(upper.x + 0.2 * side, upper.y + 0.01)], true, 0.016)
	var forearm := FigureKit.capsule(lower, hand - x * 0.02, Vector2(rf * 0.85, rf * 0.85), Vector2(rf, rf))
	list.append(FigureRig.Part.new(StringName(s + "LowerArm"), &"stone", forearm))
	_add(list, StringName(s + "LowerArm"), &"stone", FigureKit.rounded_box(Vector3(0.16, 0.07, 0.15), 0.4, 12, 6),
		Transform3D(Basis(Vector3.BACK, 0.12 * side), lower + x * 0.11 + Vector3(0, rf * 0.88, 0)))
	_crack(list, StringName(s + "LowerArm"), forearm, [Vector2(lower.x + 0.04 * side, lower.y - 0.01),
		Vector2(lower.x + 0.12 * side, lower.y + 0.03), Vector2(lower.x + 0.19 * side, lower.y - 0.02)], true, 0.016)
	_add(list, StringName(s + "LowerArm"), &"iron", FigureKit.torus(rf * 1.05, 0.035, 20, 8, Vector2(0.8, 1.4)),
		Transform3D(Basis(Vector3.BACK, PI / 2), hand - x * 0.05))
	# Anvil fist: a blocky stone hand with a ridge of knuckles and a thumb.
	var f := d.fist_size
	var fist := hand + x * (f.x * 0.5 - 0.01) + Vector3(0, -0.01, 0)
	_add(list, StringName(s + "Hand"), &"stone", FigureKit.rounded_box(f, 0.38), fist)
	for k in 4:
		var z := lerpf(-f.z * 0.32, f.z * 0.32, k / 3.0)
		_add(list, StringName(s + "Hand"), &"stone", FigureKit.rounded_box(Vector3(0.07, 0.085, 0.07), 0.6, 10, 6),
			fist + Vector3(side * f.x * 0.47, f.y * 0.2, z))
	_add(list, StringName(s + "Hand"), &"stone", FigureKit.capsule(fist + Vector3(-side * 0.05, -0.02, f.z * 0.48),
		fist + Vector3(side * 0.06, -0.04, f.z * 0.5), Vector2(0.05, 0.05), Vector2(0.045, 0.045), 8, 2))
	_add(list, StringName(s + "Hand"), &"ember", FigureKit.capsule(fist + Vector3(side * f.x * 0.5, f.y * 0.2 - 0.05, -f.z * 0.3),
		fist + Vector3(side * f.x * 0.5, f.y * 0.2 - 0.05, f.z * 0.3), Vector2(0.012, 0.012), Vector2(0.012, 0.012), 6, 1))


static func _leg(d: BrannDesign, j: Dictionary, side: float, list: Array[FigureRig.Part]) -> void:
	var s := "Left" if side > 0 else "Right"
	var hip: Vector3 = j[StringName(s + "UpperLeg")]
	var knee: Vector3 = j[StringName(s + "LowerLeg")]
	var ankle: Vector3 = j[StringName(s + "Foot")]
	var r := d.thigh_radius
	_add(list, StringName(s + "UpperLeg"), &"cloth", FigureKit.capsule(hip, knee, Vector2(r, r), Vector2(r * 0.85, r * 0.85)))
	_add(list, StringName(s + "LowerLeg"), &"cloth",
		FigureKit.capsule(knee, ankle + Vector3(0, 0.06, 0), Vector2(r * 0.85, r * 0.85), Vector2(r * 0.95, r * 0.95)))
	_add(list, StringName(s + "LowerLeg"), &"iron", FigureKit.rounded_box(Vector3(0.15, 0.13, 0.08), 0.5, 12, 8),
		knee + Vector3(0, -0.02, r * 0.8))
	_add(list, StringName(s + "LowerLeg"), &"leather", FigureKit.torus(r * 0.98, 0.04, 20, 8),
		ankle + Vector3(0, 0.1, 0))
	var b := d.boot_size
	var boot := Vector3(ankle.x, b.y * 0.5, b.z * 0.18)
	_add(list, StringName(s + "Foot"), &"leather", FigureKit.rounded_box(b, 0.45), boot)
	_add(list, StringName(s + "Foot"), &"iron", FigureKit.rounded_box(Vector3(b.x * 1.04, b.y * 0.7, b.z * 0.38), 0.45),
		boot + Vector3(0, -b.y * 0.12, b.z * 0.34))
	_add(list, StringName(s + "Foot"), &"iron", FigureKit.rounded_box(Vector3(b.x * 1.06, 0.05, b.z * 1.04), 0.4),
		Vector3(ankle.x, 0.025, boot.z))


## A glowing crack traced over the stone: points are (x, y) on the shape's
## front (+Z) or back face; it tapers to its last point.
static func _crack(list: Array[FigureRig.Part], bone: StringName, surface: FigureShape, points: Array,
		front: bool, width: float) -> void:
	var path := PackedVector3Array()
	for p: Vector2 in points:
		path.append(_on_surface(surface, p, front))
	if path.size() == 2:
		path.insert(1, path[0].lerp(path[1], 0.5))
	var hint := Vector3.BACK if front else Vector3.FORWARD
	list.append(FigureRig.Part.new(bone, &"ember", FigureKit.point(path, Vector2(width, width * 0.6), 6, 1.0,
		hint, 1.6)))


## Where a ray along Z through (x, y) first meets the shape, lifted off it.
static func _on_surface(shape: FigureShape, at: Vector2, front: bool) -> Vector3:
	var direction := Vector3.FORWARD if front else Vector3.BACK
	var origin := Vector3(at.x, at.y, -direction.z * 10.0)
	var best := INF
	for t in range(0, shape.indices.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin, direction, shape.vertices[shape.indices[t]],
			shape.vertices[shape.indices[t + 1]], shape.vertices[shape.indices[t + 2]])
		if hit != null:
			best = minf(best, origin.distance_to(hit))
	if best == INF:
		return Vector3(at.x, at.y, 0.0)
	return origin + direction * (best - CRACK_LIFT)


static func _add(list: Array[FigureRig.Part], bone: StringName, material: StringName,
		shape: FigureShape, place: Variant = Transform3D.IDENTITY) -> void:
	var xform: Transform3D = place if place is Transform3D else Transform3D(Basis(), place)
	list.append(FigureRig.Part.new(bone, material, shape.transformed(xform)))
