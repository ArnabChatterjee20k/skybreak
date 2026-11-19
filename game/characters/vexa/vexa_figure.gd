@tool
class_name VexaFigure
extends Node3D
## Vexa as a toy action figure, built in code on _ready: a humanoid-profile
## skeleton plus rigid FigureKit parts. Also runs in the editor, so changing
## the design shows up when the scene is reopened.

const MATERIALS := {
	&"violet": "res://game/characters/vexa/materials/vexa_violet.tres",
	&"silver": "res://game/characters/vexa/materials/vexa_silver.tres",
	&"black": "res://game/characters/vexa/materials/vexa_black.tres",
	&"wrap": "res://game/characters/vexa/materials/vexa_wrap.tres",
	&"visor": "res://game/characters/vexa/materials/vexa_visor.tres",
	&"eyes": "res://game/characters/vexa/materials/vexa_eyes.tres",
}
## Fingers, eyes and jaw come from the profile's reference pose times this.
const PROFILE_SCALE := 1.3
## Secondary bones moved by springs, not by clips.
const HOOD_POINTS: Array[StringName] = [&"LeftHoodPoint", &"RightHoodPoint"]
const SASH_BONES: Array[StringName] = [&"SashUpper", &"SashLower"]

@export var design: VexaDesign
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
	var d := design if design else VexaDesign.new()
	skeleton = FigureRig.build_skeleton(joints(d), PROFILE_SCALE, extra_bones(d))
	add_child(skeleton)
	skeleton.owner = self
	skeleton.unique_name_in_owner = true
	var materials := {}
	for key: StringName in MATERIALS:
		materials[key] = load(MATERIALS[key])
	meshes = FigureRig.assemble(skeleton, parts(d), materials, assembly)


## Rest positions of the humanoid joints (T-pose).
static func joints(d: VexaDesign) -> Dictionary:
	var hips := d.hips_height
	var hip_joint := hips - 0.04
	var ankle := hips * 0.12
	var knee := (hip_joint + ankle) * 0.5
	var upper_chest := hips + 0.27
	var arm_y := upper_chest + 0.14
	var j := {
		&"Root": Vector3.ZERO,
		&"Hips": Vector3(0, hips, 0),
		&"Spine": Vector3(0, hips + 0.09, 0),
		&"Chest": Vector3(0, hips + 0.18, 0),
		&"UpperChest": Vector3(0, upper_chest, 0),
		&"Neck": Vector3(0, upper_chest + 0.17, 0),
		&"Head": Vector3(0, upper_chest + 0.24, 0),
	}
	for side: float in [1.0, -1.0]:
		var s := "Left" if side > 0 else "Right"
		var hand_x := d.shoulder_x + d.upper_arm_length + d.lower_arm_length
		j[StringName(s + "Shoulder")] = Vector3(0.05 * side, arm_y - 0.02, 0)
		j[StringName(s + "UpperArm")] = Vector3(d.shoulder_x * side, arm_y, 0)
		j[StringName(s + "LowerArm")] = Vector3((d.shoulder_x + d.upper_arm_length) * side, arm_y, 0)
		j[StringName(s + "Hand")] = Vector3(hand_x * side, arm_y, 0)
		j[StringName(s + "UpperLeg")] = Vector3(d.leg_x * side, hip_joint, 0)
		j[StringName(s + "LowerLeg")] = Vector3(d.leg_x * side, knee, 0)
		j[StringName(s + "Foot")] = Vector3(d.leg_x * side, ankle, 0)
		j[StringName(s + "Toes")] = Vector3(d.leg_x * side, 0.03, d.boot_size.z * 0.45)
	return j


static func extra_bones(d: VexaDesign) -> Array:
	var j := joints(d)
	var head: Vector3 = j[&"Head"]
	var bones := []
	for side: float in [1.0, -1.0]:
		bones.append({"name": HOOD_POINTS[0] if side > 0 else HOOD_POINTS[1], "parent": &"Head",
			"position": head + Vector3(0.12 * side, d.hood_size.y * 0.78, -0.05)})
	var hips: Vector3 = j[&"Hips"]
	bones.append({"name": SASH_BONES[0], "parent": &"Hips", "position": hips + Vector3(0, 0.07, -0.14)})
	bones.append({"name": SASH_BONES[1], "parent": SASH_BONES[0],
		"position": hips + Vector3(0, 0.07 - d.sash_length * 0.45, -0.19)})
	return bones


## Where each spring bone's tip rests, relative to the bone.
static func spring_tips(d: VexaDesign) -> Dictionary:
	var tips := {}
	for side: float in [1.0, -1.0]:
		var path := _ear_path(d, side)
		tips[HOOD_POINTS[0] if side > 0 else HOOD_POINTS[1]] = path[-1] - path[0]
	tips[SASH_BONES[0]] = Vector3(0, -d.sash_length * 0.45, -0.05)
	tips[SASH_BONES[1]] = Vector3(0.0, -d.sash_length * 0.55, -0.04)
	return tips


## Every rigid part, left parts mirrored to the right.
static func parts(d: VexaDesign) -> Array[FigureRig.Part]:
	var j := joints(d)
	var list: Array[FigureRig.Part] = []
	_torso(d, j, list)
	_head(d, j, list)
	for side: float in [1.0, -1.0]:
		_arm(d, j, side, list)
		_leg(d, j, side, list)
	_sash(d, j, list)
	return list


static func _torso(d: VexaDesign, j: Dictionary, list: Array[FigureRig.Part]) -> void:
	var hips: Vector3 = j[&"Hips"]
	var chest: Vector3 = j[&"Chest"]
	var upper: Vector3 = j[&"UpperChest"]
	var neck: Vector3 = j[&"Neck"]
	_add(list, &"Hips", &"black", FigureKit.rounded_box(d.pelvis_size, 0.45), hips + Vector3(0, -0.03, 0))
	_add(list, &"Hips", &"violet", FigureKit.torus(d.pelvis_size.x * 0.47, 0.034, 24, 8),
		Transform3D(Basis.from_scale(Vector3(1, 1, 0.8)), hips + Vector3(0, 0.07, 0)))
	_add(list, &"Hips", &"violet", FigureKit.rounded_box(Vector3(0.09, 0.08, 0.06), 0.5),
		hips + Vector3(0, 0.07, -0.13))
	_add(list, &"Chest", &"black", FigureKit.rounded_box(d.waist_size, 0.6), chest + Vector3(0, -0.02, 0))
	_add(list, &"UpperChest", &"silver", FigureKit.rounded_box(d.chest_size, 0.45),
		upper + Vector3(0, 0.04, -0.005))
	# Open jacket front: a black V of the suit underneath.
	var v_neck := PackedVector2Array([Vector2(-0.085, 0.1), Vector2(0.085, 0.1), Vector2(0.0, -0.11)])
	_add(list, &"UpperChest", &"black", FigureKit.extrude(v_neck, 0.05, 0.01),
		upper + Vector3(0, 0.07, d.chest_size.z * 0.44))
	# Mantle: the hood's drape over the shoulders.
	var mantle := PackedVector3Array()
	var mantle_radii := PackedVector2Array()
	for k in 5:
		var t := k / 4.0
		mantle.append(neck + Vector3(0, 0.06 - 0.16 * t, -0.02 - 0.02 * t))
		mantle_radii.append(Vector2(lerpf(0.1, 0.2, t * t), lerpf(0.1, 0.16, t * t)))
	_add(list, &"UpperChest", &"violet", FigureKit.loft(mantle, mantle_radii, 24, 0.8))
	# Orbit Chakram, carried on the back.
	var ring := Transform3D(Basis(Vector3.RIGHT, PI / 2), upper + Vector3(0, 0.02, -d.chest_size.z * 0.5 - 0.05))
	_add(list, &"UpperChest", &"silver", FigureKit.torus(d.chakram_radius, 0.026, 32, 8), ring)
	_add(list, &"UpperChest", &"eyes", FigureKit.torus(d.chakram_radius * 0.8, 0.01, 32, 6), ring)
	for k in 4:
		var angle := PI / 4 + PI / 2 * k
		var out := Vector3(cos(angle), 0, sin(angle))
		var tangent := Vector3(-sin(angle), 0, cos(angle))
		var r := d.chakram_radius
		var blade := PackedVector3Array([out * (r - 0.01), out * (r + 0.03) + tangent * 0.02,
			out * (r + 0.07) + tangent * 0.06])
		_add(list, &"UpperChest", &"silver", FigureKit.point(blade, Vector2(0.03, 0.012), 8, 1.0, Vector3.UP), ring)


static func _head(d: VexaDesign, j: Dictionary, list: Array[FigureRig.Part]) -> void:
	var head: Vector3 = j[&"Head"]
	var face := head + Vector3(0, d.head_size.y * 0.56, 0.02)
	_add(list, &"Head", &"black", FigureKit.rounded_box(d.head_size, 0.7), face)
	var visor_z := d.head_size.z * 0.36
	_add(list, &"Head", &"visor", FigureKit.rounded_box(Vector3(d.head_size.x * 0.9, 0.09, 0.1), 0.35),
		face + Vector3(0, 0.005, visor_z))
	var eye_z := visor_z + 0.052
	for side: float in [1.0, -1.0]:
		var eye := FigureKit.extrude(_eye_profile(), 0.02, 0.004)
		if side < 0:
			eye = eye.mirrored_x()
		_add(list, &"Head", &"eyes", eye, face + Vector3(0.068 * side, 0.008, eye_z))
	var hood := FigureKit.hood_shell(d.hood_size, d.hood_roundness, 0.025,
		d.hood_opening_half_width, d.hood_opening_top, d.hood_bottom)
	_add(list, &"Head", &"violet", hood, face + Vector3(0, 0.03, -0.035))
	for side: float in [1.0, -1.0]:
		var bone := HOOD_POINTS[0] if side > 0 else HOOD_POINTS[1]
		_add(list, bone, &"violet", FigureKit.point(_ear_path(d, side), d.ear_radius, 12, 0.9, Vector3.BACK, 1.6))
	# Widow's peak on the hood's brim.
	var peak := PackedVector2Array([Vector2(-0.07, 0.0), Vector2(0.07, 0.0), Vector2(0.0, -0.065)])
	var brim := face + Vector3(0, 0.03 + d.hood_size.y * 0.5 * sin(d.hood_opening_top) - 0.005,
		-0.035 + d.hood_size.z * 0.5 * cos(d.hood_opening_top) - 0.01)
	_add(list, &"Head", &"violet", FigureKit.extrude(peak, 0.035, 0.01),
		Transform3D(Basis(Vector3.RIGHT, -0.35), brim))


## Ear-like hood point: rises from the hood's top side, leans out and sweeps back.
static func _ear_path(d: VexaDesign, side: float) -> PackedVector3Array:
	var head: Vector3 = joints(d)[&"Head"]
	var base := head + Vector3(0.12 * side, d.hood_size.y * 0.78, -0.05)
	var path := PackedVector3Array()
	var steps := 5
	for i in steps + 1:
		var t := float(i) / steps
		var lean := d.ear_spread * t
		var sweep := d.ear_sweep * t * t
		var rise := Vector3(sin(lean) * side, cos(lean) * cos(sweep), -sin(sweep))
		path.append(base + rise * d.ear_length * t)
	return path


## A sly, upturned crescent: the eye of a grin.
static func _eye_profile() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8
		var x := lerpf(-0.05, 0.045, t)
		points.append(Vector2(x, 0.022 * sin(PI * t) - 0.004 + x * 0.25))
	for i in range(8, -1, -1):
		var t := float(i) / 8
		var x := lerpf(-0.05, 0.045, t)
		points.append(Vector2(x, -0.006 * sin(PI * t) - 0.012 + x * 0.25))
	# Drop the duplicated end points of the two arcs.
	points.remove_at(9)
	points.remove_at(points.size() - 1)
	return points


static func _arm(d: VexaDesign, j: Dictionary, side: float, list: Array[FigureRig.Part]) -> void:
	var s := "Left" if side > 0 else "Right"
	var upper: Vector3 = j[StringName(s + "UpperArm")]
	var lower: Vector3 = j[StringName(s + "LowerArm")]
	var hand: Vector3 = j[StringName(s + "Hand")]
	var x := Vector3(side, 0, 0)
	var r := d.limb_radius
	_add(list, StringName(s + "UpperArm"), &"silver",
		FigureKit.capsule(upper - x * 0.02, upper + x * 0.08, Vector2(0.095, 0.09), Vector2(0.085, 0.082)))
	_add(list, StringName(s + "UpperArm"), &"wrap",
		FigureKit.capsule(upper + x * 0.04, lower, Vector2(r, r), Vector2(r * 0.94, r * 0.94)))
	_wraps(list, StringName(s + "UpperArm"), upper + x * 0.11, lower - x * 0.01, r, r * 0.94, 3, side)
	_add(list, StringName(s + "LowerArm"), &"wrap",
		FigureKit.capsule(lower, hand - x * 0.02, Vector2(r * 0.94, r * 0.94), Vector2(r * 1.12, r * 1.12)))
	_wraps(list, StringName(s + "LowerArm"), lower + x * 0.05, hand - x * 0.04, r * 0.94, r * 1.12, 3, side)
	_add(list, StringName(s + "LowerArm"), &"silver", FigureKit.torus(r * 1.18, 0.024, 20, 8),
		Transform3D(Basis(Vector3.BACK, PI / 2), hand - x * 0.015))
	# Big wrapped fist with a Ki Gauntlet plate.
	var fist := hand + x * (d.fist_size.x * 0.5 + 0.005) + Vector3(0, -0.005, 0.005)
	_add(list, StringName(s + "Hand"), &"wrap", FigureKit.rounded_box(d.fist_size, 0.7), fist)
	_add(list, StringName(s + "Hand"), &"silver",
		FigureKit.rounded_box(Vector3(d.fist_size.x * 0.8, 0.045, d.fist_size.z * 0.92), 0.5),
		fist + Vector3(0, d.fist_size.y * 0.47, 0))
	var glow := fist + Vector3(0, d.fist_size.y * 0.5 + 0.022, 0)
	_add(list, StringName(s + "Hand"), &"eyes", FigureKit.capsule(glow - x * 0.045, glow + x * 0.045,
		Vector2(0.011, 0.011), Vector2(0.011, 0.011), 8, 2))


static func _leg(d: VexaDesign, j: Dictionary, side: float, list: Array[FigureRig.Part]) -> void:
	var s := "Left" if side > 0 else "Right"
	var hip: Vector3 = j[StringName(s + "UpperLeg")]
	var knee: Vector3 = j[StringName(s + "LowerLeg")]
	var ankle: Vector3 = j[StringName(s + "Foot")]
	_add(list, StringName(s + "UpperLeg"), &"black",
		FigureKit.capsule(hip, knee, Vector2(0.1, 0.1), Vector2(0.078, 0.078)))
	_add(list, StringName(s + "LowerLeg"), &"black",
		FigureKit.capsule(knee, ankle + Vector3(0, 0.03, 0), Vector2(0.076, 0.076), Vector2(0.064, 0.064)))
	_wraps(list, StringName(s + "LowerLeg"), knee + Vector3(0, -0.07, 0), ankle + Vector3(0, 0.1, 0), 0.074, 0.066, 3, side)
	var boot := Vector3(ankle.x, d.boot_size.y * 0.5, d.boot_size.z * 0.17)
	_add(list, StringName(s + "Foot"), &"black", FigureKit.rounded_box(d.boot_size, 0.5), boot)
	_add(list, StringName(s + "Foot"), &"silver",
		FigureKit.rounded_box(Vector3(d.boot_size.x * 1.04, 0.045, d.boot_size.z * 1.03), 0.4),
		Vector3(ankle.x, 0.022, boot.z))
	_add(list, StringName(s + "Foot"), &"silver", FigureKit.torus(0.074, 0.024, 20, 8),
		Vector3(ankle.x, d.boot_size.y + 0.01, 0))


## Cloth tails hanging from the sash knot, split over two spring bones.
static func _sash(d: VexaDesign, j: Dictionary, list: Array[FigureRig.Part]) -> void:
	var hips: Vector3 = j[&"Hips"]
	var top := hips + Vector3(0, 0.07, -0.14)
	var mid := top + Vector3(0, -d.sash_length * 0.45, -0.05)
	var end := mid + Vector3(0, -d.sash_length * 0.55, -0.04)
	for side: float in [1.0, -1.0]:
		var spread := Vector3(0.035 * side, 0, 0)
		_add(list, SASH_BONES[0], &"violet", FigureKit.cloth_flap(PackedVector3Array([
			top + spread * 0.6, top.lerp(mid, 0.5) + spread * 1.2, mid + spread * 1.5 + Vector3(0, -0.02, 0)]),
			0.075, 0.018, 1.0, 8))
		_add(list, SASH_BONES[1], &"violet", FigureKit.cloth_flap(PackedVector3Array([
			mid + spread * 1.5 + Vector3(0, 0.02, 0), mid.lerp(end, 0.5) + spread * 1.9, end + spread * 2.2]),
			0.075, 0.018, 0.45, 8))


## Bandage rings along a limb (along X for arms, Y for legs), slightly tilted.
static func _wraps(list: Array[FigureRig.Part], bone: StringName, from: Vector3, to: Vector3,
		radius_from: float, radius_to: float, count: int, side: float) -> void:
	var axis := (to - from).normalized()
	var to_axis := Basis() if absf(axis.y) > 0.9 else Basis(Vector3.BACK, -PI / 2 * side)
	for k in count:
		var t := float(k) / maxf(count - 1, 1)
		var tilt := Basis(Vector3.RIGHT if absf(axis.y) > 0.9 else Vector3.BACK, 0.18 * (1 if k % 2 == 0 else -1))
		var radius := lerpf(radius_from, radius_to, t) + 0.004
		_add(list, bone, &"wrap", FigureKit.torus(radius, 0.013, 18, 6),
			Transform3D(to_axis * tilt, from.lerp(to, t)))


static func _add(list: Array[FigureRig.Part], bone: StringName, material: StringName,
		shape: FigureShape, place: Variant = Transform3D.IDENTITY) -> void:
	var xform: Transform3D = place if place is Transform3D else Transform3D(Basis(), place)
	list.append(FigureRig.Part.new(bone, material, shape.transformed(xform)))
