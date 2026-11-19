extends GutTest

const MODEL_PATH := "res://game/characters/kael_chunky/kael_chunky.glb"
const DT := 1.0 / 60.0

var _layers: MotionLayers
var _rest: Array[Quaternion] = []
var _hips := Vector3.ZERO


func before_each() -> void:
	var model := (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	var skeleton := model.get_node("%GeneralSkeleton") as Skeleton3D
	var names := PackedStringArray()
	var parents := PackedInt32Array()
	var rests: Array[Transform3D] = []
	_rest.clear()
	for i in skeleton.get_bone_count():
		names.append(skeleton.get_bone_name(i))
		parents.append(skeleton.get_bone_parent(i))
		rests.append(skeleton.get_bone_rest(i))
		_rest.append(skeleton.get_bone_rest(i).basis.get_rotation_quaternion())
	_hips = skeleton.get_bone_rest(skeleton.find_bone(&"Hips")).origin
	model.free()
	_layers = MotionLayers.new()
	_layers.setup_bones(names, parents, rests)


func after_each() -> void:
	_layers.free()


func _pose(bend: float) -> Array[Quaternion]:
	var pose: Array[Quaternion] = _rest.duplicate()
	for i in pose.size():
		pose[i] = Quaternion(Vector3.RIGHT, bend * (0.3 + 0.1 * (i % 5))) * pose[i]
	return pose


func _max_angle(a: Array[Quaternion], b: Array[Quaternion]) -> float:
	var worst := 0.0
	for i in a.size():
		worst = maxf(worst, a[i].angle_to(b[i]))
	return worst


func test_layers_stay_finite_and_bounded_for_a_minute_of_chaos() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 22
	var worst := 0.0
	var finite := true
	for tick in 3600:
		_layers.velocity = Vector3(rng.randf_range(-30, 30), rng.randf_range(-20, 20), rng.randf_range(-30, 30)) \
			if tick % 7 == 0 else _layers.velocity
		_layers.flying = (tick / 300) % 2 == 1
		_layers.look_weight = 1.0
		_layers.look_target = Vector3(rng.randf_range(-5, 5), rng.randf_range(0, 3), rng.randf_range(-5, 5))
		if tick % 23 == 0:
			_layers.flinch(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)), rng.randf_range(0.5, 3.0))
		if tick % 97 == 0:
			_layers.land(rng.randf_range(0.5, 2.0))
		if tick % 41 == 0:
			_layers.inertialize()
		var pose := _pose(sin(tick * 0.05) + (1.0 if tick % 82 < 41 else -1.0) * 0.4)
		var source := pose.duplicate()
		var delta := DT * rng.randf_range(0.5, 2.0)
		var hips := _layers.process_pose(pose, _hips, delta)
		finite = finite and hips.is_finite()
		for q in pose:
			finite = finite and q.is_finite() and absf(q.length() - 1.0) < 0.001
		worst = maxf(worst, _max_angle(pose, source))
	assert_true(finite, "every output is finite and normalised")
	assert_lt(worst, deg_to_rad(150.0), "layers never spin a bone off (worst %.0f deg)" % rad_to_deg(worst))


func test_inertialization_starts_from_the_old_pose_and_converges_to_the_new_one() -> void:
	_layers.foot_ik = false
	var old_pose := _pose(0.0)
	var new_pose := _pose(0.8)
	var out: Array[Quaternion] = []
	for tick in 30:
		out = old_pose.duplicate()
		_layers.process_pose(out, _hips, DT)
	_layers.inertialize()
	var first: Array[Quaternion] = new_pose.duplicate()
	_layers.process_pose(first, _hips, DT)
	assert_lt(_max_angle(first, out), 0.01, "the first blended frame continues the old pose (no pop)")
	var previous := first
	var largest_step := 0.0
	for tick in 60:
		var frame: Array[Quaternion] = new_pose.duplicate()
		_layers.process_pose(frame, _hips, DT)
		largest_step = maxf(largest_step, _max_angle(frame, previous))
		previous = frame
	assert_lt(largest_step, _max_angle(old_pose, new_pose) * 0.35, "it eases over several frames")
	assert_lt(_max_angle(previous, new_pose), 0.01, "and lands on the new clip within a second")


func test_inertialization_keeps_the_incoming_velocity() -> void:
	_layers.foot_ik = false
	var out: Array[Quaternion] = []
	for tick in 20:
		out = _pose(tick * 0.02)
		_layers.process_pose(out, _hips, DT)
	_layers.inertialize()
	var a: Array[Quaternion] = _pose(1.0)
	_layers.process_pose(a, _hips, DT)
	var b: Array[Quaternion] = _pose(1.0)
	_layers.process_pose(b, _hips, DT)
	assert_gt(_max_angle(b, a), 0.0, "the pose keeps moving the way it was going")


func test_acceleration_leans_the_body_and_springs_back() -> void:
	_layers.foot_ik = false
	for tick in 10:
		_layers.velocity = Vector3(0, 0, tick * 1.5)
		_layers.process_pose(_rest.duplicate(), _hips, DT)
	assert_gt(_layers.lean.x, 0.05, "leans forward into forward acceleration")
	_layers.velocity = Vector3.ZERO
	for tick in 240:
		_layers.process_pose(_rest.duplicate(), _hips, DT)
	assert_almost_eq(_layers.lean.length(), 0.0, 0.01, "settles back upright")


func test_flight_banks_into_sideways_acceleration() -> void:
	_layers.flying = true
	for tick in 20:
		_layers.velocity = Vector3(tick * 2.0, 0, 10)
		_layers.process_pose(_rest.duplicate(), _hips, DT)
	assert_gt(absf(_layers.lean.z), 0.2, "banks")


func test_a_flinch_is_additive_and_recovers() -> void:
	_layers.foot_ik = false
	_layers.flinch(Vector3(0, 0, 1), 2.0)
	var pose := _rest.duplicate()
	for tick in 4:
		pose = _rest.duplicate()
		_layers.process_pose(pose, _hips, DT)
	assert_gt(_max_angle(pose, _rest), 0.1, "the upper body snaps back")
	for tick in 120:
		pose = _rest.duplicate()
		_layers.process_pose(pose, _hips, DT)
	assert_lt(_max_angle(pose, _rest), 0.01, "and returns to the clip")


func test_foot_ik_keeps_planted_feet_on_lower_ground_with_a_pelvis_drop() -> void:
	_layers.ground = Vector2(-0.1, 0.0)
	var hips := Vector3.ZERO
	for tick in 5:
		hips = _layers.process_pose(_rest.duplicate(), _hips, DT)
	assert_lt(hips.y, _hips.y - 0.02, "the pelvis drops to reach the lower step")
