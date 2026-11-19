extends GutTest
## Pickup pillars, streaks and glows fade near the camera and cap their screen share (polish batch 2).


func test_a_beam_at_the_camera_is_invisible_and_whole_from_three_metres() -> void:
	assert_eq(WeaponLayer.beam_fade(0.0, 0.01), 0.0, "at the camera")
	assert_lt(WeaponLayer.beam_fade(2.0, 0.01), 1.0, "fading inside 3 m")
	assert_gt(WeaponLayer.beam_fade(2.0, 0.01), 0.0)
	assert_eq(WeaponLayer.beam_fade(WeaponLayer.NEAR_FADE_END, 0.01), 1.0, "whole from 3 m")


func test_a_beam_never_covers_more_than_the_screen_cap() -> void:
	var tan_half := tan(deg_to_rad(75.0) * 0.5)
	for distance: float in [3.0, 4.0, 6.0, 10.0, 30.0]:
		var coverage := WeaponLayer.beam_coverage(WeaponLayer.PILLAR_RADIUS, 40.0, distance, tan_half, 16.0 / 9.0)
		var seen := coverage * WeaponLayer.beam_fade(distance, coverage)
		assert_lte(seen, WeaponLayer.MAX_COVERAGE + 0.0001, "at %.0f m" % distance)
	var far := WeaponLayer.beam_coverage(WeaponLayer.PILLAR_RADIUS, 40.0, 30.0, tan_half, 16.0 / 9.0)
	assert_eq(WeaponLayer.beam_fade(30.0, far), 1.0, "a far pillar keeps full strength")


func test_a_telegraphed_pillar_right_at_the_camera_is_faded_out() -> void:
	var sim := CombatSim.new(3)
	sim.add_fighter(Vector3(0, 1, 6))
	sim.add_fighter(Vector3(0, 1, -6))
	var camera := Camera3D.new()
	add_child_autofree(camera)
	var layer := WeaponLayer.new()
	add_child_autofree(layer)
	layer.setup(sim, [] as Array[FighterView])
	var pickup := WeaponPickup.new()
	pickup.id = 1
	pickup.kind = Weapon.Kind.STORM_BLADE
	pickup.phase = WeaponPickup.Phase.TELEGRAPH
	pickup.position = Vector3(0, 12, 0)
	sim.pickups.append(pickup)
	camera.current = true
	camera.global_position = Vector3(0.3, 6, 0)
	layer.present(1.0, 1.0 / 60.0)
	var pillar: GeometryInstance3D = layer.get_child(layer.get_child_count() - 1).get_node("Pillar")
	assert_true(pillar.visible)
	assert_eq(pillar.transparency, 1.0, "the camera is inside the pillar: fully faded")
	camera.global_position = Vector3(25, 6, 0)
	layer.present(1.0, 1.0 / 60.0)
	assert_eq(pillar.transparency, 0.0, "seen from 25 m it is whole")
