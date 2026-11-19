class_name WeaponGrip
extends RefCounted
## How each weapon is held (T-D30): its hold class, its grip sockets (main hand at
## the model origin, plus an off-hand point for two-handed weapons) and its size
## relative to the holder's hand. Hand sockets come from the rig: a palm frame on
## each hand bone, so every legend's proportions fit the same grip.

enum Hold { NONE, FIST, ONE_HAND, HEAVY, PISTOL, BRACED, BOW }

const RIGHT_HAND := &"RightHand"
const LEFT_HAND := &"LeftHand"
## Hand length (hand bone to middle knuckle, m) the weapon scales were tuned on (Kael).
const REFERENCE_HAND := 0.11
## Model scale at the reference hand.
const SCALE := {
	Weapon.Kind.KI_GAUNTLETS: 0.62,
	Weapon.Kind.STORM_BLADE: 0.72,
	Weapon.Kind.SKY_LANCE: 0.72,
	Weapon.Kind.TITAN_HAMMER: 0.8,
	Weapon.Kind.ORBIT_CHAKRAM: 0.85,
	Weapon.Kind.EMBER_SCYTHE: 0.75,
	Weapon.Kind.KI_BOW: 0.7,
	Weapon.Kind.ARC_REVOLVER: 0.85,
	Weapon.Kind.STORM_REPEATER: 0.8,
	Weapon.Kind.SCATTER_CANNON: 0.85,
	Weapon.Kind.HEARTSTRING_BOW: 0.7,
}
## Off-hand grip in model space (before scale), for two-handed holds.
const OFF_HAND := {
	Weapon.Kind.SKY_LANCE: Vector3(0, 0.62, 0),
	Weapon.Kind.TITAN_HAMMER: Vector3(0, 0.5, 0),
	Weapon.Kind.EMBER_SCYTHE: Vector3(0, 0.7, 0),
	Weapon.Kind.STORM_REPEATER: Vector3(0, 0.08, -0.46),
	Weapon.Kind.SCATTER_CANNON: Vector3(0, 0.1, -0.42),
}
## Bow string ends and rest point in bow model space.
const BOW_TIP := Vector3(0, 0.69, 0.26)
const BOW_STRING_REST := Vector3(0, 0, 0.26)


static func hold_of(kind: Weapon.Kind) -> Hold:
	match kind:
		Weapon.Kind.NONE:
			return Hold.NONE
		Weapon.Kind.KI_GAUNTLETS:
			return Hold.FIST
		Weapon.Kind.SKY_LANCE, Weapon.Kind.TITAN_HAMMER, Weapon.Kind.EMBER_SCYTHE:
			return Hold.HEAVY
		Weapon.Kind.ARC_REVOLVER:
			return Hold.PISTOL
		Weapon.Kind.STORM_REPEATER, Weapon.Kind.SCATTER_CANNON:
			return Hold.BRACED
		Weapon.Kind.KI_BOW, Weapon.Kind.HEARTSTRING_BOW:
			return Hold.BOW
	return Hold.ONE_HAND


## Hand bone(s) the model goes on: bows in the left hand, gauntlets on both, the rest in the right.
static func hands_of(kind: Weapon.Kind) -> Array[StringName]:
	match hold_of(kind):
		Hold.NONE:
			return []
		Hold.FIST:
			return [RIGHT_HAND, LEFT_HAND]
		Hold.BOW:
			return [LEFT_HAND]
	return [RIGHT_HAND]


static func off_hand_of(kind: Weapon.Kind) -> Vector3:
	return OFF_HAND.get(kind, Vector3.INF)


## Hand length (m) of a hand bone: wrist to middle knuckle.
static func hand_size(skeleton: Skeleton3D, hand: StringName) -> float:
	var h := skeleton.find_bone(hand)
	var knuckle := skeleton.find_bone(String(hand).replace("Hand", "MiddleProximal"))
	if h < 0 or knuckle < 0:
		return REFERENCE_HAND
	return maxf(skeleton.get_bone_global_rest(h).origin.distance_to(skeleton.get_bone_global_rest(knuckle).origin), 0.04)


## The palm socket of a hand bone, in that bone's space: origin in the closed fist, +Y toward
## the thumb (where a blade leaves the fist), -Z along the knuckles (where a barrel points).
static func hand_socket(skeleton: Skeleton3D, hand: StringName) -> Transform3D:
	var key := "hand_socket_%s" % hand
	if skeleton.has_meta(key):
		return skeleton.get_meta(key)
	var socket := Transform3D.IDENTITY
	var h := skeleton.find_bone(hand)
	var side := "Right" if hand == RIGHT_HAND else "Left"
	var knuckle := skeleton.find_bone(side + "MiddleProximal")
	var index := skeleton.find_bone(side + "IndexProximal")
	var little := skeleton.find_bone(side + "LittleProximal")
	if h >= 0 and knuckle >= 0 and index >= 0:
		var rest := skeleton.get_bone_global_rest(h)
		var wrist := rest.origin
		var k := skeleton.get_bone_global_rest(knuckle).origin
		var outer := skeleton.get_bone_global_rest(little).origin if little >= 0 else k
		var fingers := (k - wrist).normalized()
		var thumbward := skeleton.get_bone_global_rest(index).origin - outer
		thumbward = (thumbward - fingers * thumbward.dot(fingers)).normalized()
		var palm := thumbward.cross(fingers) * (1.0 if hand == RIGHT_HAND else -1.0)
		var size := wrist.distance_to(k)
		var y := thumbward
		var z := -fingers
		var basis := Basis(y.cross(z), y, z)
		var origin := wrist + fingers * size * 0.75 + palm * size * 0.35
		socket = rest.affine_inverse() * Transform3D(basis, origin)
	skeleton.set_meta(key, socket)
	return socket


## The weapon model's transform in the hand bone's space: socket, then scale for this hand.
static func grip_transform(skeleton: Skeleton3D, kind: Weapon.Kind, hand: StringName) -> Transform3D:
	var socket := hand_socket(skeleton, hand)
	var size := float(SCALE.get(kind, 1.0)) * hand_size(skeleton, hand) / REFERENCE_HAND
	if hold_of(kind) == Hold.FIST:
		# The gauntlet's cuff runs up the forearm: its +Y follows the knuckles.
		var fist := Basis(Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0))
		return Transform3D(socket.basis * fist * Basis.from_scale(Vector3.ONE * size),
			socket.origin + socket.basis.z * 0.02)
	return Transform3D(socket.basis * Basis.from_scale(Vector3.ONE * size), socket.origin)


## Every visible mesh part of a model as an oriented box (a transform of the unit cube
## [-1, 1]^3) in the model's own space. Parts named "String" (bow strings) are left out.
static func part_boxes(model: Node3D) -> Array[Transform3D]:
	var boxes: Array[Transform3D] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		# The string and the nocked arrow ride on the string hand; the bow-vs-head check covers them.
		if part.name.begins_with("String") or part.get_parent().name in ["BowString", "NockedArrow"] \
				or not part.is_visible_in_tree():
			continue
		var to_model := Transform3D.IDENTITY
		var at: Node = part
		while at != model and at != null:
			to_model = (at as Node3D).transform * to_model
			at = at.get_parent()
		var box := part.get_aabb()
		boxes.append(to_model * Transform3D(Basis.from_scale(box.size * 0.5), box.get_center()))
	return boxes


static var _box_cache := {}


## Part boxes of a freshly built model of kind (cached per kind).
static func model_boxes(kind: Weapon.Kind) -> Array[Transform3D]:
	if not _box_cache.has(kind):
		var model := WeaponModels.build(kind)
		model.transform = Transform3D.IDENTITY
		_box_cache[kind] = part_boxes(model)
		model.free()
	return _box_cache[kind]
