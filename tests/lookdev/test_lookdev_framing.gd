extends GutTest
## Look-dev camera placement from measured bounds (game/lookdev/lookdev_framing.gd)
## and the close-up and over-the-shoulder rules that use it.

const CAPTURE := preload("res://game/lookdev/lookdev_capture.gd")


func _fist() -> PackedVector3Array:
	# A gauntlet fist and forearm, wider than the old fixed 0.42 m close-up span.
	var pts := PackedVector3Array()
	for i in 400:
		var t := i / 399.0
		pts.append(Vector3(-0.32 + 0.6 * t, 1.0 + 0.18 * sin(t * 31.0), 0.12 * cos(t * 17.0)))
	return pts


func test_close_up_keeps_the_whole_fist_inside_the_frame() -> void:
	var pts := _fist()
	for pitch: float in [-8.0, -20.0]:
		var basis: Basis = CAPTURE.view_basis(pitch, 0.0)
		var eye := LookdevFraming.fit(pts, basis, 24.0, 16.0 / 9.0, 0.14)
		assert_true(LookdevFraming.inside_frame(pts, eye, basis, 24.0, 16.0 / 9.0), "pitch %d" % pitch)


func test_close_up_padding_leaves_a_margin_at_the_frame_edge() -> void:
	var pts := _fist()
	var basis: Basis = CAPTURE.view_basis(-8.0, 0.0)
	var eye := LookdevFraming.fit(pts, basis, 24.0, 16.0 / 9.0, 0.14)
	# Still inside a frame 12% narrower than the real one.
	var narrower := rad_to_deg(2.0 * atan(tan(deg_to_rad(12.0)) * 0.88))
	assert_true(LookdevFraming.inside_frame(pts, eye, basis, narrower, 16.0 / 9.0))


func test_view_basis_looks_at_the_subject_from_the_front_and_above() -> void:
	var basis: Basis = CAPTURE.view_basis(-8.0, 0.0)
	var look := -basis.z
	assert_lt(look.z, -0.9, "looks toward -Z, at a subject facing +Z")
	assert_lt(look.y, 0.0, "pitched down")


func test_shoulder_camera_lifts_until_the_shoulders_clear_the_dummy() -> void:
	# A shoulder boulder right on the sight lines from the low camera.
	var boulder := PackedVector3Array()
	for x in range(-3, 4):
		for y in range(-3, 4):
			boulder.append(Vector3(0.8 + x * 0.05, 1.5 + y * 0.05, 0.0))
	var dummy := PackedVector3Array([Vector3(0.0, 1.9, -5.0), Vector3(0.0, 1.2, -5.0), Vector3(0.0, 0.05, -5.0)])
	var base := Vector3(1.4, 1.55, 3.6)
	var lift := Vector3(1.4, 1.1, 1.0)
	assert_lt(LookdevFraming.clearance(base, dummy, boulder, 0.05), 0.0, "the low camera is blocked")
	var t := LookdevFraming.clear_lift(base, lift, dummy, boulder, 0.05)
	assert_gt(t, 0.0)
	assert_lt(t, 1.0, "a clear position exists in range")
	assert_gte(LookdevFraming.clearance(base + lift * t, dummy, boulder, 0.05), 0.0, "every sight line clears the boulder")


func test_clearance_can_ignore_what_touches_the_target() -> void:
	var eye := Vector3(0, 1.7, 2.0)
	var chin := PackedVector3Array([Vector3(0, 1.52, 0.02)])
	# A collar just in front of the chin, on the sight line.
	var neck := PackedVector3Array([chin[0] + (eye - chin[0]).normalized() * 0.03])
	assert_lt(LookdevFraming.clearance(eye, chin, neck, 0.01), 0.0)
	assert_gte(LookdevFraming.clearance(eye, chin, neck, 0.01, 0.1), 0.0)
