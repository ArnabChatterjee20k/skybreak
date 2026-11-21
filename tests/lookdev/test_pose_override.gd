extends GutTest
## Look-dev pose override: squaring the hips to the camera and placing the
## hands with a two-bone reach (game/lookdev/pose_override.gd).


func test_squaring_turns_a_side_on_stance_to_face_the_camera() -> void:
	var camera := Vector3(0.3, 0.2, 1.0)
	for stance_deg: float in [-90.0, -40.0, 0.0, 65.0, 120.0, 179.0]:
		var hips := Basis(Vector3.UP, deg_to_rad(stance_deg))
		var front := hips * Vector3.BACK
		var squared := Basis(Vector3.UP, LookdevPoseOverride.yaw_to_face(front, camera)) * hips
		var facing := squared * Vector3.BACK
		var angle := rad_to_deg(Vector2(facing.x, facing.z).angle_to(Vector2(camera.x, camera.z)))
		assert_almost_eq(angle, 0.0, 0.01, "hips face the camera from a %d° stance" % stance_deg)


func test_squaring_ignores_a_vertical_direction() -> void:
	assert_eq(LookdevPoseOverride.yaw_to_face(Vector3.BACK, Vector3.UP), 0.0)


func test_reach_elbow_keeps_both_bone_lengths_and_bends_toward_the_pole() -> void:
	var shoulder := Vector3(0.2, 1.45, 0.0)
	var wrist := Vector3(0.05, 1.05, 0.32)
	var pole := Vector3(1.0, -0.4, -0.5)
	var elbow := LookdevPoseOverride.elbow_for(shoulder, wrist, 0.28, 0.26, pole)
	assert_almost_eq(elbow.distance_to(shoulder), 0.28, 0.001)
	assert_almost_eq(elbow.distance_to(wrist), 0.26, 0.001)
	var mid := (shoulder + wrist) * 0.5
	assert_gt((elbow - mid).dot(pole), 0.0, "the elbow bends out and back")


func test_reach_beyond_the_arm_straightens_it_toward_the_target() -> void:
	var elbow := LookdevPoseOverride.elbow_for(Vector3.ZERO, Vector3(0, 0, 2.0), 0.3, 0.3, Vector3.UP)
	assert_almost_eq(elbow.z, 0.3, 0.01)
