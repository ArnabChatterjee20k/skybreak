extends GutTest
## The moves reel's effect colour and body contact (game/lookdev/moves_reel.gd).

const REEL := preload("res://game/lookdev/moves_reel.gd")


func test_glow_material_shows_its_emission_colour_not_a_pale_albedo() -> void:
	var mat: StandardMaterial3D = REEL.glow_material(4.5, Color("ff4a12"))
	assert_ne(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "unshaded ignores emission")
	assert_eq(mat.albedo_color, Color.BLACK)
	assert_eq(mat.emission, Color("ff4a12"))
	# Above ~1.4 the filmic tonemap washes #FF4A12 toward peach.
	assert_between(mat.emission_energy_multiplier, 0.9, 1.4)


func test_surfaces_touch_within_the_gap_only() -> void:
	var a := PackedVector3Array([Vector3(0, 1, 0), Vector3(0, 1.2, 0)])
	var cells: Dictionary = REEL.surface_cells(PackedVector3Array([Vector3(0.03, 1.0, 0)]), 0.04)
	assert_true(REEL.surfaces_touch(a, cells, Vector3.ZERO, 0.04))
	assert_false(REEL.surfaces_touch(a, cells, Vector3(0.05, 0, 0), 0.04), "moved apart")
	var far: Dictionary = REEL.surface_cells(PackedVector3Array([Vector3(0.5, 1.0, 0)]), 0.04)
	assert_false(REEL.surfaces_touch(a, far, Vector3.ZERO, 0.04))
