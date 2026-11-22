extends GutTest
## Hybrid camera: side-on exchange angle for melee exchanges and beam clashes.

const DT := 1.0 / 60.0


func _camera() -> FighterCamera:
	var camera := FighterCamera.new()
	add_child_autofree(camera)
	return camera


func _run(camera: FighterCamera, a: Vector3, b: Vector3, frames: int, exchange: bool) -> float:
	var worst := 0.0
	for i in frames:
		var before := camera.global_basis.get_rotation_quaternion()
		camera.set_exchange(PackedVector3Array([a, b]) if exchange else PackedVector3Array())
		camera.follow(a, b, true, DT)
		worst = maxf(worst, rad_to_deg(before.angle_to(camera.global_basis.get_rotation_quaternion())))
	return worst


func _screen_x(camera: FighterCamera, point: Vector3) -> float:
	return (camera.global_transform.affine_inverse() * point).x


func test_a_melee_exchange_swings_side_on_with_the_player_on_the_left() -> void:
	var camera := _camera()
	var a := Vector3(0, 10, 0)
	var b := Vector3(0, 10, -2)
	_run(camera, a, b, 60, false)
	_run(camera, a, b, 90, true)
	assert_almost_eq(camera.exchange_weight(), 1.0, 0.001)
	var forward := -camera.global_basis.z
	var line := (b - a).normalized()
	assert_lt(absf(forward.dot(line)), 0.2, "looking across the fighters' line (side-on)")
	assert_lt(_screen_x(camera, a), _screen_x(camera, b), "player on the left")


func test_the_side_is_kept_when_the_fighters_cross_over() -> void:
	var camera := _camera()
	var a := Vector3(0, 10, 0)
	var b := Vector3(0, 10, -2)
	_run(camera, a, b, 90, true)
	var side := (camera.global_position - a.lerp(b, 0.5)).normalized()
	# They swap places through each other: the camera must not flip 180 degrees.
	var worst := 0.0
	for i in 60:
		var t := i / 59.0
		var a2 := a.lerp(Vector3(0, 10, -2), t)
		var b2 := b.lerp(Vector3(0, 10, 0), t)
		camera.set_exchange(PackedVector3Array([a2, b2]))
		var before := camera.global_basis.get_rotation_quaternion()
		camera.follow(a2, b2, true, DT)
		worst = maxf(worst, rad_to_deg(before.angle_to(camera.global_basis.get_rotation_quaternion())))
	var side_after := (camera.global_position - Vector3(0, 10, -1)).normalized()
	assert_gt(side.dot(side_after), 0.5, "same side of the line")
	assert_lte(worst, camera.exchange_turn_speed / 60.0 + 0.05, "never faster than the exchange turn cap")


func test_the_swing_blends_in_and_eases_back_after_the_hold() -> void:
	var camera := _camera()
	var a := Vector3(0, 10, 0)
	var b := Vector3(0, 10, -2)
	_run(camera, a, b, 60, false)
	_run(camera, a, b, 6, true)
	assert_between(camera.exchange_weight(), 0.1, 0.6, "blending in, not cut")
	_run(camera, a, b, 60, true)
	_run(camera, a, b, int(camera.exchange_hold_seconds * 60.0) - 2, false)
	assert_almost_eq(camera.exchange_weight(), 1.0, 0.001, "held just after the exchange")
	_run(camera, a, b, 60, false)
	assert_eq(camera.exchange_weight(), 0.0, "back on the base camera")


func test_turning_the_exchange_camera_off_keeps_the_base_view() -> void:
	var camera := _camera()
	camera.exchange_cam_enabled = false
	_run(camera, Vector3(0, 10, 0), Vector3(0, 10, -2), 120, true)
	assert_eq(camera.exchange_weight(), 0.0)


func test_a_wall_on_the_left_side_uses_the_open_side() -> void:
	var a := Vector3(0, 10, 0)
	var b := Vector3(0, 10, -2)
	var left_axis := LockOnFraming.exchange_axis(a, b)
	var obstacles := CameraObstacles.new()
	var wall_at := a.lerp(b, 0.5) + left_axis * 3.0
	obstacles.add_box(AABB(wall_at - Vector3(4, 4, 4) + left_axis * 4.0, Vector3(8, 8, 8)))
	var camera := _camera()
	camera.obstacles = obstacles
	_run(camera, a, b, 120, true)
	assert_false(obstacles.is_inside(camera.global_position))
	var side := camera.global_position - a.lerp(b, 0.5)
	assert_lt(side.dot(left_axis), 0.0, "swung to the open side")


func test_exchange_detection_needs_a_close_strike_or_hit() -> void:
	var sim := CombatSim.new(1)
	sim.add_fighter(Vector3(0, 1, 0))
	sim.add_fighter(Vector3(0, 1, -2))
	sim.lock_everyone_onto_nearest()
	assert_eq(ExchangeCam.participants(sim, 0).size(), 0, "standing close is not an exchange")
	sim.fighters[1].state = FighterState.State.HITSTUN
	assert_eq(ExchangeCam.participants(sim, 0), PackedInt32Array([0, 1]))
	sim.fighters[1].position = Vector3(0, 1, -8)
	assert_eq(ExchangeCam.participants(sim, 0).size(), 0, "too far apart")
