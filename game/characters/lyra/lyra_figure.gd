@tool
class_name LyraFigure
extends Node3D
## Lyra, the star-cartographer mage, as a toy action figure built in code on
## _ready: a humanoid-profile skeleton plus rigid FigureKit parts (merged), a
## two-chain star-map cape on spring bones and a floating astrolabe bone.

const MATERIALS := {
	&"navy": "res://game/characters/lyra/materials/lyra_navy.tres",
	&"night": "res://game/characters/lyra/materials/lyra_night.tres",
	&"parchment": "res://game/characters/lyra/materials/lyra_parchment.tres",
	&"brass": "res://game/characters/lyra/materials/lyra_brass.tres",
	&"skin": "res://game/characters/lyra/materials/lyra_skin.tres",
	&"hair": "res://game/characters/lyra/materials/lyra_hair.tres",
	&"ink": "res://game/characters/lyra/materials/lyra_ink.tres",
	&"star": "res://game/characters/lyra/materials/lyra_star.tres",
}
## Fingers, eyes and jaw come from the profile's reference pose times this.
const PROFILE_SCALE := 1.25
## Cape chains (upper, lower) per side; moved by springs, not by clips.
const CAPE_BONES: Array[StringName] = [&"CapeLeftUpper", &"CapeLeftLower", &"CapeRightUpper", &"CapeRightLower"]
## Floating astrolabe over her right shoulder; the view spins it.
const ASTROLABE_BONE := &"Astrolabe"
## Constellation on each cape half: (across, down) in 0..1 of the half.
const CAPE_STARS := [Vector2(0.3, 0.12), Vector2(-0.25, 0.3), Vector2(0.15, 0.5), Vector2(-0.3, 0.68),
	Vector2(0.25, 0.86)]
## Constellation on the brim: (angle in degrees from the front, fraction of the radius).
const BRIM_STARS := [Vector2(-60, 0.8), Vector2(-25, 0.66), Vector2(20, 0.82), Vector2(55, 0.68),
	Vector2(150, 0.78), Vector2(205, 0.7)]

@export var design: LyraDesign
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
	var d := design if design else LyraDesign.new()
	skeleton = FigureRig.build_skeleton(joints(d), PROFILE_SCALE, extra_bones(d))
	add_child(skeleton)
	skeleton.owner = self
	skeleton.unique_name_in_owner = true
	var materials := {}
	for key: StringName in MATERIALS:
		materials[key] = load(MATERIALS[key])
	meshes = FigureRig.assemble(skeleton, parts(d), materials, assembly)


## Rest positions of the humanoid joints (T-pose).
static func joints(d: LyraDesign) -> Dictionary:
	var hips := d.hips_height
	var hip_joint := hips - 0.04
	var ankle := hips * 0.13
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


static func extra_bones(d: LyraDesign) -> Array:
	var bones := []
	for side: float in [1.0, -1.0]:
		var path := _cape_path(d, side)
		var upper := CAPE_BONES[0] if side > 0 else CAPE_BONES[2]
		var lower := CAPE_BONES[1] if side > 0 else CAPE_BONES[3]
		bones.append({"name": upper, "parent": &"UpperChest", "position": path[0]})
		bones.append({"name": lower, "parent": upper, "position": path[1]})
	bones.append({"name": ASTROLABE_BONE, "parent": &"UpperChest", "position": astrolabe_center(d)})
	return bones


## Where each spring bone's tip rests, relative to the bone.
static func spring_tips(d: LyraDesign) -> Dictionary:
	var tips := {}
	for side: float in [1.0, -1.0]:
		var path := _cape_path(d, side)
		tips[CAPE_BONES[0] if side > 0 else CAPE_BONES[2]] = path[1] - path[0]
		tips[CAPE_BONES[1] if side > 0 else CAPE_BONES[3]] = path[2] - path[1]
	return tips


static func astrolabe_center(d: LyraDesign) -> Vector3:
	var upper: Vector3 = joints(d)[&"UpperChest"]
	return upper + Vector3(-0.4, 0.36, -0.12)


## Every rigid part, left parts mirrored to the right.
static func parts(d: LyraDesign) -> Array[FigureRig.Part]:
	var j := joints(d)
	var list: Array[FigureRig.Part] = []
	_torso(d, j, list)
	_head(d, j, list)
	_hat(d, j, list)
	for side: float in [1.0, -1.0]:
		_arm(d, j, side, list)
		_leg(d, j, side, list)
		_cape(d, side, list)
	_astrolabe(d, list)
	_weapons(d, j, list)
	return list


static func _torso(d: LyraDesign, j: Dictionary, list: Array[FigureRig.Part]) -> void:
	var hips: Vector3 = j[&"Hips"]
	var chest: Vector3 = j[&"Chest"]
	var upper: Vector3 = j[&"UpperChest"]
	var neck: Vector3 = j[&"Neck"]
	# Robe skirt flaring from the waist, with a parchment hem.
	var skirt := PackedVector3Array()
	var skirt_radii := PackedVector2Array()
	for k in 5:
		var t := k / 4.0
		skirt.append(hips + Vector3(0, 0.07 - (d.skirt_length + 0.07) * t, -0.01 * t))
		skirt_radii.append(Vector2(lerpf(0.18, d.skirt_hem.x, t), lerpf(0.14, d.skirt_hem.y, t)))
	_add(list, &"Hips", &"navy", FigureKit.loft(skirt, skirt_radii, 24, 0.9))
	var hem: Vector3 = skirt[-1] + Vector3(0, 0.01, 0)
	_add(list, &"Hips", &"parchment", FigureKit.torus(d.skirt_hem.x - 0.005, 0.026, 28, 6),
		Transform3D(Basis.from_scale(Vector3(1, 1, d.skirt_hem.y / d.skirt_hem.x)), hem))
	# Sash with a brass star buckle.
	_add(list, &"Hips", &"parchment", FigureKit.torus(0.175, 0.036, 24, 8),
		Transform3D(Basis.from_scale(Vector3(1, 1, 0.8)), hips + Vector3(0, 0.07, 0)))
	_add(list, &"Hips", &"brass", FigureKit.extrude(_star_profile(0.06, 0.026), 0.03, 0.008),
		hips + Vector3(0, 0.07, 0.15))
	_add(list, &"Chest", &"navy", FigureKit.rounded_box(d.waist_size, 0.6), chest + Vector3(0, -0.02, 0))
	_add(list, &"UpperChest", &"navy", FigureKit.rounded_box(d.chest_size, 0.5), upper + Vector3(0, 0.04, -0.005))
	# Parchment shirt front with two brass buttons.
	var front := PackedVector2Array([Vector2(-0.09, 0.11), Vector2(0.09, 0.11), Vector2(0.05, -0.12),
		Vector2(-0.05, -0.12)])
	_add(list, &"UpperChest", &"parchment", FigureKit.extrude(front, 0.05, 0.01),
		upper + Vector3(0, 0.05, d.chest_size.z * 0.42))
	for k in 2:
		_add(list, &"UpperChest", &"brass", FigureKit.rounded_box(Vector3.ONE * 0.03, 1.0, 8, 6),
			upper + Vector3(0, 0.07 - 0.08 * k, d.chest_size.z * 0.42 + 0.03))
	# High collar the cape hangs from, closed by a brass clasp.
	var collar := PackedVector3Array()
	var collar_radii := PackedVector2Array()
	for k in 5:
		var t := k / 4.0
		collar.append(neck + Vector3(0, 0.06 - 0.15 * t, -0.02 - 0.02 * t))
		collar_radii.append(Vector2(lerpf(0.1, 0.21, t * t), lerpf(0.1, 0.17, t * t)))
	_add(list, &"UpperChest", &"navy", FigureKit.loft(collar, collar_radii, 24, 0.8))
	var clasp := neck + Vector3(0, -0.06, 0.15)
	_add(list, &"UpperChest", &"brass", FigureKit.torus(0.035, 0.012, 16, 6), Transform3D(Basis(Vector3.RIGHT, PI / 2), clasp))
	_add(list, &"UpperChest", &"star", FigureKit.rounded_box(Vector3.ONE * 0.03, 1.0, 8, 6), clasp)


static func _head(d: LyraDesign, j: Dictionary, list: Array[FigureRig.Part]) -> void:
	var face := face_center(d)
	var h := d.head_size
	_add(list, &"Head", &"skin", FigureKit.rounded_box(h, 0.75), face)
	# Hair: a cap over the top and back, a fringe of bangs and two side locks.
	_add(list, &"Head", &"hair", FigureKit.rounded_box(Vector3(h.x * 1.08, h.y * 0.6, h.z * 1.08), 0.7),
		face + Vector3(0, h.y * 0.24, -0.015))
	_add(list, &"Head", &"hair", FigureKit.rounded_box(Vector3(h.x * 1.05, h.y * 0.82, h.z * 0.62), 0.7),
		face + Vector3(0, -0.01, -h.z * 0.27))
	_add(list, &"Head", &"hair", FigureKit.extrude(_bangs_profile(h.x * 0.98), 0.06, 0.012),
		face + Vector3(0, h.y * 0.3, h.z * 0.44))
	for side: float in [1.0, -1.0]:
		var top := face + Vector3(h.x * 0.47 * side, 0.07, 0.03)
		_add(list, &"Head", &"hair", FigureKit.capsule(top, top + Vector3(0.012 * side, -0.2, 0.01),
			Vector2(0.045, 0.04), Vector2(0.03, 0.028)))
		# Big round eyes with a starlight glint.
		var eye := face + Vector3(0.078 * side, -0.02, h.z * 0.47)
		_add(list, &"Head", &"ink", FigureKit.extrude(_eye_profile(), 0.03, 0.006), eye)
		_add(list, &"Head", &"star", FigureKit.rounded_box(Vector3(0.024, 0.024, 0.014), 1.0, 8, 6),
			eye + Vector3(0.014 * side, 0.02, 0.014))
	_add(list, &"Head", &"ink", FigureKit.capsule(face + Vector3(-0.022, -0.11, h.z * 0.45),
		face + Vector3(0.022, -0.11, h.z * 0.45), Vector2(0.007, 0.007), Vector2(0.007, 0.007), 6, 2))


static func face_center(d: LyraDesign) -> Vector3:
	var head: Vector3 = joints(d)[&"Head"]
	return head + Vector3(0, d.head_size.y * 0.56, 0.02)


## Wide midnight-blue brim, a crown that bends back, a brass band and starlights.
static func _hat(d: LyraDesign, j: Dictionary, list: Array[FigureRig.Part]) -> void:
	var brim_place := Transform3D(Basis(Vector3.RIGHT, d.brim_tilt), face_center(d) + Vector3(0, d.head_size.y * 0.43, -0.01))
	var r := d.brim_radius
	_add(list, &"Head", &"navy", FigureKit.rounded_box(Vector3(r * 2.0, 0.06, r * 2.0), 0.8, 32, 8), brim_place)
	_add(list, &"Head", &"brass", FigureKit.torus(r * 0.97, 0.022, 40, 6), brim_place)
	var crown := PackedVector3Array()
	for k in 6:
		var t := k / 5.0
		crown.append(Vector3(0.02 * t * t, d.crown_height * t, -d.crown_bend * pow(t, 2.2)))
	_add(list, &"Head", &"navy", FigureKit.point(crown, Vector2(d.crown_radius, d.crown_radius), 16, 1.0,
		Vector3.BACK, 1.3), brim_place)
	_add(list, &"Head", &"brass", FigureKit.torus(d.crown_radius * 0.93, 0.03, 24, 8),
		brim_place * Transform3D(Basis(), Vector3(0, 0.05, 0)))
	_add(list, &"Head", &"brass", FigureKit.extrude(_star_profile(0.055, 0.024), 0.03, 0.008),
		brim_place * Transform3D(Basis(), Vector3(0, 0.055, d.crown_radius * 0.93 + 0.025)))
	var stars := PackedVector3Array()
	for star: Vector2 in BRIM_STARS:
		var angle := deg_to_rad(star.x)
		stars.append(Vector3(sin(angle) * r * star.y, 0.034, cos(angle) * r * star.y))
	stars.append(crown[2] + Vector3(0.0, 0.0, d.crown_radius * 0.6))
	stars.append(crown[3] + Vector3(-d.crown_radius * 0.45, 0.0, 0.0))
	_constellation(list, &"Head", stars, brim_place, 0.032)


static func _arm(d: LyraDesign, j: Dictionary, side: float, list: Array[FigureRig.Part]) -> void:
	var s := "Left" if side > 0 else "Right"
	var upper: Vector3 = j[StringName(s + "UpperArm")]
	var lower: Vector3 = j[StringName(s + "LowerArm")]
	var hand: Vector3 = j[StringName(s + "Hand")]
	var x := Vector3(side, 0, 0)
	var r := d.limb_radius
	_add(list, StringName(s + "UpperArm"), &"navy",
		FigureKit.capsule(upper - x * 0.02, upper + x * 0.07, Vector2(0.095, 0.09), Vector2(0.085, 0.08)))
	_add(list, StringName(s + "UpperArm"), &"navy",
		FigureKit.capsule(upper + x * 0.04, lower, Vector2(r, r), Vector2(r * 0.95, r * 0.95)))
	# Bell sleeve opening toward the glove, trimmed in brass.
	var sleeve := PackedVector3Array()
	var sleeve_radii := PackedVector2Array()
	for k in 4:
		var t := k / 3.0
		sleeve.append(lower.lerp(hand - x * 0.03, t))
		sleeve_radii.append(Vector2.ONE * lerpf(r * 0.95, r * 1.75, t * t))
	_add(list, StringName(s + "LowerArm"), &"navy", FigureKit.loft(sleeve, sleeve_radii, 16))
	_add(list, StringName(s + "LowerArm"), &"brass", FigureKit.torus(r * 1.72, 0.018, 20, 6),
		Transform3D(Basis(Vector3.BACK, PI / 2), hand - x * 0.03))
	var glove := hand + x * (d.glove_size.x * 0.5 + 0.005)
	_add(list, StringName(s + "Hand"), &"parchment", FigureKit.rounded_box(d.glove_size, 0.7), glove)
	_add(list, StringName(s + "Hand"), &"star", FigureKit.extrude(_star_profile(0.035, 0.015), 0.012, 0.003),
		Transform3D(Basis(Vector3.RIGHT, -PI / 2), glove + Vector3(0, d.glove_size.y * 0.5, 0)))


static func _leg(d: LyraDesign, j: Dictionary, side: float, list: Array[FigureRig.Part]) -> void:
	var s := "Left" if side > 0 else "Right"
	var hip: Vector3 = j[StringName(s + "UpperLeg")]
	var knee: Vector3 = j[StringName(s + "LowerLeg")]
	var ankle: Vector3 = j[StringName(s + "Foot")]
	_add(list, StringName(s + "UpperLeg"), &"night",
		FigureKit.capsule(hip, knee, Vector2(0.09, 0.09), Vector2(0.07, 0.07)))
	_add(list, StringName(s + "LowerLeg"), &"night",
		FigureKit.capsule(knee, ankle + Vector3(0, 0.03, 0), Vector2(0.07, 0.07), Vector2(0.062, 0.062)))
	var boot := Vector3(ankle.x, d.boot_size.y * 0.5, d.boot_size.z * 0.17)
	_add(list, StringName(s + "Foot"), &"navy", FigureKit.rounded_box(d.boot_size, 0.5), boot)
	_add(list, StringName(s + "Foot"), &"brass",
		FigureKit.rounded_box(Vector3(d.boot_size.x * 1.04, 0.04, d.boot_size.z * 1.03), 0.4),
		Vector3(ankle.x, 0.02, boot.z))
	_add(list, StringName(s + "Foot"), &"parchment", FigureKit.torus(0.075, 0.026, 20, 8),
		Vector3(ankle.x, d.boot_size.y + 0.015, 0))


## Cape half path in rest space: top, middle (lower bone), hem.
static func _cape_path(d: LyraDesign, side: float) -> PackedVector3Array:
	var upper: Vector3 = joints(d)[&"UpperChest"]
	var top := upper + Vector3(0.11 * side, 0.12, -0.16)
	var mid := top + Vector3(0.035 * side, -d.cape_length * 0.45, -0.1)
	var hem := mid + Vector3(0.045 * side, -d.cape_length * 0.55, -0.05)
	return PackedVector3Array([top, mid, hem])


## One half of the star-map cape: navy outside, parchment lining, a constellation.
static func _cape(d: LyraDesign, side: float, list: Array[FigureRig.Part]) -> void:
	var path := _cape_path(d, side)
	var bones := [CAPE_BONES[0], CAPE_BONES[1]] if side > 0 else [CAPE_BONES[2], CAPE_BONES[3]]
	var width := d.cape_width
	var lining := Vector3(-0.004 * side, 0.0, 0.014)
	for k in 2:
		var a: Vector3 = path[k] + Vector3(0, 0.03 if k == 1 else 0.0, 0.0)
		var b: Vector3 = path[k + 1]
		var middle := a.lerp(b, 0.5) + Vector3(0.012 * side, 0, -0.012)
		var w := width * (1.0 + 0.12 * k)
		var tip := 1.12 if k == 0 else 1.22
		_add(list, bones[k], &"navy", FigureKit.cloth_flap(PackedVector3Array([a, middle, b]), w, 0.022, tip, 10))
		_add(list, bones[k], &"parchment", FigureKit.cloth_flap(PackedVector3Array([a + lining, middle + lining,
			b + lining + Vector3(0, 0.02, 0)]), w * 0.92, 0.012, tip, 8))
	# The constellation, split at the bone boundary.
	var upper_stars := PackedVector3Array()
	var lower_stars := PackedVector3Array()
	for star: Vector2 in CAPE_STARS:
		var down := star.y
		var at := path[0].lerp(path[1], down / 0.45) if down < 0.45 else path[1].lerp(path[2], (down - 0.45) / 0.55)
		var across := width * 0.5 * lerpf(1.0, 1.25, down) * star.x * side
		var point := at + Vector3(across, 0, -0.016)
		if down < 0.45:
			upper_stars.append(point)
		else:
			lower_stars.append(point)
	_constellation(list, bones[0], upper_stars, Transform3D.IDENTITY, 0.034)
	_constellation(list, bones[1], lower_stars, Transform3D.IDENTITY, 0.034)


## Floating brass astrolabe: three nested rings around a starlight core.
static func _astrolabe(d: LyraDesign, list: Array[FigureRig.Part]) -> void:
	var c := astrolabe_center(d)
	var r := d.astrolabe_radius
	_add(list, ASTROLABE_BONE, &"brass", FigureKit.torus(r, 0.014, 28, 6), Transform3D(Basis(Vector3.RIGHT, PI / 2), c))
	_add(list, ASTROLABE_BONE, &"brass", FigureKit.torus(r * 0.78, 0.012, 24, 6),
		Transform3D(Basis(Vector3.BACK, PI / 2), c))
	_add(list, ASTROLABE_BONE, &"brass", FigureKit.torus(r * 0.9, 0.01, 24, 6),
		Transform3D(Basis(Vector3.RIGHT, 0.45) * Basis(Vector3.BACK, 0.3), c))
	_add(list, ASTROLABE_BONE, &"star", FigureKit.extrude(_star_profile(0.05, 0.022), 0.03, 0.008), c)
	for k in 4:
		var angle := PI / 4 + PI / 2 * k
		var out := Vector3(cos(angle), sin(angle), 0)
		_add(list, ASTROLABE_BONE, &"brass", FigureKit.point(PackedVector3Array([c + out * r, c + out * (r + 0.035),
			c + out * (r + 0.07)]), Vector2(0.016, 0.01), 6), Transform3D.IDENTITY)


## Signature pair (GAME_DESIGN §6): the Sky Lance slung across her back and a
## folded Ki Bow at her left hip.
static func _weapons(d: LyraDesign, j: Dictionary, list: Array[FigureRig.Part]) -> void:
	var hips: Vector3 = j[&"Hips"]
	var upper: Vector3 = j[&"UpperChest"]
	var low := hips + Vector3(-0.34, -0.12, -0.34)
	var axis := (upper + Vector3(0.5, 0.32, -0.34) - low).normalized()
	var high := low + axis * d.lance_length
	_add(list, &"UpperChest", &"night", FigureKit.capsule(low, high, Vector2(0.022, 0.022), Vector2(0.022, 0.022), 8, 2))
	_add(list, &"UpperChest", &"parchment", FigureKit.capsule(low + axis * 0.38, low + axis * 0.58,
		Vector2(0.03, 0.03), Vector2(0.03, 0.03), 8, 2))
	_add(list, &"UpperChest", &"brass", FigureKit.rounded_box(Vector3(0.06, 0.08, 0.06), 0.7, 10, 6),
		Transform3D(Basis(Quaternion(Vector3.UP, axis)), low))
	var ring := high + axis * 0.06
	_add(list, &"UpperChest", &"brass", FigureKit.torus(0.075, 0.016, 20, 6),
		Transform3D(Basis(Quaternion(Vector3.UP, axis)) * Basis(Vector3.RIGHT, PI / 2), ring))
	_add(list, &"UpperChest", &"star", FigureKit.rounded_box(Vector3.ONE * 0.05, 1.0, 8, 6), ring)
	_add(list, &"UpperChest", &"brass", FigureKit.point(PackedVector3Array([ring + axis * 0.07, ring + axis * 0.16,
		ring + axis * 0.27]), Vector2(0.045, 0.016), 8, 1.0, Vector3.BACK, 0.8))
	# Ki Bow: a slim brass arc with a starlight string.
	var bow_center := hips + Vector3(0.27, -0.08, -0.02)
	var arc := PackedVector3Array()
	var arc_radii := PackedVector2Array()
	for k in 9:
		var angle := lerpf(-1.0, 1.0, k / 8.0)
		arc.append(bow_center + Vector3(0, sin(angle) * 0.26, -cos(angle) * 0.1))
		arc_radii.append(Vector2.ONE * lerpf(0.022, 0.012, absf(angle)))
	_add(list, &"Hips", &"brass", FigureKit.loft(arc, arc_radii, 8))
	_add(list, &"Hips", &"star", FigureKit.capsule(arc[0], arc[-1], Vector2(0.006, 0.006), Vector2(0.006, 0.006), 6, 2))


## Glowing stars at points (in place's space) joined by thin starlight lines.
static func _constellation(list: Array[FigureRig.Part], bone: StringName, points: PackedVector3Array,
		place: Transform3D, size: float) -> void:
	for i in points.size():
		_add(list, bone, &"star", FigureKit.rounded_box(Vector3.ONE * size, 1.0, 8, 6), place * Transform3D(Basis(), points[i]))
		if i > 0:
			_add(list, bone, &"star", FigureKit.capsule(points[i - 1], points[i], Vector2(0.006, 0.006),
				Vector2(0.006, 0.006), 6, 1), place)


## A five-pointed star outline (XY).
static func _star_profile(outer: float, inner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 10:
		var angle := PI / 2 + PI * k / 5.0
		var radius := outer if k % 2 == 0 else inner
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


## Tall rounded eye.
static func _eye_profile() -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 16:
		var angle := TAU * k / 16.0
		points.append(Vector2(cos(angle) * 0.03, sin(angle) * 0.045))
	return points


## Bangs: a fringe with three soft points along its lower edge.
static func _bangs_profile(width: float) -> PackedVector2Array:
	var half := width * 0.5
	var points := PackedVector2Array([Vector2(half, 0.06), Vector2(-half, 0.06), Vector2(-half, -0.04)])
	var tips := 6
	for k in range(1, tips):
		var x := -half + width * k / tips
		var y := -0.05 if k % 2 == 1 else -0.025
		points.append(Vector2(x, y))
	points.append(Vector2(half, -0.04))
	return points


static func _add(list: Array[FigureRig.Part], bone: StringName, material: StringName,
		shape: FigureShape, place: Variant = Transform3D.IDENTITY) -> void:
	var xform: Transform3D = place if place is Transform3D else Transform3D(Basis(), place)
	list.append(FigureRig.Part.new(bone, material, shape.transformed(xform)))
