extends GutTest

const HEIGHTMAP := "res://game/world/terrain/terrain_heightmap.res"
const SHADER := "res://game/world/shaders/terrain_toon.gdshader"

var map: TerrainHeightmap


func before_all() -> void:
	map = load(HEIGHTMAP)


func test_heightmap_is_a_2_km_grid_of_2_m_cells() -> void:
	assert_eq(map.size, 1025)
	assert_almost_eq(map.cell_size, 2.0, 0.0001)
	assert_eq(map.heights.size(), map.size * map.size)
	assert_almost_eq(map.world_size(), 2048.0, 0.01)
	assert_eq(map.zone_weights.size(), map.weights_size * map.weights_size * 6)


func test_ground_height_is_exact_at_samples() -> void:
	for sample in [Vector2i(0, 0), Vector2i(512, 300), Vector2i(1024, 1024), Vector2i(77, 901)]:
		var p := map.sample_position(sample.x, sample.y)
		assert_eq(map.ground_height_at(p.x, p.y), map.height_at_sample(sample.x, sample.y))


func test_ground_height_is_bilinear_between_samples() -> void:
	var p := map.sample_position(400, 600)
	var h00 := map.height_at_sample(400, 600)
	var h10 := map.height_at_sample(401, 600)
	var h01 := map.height_at_sample(400, 601)
	var h11 := map.height_at_sample(401, 601)
	var expected := lerpf(lerpf(h00, h10, 0.25), lerpf(h01, h11, 0.25), 0.75)
	assert_almost_eq(map.ground_height_at(p.x + 0.5, p.y + 1.5), expected, 0.0001)


func test_ground_height_is_deterministic() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var first := PackedFloat64Array()
	var points: Array[Vector2] = []
	for i in 500:
		points.append(Vector2(rng.randf_range(-1100.0, 1100.0), rng.randf_range(-1100.0, 1100.0)))
	for p in points:
		first.append(map.ground_height_at(p.x, p.y))
	var reloaded: TerrainHeightmap = ResourceLoader.load(HEIGHTMAP, "", ResourceLoader.CACHE_MODE_IGNORE)
	for i in points.size():
		assert_eq(reloaded.ground_height_at(points[i].x, points[i].y), first[i])
		if reloaded.ground_height_at(points[i].x, points[i].y) != first[i]:
			return


func test_ground_height_clamps_outside_the_grid() -> void:
	assert_eq(map.ground_height_at(-5000.0, -5000.0), map.height_at_sample(0, 0))
	assert_eq(map.ground_height_at(5000.0, 5000.0), map.height_at_sample(map.size - 1, map.size - 1))


func test_baked_heights_match_the_generator() -> void:
	var shape := TerrainShape.new(ZoneLayout.load_default())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		var column := rng.randi_range(0, map.size - 1)
		var row := rng.randi_range(0, map.size - 1)
		var p := map.sample_position(column, row)
		assert_almost_eq(map.height_at_sample(column, row), shape.height_at(p.x, p.y), 0.001,
			"sample %d,%d; re-run bake_terrain.gd after changing the generator" % [column, row])


func test_zone_shaping_gives_each_zone_its_heights() -> void:
	var layout := ZoneLayout.load_default()
	var mesa := layout.zones[layout.index_of(&"shattered_mesa")]
	var city := layout.zones[layout.index_of(&"stormfall_city")]
	var peaks := layout.zones[layout.index_of(&"frozen_peaks")]
	var ember := layout.zones[layout.index_of(&"ember_rift")]
	# Great Mesa top stands well above the desert floor.
	assert_gt(map.ground_height_at(400.0, 540.0) - map.ground_height_at(490.0, 490.0), 50.0, "mesa")
	# City ground is flat: under 3 m variation around the spawn street.
	var a := map.ground_height_at(city.centre.x - 40.0, city.centre.y - 78.0)
	var b := map.ground_height_at(city.centre.x, city.centre.y - 78.0)
	assert_lt(absf(a - b), 3.0, "city is flattened")
	# Peaks rise far above the glacier valley floor.
	var highest := 0.0
	for k in 40:
		highest = maxf(highest, map.ground_height_at(peaks.centre.x - 300.0 + k * 15.0, peaks.centre.y - 300.0))
	assert_gt(highest, 180.0, "glacier ridges")
	# Crater: rim far above the floor.
	assert_gt(map.ground_height_at(ember.centre.x, ember.centre.y - 270.0) - map.ground_height_at(ember.centre.x, ember.centre.y + 90.0), 70.0, "crater rim")
	# Lake bed below the water plane at 0 m.
	assert_lt(map.ground_height_at(-640.0, 450.0), -5.0, "lake bed")
	# Waterfall cliff: the plateau north of the lake is far higher.
	assert_gt(map.ground_height_at(-660.0, 290.0) - map.ground_height_at(-660.0, 350.0), 80.0, "waterfall cliff")


func test_ground_height_matches_the_rendered_mesh_vertices() -> void:
	var image := map.to_height_image()
	var chunk_cells := TerrainGrid.CHUNK_CELLS
	for chunk in [Vector2i(0, 0), Vector2i(7, 9), Vector2i(15, 15)]:
		var origin := map.sample_position(chunk.x * chunk_cells, chunk.y * chunk_cells)
		for lod in TerrainGrid.LOD_COUNT:
			var mesh := TerrainGrid.mesh_for_lod(lod, map.cell_size)
			var arrays := mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var checked := 0
			for i in verts.size():
				if uvs[i].x > 0.5:
					continue  # skirt
				var world := Vector3(origin.x, 0.0, origin.y) + verts[i]
				var fx := (world.x - map.origin.x) / map.cell_size
				var fz := (world.z - map.origin.y) / map.cell_size
				# The shader fetches the texel at the rounded index; vertices sit exactly on it.
				assert_almost_eq(fx, roundf(fx), 0.0001)
				assert_almost_eq(fz, roundf(fz), 0.0001)
				var lifted := image.get_pixel(int(roundf(fx)), int(roundf(fz))).r
				assert_almost_eq(lifted, map.ground_height_at(world.x, world.z), 0.0001)
				checked += 1
			assert_eq(checked, ((chunk_cells >> lod) + 1) * ((chunk_cells >> lod) + 1))


func test_terrain_shader_lifts_vertices_with_the_same_index_math() -> void:
	var code := (load(SHADER) as Shader).code
	assert_string_contains(code, "ivec2 idx = ivec2(round((wp.xz - map_origin) / cell_size));")
	assert_string_contains(code, "texelFetch(heightmap, p, 0).r")
	assert_string_contains(code, "VERTEX.y = h - UV.x * skirt_depth")


func test_lod_picks_lower_detail_with_distance() -> void:
	assert_eq(TerrainGrid.lod_for_distance(0.0), 0)
	assert_eq(TerrainGrid.lod_for_distance(100.0), 0)
	var previous := 0
	var distance := 0.0
	while distance < 1250.0:
		var lod := TerrainGrid.lod_for_distance(distance)
		assert_gte(lod, previous, "never more detail further away (%.0f m)" % distance)
		previous = lod
		distance += 10.0
	assert_eq(TerrainGrid.lod_for_distance(1200.0), TerrainGrid.LOD_COUNT - 1)
	assert_eq(TerrainGrid.lod_for_distance(1400.0), -1, "culled past the fog")
	for lod in range(1, TerrainGrid.LOD_COUNT):
		assert_lt(TerrainGrid.triangle_count(lod), TerrainGrid.triangle_count(lod - 1), "LOD %d is coarser" % lod)


func test_lod_meshes_have_the_counted_triangles() -> void:
	for lod in TerrainGrid.LOD_COUNT:
		var mesh := TerrainGrid.mesh_for_lod(lod, map.cell_size)
		var indices: PackedInt32Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		assert_eq(indices.size() / 3, TerrainGrid.triangle_count(lod))


func test_chunk_lods_partition_the_distance_without_gaps() -> void:
	var terrain := WorldTerrain.new()
	add_child(terrain)
	terrain.build(map, ZoneLayout.load_default().zones)
	var by_chunk := {}
	for chunk: MeshInstance3D in terrain.get_children():
		var key := chunk.position
		by_chunk[key] = by_chunk.get(key, []) + [chunk]
	assert_eq(by_chunk.size(), 256)
	for key in by_chunk:
		var lods: Array = by_chunk[key]
		assert_eq(lods.size(), TerrainGrid.LOD_COUNT)
		lods.sort_custom(func(a, b): return a.get_meta("lod") < b.get_meta("lod"))
		for i in lods.size():
			var c: MeshInstance3D = lods[i]
			assert_eq(c.custom_aabb, (lods[0] as MeshInstance3D).custom_aabb, "LODs share one AABB, so one is drawn")
			if i > 0:
				assert_eq(c.visibility_range_begin, (lods[i - 1] as MeshInstance3D).visibility_range_end)
			var shadows := c.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			assert_eq(shadows, i < WorldTerrain.SHADOW_LODS, "only near chunks cast shadows")
		break
	terrain.free()


func test_chunk_bounds_contain_the_terrain() -> void:
	var terrain := WorldTerrain.new()
	add_child(terrain)
	terrain.build(map, ZoneLayout.load_default().zones)
	for chunk: MeshInstance3D in terrain.get_children():
		if chunk.get_meta("lod") != 0:
			continue
		var box := chunk.custom_aabb
		for k in 5:
			var p := Vector3(chunk.position.x + box.size.x * k / 4.0, 0.0, chunk.position.z + box.size.z * (4 - k) / 4.0)
			var h := map.ground_height_at(p.x, p.z)
			assert_true(h >= box.position.y and h <= box.end.y, "%s holds its ground" % chunk.name)
	terrain.free()
