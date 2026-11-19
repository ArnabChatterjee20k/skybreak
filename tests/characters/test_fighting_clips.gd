extends GutTest

const KAEL_PATH := "res://game/characters/kael/kael.tscn"
const MOVE_SET_PATH := "res://game/combat/moves/kael/kael_move_set.tres"
const FRAME := 1.0 / 60.0
const TIMING_TOLERANCE_TICKS := 2
## Moves T-D10b remapped to authored clips.
const REMAPPED_MOVES := {&"light_4": &"roundhouse_kick", &"launcher": &"uppercut",
	&"rising": &"flip_kick", &"spike": &"axe_kick", &"sweep": &"low_sweep_kick"}
## Clips that stand on both feet the whole time.
const TWO_FOOT_CLIPS: Array[StringName] = [&"fight_stance", &"power_up", &"power_up_start"]
## Soles may dip this far (metres) below the floor: the sole points are
## an approximation of the shoe.
const FLOOR_TOLERANCE := 0.02
const KNEE_FLEX_MIN := -5.0
const KNEE_FLEX_MAX := 160.0
## Elbows may hyperextend about 10 degrees, no more.
const ELBOW_FLEX_MIN := -10.0
const ELBOW_FLEX_MAX := 155.0
## A hinge joint may leave its bending plane by this much (degrees).
const HINGE_OFF_PLANE_MAX := 15.0
## Largest rotation from rest for the rest of the body (degrees).
const SPINE_MAX := 50.0
const HIP_MAX := 140.0
const FOOT_MAX := 70.0
## Ankle height (metres above the floor) of a kick at impact.
const KICK_HEIGHT := 0.6
## The sweep's ankle: out from the hips, near the floor.
const SWEEP_REACH := 0.7
const SWEEP_HEIGHT := 0.3
const SPINE_BONES: Array[StringName] = [&"Spine", &"Chest", &"UpperChest", &"Neck", &"Head"]

var _view: CharacterView
var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _fighter: FighterState


func before_each() -> void:
	_view = (load(KAEL_PATH) as PackedScene).instantiate() as CharacterView
	add_child_autofree(_view)
	_player = _view.get_node("AnimationPlayer") as AnimationPlayer
	_skeleton = _view.model.get_node("%GeneralSkeleton") as Skeleton3D
	_fighter = FighterState.new()


func _authored() -> Array[StringName]:
	var clips: Array[StringName] = []
	clips.assign(FightingClips.definitions().keys())
	return clips


func _move(move_id: StringName) -> MoveData:
	var move_set := load(MOVE_SET_PATH) as MoveSet
	var moves: Array[MoveData] = []
	moves.append_array(move_set.light_string)
	moves.append_array([move_set.launcher, move_set.rising, move_set.spike, move_set.sweep])
	for move in moves:
		if move.id == move_id:
			return move
	return null


## Poses the skeleton at a frame of a clip.
func _pose(clip: StringName, frame: int) -> void:
	_player.play(StringName("%s/%s" % [CharacterView.LIBRARY_NAME, clip]), 0.0)
	_player.seek(frame * FRAME, true)


func _frames(clip: StringName) -> int:
	return roundi(_view.clips.library.get_animation(clip).length / FRAME)


## Bone transform in skeleton space from the local poses just applied.
func _global_pose(bone: StringName) -> Transform3D:
	var index := _skeleton.find_bone(bone)
	var pose := _skeleton.get_bone_pose(index)
	var parent := _skeleton.get_bone_parent(index)
	while parent >= 0:
		pose = _skeleton.get_bone_pose(parent) * pose
		parent = _skeleton.get_bone_parent(parent)
	return pose


func _sole_height(side: String) -> float:
	var lowest := INF
	for sole: Array in FightingClips.sole_points(_skeleton, side):
		lowest = minf(lowest, (_global_pose(StringName(sole[0])) * (sole[1] as Vector3)).y)
	return lowest


## Rotation of a bone relative to rest, in body axes.
func _body(bone: StringName) -> Basis:
	return FightingClips.to_body(bone, _skeleton.get_bone_pose_rotation(_skeleton.find_bone(bone)))


func _angle_from_rest(bone: StringName) -> float:
	var angle := rad_to_deg(_body(bone).get_rotation_quaternion().get_angle())
	return minf(angle, 360.0 - angle)


func test_every_authored_clip_is_in_the_library() -> void:
	for clip in _authored():
		assert_true(_view.clips.library.has_animation(clip), "library has %s" % clip)


func test_authored_clips_only_animate_the_humanoid_skeleton() -> void:
	for clip in _authored():
		var animation := _view.clips.library.get_animation(clip)
		assert_gt(animation.get_track_count(), 0, "%s has tracks" % clip)
		for track in animation.get_track_count():
			assert_eq(String(animation.track_get_path(track)).get_slice(":", 0), "%GeneralSkeleton",
				"%s track %d targets the retargeted skeleton" % [clip, track])


func test_authored_clips_have_no_root_motion() -> void:
	for clip in _authored():
		var animation := _view.clips.library.get_animation(clip)
		var track := animation.find_track(NodePath("%GeneralSkeleton:Hips"), Animation.TYPE_POSITION_3D)
		assert_gte(track, 0, "%s keys the hips height" % clip)
		var first: Vector3 = animation.track_get_key_value(track, 0)
		for key in animation.track_get_key_count(track):
			var value: Vector3 = animation.track_get_key_value(track, key)
			assert_almost_eq(Vector2(value.x, value.z), Vector2(first.x, first.z), Vector2(0.0001, 0.0001),
				"%s hips X/Z pinned" % clip)


func test_strike_clips_are_timed_tick_for_tick_to_their_move() -> void:
	for move_id: StringName in REMAPPED_MOVES:
		var move := _move(move_id)
		var clip: StringName = REMAPPED_MOVES[move_id]
		var window: Vector2 = _view.clips.impact_windows.get(clip, Vector2(-1, -1))
		assert_almost_eq(window.x, move.startup_ticks * FRAME, 0.001, "%s impact starts after STARTUP" % clip)
		assert_almost_eq(window.y, move.recovery_start_tick() * FRAME, 0.001, "%s impact spans ACTIVE" % clip)
		assert_eq(_frames(clip), move.total_ticks(), "%s lasts the whole move" % clip)


func test_remapped_moves_land_on_their_active_ticks() -> void:
	for move_id: StringName in REMAPPED_MOVES:
		var move := _move(move_id)
		var clip := _view.clips.clip_for_move(move_id)
		var window: Vector2 = _view.clips.impact_windows[clip]
		_fighter.begin_move(move)
		var first := -1
		var last := -1
		for tick in move.total_ticks():
			_fighter.move_tick = tick
			_view.apply_state(_fighter, 0.0)
			var time := _view.current_clip_time()
			if time >= window.x - 0.0001 and time <= window.y + 0.0001:
				if first < 0:
					first = tick
				last = tick
		assert_almost_eq(first, move.startup_ticks, TIMING_TOLERANCE_TICKS, "%s lands on the first ACTIVE tick" % move_id)
		assert_almost_eq(last, move.recovery_start_tick() - 1, TIMING_TOLERANCE_TICKS,
			"%s holds through the last ACTIVE tick" % move_id)


## The hips may keep turning through a spin or a flip; the limbs hold.
func test_the_impact_pose_is_held_through_the_active_ticks() -> void:
	for clip: StringName in REMAPPED_MOVES.values():
		var impact: Vector2i = FightingClips.definitions()[clip].impact
		_pose(clip, impact.x)
		var start := {}
		for bone in FightingClips.BODY_BONES:
			start[bone] = _skeleton.get_bone_pose_rotation(_skeleton.find_bone(bone))
		_pose(clip, impact.y)
		for bone in FightingClips.BODY_BONES:
			if bone == &"Hips":
				continue
			var now := _skeleton.get_bone_pose_rotation(_skeleton.find_bone(bone))
			assert_lt(rad_to_deg(now.angle_to(start[bone])), 25.0, "%s %s stays near its impact pose" % [clip, bone])


func test_knees_bend_one_way_only() -> void:
	for clip in _authored():
		for frame in _frames(clip) + 1:
			_pose(clip, frame)
			for side in ["Left", "Right"]:
				var shin := _body(StringName(side + "LowerLeg")) * Vector3.DOWN
				var flex := rad_to_deg(atan2(-shin.z, -shin.y))
				var off_plane := rad_to_deg(asin(clampf(shin.x, -1.0, 1.0)))
				if flex < KNEE_FLEX_MIN or flex > KNEE_FLEX_MAX or absf(off_plane) > HINGE_OFF_PLANE_MAX:
					fail_test("%s frame %d %s knee: flex %.0f, off plane %.0f" % [clip, frame, side, flex, off_plane])
					return
	pass_test("every knee bends forward within %d-%d degrees" % [KNEE_FLEX_MIN, KNEE_FLEX_MAX])


func test_elbows_never_hyperextend() -> void:
	for clip in _authored():
		for frame in _frames(clip) + 1:
			_pose(clip, frame)
			for side in ["Left", "Right"]:
				var out := 1.0 if side == "Left" else -1.0
				var forearm := _body(StringName(side + "LowerArm")) * Vector3(out, 0, 0)
				var flex := rad_to_deg(atan2(forearm.z, forearm.x * out))
				var off_plane := rad_to_deg(asin(clampf(forearm.y, -1.0, 1.0)))
				if flex < ELBOW_FLEX_MIN or flex > ELBOW_FLEX_MAX or absf(off_plane) > HINGE_OFF_PLANE_MAX:
					fail_test("%s frame %d %s elbow: flex %.0f, off plane %.0f" % [clip, frame, side, flex, off_plane])
					return
	pass_test("every elbow stays within %d-%d degrees" % [ELBOW_FLEX_MIN, ELBOW_FLEX_MAX])


func test_spine_hips_and_feet_stay_in_human_range() -> void:
	for clip in _authored():
		for frame in _frames(clip) + 1:
			_pose(clip, frame)
			var limits := {}
			for bone in SPINE_BONES:
				limits[bone] = SPINE_MAX
			for side in ["Left", "Right"]:
				limits[StringName(side + "UpperLeg")] = HIP_MAX
				limits[StringName(side + "Foot")] = FOOT_MAX
			for bone: StringName in limits:
				var angle := _angle_from_rest(bone)
				if angle > limits[bone]:
					fail_test("%s frame %d: %s turns %.0f degrees (max %.0f)" % [clip, frame, bone, angle, limits[bone]])
					return
	pass_test("spine, hips and feet stay in range")


func test_feet_never_sink_through_the_floor() -> void:
	for clip in FightingClips.grounded_clips():
		for frame in _frames(clip) + 1:
			_pose(clip, frame)
			var lowest := minf(_sole_height("Left"), _sole_height("Right"))
			if lowest < -FLOOR_TOLERANCE:
				fail_test("%s frame %d: a sole is %.3f m below the floor" % [clip, frame, -lowest])
				return
	pass_test("no grounded clip sinks a foot")


func test_stance_clips_keep_both_feet_on_the_floor() -> void:
	for clip in TWO_FOOT_CLIPS:
		for frame in _frames(clip) + 1:
			_pose(clip, frame)
			for side in ["Left", "Right"]:
				assert_almost_eq(_sole_height(side), 0.0, FLOOR_TOLERANCE, "%s frame %d %s foot on the floor" % [clip, frame, side])


## At impact the kicking foot is up at the target (above the knees of a
## standing fighter), or for the sweep out along the floor.
func test_kicks_extend_a_foot_on_their_impact_frame() -> void:
	var kicks: Array[StringName] = [&"front_kick", &"roundhouse_kick", &"axe_kick", &"flip_kick", &"knee_strike"]
	for clip in kicks + [&"low_sweep_kick"]:
		var impact: Vector2i = FightingClips.definitions()[clip].impact
		_pose(clip, impact.x)
		var hips := _global_pose(&"Hips").origin
		var height := 0.0
		var reach := 0.0
		for side in ["Left", "Right"]:
			var foot := _global_pose(StringName(side + "Foot")).origin
			height = maxf(height, foot.y)
			reach = maxf(reach, Vector2(foot.x - hips.x, foot.z - hips.z).length())
		if clip == &"low_sweep_kick":
			assert_gt(reach, SWEEP_REACH, "the sweep's foot reaches out from the hips")
			assert_lt(height, SWEEP_HEIGHT, "the sweep stays low")
		else:
			assert_gt(height, KICK_HEIGHT, "%s raises a foot to the target" % clip)


func test_clip_set_picks_the_authored_clips() -> void:
	var expected := {&"IDLE": &"fight_stance", &"CHARGING": &"power_up", &"FLYING": &"fly_hover"}
	for state_name: StringName in expected:
		assert_eq(_view.clips.clip_for_state(state_name), expected[state_name])
	assert_eq(_view.clips.fly_fast_clip, &"fly_forward")
	assert_eq(_view.clips.charge_hold_clip, &"power_up")
	assert_eq(_view.clips.clip_for_state(&"DASHING", true), &"air_dash")
	assert_eq(_view.clips.clip_for_state(&"VANISHING", true), &"air_dash")
	assert_eq(_view.clips.clip_for_state(&"DASHING", false), &"dash", "the ground keeps the ground dash")
	for move_id: StringName in REMAPPED_MOVES:
		assert_eq(_view.clips.clip_for_move(move_id), REMAPPED_MOVES[move_id])


func test_idle_and_flight_play_the_authored_clips() -> void:
	_fighter.enter_state(FighterState.State.IDLE)
	_fighter.position.y = 1.0
	_view.apply_state(_fighter, FRAME)
	assert_eq(_view.current_clip(), &"fight_stance")
	_fighter.enter_state(FighterState.State.FLYING)
	_fighter.position.y = 6.0
	_view.apply_state(_fighter, FRAME)
	assert_eq(_view.current_clip(), &"fly_hover")
	_fighter.velocity = Vector3(0, 0, -25)
	_view.apply_state(_fighter, FRAME)
	assert_eq(_view.current_clip(), &"fly_forward")


func test_dashing_in_the_air_plays_the_air_dash() -> void:
	_fighter.enter_state(FighterState.State.DASHING)
	_fighter.position.y = 1.0
	_view.apply_state(_fighter, FRAME)
	assert_eq(_view.current_clip(), &"dash", "on the ground")
	_fighter.position.y = 5.0
	_view.apply_state(_fighter, FRAME)
	assert_eq(_view.current_clip(), &"air_dash", "in the air")


func test_charging_enters_through_the_power_up_start() -> void:
	_fighter.enter_state(FighterState.State.CHARGING)
	_view.apply_state(_fighter, FRAME)
	assert_eq(_view.current_clip(), &"power_up_start")
	var intro_ticks := ceili(_view.clips.library.get_animation(&"power_up_start").length / FRAME)
	for tick in intro_ticks + 1:
		_fighter.state_ticks = tick
		_view.apply_state(_fighter, FRAME)
	assert_eq(_view.current_clip(), &"power_up", "then loops the power-up")
	assert_eq(_view.clips.library.get_animation(&"power_up").loop_mode, Animation.LOOP_LINEAR)


func test_looping_clips_end_where_they_start() -> void:
	for clip in _authored():
		var animation := _view.clips.library.get_animation(clip)
		if animation.loop_mode == Animation.LOOP_NONE:
			continue
		_pose(clip, 0)
		var start := {}
		for bone in FightingClips.BODY_BONES:
			start[bone] = _skeleton.get_bone_pose_rotation(_skeleton.find_bone(bone))
		_player.seek(animation.length - 0.0001, true)
		for bone in FightingClips.BODY_BONES:
			var now := _skeleton.get_bone_pose_rotation(_skeleton.find_bone(bone))
			assert_lt(rad_to_deg(now.angle_to(start[bone])), 3.0, "%s %s loops seamlessly" % [clip, bone])
