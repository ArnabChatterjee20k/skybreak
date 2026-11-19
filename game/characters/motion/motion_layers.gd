class_name MotionLayers
extends SkeletonModifier3D
## Procedural realism on top of any clip: lean into acceleration and velocity, a sprung
## superhero-flight body (pitch, bank, trailing legs, tucked or reaching arms, dash burst),
## hip/spine counter-rotation, look-at, critically damped secondary motion, two-bone foot IK with
## pelvis drop, additive hit flinches, per-weapon arm IK and inertialized clip switches.
## Everything is in skeleton space (+Y up, facing +Z). Set the inputs each frame; call
## inertialize() right before switching clips. Works on a Skeleton3D or, for tests, on arrays.

const SPINE := [&"Hips", &"Spine", &"Chest", &"UpperChest", &"Neck", &"Head"]
const LEGS := [[&"LeftUpperLeg", &"LeftLowerLeg", &"LeftFoot"], [&"RightUpperLeg", &"RightLowerLeg", &"RightFoot"]]
const SECONDARY := [&"Head", &"LeftUpperArm", &"RightUpperArm", &"LeftLowerArm", &"RightLowerArm"]
const MAX_LEAN := deg_to_rad(28.0)
const MAX_BANK := deg_to_rad(55.0)
const PLANTED_HEIGHT := 0.06
const MAX_PELVIS_DROP := 0.25
const ARMS := [[&"LeftUpperArm", &"LeftLowerArm", &"LeftHand"], [&"RightUpperArm", &"RightLowerArm", &"RightHand"]]
## Flight: speed (m/s) for the full flight body, and the flutter of the trailing legs.
const FLIGHT_FULL_SPEED := 22.0
const FLUTTER_HZ := 2.4
## Arm poses for held weapons (T-D30), solved by two-bone IK on top of the clip.
enum ArmPose { NONE, TWO_HANDED, BOW_DRAW, PISTOL_AIM, GUARD, BRACED }
## Main-hand grip point per pose, from its shoulder in chest space (+Y up, +Z forward, +X to the
## holder's left), in arm lengths, then the weapon's +Y and its forward (-Z) in the same space.
const ARM_POSES := {
	ArmPose.GUARD: [Vector3(-0.15, -0.62, 0.62), Vector3(-0.15, 0.8, 0.58), Vector3(0, -0.4, 1)],
	ArmPose.TWO_HANDED: [Vector3(0.2, -0.78, 0.55), Vector3(0.62, 0.62, 0.48), Vector3(0, 0, 1)],
	ArmPose.PISTOL_AIM: [Vector3(0.12, 0.02, 0.96), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	ArmPose.BRACED: [Vector3(-0.3, -0.62, 0.62), Vector3(0, 1, 0), Vector3(0, 0, 1)],
}
## Bow draw: the string hand anchors this far beside the head capsule's surface (m), at jaw height.
const BOW_ANCHOR_GAP := 0.07
const BOW_ANCHOR_DROP := 0.04
## Clearance solver: passes, and the margin it leaves (m).
const CLEARANCE_PASSES := 10
const CLEARANCE_MARGIN := 0.03
## Capsules a held weapon must stay out of, per main hand (its own forearm and hand grip it).
const CLEAR_OF := {
	&"RightHand": [&"pelvis", &"chest", &"head", &"upper_arm_l", &"lower_arm_l", &"upper_arm_r"],
	&"LeftHand": [&"pelvis", &"chest", &"head", &"upper_arm_l", &"upper_arm_r", &"lower_arm_r"],
}

## Fighter velocity in skeleton space (m/s).
@export var velocity := Vector3.ZERO
@export var flying := false
## Point to look at in skeleton space; null-like when look_weight is 0.
@export var look_target := Vector3(0, 1.5, 5)
@export_range(0.0, 1.0) var look_weight := 0.0
@export var foot_ik := true
## Ground height under each foot in skeleton space (left, right).
@export var ground := Vector2.ZERO
## Lean per m/s^2 of acceleration and per m/s of velocity (radians).
@export var accel_lean := 0.03
@export var velocity_lean := 0.012
@export var lean_frequency := 9.0
@export var secondary_frequency := 14.0
@export var flinch_frequency := 16.0
## Inertialization speed: critically damped decay rate (1/s).
@export var blend_frequency := 18.0
## Held-weapon arm pose and how much of it to apply (0..1, sprung).
@export var arm_pose := ArmPose.NONE
@export_range(0.0, 1.0) var arm_weight := 0.0
## Lean, flight, look, secondary, flinch and landing layers; off keeps only the IK stages.
@export var body_layers := true
## Held weapon: the hand bone it sits on (empty = none), its transform in that bone's space,
## its part boxes in its own space and the off-hand grip point (INF = one-handed).
var weapon_hand := &""
var weapon_grip := Transform3D.IDENTITY
var weapon_boxes: Array[Transform3D] = []
var weapon_off_hand := Vector3.INF
## The off hand's palm socket in its bone's space (see WeaponGrip.hand_socket).
var off_hand_socket := Transform3D.IDENTITY
## The holder's body capsules; the clearance solver keeps the weapon out of them.
var body: BodyCapsules
## Deepest weapon-into-body overlap left after the last solve (m), for tests and QA.
var weapon_overlap := 0.0

var lean := Vector3.ZERO  # Current lean as a rotation vector (x pitch, z roll).
var _lean_velocity := Vector3.ZERO
var _last_velocity := Vector3.ZERO
var _look := Vector2.ZERO
var _look_velocity := Vector2.ZERO
var _secondary: Array[Vector3] = []
var _secondary_velocity: Array[Vector3] = []
var _flinch := Vector3.ZERO
var _flinch_velocity := Vector3.ZERO
var _last_chest := Quaternion.IDENTITY
var _landing := 0.0
var _landing_velocity := 0.0
# Inertialization: per-bone rotation offsets (rotation vectors) and the hips offset.
var _offsets: Array[Vector3] = []
var _offset_velocity: Array[Vector3] = []
var _hips_offset := Vector3.ZERO
var _hips_offset_velocity := Vector3.ZERO
var _pending_blend := false
var _last_out: Array[Quaternion] = []
var _prev_out: Array[Quaternion] = []
var _last_hips := Vector3.ZERO
var _prev_hips := Vector3.ZERO
var _last_delta := 1.0 / 60.0
# Flight body: amount (0..1), arm reach (dive), dash burst and the flutter phase.
var _flight := 0.0
var _flight_velocity := 0.0
var _reach := 0.0
var _reach_velocity := 0.0
var _burst := 0.0
var _burst_velocity := 0.0
var _flutter_phase := 0.0
var _arm := 0.0
var _arm_velocity := 0.0
var _arm_pose_now := ArmPose.NONE
var _world_cache: Array = []
var _rest_parent_rot: Array[Quaternion] = []
## Bones the skeleton mode reads and writes (the body; fingers and extras are left alone).
var _used: PackedInt32Array = []
var _scratch: Array[Quaternion] = []
# Bones (from the skeleton or setup_bones()).
var _names: Array[StringName] = []
var _parents: PackedInt32Array = []
var _origins: Array[Vector3] = []
var _rest_heights: PackedFloat32Array = []
var _index := {}


func _ready() -> void:
	var skeleton := get_skeleton()
	if skeleton:
		var names := PackedStringArray()
		var parents := PackedInt32Array()
		var rests: Array[Transform3D] = []
		for i in skeleton.get_bone_count():
			names.append(skeleton.get_bone_name(i))
			parents.append(skeleton.get_bone_parent(i))
			rests.append(skeleton.get_bone_rest(i))
		setup_bones(names, parents, rests)


## Bone layout for array mode: names, parent indices and rest transforms.
func setup_bones(names: PackedStringArray, parents: PackedInt32Array, rests: Array[Transform3D]) -> void:
	_names.clear()
	_index.clear()
	_origins.clear()
	_rest_heights.clear()
	var world: Array[Transform3D] = []
	for i in names.size():
		_names.append(StringName(names[i]))
		_index[StringName(names[i])] = i
		_origins.append(rests[i].origin)
		world.append(rests[i] if parents[i] < 0 else world[parents[i]] * rests[i])
		_rest_heights.append(world[i].origin.y)
	_parents = parents
	_rest_parent_rot.clear()
	_used.clear()
	var body := SPINE.duplicate()
	for chain: Array in LEGS + ARMS:
		body.append_array(chain)
	body.append_array([&"LeftShoulder", &"RightShoulder", &"LeftToes", &"RightToes"])
	for i in names.size():
		_rest_parent_rot.append(Quaternion.IDENTITY if parents[i] < 0 else world[parents[i]].basis.get_rotation_quaternion())
		if body.has(_names[i]):
			_used.append(i)
	reset()


## Clears all spring state (e.g. after a teleport).
func reset() -> void:
	lean = Vector3.ZERO
	_lean_velocity = Vector3.ZERO
	_last_velocity = velocity
	_look = Vector2.ZERO
	_look_velocity = Vector2.ZERO
	_secondary.resize(SECONDARY.size())
	_secondary.fill(Vector3.ZERO)
	_secondary_velocity.resize(SECONDARY.size())
	_secondary_velocity.fill(Vector3.ZERO)
	_flinch = Vector3.ZERO
	_flinch_velocity = Vector3.ZERO
	_landing = 0.0
	_landing_velocity = 0.0
	_offsets.resize(_names.size())
	_offsets.fill(Vector3.ZERO)
	_offset_velocity.resize(_names.size())
	_offset_velocity.fill(Vector3.ZERO)
	_hips_offset = Vector3.ZERO
	_hips_offset_velocity = Vector3.ZERO
	_last_out.clear()
	_prev_out.clear()
	_pending_blend = false
	_flight = 0.0
	_flight_velocity = 0.0
	_reach = 0.0
	_reach_velocity = 0.0
	_burst = 0.0
	_burst_velocity = 0.0
	_arm = 0.0
	_arm_velocity = 0.0


## Blend from the last output pose into whatever the next clip gives, without a linear crossfade.
func inertialize() -> void:
	_pending_blend = not _last_out.is_empty()


## Additive hit flinch: the upper body snaps away from direction (skeleton space), then recovers.
func flinch(direction: Vector3, strength := 1.0) -> void:
	var axis := Vector3.UP.cross(direction.normalized())
	_flinch_velocity += axis * strength * 9.0


## Landing: knees and arms absorb it (strength 1 = a normal landing).
func land(strength := 1.0) -> void:
	_landing_velocity -= strength * 2.5


## Flight dash: the body snaps into a streamlined burst pose, then springs back.
func burst(strength := 1.0) -> void:
	_burst_velocity += strength * 14.0


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _names.is_empty():
		return
	if _scratch.size() != _names.size():
		_scratch.resize(_names.size())
		_scratch.fill(Quaternion.IDENTITY)
	var rotations := _scratch
	for i in _used:
		rotations[i] = skeleton.get_bone_pose_rotation(i)
	var hips_id: int = _index.get(&"Hips", -1)
	var hips := skeleton.get_bone_pose_position(hips_id) if hips_id >= 0 else Vector3.ZERO
	hips = process_pose(rotations, hips, delta)
	for i in _used:
		skeleton.set_bone_pose_rotation(i, rotations[i])
	if hips_id >= 0:
		skeleton.set_bone_pose_position(hips_id, hips)


## Applies every layer to local bone rotations (in place) and returns the new hips position.
func process_pose(rotations: Array[Quaternion], hips: Vector3, delta: float) -> Vector3:
	if delta <= 0.0:
		delta = 0.0
	if body_layers:
		_inertialize(rotations, delta)
		hips = _inertialize_hips(hips, delta)
		_lean_layer(rotations, delta)
		_flight_layer(rotations, delta)
		_look_layer(rotations, delta)
		_secondary_layer(rotations, delta)
		_flinch_layer(rotations, delta)
		hips = _landing_layer(rotations, hips, delta)
	_arm_layer(rotations, hips, delta)
	_clearance(rotations, hips)
	if foot_ik:
		hips = _foot_ik(rotations, hips)
	_prev_out = _last_out.duplicate()
	_last_out = rotations.duplicate()
	_prev_hips = _last_hips
	_last_hips = hips
	if delta > 0.0:
		_last_delta = delta
	return hips


# --- Springs -------------------------------------------------------------------------------------

## Critically damped spring step toward target (exact for constant target).
static func spring(x: Variant, v: Variant, target: Variant, frequency: float, delta: float) -> Array:
	var y: Variant = x - target
	var e := exp(-frequency * delta)
	var j: Variant = v + y * frequency
	return [target + (y + j * delta) * e, (v - j * frequency * delta) * e]


static func rotvec(q: Quaternion) -> Vector3:
	if q.w < 0.0:
		q = -q
	var angle := q.get_angle()
	return q.get_axis() * angle if angle > 1e-6 else Vector3.ZERO


static func from_rotvec(v: Vector3) -> Quaternion:
	var angle := v.length()
	return Quaternion(v / angle, angle) if angle > 1e-6 else Quaternion.IDENTITY


# --- Layers --------------------------------------------------------------------------------------

func _inertialize(rotations: Array[Quaternion], delta: float) -> void:
	var starting := _pending_blend
	if _pending_blend:
		_pending_blend = false
		for i in rotations.size():
			_offsets[i] = rotvec(_last_out[i] * rotations[i].inverse())
			_offset_velocity[i] = Vector3.ZERO
			if _prev_out.size() == rotations.size():
				_offset_velocity[i] = rotvec(_last_out[i] * _prev_out[i].inverse()) / _last_delta
		_hips_offset = Vector3(INF, 0, 0)  # Resolved against the new hips in _inertialize_hips.
		_hips_offset_velocity = Vector3.ZERO
	for i in rotations.size():
		if _offsets[i] == Vector3.ZERO and _offset_velocity[i] == Vector3.ZERO:
			continue
		if not starting:
			# The offset decays to zero, carrying the old clip's velocity in at first.
			var s := spring(_offsets[i], _offset_velocity[i], Vector3.ZERO, blend_frequency, delta)
			_offsets[i] = s[0]
			_offset_velocity[i] = s[1]
			if _offsets[i].length() < 1e-5 and _offset_velocity[i].length() < 1e-4:
				_offsets[i] = Vector3.ZERO
				_offset_velocity[i] = Vector3.ZERO
		rotations[i] = from_rotvec(_offsets[i]) * rotations[i]


func _inertialize_hips(hips: Vector3, delta: float) -> Vector3:
	if is_inf(_hips_offset.x):
		_hips_offset = _last_hips - hips
		return hips + _hips_offset
	if _hips_offset == Vector3.ZERO:
		return hips
	var s := spring(_hips_offset, _hips_offset_velocity, Vector3.ZERO, blend_frequency, delta)
	_hips_offset = s[0]
	_hips_offset_velocity = s[1]
	return hips + _hips_offset


func _lean_layer(rotations: Array[Quaternion], delta: float) -> void:
	var accel := (velocity - _last_velocity) / delta if delta > 0.0 else Vector3.ZERO
	_last_velocity = velocity
	accel = accel.limit_length(60.0)
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	# Pitch into forward motion (+Z forward: rotating about +X tips the top forward).
	var target := Vector3(
		accel.z * accel_lean + horizontal.z * velocity_lean,
		0.0,
		-accel.x * accel_lean - horizontal.x * velocity_lean)
	if flying:
		# Bank into turns: roll with lateral acceleration, pitch down with speed (dive).
		target.z = clampf(-accel.x * accel_lean * 2.0 - velocity.x * 0.03, -MAX_BANK, MAX_BANK)
		var speed := velocity.length()
		target.x = clampf(velocity.z * 0.035 - velocity.y * 0.02 + speed * 0.012 + _burst * 0.35,
			-MAX_LEAN, deg_to_rad(78.0))
	else:
		target.x = clampf(target.x, -MAX_LEAN, MAX_LEAN)
		target.z = clampf(target.z, -MAX_LEAN, MAX_LEAN)
	var s := spring(lean, _lean_velocity, target, lean_frequency, delta)
	lean = s[0]
	_lean_velocity = s[1]
	var hips: int = _index.get(&"Hips", -1)
	if hips < 0:
		return
	rotations[hips] = from_rotvec(lean) * rotations[hips]
	# Counter-rotation: the chest takes back part of the hips' lean and twist, keeping the head level.
	var chest: int = _index.get(&"Chest", -1)
	if chest >= 0:
		var twist := rotations[hips].get_euler().y
		var counter := from_rotvec(-lean * 0.35 + Vector3(0, -twist * 0.25, 0))
		rotations[chest] = counter * rotations[chest]


## Rotation by euler (radians) about axes of the model's rest frame, applied in bone i's parent.
func _rest_frame(i: int, euler: Vector3) -> Quaternion:
	var p := _rest_parent_rot[i]
	return p.inverse() * Quaternion.from_euler(euler) * p


func _offset(rotations: Array[Quaternion], bone: StringName, euler: Vector3) -> void:
	var i: int = _index.get(bone, -1)
	if i >= 0 and euler != Vector3.ZERO:
		rotations[i] = _rest_frame(i, euler) * rotations[i]


## Superhero flight: legs trail and flutter, arms tuck at speed or reach in a dive, dash bursts.
func _flight_layer(rotations: Array[Quaternion], delta: float) -> void:
	var speed := velocity.length()
	var amount := clampf(speed / FLIGHT_FULL_SPEED, 0.0, 1.0) if flying else 0.0
	var s := spring(_flight, _flight_velocity, amount, 7.0, delta)
	_flight = s[0]
	_flight_velocity = s[1]
	var diving := clampf((-velocity.y - 6.0) / 14.0, 0.0, 1.0) if flying else 0.0
	var forward := clampf((velocity.z - 16.0) / 10.0, 0.0, 1.0) if flying else 0.0
	s = spring(_reach, _reach_velocity, maxf(diving, forward), 6.0, delta)
	_reach = s[0]
	_reach_velocity = s[1]
	s = spring(_burst, _burst_velocity, 0.0, 9.0, delta)
	_burst = clampf(s[0], -0.3, 1.2)
	_burst_velocity = s[1]
	if _flight < 0.002 and absf(_burst) < 0.002:
		return
	_flutter_phase = fmod(_flutter_phase + delta * TAU * FLUTTER_HZ * (0.6 + _flight), TAU)
	var f := _flight
	var flutter := sin(_flutter_phase) * 0.07 * f
	var b := _burst
	# Legs: straighten in line with the body, knees soft, alternating flutter; the burst pulls them together.
	_offset(rotations, &"LeftUpperLeg", Vector3(0.22 * f + flutter - 0.1 * b, 0, -0.05 * f))
	_offset(rotations, &"RightUpperLeg", Vector3(0.22 * f - flutter - 0.1 * b, 0, 0.05 * f))
	_offset(rotations, &"LeftLowerLeg", Vector3(0.18 * f + flutter * 1.5 + 0.2 * b, 0, 0))
	_offset(rotations, &"RightLowerLeg", Vector3(0.32 * f - flutter * 1.5 + 0.2 * b, 0, 0))
	_offset(rotations, &"LeftFoot", Vector3(0.45 * f, 0, 0))
	_offset(rotations, &"RightFoot", Vector3(0.45 * f, 0, 0))
	# Arms: tucked back along the body at speed; the lead (right) arm reaches ahead in a dive.
	var tuck := f * (1.0 - _reach) + b
	var reach := _reach * f
	_offset(rotations, &"LeftUpperArm", Vector3(0.55 * tuck, 0, -0.35 * tuck))
	_offset(rotations, &"RightUpperArm", Vector3(0.55 * tuck * (1.0 - _reach) - 2.4 * reach, 0, 0.35 * tuck - 0.2 * reach))
	_offset(rotations, &"RightLowerArm", Vector3(0.6 * reach, 0, 0))
	_offset(rotations, &"LeftLowerArm", Vector3(0.25 * tuck, 0, 0))
	# Head stays up, looking where it flies.
	_offset(rotations, &"Neck", Vector3(-0.25 * f - 0.1 * b, 0, 0))
	_offset(rotations, &"Head", Vector3(-0.3 * f, 0, 0))


## Held-weapon arm pose: the main hand to its grip point with the weapon turned to the pose,
## the off hand onto the weapon's off-hand grip; bows draw the string to beside the face.
func _arm_layer(rotations: Array[Quaternion], hips: Vector3, delta: float) -> void:
	if arm_pose != ArmPose.NONE:
		_arm_pose_now = arm_pose
	var s := spring(_arm, _arm_velocity, arm_weight if arm_pose != ArmPose.NONE else 0.0, 14.0, delta)
	_arm = clampf(s[0], 0.0, 1.0)
	_arm_velocity = s[1]
	if _arm < 0.01 or _arm_pose_now == ArmPose.NONE or weapon_hand == &"":
		return
	var chest: int = _index.get(&"UpperChest", _index.get(&"Chest", -1))
	var main: int = _index.get(weapon_hand, -1)
	if chest < 0 or main < 0:
		return
	_world_cache.clear()
	var frame := _world_at(rotations, hips, chest).basis.orthonormalized()
	var main_chain := _arm_chain(weapon_hand)
	if main_chain.is_empty():
		return
	var shoulder := _world_at(rotations, hips, main_chain[0]).origin
	var reach := _arm_length(main_chain)
	var grip := weapon_grip.orthonormalized()
	var goal_point: Vector3
	var goal_basis: Basis
	if _arm_pose_now == ArmPose.BOW_DRAW:
		var anchor := _bow_anchor(rotations, hips, frame)
		# Bow arm straight out toward the target, in line with the anchor beside the face.
		var aim := frame * Vector3(0, 0, 1)
		var toward := anchor + aim * reach * 1.3 - shoulder
		goal_point = shoulder + toward.normalized() * reach * 0.96
		var forward := (goal_point - anchor).normalized()
		var up := (frame * Vector3(0.12, 1, 0)).normalized()
		goal_basis = _weapon_basis(up, forward)
	elif ARM_POSES.has(_arm_pose_now):
		var pose: Array = ARM_POSES[_arm_pose_now]
		# Poses are authored for the right hand; a left main hand mirrors them.
		var mirror := Vector3(-1, 1, 1) if weapon_hand == &"LeftHand" else Vector3.ONE
		goal_point = shoulder + frame * ((pose[0] as Vector3) * mirror * reach)
		goal_basis = _weapon_basis(frame * ((pose[1] as Vector3) * mirror).normalized(), frame * (pose[2] as Vector3).normalized())
	else:
		return
	var hand_basis := goal_basis * grip.basis.inverse()
	var hand_point := goal_point - hand_basis * grip.origin
	_reach_hand(rotations, hips, main_chain, hand_point, hand_basis.get_rotation_quaternion(), _arm)
	if _arm_pose_now == ArmPose.BOW_DRAW:
		var anchor := _bow_anchor(rotations, hips, frame)
		var string_chain := _arm_chain(&"RightHand" if weapon_hand == &"LeftHand" else &"LeftHand")
		if not string_chain.is_empty():
			var bow := _world_at(rotations, hips, main_chain[2]) * weapon_grip
			var pull := (anchor - bow.origin).normalized()
			var palm := _weapon_basis(frame * Vector3.UP, -pull)
			_reach_hand(rotations, hips, string_chain, anchor - pull * 0.03, palm.get_rotation_quaternion(), _arm)
	else:
		_grip_off_hand(rotations, hips, _arm)


## Where the bow string hand anchors: beside the head capsule on the string-hand side, at the jaw.
func _bow_anchor(rotations: Array[Quaternion], hips: Vector3, frame: Basis) -> Vector3:
	var head: int = _index.get(&"Head", -1)
	var radius := 0.12
	if body != null and body.radii.has(&"head"):
		radius = body.radii[&"head"]
	var at := _world_at(rotations, hips, head).origin if head >= 0 else Vector3(0, 1.4, 0)
	var side := -1.0 if weapon_hand == &"LeftHand" else 1.0
	return at + frame * Vector3(side * (radius + BOW_ANCHOR_GAP), -BOW_ANCHOR_DROP, 0.04)


## A weapon basis whose +Y is up and whose -Z points along forward (made orthogonal).
static func _weapon_basis(up: Vector3, forward: Vector3) -> Basis:
	var y := up.normalized()
	var z := -(forward - y * forward.dot(y))
	z = z.normalized() if z.length() > 1e-4 else y.cross(Vector3.RIGHT).normalized()
	return Basis(y.cross(z), y, z).orthonormalized()


## [upper arm, lower arm, hand] bone indices of a hand, or empty.
func _arm_chain(hand: StringName) -> Array:
	for chain: Array in ARMS:
		if chain[2] == hand:
			var ids := [_index.get(chain[0], -1), _index.get(chain[1], -1), _index.get(chain[2], -1)]
			return [] if ids.has(-1) else ids
	return []


func _arm_length(chain: Array) -> float:
	return (_origins[chain[1]] as Vector3).length() + (_origins[chain[2]] as Vector3).length()


## Two-bone IK of one arm to a hand position and world rotation, blended by weight.
func _reach_hand(rotations: Array[Quaternion], hips: Vector3, chain: Array, point: Vector3,
		hand_rotation: Quaternion, weight: float) -> void:
	var up: int = chain[0]
	var lo: int = chain[1]
	var hand: int = chain[2]
	var before := [rotations[up], rotations[lo], rotations[hand]]
	_world_cache.clear()
	_two_bone(rotations, _chain_world(rotations, hips, chain), up, lo, hand, point)
	_world_cache.clear()
	var lower := _world_at(rotations, hips, lo).basis.get_rotation_quaternion()
	rotations[hand] = lower.inverse() * hand_rotation
	rotations[up] = (before[0] as Quaternion).slerp(rotations[up], weight)
	rotations[lo] = (before[1] as Quaternion).slerp(rotations[lo], weight)
	rotations[hand] = (before[2] as Quaternion).slerp(rotations[hand], weight)
	_world_cache.clear()


## The off hand onto the weapon's off-hand grip (two-handed weapons).
func _grip_off_hand(rotations: Array[Quaternion], hips: Vector3, weight: float) -> void:
	if weapon_off_hand == Vector3.INF:
		return
	var main: Array = _arm_chain(weapon_hand)
	var off: Array = _arm_chain(&"RightHand" if weapon_hand == &"LeftHand" else &"LeftHand")
	if main.is_empty() or off.is_empty():
		return
	_world_cache.clear()
	var weapon := (_world_at(rotations, hips, main[2]) * weapon_grip).orthonormalized()
	# The off hand's palm socket closes around the off-hand grip, along the haft.
	var hand_basis := weapon.basis * off_hand_socket.basis.orthonormalized().inverse()
	var point := weapon * (weapon_off_hand * weapon_grip.basis.get_scale()) - hand_basis * off_hand_socket.origin
	_reach_hand(rotations, hips, off, point, hand_basis.get_rotation_quaternion(), weight)


## Body clearance: while the held weapon's boxes reach into the holder's torso, head or arms,
## move the main hand (and the weapon with it) out along the push and solve the arm again.
func _clearance(rotations: Array[Quaternion], hips: Vector3) -> void:
	weapon_overlap = 0.0
	if weapon_hand == &"" or body == null or weapon_boxes.is_empty():
		return
	var main := _arm_chain(weapon_hand)
	if main.is_empty():
		return
	var names: Array = CLEAR_OF.get(weapon_hand, [])
	if weapon_off_hand != Vector3.INF:
		names = names.filter(func(n: StringName) -> bool: return not n.begins_with("lower_arm"))
	for pass_index in CLEARANCE_PASSES + 1:
		_world_cache.clear()
		var hand := _world_at(rotations, hips, main[2])
		var weapon := hand * weapon_grip
		var boxes: Array[Transform3D] = []
		for box in weapon_boxes:
			boxes.append(weapon * box)
		var capsules := body.capsules(func(bone: int) -> Transform3D: return _world_at(rotations, hips, bone),
			Transform3D.IDENTITY, names)
		var hit := BodyCapsules.deepest_box(capsules, boxes)
		weapon_overlap = maxf(float(hit[0]), 0.0)
		if float(hit[0]) <= 0.0 or pass_index == CLEARANCE_PASSES:
			return
		var push: Vector3 = hit[1]
		var target := hand.origin + push * (float(hit[0]) + CLEARANCE_MARGIN)
		_reach_hand(rotations, hips, main, target, hand.basis.get_rotation_quaternion(), 1.0)
		_grip_off_hand(rotations, hips, 1.0)


## World transforms of one chain (plus its parent), as a sparse array _two_bone can read.
func _chain_world(rotations: Array[Quaternion], hips: Vector3, chain: Array) -> Array:
	var out := []
	out.resize(_names.size())
	var top: int = chain[0]
	if _parents[top] >= 0:
		out[_parents[top]] = _world_at(rotations, hips, _parents[top])
	for i: int in chain:
		out[i] = _world_at(rotations, hips, i)
	return out


## One bone's world transform, cached per pass (clear _world_cache when rotations change).
func _world_at(rotations: Array[Quaternion], hips: Vector3, bone: int) -> Transform3D:
	if _world_cache.size() != _names.size():
		_world_cache.resize(_names.size())
		_world_cache.fill(null)
	if _world_cache[bone] != null:
		return _world_cache[bone]
	var origin: Vector3 = hips if _names[bone] == &"Hips" else _origins[bone]
	var local := Transform3D(Basis(rotations[bone]), origin)
	var result := local if _parents[bone] < 0 else _world_at(rotations, hips, _parents[bone]) * local
	_world_cache[bone] = result
	return result


func _look_layer(rotations: Array[Quaternion], delta: float) -> void:
	var target := Vector2.ZERO
	if look_weight > 0.0:
		var to := look_target - Vector3(0, 1.5, 0)
		target = Vector2(clampf(atan2(to.x, to.z), -1.0, 1.0), clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.6, 0.6))
		target *= look_weight
	var s := spring(_look, _look_velocity, target, 10.0, delta)
	_look = s[0]
	_look_velocity = s[1]
	for item: Array in [[&"Neck", 0.4], [&"Head", 0.6]]:
		var i: int = _index.get(item[0], -1)
		if i >= 0:
			rotations[i] = Quaternion(Vector3.UP, _look.x * item[1]) * Quaternion(Vector3.RIGHT, _look.y * item[1]) * rotations[i]


func _secondary_layer(rotations: Array[Quaternion], delta: float) -> void:
	var chest: int = _index.get(&"UpperChest", _index.get(&"Chest", -1))
	if chest < 0 or delta <= 0.0:
		return
	var chest_world := _world_rotation(rotations, chest)
	var spin := rotvec(chest_world * _last_chest.inverse()) / delta
	_last_chest = chest_world
	spin = spin.limit_length(20.0)
	for k in SECONDARY.size():
		var i: int = _index.get(SECONDARY[k], -1)
		if i < 0:
			continue
		# Driven by the chest's spin: the bone lags behind, then catches up.
		var drive := -spin * (0.012 if SECONDARY[k] == &"Head" else 0.02)
		var s := spring(_secondary[k], _secondary_velocity[k], drive, secondary_frequency, delta)
		_secondary[k] = (s[0] as Vector3).limit_length(0.5)
		_secondary_velocity[k] = s[1]
		rotations[i] = from_rotvec(_secondary[k]) * rotations[i]


func _flinch_layer(rotations: Array[Quaternion], delta: float) -> void:
	var s := spring(_flinch, _flinch_velocity, Vector3.ZERO, flinch_frequency, delta)
	_flinch = (s[0] as Vector3).limit_length(0.9)
	_flinch_velocity = s[1]
	for item: Array in [[&"Spine", 0.3], [&"Chest", 0.4], [&"Neck", 0.3], [&"Head", 0.4]]:
		var i: int = _index.get(item[0], -1)
		if i >= 0:
			rotations[i] = from_rotvec(_flinch * item[1]) * rotations[i]


func _landing_layer(rotations: Array[Quaternion], hips: Vector3, delta: float) -> Vector3:
	var s := spring(_landing, _landing_velocity, 0.0, 12.0, delta)
	_landing = clampf(s[0], -0.25, 0.1)
	_landing_velocity = s[1]
	for item: Array in [[&"LeftUpperArm", 1.0], [&"RightUpperArm", -1.0]]:
		var i: int = _index.get(item[0], -1)
		if i >= 0:
			rotations[i] = Quaternion(Vector3.BACK, _landing * 1.2 * item[1]) * rotations[i]
	return hips + Vector3(0, _landing, 0)


func _foot_ik(rotations: Array[Quaternion], hips: Vector3) -> Vector3:
	var hips_id: int = _index.get(&"Hips", -1)
	if hips_id < 0 or flying:
		return hips
	_world_cache.clear()
	var world := _legs_world(rotations, hips)
	var heights := [ground.x, ground.y]
	var targets: Array[Vector3] = []
	var drop := 0.0
	for side in 2:
		var up: int = _index.get(LEGS[side][0], -1)
		var lo: int = _index.get(LEGS[side][1], -1)
		var foot: int = _index.get(LEGS[side][2], -1)
		if up < 0 or lo < 0 or foot < 0:
			targets.append(Vector3.INF)
			continue
		var ankle: Vector3 = (world[foot] as Transform3D).origin
		var rest_y := _rest_heights[foot]
		# A foot near the floor is planted: it follows the ground; others only stay above it.
		var target := ankle
		if ankle.y < rest_y + PLANTED_HEIGHT:
			target.y = ankle.y + heights[side]
		target.y = maxf(target.y, heights[side] + rest_y)
		targets.append(target)
		var reach := (_origins[lo].length() + _origins[foot].length()) * 0.999
		var hip: Vector3 = (world[up] as Transform3D).origin
		var horizontal := Vector2(target.x - hip.x, target.z - hip.z).length()
		var need := sqrt(maxf(reach * reach - horizontal * horizontal, 0.0))
		drop = maxf(drop, (hip.y - target.y) - need)
	hips.y -= clampf(drop, 0.0, MAX_PELVIS_DROP)
	_world_cache.clear()
	world = _legs_world(rotations, hips)
	for side in 2:
		if targets[side] == Vector3.INF:
			continue
		var foot: int = _index.get(LEGS[side][2], -1)
		if (world[foot] as Transform3D).origin.is_equal_approx(targets[side]):
			continue
		_two_bone(rotations, world, _index[LEGS[side][0]], _index[LEGS[side][1]], foot, targets[side])
		_world_cache.clear()
		world = _legs_world(rotations, hips)
	return hips


## World transforms of the hips and both legs only (sparse), for the foot IK.
func _legs_world(rotations: Array[Quaternion], hips: Vector3) -> Array:
	var out := []
	out.resize(_names.size())
	for leg: Array in LEGS:
		for bone: StringName in leg:
			var i: int = _index.get(bone, -1)
			if i >= 0:
				out[i] = _world_at(rotations, hips, i)
				if _parents[i] >= 0 and out[_parents[i]] == null:
					out[_parents[i]] = _world_at(rotations, hips, _parents[i])
	return out


func _two_bone(rotations: Array[Quaternion], world: Array, up: int, lo: int, foot: int, target: Vector3) -> void:
	var h: Transform3D = world[up]
	var k: Transform3D = world[lo]
	var a: Transform3D = world[foot]
	var l1 := h.origin.distance_to(k.origin)
	var l2 := k.origin.distance_to(a.origin)
	var to := target - h.origin
	var d := clampf(to.length(), absf(l1 - l2) + 0.001, (l1 + l2) * 0.9999)
	var u := to.normalized()
	var perp := (k.origin - h.origin) - u * (k.origin - h.origin).dot(u)
	var v := perp.normalized() if perp.length() > 1e-5 else Vector3.FORWARD
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var knee := h.origin + l1 * (cos_a * u + sqrt(1.0 - cos_a * cos_a) * v)
	var ankle := h.origin + u * d
	var r1 := Quaternion((k.origin - h.origin).normalized(), (knee - h.origin).normalized())
	var thigh_world := r1 * h.basis.get_rotation_quaternion()
	var r2 := Quaternion((r1 * (a.origin - k.origin)).normalized(), (ankle - knee).normalized())
	var shin_world := r2 * r1 * k.basis.get_rotation_quaternion()
	var parent_world := (world[_parents[up]] as Transform3D).basis.get_rotation_quaternion()
	rotations[up] = parent_world.inverse() * thigh_world
	rotations[lo] = thigh_world.inverse() * shin_world
	rotations[foot] = shin_world.inverse() * a.basis.get_rotation_quaternion()


func _world(rotations: Array[Quaternion], hips: Vector3) -> Array:
	var out := []
	out.resize(_names.size())
	for i in _names.size():
		var origin: Vector3 = hips if _names[i] == &"Hips" else _origins[i]
		var local := Transform3D(Basis(rotations[i]), origin)
		out[i] = local if _parents[i] < 0 else (out[_parents[i]] as Transform3D) * local
	return out


func _world_rotation(rotations: Array[Quaternion], bone: int) -> Quaternion:
	var q := rotations[bone]
	var i := _parents[bone]
	while i >= 0:
		q = rotations[i] * q
		i = _parents[i]
	return q
