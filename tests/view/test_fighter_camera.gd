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
