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
