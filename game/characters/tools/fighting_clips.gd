class_name FightingClips
extends RefCounted
## Skybreak's original fighting clips as keyframe data, baked by
## tools/author_clips.gd into the shared humanoid clip library.
##
## A pose maps a SkeletonProfileHumanoid bone to an Euler rotation in degrees,
## relative to the profile's rest pose (T-pose) and expressed in body axes:
## +X is the character's left, +Y up, +Z forward. Applied as Y * X * Z, so:
## - spine, neck, head, hips: x+ bends forward, y+ turns left, z+ leans right
## - left arm (rest points +X): z- lowers it, then x- swings it forward
## - right arm: z+ lowers it, then x- swings it forward
## - elbows: left flexes with y-, right with y+
## - legs (rest point down): x- raises the leg forward, x+ swings it back;
##   z+ moves the left leg out, z- the right leg; knees flex with x+
## - feet: x+ points the toes down, x- pulls them up
## A Vector4 adds a twist (w) about the bone's rest direction, applied first.
## Missing bones stay at rest.
##
## Pose extras: "drop" lowers the hips (metres, negative raises them);
## "plant" lists the feet ("L", "R") whose knee is solved so the sole touches
## the floor in grounded clips. Keys ease into their pose with "ease".

## Soles, in the reference skeleton's rest (metres): heel under the ankle,
## the ball under the toe joint, the tip under the toe end.
const SOLE_HEEL_BACK := 0.05
const SOLE_TIP_FORWARD := 0.03

const BODY_BONES: Array[StringName] = [&"Hips", &"Spine", &"Chest", &"UpperChest", &"Neck",
	&"Head", &"LeftShoulder", &"LeftUpperArm", &"LeftLowerArm", &"LeftHand", &"RightShoulder",
	&"RightUpperArm", &"RightLowerArm", &"RightHand", &"LeftUpperLeg", &"LeftLowerLeg",
	&"LeftFoot", &"LeftToes", &"RightUpperLeg", &"RightLowerLeg", &"RightFoot", &"RightToes"]
const FINGERS := ["Index", "Middle", "Ring", "Little"]
const PHALANGES := ["Proximal", "Intermediate", "Distal"]
const THUMB := ["ThumbMetacarpal", "ThumbProximal", "ThumbDistal"]


static var _rest_cache := {}


## Profile rest of a bone: [local basis, global basis (body axes to bone axes)].
static func profile_rest(bone: StringName) -> Array[Basis]:
	if not _rest_cache.has(bone):
		var profile := SkeletonProfileHumanoid.new()
		var index := profile.find_bone(bone)
		var local := profile.get_reference_pose(index).basis
		var global := local
		var parent := profile.find_bone(profile.get_bone_parent(index))
		while parent >= 0:
			global = profile.get_reference_pose(parent).basis * global
			parent = profile.find_bone(profile.get_bone_parent(parent))
		_rest_cache[bone] = [local, global] as Array[Basis]
	return _rest_cache[bone]


## Local pose rotation for a body-axes rotation relative to the rest pose.
static func to_local(bone: StringName, body_rotation: Basis) -> Quaternion:
	var rest := profile_rest(bone)
	return (rest[0] * (rest[1].inverse() * body_rotation * rest[1])).get_rotation_quaternion()


## Body-axes rotation relative to the rest pose for a local pose rotation.
static func to_body(bone: StringName, local_rotation: Quaternion) -> Basis:
	var rest := profile_rest(bone)
	return rest[1] * rest[0].inverse() * Basis(local_rotation) * rest[1].inverse()


## A foot's sole points ("Left" or "Right"): [[bone, point in its frame], ...]
## for the heel, the ball and the toe tip, from the skeleton's rest.
static func sole_points(skeleton: Skeleton3D, side: String) -> Array:
	var ankle := skeleton.get_bone_global_rest(skeleton.find_bone(side + "Foot"))
	var toes_index := skeleton.find_bone(side + "Toes")
	var toes := skeleton.get_bone_global_rest(toes_index)
	var tip := skeleton.get_bone_global_rest(skeleton.get_bone_children(toes_index)[0])
	var heel := Vector3(ankle.origin.x, 0.0, ankle.origin.z - SOLE_HEEL_BACK)
	var ball := Vector3(toes.origin.x, 0.0, toes.origin.z)
	var toe_tip := Vector3(tip.origin.x, 0.0, tip.origin.z + SOLE_TIP_FORWARD)
	return [[side + "Foot", ankle.affine_inverse() * heel],
		[side + "Toes", toes.affine_inverse() * ball], [side + "Toes", toes.affine_inverse() * toe_tip]]


## Every bone a clip animates: the body plus both hands' fingers.
static func animated_bones() -> Array[StringName]:
	var bones: Array[StringName] = BODY_BONES.duplicate()
	for side in ["Left", "Right"]:
		for finger in FINGERS:
			for phalanx in PHALANGES:
				bones.append(StringName(side + finger + phalanx))
		for thumb in THUMB:
			bones.append(StringName(side + thumb))
	return bones


## Clip name -> definition:
## frames (length at 60 fps), loop, grounded (the hips follow the planted feet
## and no sole goes below the floor), keys [{f, pose, ease}],
## impact (Vector2i first and last frame of the held impact pose) for strikes,
## and shake {bone: degrees} with shake_hz (whole cycles per loop second) for
## a trembling loop.
static func definitions() -> Dictionary:
	return {
		&"fight_stance": _fight_stance(),
		&"power_up_start": _power_up_start(),
		&"power_up": _power_up(),
		&"fly_hover": _fly_hover(),
		&"fly_forward": _fly_forward(),
		&"air_dash": _air_dash(),
		&"front_kick": _front_kick(),
		&"roundhouse_kick": _roundhouse_kick(),
		&"uppercut": _uppercut(),
		&"flip_kick": _flip_kick(),
		&"axe_kick": _axe_kick(),
		&"low_sweep_kick": _low_sweep_kick(),
		&"knee_strike": _knee_strike(),
	}


## Clips that stand on the floor: soles never below it.
static func grounded_clips() -> Array[StringName]:
	var names: Array[StringName] = []
	var all := definitions()
	for clip: StringName in all:
		if all[clip].get("grounded", false):
			names.append(clip)
	return names


# Building blocks.

## Left fist; mirrored for the right.
static func _fist_left() -> Dictionary:
	return {
		"LeftIndexProximal": Vector3(0, 0, -85), "LeftIndexIntermediate": Vector3(0, 0, -100),
		"LeftIndexDistal": Vector3(0, 0, -55),
		"LeftMiddleProximal": Vector3(0, 0, -88), "LeftMiddleIntermediate": Vector3(0, 0, -100),
		"LeftMiddleDistal": Vector3(0, 0, -55),
		"LeftRingProximal": Vector3(0, 0, -90), "LeftRingIntermediate": Vector3(0, 0, -100),
		"LeftRingDistal": Vector3(0, 0, -55),
		"LeftLittleProximal": Vector3(0, 0, -92), "LeftLittleIntermediate": Vector3(0, 0, -100),
		"LeftLittleDistal": Vector3(0, 0, -55),
		"LeftThumbMetacarpal": Vector3(10, 20, -25), "LeftThumbProximal": Vector3(0, 15, -35),
		"LeftThumbDistal": Vector3(0, 0, -35),
	}


## Loosely curled hand, for floating.
static func _open_left() -> Dictionary:
	var hand := {}
	for finger in FINGERS:
		hand["Left%sProximal" % finger] = Vector3(0, 0, -20)
		hand["Left%sIntermediate" % finger] = Vector3(0, 0, -25)
		hand["Left%sDistal" % finger] = Vector3(0, 0, -15)
	hand["LeftThumbProximal"] = Vector3(0, 0, -10)
	return hand


static func _fists() -> Dictionary:
	return _both(_fist_left())


static func _both(left: Dictionary) -> Dictionary:
	return _merge([left, _mirror(left)])


## Swaps left and right and mirrors each rotation across the body's midplane.
static func _mirror(pose: Dictionary) -> Dictionary:
	var mirrored := {}
	for key: String in pose:
		var value: Variant = pose[key]
		var bone := key
		if key.begins_with("Left"):
			bone = "Right" + key.trim_prefix("Left")
		elif key.begins_with("Right"):
			bone = "Left" + key.trim_prefix("Right")
		if value is Vector3:
			value = Vector3(value.x, -value.y, -value.z)
		elif value is Vector4:
			value = Vector4(value.x, -value.y, -value.z, -value.w)
		elif key == "plant":
			value = (value as Array).map(func(foot: String) -> String: return "R" if foot == "L" else "L")
		mirrored[bone] = value
	return mirrored


static func _merge(parts: Array) -> Dictionary:
	var pose := {}
	for part: Dictionary in parts:
		pose.merge(part, true)
	return pose


static func _key(frame: int, pose: Dictionary, ease := "in_out") -> Dictionary:
	return {"f": frame, "pose": pose, "ease": ease}


# Poses.

## Bladed orthodox stance: left foot and fist lead, rear fist at the cheek.
static func _stance() -> Dictionary:
	return _merge([_fists(), {
		"drop": 0.13, "plant": ["L", "R"],
		"Hips": Vector3(6, -34, 0),
		"Spine": Vector3(5, 10, 0), "Chest": Vector3(5, 8, 0), "UpperChest": Vector3(4, 8, 0),
		"Neck": Vector3(-6, 4, 0), "Head": Vector3(-8, 6, 0),
		"LeftShoulder": Vector3(0, -6, 4), "RightShoulder": Vector3(0, 4, -4),
		"LeftUpperArm": Vector3(-62, 8, -64), "LeftLowerArm": Vector3(0, -96, 0),
		"LeftHand": Vector3(0, 0, -6),
		"RightUpperArm": Vector3(-34, 0, 70), "RightLowerArm": Vector3(0, 132, 0),
		"RightHand": Vector3(0, 0, 8),
		"LeftUpperLeg": Vector3(-26, 14, 8), "LeftLowerLeg": Vector3(36, 0, 0),
		"LeftFoot": Vector3(-16, 0, 0),
		"RightUpperLeg": Vector3(18, -8, -10), "RightLowerLeg": Vector3(30, 0, 0),
		"RightFoot": Vector3(-28, 0, 0), "RightToes": Vector3(-18, 0, 0),
	}])


static func _fight_stance() -> Dictionary:
	var stance := _stance()
	var inhale := _merge([stance, {
		"drop": 0.145,
		"UpperChest": Vector3(2, 8, 0), "Neck": Vector3(-5, 4, 0),
		"LeftShoulder": Vector3(0, -6, 7), "RightShoulder": Vector3(0, 4, -7),
		"LeftUpperArm": Vector3(-64, 8, -62), "RightUpperArm": Vector3(-36, 0, 68),
	}])
	return {
		"frames": 90, "loop": true, "grounded": true,
		"keys": [_key(0, stance), _key(45, inhale), _key(90, stance)],
	}


## Wide low crouch, fists clenched at the hips, elbows flared, chest out.
static func _power_crouch() -> Dictionary:
	return _merge([_fists(), {
		"drop": 0.27, "plant": ["L", "R"],
		"Hips": Vector3(10, 0, 0),
		"Spine": Vector3(-4, 0, 0), "Chest": Vector3(-6, 0, 0), "UpperChest": Vector3(-10, 0, 0),
		"Neck": Vector3(-4, 0, 0), "Head": Vector3(-14, 0, 0),
		"LeftShoulder": Vector3(0, 8, 10), "RightShoulder": Vector3(0, -8, -10),
		"LeftUpperArm": Vector3(38, 0, -66), "LeftLowerArm": Vector3(0, -100, 0),
		"LeftHand": Vector3(0, 0, -10),
		"RightUpperArm": Vector3(38, 0, 66), "RightLowerArm": Vector3(0, 100, 0),
		"RightHand": Vector3(0, 0, 10),
		"LeftUpperLeg": Vector3(-48, 22, 24), "LeftLowerLeg": Vector3(78, 0, 0),
		"LeftFoot": Vector3(-40, -10, -6),
		"RightUpperLeg": Vector3(-48, -22, -24), "RightLowerLeg": Vector3(78, 0, 0),
		"RightFoot": Vector3(-40, 10, 6),
	}])


static func _power_up_start() -> Dictionary:
	var gather := _merge([_power_crouch(), {
		"drop": 0.2,
		"Spine": Vector3(10, 0, 0), "Chest": Vector3(10, 0, 0), "UpperChest": Vector3(8, 0, 0),
		"Head": Vector3(16, 0, 0),
		"LeftUpperArm": Vector3(14, 0, -72), "RightUpperArm": Vector3(14, 0, 72),
		"LeftLowerArm": Vector3(0, -120, 0), "RightLowerArm": Vector3(0, 120, 0),
	}])
	var burst := _merge([_power_crouch(), {
		"drop": 0.29,
		"UpperChest": Vector3(-14, 0, 0), "Head": Vector3(-12, 0, 0),
	}])
	return {
		"frames": 20, "loop": false, "grounded": true,
		"keys": [_key(0, _stance()), _key(9, gather, "out"), _key(15, burst, "snap"),
			_key(20, _power_crouch(), "in_out")],
	}


static func _power_up() -> Dictionary:
	var crouch := _power_crouch()
	var swell := _merge([crouch, {
		"drop": 0.29,
		"UpperChest": Vector3(-13, 0, 0), "Head": Vector3(-9, 0, 0),
		"LeftShoulder": Vector3(0, 8, 13), "RightShoulder": Vector3(0, -8, -13),
	}])
	return {
		"frames": 60, "loop": true, "grounded": true,
		"keys": [_key(0, crouch), _key(30, swell), _key(60, crouch)],
		"shake": {"Spine": 0.8, "Chest": 1.0, "UpperChest": 1.2, "Head": 1.0,
			"LeftUpperArm": 1.5, "RightUpperArm": 1.5, "LeftLowerArm": 1.2, "RightLowerArm": 1.2},
		"shake_hz": [11, 17],
	}


## Upright float, legs slightly tucked, hands loose at a half guard.
static func _fly_hover() -> Dictionary:
	var float_pose := _merge([_both(_open_left()), {
		"Hips": Vector3(4, -10, 0),
		"Spine": Vector3(3, 4, 0), "Chest": Vector3(2, 3, 0), "UpperChest": Vector3(2, 3, 0),
		"Head": Vector3(-6, 0, 0),
		"LeftUpperArm": Vector3(-22, 0, -62), "LeftLowerArm": Vector3(0, -55, 0),
		"LeftHand": Vector3(0, 0, -10),
		"RightUpperArm": Vector3(-14, 0, 66), "RightLowerArm": Vector3(0, 48, 0),
		"RightHand": Vector3(0, 0, 10),
		"LeftUpperLeg": Vector3(-30, 4, 4), "LeftLowerLeg": Vector3(58, 0, 0),
		"LeftFoot": Vector3(34, 0, 0),
		"RightUpperLeg": Vector3(-22, -4, -4), "RightLowerLeg": Vector3(66, 0, 0),
		"RightFoot": Vector3(36, 0, 0),
	}])
	var high := _merge([float_pose, {
		"drop": -0.035,
		"LeftUpperArm": Vector3(-24, 0, -58), "RightUpperArm": Vector3(-16, 0, 62),
		"LeftLowerLeg": Vector3(62, 0, 0), "RightLowerLeg": Vector3(70, 0, 0),
	}])
	return {
		"frames": 120, "loop": true,
		"keys": [_key(0, float_pose), _key(60, high), _key(120, float_pose)],
	}


## Superhero flight: body pitched toward travel, right fist forward, legs
## trailing together. FighterView adds up to 18 degrees of lean on top.
static func _fly_forward() -> Dictionary:
	var glide := _merge([_fists(), {
		"Hips": Vector3(60, 0, 0),
		"Spine": Vector3(4, 0, 0), "Chest": Vector3(2, 0, 0), "UpperChest": Vector3(-4, 0, 0),
		"Neck": Vector3(-24, 0, 0), "Head": Vector3(-30, 0, 0),
		"RightShoulder": Vector3(0, 0, -10),
		"RightUpperArm": Vector3(-12, 0, -78), "RightLowerArm": Vector3(0, 8, 0),
		"LeftUpperArm": Vector3(14, 0, -72), "LeftLowerArm": Vector3(0, -30, 0),
		"LeftHand": Vector3(0, 0, -10),
		"LeftUpperLeg": Vector3(6, 0, 2), "LeftLowerLeg": Vector3(8, 0, 0),
		"LeftFoot": Vector3(40, 0, 0),
		"RightUpperLeg": Vector3(2, 0, -2), "RightLowerLeg": Vector3(26, 0, 0),
		"RightFoot": Vector3(44, 0, 0),
	}])
	var flutter := _merge([glide, {
		"drop": 0.02,
		"LeftLowerLeg": Vector3(12, 0, 0), "RightLowerLeg": Vector3(22, 0, 0),
		"Head": Vector3(-28, 0, 0),
	}])
	return {
		"frames": 60, "loop": true,
		"keys": [_key(0, glide), _key(30, flutter), _key(60, glide)],
	}


## Burst: shoulders hunched, arms swept back, legs tucked.
static func _air_dash() -> Dictionary:
	var burst := _merge([_fists(), {
		"Hips": Vector3(26, 0, 0),
		"Spine": Vector3(8, 0, 0), "Chest": Vector3(8, 0, 0), "UpperChest": Vector3(6, 0, 0),
		"Neck": Vector3(-14, 0, 0), "Head": Vector3(-16, 0, 0),
		"LeftShoulder": Vector3(0, 10, 16), "RightShoulder": Vector3(0, -10, -16),
		"LeftUpperArm": Vector3(42, 0, -64), "LeftLowerArm": Vector3(0, -20, 0),
		"RightUpperArm": Vector3(42, 0, 64), "RightLowerArm": Vector3(0, 20, 0),
		"LeftUpperLeg": Vector3(-40, 0, 4), "LeftLowerLeg": Vector3(80, 0, 0),
		"LeftFoot": Vector3(30, 0, 0),
		"RightUpperLeg": Vector3(-12, 0, -4), "RightLowerLeg": Vector3(70, 0, 0),
		"RightFoot": Vector3(30, 0, 0),
	}])
	var push := _merge([burst, {
		"Hips": Vector3(30, 0, 0),
		"LeftUpperArm": Vector3(48, 0, -66), "RightUpperArm": Vector3(48, 0, 66),
	}])
	var set_pose := _merge([burst, {"Hips": Vector3(22, 0, 0),
		"LeftUpperArm": Vector3(34, 0, -62), "RightUpperArm": Vector3(34, 0, 62)}])
	return {
		"frames": 30, "loop": false,
		"keys": [_key(0, _fly_hover()["keys"][0]["pose"]), _key(4, push, "snap"), _key(10, burst, "out"),
			_key(30, set_pose, "in_out")],
	}


# Strikes. Frames match the move's ticks one to one: STARTUP frames of
# anticipation, the ACTIVE frames held at full extension, RECOVERY back to
# the stance.

## Rear-leg front snap kick (no move mapped yet).
static func _front_kick() -> Dictionary:
	var load_pose := _merge([_stance(), {
		"drop": 0.11,
		"Hips": Vector3(4, -24, 0),
		"RightUpperLeg": Vector3(10, -8, -8), "RightLowerLeg": Vector3(44, 0, 0),
	}])
	var chamber := _merge([_stance(), {
		"drop": 0.06, "plant": ["L"],
		"Hips": Vector3(-6, -10, 0), "Spine": Vector3(0, 4, 0),
		"LeftUpperLeg": Vector3(-6, 8, 4), "LeftLowerLeg": Vector3(22, 0, 0),
		"RightUpperLeg": Vector3(-95, 0, -4), "RightLowerLeg": Vector3(118, 0, 0),
		"RightFoot": Vector3(30, 0, 0), "RightToes": Vector3(-30, 0, 0),
	}])
	var extend := _merge([chamber, {
		"Hips": Vector3(-14, -6, 0), "Spine": Vector3(-4, 4, 0),
		"RightUpperLeg": Vector3(-86, 0, -4), "RightLowerLeg": Vector3(4, 0, 0),
		"RightFoot": Vector3(24, 0, 0), "RightToes": Vector3(-40, 0, 0),
	}])
	var hold := _merge([extend, {"RightUpperLeg": Vector3(-90, 0, -4), "RightLowerLeg": Vector3(2, 0, 0)}])
	return {
		"frames": 33, "loop": false, "grounded": true, "impact": Vector2i(12, 15),
		"keys": [_key(0, _stance()), _key(5, load_pose, "out"), _key(9, chamber, "in"),
			_key(12, extend, "snap"), _key(15, hold, "linear"), _key(21, chamber, "out"),
			_key(33, _stance(), "in_out")],
	}


## Rear-leg roundhouse: pivot on the lead foot, hip turned over, shin
## snapping across at head height; the light string finisher.
static func _roundhouse_kick() -> Dictionary:
	var coil := _merge([_stance(), {
		"drop": 0.12,
		"Hips": Vector3(8, -46, 0), "Spine": Vector3(6, 14, 0),
		"RightUpperArm": Vector3(-20, 0, 74),
	}])
	var chamber := _merge([_fists(), {
		"drop": 0.04, "plant": ["L"],
		"Hips": Vector3(0, 30, -14),
		"Spine": Vector3(0, -12, -6), "Chest": Vector3(0, -10, -6), "UpperChest": Vector3(0, -8, -4),
		"Neck": Vector3(0, -8, 4), "Head": Vector3(-4, -12, 6),
		"LeftUpperArm": Vector3(-56, 10, -62), "LeftLowerArm": Vector3(0, -115, 0),
		"RightUpperArm": Vector3(20, 0, 62), "RightLowerArm": Vector3(0, 70, 0),
		"LeftUpperLeg": Vector3(-4, 8, -10), "LeftLowerLeg": Vector3(24, 0, 0),
		"LeftFoot": Vector3(-12, 0, 0),
		"RightUpperLeg": Vector4(-40, 40, -68, 0), "RightLowerLeg": Vector3(120, 0, 0),
		"RightFoot": Vector3(40, 0, 0),
	}])
	var strike := _merge([chamber, {
		"drop": 0.02,
		"Hips": Vector3(-4, 70, -30),
		"Spine": Vector3(-4, -18, -10), "Chest": Vector3(-2, -14, -8), "UpperChest": Vector3(0, -12, -6),
		"Neck": Vector3(0, -12, 6), "Head": Vector3(-4, -18, 8),
		"LeftUpperArm": Vector3(-64, 12, -60), "LeftLowerArm": Vector3(0, -118, 0),
		"RightUpperArm": Vector3(40, 0, 50), "RightLowerArm": Vector3(0, 40, 0),
		"LeftUpperLeg": Vector3(-2, 6, -16),
		"RightUpperLeg": Vector4(-6, 6, -78, 0), "RightLowerLeg": Vector3(4, 0, 0),
		"RightFoot": Vector3(46, 0, 0),
	}])
	var follow := _merge([strike, {
		"Hips": Vector3(-4, 80, -30),
		"RightUpperLeg": Vector4(-4, 16, -78, 0), "RightLowerLeg": Vector3(6, 0, 0),
	}])
	var rechamber := _merge([chamber, {"Hips": Vector3(0, 40, -10),
		"RightUpperLeg": Vector4(-30, 40, -58, 0), "RightLowerLeg": Vector3(110, 0, 0)}])
	return {
		"frames": 31, "loop": false, "grounded": true, "impact": Vector2i(10, 13),
		"keys": [_key(0, _stance()), _key(4, coil, "out"), _key(8, chamber, "in"),
			_key(10, strike, "snap"), _key(13, follow, "linear"), _key(19, rechamber, "out"),
			_key(31, _stance(), "in_out")],
	}


## Rising right uppercut out of a deep dip; the launcher.
static func _uppercut() -> Dictionary:
	var dip := _merge([_stance(), {
		"drop": 0.24,
		"Hips": Vector3(14, -48, 0), "Spine": Vector3(10, 6, -6), "Chest": Vector3(8, 4, -6),
		"UpperChest": Vector3(6, 4, -4), "Head": Vector3(-14, 10, 4),
		"LeftUpperLeg": Vector3(-46, 14, 10), "LeftLowerLeg": Vector3(70, 0, 0),
		"RightUpperLeg": Vector3(2, -8, -12), "RightLowerLeg": Vector3(62, 0, 0),
		"RightUpperArm": Vector3(28, 0, 72), "RightLowerArm": Vector3(0, 95, 0),
		"RightHand": Vector3(0, 0, 0),
	}])
	var strike := _merge([_stance(), {
		"drop": -0.02,
		"Hips": Vector3(-6, 12, 0), "Spine": Vector3(-6, 6, 4), "Chest": Vector3(-6, 4, 4),
		"UpperChest": Vector3(-4, 4, 2), "Neck": Vector3(-6, 0, 0), "Head": Vector3(-10, -2, 0),
		"LeftUpperArm": Vector3(-30, 0, -72), "LeftLowerArm": Vector3(0, -130, 0),
		"RightShoulder": Vector3(0, 0, -14),
		"RightUpperArm": Vector3(-122, 0, 84), "RightLowerArm": Vector3(0, 78, 0),
		"LeftUpperLeg": Vector3(-14, 14, 8), "LeftLowerLeg": Vector3(8, 0, 0),
		"LeftFoot": Vector3(16, 0, 0),
		"RightUpperLeg": Vector3(14, -8, -10), "RightLowerLeg": Vector3(4, 0, 0),
		"RightFoot": Vector3(10, 0, 0), "RightToes": Vector3(-30, 0, 0),
	}])
	var hold := _merge([strike, {
		"drop": -0.04,
		"Hips": Vector3(-8, 16, 0), "RightUpperArm": Vector3(-128, 0, 84),
	}])
	var settle := _merge([_stance(), {"drop": 0.12, "Hips": Vector3(8, -20, 0),
		"RightUpperArm": Vector3(-60, 0, 80), "RightLowerArm": Vector3(0, 110, 0)}])
	return {
		"frames": 40, "loop": false, "grounded": true, "impact": Vector2i(13, 16),
		"keys": [_key(0, _stance()), _key(8, dip, "out"), _key(11, dip, "linear"),
			_key(13, strike, "snap"), _key(16, hold, "linear"), _key(26, settle, "out"),
			_key(40, _stance(), "in_out")],
	}


## Anti-air backflip kick: crouch, spring back, the right foot sweeping up
## through the space above and in front; lands back in the stance.
static func _flip_kick() -> Dictionary:
	var crouch := _merge([_stance(), {
		"drop": 0.26,
		"Hips": Vector3(22, -20, 0), "Spine": Vector3(10, 6, 0), "Chest": Vector3(8, 4, 0),
		"Head": Vector3(-20, 4, 0),
		"LeftUpperArm": Vector3(30, 0, -74), "LeftLowerArm": Vector3(0, -30, 0),
		"RightUpperArm": Vector3(30, 0, 74), "RightLowerArm": Vector3(0, 30, 0),
		"LeftUpperLeg": Vector3(-60, 10, 10), "LeftLowerLeg": Vector3(90, 0, 0),
		"RightUpperLeg": Vector3(-30, -8, -10), "RightLowerLeg": Vector3(80, 0, 0),
	}])
	var kick := _merge([_fists(), {
		"drop": -0.42, "plant": [],
		"Hips": Vector3(-95, 0, 0),
		"Spine": Vector3(-8, 0, 0), "Chest": Vector3(-6, 0, 0), "UpperChest": Vector3(-4, 0, 0),
		"Neck": Vector3(20, 0, 0), "Head": Vector3(30, 0, 0),
		"LeftUpperArm": Vector3(70, 0, -60), "LeftLowerArm": Vector3(0, -20, 0),
		"RightUpperArm": Vector3(70, 0, 60), "RightLowerArm": Vector3(0, 20, 0),
		"LeftUpperLeg": Vector3(20, 0, 6), "LeftLowerLeg": Vector3(100, 0, 0),
		"LeftFoot": Vector3(30, 0, 0),
		"RightUpperLeg": Vector3(-50, 0, -4), "RightLowerLeg": Vector3(2, 0, 0),
		"RightFoot": Vector3(40, 0, 0),
	}])
	var kick_hold := _merge([kick, {"drop": -0.46, "Hips": Vector3(-125, 0, 0),
		"RightUpperLeg": Vector3(-56, 0, -4)}])
	var tuck := _merge([_fists(), {
		"drop": -0.5, "plant": [],
		"Hips": Vector3(-215, 0, 0),
		"Spine": Vector3(14, 0, 0), "Chest": Vector3(10, 0, 0), "Head": Vector3(10, 0, 0),
		"LeftUpperArm": Vector3(-30, 0, -70), "LeftLowerArm": Vector3(0, -90, 0),
		"RightUpperArm": Vector3(-30, 0, 70), "RightLowerArm": Vector3(0, 90, 0),
		"LeftUpperLeg": Vector3(-90, 8, 6), "LeftLowerLeg": Vector3(110, 0, 0),
		"RightUpperLeg": Vector3(-80, -8, -6), "RightLowerLeg": Vector3(100, 0, 0),
	}])
	var land := _merge([crouch, {
		"drop": 0.22, "plant": [], "Hips": Vector3(-340, -20, 0), "Spine": Vector3(14, 6, 0),
		"Head": Vector3(-16, 4, 0),
		"LeftUpperArm": Vector3(-20, 0, -60), "RightUpperArm": Vector3(-20, 0, 60),
	}])
	var land_settle := _merge([land, {"Hips": Vector3(-345, -26, 0)}])
	return {
		"frames": 37, "loop": false, "grounded": true, "impact": Vector2i(9, 13),
		"keys": [_key(0, _stance()), _key(5, crouch, "out"), _key(9, kick, "snap"),
			_key(13, kick_hold, "linear"), _key(21, tuck, "linear"), _key(28, land, "in"),
			_key(31, land_settle, "out"), _key(37, _stance(), "in_out")],
	}


## Axe kick: the right leg swung straight up past the head, then the heel
## chopped down; the spike.
static func _axe_kick() -> Dictionary:
	var load_pose := _merge([_stance(), {"drop": 0.1, "Hips": Vector3(2, -26, 0),
		"RightUpperLeg": Vector3(14, -8, -10)}])
	var raise := _merge([_stance(), {
		"drop": 0.02, "plant": ["L"],
		"Hips": Vector3(-14, -12, 0), "Spine": Vector3(-6, 4, 0), "Chest": Vector3(-4, 4, 0),
		"Head": Vector3(6, 4, 0),
		"LeftUpperArm": Vector3(-40, 0, -50), "LeftLowerArm": Vector3(0, -60, 0),
		"RightUpperArm": Vector3(-10, 0, 40), "RightLowerArm": Vector3(0, 40, 0),
		"LeftUpperLeg": Vector3(-4, 8, 4), "LeftLowerLeg": Vector3(14, 0, 0),
		"RightUpperLeg": Vector3(-125, 0, -18), "RightLowerLeg": Vector3(6, 0, 0),
		"RightFoot": Vector3(-10, 0, 0),
	}])
	var chop := _merge([raise, {
		"drop": 0.12,
		"Hips": Vector3(16, -16, 0), "Spine": Vector3(10, 4, 0), "Chest": Vector3(8, 4, 0),
		"Head": Vector3(-14, 4, 0),
		"LeftUpperArm": Vector3(30, 0, -70), "LeftLowerArm": Vector3(0, -40, 0),
		"RightUpperArm": Vector3(30, 0, 70), "RightLowerArm": Vector3(0, 40, 0),
		"LeftUpperLeg": Vector3(-20, 8, 4), "LeftLowerLeg": Vector3(40, 0, 0),
		"RightUpperLeg": Vector3(-96, 0, -6), "RightLowerLeg": Vector3(2, 0, 0),
		"RightFoot": Vector3(-24, 0, 0),
	}])
	var chop_hold := _merge([chop, {"drop": 0.14, "RightUpperLeg": Vector3(-86, 0, -6)}])
	var lower := _merge([_stance(), {"drop": 0.12, "Hips": Vector3(10, -20, 0),
		"RightUpperLeg": Vector3(-30, 0, -8), "RightLowerLeg": Vector3(40, 0, 0),
		"RightFoot": Vector3(-10, 0, 0), "plant": ["L"]}])
	return {
		"frames": 42, "loop": false, "grounded": true, "impact": Vector2i(15, 18),
		"keys": [_key(0, _stance()), _key(5, load_pose, "out"), _key(11, raise, "out"),
			_key(13, raise, "linear"), _key(15, chop, "snap"), _key(18, chop_hold, "linear"),
			_key(28, lower, "out"), _key(42, _stance(), "in_out")],
	}


## Crouching spin sweep: drop onto the bent lead leg, right hand on the floor,
## the straight right leg swinging round at ankle height; the sweep.
static func _low_sweep_kick() -> Dictionary:
	var drop_pose := _merge([_fists(), {
		"drop": 0.36, "plant": ["L", "R"],
		"Hips": Vector3(24, -70, 0),
		"Spine": Vector3(12, 10, 0), "Chest": Vector3(8, 8, 0), "UpperChest": Vector3(6, 8, 0),
		"Neck": Vector3(-14, 10, 0), "Head": Vector3(-18, 14, 0),
		"LeftUpperArm": Vector3(-50, 8, -66), "LeftLowerArm": Vector3(0, -110, 0),
		"RightUpperArm": Vector3(-30, 0, 74), "RightLowerArm": Vector3(0, 40, 0),
		"LeftUpperLeg": Vector3(-80, 20, 12), "LeftLowerLeg": Vector3(120, 0, 0),
		"LeftFoot": Vector3(-34, 0, 0),
		"RightUpperLeg": Vector3(-10, -10, -40), "RightLowerLeg": Vector3(60, 0, 0),
		"RightFoot": Vector3(-20, 0, 0),
	}])
	var sweep := _merge([_fists(), {
		"drop": 0.56, "plant": ["L"],
		"Hips": Vector3(30, 30, 0),
		"Spine": Vector3(14, -10, -6), "Chest": Vector3(10, -8, -6), "UpperChest": Vector3(8, -8, -4),
		"Neck": Vector3(-20, -8, 0), "Head": Vector3(-24, -12, 0),
		"LeftUpperArm": Vector3(-50, 8, -64), "LeftLowerArm": Vector3(0, -110, 0),
		"RightUpperArm": Vector3(-40, 0, 88), "RightLowerArm": Vector3(0, 8, 0),
		"RightHand": Vector3(0, 0, -40),
		"LeftUpperLeg": Vector3(-100, 24, 20), "LeftLowerLeg": Vector3(140, 0, 0),
		"LeftFoot": Vector3(-40, 0, 0),
		"RightUpperLeg": Vector4(-30, 0, -72, 0), "RightLowerLeg": Vector3(2, 0, 0),
		"RightFoot": Vector3(-24, 0, 0),
	}])
	var sweep_end := _merge([sweep, {"Hips": Vector3(30, 80, 0),
		"Head": Vector3(-24, -30, 0), "RightUpperLeg": Vector4(-26, 0, -70, 0)}])
	var rise := _merge([drop_pose, {"drop": 0.3, "Hips": Vector3(20, 40, 0),
		"Spine": Vector3(10, -40, 0), "Head": Vector3(-16, -20, 0)}])
	return {
		"frames": 35, "loop": false, "grounded": true, "impact": Vector2i(12, 17),
		"keys": [_key(0, _stance()), _key(7, drop_pose, "out"), _key(12, sweep, "snap"),
			_key(17, sweep_end, "linear"), _key(25, rise, "out"), _key(35, _stance(), "in_out")],
	}


## Rear knee driven up into the opponent while both hands pull down.
static func _knee_strike() -> Dictionary:
	var reach := _merge([_stance(), {
		"drop": 0.08,
		"LeftUpperArm": Vector3(-80, 0, -60), "LeftLowerArm": Vector3(0, -40, 0),
		"RightUpperArm": Vector3(-80, 0, 60), "RightLowerArm": Vector3(0, 40, 0),
	}])
	var knee := _merge([_fists(), {
		"drop": 0.0, "plant": ["L"],
		"Hips": Vector3(-14, -10, 0), "Spine": Vector3(-4, 4, 0), "Chest": Vector3(2, 2, 0),
		"UpperChest": Vector3(8, 2, 0), "Head": Vector3(-4, 4, 0),
		"LeftUpperArm": Vector3(-62, 0, -74), "LeftLowerArm": Vector3(0, -70, 0),
		"RightUpperArm": Vector3(-62, 0, 74), "RightLowerArm": Vector3(0, 70, 0),
		"LeftUpperLeg": Vector3(4, 10, 4), "LeftLowerLeg": Vector3(14, 0, 0),
		"LeftFoot": Vector3(10, 0, 0),
		"RightUpperLeg": Vector3(-110, 0, -4), "RightLowerLeg": Vector3(130, 0, 0),
		"RightFoot": Vector3(40, 0, 0),
	}])
	var knee_hold := _merge([knee, {"RightUpperLeg": Vector3(-114, 0, -4)}])
	return {
		"frames": 28, "loop": false, "grounded": true, "impact": Vector2i(9, 12),
		"keys": [_key(0, _stance()), _key(5, reach, "out"), _key(9, knee, "snap"),
			_key(12, knee_hold, "linear"), _key(28, _stance(), "in_out")],
	}
