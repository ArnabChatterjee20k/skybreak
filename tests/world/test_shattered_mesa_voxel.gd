extends GutTest
## Shattered Mesa's voxel look-dev keeps the sim's truth: the visible floor lies
## on the sim's ground, and the props take ShatteredMesaProps' transforms.

const FEET_TOLERANCE := 0.044

var _map: TerrainHeightmap
var _zone: ZoneData


func before_all() -> void:
	_map = load(WorldMap.HEIGHTMAP_PATH)
	_zone = load("res://game/world/zones/shattered_mesa.tres")


func _terrain() -> MesaTerrain:
	var c := _zone.centre
	var t := MesaTerrain.new(_map, c - _zone.extent, c + _zone.extent, c - Vector2(720, 700), Vector2(1012, 1012))
	t._classify()
	return t


## Worst |visible - sim| height over floor triangles of the chunk around `at`.
func _worst_gap(t: MesaTerrain, at: Vector2) -> float:
	var s := t._sample_of(at)
	var mesh := t._floor_chunk(s.x - 8, s.y - 8, s.x + 8, s.y + 8, 1)
	assert_not_null(mesh, "floor exists at %s" % at)
	if mesh == null:
		return INF
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var worst := 0.0
	for i in range(0, verts.size(), 3):
		if uvs[i].y > 0.5:
			continue  # a skirt, not walkable
		for w: Vector3 in [Vector3(1, 1, 1) / 3.0, Vector3(0.6, 0.2, 0.2), Vector3(0.2, 0.6, 0.2), Vector3(0.2, 0.2, 0.6),
				Vector3(0.5, 0.5, 0.0), Vector3(0.0, 0.5, 0.5), Vector3(0.5, 0.0, 0.5)]:
			var p := verts[i] * w.x + verts[i + 1] * w.y + verts[i + 2] * w.z
			worst = maxf(worst, absf(p.y - _map.ground_height_at(p.x, p.z)))
	return worst


func test_the_visible_floor_at_the_spawns_lies_on_the_sim_ground() -> void:
	var t := _terrain()
	for sp in _zone.spawn_points:
		assert_lt(_worst_gap(t, Vector2(sp.x, sp.z)), FEET_TOLERANCE)


func test_the_visible_mesa_tops_lie_on_the_sim_ground() -> void:
	var t := _terrain()
	# The Anvil Mesa's and the Great Mesa's tops.
	for i: int in [4, 2]:
		var mc: Vector2 = _zone.centre + TerrainShape.MESAS[i][0]
		assert_lt(_worst_gap(t, mc), FEET_TOLERANCE)


func test_cliff_cells_get_no_floor_and_flat_cells_do() -> void:
	var t := _terrain()
	var anvil: Vector2 = _zone.centre + TerrainShape.MESAS[4][0]
	var top := t._sample_of(anvil)
	assert_true(t._floor_cell(top.x, top.y, 1), "the mesa top is floor")
	# Walk out from the centre: somewhere the wall is too steep to be floor.
	var found := false
	for k in 60:
		var s := t._sample_of(anvil + Vector2(k * 1.0, 0.0))
		if not t._floor_cell(s.x, s.y, 1):
			found = true
			break
	assert_true(found, "the Anvil Mesa's wall is cliff")


func test_props_take_the_sims_hoodoo_boulder_and_arch_transforms() -> void:
	var z := ShatteredMesaVoxel.new()
	var p := MesaProps.new(z)
	p._placements()
	assert_eq(p._pillars.size(), 46, "46 hoodoos")
	assert_eq(p._boulders.size(), 220, "220 boulders")
	var arch := Vector2(p._arch.origin.x, p._arch.origin.z)
	assert_almost_eq(arch.distance_to(Vector2(590, 330)), 0.0, 0.01, "the Red Arch stands where the sim has it")
	z.free()
