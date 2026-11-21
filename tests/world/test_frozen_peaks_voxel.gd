extends GutTest
## Frozen Peaks voxel look-dev (game/world/zones_voxel/frozen_peaks/): the
## visible floor stays on the sim floor, and the voxel props keep the sim's
## placements and sizes.

const SPAWN := Vector2(-670, -530)


func _zone() -> FrozenPeaksVoxel:
	var z := FrozenPeaksVoxel.new()
	z.map = load(WorldMap.HEIGHTMAP_PATH)
	z.layout = ZoneLayout.load_default()
	z.zone = load("res://game/world/zones/frozen_peaks.tres")
	z.centre = z.zone.centre
	autofree(z)
	return z


func test_the_floor_lattice_quads_are_one_metre_and_sit_on_the_height_function() -> void:
	var hf := FrozenHeightfield.new(VoxelZone.T1, Vector2.ZERO, Vector2(9.9, 9.9))
	for z in hf.size.y:
		for x in hf.size.x:
			hf.set_column(x, z, 0, 0, Color.WHITE)
	hf.smooth_height = func(x: float, z: float) -> float: return 0.1 * x + 0.05 * z
	var height: Callable = hf.smooth_height
	var verts: PackedVector3Array = hf.chunk_mesh(0, 0).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_gt(verts.size(), 0)
	for t in range(0, verts.size(), 3):
		var a := verts[t]
		for k in [1, 2]:
			assert_lt(absf(verts[t + k].x - a.x), 1.01)
			assert_lt(absf(verts[t + k].z - a.z), 1.01)
		assert_almost_eq(fposmod(a.x, 1.0), 0.0, 1e-3, "on the 1 m lattice")
		assert_almost_eq(a.y, float(height.call(a.x, a.z)), 1e-4)


func test_the_valley_floor_at_the_spawns_stays_within_feet_tolerance_of_the_sim_floor() -> void:
	var zone := _zone()
	var hf := FrozenHeightfield.new(VoxelZone.T1, SPAWN - Vector2(10, 10), SPAWN + Vector2(10, 10))
	for z in hf.size.y:
		for x in hf.size.x:
			var w := hf.centre(x, z)
			var lv := roundi(zone.ground_at(w.x, w.y) / hf.cell)
			hf.set_column(x, z, lv, lv, Color.WHITE)
	hf.smooth_height = zone.ground_at
	var ground := ZoneGround.bake(zone.map, null, zone.centre, 300.0)
	var verts: PackedVector3Array = hf.chunk_mesh(0, 0).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var worst := 0.0
	for t in range(0, verts.size(), 3):
		# The triangle's centroid against the sim's integer floor.
		var c := (verts[t] + verts[t + 1] + verts[t + 2]) / 3.0
		worst = maxf(worst, absf(c.y - ground.height_at(c.x, c.z, INF)))
	assert_lt(worst, 0.044, "visible floor within T1 / 2 of the sim floor")


func test_voxel_spires_shelves_and_boulders_keep_the_sim_placements() -> void:
	var zone := _zone()
	zone._placements()
	assert_eq(zone.sim_spires.size(), 60)
	assert_eq(zone.sim_shelves.size(), 26)
	assert_eq(zone.sim_boulders.size(), 120)
	for xf in zone.sim_spires:
		var fit := FrozenPeaksDesigns.fit_spire(xf)
		var spec: Array = FrozenPeaksDesigns.SPIRES[fit[0]]
		var placed: Transform3D = fit[1]
		var sc := xf.basis.get_scale()
		var base := xf.origin - xf.basis * Vector3(0, 0.5, 0)
		assert_almost_eq(placed.origin.distance_to(base), 0.0, 0.01, "same base")
		assert_almost_eq(float(spec[0]) * placed.basis.get_scale().y, absf(sc.y), 0.01, "same height")
		var r := float(spec[1]) * placed.basis.get_scale().x
		assert_between(r / (absf(sc.x) * 0.5), 0.5, 1.6, "footprint near the sim cone's")
	for xf in zone.sim_shelves:
		var fit := FrozenPeaksDesigns.fit_shelf(xf)
		var placed: Transform3D = fit[1]
		assert_almost_eq(placed.origin.distance_to(xf.origin), 0.0, 0.01)
		var size := Vector3(FrozenPeaksDesigns.SHELVES[fit[0]][0], 4.0, FrozenPeaksDesigns.SHELVES[fit[0]][1]) * placed.basis.get_scale()
		assert_almost_eq(size.x, absf(xf.basis.get_scale().x), 0.01, "same jut")
		assert_almost_eq(size.z, absf(xf.basis.get_scale().z), 0.01, "same width")


func test_the_crown_star_has_three_long_points_on_top() -> void:
	assert_true(FrozenPeaksDesigns.crown_star(Vector2(0, 0.9)), "top point reaches 0.9")
	assert_false(FrozenPeaksDesigns.crown_star(Vector2(0, -0.9)), "bottom point is short")
	assert_true(FrozenPeaksDesigns.crown_star(Vector2(0, -0.55)))
	assert_true(FrozenPeaksDesigns.crown_star(Vector2.ZERO))


func test_the_fly_through_clears_every_sim_spire() -> void:
	var zone := _zone()
	zone._placements()
	zone._story_layout()
	var pts := zone.flight()
	assert_eq(zone._flight_hit(pts), -1)
