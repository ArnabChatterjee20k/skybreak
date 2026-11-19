extends GutTest

## Matches the arena camera: 75° vertical FOV at 16:9.
const VERTICAL_FOV := deg_to_rad(75.0)
const ASPECT := 16.0 / 9.0

const PLAYER := Vector3(0, 10, 0)


func _half_fovs() -> Vector2:
	var half_vertical := VERTICAL_FOV / 2.0
	return Vector2(atan(tan(half_vertical) * ASPECT), half_vertical)


## True if the point is in front of the camera and inside 90% of the view.
func _on_screen(camera: Transform3D, point: Vector3, vertical_fov: float = VERTICAL_FOV) -> bool:
	var local := camera.affine_inverse() * point
	if local.z >= 0.0:
		return false
	var half_vertical := vertical_fov / 2.0
	var half := Vector2(atan(tan(half_vertical) * ASPECT), half_vertical) * 0.9
	return absf(atan2(local.x, -local.z)) < half.x and absf(atan2(local.y, -local.z)) < half.y


func test_both_fighters_on_screen_across_range_bands_and_directions() -> void:
	for distance in [2.0, 5.0, 12.0, 25.0, 40.0, 80.0]:
		for angle in [0.0, 1.0, 2.5, 4.0]:
			for height in [-8.0, 0.0, 8.0]:
				var target := PLAYER + Vector3(sin(angle) * distance, height, cos(angle) * distance)
				for shoulder in [-1.0, 1.0]:
					var pose := LockOnFraming.locked_pose(PLAYER, target, shoulder, Vector2.ZERO)
					var where := "d=%s a=%s h=%s s=%s" % [distance, angle, height, shoulder]
					assert_true(_on_screen(pose, PLAYER), "player visible " + where)
					# Steeper than the pitch limits the opponent may leave the frame (marker).
					if atan2(absf(height), distance) <= LockOnFraming.MAX_VIEW_PITCH_UP:
						assert_true(_on_screen(pose, target), "target visible " + where)


func test_both_fighters_stay_on_screen_at_full_mouse_orbit() -> void:
	var target := PLAYER + Vector3(0, 0, -12)
	for orbit in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var pose := LockOnFraming.locked_pose(PLAYER, target, 1.0, orbit)
		assert_true(_on_screen(pose, PLAYER), "player visible at orbit %s" % orbit)
		assert_true(_on_screen(pose, target), "target visible at orbit %s" % orbit)


func test_camera_sits_lower_and_more_behind_at_far_range() -> void:
	var close := LockOnFraming.locked_pose(PLAYER, PLAYER + Vector3(0, 0, -4), 1.0, Vector2.ZERO)
	var far := LockOnFraming.locked_pose(PLAYER, PLAYER + Vector3(0, 0, -50), 1.0, Vector2.ZERO)
	assert_lt(far.origin.y, close.origin.y, "lower when far")
	assert_lt(absf(far.origin.x - PLAYER.x), absf(close.origin.x - PLAYER.x), "less to the side when far")
	assert_gt(far.origin.z, PLAYER.z, "behind the player")


func test_shoulder_side_moves_camera_to_that_side() -> void:
	var target := PLAYER + Vector3(0, 0, -10)
	var right := LockOnFraming.locked_pose(PLAYER, target, 1.0, Vector2.ZERO)
	var left := LockOnFraming.locked_pose(PLAYER, target, -1.0, Vector2.ZERO)
	assert_gt(right.origin.x, PLAYER.x)
	assert_lt(left.origin.x, PLAYER.x)


func test_opponent_appears_on_the_shoulder_side_of_the_screen() -> void:
	var target := PLAYER + Vector3(0, 0, -10)
	var pose := LockOnFraming.locked_pose(PLAYER, target, 1.0, Vector2.ZERO)
	var target_local := pose.affine_inverse() * target
	var player_local := pose.affine_inverse() * PLAYER
	assert_gt(target_local.x / -target_local.z, player_local.x / -player_local.z, "target right of the player")
	assert_lt(player_local.x, 0.0, "player left of centre")


func test_orbit_is_clamped_to_limits() -> void:
	var clamped := LockOnFraming.clamp_orbit(Vector2(3, -3))
	assert_almost_eq(clamped.x, LockOnFraming.MAX_ORBIT_YAW, 0.0001)
	assert_almost_eq(clamped.y, -LockOnFraming.MAX_ORBIT_PITCH, 0.0001)


func test_shoulder_follows_the_opponent_relative_to_the_player_not_the_centre() -> void:
	var camera := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var player := Vector3(-3, 0, -8)
	# Opponent left of centre but still right of the player: keep the right shoulder.
	assert_eq(LockOnFraming.shoulder_side_for(camera, player, Vector3(-1, 0, -20), 1.0), 1.0, "keep right")
	# Opponent crosses to the left of the player: flip left.
	assert_eq(LockOnFraming.shoulder_side_for(camera, player, Vector3(-12, 0, -20), 1.0), -1.0, "flip left")
	# Mirror image.
	var right_player := Vector3(3, 0, -8)
	assert_eq(LockOnFraming.shoulder_side_for(camera, right_player, Vector3(1, 0, -20), -1.0), -1.0, "keep left")
	assert_eq(LockOnFraming.shoulder_side_for(camera, right_player, Vector3(12, 0, -20), -1.0), 1.0, "flip right")


func test_locked_player_sits_a_third_from_the_edge() -> void:
	var target := PLAYER + Vector3(0, 0, -15)
	for shoulder in [-1.0, 1.0]:
		var pose := LockOnFraming.locked_pose(PLAYER, target, shoulder, Vector2.ZERO)
		var local := pose.affine_inverse() * PLAYER
		var ndc_x := local.x / -local.z / (tan(VERTICAL_FOV / 2.0) * ASPECT)
		assert_almost_eq(ndc_x, -shoulder / 3.0, 0.02, "shoulder %s" % shoulder)


func test_free_pose_orbits_player_at_boom_length_and_looks_at_them() -> void:
	var pose := LockOnFraming.free_pose(PLAYER, 1.2, 0.3)
	var pivot := PLAYER + Vector3.UP * LockOnFraming.FREE_LOOK_HEIGHT
	assert_almost_eq(pose.origin.distance_to(pivot), LockOnFraming.FREE_BOOM_LENGTH, 0.001)
	var forward := -pose.basis.z
	assert_almost_eq(forward.dot((pivot - pose.origin).normalized()), 1.0, 0.001)


func test_free_pose_pitch_is_clamped() -> void:
	var pose := LockOnFraming.free_pose(PLAYER, 0.0, deg_to_rad(89.0))
	var pivot := PLAYER + Vector3.UP * LockOnFraming.FREE_LOOK_HEIGHT
	var elevation := asin((pose.origin - pivot).normalized().y)
	assert_almost_eq(elevation, LockOnFraming.MAX_FREE_PITCH, 0.001)


## Camera view pitch in radians: negative looks down.
func _view_pitch(camera: Transform3D) -> float:
	return asin(clampf(-camera.basis.z.y, -1.0, 1.0))


func test_view_pitch_stays_inside_limits_for_big_height_gaps() -> void:
	for flat_distance in [2.0, 5.0, 12.0, 40.0]:
		for height in [-60.0, -20.0, -8.0, 8.0, 20.0, 60.0]:
			var target := PLAYER + Vector3(0, height, -flat_distance)
			var pose := LockOnFraming.locked_pose(PLAYER, target, 1.0, Vector2.ZERO)
			var pitch := _view_pitch(pose)
			var where := "flat=%s height=%s pitch=%.1f" % [flat_distance, height, rad_to_deg(pitch)]
			assert_gte(pitch, -LockOnFraming.MAX_VIEW_PITCH_DOWN - 0.001, "not steeper down " + where)
			assert_lte(pitch, LockOnFraming.MAX_VIEW_PITCH_UP + 0.001, "not steeper up " + where)


func test_player_stays_on_screen_for_big_height_gaps() -> void:
	# The opponent may leave the frame here; OpponentMarker points at it.
	for flat_distance in [2.0, 5.0, 12.0, 40.0]:
		for height in [-60.0, -20.0, 20.0, 60.0]:
			var target := PLAYER + Vector3(0, height, -flat_distance)
			var pose := LockOnFraming.locked_pose(PLAYER, target, 1.0, Vector2.ZERO)
			var fov := deg_to_rad(LockOnFraming.locked_fov(75.0, PLAYER, target))
			assert_true(_on_screen(pose, PLAYER, fov), "player visible flat=%s height=%s" % [flat_distance, height])


func test_fov_widens_only_for_big_height_gaps_and_at_most_ten_degrees() -> void:
	assert_eq(LockOnFraming.locked_fov(75.0, PLAYER, PLAYER + Vector3(0, 0, -10)), 75.0)
	var steep := LockOnFraming.locked_fov(75.0, PLAYER, PLAYER + Vector3(0, 60, -2))
	assert_gt(steep, 75.0)
	assert_lte(steep, 75.0 + LockOnFraming.MAX_FOV_BOOST)


func test_range_bands_use_hysteresis_at_their_edges() -> void:
	var NEAR := LockOnFraming.Band.NEAR
	var MID := LockOnFraming.Band.MID
	var FAR := LockOnFraming.Band.FAR
	assert_eq(LockOnFraming.band_for(8.9, MID), NEAR, "enter near below 9 m")
	assert_eq(LockOnFraming.band_for(10.0, MID), MID, "stay mid at 10 m")
	assert_eq(LockOnFraming.band_for(10.0, NEAR), NEAR, "stay near until 11 m")
	assert_eq(LockOnFraming.band_for(11.1, NEAR), MID, "leave near above 11 m")
	assert_eq(LockOnFraming.band_for(30.0, MID), MID, "stay mid at 30 m")
	assert_eq(LockOnFraming.band_for(32.1, MID), FAR, "enter far above 32 m")
	assert_eq(LockOnFraming.band_for(30.0, FAR), FAR, "stay far until 28 m")
	assert_eq(LockOnFraming.band_for(27.9, FAR), MID, "leave far below 28 m")


func test_far_zoom_keeps_a_fighter_40_pixels_tall_down_to_the_floor() -> void:
	var fov := LockOnFraming.far_zoom_fov(75.0, 50.0)
	var pixels := LockOnFraming.FIGHTER_HEIGHT / (2.0 * 50.0 * tan(deg_to_rad(fov) / 2.0)) * 1080.0
	assert_almost_eq(pixels, LockOnFraming.FAR_OPPONENT_PIXELS, 0.5, "40 px at 50 m")
	assert_eq(LockOnFraming.far_zoom_fov(75.0, 300.0), LockOnFraming.MIN_ZOOM_FOV, "40° floor")
	assert_eq(LockOnFraming.far_zoom_fov(75.0, 10.0), 75.0, "never wider than the base")


func test_near_framing_keeps_the_fighters_apart_on_screen() -> void:
	var target := PLAYER + Vector3(0, 0, -2.5)
	for shoulder in [-1.0, 1.0]:
		var pose := LockOnFraming.locked_pose(PLAYER, target, shoulder, Vector2.ZERO, 0.0)
		assert_gte(LockOnFraming.screen_gap(pose, 75.0, PLAYER, target), 0.1, "shoulder %s" % shoulder)
