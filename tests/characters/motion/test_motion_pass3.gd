extends GutTest
## Motion pass 3 (T-D22d): regressions for the causes the QA harness found in real matches.

const MODEL_PATH := "res://game/characters/kael_chunky/kael_chunky.glb"
const DT := 1.0 / 60.0

var _layers: MotionLayers
var _rest: Array[Quaternion] = []
var _hips := Vector3.ZERO
var _foot := -1


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
	_foot = skeleton.find_bone(&"LeftFoot")
	model.free()
	_layers = MotionLayers.new()
	_layers.setup_bones(names, parents, rests)


func after_each() -> void:
	_layers.free()


func _ankle(rotations: Array[Quaternion], hips: Vector3) -> Vector3:
	_layers._world_cache.clear()
	return _layers._world_at(rotations, hips, _foot).origin


func test_a_fighter_standing_on_raised_terrain_is_not_airborne() -> void:
	var fighter := FighterState.new()
	fighter.stand_height = 13.0
	fighter.position = Vector3(0, 13.0, 0)
	assert_false(CharacterView.is_airborne(fighter), "standing on a 12 m hill")
	fighter.position.y = 14.0
	assert_true(CharacterView.is_airborne(fighter), "a metre above the hill")


func test_switching_clips_every_frame_does_not_stack_the_layers() -> void:
	# The AI can flip IDLE and BLOCKING every tick; each switch re-inertializes. Blending from the
	# last output (not the clip pose) re-applied lean and crouch on top of themselves each frame.
	_layers.velocity = Vector3(0, 0, 6)
	_layers.crouch = 0.06
	var once: Vector3
	for frame in 120:
		var pose: Array[Quaternion] = _rest.duplicate()
		var hips := _layers.process_pose(pose, _hips, DT)
		if frame == 60:
			once = _ankle(pose, hips)
	for frame in 120:
		_layers.inertialize()
		var pose: Array[Quaternion] = _rest.duplicate()
		var hips := _layers.process_pose(pose, _hips, DT)
		if frame == 119:
			assert_lt(_ankle(pose, hips).distance_to(once), 0.03, "the feet stay where one switch puts them")


func test_a_planted_foot_stays_put_while_the_body_turns() -> void:
	_layers.foot_lock = true
	var start := Vector3.ZERO
	var worst := 0.0
	for frame in 30:
		# The body turns 1 degree a frame about its centre, as an idle fighter tracking a target.
		_layers.body_to_world = Transform3D(Basis(Vector3.UP, deg_to_rad(frame)), Vector3.ZERO)
		var pose: Array[Quaternion] = _rest.duplicate()
		var hips := _layers.process_pose(pose, _hips, DT)
		var world := _layers.body_to_world * _ankle(pose, hips)
		if frame == 0:
			start = world
		worst = maxf(worst, Vector2(world.x - start.x, world.z - start.z).length())
	assert_lt(worst, 0.01, "the locked foot does not slide (m)")


func test_a_skeleton_update_without_a_new_frame_reuses_the_last_output() -> void:
	var model := (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	add_child_autofree(model)
	var skeleton := model.get_node("%GeneralSkeleton") as Skeleton3D
	var layers := MotionLayers.new()
	skeleton.add_child(layers)
	layers.velocity = Vector3(0, 0, 8)
	var hand := skeleton.find_bone(&"RightLowerArm")
	var outputs: Array[Quaternion] = []
	skeleton.skeleton_updated.connect(func() -> void:
		outputs.append(skeleton.get_bone_global_pose(hand).basis.get_rotation_quaternion()))
	layers.advance_frame(DT)
	layers._process_modification_with_delta(0.0)
	var first := skeleton.get_bone_pose_rotation(hand)
	var stepped := layers.lean
	layers._process_modification_with_delta(0.016)
	assert_eq(layers.lean, stepped, "a second pass in the same frame does not step the springs")
	assert_true(skeleton.get_bone_pose_rotation(hand).is_equal_approx(first), "and writes the same pose")
