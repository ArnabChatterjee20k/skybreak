extends GutTest
## KiBeamEffect sizes: a compact clash point and a narrow white core (media-3 beam clash).


func test_a_clash_point_stays_about_one_to_one_and_a_half_metres() -> void:
	for width in [1.0, 2.5, 4.0]:
		var sizes := KiBeamEffect.tip_sizes(width, true)
		assert_lte(maxf(sizes.x, maxf(sizes.y, sizes.z)), 1.5, "width %s" % width)
		assert_gt(sizes.x, 0.5, "the clash point still shows")


func test_a_clash_point_fades_with_the_beam() -> void:
	assert_eq(KiBeamEffect.tip_sizes(0.0, true), Vector3.ZERO)


func test_a_free_tip_has_no_clash_star() -> void:
	assert_eq(KiBeamEffect.tip_sizes(1.0, false).z, 0.0)


func test_the_hand_orb_shrinks_to_a_muzzle_while_firing() -> void:
	var beam := KiBeamEffect.new()
	add_child_autofree(beam)
	beam.fire(Vector3.ZERO, Vector3(0, 0, -10), Color(1, 0.5, 0.2), 0.0, 1.0, true)
	beam.advance(0.3)
	var orb := beam.meshes()[1]
	assert_lte(orb.scale.x * (orb.mesh as QuadMesh).size.x, 2.0 * KiBeamEffect.CHARGE_RADIUS * 0.5,
		"no sphere engulfing the caster")


func test_a_free_tip_is_at_most_one_and_a_half_beam_widths() -> void:
	for width in [0.5, 1.0, 2.5, 4.0]:
		var sizes := KiBeamEffect.tip_sizes(width, false)
		var diameter := 2.0 * KiBeamEffect.BEAM_RADIUS * width
		assert_lte(maxf(sizes.x, sizes.y), 1.5 * diameter, "width %s" % width)
		assert_gt(sizes.x, diameter, "the head still reads past the body")


func test_the_beam_core_keeps_its_colour() -> void:
	assert_lte(float(VfxKit.LOOKS[&"beam"].core_whiteness), 0.5, "a white core washes out the energy colour")
	assert_lte(float(VfxKit.LOOKS[&"beam_tip"].core_whiteness), 0.5)


func test_firing_a_beam_puts_no_ring_on_the_caster() -> void:
	for type in [CombatSim.EventType.BEAM_START, CombatSim.EventType.BEAM_FIRE]:
		var plan = CombatFeedback.plan_for({"type": type})
		assert_false(CombatFeedback.SHOCKWAVE in plan.effects, "event %d" % type)
