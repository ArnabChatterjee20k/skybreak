extends GutTest
## Voxel Vexa v2 values (docs/lookdev/vexa.md): purple and dark dominate,
## light values only at small accents, shaded hood and mantle.



func _lum(mat: int) -> float:
	return (VexaVoxelDesign.COLORS[mat] as Color).get_luminance()


## A mantle point on the shell at this angle (degrees from the front) and height.
func _mantle(angle_deg: float, y: float) -> Vector3:
	var a := deg_to_rad(angle_deg)
	return Vector3(sin(a) * 0.27, y, cos(a) * 0.27 - 0.015)


func _out(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z + 0.015).normalized()


func test_jacket_is_a_mid_dark_slate_below_the_wraps() -> void:
	assert_lt(_lum(VexaVoxelDesign.Mat.JACKET), 0.4, "jacket no longer reads light")
	assert_lt(_lum(VexaVoxelDesign.Mat.JACKET), _lum(VexaVoxelDesign.Mat.WRAP), "jacket darker than the wraps")


func test_jacket_is_a_neutral_slate_not_navy() -> void:
	# The stage key pushes blue up (#3a3a4c rendered #282940), so the authored
	# jacket family leans no more than 12/255 blue over red and green, with red at least green.
	for mat: int in [VexaVoxelDesign.Mat.JACKET, VexaVoxelDesign.Mat.JACKET_EDGE, VexaVoxelDesign.Mat.JACKET_DARK]:
		var c: Color = VexaVoxelDesign.COLORS[mat]
		assert_lte(c.b8 - maxi(c.r8, c.g8), 12, "%s leans no further blue than #3c3a48" % c.to_html(false))
		assert_gte(c.r8, c.g8, "%s is not green-grey" % c.to_html(false))


func test_jacket_value_stays_below_the_wraps_and_the_purple() -> void:
	var jacket: Color = VexaVoxelDesign.COLORS[VexaVoxelDesign.Mat.JACKET]
	assert_lt(jacket.v, (VexaVoxelDesign.COLORS[VexaVoxelDesign.Mat.WRAP] as Color).v, "below the wraps")
	assert_lt(jacket.v, (VexaVoxelDesign.COLORS[VexaVoxelDesign.Mat.HOOD] as Color).v, "below the hood purple")


func test_jacket_edge_and_seams_are_darker_than_the_jacket() -> void:
	assert_lt(_lum(VexaVoxelDesign.Mat.JACKET_EDGE), _lum(VexaVoxelDesign.Mat.JACKET))
	assert_lt(_lum(VexaVoxelDesign.Mat.JACKET_DARK), _lum(VexaVoxelDesign.Mat.JACKET_EDGE))


func test_zip_teeth_are_a_small_light_accent() -> void:
	assert_gt(_lum(VexaVoxelDesign.Mat.ZIP), _lum(VexaVoxelDesign.Mat.JACKET) + 0.3)


func test_wraps_are_broken_by_dark_bands() -> void:
	assert_lt(_lum(VexaVoxelDesign.Mat.WRAP_BAND), _lum(VexaVoxelDesign.Mat.WRAP) * 0.5)
	assert_false(VexaVoxelDesign.Mat.WRAP in VexaVoxelDesign.WEARS, "plain wraps don't lighten on exposed edges")


func test_hood_interior_faces_are_darker_than_its_outside() -> void:
	var base: Color = VexaVoxelDesign.COLORS[VexaVoxelDesign.Mat.HOOD]
	var p := Vector3(0.12, 1.6, -0.02)
	var outside := VexaVoxelDesign.hood_shade(base, VexaVoxelDesign.Mat.HOOD, p, _out(p))
	var inside := VexaVoxelDesign.hood_shade(base, VexaVoxelDesign.Mat.HOOD, p, -_out(p))
	assert_lt(inside.get_luminance(), outside.get_luminance() * 0.7)


func test_mantle_underside_is_dark() -> void:
	var base: Color = VexaVoxelDesign.COLORS[VexaVoxelDesign.Mat.HOOD]
	var p := _mantle(92.0, 1.2)
	var under := VexaVoxelDesign.hood_shade(base, VexaVoxelDesign.Mat.HOOD, p, Vector3.DOWN)
	assert_lt(under.get_luminance(), VexaVoxelDesign.hood_shade(base, VexaVoxelDesign.Mat.HOOD, p, _out(p)).get_luminance() * 0.7)


func test_mantle_folds_are_lighter_on_the_tatter_than_in_the_valley() -> void:
	var base: Color = VexaVoxelDesign.COLORS[VexaVoxelDesign.Mat.HOOD]
	var ridge := _mantle(92.0, 1.22)
	var valley := _mantle(121.0, 1.30)
	assert_gt(VexaVoxelDesign.hood_shade(base, VexaVoxelDesign.Mat.HOOD, ridge, _out(ridge)).get_luminance(),
		VexaVoxelDesign.hood_shade(base, VexaVoxelDesign.Mat.HOOD, valley, _out(valley)).get_luminance() * 1.3)


func test_tatter_tips_have_a_lighter_rim() -> void:
	var base: Color = VexaVoxelDesign.COLORS[VexaVoxelDesign.Mat.HOOD]
	var tip := _mantle(150.0, 1.155)
	var mid := _mantle(150.0, 1.22)
	assert_gt(VexaVoxelDesign.hood_shade(base, VexaVoxelDesign.Mat.HOOD, tip, _out(tip)).get_luminance(),
		VexaVoxelDesign.hood_shade(base, VexaVoxelDesign.Mat.HOOD, mid, _out(mid)).get_luminance())


func test_hood_back_has_fold_shading() -> void:
	var base: Color = VexaVoxelDesign.COLORS[VexaVoxelDesign.Mat.HOOD]
	var values: Array[float] = []
	for deg: float in [150.0, 165.0, 180.0]:
		var a := deg_to_rad(deg)
		var p := Vector3(sin(a) * 0.16, 1.55, cos(a) * 0.16 - 0.015)
		values.append(VexaVoxelDesign.hood_shade(base, VexaVoxelDesign.Mat.HOOD, p, _out(p)).get_luminance())
	assert_gt(values.max() - values.min(), 0.01, "the back panel isn't one flat value")


func test_violet_lining_stays_the_most_saturated_hood_colour() -> void:
	for mat: int in [VexaVoxelDesign.Mat.HOOD, VexaVoxelDesign.Mat.HOOD_DARK, VexaVoxelDesign.Mat.HOOD_INNER, VexaVoxelDesign.Mat.HOOD_RIM]:
		assert_gt((VexaVoxelDesign.COLORS[VexaVoxelDesign.Mat.LINING] as Color).s, (VexaVoxelDesign.COLORS[mat] as Color).s)
