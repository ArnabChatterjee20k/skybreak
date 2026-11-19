extends GutTest

var _camera: FighterCamera


func before_each() -> void:
	_camera = add_child_autofree(FighterCamera.new())


func test_first_follow_snaps_to_the_goal_pose() -> void:
	var player := Vector3(3, 2, 1)
	_camera.follow(player, Vector3.ZERO, false, 1.0 / 60.0)
	var goal := LockOnFraming.free_pose(player, _camera.free_yaw, _camera.free_pitch)
	assert_almost_eq(_camera.global_position.distance_to(goal.origin), 0.0, 0.001)


func test_follow_converges_on_the_locked_pose() -> void:
	var player := Vector3.ZERO
	var target := Vector3(0, 0, -15)
	_camera.follow(player, target, false, 1.0 / 60.0)
	for _frame in 240:
		_camera.follow(player, target, true, 1.0 / 60.0)
	var goal := LockOnFraming.locked_pose(player, target, 1.0, Vector2.ZERO)
	assert_almost_eq(_camera.global_position.distance_to(goal.origin), 0.0, 0.01)


func test_mouse_orbit_is_clamped_and_springs_back_when_mouse_stops() -> void:
	_camera.add_mouse_motion(Vector2(-100000, 0))
	assert_almost_eq(_camera.orbit.x, LockOnFraming.MAX_ORBIT_YAW, 0.0001)
	for _frame in 180:
		_camera.follow(Vector3.ZERO, Vector3(0, 0, -10), true, 1.0 / 60.0)
	assert_almost_eq(_camera.orbit.x, 0.0, 0.01)


func test_orbit_holds_while_the_mouse_keeps_moving() -> void:
	_camera.add_mouse_motion(Vector2(-100, 0))
	var held := _camera.orbit.x
	_camera.follow(Vector3.ZERO, Vector3(0, 0, -10), true, 0.1)
	assert_almost_eq(_camera.orbit.x, held, 0.0001)


func test_fov_widens_for_a_big_height_gap_and_returns_when_unlocked() -> void:
	var player := Vector3.ZERO
	var above := Vector3(0, 60, -2)
	_camera.follow(player, above, true, 1.0 / 60.0)
	for _frame in 240:
		_camera.follow(player, above, true, 1.0 / 60.0)
	assert_almost_eq(_camera.fov, LockOnFraming.locked_fov(_camera.base_fov, player, above), 0.05)
	assert_gt(_camera.fov, _camera.base_fov)
	for _frame in 240:
		_camera.follow(player, above, false, 1.0 / 60.0)
	assert_almost_eq(_camera.fov, _camera.base_fov, 0.05)


func test_shoulder_side_is_frozen_while_turning_back_after_a_relock() -> void:
	var player := Vector3.ZERO
	var ahead := Vector3(3, 0, -15)
	for _frame in 120:
		_camera.follow(player, ahead, true, 1.0 / 60.0)
	var side := _camera.shoulder_side()
	for _frame in 10:
		_camera.follow(player, ahead, false, 1.0 / 60.0)
	# Re-lock onto an opponent behind and to the other side: the big turn starts.
	var behind := Vector3(-side * 6.0, 0, 15)
	for _frame in 20:
		_camera.follow(player, behind, true, 1.0 / 60.0)
		assert_eq(_camera.shoulder_side(), side, "no shoulder flip mid-turn")


# --- T-117b ---

func test_a_half_turn_of_the_offset_goes_around_the_player_not_over_them() -> void:
	var offset := Vector3(0, 1.5, 6)
	var goal := Vector3(0.01, 1.5, -6)
	var highest := 0.0
	for i in 120:
		offset = FighterCamera.step_offset(offset, goal, 0.2, 0.2, deg_to_rad(3.0))
		highest = maxf(highest, offset.y)
	assert_lt(highest, 1.6, "the camera never rises over the player's head")
	assert_lt(offset.distance_to(goal), 0.1, "and still arrives")


func test_offset_heading_turns_at_most_the_cap_per_step() -> void:
	var offset := FighterCamera.step_offset(Vector3(0, 0, 6), Vector3(6, 0, 0), 1.0, 1.0, deg_to_rad(3.0))
	assert_almost_eq(Vector3(0, 0, 6).angle_to(offset), deg_to_rad(3.0), 0.0001)


func test_lag_widening_starts_past_15_degrees_and_is_full_at_60() -> void:
	assert_eq(LockOnFraming.lag_widen(deg_to_rad(10.0)), 0.0)
	assert_between(LockOnFraming.lag_widen(deg_to_rad(35.0)), 0.1, 0.9)
	assert_eq(LockOnFraming.lag_widen(deg_to_rad(70.0)), 1.0)


func test_stacked_framing_takes_over_only_for_close_steep_gaps() -> void:
	var player := Vector3(0, 10, 0)
	assert_eq(LockOnFraming.stack_weight(player, player + Vector3(0, -5, -0.3)), 1.0, "5 m straight below")
	assert_eq(LockOnFraming.stack_weight(player, player + Vector3(0, -1, -8)), 0.0, "level-ish")
	assert_eq(LockOnFraming.stack_weight(player, player + Vector3(0, -60, -5)), 0.0, "far below keeps widen + arrow")
