extends GutTest
## The voxel zone kit (game/world/voxel_zone_kit/): heightfield meshing,
## placement tiles and LOD tiers, the stage presets.


func _flat_field(level: int, n: int) -> VoxelHeightfield:
	var hf := VoxelHeightfield.new(0.5, Vector2.ZERO, Vector2(n * 0.5 - 0.01, n * 0.5 - 0.01))
	for z in hf.size.y:
		for x in hf.size.x:
			hf.set_column(x, z, level, level - 2, Color.WHITE)
	return hf


func _normals(mesh: ArrayMesh) -> PackedVector3Array:
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]


func _verts(mesh: ArrayMesh) -> PackedVector3Array:
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


func test_a_flat_field_merges_into_one_top_quad_and_one_wall_per_side() -> void:
	var hf := _flat_field(4, 10)
	var mesh := hf.chunk_mesh(0, 0)
	assert_eq(_verts(mesh).size() / 6, 5, "1 top + 4 walls")


func test_two_levels_make_two_top_rectangles_and_a_step_wall() -> void:
	var hf := _flat_field(4, 10)
	for z in hf.size.y:
		for x in range(5, hf.size.x):
			hf.set_column(x, z, 6, 2, Color.WHITE)
	var mesh := hf.chunk_mesh(0, 0)
	var ups := 0
	for n in _normals(mesh):
		if n.y > 0.5:
			ups += 1
	assert_eq(ups / 6, 2, "two top rectangles")
	# 4 outer sides (one is split by the step: 2 runs on each of the two long sides) + the step.
	assert_eq(_verts(mesh).size() / 6, 2 + 1 + 2 + 2 + 1 + 1)


func test_an_underside_shows_its_bottoms_facing_down() -> void:
	var hf := VoxelHeightfield.new(0.5, Vector2.ZERO, Vector2(4.99, 4.99), true)
	for z in hf.size.y:
		for x in hf.size.x:
			hf.set_column(x, z, -3, 0, Color.WHITE)
	var mesh := hf.chunk_mesh(0, 0)
	var downs := 0
	for n in _normals(mesh):
		if n.y < -0.5:
			downs += 1
	assert_eq(downs / 6, 1)


func test_a_smooth_top_lies_exactly_on_its_height_function() -> void:
	var hf := _flat_field(0, 40)
	var height := func(x: float, z: float) -> float: return 3.0 + 0.01 * x * x - 0.02 * z
	hf.smooth_height = height
	var mesh := hf.chunk_mesh(0, 0)
	var on_top := 0
	for v in _verts(mesh):
		if v.y > 1.0:
			assert_almost_eq(v.y, height.call(v.x, v.z), 1e-4)
			on_top += 1
	assert_gt(on_top, 0)
	# The quadtree keeps a full 40x40 interior down to a handful of quads.
	assert_lt(_verts(mesh).size() / 6, 40)


func test_heartbloom_lawn_vertices_stay_on_the_sim_surface() -> void:
	var field := IslandField.heartbloom()
	var i := field.index_of("Heart Isle")
	var c := field.centres[i]
	var hf := VoxelHeightfield.new(VoxelZone.T1, c - Vector2(6, 6), c + Vector2(6, 6))
	for z in hf.size.y:
		for x in hf.size.x:
			var h := field.top_profile(i, field.rim_fraction(i, hf.centre(x, z).x, hf.centre(x, z).y))
			hf.set_column(x, z, roundi(h / hf.cell), roundi((h - 1.6) / hf.cell), Color.WHITE)
	hf.smooth_height = func(x: float, z: float) -> float:
		return field.top_profile(i, minf(field.rim_fraction(i, x, z), 1.0))
	var mesh := hf.chunk_mesh(0, 0)
	var verts := _verts(mesh)
	var normals := _normals(mesh)
	var checked := 0
	for k in verts.size():
		if normals[k].y > 0.5:  # the lawn, not the patch's own edge walls
			assert_almost_eq(verts[k].y, field.surface_at(verts[k].x, verts[k].z), 0.044, "QA foot check: within half a T1 cell")
			checked += 1
	assert_gt(checked, 0)


func test_step_ao_darkens_the_foot_of_a_step_only() -> void:
	var hf := _flat_field(4, 10)
	for z in hf.size.y:
		for x in range(5, hf.size.x):
			hf.set_column(x, z, 6, 2, Color.WHITE)
	hf.bake_step_ao(0.4, 2)
	assert_lt(hf.colours[hf.index(4, 5) * 4], 255, "beside the step")
	assert_eq(hf.colours[hf.index(0, 5) * 4], 255, "far from the step")
	assert_eq(hf.colours[hf.index(7, 5) * 4], 255, "on top of the step")


func test_placement_tiles_carry_every_lod_tier_with_its_range() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var near := BoxMesh.new()
	var far := BoxMesh.new()
	var meshes: Array[ArrayMesh] = []
	for m: PrimitiveMesh in [near, far]:
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.get_mesh_arrays())
		meshes.append(am)
	var xfs: Array[Transform3D] = [Transform3D(Basis(), Vector3(1, 0, 1)), Transform3D(Basis(), Vector3(2, 0, 3)),
		Transform3D(Basis(), Vector3(VoxelProp.TILE * 3.0, 0, 1))]
	var root := VoxelProp.place(parent, "Things", meshes, [30.0, 0.0], xfs, 1)
	assert_eq(root.get_child_count(), 4, "2 tiles x 2 tiers")
	var instances := 0
	for node: MultiMeshInstance3D in root.get_children():
		var tier := int(node.name.right(1))
		assert_eq(node.visibility_range_end, [30.0, 0.0][tier])
		assert_eq(node.visibility_range_begin, [0.0, 30.0][tier])
		assert_eq(node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, tier == 0, "only the near tier casts")
		if tier == 0:
			instances += node.multimesh.instance_count
	assert_eq(instances, 3)


func test_every_stage_preset_has_every_value() -> void:
	var keys: Array = VoxelStage.PRESETS["dusk"].keys()
	for name: String in ["day", "dusk", "night"]:
		var p: Dictionary = VoxelStage.PRESETS[name]
		for k: String in keys:
			assert_true(p.has(k), "%s has %s" % [name, k])


func test_applying_a_preset_sets_sun_fog_and_exposure() -> void:
	var stage := VoxelStage.new()
	add_child_autofree(stage)
	stage.setup()
	stage.apply("night")
	var p: Dictionary = VoxelStage.PRESETS["night"]
	assert_eq(stage.sun.light_color, p.sun_color)
	assert_almost_eq(stage.env.fog_density, float(p.fog_density), 1e-6)
	assert_almost_eq(stage.env.tonemap_exposure, float(p.exposure), 1e-6)
	assert_almost_eq(-stage.sun.global_basis.z.normalized().dot((p.sun_dir as Vector3).normalized()), 1.0, 1e-3,
		"the sun shines along sun_dir")


func test_pink_is_the_accent_not_the_sky_or_fog() -> void:
	for name: String in ["day", "dusk"]:
		var p: Dictionary = VoxelStage.PRESETS[name]
		for k: String in ["sky_top", "fog_color", "sky_below", "cloud"]:
			var c: Color = p[k]
			var pinkish := c.r > c.b + 0.08 and c.r > c.g + 0.08 and fposmod(c.h, 1.0) > 0.85
			assert_false(pinkish, "%s %s is not pink" % [name, k])


func _slab(n: int) -> VoxelHeightfield:
	var hf := VoxelHeightfield.new(0.5, Vector2.ZERO, Vector2(n * 0.5 - 0.01, n * 0.5 - 0.01))
	for z in hf.size.y:
		for x in hf.size.x:
			hf.set_column(x, z, 40, 10, Color.WHITE)
	return hf


func test_a_solid_field_gets_an_occluder_inside_its_solid() -> void:
	var hf := _slab(40)
	var occ := hf.chunk_occluder(0, 0)
	assert_not_null(occ)
	var top := -INF
	var bottom := INF
	for v in occ.vertices:
		top = maxf(top, v.y)
		bottom = minf(bottom, v.y)
	assert_lt(top, 40 * hf.cell, "below the shown top")
	assert_gt(bottom, 10 * hf.cell, "above the hidden bottom")


func test_a_thin_field_gets_no_occluder() -> void:
	var hf := _flat_field(4, 10)
	assert_null(hf.chunk_occluder(0, 0), "a 2-cell crust is too thin to occlude safely")


func test_built_chunks_keep_only_meshes_under_their_root() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var hf := _slab(40)
	var root := hf.build(parent, ShaderMaterial.new(), "Field")
	for c in root.get_children():
		assert_true(c is MeshInstance3D)
	assert_not_null(parent.get_node_or_null("FieldOccluders"))


func test_medium_keeps_the_high_look_and_web_shortens_ranges() -> void:
	var high: Dictionary = VoxelQuality.VALUES[GraphicsSettings.Quality.HIGH]
	var medium: Dictionary = VoxelQuality.VALUES[GraphicsSettings.Quality.MEDIUM]
	var web: Dictionary = VoxelQuality.VALUES[GraphicsSettings.Quality.WEB]
	assert_eq(medium.range_scale, high.range_scale)
	assert_eq(medium.near_split, high.near_split, "contact shadows as sharp")
	assert_eq(medium.shadow_distance, high.shadow_distance, "far shadows (islands on the cloud sea) stay")
	assert_lt(float(web.range_scale), 1.0)


func test_place_drops_shadows_from_clutter_on_medium() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var box := BoxMesh.new()
	box.size = Vector3(0.2, 0.2, 0.2)
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	var keep := VoxelQuality.tier
	VoxelQuality.tier = GraphicsSettings.Quality.MEDIUM
	var meshes: Array[ArrayMesh] = [am]
	var xfs: Array[Transform3D] = [Transform3D.IDENTITY]
	var root := VoxelProp.place(parent, "Pebbles", meshes, [80.0], xfs, 1)
	VoxelQuality.tier = keep
	var mmi := root.get_child(0) as MultiMeshInstance3D
	assert_eq(mmi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_tiles_of_a_far_region_hide_behind_one_merged_far_node() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	var meshes: Array[ArrayMesh] = []
	for m: PrimitiveMesh in [BoxMesh.new(), BoxMesh.new()]:
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.get_mesh_arrays())
		meshes.append(am)
	var xfs: Array[Transform3D] = []
	for i in 4:
		xfs.append(Transform3D(Basis(), Vector3(VoxelProp.TILE * i + 1.0, 0, 1)))
	var root := VoxelProp.place(parent, "Things", meshes, [60.0, 0.0], xfs, 1)
	var far := root.get_node("Things_far_0_0") as MultiMeshInstance3D
	assert_eq(far.multimesh.instance_count, 4, "every copy, last tier")
	# The farthest tile centre is 1.5 tiles from the region centre.
	assert_almost_eq(far.visibility_range_begin, 60.0 + VoxelProp.TILE * 1.5 + 1.0, 0.01)
	for node: MultiMeshInstance3D in root.get_children():
		if node != far:
			assert_eq(node.get_node(node.visibility_parent), far)
