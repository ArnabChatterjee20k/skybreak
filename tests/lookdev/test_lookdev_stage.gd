extends GutTest
## Look-dev stage capture settings that keep the PCSS key shadow free of dot
## grain (game/lookdev/lookdev_stage.gd).


func test_capture_viewports_use_taa_on_top_of_msaa() -> void:
	var viewport := SubViewport.new()
	LookdevStage.configure_viewport(viewport)
	assert_true(viewport.use_taa, "TAA accumulates the per-pixel PCSS dither")
	assert_eq(viewport.msaa_3d, Viewport.MSAA_4X, "voxel edges stay crisp")
	viewport.free()


func test_key_light_is_soft_without_a_grainy_wide_penumbra() -> void:
	var stage := LookdevStage.new()
	add_child_autofree(stage)
	assert_almost_eq(stage.key.light_angular_distance, LookdevStage.KEY_ANGULAR_DISTANCE, 0.001)
	assert_between(stage.key.light_angular_distance, 1.5, 3.0, "soft but not a dithered smear")
	assert_lte(stage.key.shadow_blur, 1.0)
	assert_true(stage.key.shadow_enabled)
	assert_not_null(stage.contact_shadow, "the soft contact shadow stays")


func test_stills_wait_for_taa_to_converge() -> void:
	assert_gte(LookdevStage.TAA_SETTLE_FRAMES, 8)
