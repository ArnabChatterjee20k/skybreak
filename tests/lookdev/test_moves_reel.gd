extends GutTest
## The moves reel's effect colour, body contact, strike step-in and beam-charge orb
## (game/lookdev/moves_reel.gd).

const REEL := preload("res://game/lookdev/moves_reel.gd")


func test_glow_material_shows_its_emission_colour_not_a_pale_albedo() -> void:
	var mat: StandardMaterial3D = REEL.glow_material(4.5, Color("ff4a12"))
	assert_ne(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "unshaded ignores emission")
	assert_eq(mat.albedo_color, Color.BLACK)
	assert_eq(mat.emission, Color("ff4a12"))
	# Above ~1.4 the filmic tonemap washes #FF4A12 toward peach.
	assert_between(mat.emission_energy_multiplier, 0.9, 1.4)


func test_step_in_distance_is_the_surface_gap_less_the_contact_spacing() -> void:
	# A fist 0.5 m short of the target's front, straight ahead along +X.
	var fist := PackedVector3Array([Vector3(0.0, 1.2, 0.0), Vector3(-0.05, 1.2, 0.0)])
	var body := PackedVector3Array([Vector3(0.5, 1.2, 0.0), Vector3(0.7, 1.2, 0.0), Vector3(0.5, 0.6, 0.0)])
	var step: float = REEL.step_to_touch(fist, body, Vector3.RIGHT, 0.04)
	assert_almost_eq(step, 0.46, 0.001, "stops 4 cm short of the surface")
	var moved := PackedVector3Array()
	for p in fist:
		moved.append(p + Vector3.RIGHT * step)
	assert_almost_eq(REEL.step_to_touch(moved, body, Vector3.RIGHT, 0.04), 0.0, 0.001, "first touch after stepping in")


func test_step_in_sees_an_overlap_as_negative_and_misses_as_never() -> void:
	var body := PackedVector3Array([Vector3(0.5, 1.2, 0.0)])
	var sunk: float = REEL.step_to_touch(PackedVector3Array([Vector3(0.48, 1.2, 0.0)]), body, Vector3.RIGHT, 0.04)
	assert_almost_eq(sunk, -0.02, 0.001)
	var above: float = REEL.step_to_touch(PackedVector3Array([Vector3(0.0, 1.5, 0.0)]), body, Vector3.RIGHT, 0.04)
	assert_eq(above, INF, "a fist passing over the target never touches it")


func test_step_in_reaches_a_bulky_belly_before_the_capsule() -> void:
	# A belly 0.42 m in front of the hips line sticks out past BODY_RADIUS.
	var belly := PackedVector3Array([Vector3(1.0 - 0.42, 1.0, 0.0)])
	var fist := PackedVector3Array([Vector3(0.2, 1.0, 0.0)])
	var step: float = REEL.step_to_touch(fist, belly, Vector3.RIGHT, REEL.BODY_GAP)
	assert_almost_eq(step, 0.58 - 0.2 - REEL.BODY_GAP, 0.001)
	assert_lt(step, REEL.MAX_STEP_IN, "close enough to step in, not whiff")


func test_charge_orb_sits_outside_the_hand_bounds() -> void:
	# Two big stone fists (a 0.16 m box each) cupped either side of the palms point.
	var hands := PackedVector3Array()
	for x in [-0.18, -0.02, 0.02, 0.18]:
		for y in [0.9, 1.06]:
			for z in [0.2, 0.36]:
				hands.append(Vector3(x, y, z))
	var palms := Vector3(0.0, 0.98, 0.28)
	for radius: float in [0.04, 0.1, 0.144]:
		var orb: Vector3 = REEL.orb_centre(palms, Vector3.BACK, hands, radius)
		assert_gt(REEL.nearest(orb, hands), radius, "no hand surface inside the orb (r %.3f)" % radius)
		assert_gt(orb.z, 0.36, "in front of the palms, toward the camera")
		assert_lt(orb.z, 0.36 + radius + 0.05, "still held at the hands")


func test_limb_and_hand_bones_are_recognised() -> void:
	assert_true(REEL.is_limb("RightLowerArm"))
	assert_true(REEL.is_limb("LeftIndexProximal"))
	assert_true(REEL.is_limb("RightToes"))
	assert_false(REEL.is_limb("Chest"))
	assert_true(REEL.is_hand("LeftThumbDistal"))
	assert_false(REEL.is_hand("LeftLowerArm"))
