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


func test_near_turn_cap_ramps_up_only_while_the_opponent_is_out_of_view() -> void:
	var camera := FighterCamera.new()
	add_child_autofree(camera)
	var player := Vector3(0, 10, 0)
	var ahead := Vector3(0, 10, -5)
	for i in 120:
		camera.follow(player, ahead, true, 1.0 / 60.0)
	assert_eq(camera.turn_cap(), camera.max_turn_speed, "normal cap with the opponent in view")
	# Opponent jumps behind the camera, 5 m away (near band).
	var behind := Vector3(0, 10, 5)
	var previous := camera.turn_cap()
	var highest := previous
	for i in 30:
		camera.follow(player, behind, true, 1.0 / 60.0)
		assert_lte(camera.turn_cap() - previous, camera.turn_cap_ramp / 60.0 + 0.001, "ramps, never jumps")
		previous = camera.turn_cap()
		highest = maxf(highest, previous)
	assert_gt(highest, camera.max_turn_speed, "speeds up to catch the opponent")
	assert_lte(highest, camera.near_catch_up_turn_speed)
	for i in 240:
		camera.follow(player, behind, true, 1.0 / 60.0)
	assert_eq(camera.turn_cap(), camera.max_turn_speed, "back to normal once the opponent is in view")


# --- Issue #75: obstacles, ease-in turns, target glide, cuts ---

func _locked_camera(obstacles: CameraObstacles = null) -> FighterCamera:
	var camera := FighterCamera.new()
	camera.obstacles = obstacles
	add_child_autofree(camera)
	return camera


func _settle(camera: FighterCamera, player: Vector3, target: Vector3, frames: int) -> void:
	for i in frames:
		camera.follow(player, target, true, 1.0 / 60.0)


func test_camera_never_sits_inside_a_prop_behind_the_player() -> void:
	var player := Vector3(0, 10, 0)
	var target := Vector3(0, 10, -12)
	var free := _locked_camera()
	_settle(free, player, target, 120)
	# A wall right where the free camera would sit.
	var obstacles := CameraObstacles.new()
	var spot := free.global_position
	obstacles.add_box(AABB(spot - Vector3(3, 3, 1), Vector3(6, 6, 2)))
	var camera := _locked_camera(obstacles)
	for i in 120:
		camera.follow(player, target, true, 1.0 / 60.0)
		assert_false(obstacles.is_inside(camera.global_position), "never inside the wall (frame %d)" % i)
	assert_false(obstacles.blocks(player + Vector3.UP * 0.5, camera.global_position), "nothing between player and camera")


func test_camera_stays_above_the_ground() -> void:
	var obstacles := CameraObstacles.new()
	obstacles.ground_height = func(_x: float, _z: float, _from_y: float) -> float: return 9.8
	var camera := _locked_camera(obstacles)
	# Opponent far above: the boom swings low, toward the ground.
	for i in 180:
		camera.follow(Vector3(0, 10.2, 0), Vector3(0, 30, -6), true, 1.0 / 60.0)
		assert_gte(camera.global_position.y, 9.8 + CameraObstacles.CLEARANCE - 0.001)


func test_pulled_in_camera_eases_back_out() -> void:
	var player := Vector3(0, 10, 0)
	var target := Vector3(0, 10, -12)
	var obstacles := CameraObstacles.new()
	var camera := _locked_camera(obstacles)
	_settle(camera, player, target, 120)
	var free_distance := camera.global_position.distance_to(player)
	var wall := CameraObstacles.new()
	wall.add_box(AABB(camera.global_position - Vector3(3, 3, 1), Vector3(6, 6, 2)))
	camera.obstacles = wall
	_settle(camera, player, target, 30)
	var pulled := camera.global_position.distance_to(player)
	assert_lt(pulled, free_distance - 0.5, "pulled in front of the wall")
	camera.obstacles = obstacles  # wall gone
	var previous := pulled
	for i in 30:
		camera.follow(player, target, true, 1.0 / 60.0)
		var now := camera.global_position.distance_to(player)
		assert_lte(now - previous, camera.obstacle_release_speed / 60.0 + 0.02, "eases out, no pop")
		previous = now


func test_turns_ease_in_instead_of_snapping() -> void:
	var camera := _locked_camera()
	var player := Vector3(0, 10, 0)
	_settle(camera, player, Vector3(0, 10, -12), 120)
	var before := camera.global_basis.get_rotation_quaternion()
	camera.follow(player, Vector3(12, 10, 0), true, 1.0 / 60.0)  # target swings 90 deg
	var first_turn := before.angle_to(camera.global_basis.get_rotation_quaternion())
	var limit := deg_to_rad(camera.max_turn_acceleration) / 60.0 / 60.0
	assert_lte(first_turn, limit + 0.0005, "first frame of a turn is gentle")


func test_a_target_switch_glides_instead_of_cutting() -> void:
	var camera := _locked_camera()
	var player := Vector3(0, 10, 0)
	_settle(camera, player, Vector3(0, 10, -12), 120)
	var worst := 0.0
	var previous := camera.global_basis.get_rotation_quaternion()
	for i in 60:
		camera.follow(player, Vector3(-14, 12, -4), true, 1.0 / 60.0)  # new target, 15 m away
		var now := camera.global_basis.get_rotation_quaternion()
		worst = maxf(worst, rad_to_deg(previous.angle_to(now)))
		previous = now
	assert_lte(worst, camera.max_turn_speed / 60.0 + 0.01, "no frame turns faster than the cap")


func test_a_huge_teleport_cuts_to_the_new_framing() -> void:
	var camera := _locked_camera()
	_settle(camera, Vector3(0, 300, 0), Vector3(0, 300, -12), 120)
	var landed := Vector3(0, 20, 0)
	camera.follow(landed, Vector3(0, 300, -12), false, 1.0 / 60.0)
	assert_lt(camera.global_position.distance_to(landed), 12.0, "the camera is with the player at once")


func _one_island() -> IslandField:
	var field := IslandField.new()
	field.add("test", Vector2(0, 0), 100.0, 30.0, 20.0, 0.0)
	return field


func test_the_merged_island_mesh_adds_no_zone_wide_box() -> void:
	var obstacles := CameraObstacles.new()
	obstacles.islands = _one_island()
	var root := Node3D.new()
	add_child_autofree(root)
	var merged := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(500, 100, 400)
	merged.mesh = mesh
	merged.set_meta(CameraObstacles.ISLANDS_META, PackedStringArray(["test"]))
	root.add_child(merged)
	obstacles.add_props(root, Vector2.ZERO, INF)
	assert_eq(obstacles.boxes.size(), 0, "islands are tested by shape, not by one box")
	assert_false(obstacles.is_inside(Vector3(150, 120, 0)), "open sky beside the island is clear")


func test_an_island_body_blocks_the_camera_from_below() -> void:
	var obstacles := CameraObstacles.new()
	obstacles.islands = _one_island()
	assert_true(obstacles.is_inside(Vector3(0, 95, 0)), "inside the rock under the top")
	assert_false(obstacles.is_inside(Vector3(0, 103, 0)), "above the top is clear")
	assert_true(obstacles.blocks(Vector3(0, 103, 0), Vector3(0, 70, 0)), "rock between a player on top and a camera below")
	assert_false(obstacles.blocks(Vector3(0, 103, 0), Vector3(0, 108, 6)), "a camera above the top is clear")


# --- Issue #107: other fighters on the boom ---

func test_camera_pulls_in_front_of_another_fighter_on_the_boom() -> void:
	var player := Vector3(0, 10, 0)
	var target := Vector3(0, 10, -12)
	var free := _locked_camera()
	_settle(free, player, target, 120)
	# A third fighter standing right where the camera would sit (FFA, seed 2610).
	var obstacles := CameraObstacles.new()
	var body := Vector3(free.global_position.x, 10.0, free.global_position.z)
	obstacles.set_bodies(PackedVector3Array([body]), Vector3(1.0, 1.8, 1.0))
	var camera := _locked_camera(obstacles)
	for i in 120:
		camera.follow(player, target, true, 1.0 / 60.0)
		assert_false(obstacles.bodies[0].has_point(camera.global_position), "never inside the body (frame %d)" % i)
	assert_lt(camera.global_position.distance_to(player), free.global_position.distance_to(player) - 0.5,
		"in front of it")


func test_a_body_around_the_pivot_does_not_block_the_boom() -> void:
	var obstacles := CameraObstacles.new()
	obstacles.set_bodies(PackedVector3Array([Vector3(0, 10, 0)]), Vector3(1.0, 1.8, 1.0))
	assert_eq(obstacles.body_clear_fraction(Vector3(0, 10, 0), Vector3(0, 11, 6)), 1.0)
	assert_lt(obstacles.body_clear_fraction(Vector3(0, 10, 5), Vector3(0, 10, -5)), 0.5)
