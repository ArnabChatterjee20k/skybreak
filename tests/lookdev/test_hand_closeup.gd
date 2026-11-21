extends GutTest
## The hand (gauntlet) close-up of every hero, framed headless from the posed
## vertices (game/lookdev/lookdev_capture.gd, hand_shot()): the whole fist sits
## inside the 10% safe area and clear of the shoulder pieces (Brann's boulders).

const CAPTURE := preload("res://game/lookdev/lookdev_capture.gd")
const HEROES := {
	"kael": "res://game/characters/kael_voxel/kael_voxel.tscn",
	"vexa": "res://game/characters/vexa/vexa.tscn",
	"lyra": "res://game/characters/lyra_voxel/lyra_voxel.tscn",
	"brann": "res://game/characters/brann_voxel/brann_voxel.tscn",
}

var _host: Node3D
var _capture: SceneTree


func before_each() -> void:
	_host = Node3D.new()
	add_child(_host)
	_capture = CAPTURE.new()


func after_each() -> void:
	_host.queue_free()
	_capture.free()


func _check(hero: String) -> void:
	await _capture.setup(_host, HEROES[hero])
	var r: Dictionary = await _capture.hand_shot()
	var fist: PackedVector3Array = r["fist"]
	var shoulders: PackedVector3Array = r["shoulders"]
	var cam: Transform3D = r["camera"]
	assert_gt(fist.size(), 200, "%s: the fist's vertices were measured" % hero)
	if hero == "brann":
		assert_gt(shoulders.size(), 1000, "brann: both boulders were measured")
	var box := LookdevFraming.screen_box(fist, cam, CAPTURE.HAND_FOV, CAPTURE.ASPECT)
	assert_gte(LookdevFraming.safe_margin(box, CAPTURE.HAND_SAFE), 0.0, "%s: fist %s inside the 10%% safe area" % [hero, box])
	assert_gt(box.size.y, 0.4, "%s: the fist fills the close-up (%s)" % [hero, box])
	assert_eq(LookdevFraming.cover(box, shoulders, cam, CAPTURE.HAND_FOV, CAPTURE.ASPECT), 0.0,
		"%s: no shoulder-piece (boulder) vertex shows inside the fist's screen bounds" % hero)
	var bounds := _aabb(fist)
	var inside := 0
	for p in shoulders:
		if bounds.has_point(p):
			inside += 1
	assert_eq(inside, 0, "%s: no shoulder-piece vertex inside the fist's bounds in space" % hero)
	assert_gte(r["eye_clear"], CAPTURE.HAND_EYE_CLEAR, "%s: the camera sits outside the body" % hero)
	assert_lte(absf(r["yaw"]), 45.0, "%s: the backdrop is the cyclorama, not its edge" % hero)
	# The pose holds while the still settles, so the saved frame matches.
	for i in CAPTURE.HAND_SETTLE_CHECK:
		await get_tree().process_frame
	var settled := LookdevFraming.screen_box(_capture._fist_points(), cam, CAPTURE.HAND_FOV, CAPTURE.ASPECT)
	assert_gte(LookdevFraming.safe_margin(settled, CAPTURE.HAND_SAFE), 0.0, "%s: still inside after settling" % hero)


func _aabb(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for p in points:
		box = box.expand(p)
	return box


func test_kael_hand_close_up_keeps_the_fist_inside_the_safe_area() -> void:
	await _check("kael")


func test_vexa_hand_close_up_keeps_the_fist_inside_the_safe_area() -> void:
	await _check("vexa")


func test_lyra_hand_close_up_keeps_the_fist_inside_the_safe_area() -> void:
	await _check("lyra")


func test_brann_gauntlet_close_up_keeps_the_fist_inside_the_safe_area_and_off_the_boulder() -> void:
	await _check("brann")


func test_nearest_is_the_distance_to_the_closest_point() -> void:
	var pts := PackedVector3Array([Vector3(1, 0, 0), Vector3(0, 0.3, 0)])
	assert_almost_eq(CAPTURE.nearest(Vector3.ZERO, pts), 0.3, 1e-6)
	assert_eq(CAPTURE.nearest(Vector3.ZERO, PackedVector3Array()), INF, "nothing to hit")


func test_safe_margin_is_negative_past_the_padding() -> void:
	assert_almost_eq(LookdevFraming.safe_margin(Rect2(0.2, 0.15, 0.5, 0.6), 0.1), 0.05, 1e-6)
	assert_lt(LookdevFraming.safe_margin(Rect2(0.05, 0.2, 0.5, 0.5), 0.1), 0.0)


func test_cover_counts_the_share_of_a_box_with_clutter_in_it() -> void:
	var cam := Transform3D(Basis.IDENTITY, Vector3(0, 0, 2))
	var box := Rect2(0.25, 0.25, 0.5, 0.5)
	assert_eq(LookdevFraming.cover(box, PackedVector3Array([Vector3(5, 0, 0)]), cam, 60.0, 1.0), 0.0, "outside the box")
	assert_almost_eq(LookdevFraming.cover(box, PackedVector3Array([Vector3(0.01, 0.01, 0)]), cam, 60.0, 1.0, 2), 0.25, 1e-6, "one cell of four")
