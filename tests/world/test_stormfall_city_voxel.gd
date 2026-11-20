extends GutTest
## Stormfall City's voxel look (game/world/zones_voxel/stormfall_city/): the
## sim's layout stays the truth and the block mesher stays cheap.

var _zone: StormfallCityVoxel


func before_all() -> void:
	_zone = StormfallCityVoxel.new()
	_zone.zone = load("res://game/world/zones/stormfall_city.tres")
	_zone.layout = ZoneLayout.load_default()
	_zone.heightmap = load(WorldMap.HEIGHTMAP_PATH)
	_zone._placements()


func after_all() -> void:
	_zone.free()


func test_placements_are_the_sims_own_props_with_the_zone_match_seed() -> void:
	var kit := PropKit.new(_zone.heightmap, WorldMap.PROP_SEED)
	for z in _zone.layout.ground_zones():
		for p in z.spawn_points:
			kit.keep_clear.append(Vector3(p.x, p.z, WorldMap.SPAWN_CLEAR_RADIUS))
	var scratch := Node3D.new()
	StormfallCityProps.build(scratch, kit, _zone.zone, _zone.layout)
	var sim: Array = scratch.get_node("Buildings").get_meta(PropKit.INSTANCE_TRANSFORMS_META)
	var cars: Array = scratch.get_node("Cars").get_meta(PropKit.INSTANCE_TRANSFORMS_META)
	assert_eq(_zone.buildings.size(), sim.size())
	assert_eq(_zone.buildings[0], sim[0])
	assert_eq(_zone.buildings[-1], sim[-1])
	assert_eq(_zone.cars.size(), cars.size())
	scratch.free()


func test_the_signal_and_old_towers_sit_on_the_sims_tower_blocks() -> void:
	assert_true(_zone.towers.has("Signal Tower"))
	assert_true(_zone.towers.has("Old Tower"))
	assert_true(_zone.towers.has("Spire Tower"), "the Spire stands in as a visual landmark")
	var signal_tower: Transform3D = _zone.towers["Signal Tower"]
	assert_true(signal_tower in _zone.buildings)


func test_the_visible_street_is_the_sims_floor_within_the_foot_tolerance() -> void:
	# The spawn plaza and a tile across the canal's embankments.
	var verts := PackedVector3Array()
	for o in [Vector2(-48, 384), Vector2(-96, 480)]:
		verts.append_array(_zone._ground_mesh(o, 2.0).surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	var ground := ZoneGround.bake(_zone.heightmap, null, _zone.zone.centre, 300.0)
	var worst := 0.0
	for i in range(0, verts.size(), 3):
		# Triangle centroids: the worst spot between the shared grid vertices.
		var c := (verts[i] + verts[i + 1] + verts[i + 2]) / 3.0
		var sim := ground.height_at(c.x, c.z, c.y + 5.0)
		worst = maxf(worst, absf(c.y - sim) * 100.0)
	assert_lt(worst, 4.4, "cm between the visible street and the sim floor")


func test_a_box_costs_twelve_triangles_whatever_its_size() -> void:
	var b := CityBlocks.new()
	b.box(Vector3.ZERO, Vector3(40, 60, 30), Color.GRAY, CityBlocks.Code.FACADE, VoxelZone.T2)
	assert_eq(b.triangles(), 12)
	b.box(Vector3.ZERO, Vector3(1, 1, 1), Color.GRAY, CityBlocks.Code.CONCRETE, VoxelZone.T1, CityBlocks.NO_BOTTOM)
	assert_eq(b.triangles(), 22)


func test_block_faces_carry_their_size_cell_and_material_code() -> void:
	var b := CityBlocks.new()
	b.box(Vector3(0, 5, 0), Vector3(4, 10, 2), Color(0.5, 0.5, 0.5), CityBlocks.Code.NEON, VoxelZone.T0, 0b000001)
	var arrays := b.commit().surface_get_arrays(0)
	var custom: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	assert_almost_eq(custom[0], 2.0, 1e-4, "+x face is as wide as the box is deep")
	assert_almost_eq(custom[1], 10.0, 1e-4)
	assert_almost_eq(custom[2], VoxelZone.T0, 1e-6)
	assert_eq(int(colors[0].a * 255.0), CityBlocks.Code.NEON)


func test_the_only_saturated_zone_colour_is_the_magenta_accent() -> void:
	var muted: Array[Color] = [StormfallCityVoxel.ASPHALT, StormfallCityVoxel.CONCRETE, StormfallCityVoxel.BRICK,
		StormfallCityVoxel.STONE, StormfallCityVoxel.STEEL, StormfallCityVoxel.RUST, StormfallCityVoxel.WINDOW,
		StormfallCityVoxel.SODIUM]
	muted.append_array(StormfallCityVoxel.CAR_COLOURS)
	for c in muted:
		assert_lt(c.s, 0.46, "%s stays under the saturation ceiling" % c.to_html(false))
	assert_gt(StormfallCityVoxel.MAGENTA.s, 0.7)
	assert_almost_eq(StormfallCityVoxel.MAGENTA.h * 360.0, 327.0, 6.0)


func test_night_sky_is_lighter_than_the_facades_and_never_violet() -> void:
	var night: Dictionary = _zone.presets().night
	assert_gt((night.sky_horizon as Color).get_luminance(), StormfallCityVoxel.CONCRETE.get_luminance() * 0.9)
	for key in ["sky_top", "sky_horizon", "fog_color"]:
		var c: Color = night[key]
		assert_lt(c.s, 0.3, "%s stays slate" % key)
	var rim: Color = night.rim_color
	assert_lt(rim.s, 0.2, "cool white rim, not cyan")
