extends GutTest
## VoxelFaceMerge: greedy-merged prop meshes keep every voxel face's data
## (colour, corner AO, edge flags) in the face texture, so they shade the same.

const BOUNDS := AABB(Vector3(-0.6, 0, -0.6), Vector3(1.2, 1.4, 1.2))


func _paint(g: VoxelGrid) -> void:
	g.paint(BOUNDS, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 0.35, 0), Vector3(0.45, 0.35, 0.45), 0.0), 1)
	g.paint(BOUNDS, func(p: Vector3) -> float: return (p - Vector3(0, 0.95, 0)).length() - 0.4, 2)


func _color(mat: int, _p: Vector3, c: Vector3i, _n: Vector3, occlusion: float, _exposure: float) -> Color:
	var col := (Color("#8a7f70") if mat == 1 else Color("#5a8a40")) * (0.9 + 0.2 * VoxelSdf.hash3(c, 3))
	col *= 1.0 - occlusion * 0.4
	col.a = 1.0
	return col


func _surface(mat: int) -> int:
	return VoxelProp.Surf.MATTE if mat == 1 else VoxelProp.Surf.PETAL


func _meshes() -> Array[ArrayMesh]:
	var grid := VoxelGrid.new(BOUNDS, 0.1)
	_paint(grid)
	var none := [PackedInt32Array([0, 0, 0, 0]), PackedFloat32Array([1, 0, 0, 0])]
	var raw := VoxelMesher.build(grid, _color, _surface, func(_t: int, _p: Vector3) -> Array: return none,
		VoxelProp.materials(), 2)
	raw = VoxelProp._strip_skin(raw)
	return [raw, VoxelFaceMerge.merge(raw)]


func test_merging_cuts_the_quads_of_a_box_and_a_ball_by_more_than_half() -> void:
	var m := _meshes()
	assert_lt(VoxelProp.quads(m[1]) * 2, VoxelProp.quads(m[0]))


func test_a_merged_mesh_is_one_surface_whatever_its_materials() -> void:
	var m := _meshes()
	assert_eq(m[0].get_surface_count(), 2)
	assert_eq(m[1].get_surface_count(), 1)


func test_merged_quads_cover_exactly_the_original_faces() -> void:
	var m := _meshes()
	var faces := 0
	var custom: PackedFloat32Array = m[1].surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0]
	for q in custom.size() / 16:
		faces += int(custom[q * 16 + 1]) * int(custom[q * 16 + 2])
	assert_eq(faces, VoxelProp.quads(m[0]))
	assert_true(m[1].get_aabb().is_equal_approx(m[0].get_aabb()), "same bounds")


func test_the_face_texture_holds_every_original_corner_colour_and_ao() -> void:
	var m := _meshes()
	var expected := []
	for s in m[0].get_surface_count():
		var a := m[0].surface_get_arrays(s)
		var colors: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var ao: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM0]
		for v in colors.size():
			var k := v % 4
			var level := VoxelFaceMerge._ao_level(ao[(v - k) * 4 + k])
			var surf := m[0].surface_get_name(s).to_int()
			expected.append(Vector4i(roundi(colors[v].r * 255.0), roundi(colors[v].g * 255.0),
				roundi(colors[v].b * 255.0), level | surf << 3))
	var img: Image = m[1].get_meta("faces")
	var data := img.get_data()
	var got := []
	for i in expected.size():
		got.append(Vector4i(data[i * 4], data[i * 4 + 1], data[i * 4 + 2], data[i * 4 + 3] & ~4))
	expected.sort()
	got.sort()
	assert_eq(got, expected)


func test_merged_meshes_get_materials_that_read_their_face_texture() -> void:
	var m := _meshes()[1]
	VoxelProp._apply_materials(m)
	var mat := m.surface_get_material(0) as ShaderMaterial
	assert_eq(mat.shader, VoxelProp.MERGED_SHADER)
	assert_not_null(mat.get_shader_parameter("faces"))
	var rough: PackedFloat32Array = mat.get_shader_parameter("roughness_value")
	assert_almost_eq(rough[VoxelProp.Surf.MATTE], 0.9, 0.001, "per-surface values from the shared materials")
	assert_almost_eq(rough[VoxelProp.Surf.METAL], 0.4, 0.001)


func test_lantern_emission_reaches_the_merged_copies() -> void:
	var m := _meshes()[1]
	VoxelProp._apply_materials(m)
	var shared := VoxelProp.materials()[VoxelProp.Surf.PETAL] as ShaderMaterial
	var before: Variant = shared.get_shader_parameter("emission_value")
	shared.set_shader_parameter("emission_value", 0.7)
	VoxelProp.sync_materials()
	var copy := m.surface_get_material(0) as ShaderMaterial
	var emission: PackedFloat32Array = copy.get_shader_parameter("emission_value")
	assert_almost_eq(emission[VoxelProp.Surf.PETAL], 0.7, 0.001)
	shared.set_shader_parameter("emission_value", before)
	VoxelProp.sync_materials()
