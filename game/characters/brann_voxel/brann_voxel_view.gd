class_name BrannVoxelView
extends BrannView
## Voxel Brann's view: BrannView unchanged, except that its crack pulse
## (BrannView.ember_energy) drives the voxel body's GLOW surface instead of
## the old figure's ember material. Each view owns its copy of the material.

## Emission per unit of ember energy, clamped so bloom stays a thin line glow.
const EMBER_GAIN := 0.7
const EMBER_MIN := 1.0
const EMBER_MAX := 2.6

## Hang the old smooth weapon models on his back and hip. Off by default:
## they don't match the voxel style. A VoxelArmory in the scene stows the voxel ones.
@export var stow_old_weapons := false

## Braid chain: how far its centre line stays in front of the chest and belly
## fronts (the bib plus the bead radius: it lies on the bib), the widest it may swing off his body's down
## axis, gravity, a weak pull back to its rest hang, damping, and how much of
## his own movement blows it back.
const BRAID_CLEARANCE := 0.06
const BRAID_MAX_SWING := deg_to_rad(32.0)
const BRAID_GRAVITY := 9.8
const BRAID_FOLLOW := 15.0
const BRAID_DAMPING := 0.88
const BRAID_DRAG := 0.6
const BRAID_ITERATIONS := 4
## Fastest a drawn braid segment may turn in skeleton space (rad/s), as ScarfLag.MAX_TURN_RATE.
const BRAID_MAX_TURN_RATE := 54.0
## How much further than BRAID_MAX_SWING the body may tilt the braid out.
const BRAID_BODY_TILT := deg_to_rad(20.0)
## The most his movement may blow the braid (m/s^2): a dash leans it, never flings it.
const BRAID_MAX_DRAG := 12.0
## How far the tufted tip and the end ring hang below the last joint.
const BRAID_TAIL := 0.09
## Rest heights (low, high) of the stone each of Spine, Chest and UpperChest moves.
const TORSO_BANDS: Array[Vector2] = [Vector2(0.90, 1.24), Vector2(1.04, 1.30), Vector2(1.22, 1.48)]
## The most the fist may swing off the forearm's line; the wrist plug fills
## the cuff's mouth up to this bend (twist about the forearm is free).
const WRIST_MAX_SWING := deg_to_rad(24.0)
## Air between a fist and a boulder.
const FIST_CLEARANCE := 0.01
## The boulder's and its wedge's axis faces (rest space, from the boulder's
## centre, x mirrored per side), grown by FIST_CLEARANCE: points outside both
## boxes are farther than that from the rock and skip its hull test.
const BOULDER_BOX := AABB(Vector3(-0.17, -0.17, -0.23), Vector3(0.38, 0.32, 0.43))
const WEDGE_BOX := AABB(Vector3(-0.01, 0.07, -0.20), Vector3(0.18, 0.12, 0.16))

var _glow: ShaderMaterial
var _design: BrannVoxelDesign
var _braid_bones: Array[int] = []
var _torso_bones: Array[int] = []
## Simulated braid joints and tip (skeleton space), now and one step ago.
var _braid_now := PackedVector3Array()
var _braid_was := PackedVector3Array()
var _braid_time := 0.0
## The braid bones' drawn rotations last frame (skeleton space).
var _braid_rot: Array[Quaternion] = []
## The head's skinning transform the braid was simulated against (before modifiers).
var _head_skin := Transform3D()
var _braid_pose: BraidPose


## Poses the braid as the skeleton's last modifier, on the body as drawn (MotionLayers
## and the other modifiers turn his torso and head after apply_state).
class BraidPose:
	extends SkeletonModifier3D
	var view: BrannVoxelView

	func _process_modification_with_delta(delta: float) -> void:
		if view != null and not view._braid_now.is_empty():
			view._pose_braid(delta)
## This frame's skinning transforms of Spine, Chest and UpperChest and their
## inverses (the torso holds still while the braid steps).
var _torso_skins: Array[Transform3D] = [Transform3D(), Transform3D(), Transform3D()]
var _torso_unskins: Array[Transform3D] = [Transform3D(), Transform3D(), Transform3D()]


func apply_state(fighter: FighterState, delta: float) -> void:
	super.apply_state(fighter, delta)
	_add_braid_pose()
	if _braid_pose.get_index() != _skeleton.get_child_count() - 1:
		_skeleton.move_child(_braid_pose, -1)
	_swing_braid(fighter, 0.0 if fighter.hitstop_ticks > 0 else delta)
	for side: float in [1.0, -1.0]:
		_clamp_wrist(side)
		_keep_fist_clear(side)
	if _glow:
		_glow.set_shader_parameter(&"emission_value", glow_energy(fighter, _time))


## The GLOW surface's emission for a state at a time.
static func glow_energy(fighter: FighterState, time: float) -> float:
	return clampf(ember_energy(fighter, time) * EMBER_GAIN, EMBER_MIN, EMBER_MAX)


## The braid hangs from the bottom of the beard as a chain of three
## segments: verlet joints under gravity with a weak pull toward the head's
## rest hang, his movement blowing it back, each segment held within
## BRAID_MAX_SWING of his chest's down axis and in front of his chest and
## belly. Stepped at 60 Hz; frozen in hitstop.
func _swing_braid(fighter: FighterState, delta: float) -> void:
	if _braid_bones.is_empty():
		for bone in BrannVoxelDesign.BRAID_BONES:
			_braid_bones.append(_skeleton.find_bone(bone))
		for bone: StringName in [&"Spine", &"Chest", &"UpperChest", &"Head", &"Neck"]:
			_torso_bones.append(_skeleton.find_bone(bone))
		if _braid_bones.has(-1):
			_braid_bones.clear()
			_torso_bones.clear()
			return
	var rest := BrannVoxelDesign.braid_points()
	for k in 3:
		_torso_skins[k] = _skin_of(_torso_bones[k])
		_torso_unskins[k] = _torso_skins[k].affine_inverse()
	var head := _skin_of(_torso_bones[3])
	var target := PackedVector3Array()
	for p in rest:
		target.append(head * p)
	if _braid_now.is_empty():
		_braid_now = target.duplicate()
		_braid_was = target.duplicate()
	var down := (_torso_skins[2].basis * Vector3.DOWN).normalized()
	var gravity := Vector3.DOWN
	if _skeleton.is_inside_tree():
		gravity = (_skeleton.global_transform.basis.inverse() * Vector3.DOWN).normalized()
	var push := (-_model_velocity(fighter) * CLOTH_DRAG * BRAID_DRAG).limit_length(BRAID_MAX_DRAG)
	_braid_time += delta
	while _braid_time >= SPRING_STEP:
		_braid_time -= SPRING_STEP
		for i in range(1, rest.size()):
			var x := _braid_now[i]
			var accel := gravity * BRAID_GRAVITY + push + (target[i] - x) * BRAID_FOLLOW
			_braid_now[i] = x + (x - _braid_was[i]) * BRAID_DAMPING + accel * SPRING_STEP * SPRING_STEP
			_braid_was[i] = x
		_constrain_braid(rest, target, down)
	if delta <= 0.0:
		_constrain_braid(rest, target, down)
	_head_skin = head


func _constrain_braid(rest: PackedVector3Array, target: PackedVector3Array, down: Vector3) -> void:
	# The root rides in the beard's bottom lobe, which is mostly on the neck.
	_braid_now[0] = _skin_of(_torso_bones[3]) * rest[0] * 0.37 + _skin_of(_torso_bones[4]) * rest[0] * 0.63
	for pass_index in BRAID_ITERATIONS:
		_hang_segments(rest, target, down, true)
		# Midpoints too: push a joint out if its segment cuts the bib.
		for i in range(1, rest.size()):
			var mid := (_braid_now[i - 1] + _braid_now[i]) * 0.5
			var out := _clear_of_torso(mid) - mid
			if out.length_squared() > 0.0:
				_braid_now[i] += out * 2.0
	# Last, exact lengths (the bones are rigid): never leave a segment stretched.
	_hang_segments(rest, target, down, true)


## Puts each joint at its segment's rest length from the one above, its
## direction held within BRAID_MAX_SWING of `down`. With `clear`, the joint,
## the segment's middle and (below the tip) the end ring are pushed out of
## the chest and belly first.
func _hang_segments(rest: PackedVector3Array, target: PackedVector3Array, down: Vector3, clear: bool) -> void:
	for i in range(1, rest.size()):
		var length := rest[i - 1].distance_to(rest[i])
		var start := _braid_now[i - 1]
		var dir := _braid_now[i] - start
		if dir.length_squared() < 1e-8:
			dir = target[i] - target[i - 1]
		dir = dir.normalized()
		if clear:
			for attempt in 3:
				var tail := length + (BRAID_TAIL if i == rest.size() - 1 else 0.0)
				var push := Vector3.ZERO
				for f: float in [0.5, 1.0, tail / length]:
					var p := start + dir * length * f
					push += (_clear_of_torso(p) - p) / f
				if push.length_squared() < 1e-8:
					break
				dir = (dir * length + push).normalized()
		if dir.angle_to(down) > BRAID_MAX_SWING:
			var axis := down.cross(dir)
			if axis.length_squared() < 1e-8:
				axis = Vector3.RIGHT
			dir = down.rotated(axis.normalized(), BRAID_MAX_SWING)
			if clear:
				# Held inside the stone at the limit: tilt it out over the chest
				# a little further (bounded, so it never swings up).
				var front := (_torso_skins[2].basis * Vector3.BACK).normalized()
				for step in 4:
					var end := start + dir * length
					if _clear_of_torso(end).is_equal_approx(end):
						break
					var out_axis := dir.cross(front)
					if out_axis.length_squared() < 1e-8:
						break
					dir = dir.rotated(out_axis.normalized(), BRAID_BODY_TILT / 4.0)
		_braid_now[i] = start + dir * length


## p pushed straight out of the chest and belly fronts (skeleton space).
func _clear_of_torso(p: Vector3) -> Vector3:
	for k in 3:
		var skin: Transform3D = _torso_skins[k]
		var q: Vector3 = _torso_unskins[k] * p
		# Each torso bone only for the band of stone it skins (spine, chest, upper chest).
		if q.y < TORSO_BANDS[k].x or q.y > TORSO_BANDS[k].y or absf(q.x) > 0.42:
			continue
		var deficit := BrannVoxelDesign.FRONT_Z + BRAID_CLEARANCE - q.z
		if deficit > 0.0:
			p = skin * Vector3(q.x, q.y, q.z + deficit)
	return p


## Called by BraidPose: the simulated chain carried along with the drawn head, each
## drawn segment turning at most BRAID_MAX_TURN_RATE (the solver's cone or the body's
## pose would flick it otherwise).
func _pose_braid(delta: float) -> void:
	var rest := BrannVoxelDesign.braid_points()
	var head := _skin_of(_torso_bones[3])
	var follow := head * _head_skin.affine_inverse()
	var head_basis := head.basis.orthonormalized()
	var max_turn := BRAID_MAX_TURN_RATE * delta
	var origin := follow * _braid_now[0]
	for k in _braid_bones.size():
		var from := (head_basis * (rest[k + 1] - rest[k])).normalized()
		var to := (follow.basis * (_braid_now[k + 1] - _braid_now[k])).normalized()
		var turn := Basis(Quaternion(from, to)) if from.dot(to) > -0.999 else Basis()
		var q := (turn * head_basis).get_rotation_quaternion()
		if k < _braid_rot.size():
			var angle := _braid_rot[k].angle_to(q)
			if angle > max_turn:
				q = _braid_rot[k].slerp(q, max_turn / angle)
			_braid_rot[k] = q
		else:
			_braid_rot.append(q)
		var basis := Basis(q)
		_skeleton.set_bone_global_pose(_braid_bones[k], Transform3D(basis, origin))
		origin += basis * head_basis.inverse() * (from * rest[k].distance_to(rest[k + 1]))


func _add_braid_pose() -> void:
	if _skeleton == null or _braid_pose != null:
		return
	_braid_pose = BraidPose.new()
	_braid_pose.name = "BraidPose"
	_braid_pose.view = self
	_skeleton.add_child(_braid_pose)


## The skinning transform of a bone: rest skeleton space to posed.
func _skin_of(bone: int) -> Transform3D:
	return _skeleton.get_bone_global_pose(bone) * _skeleton.get_bone_global_rest(bone).affine_inverse()


## The simulated braid joints and tip (skeleton space), root first.
func braid_joints() -> PackedVector3Array:
	return _braid_now


## A stone wrist barely bends: limit the hand's swing off the forearm's line
## so the palm and plug always fill the cuff (no gap), keeping its twist.
func _clamp_wrist(side: float) -> void:
	var prefix := "Left" if side > 0 else "Right"
	var lower := _skeleton.find_bone(StringName(prefix + "LowerArm"))
	var hand := _skeleton.find_bone(StringName(prefix + "Hand"))
	var fore := _skin_of(lower).basis.orthonormalized()
	var pose := _skeleton.get_bone_global_pose(hand)
	var hand_skin := (pose * _skeleton.get_bone_global_rest(hand).affine_inverse()).basis.orthonormalized()
	# The hand's turn relative to the forearm, in rest space, split into swing and twist about the arm (x).
	var rel := (fore.inverse() * hand_skin).get_rotation_quaternion()
	var axis := Vector3(rel.x, rel.y, rel.z)
	var twist := Quaternion(axis.x, 0.0, 0.0, rel.w).normalized() \
		if absf(rel.w) + absf(axis.x) > 1e-6 else Quaternion.IDENTITY
	var swing := rel * twist.inverse()
	if swing.w < 0.0:
		swing = -swing
	var angle := swing.get_angle()
	if angle <= WRIST_MAX_SWING:
		return
	var limited := Quaternion.IDENTITY.slerp(swing, WRIST_MAX_SWING / angle) * twist
	var turned := fore * Basis(limited) * _skeleton.get_bone_global_rest(hand).basis.orthonormalized()
	# Only the local rotation changes: the pose's position and scale stay the clip's.
	var parent := _skeleton.get_bone_global_pose(lower).basis.orthonormalized()
	_skeleton.set_bone_pose_rotation(hand, (parent.inverse() * turned).get_rotation_quaternion())


## His clips cock the fists by the shoulders, where the boulders sit: swing
## the upper arm about its root until the fist and forearm clear the rock.
func _keep_fist_clear(side: float) -> void:
	var prefix := "Left" if side > 0 else "Right"
	var shoulder := _skeleton.find_bone(StringName(prefix + "Shoulder"))
	var upper := _skeleton.find_bone(StringName(prefix + "UpperArm"))
	var hand := _skeleton.find_bone(StringName(prefix + "Hand"))
	var lower := _skeleton.find_bone(StringName(prefix + "LowerArm"))
	if _design == null:
		_design = BrannVoxelDesign.new(_skeleton)
	var points := BrannVoxelDesign.fist_points(side)
	var fore := BrannVoxelDesign.forearm_points(side)
	var centre := BrannVoxelDesign.boulder_center(side)
	for attempt in 6:
		var to_rock := (_skeleton.get_bone_global_pose(shoulder) * _skeleton.get_bone_global_rest(shoulder).affine_inverse()).affine_inverse()
		var shoulder_basis := _skeleton.get_bone_global_pose(shoulder).basis.orthonormalized() \
			* _skeleton.get_bone_global_rest(shoulder).basis.orthonormalized().inverse()
		var skin := _skeleton.get_bone_global_pose(hand) * _skeleton.get_bone_global_rest(hand).affine_inverse()
		var fore_skin := _skeleton.get_bone_global_pose(lower) * _skeleton.get_bone_global_rest(lower).affine_inverse()
		var worst := 0.0
		var at := Vector3.ZERO
		var push := Vector3.ZERO
		for k in points.size() + fore.size():
			var posed := skin * points[k] if k < points.size() else fore_skin * fore[k - points.size()]
			var q := to_rock * posed
			if not _near_boulder(q, centre, side):
				continue
			var deficit := FIST_CLEARANCE - _design.boulder_sdf(q, side)
			if deficit > worst:
				worst = deficit
				at = posed
				push = shoulder_basis * _design.boulder_normal(q, side) * deficit * 1.3
		if worst <= 0.002:
			return
		var root := _skeleton.get_bone_global_pose(upper).origin
		var turn := Quaternion((at - root).normalized(), (at + push - root).normalized())
		_turn_bone(upper, turn)


## Turns a bone by a skeleton-space rotation, changing only its local rotation: a global
## pose write folds any parent scale into the arm (skew, and a hand off where the weapon clearance put it).
func _turn_bone(bone: int, turn: Quaternion) -> void:
	var parent := _skeleton.get_bone_parent(bone)
	var parent_turn := _skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 \
		else Quaternion.IDENTITY
	var local := _skeleton.get_bone_pose_rotation(bone)
	_skeleton.set_bone_pose_rotation(bone, (parent_turn.inverse() * turn * parent_turn * local).normalized())


## Stone neither breathes nor squashes: the layer's bone scales would also grow his arms and the
## held weapon past where the weapon clearance solver (rotations only) placed them (QA-20).
func _apply_layer(layer: Dictionary) -> void:
	for bone: StringName in layer:
		layer[bone].scale = Vector3.ONE
	super._apply_layer(layer)


static func _near_boulder(q: Vector3, centre: Vector3, side: float) -> bool:
	var local := Vector3((q.x - centre.x) * side, q.y - centre.y, q.z - centre.z)
	return BOULDER_BOX.has_point(local) or WEDGE_BOX.has_point(local)


func _stow_weapons() -> void:
	if stow_old_weapons or bool(_skeleton.get_meta(WeaponModels.VOXEL_META, false)):
		super._stow_weapons()


## The view's own copy of the ember GLOW material (null before _ready).
func glow_material() -> ShaderMaterial:
	return _glow


func _own_ember(_figure: BrannFigure) -> void:
	var meshes := _skeleton.find_children("*", "MeshInstance3D", false, false)
	if meshes.is_empty():
		return
	var instance := meshes[0] as MeshInstance3D
	for s in instance.mesh.get_surface_count():
		var material := instance.mesh.surface_get_material(s) as ShaderMaterial
		if material == null:
			continue
		var emission: Variant = material.get_shader_parameter(&"emission_value")
		if emission == null or not is_equal_approx(float(emission), BrannVoxelDesign.GLOW_EMISSION):
			continue
		if _glow == null:
			_glow = material.duplicate() as ShaderMaterial
		instance.set_surface_override_material(s, _glow)
