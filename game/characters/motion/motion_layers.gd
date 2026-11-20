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
const MAX_PELVIS_DROP := 0.25
## Grounding pass: how far the pelvis may shift to put the lowest sole on the ground (m), the
## steepest surface a planted foot tilts to, and how fast the shift eases out off the ground.
const MAX_GROUND_SHIFT := 0.45
const MAX_FOOT_TILT := deg_to_rad(25.0)
const SHIFT_RELEASE_FREQUENCY := 10.0
## Share of the full leg length the IK may straighten to (no locked or hyperextended knee).
const KNEE_REACH := 0.995
## Foot lock: a planted foot stays where it touched down (world) until the clip pulls it this far
## away (m), then steps back over the lock blend, lifted by STEP_LIFT of the distance left.
const LOCK_RELEASE := 0.22
const LOCK_BLEND_FREQUENCY := 16.0
const STEP_LIFT := 0.5
const ARMS := [[&"LeftUpperArm", &"LeftLowerArm", &"LeftHand"], [&"RightUpperArm", &"RightLowerArm", &"RightHand"]]
## Flight: speed (m/s) for the full flight body, and the flutter of the trailing legs.
const FLIGHT_FULL_SPEED := 22.0
const FLIGHT_RELEASE_FREQUENCY := 10.0
## Spring rate of the lean and flight body while bracing for a landing (1/s).
const BRACE_FREQUENCY := 22.0
## Level flight pitch limit; dives go on to the profile's dive_pitch (horizontal superman).
const MAX_FLIGHT_PITCH := deg_to_rad(78.0)
## Twist limits about the bone (radians) and the fastest any body bone may turn (rad/s).
const TWIST_LIMITS := {&"LeftLowerArm": 1.6, &"RightLowerArm": 1.6, &"LeftUpperArm": 1.8, &"RightUpperArm": 1.8}
const MAX_TURN_RATE := 54.0
## Largest turn (rad) an arm bone may make in one frame after the late weapon clearance (pops are 1.2).
const MAX_ARM_FRAME_TURN := 1.1
## Clear-then-limit rounds after the turn cap: a trimmed arm gets another solve within the limit.
const POST_CAP_ROUNDS := 6
## Shares of this frame's arm turn the trim fallback tries, from the most to none (last frame's arm).
const TRIM_FALLBACK_SHARES: Array[float] = [0.75, 0.5, 0.25, 0.0]
## Smallest trim (rad) the fallback checks: less moves the weapon under the solver's gap at an arm's reach.
const TRIM_FALLBACK_MIN := 0.05
## Post-cap rounds that may swing the weapon; the rest only move the hand.
const SWING_ROUNDS := 2
## Costume spring chains (hood points, sash, cape, beard braid, apron) the pop guard covers too: their
## springs lag the clip's pose, which the layers then move, so they can whip round in one frame.
const CHAIN_PARTS := ["Hood", "Sash", "Cape", "Beard", "Apron"]
## Inertialization never carries in more angular velocity than this (rad/s).
const MAX_BLEND_SPEED := 14.0
const FLUTTER_HZ := 2.4
## Arm poses for held weapons (T-D30), solved by two-bone IK on top of the clip.
enum ArmPose { NONE, TWO_HANDED, BOW_DRAW, PISTOL_AIM, GUARD, BRACED, SWING, BOW_LOW, SIDE, PISTOL_LOW, TUCK, FLY,
	BOW_TUCK, BOW_FLY }
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
	# Hit reaction: a one-hand weapon tucked low at the side, pointing down and out, whatever the clip does.
	ArmPose.TUCK: [Vector3(-0.5, -0.8, 0.05), Vector3(-0.35, -1, -0.2), Vector3(0, 0, 1)],
	# Flight: held at the side, trailing back along the body.
	ArmPose.FLY: [Vector3(-0.45, -0.75, -0.1), Vector3(-0.3, -0.35, -1), Vector3(0, -1, 0.2)],
	# A bow in a hit reaction or in flight: out at the side, limbs fore and aft, string facing out,
	# so neither limb swings up into the arm or chest.
	ArmPose.BOW_TUCK: [Vector3(-0.55, -0.78, 0.05), Vector3(-0.15, -0.35, 1), Vector3(1, 0, 0)],
	ArmPose.BOW_FLY: [Vector3(-0.55, -0.72, -0.05), Vector3(-0.15, -0.3, -1), Vector3(1, 0, 0)],
}
## Poses that replace the clip's arm (weight 1), eased in over about 8 frames (spring rate, 1/s).
const BASE_HOLDS: Array[ArmPose] = [ArmPose.TUCK, ArmPose.FLY, ArmPose.BOW_TUCK, ArmPose.BOW_FLY]
const BASE_HOLD_FREQUENCY := 36.0
## Spring rate (1/s) of the weapon's goal in chest space: pose changes glide in a few frames.
const GOAL_FREQUENCY := 36.0
const GOAL_DRAW_FREQUENCY := 48.0
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
const STRING_FREQUENCY := 60.0
## Torso turn (radians) toward the bow side at full draw.
const BOW_TWIST := deg_to_rad(70.0)
## The drawn upper string keeps this far off the head (m), canting the bow up to STRING_MAX_CANT (rad).
const STRING_CLEARANCE := 0.05
const STRING_MAX_CANT := 0.9
const STRING_CANT_STEP := 0.05
## Clearance solver: passes, and the margin it leaves (m).
const CLEARANCE_PASSES := 16
const CLEARANCE_MARGIN := 0.01
## Gap the solver keeps between weapon and body (m): the drawn spine can sit a few cm off the solved one.
const CLEARANCE_GAP := 0.03
## Share of last frame's clearance correction carried into the next frame (the rest relaxes).
const CLEARANCE_CARRY := 0.9
## Swing correction: largest turn of the weapon about the wrist per pass, and the shortest lever it acts on.
const SWING_STEP := 0.35
const SWING_MIN_LEVER := 0.12
## Capsules a held weapon must stay out of, per main hand (its own forearm and hand grip it).
const CLEAR_OF := {
	&"RightHand": [&"pelvis", &"chest", &"head", &"upper_arm_l", &"lower_arm_l", &"upper_arm_r"],
	&"LeftHand": [&"pelvis", &"chest", &"head", &"upper_arm_l", &"upper_arm_r", &"lower_arm_r"],
}


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
## Planted feet hold their world position (standing states); needs body_to_world.
@export var foot_lock := false
## Standing on the ground (idle, guard, charge, landing): the lowest sole is put on the ground.
@export var stance := false
## About to land: the flight lean and body ease out fast so the legs are under the body.
@export var brace := false
## Ground under a world point, in skeleton space relative to the stand floor (overrides ground
## when valid, so a locked foot is placed on the floor where it actually is).
var ground_at: Callable
## The skeleton's world transform this frame (read from the skeleton in skeleton mode).
var body_to_world := Transform3D.IDENTITY
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
## Progress through the attack for the swing arc (0..1).
var arm_phase := 0.0
## Lean, flight, look, secondary, flinch and landing layers; off keeps only the IK stages.
@export var body_layers := true
## Held weapon: the hand bone it sits on (empty = none), its transform in that bone's space,
## its part boxes in its own space and the off-hand grip point (INF = one-handed).
var weapon_hand := &""
var weapon_grip := Transform3D.IDENTITY
var weapon_boxes: Array[Transform3D] = []
## A bow's boxes without its resting string: once drawn, the solver keeps the drawn string off the head instead.
var weapon_drawn_boxes: Array[Transform3D] = []
var weapon_off_hand := Vector3.INF
## The off hand's palm socket in its bone's space (see WeaponGrip.hand_socket).
var off_hand_socket := Transform3D.IDENTITY
## The holder's body capsules; the clearance solver keeps the weapon out of them.
var body: BodyCapsules
## Deepest weapon-into-body overlap left after the last solve (m), for tests and QA.
var weapon_overlap := 0.0
## Largest arm turn the per-frame arm limit took back in the last solve (rad), for QA.
var arm_trim := 0.0
var arm_trim_bone := &""
# Clearance carry-over: last frame's main-hand correction (chest space), so the cleared weapon stays
# on the side it was cleared to instead of flipping as the clip passes it through the body.
var _carry_offset := Vector3.ZERO
var _carry_turn := Quaternion.IDENTITY
var _carry_from := Transform3D.IDENTITY
var _carry_live := false
# The eased weapon goal in chest space (see _ease_goal).
var _goal := Transform3D.IDENTITY
var _goal_velocity := Vector3.ZERO
var _goal_live := false
# Bow draw weight (string hand at the anchor), sprung on its own.
var _string := 0.0
var _string_velocity := 0.0
# Hips as posed this frame before the pop guard (its hand fix-up works from them).
var _last_hips_now := Vector3.ZERO
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
var _moving_sets := {}
var _prev_out: Array[Quaternion] = []
var _last_hips := Vector3.ZERO
var _prev_hips := Vector3.ZERO
# The blended clip pose (inertialization only, before the other layers) of the last two frames: a
# clip switch blends from it, so the layers are never captured into the offsets and re-applied.
var _last_base: Array[Quaternion] = []
var _prev_base: Array[Quaternion] = []
var _last_base_hips := Vector3.ZERO
var _last_delta := 1.0 / 60.0
# Foot lock per side: the locked world point (INF: none) and the sprung skeleton-space offset.
var _lock_world: Array[Vector3] = [Vector3.INF, Vector3.INF]
var _lock_offset: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _lock_offset_velocity: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
# Grounding pass: the pelvis shift (skeleton space, m) and its release velocity.
var _shift := 0.0
var _shift_velocity := 0.0
# Frame stepping (advance_frame): the delta still to step, or -1 once stepped this frame.
var _frame_delta := -1.0
var _frame_driven := false
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
## Rest rotation of each bone in skeleton space.
var _rest_world_rot: Array[Quaternion] = []
var _bone_axis: Array[Vector3] = []
# Pop guard: per body bone (index into _used), its body parent's index (-1: none) and world rotations.
var _used_parent: PackedInt32Array = []
var _guard_world: Array[Quaternion] = []
var _guard_world_now: Array[Quaternion] = []
var _world_cache: Array = []
## The upper-body pose the last clear _clearance this frame ended on: a repeat call on it is a no-op.
## Legs and the hips' position don't move the weapon against the torso, so they are not part of it.
var _clear_rotations: Array[Quaternion] = []
var _clear_valid := false
var _clear_key_bones := {}
var _clear_capsule_body: BodyCapsules = null
var _clear_capsule_sets := {}
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
	_clear_key_bones.clear()
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
		if body.has(_names[i]) or _is_chain(_names[i]):
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


static func _is_chain(bone: StringName) -> bool:
	for part: String in CHAIN_PARTS:
		if String(bone).contains(part):
			return true
	return false


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
	_last_base.clear()
	_prev_base.clear()
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
	_lock_world = [Vector3.INF, Vector3.INF]
	_lock_offset = [Vector3.ZERO, Vector3.ZERO]
	_lock_offset_velocity = [Vector3.ZERO, Vector3.ZERO]
	_guard_world.clear()
	_carry_offset = Vector3.ZERO
	_carry_turn = Quaternion.IDENTITY
	_goal_live = false
	_string = 0.0
	_string_velocity = 0.0
	_shift = 0.0
	_shift_velocity = 0.0


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
	_pending_blend = not _last_base.is_empty()


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


## Steps the layers by delta (the view's frame time) on the next skeleton update. The skeleton can
## update several times per frame (Godot runs a delta-0 pass too); only the first steps, the rest
## re-apply that result. Without calls, each update steps by the skeleton's own delta.
func advance_frame(delta: float) -> void:
	_frame_delta = maxf(delta, 0.0)
	_frame_driven = true


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _names.is_empty():
		return
	if _scratch.size() != _names.size():
		_scratch.resize(_names.size())
		_scratch.fill(Quaternion.IDENTITY)
	var rotations := _scratch
	var hips_id: int = _index.get(&"Hips", -1)
	if _frame_driven and _frame_delta < 0.0 and _last_out.size() == rotations.size():
		# Same frame, same input pose: the same output (the skeleton undid it after the last pass).
		for i in _used:
			skeleton.set_bone_pose_rotation(i, _last_out[i])
		if hips_id >= 0:
			skeleton.set_bone_pose_position(hips_id, _last_hips)
		return
	if _frame_driven:
		delta = _frame_delta
		_frame_delta = -1.0
	body_to_world = skeleton.global_transform
	for i in _used:
		rotations[i] = skeleton.get_bone_pose_rotation(i)
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
	_clear_valid = false
	if body_layers:
		_inertialize(rotations, delta)
		hips = _inertialize_hips(hips, delta)
		_prev_base = _last_base
		_last_base = rotations.duplicate()
		_last_base_hips = hips
		_lean_layer(rotations, delta)
		_flight_layer(rotations, delta)
		_look_layer(rotations, delta)
		_secondary_layer(rotations, delta)
		_flinch_layer(rotations, delta)
		hips = _landing_layer(rotations, hips, delta)
	_arm_layer(rotations, hips, delta)
	hips = _stance_layer(hips, delta)
	hips = _stance_shift(rotations, hips, delta)
	_carry_clearance(rotations, hips)
	_clearance(rotations, hips)
	if foot_ik:
		hips = _foot_ik(rotations, hips, delta)
	else:
		_release_locks()
	_ground_pass(rotations, hips)
	_last_hips_now = hips
	_twist_guard(rotations)
	# The twist limits can bring the weapon back into the body: clear it once more, before the turn cap.
	_clearance(rotations, hips)
	_pop_guard(rotations, delta)
	# The turn cap can bring the weapon back in: clear it after the cap too, under the arm pop limit.
	for round_index in POST_CAP_ROUNDS:
		# Later rounds only move the hand: a swing turns the hand, which the cap would trim again.
		_clearance(rotations, hips, round_index < SWING_ROUNDS)
		_arm_pop_limit(rotations)
		if arm_trim <= 0.0:
			break
	_trim_fallback(rotations, hips)
	_remember_clearance(rotations, hips)
	# Next frame's turn cap starts from this output as drawn (cleared), not the pre-clearance pose.
	_guard_world.clear()
	hips = _lift_sunk_feet(rotations, hips)
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
			_offsets[i] = rotvec(_last_base[i] * rotations[i].inverse())
			_offset_velocity[i] = Vector3.ZERO
			if _prev_base.size() == rotations.size():
				_offset_velocity[i] = (rotvec(_last_base[i] * _prev_base[i].inverse()) / _last_delta).limit_length(MAX_BLEND_SPEED)
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
		_hips_offset = _last_base_hips - hips
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
	if brace:
		target = Vector3.ZERO
	elif flying:
		# Bank into turns: roll with lateral acceleration, pitch down with speed (dive).
		target.z = clampf(-accel.x * accel_lean * 2.0 - velocity.x * 0.03, -MAX_BANK, MAX_BANK)
		var speed := velocity.length()
		var diving := clampf((-velocity.y - 6.0) / 14.0, 0.0, 1.0)
		target.x = clampf(velocity.z * 0.045 - velocity.y * 0.03 + speed * 0.012 + diving * 0.45 + _burst * 0.5,
			-MAX_LEAN, lerpf(MAX_FLIGHT_PITCH, dive_pitch, diving))
	else:
		target.x = clampf(target.x, -MAX_LEAN, MAX_LEAN)
		target.z = clampf(target.z, -MAX_LEAN, MAX_LEAN)
	var s := spring(lean, _lean_velocity, target, maxf(lean_frequency, BRACE_FREQUENCY) if brace else lean_frequency, delta)
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
	# Bracing for a landing, the flight body goes fast: the legs come under the body before touchdown.
	var s := spring(_flight, _flight_velocity, amount, 7.0 if flying else BRACE_FREQUENCY if brace else FLIGHT_RELEASE_FREQUENCY, delta)
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
	if arm_pose in BASE_HOLDS:
		frequency = BASE_HOLD_FREQUENCY
	var s := spring(_arm, _arm_velocity, arm_weight if arm_pose != ArmPose.NONE else 0.0, frequency, delta)
	_arm = clampf(s[0], 0.0, 1.0)
	_arm_velocity = s[1]
	# The draw (string hand at the anchor, archer's turn) eases in and out on its own weight.
	var draw := spring(_string, _string_velocity, 1.0 if arm_pose == ArmPose.BOW_DRAW else 0.0, STRING_FREQUENCY, delta)
	_string = clampf(draw[0], 0.0, 1.0)
	_string_velocity = draw[1]
	if _arm < 0.01 or _arm_pose_now == ArmPose.NONE or weapon_hand == &"":
		_goal_live = false
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
	var drawing := weapon_hand == &"LeftHand" and weapon_off_hand == Vector3.INF and _string > 0.01
	if drawing:
		_archer_stance(rotations, _arm * _string)
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
		goal_basis = _clear_string_of_head(rotations, hips, _weapon_basis(up, forward), goal_point, anchor)
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
	var eased := _ease_goal(Transform3D(goal_basis, goal_point), _world_at(rotations, hips, chest), delta)
	goal_basis = eased.basis
	goal_point = eased.origin
	var hand_basis := goal_basis * grip.basis.inverse()
	var hand_point := goal_point - hand_basis * grip.origin
	_reach_hand(rotations, hips, main_chain, hand_point, hand_basis.get_rotation_quaternion(), _arm)
	if drawing:
		var anchor := _bow_anchor(rotations, hips, frame) + _bow_pull_offset(frame)
		var string_chain := _arm_chain(&"RightHand" if weapon_hand == &"LeftHand" else &"LeftHand")
		if not string_chain.is_empty():
			_world_cache.clear()
			var bow := _world_at(rotations, hips, main_chain[2]) * weapon_grip
			var pull := (anchor - bow.origin).normalized()
			var palm := _weapon_basis(frame * Vector3.UP, -pull).orthonormalized()
			# The palm (where the string sits), not the wrist, goes to the anchor.
			var wrist := anchor - palm * off_hand_socket.origin
			_reach_hand(rotations, hips, string_chain, wrist, palm.get_rotation_quaternion(), _arm * _string)
	elif _arm_pose_now != ArmPose.SIDE:
		_grip_off_hand(rotations, hips, _arm)


## A new weapon in hand: no carried clearance from the last one (the goal still eases over).
func new_weapon() -> void:
	_carry_offset = Vector3.ZERO
	_carry_turn = Quaternion.IDENTITY


## Eases the weapon's goal toward this frame's in chest space, so a pose change (guard to tuck,
## swing to guard) glides over a few frames instead of jumping the arm.
func _ease_goal(goal: Transform3D, chest: Transform3D, delta: float) -> Transform3D:
	var local := chest.affine_inverse() * goal
	if not _goal_live:
		_goal_live = true
		_goal = local
		_goal_velocity = Vector3.ZERO
	else:
		# A bow draw tracks its aim line closely; other holds glide.
		var frequency := GOAL_DRAW_FREQUENCY if _arm_pose_now == ArmPose.BOW_DRAW else GOAL_FREQUENCY
		var s := spring(_goal.origin, _goal_velocity, local.origin, frequency, delta)
		var t := 1.0 - exp(-frequency * delta)
		var turn := _goal.basis.get_rotation_quaternion().slerp(local.basis.get_rotation_quaternion(), t)
		_goal = Transform3D(Basis(turn), s[0])
		_goal_velocity = s[1]
	return chest * _goal


## Where a short-armed draw moves the anchor: back along the draw and out, away from the head.
func _bow_pull_offset(frame: Basis) -> Vector3:
	var side := -1.0 if weapon_hand == &"LeftHand" else 1.0
	return frame * Vector3(side * _bow_pull_back * 0.6, 0, -_bow_pull_back)


## True once a bow draw has fully arrived: the string hand is at the anchor beside the face.
func bow_at_anchor() -> bool:
	return _arm_pose_now == ArmPose.BOW_DRAW and arm_pose == ArmPose.BOW_DRAW and _arm * _string >= BOW_SHOWN_WEIGHT


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


## Cants a drawn bow further about its aim until the upper string (top tip to the anchor) and the
## bow itself clear the head, so the clearance has less reason to swing the bow across the face.
func _clear_string_of_head(rotations: Array[Quaternion], hips: Vector3, basis: Basis, grip_point: Vector3,
		anchor: Vector3) -> Basis:
	if body == null or not body.bones.has(&"head"):
		return basis
	var entry: Array = body.bones[&"head"]
	var from := _world_at(rotations, hips, entry[0])
	var end: Vector3 = _world_at(rotations, hips, entry[1]).origin if entry[1] >= 0 else from * (entry[2] as Vector3)
	var radius := float(body.radii[&"head"])
	var string_head := [from.origin, end, radius + STRING_CLEARANCE]
	var bow_head := {&"head": [from.origin, end, radius + CLEARANCE_GAP + CLEARANCE_MARGIN]}
	var scale := weapon_grip.basis.get_scale()
	var tip := WeaponGrip.BOW_TIP * scale
	var aim := (grip_point - anchor).normalized()
	var cost := func(b: Basis) -> float:
		var string_depth := BodyCapsules.segment_depth(grip_point + b * tip, anchor, string_head)
		var boxes: Array[Transform3D] = []
		var at := Transform3D(b.scaled_local(scale), grip_point)
		for box in weapon_boxes:
			boxes.append(at * box)
		var box_depth := float(BodyCapsules.deepest_box(bow_head, boxes)[0]) if not boxes.is_empty() else -INF
		return maxf(maxf(string_depth, box_depth), 0.0)
	var best_cost: float = cost.call(basis)
	if best_cost <= 0.0:
		return basis
	# Turn the top away from the head: the side of the aim line the head is not on.
	var to_head := from.origin - anchor
	var away := -(to_head - aim * to_head.dot(aim))
	var top := basis * tip
	var turn_sign := 1.0 if aim.cross(top - aim * top.dot(aim)).dot(away) > 0.0 else -1.0
	var best := basis
	var angle := 0.0
	while angle < STRING_MAX_CANT and best_cost > 0.0:
		angle += STRING_CANT_STEP
		var turned := Basis(aim, turn_sign * angle) * basis
		var c: float = cost.call(turned)
		if c < best_cost:
			best_cost = c
			best = turned
	return best


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
func _clearance(rotations: Array[Quaternion], hips: Vector3, swing := true) -> void:
	weapon_overlap = 0.0
	if weapon_hand == &"" or body == null or weapon_boxes.is_empty():
		return
	var main := _arm_chain(weapon_hand)
	if main.is_empty():
		return
	var tested := _clear_capsules(main)
	var key_bones := _clear_bones(tested, main)
	# A drawn bow: its string runs to the string hand, so the solver tests that string against the head.
	var drawn := not weapon_drawn_boxes.is_empty() and weapon_hand == &"LeftHand" and bow_at_anchor()
	var string_chain := _arm_chain(&"RightHand") if drawn else []
	drawn = drawn and not string_chain.is_empty()
	if not drawn and _clear_valid and _pose_of(rotations, key_bones) == _clear_rotations:
		_world_cache.clear()
		return
	var own := weapon_drawn_boxes if drawn else weapon_boxes
	var capsules := {}
	_world_cache.clear()
	_place_capsules(rotations, hips, capsules, tested)
	var moving := _moving_capsules(tested, main)
	for pass_index in CLEARANCE_PASSES + 1:
		_world_cache.clear()
		var hand := _world_at(rotations, hips, main[2])
		var hit := _holder_hit(rotations, hips, hand * weapon_grip, capsules, moving, own, string_chain if drawn else [])
		weapon_overlap = maxf(float(hit[0]), 0.0)
		if float(hit[0]) <= -CLEARANCE_GAP:
			_clear_rotations = _pose_of(rotations, key_bones)
			_clear_valid = true
			return
		if pass_index == CLEARANCE_PASSES:
			return
		var push: Vector3 = hit[1]
		var depth := float(hit[0]) + CLEARANCE_GAP + CLEARANCE_MARGIN
		# Swing: turn the weapon about the wrist so the overlapping part moves out along the push,
		# then move the hand for whatever the swing did not clear.
		# Lever: the overlapping part's centre, or the contact point when that centre is at the wrist.
		var lever: Vector3 = (hit[4] as Vector3) - hand.origin
		if lever.length() <= SWING_MIN_LEVER:
			lever = (hit[3] as Vector3) - hand.origin
		var hand_rotation := hand.basis.get_rotation_quaternion()
		var moved := 0.0
		var axis := lever.cross(push)
		if swing and lever.length() > SWING_MIN_LEVER and axis.length() > 1e-4:
			var angle := minf(depth / lever.length(), SWING_STEP)
			hand_rotation = Quaternion(axis.normalized(), angle) * hand_rotation
			moved = angle * lever.length() * axis.length() / lever.length()
		var target := hand.origin + push * maxf(depth - moved, CLEARANCE_MARGIN)
		_reach_hand(rotations, hips, main, target, hand_rotation, 1.0)
		_grip_off_hand(rotations, hips, 1.0)


## The weapon's deepest reach into the tested capsules: [depth, push, capsule, contact, centre]
## (BodyCapsules.deepest_box). With a string chain, also a drawn bow's string and arrow vs the head.
func _holder_hit(rotations: Array[Quaternion], hips: Vector3, weapon: Transform3D, capsules: Dictionary,
		refresh: Array, own: Array[Transform3D], string_chain: Array) -> Array:
	var boxes: Array[Transform3D] = []
	for box in own:
		boxes.append(weapon * box)
	_place_capsules(rotations, hips, capsules, refresh)
	var hit := BodyCapsules.deepest_box(capsules, boxes)
	if not string_chain.is_empty() and capsules.has(&"head"):
		var nock := (_world_at(rotations, hips, string_chain[2]) * off_hand_socket).origin
		var tip := WeaponGrip.BOW_TIP
		# Both halves of the string, and the nocked arrow from the nock out through the grip.
		var arrow := (weapon.origin - nock).normalized() * BowString.ARROW_LENGTH * weapon.basis.get_scale().z
		var strings: Array[Transform3D] = [_segment_box(weapon * tip, nock),
			_segment_box(weapon * Vector3(tip.x, -tip.y, tip.z), nock), _segment_box(nock, nock + arrow)]
		var string_hit := BodyCapsules.deepest_box({&"head": capsules[&"head"]}, strings)
		if float(string_hit[0]) > float(hit[0]):
			hit = string_hit
	return hit


## Writes the world [a, b, radius] of each capsule entry ([name, bone, end bone, offset, radius]) into capsules.
func _place_capsules(rotations: Array[Quaternion], hips: Vector3, capsules: Dictionary, entries: Array) -> void:
	for entry: Array in entries:
		var from := _world_at(rotations, hips, entry[1])
		var b: Vector3 = _world_at(rotations, hips, entry[2]).origin if entry[2] >= 0 else from * (entry[3] as Vector3)
		capsules[entry[0]] = [from.origin, b, entry[4]]


## The tested capsules the solver's arm moves (on the main or off-hand chain); the rest hold still during a solve.
func _moving_capsules(tested: Array, main: Array) -> Array:
	var two_handed := weapon_off_hand != Vector3.INF
	# Per body, fixed by the main hand, the tested set and whether the off hand grips too.
	var key: int = (main[2] * 64 + tested.size()) * 2 + int(two_handed)
	if not _moving_sets.has(key):
		var chains: Array = main.duplicate()
		if two_handed:
			chains.append_array(_arm_chain(&"RightHand" if weapon_hand == &"LeftHand" else &"LeftHand"))
		_moving_sets[key] = tested.filter(func(entry: Array) -> bool: return chains.has(entry[1]) or chains.has(entry[2]))
	return _moving_sets[key]


## When the turn cap leaves a one-hand weapon in the body, the arm eases back toward last frame's
## cleared pose instead: the largest share of this frame's turn that is clear (else the shallowest) within the cap.
func _trim_fallback(rotations: Array[Quaternion], hips: Vector3) -> void:
	if arm_trim < TRIM_FALLBACK_MIN or weapon_hand == &"" or body == null or weapon_boxes.is_empty() \
			or weapon_off_hand != Vector3.INF or _last_out.size() != rotations.size():
		return
	var main := _arm_chain(weapon_hand)
	if main.is_empty():
		return
	var tested := _clear_capsules(main)
	var drawn := not weapon_drawn_boxes.is_empty() and weapon_hand == &"LeftHand" and bow_at_anchor()
	var string_chain := _arm_chain(&"RightHand") if drawn else []
	drawn = drawn and not string_chain.is_empty()
	var own := weapon_drawn_boxes if drawn else weapon_boxes
	var strings := string_chain if drawn else []
	_world_cache.clear()
	var capsules := {}
	_place_capsules(rotations, hips, capsules, tested)
	var moving := _moving_capsules(tested, main)
	var depth := float(_holder_hit(rotations, hips, _world_at(rotations, hips, main[2]) * weapon_grip, capsules, [], own, strings)[0])
	if depth <= 0.0:
		return
	var trimmed: Array[Quaternion] = [rotations[main[0]], rotations[main[1]], rotations[main[2]]]
	# Two arms to ease toward: last frame's, carried by this frame's torso, and last frame's as held in the world.
	var shoulder := _world_rotation(rotations, _parents[main[0]]) if _parents[main[0]] >= 0 else Quaternion.IDENTITY
	var held: Array[Quaternion] = [(shoulder.inverse() * _world_rotation(_last_out, main[0])).normalized(),
		_last_out[main[1]], _last_out[main[2]]]
	var carried: Array[Quaternion] = [_last_out[main[0]], _last_out[main[1]], _last_out[main[2]]]
	# None clear: the shallowest within the cap.
	var best := trimmed
	var best_depth := depth
	for base: Array[Quaternion] in [carried, held]:
		for share: float in TRIM_FALLBACK_SHARES:
			for k in 3:
				rotations[main[k]] = base[k].slerp(trimmed[k], share).normalized()
			_world_cache.clear()
			if not _arm_turn_within_cap(rotations, main):
				continue
			var reach := float(_holder_hit(rotations, hips, _world_at(rotations, hips, main[2]) * weapon_grip, capsules, moving, own, strings)[0])
			if reach <= 0.0:
				weapon_overlap = 0.0
				return
			if reach < best_depth:
				best_depth = reach
				best = [rotations[main[0]], rotations[main[1]], rotations[main[2]]]
	for k in 3:
		rotations[main[k]] = best[k]
	weapon_overlap = best_depth
	_world_cache.clear()


## Whether every bone of the arm chain turned at most MAX_ARM_FRAME_TURN (model space) since the last output.
func _arm_turn_within_cap(rotations: Array[Quaternion], chain: Array) -> bool:
	for i: int in chain:
		var now := _world_rotation(rotations, i)
		var last := _world_rotation(_last_out, i)
		if last.angle_to(now) > MAX_ARM_FRAME_TURN + 1e-4:
			return false
	return true


## A thin box (unit-cube transform) along the segment a to b, as thick as a bow string.
static func _segment_box(a: Vector3, b: Vector3) -> Transform3D:
	var along := b - a
	var length := maxf(along.length(), 0.001)
	var y := along / length
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var r := BowString.STRING_RADIUS
	return Transform3D(Basis(x * r, y * length * 0.5, x.cross(y) * r), (a + b) * 0.5)


## The body's capsules the clearance tests, in BodyCapsules order: [name, bone, end bone, offset, radius].
## The set is CLEAR_OF's for the main hand, less the forearms while the off hand grips the weapon too.
func _clear_capsules(main: Array) -> Array:
	var two_handed := weapon_off_hand != Vector3.INF
	var key: int = main[2] * 2 + int(two_handed)
	if _clear_capsule_body != body:
		_clear_capsule_body = body
		_clear_capsule_sets.clear()
		_clear_key_bones.clear()
		_moving_sets.clear()
	if not _clear_capsule_sets.has(key):
		var names: Array = CLEAR_OF.get(weapon_hand, [])
		if two_handed:
			names = names.filter(func(n: StringName) -> bool: return not n.begins_with("lower_arm"))
		var entries: Array = []
		for name: StringName in body.bones:
			if names.is_empty() or names.has(name):
				var entry: Array = body.bones[name]
				entries.append([name, entry[0], entry[1], entry[2], float(body.radii[name])])
		_clear_capsule_sets[key] = entries
	return _clear_capsule_sets[key]


## The bones whose rotations place the tested capsules and the main hand: every ancestor of each.
func _clear_bones(tested: Array, main: Array) -> PackedInt32Array:
	# Per body, the tested set is fixed by the main hand and whether the off hand grips too.
	var key: int = main[2] * 64 + tested.size()
	if not _clear_key_bones.has(key):
		var marked := {}
		var leaves: Array = [main[2]]
		for entry: Array in tested:
			leaves.append(entry[1])
			if entry[2] >= 0:
				leaves.append(entry[2])
		for leaf: int in leaves:
			var i := leaf
			while i >= 0 and not marked.has(i):
				marked[i] = true
				i = _parents[i]
		var out := PackedInt32Array(marked.keys())
		out.sort()
		_clear_key_bones[key] = out
	return _clear_key_bones[key]


static func _pose_of(rotations: Array[Quaternion], bones: PackedInt32Array) -> Array[Quaternion]:
	var out: Array[Quaternion] = []
	out.resize(bones.size())
	for k in bones.size():
		out[k] = rotations[bones[k]]
	return out


## Re-applies most of last frame's clearance correction to the main hand before this frame's solve.
func _carry_clearance(rotations: Array[Quaternion], hips: Vector3) -> void:
	_carry_live = false
	var chest: int = _index.get(&"UpperChest", _index.get(&"Chest", -1))
	var main := _arm_chain(weapon_hand) if weapon_hand != &"" else []
	# A bow draw places both hands on the aim line itself: nothing carries into it.
	if body == null or weapon_boxes.is_empty() or main.is_empty() or chest < 0 or _arm_pose_now == ArmPose.BOW_DRAW:
		_carry_offset = Vector3.ZERO
		_carry_turn = Quaternion.IDENTITY
		return
	_world_cache.clear()
	var space := _world_at(rotations, hips, chest)
	_carry_from = space.affine_inverse() * _world_at(rotations, hips, main[2])
	_carry_live = true
	if _carry_offset == Vector3.ZERO and _carry_turn.is_equal_approx(Quaternion.IDENTITY):
		return
	var point := space * (_carry_from.origin + _carry_offset * CLEARANCE_CARRY)
	var turn := Quaternion.IDENTITY.slerp(_carry_turn, CLEARANCE_CARRY)
	var rotation := space.basis.get_rotation_quaternion() * turn * _carry_from.basis.get_rotation_quaternion()
	_reach_hand(rotations, hips, main, point, rotation.normalized(), 1.0)
	_grip_off_hand(rotations, hips, 1.0)


## Stores this frame's main-hand correction (drawn hand against the hand before the clearance).
func _remember_clearance(rotations: Array[Quaternion], hips: Vector3) -> void:
	if not _carry_live:
		return
	var chest: int = _index.get(&"UpperChest", _index.get(&"Chest", -1))
	var main := _arm_chain(weapon_hand)
	_world_cache.clear()
	var now := _world_at(rotations, hips, chest).affine_inverse() * _world_at(rotations, hips, main[2])
	_world_cache.clear()
	_carry_offset = now.origin - _carry_from.origin
	_carry_turn = (now.basis.get_rotation_quaternion() * _carry_from.basis.get_rotation_quaternion().inverse()).normalized()
	if _carry_offset.length() < 0.002 and _carry_turn.get_angle() < 0.01:
		_carry_offset = Vector3.ZERO
		_carry_turn = Quaternion.IDENTITY



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
	if _last_out.size() != rotations.size():
		_guard_world.clear()
		return
	# A frozen frame (hitstop) still may not turn a bone further than one 60 Hz frame would.
	var step := MAX_TURN_RATE * (delta if delta > 0.0 else 1.0 / 60.0)
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


## Limits each arm bone's model-space turn since the last output to MAX_ARM_FRAME_TURN (parents first).
func _arm_pop_limit(rotations: Array[Quaternion]) -> void:
	arm_trim = 0.0
	if _last_out.size() != rotations.size():
		return
	for chain: Array in ARMS:
		for bone: StringName in chain:
			var i: int = _index.get(bone, -1)
			if i < 0:
				continue
			var parent_now := _world_rotation(rotations, _parents[i]) if _parents[i] >= 0 else Quaternion.IDENTITY
			var now := parent_now * rotations[i]
			var last := _world_rotation(_last_out, i)
			if last.dot(now) < 0.0:
				now = -now
			var angle := last.angle_to(now)
			if angle > MAX_ARM_FRAME_TURN:
				if angle - MAX_ARM_FRAME_TURN > arm_trim:
					arm_trim = angle - MAX_ARM_FRAME_TURN
					arm_trim_bone = bone
				now = last.slerp(now, MAX_ARM_FRAME_TURN / angle).normalized()
				rotations[i] = (parent_now.inverse() * now).normalized()
	_world_cache.clear()



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


func _release_locks() -> void:
	_lock_world = [Vector3.INF, Vector3.INF]
	_lock_offset = [Vector3.ZERO, Vector3.ZERO]
	_lock_offset_velocity = [Vector3.ZERO, Vector3.ZERO]


## Where a planted foot goes horizontally: its locked world point while the lock holds, else back
## toward the clip's foot (sprung, lifted a little so it reads as a step). Skeleton space.
func _locked_target(side: int, ankle: Vector3, planted: bool, delta: float) -> Vector3:
	if foot_lock and planted:
		if _lock_world[side] == Vector3.INF:
			_lock_world[side] = body_to_world * (ankle + _lock_offset[side])
		var locked := body_to_world.affine_inverse() * _lock_world[side]
		var offset := Vector3(locked.x - ankle.x, 0.0, locked.z - ankle.z)
		if offset.length() <= LOCK_RELEASE:
			_lock_offset[side] = offset
			_lock_offset_velocity[side] = Vector3.ZERO
			return ankle + offset
	_lock_world[side] = Vector3.INF
	if _lock_offset[side] != Vector3.ZERO:
		var s := spring(_lock_offset[side], _lock_offset_velocity[side], Vector3.ZERO, LOCK_BLEND_FREQUENCY, delta)
		_lock_offset[side] = s[0]
		_lock_offset_velocity[side] = s[1]
		if (s[0] as Vector3).length() < 0.002:
			_lock_offset[side] = Vector3.ZERO
			_lock_offset_velocity[side] = Vector3.ZERO
	return ankle + _lock_offset[side]


## Height (skeleton space, over the rest ankle) a foot stepping back from its lock lifts to. Absolute,
## not added to the clip's foot, so re-inertialized frames (which start from this output) can't stack it.
func _step_lift(side: int) -> float:
	return _lock_offset[side].length() * STEP_LIFT if _lock_world[side] == Vector3.INF else 0.0


func _foot_ik(rotations: Array[Quaternion], hips: Vector3, delta := 0.0) -> Vector3:
	var hips_id: int = _index.get(&"Hips", -1)
	if hips_id < 0 or flying:
		_release_locks()
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
		var planted := ankle.y < rest_y + PLANTED_HEIGHT
		var target := _locked_target(side, ankle, planted, delta)
		target.y = maxf(target.y, rest_y + _step_lift(side))
		if ground_at.is_valid():
			heights[side] = ground_at.call(body_to_world * target)
		if planted:
			if foot_lock:
				# Standing: the sole goes flat on the floor, easing out as the clip lifts the foot.
				var pin := 1.0 - smoothstep(PLANTED_HEIGHT * 0.5, PLANTED_HEIGHT, ankle.y - rest_y)
				target.y = lerpf(target.y, rest_y + _step_lift(side), pin)
			target.y += heights[side]
		target.y = maxf(target.y, heights[side] + rest_y)
		targets.append(target)
		var reach := (_origins[lo].length() + _origins[foot].length()) * 0.999
		var hip: Vector3 = (world[up] as Transform3D).origin
		var horizontal := Vector2(target.x - hip.x, target.z - hip.z).length()
		var need := sqrt(maxf(reach * reach - horizontal * horizontal, 0.0))
		drop = maxf(drop, (hip.y - target.y) - need)
	drop = clampf(drop, 0.0, MAX_PELVIS_DROP)
	hips.y -= drop
	_world_cache.clear()
	if drop > 0.0:
		# Lowering the hips only translates the legs: shift the transforms instead of rebuilding them.
		var shift := _rest_parent_rot[hips_id] * Vector3(0, -drop, 0)
		for i in world.size():
			if world[i] != null:
				var t: Transform3D = world[i]
				t.origin += shift
				world[i] = t
	# The two legs are separate chains below the hips, so one set of transforms serves both solves.
	for side in 2:
		if targets[side] == Vector3.INF:
			continue
		var foot: int = _index.get(LEGS[side][2], -1)
		if (world[foot] as Transform3D).origin.is_equal_approx(targets[side]):
			continue
		_two_bone(rotations, world, _index[LEGS[side][0]], _index[LEGS[side][1]], foot, targets[side])
	return hips


## Standing, the pelvis shifts so the lowest sole meets the ground under it (a clip or blend that
## floats the feet, a landing clip that starts above its contact); the foot IK then plants and locks
## it. Off the ground the shift eases out.
func _stance_shift(rotations: Array[Quaternion], hips: Vector3, delta: float) -> Vector3:
	var hips_id: int = _index.get(&"Hips", -1)
	if hips_id < 0 or not foot_ik or flying:
		_shift = 0.0
		_shift_velocity = 0.0
		return hips
	if stance:
		var gaps := _ground_gaps(rotations, hips)
		var lowest := minf(gaps[0], gaps[1])
		if not is_finite(lowest):
			return hips
		_shift = clampf(-lowest / maxf((_rest_parent_rot[hips_id] * Vector3.UP).y, 0.1), -MAX_GROUND_SHIFT, MAX_GROUND_SHIFT)
		_shift_velocity = 0.0
	elif _shift != 0.0:
		var s := spring(_shift, _shift_velocity, 0.0, SHIFT_RELEASE_FREQUENCY, delta)
		_shift = s[0]
		_shift_velocity = s[1]
		if absf(_shift) < 1e-4 and absf(_shift_velocity) < 1e-3:
			_shift = 0.0
			_shift_velocity = 0.0
	hips.y += _shift
	return hips


## Each sole's height over the ground under it (skeleton space; INF without that leg).
func _ground_gaps(rotations: Array[Quaternion], hips: Vector3) -> Array[float]:
	_world_cache.clear()
	var gaps: Array[float] = [INF, INF]
	for side in 2:
		var foot: int = _index.get(LEGS[side][2], -1)
		if foot < 0 or _index.get(LEGS[side][0], -1) < 0 or _index.get(LEGS[side][1], -1) < 0:
			continue
		var ankle := _world_at(rotations, hips, foot).origin
		gaps[side] = ankle.y - _floor_under(side, ankle, foot)
	_world_cache.clear()
	return gaps


## Rest ankle height over the ground under a skeleton-space point.
func _floor_under(side: int, at: Vector3, foot: int) -> float:
	var under: float = ground_at.call(body_to_world * at) if ground_at.is_valid() else ground[side]
	return under + _rest_heights[foot]


## Last word on the feet before the pop guard: a foot below its ground (steep runs) is re-solved
## onto it, so is the lowest standing foot the shift limit left short; planted feet tilt to the surface.
func _ground_pass(rotations: Array[Quaternion], hips: Vector3) -> void:
	if _index.get(&"Hips", -1) < 0 or not foot_ik or flying:
		return
	_world_cache.clear()
	var world := _legs_world(rotations, hips)
	var gaps := [INF, INF]
	var floors := [INF, INF]
	for side in 2:
		var foot: int = _index.get(LEGS[side][2], -1)
		if foot < 0 or _index.get(LEGS[side][0], -1) < 0 or _index.get(LEGS[side][1], -1) < 0:
			continue
		var ankle: Vector3 = (world[foot] as Transform3D).origin
		floors[side] = _floor_under(side, ankle, foot)
		gaps[side] = ankle.y - floors[side]
	var lowest_side := 0 if gaps[0] <= gaps[1] else 1
	for side in 2:
		if not is_finite(gaps[side]):
			continue
		var foot: int = _index[LEGS[side][2]]
		var ankle: Vector3 = (world[foot] as Transform3D).origin
		var short: bool = stance and side == lowest_side and gaps[side] > 0.001
		if gaps[side] < -0.001 or short:
			_two_bone(rotations, world, _index[LEGS[side][0]], _index[LEGS[side][1]], foot,
				Vector3(ankle.x, floors[side], ankle.z))
			gaps[side] = 0.0
	_world_cache.clear()
	_tilt_feet(rotations, hips, gaps)
	_world_cache.clear()


## After the pop guard (which may hold a leg back from its solve): a foot left below its ground
## lifts the whole body by the difference. A translation, so it can't pop a bone.
func _lift_sunk_feet(rotations: Array[Quaternion], hips: Vector3) -> Vector3:
	var hips_id: int = _index.get(&"Hips", -1)
	if hips_id < 0 or not foot_ik or flying:
		return hips
	_world_cache.clear()
	var deficit := 0.0
	for side in 2:
		var foot: int = _index.get(LEGS[side][2], -1)
		if foot < 0:
			continue
		var ankle := _world_at(rotations, hips, foot).origin
		deficit = maxf(deficit, _floor_under(side, ankle, foot) - ankle.y)
	_world_cache.clear()
	if deficit > 0.001:
		hips.y += minf(deficit, MAX_GROUND_SHIFT) / maxf((_rest_parent_rot[hips_id] * Vector3.UP).y, 0.1)
	return hips


## Planted feet turn toward the surface normal under them (clamped), eased out as they lift.
func _tilt_feet(rotations: Array[Quaternion], hips: Vector3, gaps: Array) -> void:
	if not ground_at.is_valid():
		return
	for side in 2:
		var gap: float = gaps[side]
		if not is_finite(gap) or gap > PLANTED_HEIGHT:
			continue
		var foot: int = _index[LEGS[side][2]]
		var lo: int = _index[LEGS[side][1]]
		var ankle := _world_at(rotations, hips, foot)
		var normal := _ground_normal(ankle.origin)
		var angle := Vector3.UP.angle_to(normal)
		if angle < 0.01:
			continue
		var weight := 1.0 - smoothstep(PLANTED_HEIGHT * 0.5, PLANTED_HEIGHT, gap)
		var axis := Vector3.UP.cross(normal).normalized()
		var tilt := Quaternion(axis, minf(angle, MAX_FOOT_TILT) * weight)
		var shin := _world_at(rotations, hips, lo).basis.get_rotation_quaternion()
		rotations[foot] = (shin.inverse() * tilt * ankle.basis.get_rotation_quaternion()).normalized()


## Surface normal (skeleton space) of the ground around a skeleton-space point.
func _ground_normal(at: Vector3) -> Vector3:
	const STEP := 0.12
	var dx: float = ground_at.call(body_to_world * (at + Vector3(STEP, 0, 0))) - ground_at.call(body_to_world * (at - Vector3(STEP, 0, 0)))
	var dz: float = ground_at.call(body_to_world * (at + Vector3(0, 0, STEP))) - ground_at.call(body_to_world * (at - Vector3(0, 0, STEP)))
	return Vector3(-dx / (2.0 * STEP), 1.0, -dz / (2.0 * STEP)).normalized()


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
	var d := clampf(to.length(), absf(l1 - l2) + 0.001, (l1 + l2) * KNEE_REACH)
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
