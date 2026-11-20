extends GutTest
## Verdant Falls voxel look (game/world/zones_voxel/verdant_falls/): the sim
## stays the truth (floor, trees, falls), and the palette keeps the sheet's rules.

var _zone: VerdantFallsVoxel


func before_all() -> void:
	_zone = VerdantFallsVoxel.new()
	_zone.map = load(VerdantFallsVoxel.HEIGHTMAP)
	_zone.layout = ZoneLayout.load_default()
	_zone.zone = load("res://game/world/zones/verdant_falls.tres")
	_zone.centre = _zone.zone.centre
	for p in _zone.zone.spawn_points:
		_zone.spawns.append(Vector2(p.x, p.z))
	_zone._placements()
	_zone._canopy_shade()
	_zone._pick_story_spots()


func after_all() -> void:
	_zone.free()


func test_the_visible_floor_stays_on_the_sims_zone_ground() -> void:
	var ground := ZoneGround.bake(_zone.map, null, _zone.centre, 330.0)
	var spawn := _zone.spawns[0]
	var hf := VoxelHeightfield.new(VoxelZone.T1, spawn - Vector2(5, 5), spawn + Vector2(5, 5))
	for z in hf.size.y:
		for x in hf.size.x:
			var h := _zone.ground_at(hf.centre(x, z).x, hf.centre(x, z).y)
			hf.set_column(x, z, roundi(h / hf.cell), roundi((h - 1.2) / hf.cell), Color.WHITE)
	hf.smooth_height = func(x: float, z: float) -> float: return _zone.ground_at(x, z)
	var arrays := hf.chunk_mesh(0, 0).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var checked := 0
	for k in verts.size():
		if normals[k].y > 0.5:
			assert_almost_eq(verts[k].y, ground.height_at(verts[k].x, verts[k].z, verts[k].y), 0.044, "QA foot check: within half a T1 cell")
			checked += 1
	assert_gt(checked, 0)


func test_trees_and_falls_come_from_the_sims_prop_builder() -> void:
	assert_eq(_zone.trunks.size(), 150, "VerdantFallsProps places 150 trees")
	assert_eq(_zone.canopies.size(), _zone.trunks.size() * 2, "two canopy layers per tree")
	assert_eq(_zone.falls_quad.size(), 4, "the curtain's four corners")
	for k in 40:
		assert_gte(_zone.tree_radius(k), 4.5, "the first 40 are giants")


func test_story_props_stay_out_of_the_spawn_ring() -> void:
	for w: Vector2 in [_zone.shrine_at, _zone.fallen_at, _zone.sluice_at, _zone.islet_at]:
		assert_false(_zone.near_spawn(w), "%s is outside the 25 m ring" % w)
	assert_eq(_zone.grove_pair.size(), 2, "two giants carry the walkway")


func test_only_the_orchid_accent_passes_the_saturation_ceiling() -> void:
	var M := VerdantFallsVoxel.Mat
	for mat: int in VerdantFallsVoxel.COLORS:
		var c: Color = VerdantFallsVoxel.COLORS[mat]
		if mat in [M.ORCHID, M.ORCHID_DARK]:
			assert_gt(c.s, 0.45, "the accent is saturated")
			continue
		assert_lte(c.s, 0.62, "%s stays muted" % M.keys()[mat])


func test_the_day_sky_is_lighter_than_the_canopy_and_the_fog_is_not_mint() -> void:
	var day: Dictionary = _zone.presets().day
	var sky: Color = day.sky_horizon
	assert_gt(sky.get_luminance(), VerdantFallsVoxel.COLORS[VerdantFallsVoxel.Mat.LEAF_TOP].get_luminance() + 0.3)
	var fog: Color = day.fog_color
	assert_lt(fog.s, 0.12, "warm pale fog, not the foliage's green")
