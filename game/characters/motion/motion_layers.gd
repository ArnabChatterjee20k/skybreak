class_name MotionLayers
extends SkeletonModifier3D
## Procedural realism on top of any clip: lean into acceleration and velocity, a sprung
## superhero-flight body (pitch, bank, trailing legs, tucked or reaching arms, dash burst),
## hip/spine counter-rotation, look-at, critically damped secondary motion, two-bone foot IK with
## pelvis drop, additive hit flinches, per-weapon arm IK and inertialized clip switches.
## Last, a pop guard: forearm and upper-arm twist is unwrapped and limited, and no body bone turns
## faster than MAX_TURN_RATE, so retarget and IK flips never reach the screen.
## Everything is in skeleton space (+Y up, facing +Z). Set the inputs each frame; call
## inertialize() right before switching clips. Works on a Skeleton3D or, for tests, on arrays.

const SPINE := [&"Hips", &"Spine", &"Chest", &"UpperChest", &"Neck", &"Head"]
const LEGS := [[&"LeftUpperLeg", &"LeftLowerLeg", &"LeftFoot"], [&"RightUpperLeg", &"RightLowerLeg", &"RightFoot"]]
const SECONDARY := [&"Head", &"LeftUpperArm", &"RightUpperArm", &"LeftLowerArm", &"RightLowerArm"]
const MAX_LEAN := deg_to_rad(28.0)
const MAX_BANK := deg_to_rad(55.0)
const PLANTED_HEIGHT := 0.06
const MAX_PELVIS_DROP := 0.45
## A foot over ground this far below the planted one stays level with it (a step or ledge).
const STEP_LIMIT := 0.45
## Steepest slope the ankles tilt to match.
const MAX_ANKLE_TILT := deg_to_rad(35.0)
const ARMS := [[&"LeftUpperArm", &"LeftLowerArm", &"LeftHand"], [&"RightUpperArm", &"RightLowerArm", &"RightHand"]]
## Flight: speed (m/s) for the full flight body, and the flutter of the trailing legs.
const FLIGHT_FULL_SPEED := 22.0
## Level flight pitch limit; dives go on to the profile's dive_pitch (horizontal superman).
const MAX_FLIGHT_PITCH := deg_to_rad(78.0)
## Twist limits about the bone (radians) and the fastest any body bone may turn (rad/s).
const TWIST_LIMITS := {&"LeftLowerArm": 1.6, &"RightLowerArm": 1.6, &"LeftUpperArm": 1.8, &"RightUpperArm": 1.8}
const MAX_TURN_RATE := 54.0
## Inertialization never carries in more angular velocity than this (rad/s).
const MAX_BLEND_SPEED := 14.0
const FLUTTER_HZ := 2.4
## Arm poses for held weapons (T-D30), solved by two-bone IK on top of the clip.
enum ArmPose { NONE, TWO_HANDED, BOW_DRAW, PISTOL_AIM, GUARD, BRACED, SWING, BOW_LOW, SIDE, PISTOL_LOW }
## Main-hand grip point per pose, from its shoulder in chest space (+Y up, +Z forward, +X to the
## holder's left), in arm lengths, then the weapon's +Y and its forward (-Z) in the same space.
const ARM_POSES := {
	ArmPose.GUARD: [Vector3(-0.15, -0.62, 0.62), Vector3(-0.15, 0.8, 0.58), Vector3(0, -0.4, 1)],
	ArmPose.TWO_HANDED: [Vector3(0.2, -0.78, 0.55), Vector3(0.62, 0.62, 0.48), Vector3(0, 0, 1)],
	ArmPose.PISTOL_AIM: [Vector3(0.12, 0.02, 0.96), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	ArmPose.BRACED: [Vector3(-0.3, -0.62, 0.62), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	# A bow not drawn: held low and out at the side, limbs pointing ahead, never across the body.
	ArmPose.BOW_LOW: [Vector3(-0.45, -0.72, 0.4), Vector3(-0.25, 0.2, 1), Vector3(0, -1, 0)],
	# A pistol between shots: low ready, out in front, muzzle down the line.
	ArmPose.PISTOL_LOW: [Vector3(-0.2, -0.55, 0.65), Vector3(0, 1, 0.35), Vector3(0, -0.35, 1)],
	# A heavy weapon carried at the side in one hand, its head low and out.
	ArmPose.SIDE: [Vector3(-0.55, -0.85, 0.12), Vector3(-0.25, -1, 0.15), Vector3(0, 0, 1)],
}
## One-hand swing arc (from the shoulder, chest space, arm lengths): the hand sweeps from the
## weapon side across the front at this height and reach, as the attack runs (arm_phase 0..1).
const SWING_FROM := deg_to_rad(-55.0)
const SWING_TO := deg_to_rad(25.0)
const SWING_POINT := Vector3(0.0, -0.12, 0.97)
## Bow draw: the string hand anchors this far beside the head capsule's surface (m), at jaw height.
const BOW_ANCHOR_GAP := 0.13
const BOW_ANCHOR_DROP := 0.04
## Bow cant (sideways lean of its top per unit up) and the shortest bow-hand distance from the anchor (m).
const BOW_CANT := 0.12
const BOW_MIN_DRAW := 0.3
## Arm weight from which the drawn string shows (before it the string hand is still on its way).
const BOW_SHOWN_WEIGHT := 0.95
## Spring frequency (1/s) of the arm weight while drawing a bow.
const BOW_DRAW_FREQUENCY := 24.0
## Torso turn (radians) toward the bow side at full draw.
const BOW_TWIST := deg_to_rad(70.0)
## Clearance solver: passes, and the margin it leaves (m).
const CLEARANCE_PASSES := 16
const CLEARANCE_MARGIN := 0.03
## Swing correction: largest turn of the weapon about the wrist per pass, and the shortest lever it acts on.
const SWING_STEP := 0.35
const SWING_MIN_LEVER := 0.12
## Capsules a held weapon must stay out of, per main hand (its own forearm and hand grip it).
const CLEAR_OF := {
	&"RightHand": [&"pelvis", &"chest", &"head", &"upper_arm_l", &"lower_arm_l", &"upper_arm_r"],
	&"LeftHand": [&"pelvis", &"chest", &"head", &"upper_arm_l", &"upper_arm_r", &"lower_arm_r"],
}

# Hips as posed this frame before the pop guard (its hand fix-up works from them).
var _last_hips_now := Vector3.ZERO
## Core body capsules: never drawn inside another fighter's core (T-D30c). Limbs may meet.
const CORE: Array[StringName] = [&"pelvis", &"chest", &"head", &"thigh_l", &"thigh_r"]
## Gap left between two cores when the body steps back out of a rival's (m), and separation passes.
const SEPARATION_MARGIN := 0.03
const SEPARATION_PASSES := 3
## Rivals whose pelvis is farther than this (m) are not checked.
const SEPARATION_REACH := 3.0
## Other fighters' layers whose drawn core this body keeps out of (set by the match).
var rivals: Array = []
## Whether this body keeps out of its rivals (off while vanishing or in a grab pair).
var separate := true
## Mid-attack (startup, active, recovery): this fighter's limbs may meet its rivals.
var striking := false
## World body capsules as posed before separation, from the last frame: what rivals keep out of.
var body_capsules := {}
## Weapon hold points pushed forward and out (arm lengths; MotionProfile).
var hold_forward := 0.0
var hold_out := 0.0
## Fighter velocity in skeleton space (m/s).
@export var velocity := Vector3.ZERO
@export var flying := false
## Point to look at in skeleton space; null-like when look_weight is 0.
@export var look_target := Vector3(0, 1.5, 5)
@export_range(0.0, 1.0) var look_weight := 0.0
@export var foot_ik := true
## Ground height under each foot in skeleton space (left, right), when there is no probe.
@export var ground := Vector2.ZERO
## Ground under a skeleton-space point: Callable(point) -> [height, normal], both in skeleton space.
var ground_probe: Callable
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
## Progress through the attack for the swing arc (0..1).
var arm_phase := 0.0
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
## Hips lowered in grounded poses (m, from the profile); the foot IK bends the knees.
@export var crouch := 0.0
## Personality multipliers (see MotionProfile).
var secondary_scale := 1.0
var flinch_scale := 1.0
var landing_scale := 1.0
var hover_bob := 0.02
var hover_bob_hz := 0.5
var flight_arm_scale := 1.0
var dive_pitch := deg_to_rad(95.0)

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
# Hips after the clip and its inertial blend, before the other layers, last frame.
var _inertial_hips := Vector3.ZERO
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
var _crouch := 0.0
var _crouch_velocity := 0.0
var _bob_phase := 0.0
var _twists := {}
var _poles := {}
var _rest_rot: Array[Quaternion] = []
# Each bone's rest rotation in skeleton space (rigs differ in their bones' own axes).
var _rest_world_rot: Array[Quaternion] = []
var _bone_axis: Array[Vector3] = []
# Pop guard: per body bone (index into _used), its body parent's index (-1: none) and world rotations.
var _used_parent: PackedInt32Array = []
var _guard_world: Array[Quaternion] = []
var _guard_world_now: Array[Quaternion] = []
var _world_cache: Array = []
var _rest_parent_rot: Array[Quaternion] = []
var _sole_cache: Array = []
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
	_rest_rot.clear()
	_rest_world_rot.clear()
	_bone_axis.clear()
	for i in names.size():
		_rest_rot.append(rests[i].basis.get_rotation_quaternion())
		_rest_world_rot.append(world[i].basis.get_rotation_quaternion())
		_bone_axis.append(Vector3.UP)
	for i in names.size():
		if parents[i] >= 0 and rests[i].origin.length() > 1e-4 and _bone_axis[parents[i]] == Vector3.UP:
			_bone_axis[parents[i]] = rests[i].origin.normalized()
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
	_used_parent.clear()
	for k in _used.size():
		var p := parents[_used[k]]
		while p >= 0 and not _used.has(p):
			p = parents[p]
		var parent_k := _used.find(p) if p >= 0 else -1
		# Parents come first in a skeleton; anything else is treated as a root.
		_used_parent.append(parent_k if parent_k < k else -1)
	_guard_world_now.resize(_used.size())
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
	_crouch = 0.0
	_crouch_velocity = 0.0
	_twists.clear()
	_poles.clear()
	_guard_world.clear()


## Takes a legend's motion personality.
func apply_profile(profile: MotionProfile) -> void:
	accel_lean = 0.03 * profile.lean_scale
	velocity_lean = 0.012 * profile.lean_scale
	lean_frequency = profile.lean_frequency
	secondary_frequency = profile.secondary_frequency
	secondary_scale = profile.secondary_scale
	blend_frequency = profile.blend_frequency
	flinch_frequency = profile.flinch_frequency
	flinch_scale = profile.flinch_scale
	landing_scale = profile.landing_scale
	hover_bob = profile.hover_bob
	hover_bob_hz = profile.hover_bob_hz
	flight_arm_scale = profile.flight_arm_scale
	dive_pitch = deg_to_rad(profile.dive_pitch)
	hold_forward = profile.hold_forward
	hold_out = profile.hold_out


## Blend from the last output pose into whatever the next clip gives, without a linear crossfade.
func inertialize() -> void:
	_pending_blend = not _last_out.is_empty()


## Additive hit flinch: the upper body snaps away from direction (skeleton space), then recovers.
func flinch(direction: Vector3, strength := 1.0) -> void:
	var axis := Vector3.UP.cross(direction.normalized())
	_flinch_velocity += axis * strength * flinch_scale * 9.0


## Landing: knees and arms absorb it (strength 1 = a normal landing).
func land(strength := 1.0) -> void:
	_landing_velocity -= strength * landing_scale * 2.5


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
	hips = _stance_layer(hips, delta)
	_clearance(rotations, hips)
	hips = _separation(rotations, hips)
	if foot_ik:
		hips = _foot_ik(rotations, hips)
	_last_hips_now = hips
	_twist_guard(rotations)
	# The twist limits can bring the weapon back into the body: clear it once more, before the turn cap.
	_clearance(rotations, hips)
	_pop_guard(rotations, delta)
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
				_offset_velocity[i] = (rotvec(_last_out[i] * _prev_out[i].inverse()) / _last_delta).limit_length(MAX_BLEND_SPEED)
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
	# Blend from last frame's hips before the later layers (crouch, landing, foot IK, separation)
	# moved them: those run again on top, so taking them in here stacks them on every restart.
	if is_inf(_hips_offset.x):
		_hips_offset = _inertial_hips - hips
		_inertial_hips = hips + _hips_offset
		return _inertial_hips
	if _hips_offset != Vector3.ZERO:
		var s := spring(_hips_offset, _hips_offset_velocity, Vector3.ZERO, blend_frequency, delta)
		_hips_offset = s[0]
		_hips_offset_velocity = s[1]
	_inertial_hips = hips + _hips_offset
	return _inertial_hips


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
		var diving := clampf((-velocity.y - 6.0) / 14.0, 0.0, 1.0)
		target.x = clampf(velocity.z * 0.045 - velocity.y * 0.03 + speed * 0.012 + diving * 0.45 + _burst * 0.5,
			-MAX_LEAN, lerpf(MAX_FLIGHT_PITCH, dive_pitch, diving))
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
		var twist := _yaw_of(rotations[hips])
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
	var forward := clampf((velocity.z - 14.0) / 8.0, 0.0, 1.0) if flying else 0.0
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
	# Legs: eased toward the straight rest pose (whatever the take's knee bend on this rig), then in
	# line with the body, knees soft, alternating flutter; the burst pulls them together.
	for leg: Array in LEGS:
		for k in 2:
			var i: int = _index.get(leg[k], -1)
			if i >= 0:
				rotations[i] = rotations[i].slerp(_rest_rot[i], clampf(f * (0.55 if k == 0 else 0.8) + b * 0.3, 0.0, 1.0))
	_offset(rotations, &"LeftUpperLeg", Vector3(0.22 * f + flutter - 0.1 * b, 0, -0.05 * f))
	_offset(rotations, &"RightUpperLeg", Vector3(0.22 * f - flutter - 0.1 * b, 0, 0.05 * f))
	_offset(rotations, &"LeftLowerLeg", Vector3(0.08 * f + flutter * 1.5 + 0.1 * b, 0, 0))
	_offset(rotations, &"RightLowerLeg", Vector3(0.2 * f - flutter * 1.5 + 0.1 * b, 0, 0))
	_offset(rotations, &"LeftFoot", Vector3(0.45 * f, 0, 0))
	_offset(rotations, &"RightFoot", Vector3(0.45 * f, 0, 0))
	# Arms: tucked back along the body at speed; the lead (right) arm reaches ahead in a dive.
	var a := flight_arm_scale
	var tuck := (f * (1.0 - _reach) + b) * a
	var reach := _reach * f * a
	# Both arms swept back along the body at speed (read from the game camera), the lead arm
	# punched straight ahead in a dive: the superman line. The burst snaps them all the way back.
	_offset(rotations, &"LeftUpperArm", Vector3(0.9 * tuck + 0.35 * reach, 0, -0.55 * tuck))
	_offset(rotations, &"RightUpperArm", Vector3(0.9 * tuck * (1.0 - _reach) - 2.8 * reach, 0, 0.55 * tuck - 0.25 * reach))
	_offset(rotations, &"RightLowerArm", Vector3(0.75 * reach, 0, 0))
	_offset(rotations, &"LeftLowerArm", Vector3(0.45 * tuck, 0, 0))
	_offset(rotations, &"Chest", Vector3(-0.12 * b, 0, 0))
	# Head stays up, looking where it flies.
	_offset(rotations, &"Neck", Vector3(-0.3 * f - 0.15 * b, 0, 0))
	_offset(rotations, &"Head", Vector3(-0.35 * f, 0, 0))


## Held-weapon arm pose: the main hand to its grip point with the weapon turned to the pose,
## the off hand onto the weapon's off-hand grip; bows draw the string to beside the face.
## How far the bow anchor slides back behind the ear for an arm too short to reach a full draw (m).
var _bow_pull_back := 0.0


func _arm_layer(rotations: Array[Quaternion], hips: Vector3, delta: float) -> void:
	if arm_pose != ArmPose.NONE:
		_arm_pose_now = arm_pose
	# A bow draw comes up faster, so the string hand spends little time on its way to the anchor.
	var frequency := BOW_DRAW_FREQUENCY if arm_pose == ArmPose.BOW_DRAW else 14.0
	var s := spring(_arm, _arm_velocity, arm_weight if arm_pose != ArmPose.NONE else 0.0, frequency, delta)
	_arm = clampf(s[0], 0.0, 1.0)
	_arm_velocity = s[1]
	if _arm < 0.01 or _arm_pose_now == ArmPose.NONE or weapon_hand == &"":
		return
	var chest: int = _index.get(&"UpperChest", _index.get(&"Chest", -1))
	var main: int = _index.get(weapon_hand, -1)
	if chest < 0 or main < 0:
		return
	_world_cache.clear()
	# The chest's turn from rest, in the model's axes (+Y up, +Z forward), whatever the rig's bone axes.
	var frame := Basis(_world_at(rotations, hips, chest).basis.get_rotation_quaternion() * _rest_world_rot[chest].inverse())
	var main_chain := _arm_chain(weapon_hand)
	if main_chain.is_empty():
		return
	if _arm_pose_now == ArmPose.BOW_DRAW:
		_archer_stance(rotations, _arm)
		_world_cache.clear()
	var shoulder := _world_at(rotations, hips, main_chain[0]).origin
	var reach := _arm_length(main_chain)
	var grip := weapon_grip.orthonormalized()
	var goal_point: Vector3
	var goal_basis: Basis
	if _arm_pose_now == ArmPose.BOW_DRAW:
		var anchor := _bow_anchor(rotations, hips, frame)
		# Bow hand on the line from the anchor straight toward the target, at the arm's reach.
		var aim := frame * Vector3(0, 0, 1)
		var to_anchor := anchor - shoulder
		var r := reach * 0.97
		var b := to_anchor.dot(aim)
		var d := -b + sqrt(maxf(b * b - to_anchor.length_squared() + r * r, 0.0))
		# A short arm (chibi or bulky build) cannot reach a full draw: the anchor slides back past the ear.
		_bow_pull_back = maxf(BOW_MIN_DRAW + 0.02 - d, 0.0)
		goal_point = anchor + aim * maxf(d, BOW_MIN_DRAW - _bow_pull_back)
		anchor += _bow_pull_offset(frame)
		var forward := (goal_point - anchor).normalized()
		# The bow cants its top away from the head.
		var side := -1.0 if weapon_hand == &"LeftHand" else 1.0
		var up := (frame * Vector3(side * BOW_CANT, 1, 0)).normalized()
		goal_basis = _weapon_basis(up, forward)
	elif _arm_pose_now == ArmPose.SWING:
		# Authored for the right hand (sweeping from its side); a left hand mirrors.
		var mirror := Vector3(-1, 1, 1) if weapon_hand == &"LeftHand" else Vector3.ONE
		var yaw := lerpf(SWING_FROM, SWING_TO, clampf(arm_phase, 0.0, 1.0))
		var out := Basis(Vector3.UP, yaw) * SWING_POINT
		goal_point = shoulder + frame * (out * mirror * reach)
		var outward := (frame * (out * mirror)).normalized()
		goal_basis = _weapon_basis((frame * Vector3.UP * 0.5 + outward).normalized(), outward)
	elif ARM_POSES.has(_arm_pose_now):
		var pose: Array = ARM_POSES[_arm_pose_now]
		# Poses are authored for the right hand; a left main hand mirrors them.
		var mirror := Vector3(-1, 1, 1) if weapon_hand == &"LeftHand" else Vector3.ONE
		var point := (pose[0] as Vector3) + Vector3(-hold_out, 0, hold_forward)
		goal_point = shoulder + frame * (point * mirror * reach)
		goal_basis = _weapon_basis(frame * ((pose[1] as Vector3) * mirror).normalized(), frame * (pose[2] as Vector3).normalized())
	else:
		return
	var hand_basis := goal_basis * grip.basis.inverse()
	var hand_point := goal_point - hand_basis * grip.origin
	_reach_hand(rotations, hips, main_chain, hand_point, hand_basis.get_rotation_quaternion(), _arm)
	if _arm_pose_now == ArmPose.BOW_DRAW:
		var anchor := _bow_anchor(rotations, hips, frame) + _bow_pull_offset(frame)
		var string_chain := _arm_chain(&"RightHand" if weapon_hand == &"LeftHand" else &"LeftHand")
		if not string_chain.is_empty():
			_world_cache.clear()
			var bow := _world_at(rotations, hips, main_chain[2]) * weapon_grip
			var pull := (anchor - bow.origin).normalized()
			var palm := _weapon_basis(frame * Vector3.UP, -pull).orthonormalized()
			# The palm (where the string sits), not the wrist, goes to the anchor.
			var wrist := anchor - palm * off_hand_socket.origin
			_reach_hand(rotations, hips, string_chain, wrist, palm.get_rotation_quaternion(), _arm)
	elif _arm_pose_now != ArmPose.SIDE:
		_grip_off_hand(rotations, hips, _arm)


## Where a short-armed draw moves the anchor: back along the draw and out, away from the head.
func _bow_pull_offset(frame: Basis) -> Vector3:
	var side := -1.0 if weapon_hand == &"LeftHand" else 1.0
	return frame * Vector3(side * _bow_pull_back * 0.6, 0, -_bow_pull_back)


## True once a bow draw has fully arrived: the string hand is at the anchor beside the face.
func bow_at_anchor() -> bool:
	return _arm_pose_now == ArmPose.BOW_DRAW and arm_pose == ArmPose.BOW_DRAW and _arm >= BOW_SHOWN_WEIGHT


## Archer's stance: the torso turns bow shoulder toward the target, the neck and head turn
## back to face it, so the bow arm reaches the line that runs beside the face.
func _archer_stance(rotations: Array[Quaternion], weight: float) -> void:
	var turn := BOW_TWIST * weight * (-1.0 if weapon_hand == &"LeftHand" else 1.0)
	for bone: StringName in [&"Spine", &"Chest", &"UpperChest"]:
		_offset(rotations, bone, Vector3(0, turn / 3.0, 0))
	_offset(rotations, &"Neck", Vector3(0, -turn * 0.5, 0))
	_offset(rotations, &"Head", Vector3(0, -turn * 0.5, 0))


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
		var depth := float(hit[0]) + CLEARANCE_MARGIN
		# Swing: turn the weapon about the wrist so the overlapping part moves out along the push,
		# then move the hand for whatever the swing did not clear.
		# Lever: the overlapping part's centre, or the contact point when that centre is at the wrist.
		var lever: Vector3 = (hit[4] as Vector3) - hand.origin
		if lever.length() <= SWING_MIN_LEVER:
			lever = (hit[3] as Vector3) - hand.origin
		var hand_rotation := hand.basis.get_rotation_quaternion()
		var moved := 0.0
		var axis := lever.cross(push)
		if lever.length() > SWING_MIN_LEVER and axis.length() > 1e-4:
			var angle := minf(depth / lever.length(), SWING_STEP)
			hand_rotation = Quaternion(axis.normalized(), angle) * hand_rotation
			moved = angle * lever.length() * axis.length() / lever.length()
		var target := hand.origin + push * maxf(depth - moved, CLEARANCE_MARGIN)
		_reach_hand(rotations, hips, main, target, hand_rotation, 1.0)
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
		var drive := -spin * (0.012 if SECONDARY[k] == &"Head" else 0.02) * secondary_scale
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


## Grounded crouch (sprung, so take-offs and landings ease in and out) and the slow hover bob.
func _stance_layer(hips: Vector3, delta: float) -> Vector3:
	var s := spring(_crouch, _crouch_velocity, 0.0 if flying else crouch, 10.0, delta)
	_crouch = s[0]
	_crouch_velocity = s[1]
	hips.y -= _crouch
	if flying:
		_bob_phase = fmod(_bob_phase + delta * TAU * hover_bob_hz, TAU)
		hips.y += sin(_bob_phase) * hover_bob * (1.0 - _flight)
	return hips


## Steps the drawn body back (hips, level) until it is out of every rival's: cores never meet, nor
## do limbs, except a striking fighter's (they may reach the target). Measured against the rivals'
## unseparated bodies so two fighters never chase each other. The feet re-plant after.
func _separation(rotations: Array[Quaternion], hips: Vector3) -> Vector3:
	var skeleton := get_skeleton()
	if skeleton == null or body == null or rivals.is_empty() or not skeleton.is_inside_tree():
		body_capsules = {}
		return hips
	var space := skeleton.global_transform
	_world_cache.clear()
	body_capsules = body.capsules(func(bone: int) -> Transform3D: return _world_at(rotations, hips, bone), space)
	_world_cache.clear()
	if not separate:
		return hips
	var centre: Vector3 = body_capsules.get(&"pelvis", [space.origin])[0]
	var shift := Vector3.ZERO
	for pass_index in SEPARATION_PASSES:
		var deepest := 0.0
		var push := Vector3.ZERO
		for rival: MotionLayers in rivals:
			if not is_instance_valid(rival) or not rival.separate or rival.body_capsules.is_empty():
				continue
			if (rival.body_capsules.get(&"pelvis", [centre])[0] as Vector3).distance_to(centre + shift) > SEPARATION_REACH:
				continue
			for a: StringName in body_capsules:
				if striking and not CORE.has(a):
					continue
				var mine: Array = body_capsules[a]
				var from: Vector3 = mine[0] + shift
				var to: Vector3 = mine[1] + shift
				for b: StringName in rival.body_capsules:
					if rival.striking and not CORE.has(b):
						continue
					var theirs: Array = rival.body_capsules[b]
					var closest := Geometry3D.get_closest_points_between_segments(from, to, theirs[0], theirs[1])
					var depth := float(mine[2]) + float(theirs[2]) + SEPARATION_MARGIN - closest[0].distance_to(closest[1])
					if depth <= deepest:
						continue
					var away: Vector3 = closest[0] - closest[1]
					away.y = 0.0
					if away.length_squared() < 1e-8:
						away = Vector3(from.x + to.x - theirs[0].x - theirs[1].x, 0.0, from.z + to.z - theirs[0].z - theirs[1].z)
					if away.length_squared() < 1e-8:
						continue
					deepest = depth
					push = away.normalized() * depth
		if deepest <= 0.0:
			break
		shift += push
	if shift == Vector3.ZERO:
		return hips
	# Into the hips' parent space, from the skeleton's own pose of that parent (it may sit outside the body bones).
	var hips_id: int = _index.get(&"Hips", -1)
	var parent: int = _parents[hips_id] if hips_id >= 0 else -1
	var to_local := space.basis.inverse()
	if parent >= 0:
		to_local = skeleton.get_bone_global_pose(parent).basis.inverse() * to_local
	return hips + to_local * shift


## Yaw of a rotation about +Y (swing-twist, stable at any pitch, unlike Euler angles).
static func _yaw_of(q: Quaternion) -> float:
	var twist := Vector2(q.w, q.y)
	if twist.length_squared() < 1e-10:
		return 0.0
	return wrapf(2.0 * atan2(q.y, q.w), -PI, PI)


## Unwraps and limits arm twist; hands posed by the weapon IK keep their world rotation.
func _twist_guard(rotations: Array[Quaternion]) -> void:
	# Hands posed by the weapon IK keep their world rotation: the wrist takes the twist the arm gives up.
	var held := {}
	if _arm > 0.01 and weapon_hand != &"":
		for hand: StringName in [&"LeftHand", &"RightHand"]:
			var i: int = _index.get(hand, -1)
			if i >= 0:
				_world_cache.clear()
				held[i] = _world_at(rotations, _last_hips_now, i).basis.get_rotation_quaternion()
	for bone: StringName in TWIST_LIMITS:
		var i: int = _index.get(bone, -1)
		if i >= 0:
			rotations[i] = _limit_twist(i, rotations[i], TWIST_LIMITS[bone])
	for i: int in held:
		_world_cache.clear()
		var parent := _world_at(rotations, _last_hips_now, _parents[i]).basis.get_rotation_quaternion()
		rotations[i] = parent.inverse() * (held[i] as Quaternion)
	_world_cache.clear()


## Caps how far any body bone turns per frame in model space
## (parents first, so a child's limit accounts for what its parent already did): no pops.
func _pop_guard(rotations: Array[Quaternion], delta: float) -> void:
	if _last_out.size() != rotations.size() or delta <= 0.0:
		_guard_world.clear()
		return
	var step := MAX_TURN_RATE * delta
	var count := _used.size()
	if _guard_world.size() != count:
		_guard_world.resize(count)
		for k in count:
			var p := _used_parent[k]
			_guard_world[k] = _last_out[_used[k]] if p < 0 else _guard_world[p] * _last_out[_used[k]]
	# World rotations relative to the nearest ancestor outside the body (which the layers never turn).
	for k in count:
		var i := _used[k]
		var p := _used_parent[k]
		var world := rotations[i] if p < 0 else _guard_world_now[p] * rotations[i]
		var last := _guard_world[k]
		if last.dot(world) < 0.0:
			world = -world
		var angle := last.angle_to(world)
		if angle > step:
			world = last.slerp(world, step / angle).normalized()
			rotations[i] = world if p < 0 else (_guard_world_now[p].inverse() * world).normalized()
		_guard_world_now[k] = world
	var swap := _guard_world
	_guard_world = _guard_world_now
	_guard_world_now = swap


## A bone's local rotation with its twist about the bone (away from rest) unwrapped against the
## last frame and clamped to limit.
func _limit_twist(i: int, q: Quaternion, limit: float) -> Quaternion:
	var rest := _rest_rot[i]
	var local := rest.inverse() * q
	var axis := _bone_axis[i]
	var projected := axis * Vector3(local.x, local.y, local.z).dot(axis)
	var twist := Quaternion(projected.x, projected.y, projected.z, local.w)
	if twist.length_squared() < 1e-10:
		return q
	twist = twist.normalized()
	var swing := local * twist.inverse()
	var angle := 2.0 * atan2(Vector3(twist.x, twist.y, twist.z).dot(axis), twist.w)
	var previous: float = _twists.get(i, 0.0)
	angle = previous + wrapf(angle - previous, -PI, PI)
	angle = clampf(angle, -limit, limit)
	_twists[i] = angle
	return rest * swing * Quaternion(axis, angle)


func _foot_ik(rotations: Array[Quaternion], hips: Vector3) -> Vector3:
	var hips_id: int = _index.get(&"Hips", -1)
	if hips_id < 0 or flying:
		return hips
	_world_cache.clear()
	var world := _legs_world(rotations, hips)
	var feet: Array = []
	for side in 2:
		feet.append(_foot_contact(rotations, hips, world, side))
	var targets: Array[Vector3] = [Vector3.INF, Vector3.INF]
	# A foot over ground more than a step from the floor under the body (a ledge, a wall, a notch)
	# moves in toward the body until it is over ground it can stand on.
	if ground_probe.is_valid():
		var centre: float = _ground_under(Vector3(hips.x, 0.0, hips.z), 0)[0]
		for side in 2:
			var foot: Dictionary = feet[side]
			if foot.is_empty() or absf(float(foot.ground) - centre) <= STEP_LIMIT:
				continue
			var sole: Vector3 = foot.sole_point
			var inward := Vector3(hips.x - sole.x, 0.0, hips.z - sole.z)
			for k in range(1, 5):
				var shift := inward * (k / 4.0)
				var ground_y: float = _ground_under(sole + shift, side)[0]
				if absf(ground_y - centre) <= STEP_LIMIT or k == 4:
					foot.shift = shift
					foot.ground = ground_y
					foot.gap = float(foot.sole) - ground_y
					break
	# The foot nearest its ground is planted on it; the other plants if close, else stays above.
	var lowest := -1
	for side in 2:
		if not feet[side].is_empty() and (lowest < 0 or feet[side].gap < feet[lowest].gap):
			lowest = side
	if lowest < 0:
		return hips
	var planted_floor: float = feet[lowest].ground
	for side in 2:
		var foot: Dictionary = feet[side]
		if foot.is_empty():
			continue
		var ankle: Vector3 = foot.ankle
		var target := ankle + (foot.shift as Vector3)
		var ground_y: float = foot.ground
		# Still over a drop past the step limit: keep the foot level with the planted one, not lower.
		if side != lowest and ground_y < planted_floor - STEP_LIMIT:
			ground_y = planted_floor + 0.01
		var gap: float = foot.sole - ground_y
		# Planted: the lowest foot, a foot the clip has on its floor (y = 0), or one at or under the ground.
		if side == lowest or gap < PLANTED_HEIGHT or float(foot.sole) < PLANTED_HEIGHT:
			target.y = ankle.y - gap
		targets[side] = target
	var drop := 0.0
	for side in 2:
		if targets[side] == Vector3.INF:
			continue
		var up: int = _index[LEGS[side][0]]
		var lo: int = _index[LEGS[side][1]]
		var foot_bone: int = _index[LEGS[side][2]]
		var reach := (_origins[lo].length() + _origins[foot_bone].length()) * 0.995
		var hip: Vector3 = (world[up] as Transform3D).origin
		var horizontal := Vector2(targets[side].x - hip.x, targets[side].z - hip.z).length()
		var need := sqrt(maxf(reach * reach - horizontal * horizontal, 0.0))
		drop = maxf(drop, (hip.y - targets[side].y) - need)
	hips.y -= clampf(drop, 0.0, MAX_PELVIS_DROP)
	for side in 2:
		if targets[side] == Vector3.INF:
			continue
		_world_cache.clear()
		world = _legs_world(rotations, hips)
		var foot_bone: int = _index[LEGS[side][2]]
		# Ankle aligned to the surface: the clip's foot rotation tilted by the ground's slope.
		var tilt: Quaternion = feet[side].tilt
		var aligned := Transform3D(Basis(tilt * (world[foot_bone] as Transform3D).basis.get_rotation_quaternion()),
			(world[foot_bone] as Transform3D).origin)
		world[foot_bone] = aligned
		_two_bone(rotations, world, _index[LEGS[side][0]], _index[LEGS[side][1]], foot_bone, targets[side])
	_world_cache.clear()
	return hips


## One foot's contact: its ankle, lowest sole point (with the foot tilted to the ground),
## the ground under that sole and the sole's gap above it; empty without the leg's bones.
func _foot_contact(rotations: Array[Quaternion], hips: Vector3, world: Array, side: int) -> Dictionary:
	var up: int = _index.get(LEGS[side][0], -1)
	var lo: int = _index.get(LEGS[side][1], -1)
	var foot: int = _index.get(LEGS[side][2], -1)
	if up < 0 or lo < 0 or foot < 0:
		return {}
	var foot_world: Transform3D = world[foot]
	var ankle := foot_world.origin
	var probe := _ground_under(ankle, side)
	var normal: Vector3 = probe[1]
	var tilt := Quaternion(Vector3.UP, normal) if normal.angle_to(Vector3.UP) <= MAX_ANKLE_TILT \
		else Quaternion(Vector3.UP, Vector3.UP.slerp(normal, MAX_ANKLE_TILT / normal.angle_to(Vector3.UP)).normalized())
	# Lowest sole point once the foot is tilted to the ground (toes keep their clip bend).
	var sole := Vector3(ankle.x, ankle.y - _rest_heights[foot], ankle.z)
	var soles: Array = _soles(side)
	if not soles.is_empty():
		_world_cache.clear()
		var tilted := Transform3D(Basis(tilt), ankle) * Transform3D(Basis.IDENTITY, -ankle)
		var low := INF
		for item: Array in soles:
			var bone: int = item[0]
			var p := tilted * (_world_at(rotations, hips, bone) * (item[1] as Vector3))
			if p.y < low:
				low = p.y
				sole = p
	probe = _ground_under(sole, side)
	var ground_y: float = probe[0]
	return {"ankle": ankle, "sole": sole.y, "sole_point": sole, "ground": ground_y, "gap": sole.y - ground_y,
		"tilt": tilt, "shift": Vector3.ZERO}


## Ground height and normal under a skeleton-space point: the probe if set, else the flat ground.
func _ground_under(point: Vector3, side: int) -> Array:
	if ground_probe.is_valid():
		return ground_probe.call(point)
	return [ground.x if side == 0 else ground.y, Vector3.UP]


## Sole points of one side's foot and toes: [[bone, point in bone space], ...].
func _soles(side: int) -> Array:
	if body == null:
		return []
	if _sole_cache.size() != 2:
		_sole_cache = [[], []]
		for item: Array in body.soles:
			var name := String(_names[item[0]]) if int(item[0]) < _names.size() else ""
			(_sole_cache[0 if name.begins_with("Left") else 1] as Array).append(item)
	return _sole_cache[side]


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
	# Bend direction: the limb's own, but kept from the last solve while the limb is near straight
	# (there the perpendicular flips with noise and the elbow or knee would spin round).
	var pole: Vector3 = _poles.get(lo, perp if perp.length() > 1e-5 else Vector3.FORWARD)
	var straightness := clampf(perp.length() / (0.08 * l1), 0.0, 1.0)
	var bend := pole.lerp(perp.normalized() if perp.length() > 1e-5 else pole, straightness)
	bend -= u * bend.dot(u)
	var v := bend.normalized() if bend.length() > 1e-5 else Vector3.FORWARD
	_poles[lo] = v
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
