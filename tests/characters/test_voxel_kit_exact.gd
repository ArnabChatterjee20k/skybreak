extends GutTest
## The optimised voxel kit must give bit-identical results to the approved kit
## (kept verbatim in voxel_reference/) on noisy grids that hit every edge case.

const ReferenceGrid := preload("res://tests/characters/voxel_reference/voxel_grid_reference.gd")
const ReferenceMesher := preload("res://tests/characters/voxel_reference/voxel_mesher_reference.gd")
const BOUNDS := AABB(Vector3(-0.31, 0.17, -0.23), Vector3(0.47, 0.39, 0.33))
const CELL := 0.0173


## Paints the same random strokes into grid (either class): spheres and boxes
## in every mode, surface decals, with bounds that overhang the grid.
func _paint_strokes(grid, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for k in 40:
		var c := BOUNDS.position + Vector3(rng.randf(), rng.randf(), rng.randf()) * BOUNDS.size
		var r := rng.randf_range(0.02, 0.12)
		var box := AABB(c - Vector3.ONE * (r + 0.05), Vector3.ONE * (2.0 * r + 0.1))
		var mode := rng.randi_range(0, 3)
		var mat := rng.randi_range(1, 6)
		var tag := rng.randi_range(-1, 3)
		if k % 2 == 0:
			grid.paint(box, func(p: Vector3): return VoxelSdf.sphere(p, c, r), mat, tag, mode)
		else:
			grid.paint(box, func(p: Vector3): return VoxelSdf.box(p, c, Vector3(r, r * 0.6, r * 0.8), r * 0.2), mat, tag, mode)
		if k % 5 == 0:
			var only: Array = [] if k % 10 == 0 else [mat, 2]
			grid.paint_surface(box, func(p: Vector3, cc: Vector3i): return VoxelSdf.hash3(cc, k) < 0.4 and p.y > c.y,
				rng.randi_range(1, 6), only)
	# Speckle: lone cells and pits for smooth() to clean.
	for k in 300:
		var i := rng.randi_range(0, grid.mats.size() - 1)
		grid.mats[i] = 0 if rng.randf() < 0.5 else rng.randi_range(1, 6)
		grid.tags[i] = rng.randi_range(0, 3)


func _grids(seed_value: int) -> Array:
	var fresh := VoxelGrid.new(BOUNDS, CELL)
	var reference = ReferenceGrid.new(BOUNDS, CELL)
	_paint_strokes(fresh, seed_value)
	_paint_strokes(reference, seed_value)
	return [fresh, reference]


func test_paint_and_paint_surface_match_the_reference_grid() -> void:
	for seed_value in [1, 2, 3]:
		var g := _grids(seed_value)
		assert_eq(g[0].mats, g[1].mats, "mats, seed %d" % seed_value)
		assert_eq(g[0].tags, g[1].tags, "tags, seed %d" % seed_value)


func test_paint_samples_exactly_at_cell_centres() -> void:
	var grid := VoxelGrid.new(BOUNDS, CELL)
	var seen := {}
	grid.paint(AABB(BOUNDS.position - Vector3.ONE, BOUNDS.size + Vector3.ONE * 2.0), func(p: Vector3):
		seen[grid.cell_of(p)] = p
		return 1.0, 1)
	assert_eq(seen.size(), grid.mats.size())
	var off := 0
	for c: Vector3i in seen:
		if seen[c] != grid.center(c.x, c.y, c.z):
			off += 1
	assert_eq(off, 0, "samples away from center()")


func test_smooth_matches_the_reference_grid() -> void:
	for seed_value in [4, 5]:
		var g := _grids(seed_value)
		g[0].smooth([1, 3, 5])
		g[1].smooth([1, 3, 5])
		assert_eq(g[0].mats, g[1].mats, "mats, seed %d" % seed_value)
		assert_eq(g[0].tags, g[1].tags, "tags, seed %d" % seed_value)


func test_blurred_occupancy_matches_the_reference_bit_for_bit() -> void:
	var grid: VoxelGrid = _grids(6)[0]
	var s := grid.size
	for r in [1, 2, 3, 5]:
		var pad := 4
		var fast := VoxelMesher._blurred_occupancy(grid, r, pad)
		var slow := ReferenceMesher._blurred_occupancy(grid, r)
		var px := s.x + 2 * pad
		var py := s.y + 2 * pad
		var diff := 0
		for z in s.z:
			for y in s.y:
				for x in s.x:
					if fast[(x + pad) + px * ((y + pad) + py * (z + pad))] != slow[x + s.x * (y + s.y * z)]:
						diff += 1
		assert_eq(diff, 0, "cells differing at r=%d" % r)


func _color(mat: int, p: Vector3, c: Vector3i, n: Vector3, occlusion: float, exposure: float) -> Color:
	return Color(occlusion, exposure, VoxelSdf.hash3(c, mat), 1.0) * (1.0 + 0.1 * p.dot(n))


func _weights(tag: int, p: Vector3) -> Array:
	var a := clampf(p.x * 3.0 + 0.5, 0.0, 1.0)
	return [PackedInt32Array([tag, tag + 1, 0, 0]), PackedFloat32Array([1.0 - a, a, 0.0, 0.0])]


func _surface_of(mat: int) -> int:
	return mat % 2


func test_mesher_matches_the_reference_mesher_bit_for_bit() -> void:
	var materials: Array[Material] = [StandardMaterial3D.new(), StandardMaterial3D.new()]
	for seed_value in [7, 8]:
		var grid: VoxelGrid = _grids(seed_value)[0]
		for blur in [2, 3]:
			var fast := VoxelMesher.build(grid, _color, _surface_of, _weights, materials, blur)
			var slow := ReferenceMesher.build(grid, _color, _surface_of, _weights, materials, blur)
			var a := VoxelBake.checksum(fast)
			var b := VoxelBake.checksum(slow)
			assert_gt(a[0], 1000, "the noisy grid makes plenty of faces")
			assert_eq(a, b, "seed %d blur %d" % [seed_value, blur])
