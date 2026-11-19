extends GutTest

const SCREEN := Vector2(1920, 1080)
const FOV := 75.0
## Camera at the origin looking down -Z.
var CAMERA := Transform3D.IDENTITY


func test_point_straight_ahead_is_on_screen_at_the_centre() -> void:
	var result := OpponentMarker.placement(CAMERA, FOV, SCREEN, Vector3(0, 0, -10))
	assert_true(result.on_screen)
	assert_almost_eq(result.position.x, 960.0, 0.5)
	assert_almost_eq(result.position.y, 540.0, 0.5)


func test_point_up_and_right_lands_in_the_upper_right_quadrant() -> void:
	var result := OpponentMarker.placement(CAMERA, FOV, SCREEN, Vector3(3, 2, -10))
	assert_true(result.on_screen)
	assert_gt(result.position.x, 960.0)
	assert_lt(result.position.y, 540.0)


func test_point_far_to_the_right_gets_an_arrow_on_the_right_edge() -> void:
	var result := OpponentMarker.placement(CAMERA, FOV, SCREEN, Vector3(50, 0, -5))
	assert_false(result.on_screen)
	assert_almost_eq(result.position.x, SCREEN.x - OpponentMarker.EDGE_MARGIN, 0.5)
	assert_almost_eq(result.angle, 0.0, 0.001, "points right")


func test_point_far_above_gets_an_arrow_on_the_top_edge_pointing_up() -> void:
	var result := OpponentMarker.placement(CAMERA, FOV, SCREEN, Vector3(0, 60, -5))
	assert_false(result.on_screen)
	assert_almost_eq(result.position.y, OpponentMarker.EDGE_MARGIN, 0.5)
	assert_almost_eq(result.angle, -PI / 2.0, 0.001)


func test_point_behind_the_camera_is_never_on_screen() -> void:
	var result := OpponentMarker.placement(CAMERA, FOV, SCREEN, Vector3(1, 0, 10))
	assert_false(result.on_screen)
	var inside := Rect2(Vector2.ZERO, SCREEN).has_point(result.position)
	assert_true(inside, "arrow stays inside the screen")


func test_edge_arrows_stay_inside_the_margin() -> void:
	for point in [Vector3(-80, 20, 3), Vector3(5, -90, -1), Vector3(200, 200, 50)]:
		var result := OpponentMarker.placement(CAMERA, FOV, SCREEN, point)
		var inner := Rect2(Vector2.ONE * (OpponentMarker.EDGE_MARGIN - 0.5),
			SCREEN - Vector2.ONE * (OpponentMarker.EDGE_MARGIN - 0.5) * 2.0)
		assert_true(inner.has_point(result.position), "inside margin for %s" % point)


# --- T-118: distance, above/below and behind cues ---

func test_point_behind_the_camera_is_flagged_behind() -> void:
	assert_true(OpponentMarker.placement(CAMERA, FOV, SCREEN, Vector3(1, 0, 10)).behind)
	assert_false(OpponentMarker.placement(CAMERA, FOV, SCREEN, Vector3(50, 0, -5)).behind)


func test_cue_gives_the_distance_in_whole_metres() -> void:
	var cue := OpponentMarker.cue_for(Vector3.ZERO, Vector3(30, 0, 40), false)
	assert_eq(cue.label, "50 m")
	assert_eq(cue.vertical, 0)


func test_cue_says_above_or_below_beyond_the_height_threshold() -> void:
	assert_eq(OpponentMarker.cue_for(Vector3.ZERO, Vector3(0, 20, 5), false).vertical, 1)
	assert_eq(OpponentMarker.cue_for(Vector3(0, 30, 0), Vector3(0, 1, 5), false).vertical, -1)
	assert_eq(OpponentMarker.cue_for(Vector3.ZERO, Vector3(0, 3, 5), false).vertical, 0, "small gaps are level")


func test_cue_tags_an_opponent_behind_you() -> void:
	assert_eq(OpponentMarker.cue_for(Vector3.ZERO, Vector3(0, 0, 12), true).label, "12 m behind")
