extends GutTest
## The moves reel's melee and dash staging, run headless without frames
## (game/lookdev/moves_reel.gd): Lyra's hat stays out of the dummy, and the
## dash keeps Kael inside the safe area.

const REEL := preload("res://game/lookdev/moves_reel.gd")
const LYRA := "res://game/characters/lyra_voxel/lyra_voxel.tscn"
const KAEL := "res://game/characters/kael_voxel/kael_voxel.tscn"
const CAPTURE := preload("res://game/lookdev/lookdev_capture.gd")

var _host: Node3D
var _reel: SceneTree


func before_each() -> void:
	_host = Node3D.new()
	add_child(_host)
	_reel = REEL.new()


func after_each() -> void:
	_host.queue_free()
	_reel.free()


func test_lyra_head_and_brim_stay_out_of_the_dummy_through_the_combo_and_hit_react() -> void:
	_reel.setup(_host, LYRA, "res://game/combat/moves/lyra/")
	var r: Dictionary = await _reel.combo_check()
	assert_gt(r["head_reach"], 0.3, "the brim radius is measured from the posed hat (0.36 m)")
	assert_gte(r["head_clear"], 0.0, "head, hair and hat never come within 2 cm of the dummy")
	assert_lt(r["head_clear"], 0.5, "the dummy was near enough to measure")
	assert_gte(r["combo_hits"], 3, "every strike of the 3-hit combo still lands")
	assert_gte(r["react_hits"], 2, "the dummy's hits on her land")


func test_kael_stays_inside_the_safe_area_on_every_dash_frame() -> void:
	_reel.setup(_host, KAEL, "res://game/combat/moves/kael/")
	var r: Dictionary = await _reel.dash_check()
	assert_gte(r["frames"], 100, "every dash frame was checked")
	assert_gte(r["margin"], 0.0, "the hero's projected bounds stay inside 10% padding")


func test_screen_box_projects_points_to_frame_fractions() -> void:
	var xf := Transform3D(Basis.IDENTITY, Vector3(0, 0, 5))
	var ty := tan(deg_to_rad(30.0))
	var pts := PackedVector3Array([Vector3(0, 0, 0), Vector3(5.0 * ty * 2.0 * 0.5, 5.0 * ty * 0.5, 0)])
	var box: Rect2 = REEL.screen_box(pts, xf, 60.0, 2.0)
	assert_almost_eq(box.position.x, 0.5, 0.001, "centre")
	assert_almost_eq(box.end.x, 0.75, 0.001, "half way to the right edge")
	assert_almost_eq(box.position.y, 0.25, 0.001, "half way to the top, y down")


func test_safe_shift_pulls_a_span_back_inside_the_padding() -> void:
	assert_almost_eq(REEL.safe_shift(0.7, 0.95, 0.1), -0.05, 1e-6, "off the right edge moves left")
	assert_almost_eq(REEL.safe_shift(0.02, 0.3, 0.1), 0.08, 1e-6)
	assert_eq(REEL.safe_shift(0.2, 0.6, 0.1), 0.0, "already inside")
	assert_almost_eq(REEL.safe_shift(0.0, 0.9, 0.1), 0.05, 1e-6, "too wide: centred")


func test_a_hat_counts_as_part_of_the_head() -> void:
	assert_true(REEL.is_head_part("Hat"))
	assert_true(REEL.is_head_part("Head"))
	assert_false(REEL.is_head_part("Chest"))
	assert_true(CAPTURE.is_head_bone("Hat"), "the head close-up frames the hat too")
