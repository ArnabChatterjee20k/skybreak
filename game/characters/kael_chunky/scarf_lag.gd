class_name ScarfLag
extends SkeletonModifier3D
## Secondary motion for a bone chain (Kael's scarf tail): the chain trails behind the body's
## motion in world space and springs back to its animated pose. Fixed 60 Hz steps, so the same
## animation and frame times give the same scarf. Runs after the AnimationPlayer has posed the
## skeleton; the chain bones themselves are never keyed.

const STEP := 1.0 / 60.0
## At most this many steps per frame, so a long hitch doesn't stall the frame.
const MAX_STEPS := 4

@export var bones: Array[StringName] = [&"Scarf1", &"Scarf2", &"Scarf3", &"Scarf4", &"Scarf5"]
## Fraction of the way back to the animated pose per step.
@export_range(0.0, 1.0) var stiffness := 0.12
## Velocity kept per step.
@export_range(0.0, 1.0) var damping := 0.86
## Downward pull, m/s^2, on top of the spring.
@export var gravity := 3.0
## How far the rest shape droops toward straight down (0 = rigid with the chest, 1 = plumb), so
## the scarf hangs instead of sticking out when he leans.
@export_range(0.0, 1.0) var hang := 0.65

var _bone_ids: PackedInt32Array = []
## Each bone's tail in its own rest frame.
var _tails: PackedVector3Array = []
var _lengths: PackedFloat32Array = []
var _points: PackedVector3Array = []
var _previous: PackedVector3Array = []
var _accumulator := 0.0


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or not _ensure_chain(skeleton):
		return
	var to_world := skeleton.global_transform
	advance(_targets(skeleton, to_world), delta)
	_apply(skeleton, to_world)


## Steps the chain toward the target joint positions (world space) for delta seconds and
## returns the joint positions. Pure apart from the chain state, for tests.
func advance(targets: PackedVector3Array, delta: float) -> PackedVector3Array:
	if _points.size() != targets.size():
		_points = targets.duplicate()
		_previous = targets.duplicate()
		_lengths.resize(targets.size() - 1)
		for i in _lengths.size():
			_lengths[i] = targets[i].distance_to(targets[i + 1])
	_accumulator = minf(_accumulator + delta, STEP * MAX_STEPS)
	while _accumulator >= STEP - 0.000001:
		_accumulator -= STEP
		_step(targets)
	return _points


## Clears the chain so it snaps to the next targets.
func reset_chain() -> void:
	_points = []
	_previous = []
	_accumulator = 0.0


func _step(targets: PackedVector3Array) -> void:
	_points[0] = targets[0]
	_previous[0] = targets[0]
	for i in range(1, _points.size()):
		var velocity := (_points[i] - _previous[i]) * damping
		_previous[i] = _points[i]
		var pull := (targets[i] - _points[i]) * stiffness
		_points[i] += velocity + pull + Vector3.DOWN * gravity * STEP * STEP
		# Keep each segment's length.
		var segment := _points[i] - _points[i - 1]
		_points[i] = _points[i - 1] + segment.normalized() * _lengths[i - 1] if segment.length() > 0.0001 \
			else targets[i]


func _ensure_chain(skeleton: Skeleton3D) -> bool:
	if _bone_ids.size() == bones.size():
		return true
	_bone_ids.clear()
	_tails.clear()
	for bone in bones:
		var id := skeleton.find_bone(bone)
		if id < 0:
			return false
		_bone_ids.append(id)
	for i in _bone_ids.size():
		var rest := skeleton.get_bone_global_rest(_bone_ids[i])
		var tail: Vector3
		if i + 1 < _bone_ids.size():
			tail = skeleton.get_bone_global_rest(_bone_ids[i + 1]).origin
		else:
			var before := skeleton.get_bone_global_rest(_bone_ids[i - 1]).origin
			tail = rest.origin + (rest.origin - before)
		_tails.append(rest.affine_inverse() * tail)
	return true


## Joint positions of the animated chain (world space): every bone's head, then the last tail.
func _targets(skeleton: Skeleton3D, to_world: Transform3D) -> PackedVector3Array:
	var animated := PackedVector3Array()
	for i in _bone_ids.size():
		animated.append(to_world * skeleton.get_bone_global_pose(_bone_ids[i]).origin)
	var last := skeleton.get_bone_global_pose(_bone_ids[-1])
	animated.append(to_world * (last * _tails[-1]))
	return droop(animated, hang)


## The chain re-laid from its root with each segment turned toward straight down by amount.
static func droop(chain: PackedVector3Array, amount: float) -> PackedVector3Array:
	var out := PackedVector3Array([chain[0]])
	for i in range(1, chain.size()):
		var segment := chain[i] - chain[i - 1]
		var length := segment.length()
		var direction := segment.normalized().lerp(Vector3.DOWN, amount)
		if direction.length() < 0.0001:
			direction = Vector3.DOWN
		out.append(out[i - 1] + direction.normalized() * length)
	return out


## Turns each chain bone so its tail points at the next simulated joint.
func _apply(skeleton: Skeleton3D, to_world: Transform3D) -> void:
	var to_skeleton := to_world.affine_inverse()
	var parent_id := skeleton.get_bone_parent(_bone_ids[0])
	var parent := skeleton.get_bone_global_pose(parent_id) if parent_id >= 0 else Transform3D()
	for i in _bone_ids.size():
		var id := _bone_ids[i]
		var global := parent * skeleton.get_bone_pose(id)
		var current := global.basis * _tails[i]
		var wanted := to_skeleton * _points[i + 1] - global.origin
		if current.length() > 0.0001 and wanted.length() > 0.0001:
			var turn := Quaternion(current.normalized(), wanted.normalized())
			global.basis = Basis(turn) * global.basis
		var local := parent.affine_inverse() * global
		skeleton.set_bone_pose_rotation(id, local.basis.get_rotation_quaternion())
		parent = parent * Transform3D(Basis(local.basis.get_rotation_quaternion()), local.origin)
