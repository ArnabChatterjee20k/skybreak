extends GutTest
## T-135: the locked camera keeps both fighters in frame when the opponent
## crosses the boom or dashes toward the frame edge.

const DT := 1.0 / 60.0
const BODY := Vector3(1.0, 1.8, 1.0)


func _camera(obstacles: CameraObstacles = null) -> FighterCamera:
	var camera := FighterCamera.new()
	camera.obstacles = obstacles
	add_child_autofree(camera)
	return camera


func _settle(camera: FighterCamera, player: Vector3, target: Vector3, frames: int) -> void:
	for i in frames:
		camera.follow(player, target, true, DT)


func test_the_locked_target_crossing_the_boom_does_not_pull_the_camera_in_front_of_them() -> void:
	var player := Vector3(0, 10, 0)
	var obstacles := CameraObstacles.new()
	var camera := _camera(obstacles)
	_settle(camera, player, Vector3(0, 10, -12), 120)
	# The opponent dashes behind the player, right through the boom (the
	# Shattered Mesa juggle, t1052): pulled in front of them, the camera lost them
	# beside the lens.
	var on_boom := player.lerp(camera.global_position, 0.55)
	on_boom.y = player.y
	var seen := 0
	for i in 30:
		obstacles.set_target_body(on_boom, BODY)
		camera.follow(player, on_boom, true, DT)
		assert_false(obstacles.target_body.grow(CameraObstacles.CLEARANCE).has_point(camera.global_position),
			"never inside the opponent (frame %d)" % i)
		seen += int(LockOnFraming.is_in_view(camera.global_transform, camera.fov, on_boom))
	assert_gt(camera.global_position.distance_to(player), 3.0, "the boom kept its length")
	assert_eq(seen, 30, "the opponent stayed in frame")


func test_the_target_body_does_not_block_the_boom_but_other_bodies_do() -> void:
	var obstacles := CameraObstacles.new()
	obstacles.set_target_body(Vector3(0, 10, 3), BODY)
	assert_eq(obstacles.body_clear_fraction(Vector3(0, 10, 0), Vector3(0, 10, 6)), 1.0)
	obstacles.set_bodies(PackedVector3Array([Vector3(0, 10, 3)]), BODY)
	assert_lt(obstacles.body_clear_fraction(Vector3(0, 10, 0), Vector3(0, 10, 6)), 0.5)


func test_a_point_inside_the_target_moves_out_the_shortest_way() -> void:
	var obstacles := CameraObstacles.new()
	obstacles.set_target_body(Vector3(0, 10, 0), BODY)
	var box := obstacles.target_body.grow(CameraObstacles.CLEARANCE)
	assert_eq(obstacles.out_of_target(Vector3(5, 10, 0)), Vector3(5, 10, 0), "outside: unchanged")
	var near_top := obstacles.out_of_target(Vector3(0.1, 11.0, 0.1))
	assert_false(box.has_point(near_top))
	assert_almost_eq(near_top.y, box.end.y, 0.02, "near its head: up over it")
	var near_side := obstacles.out_of_target(Vector3(0.8, 10.0, 0.0))
	assert_false(box.has_point(near_side))
	assert_almost_eq(near_side.x, box.end.x, 0.02, "near its side: out through the side")


func test_an_opponent_dashing_past_the_frame_edge_widens_the_view_at_once() -> void:
	var player := Vector3(0, 10, 0)
	var camera := _camera()
	_settle(camera, player, Vector3(0, 10, -8), 120)
	var settled_fov := camera.fov
	# A blink 7 m sideways in one frame: the turn cap can't swing that far.
	var dashed := Vector3(-7, 10, -3)
	camera.follow(player, dashed, true, DT)
	assert_true(LockOnFraming.is_in_view(camera.global_transform, camera.fov, dashed), "opponent in frame")
	assert_true(LockOnFraming.is_in_view(camera.global_transform, camera.fov, player), "player in frame")
	assert_gt(camera.fov, settled_fov + 5.0, "by widening, not by whipping round")
	assert_lte(camera.fov, FighterCamera.FIT_MAX_FOV)
	_settle(camera, player, dashed, 240)
	assert_lt(camera.fov, settled_fov + 1.0, "eases back once the framing caught up")


func test_fit_fov_skips_points_beside_the_lens_and_caps_the_widening() -> void:
	var view := Transform3D.IDENTITY
	assert_eq(FighterCamera.fit_fov(view, [Vector3(3, 0, 0)], 16.0 / 9.0), 0.0, "beside the lens")
	assert_eq(FighterCamera.fit_fov(view, [Vector3(30, 0, -1)], 16.0 / 9.0), FighterCamera.FIT_MAX_FOV)
	var fit := FighterCamera.fit_fov(view, [Vector3(0, 2, -4)], 16.0 / 9.0)
	assert_true(LockOnFraming.is_in_view(view, fit, Vector3(0, 2, -4)))
	assert_false(LockOnFraming.is_in_view(view, fit - 3.0, Vector3(0, 2, -4)))
