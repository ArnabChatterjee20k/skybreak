extends GutTest

const WORLD_SCENE := preload("res://game/world/world_map.tscn")

var world: WorldMap


func before_all() -> void:
	world = WORLD_SCENE.instantiate()
	add_child(world)


func after_all() -> void:
	world.free()


func test_world_scene_loads_with_terrain_props_boundary_and_atmosphere() -> void:
	assert_not_null(world.heightmap, "heightmap")
	assert_eq(world.terrain.get_child_count(), 16 * 16 * TerrainGrid.LOD_COUNT, "chunks per LOD")
	assert_gt(world.props.get_child_count(), 6, "zone prop groups plus planes")
	assert_not_null(world.boundary.get_node_or_null("EnergyDome"), "dome")
	assert_not_null(world.atmosphere.layout, "atmosphere set up")


func test_bounds_cover_two_km_with_a_400_m_ceiling() -> void:
	var b := world.bounds()
	assert_almost_eq(b.size.x, 2000.0, 0.01)
	assert_almost_eq(b.size.z, 2000.0, 0.01)
	assert_almost_eq(b.end.y, 400.0, 0.01, "ceiling")
	assert_almost_eq(b.get_center().x, 0.0, 0.01)
	assert_almost_eq(b.get_center().z, 0.0, 0.01)


func test_ground_stays_inside_the_bounds_and_under_the_ceiling() -> void:
	var b := world.bounds()
	var highest := -INF
	var lowest := INF
	for h in world.heightmap.heights:
		highest = maxf(highest, h)
		lowest = minf(lowest, h)
	assert_lt(highest, b.end.y - 50.0, "ground leaves room under the ceiling")
	assert_gt(lowest, b.position.y, "ground above the floor of the bounds")


func test_heightmap_covers_the_bounds() -> void:
	var map := world.heightmap
	var b := world.bounds()
	assert_lte(map.origin.x, b.position.x)
	assert_lte(map.origin.y, b.position.z)
	assert_gte(map.origin.x + map.world_size(), b.end.x)
	assert_gte(map.origin.y + map.world_size(), b.end.z)


func test_zone_ids_lists_the_six_zones() -> void:
	assert_eq(world.zone_ids(), [&"shattered_mesa", &"skyhold_ruins", &"stormfall_city",
		&"frozen_peaks", &"verdant_falls", &"ember_rift"])


func test_zone_at_covers_the_whole_map_and_returns_each_zone_somewhere() -> void:
	var seen := {}
	var b := world.bounds()
	var step := 25.0
	var x := b.position.x
	while x <= b.end.x:
		var z := b.position.z
		while z <= b.end.z:
			var zone := world.zone_at(x, z)
			assert_not_null(zone)
			if zone == null:
				return
			seen[zone.id] = seen.get(zone.id, 0) + 1
			z += step
		x += step
	assert_eq(seen.size(), 6, "all six zones appear")
	for id in world.zone_ids():
		# Each zone is roughly 600-800 m across: at least ~10% of the map.
		assert_gt(seen.get(id, 0), 640, "%s owns a big area" % id)


func test_zone_at_returns_the_zone_at_its_own_centre() -> void:
	for id in world.zone_ids():
		var data := world.zone(id)
		assert_eq(world.zone_at(data.centre.x, data.centre.y).id, id)


func test_spawn_points_are_two_points_about_40_m_apart_above_the_ground() -> void:
	for id in world.zone_ids():
		var points := world.spawn_points(id)
		assert_eq(points.size(), 2, "%s has two spawns" % id)
		if points.size() != 2:
			continue
		assert_almost_eq(points[0].distance_to(points[1]), 40.0, 2.0, "%s spawns ~40 m apart" % id)
		for p in points:
			assert_gt(p.y, world.ground_height_at(p.x, p.z) + 1.0, "%s spawn above ground" % id)
			assert_eq(world.zone_at(p.x, p.z).id, id, "%s spawn inside its zone" % id)
			assert_true(world.bounds().has_point(p), "%s spawn inside the bounds" % id)


func test_spawn_points_are_kept_clear_of_props() -> void:
	for group in world.props.get_children():
		for node in group.get_children():
			var mmi := node as MultiMeshInstance3D
			if mmi == null:
				continue
			var mm := mmi.multimesh
			for i in mm.instance_count:
				var origin := mm.get_instance_transform(i).origin
				for id in world.zone_ids():
					for p in world.spawn_points(id):
						# Floating islands and their columns may sit high above a spawn.
						if absf(origin.y - p.y) > 60.0:
							continue
						var d := Vector2(origin.x - p.x, origin.z - p.z).length()
						assert_gt(d, 8.0, "%s/%s instance %d clear of %s spawn" % [group.name, node.name, i, id])
						if d <= 8.0:
							return


func test_unknown_zone_has_no_spawn_points() -> void:
	assert_eq(world.spawn_points(&"nowhere").size(), 0)


func test_destructible_candidates_are_marked() -> void:
	var marked := get_tree().get_nodes_in_group(PropKit.DESTRUCTIBLE_GROUP)
	var kinds := {}
	for node in marked:
		if world.is_ancestor_of(node):
			kinds[node.get_meta("destructible")] = true
	for kind in ["rock_pillar", "column", "building_corner", "water_tower", "car", "ice_spire", "giant_trunk", "obsidian_spire"]:
		assert_true(kinds.has(kind), "%s marked destructible" % kind)


func test_every_zone_has_named_landmarks() -> void:
	for id in world.zone_ids():
		var data := world.zone(id)
		assert_gt(data.landmark_names.size(), 1, "%s landmarks" % id)
		assert_eq(data.landmark_names.size(), data.landmark_positions.size())


func test_every_zone_has_props() -> void:
	for group in world.props.get_children():
		if not group.has_meta("zone_id"):
			continue
		var instances := 0
		for node in group.get_children():
			if node is MultiMeshInstance3D:
				instances += (node as MultiMeshInstance3D).multimesh.instance_count
		assert_gt(instances, 20, "%s has props" % group.name)
