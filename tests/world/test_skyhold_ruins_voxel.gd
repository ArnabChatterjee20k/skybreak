extends GutTest
## Skyhold Ruins' voxel look (game/world/zones_voxel/skyhold_ruins/): it reads
## the sim's layout as-is and keeps the paving on the island tops.

var _zone: SkyholdRuinsVoxel


func before_all() -> void:
	_zone = SkyholdRuinsVoxel.new()
	_zone.layout = SkyholdRuinsLayout.read()
	for isl in _zone.layout.islands:
		_zone._chords.append(_zone._outline(isl))


func after_all() -> void:
	_zone.free()


func test_the_layout_matches_the_sim_props_builder() -> void:
	var scratch := Node3D.new()
	var map := load(WorldMap.HEIGHTMAP_PATH) as TerrainHeightmap
	var kit := PropKit.new(map, WorldMap.PROP_SEED)
	var layout := ZoneLayout.load_default()
	for zd in layout.ground_zones():
		for p in zd.spawn_points:
			kit.keep_clear.append(Vector3(p.x, p.z, WorldMap.SPAWN_CLEAR_RADIUS))
	SkyholdRuinsProps.build(scratch, kit, _zone.layout.zone, layout)
	assert_eq(_zone.layout.islands.size(), int(scratch.get_meta("island_count")))
	scratch.free()


func test_crown_and_watch_islands_sit_on_their_landmarks() -> void:
	var crown := _zone.layout.named("Crown Island")
	var watch := _zone.layout.named("Watch Island")
	assert_not_null(crown)
	assert_not_null(watch)
	assert_almost_eq(crown.top, 190.0, 0.01)
	assert_almost_eq(watch.top, 150.0, 0.01)
	assert_almost_eq(crown.radius, 55.0, 0.01)


func test_every_sim_column_stands_inside_its_fractured_outline() -> void:
	for i in _zone.layout.islands.size():
		for col: Dictionary in _zone.layout.islands[i].columns:
			var at: Vector3 = col.at
			assert_lt(_zone._gauge(i, Vector2(at.x, at.z)), 0.97, "column inside island %d" % i)


func test_the_paving_is_the_island_top_plus_the_cap() -> void:
	for isl in _zone.layout.islands:
		assert_almost_eq(_zone.ground_at(isl.centre.x, isl.centre.y), isl.top + SkyholdRuinsVoxel.CAP, 0.001)


func test_a_built_paving_top_lies_within_a_voxel_half_cell_of_the_floor() -> void:
	var i := 0
	for k in _zone.layout.islands.size():
		if _zone.layout.islands[k].radius < _zone.layout.islands[i].radius:
			i = k
	var node := _zone._island_top(i)
	var top := -INF
	for mi: MeshInstance3D in node.get_children():
		for v: Vector3 in mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			top = maxf(top, v.y + node.position.y)
	assert_almost_eq(top, _zone.layout.islands[i].top + SkyholdRuinsVoxel.CAP, 0.044)


func test_only_bronze_is_saturated() -> void:
	var M := SkyholdRuinsDesigns.Mat
	var accents := [M.VERDIGRIS, M.PATINA, M.FLAME, M.FLOWER_Y]
	for mat: int in SkyholdRuinsDesigns.COLORS:
		if mat in accents:
			continue
		assert_lt((SkyholdRuinsDesigns.COLORS[mat] as Color).s, 0.46, "material %d under the saturation ceiling" % mat)
