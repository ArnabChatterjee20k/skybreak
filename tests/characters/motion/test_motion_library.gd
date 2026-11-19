extends GutTest

const LIBRARY_PATH := "res://game/characters/motion/motion_library.res"
const MODEL_PATH := "res://game/characters/kael_chunky/kael_chunky.glb"
const MOVE_DIR := "res://game/combat/moves/kael/"
const METRICS := preload("res://game/characters/motion/tools/motion_metrics.gd")
const PEAK_TOLERANCE_TICKS := 2
const STARTER_CLIPS: Array[StringName] = [&"fight_idle", &"idle_breathe", &"walk", &"run", &"strafe_left",
	&"strafe_right", &"walk_back", &"turn_in_place", &"dash_start", &"dash_stop", &"jump", &"land",
	&"heavy_land", &"hover", &"fly", &"bank_left", &"bank_right", &"dive", &"guard", &"block_hit",
	&"hit_light", &"hit_heavy", &"ko_fall", &"fall_face", &"get_up", &"get_up_face_down", &"tech", &"grab",
	&"throw"]
const BODY: Array[StringName] = [&"Hips", &"Spine", &"Chest", &"UpperChest", &"Neck", &"Head",
	&"LeftShoulder", &"LeftUpperArm", &"LeftLowerArm", &"LeftHand", &"RightShoulder", &"RightUpperArm",
	&"RightLowerArm", &"RightHand", &"LeftUpperLeg", &"LeftLowerLeg", &"LeftFoot", &"LeftToes",
	&"RightUpperLeg", &"RightLowerLeg", &"RightFoot", &"RightToes"]

var _library: MotionLibrary
var _model: Node3D
var _skeleton: Skeleton3D


func before_all() -> void:
	_model = (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	add_child(_model)
	_skeleton = _model.get_node("%GeneralSkeleton") as Skeleton3D
	# As CharacterView plays it: hips heights fitted to the rig (the mixer scales them by motion_scale).
	_library = MotionClips.for_skeleton(load(LIBRARY_PATH) as MotionLibrary, _skeleton)


func after_all() -> void:
	_model.free()


func _moves() -> Array[MoveData]:
	var moves: Array[MoveData] = []
	for id: StringName in _library.strike_bones:
		moves.append(load(MOVE_DIR + String(id) + ".tres") as MoveData)
	return moves


## A bone's head in Kael's view space (turned 180 degrees, lowered 1 m) for a clip time.
func _bone_in_view(clip: StringName, time: float, bone: StringName) -> Vector3:
	METRICS.apply_clip(_skeleton, _library.get_animation(clip), time)
	var pose := METRICS._global_pose(_skeleton, _skeleton.find_bone(bone))
	return Vector3(-pose.origin.x, pose.origin.y - 1.0, -pose.origin.z)


func test_the_library_is_a_motion_library_with_the_starter_clips() -> void:
	assert_not_null(_library)
	for clip in STARTER_CLIPS:
		assert_true(_library.has_animation(clip), "has %s" % clip)
	assert_eq(_library.strike_bones.size(), 14, "every Kael move with a strike bone has a mocap clip")


func test_every_clip_drives_every_body_bone_of_the_humanoid_profile() -> void:
	for clip in _library.get_animation_list():
		var animation := _library.get_animation(clip)
		for bone in BODY:
			assert_ne(animation.find_track(NodePath("%GeneralSkeleton:" + bone), Animation.TYPE_ROTATION_3D), -1,
				"%s drives %s" % [clip, bone])
		for track in animation.get_track_count():
			var path := String(animation.track_get_path(track))
			assert_eq(path.get_slice(":", 0), "%GeneralSkeleton")
			assert_ne(_skeleton.find_bone(path.get_slice(":", 1)), -1, "%s: %s is on Kael" % [clip, path])


func test_no_clip_has_nans_or_unnormalised_rotations() -> void:
	for clip in _library.get_animation_list():
		var animation := _library.get_animation(clip)
		var bad := 0
		for track in animation.get_track_count():
			for key in animation.track_get_key_count(track):
				var value: Variant = animation.track_get_key_value(track, key)
				if value is Quaternion:
					var q: Quaternion = value
					if not q.is_finite() or absf(q.length() - 1.0) > 0.001:
						bad += 1
				elif not (value as Vector3).is_finite():
					bad += 1
		assert_eq(bad, 0, "%s keys are finite and normalised" % clip)


func test_the_stance_is_grounded_upright_and_facing_forward() -> void:
	for clip: StringName in [&"fight_idle", &"guard", &"idle_breathe"]:
		var length := _library.get_animation(clip).length
		for k in 5:
			var t := length * k / 4.0
			var left := _bone_in_view(clip, t, &"LeftFoot")
			var right := _bone_in_view(clip, t, &"RightFoot")
			var head := _bone_in_view(clip, t, &"Head")
			assert_gt(minf(left.y, right.y), -1.0, "%s feet stay above the floor" % clip)
			assert_lt(minf(left.y, right.y), -0.8, "%s keeps a foot near the floor" % clip)
			assert_gt(head.y, 0.2, "%s head stays up" % clip)
		var toes := _bone_in_view(clip, 0.0, &"LeftToes")
		var heel := _bone_in_view(clip, 0.0, &"LeftFoot")
		assert_lt(toes.z, heel.z + 0.05, "%s faces -Z" % clip)


func test_loops_end_where_they_start() -> void:
	for clip in _library.get_animation_list():
		var animation := _library.get_animation(clip)
		if animation.loop_mode == Animation.LOOP_NONE:
			continue
		for track in animation.get_track_count():
			if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
				continue
			var first: Quaternion = animation.track_get_key_value(track, 0)
			var last: Quaternion = animation.track_get_key_value(track, animation.track_get_key_count(track) - 1)
			assert_lt(first.angle_to(last), 0.01, "%s %s loops seamlessly" % [clip, animation.track_get_path(track)])


func test_attack_clips_last_exactly_the_move() -> void:
	for move in _moves():
		assert_almost_eq(_library.get_animation(move.id).length, move.total_ticks() / 60.0, 0.001,
			"%s mocap clip lasts the move" % move.id)


func test_each_mocap_strike_peaks_inside_its_active_ticks() -> void:
	for move in _moves():
		var bone: StringName = _library.strike_bones[move.id]
		var target := Vector3.ZERO
		for tick in move.active_ticks:
			target += move.hitbox_offsets[mini(tick, move.hitbox_offsets.size() - 1)]
		target /= move.active_ticks
		var best_tick := -1
		var best := INF
		for tick in move.total_ticks():
			var distance := _bone_in_view(move.id, tick / 60.0, bone).distance_to(target)
			if distance < best:
				best = distance
				best_tick = tick
		assert_between(best_tick, move.startup_ticks - PEAK_TOLERANCE_TICKS,
			move.recovery_start_tick() - 1 + PEAK_TOLERANCE_TICKS,
			"%s: %s is closest to the hitbox on tick %d (active %d-%d)" % [move.id, bone, best_tick,
			move.startup_ticks, move.recovery_start_tick() - 1])


func test_root_curves_and_contacts_cover_every_frame() -> void:
	for clip in _library.get_animation_list():
		var frames := roundi(_library.get_animation(clip).length * MotionLibrary.FPS) + 1
		assert_eq(_library.root_motion[clip].size(), frames, "%s root curve" % clip)
		assert_eq(_library.foot_contacts[clip].size(), frames, "%s contacts" % clip)
	var run_travel := _library.root_at(&"run", _library.get_animation(&"run").length)
	assert_gt(Vector2(run_travel.x, run_travel.y).length(), 1.0, "the run's travel is in its root curve")


func test_planted_feet_stay_put() -> void:
	for clip: StringName in [&"fight_idle", &"light_2", &"smash", &"block_hit"]:
		var length := _library.get_animation(clip).length
		for left in [true, false]:
			var bone := &"LeftFoot" if left else &"RightFoot"
			var last := Vector3.INF
			var worst := 0.0
			for f in roundi(length * 60.0) + 1:
				var t := f / 60.0
				if not _library.is_planted(clip, t, left):
					last = Vector3.INF
					continue
				var p := _bone_in_view(clip, t, bone)
				if last != Vector3.INF:
					worst = maxf(worst, Vector2(p.x - last.x, p.z - last.z).length())
				last = p
			assert_lt(worst, 0.02, "%s %s slides under 2 cm per frame while planted" % [clip, bone])
