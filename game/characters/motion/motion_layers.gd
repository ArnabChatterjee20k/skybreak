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
## Arm poses for held weapons; each hand target is in chest space (+Y up, +Z forward, +X left).
enum ArmPose { NONE, TWO_HANDED, BOW_DRAW, PISTOL_AIM }
const ARM_POSES := {
	# Two-handed: the left hand grips the haft just below the right hand (offset from the right hand).
	ArmPose.TWO_HANDED: {&"LeftHand": Vector3(0.03, -0.16, -0.02)},
	ArmPose.BOW_DRAW: {&"LeftHand": Vector3(0.12, 0.22, 0.62), &"RightHand": Vector3(-0.06, 0.26, 0.12)},
	ArmPose.PISTOL_AIM: {&"RightHand": Vector3(-0.08, 0.22, 0.62)},
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
	_inertialize(rotations, delta)
	hips = _inertialize_hips(hips, delta)
	_lean_layer(rotations, delta)
	_flight_layer(rotations, delta)
	_look_layer(rotations, delta)
	_secondary_layer(rotations, delta)
	_flinch_layer(rotations, delta)
	hips = _landing_layer(rotations, hips, delta)
	_arm_layer(rotations, hips, delta)
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


## Held-weapon arm pose: two-bone IK of the hands to chest-space targets, blended by weight.
func _arm_layer(rotations: Array[Quaternion], hips: Vector3, delta: float) -> void:
	if arm_pose != ArmPose.NONE:
		_arm_pose_now = arm_pose
	var s := spring(_arm, _arm_velocity, arm_weight if arm_pose != ArmPose.NONE else 0.0, 14.0, delta)
	_arm = clampf(s[0], 0.0, 1.0)
	_arm_velocity = s[1]
	if _arm < 0.01 or not ARM_POSES.has(_arm_pose_now):
		return
	var chest: int = _index.get(&"UpperChest", _index.get(&"Chest", -1))
	if chest < 0:
		return
	var targets: Dictionary = ARM_POSES[_arm_pose_now]
	_world_cache.clear()
	var chest_world := _world_at(rotations, hips, chest)
	for chain: Array in ARMS:
		if not targets.has(chain[2]):
			continue
		var up: int = _index.get(chain[0], -1)
		var lo: int = _index.get(chain[1], -1)
		var hand: int = _index.get(chain[2], -1)
		if up < 0 or lo < 0 or hand < 0:
			continue
		var before := [rotations[up], rotations[lo], rotations[hand]]
		var world := _chain_world(rotations, hips, [up, lo, hand])
		var target: Vector3 = chest_world * (targets[chain[2]] as Vector3)
		if _arm_pose_now == ArmPose.TWO_HANDED:
			var right: int = _index.get(&"RightHand", -1)
			if right < 0:
				continue
			target = _world_at(rotations, hips, right).origin + chest_world.basis.orthonormalized() * (targets[chain[2]] as Vector3)
		_two_bone(rotations, world, up, lo, hand, target)
		rotations[up] = (before[0] as Quaternion).slerp(rotations[up], _arm)
		rotations[lo] = (before[1] as Quaternion).slerp(rotations[lo], _arm)
		rotations[hand] = before[2]
		_world_cache.clear()


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
