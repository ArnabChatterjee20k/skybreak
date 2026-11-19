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


func test_zone_ids_lists_the_seven_zones() -> void:
	assert_eq(world.zone_ids(), [&"shattered_mesa", &"skyhold_ruins", &"stormfall_city",
		&"frozen_peaks", &"verdant_falls", &"ember_rift", &"heartbloom_gardens"])


## A height where each zone owns its centre: the ground, or above a floating zone's band.
func _zone_height(data: ZoneData) -> float:
	return data.altitude_band.y + 40.0 if data.is_floating() else -INF


func test_zone_at_on_the_ground_covers_the_map_with_the_six_ground_zones() -> void:
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
	assert_eq(seen.size(), 6, "all six ground zones appear")
	assert_false(seen.has(&"heartbloom_gardens"), "the floating zone is not on the ground")
	for id in world.zone_ids().slice(0, ZoneLayout.GROUND_ZONE_COUNT):
		# Each zone is roughly 600-800 m across: at least ~10% of the map.
		assert_gt(seen.get(id, 0), 640, "%s owns a big area" % id)


func test_heartbloom_owns_a_big_region_of_the_air_above_the_map_centre() -> void:
	var owned := 0
	var step := 25.0
	for x in range(-1000, 1001, int(step)):
		for z in range(-1000, 1001, int(step)):
			if world.zone_at(x, z, 320.0).id == &"heartbloom_gardens":
				owned += 1
				assert_lt(Vector2(x, z).length(), 420.0, "Heartbloom stays over the map centre")
	# 600 m or more across: about 300 samples of 25 m.
	assert_gt(owned, 280, "Heartbloom owns a zone-sized patch of sky")


func test_heartbloom_starts_above_its_altitude_band() -> void:
	var data := world.zone(&"heartbloom_gardens")
	var c := data.centre
	assert_ne(world.zone_at(c.x, c.y, data.altitude_band.x - 1.0).id, &"heartbloom_gardens", "below the band")
	assert_ne(world.zone_at(c.x, c.y).id, &"heartbloom_gardens", "on the ground")
	assert_eq(world.zone_at(c.x, c.y, data.altitude_band.y).id, &"heartbloom_gardens", "at the top of the band")
	assert_eq(world.zone_at(c.x, c.y, 390.0).id, &"heartbloom_gardens", "under the ceiling")
	# The city's towers and Skyhold's islands stay below it.
	assert_gt(data.altitude_band.x, 186.0)


func test_every_island_top_is_in_heartbloom() -> void:
	for i in world.islands.size():
		var p := world.islands.top_point(i, 0.0, 0.0) + Vector3.UP * 2.0
		assert_eq(world.zone_at(p.x, p.z, p.y).id, &"heartbloom_gardens", world.islands.names[i])


func test_zone_at_returns_the_zone_at_its_own_centre() -> void:
	for id in world.zone_ids():
		var data := world.zone(id)
		assert_eq(world.zone_at(data.centre.x, data.centre.y, _zone_height(data)).id, id)


func test_spawn_points_are_two_points_about_40_m_apart_above_the_ground() -> void:
	for id in world.zone_ids():
		var points := world.spawn_points(id)
		assert_eq(points.size(), 2, "%s has two spawns" % id)
		if points.size() != 2:
			continue
		assert_almost_eq(points[0].distance_to(points[1]), 40.0, 2.0, "%s spawns ~40 m apart" % id)
		for p in points:
			assert_gt(p.y, world.ground_height_at(p.x, p.z) + 1.0, "%s spawn above ground" % id)
			assert_eq(world.zone_at(p.x, p.z, p.y).id, id, "%s spawn inside its zone" % id)
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
						# Nor do cloud tufts under the island a spawn stands on.
						if world.islands.island_at(p.x, p.z) >= 0 and origin.y < world.ground_height_at(p.x, p.z, p.y) - 3.0:
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
	for kind in ["rock_pillar", "column", "building_corner", "water_tower", "car", "ice_spire", "giant_trunk", "obsidian_spire",
			"lantern", "blossom_branch"]:
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


func test_heartbloom_spawn_points_stand_on_island_ground() -> void:
	var points := world.spawn_points(&"heartbloom_gardens")
	assert_eq(points.size(), 2)
	for p in points:
		var island := world.islands.island_at(p.x, p.z)
		assert_gte(island, 0, "spawn over an island")
		var top := world.islands.surface_at(p.x, p.z)
		assert_almost_eq(world.ground_height_at(p.x, p.z), top, 0.001, "ground is the island top")
		assert_almost_eq(p.y, top + WorldMap.SPAWN_CLEARANCE, 0.01, "spawn just above the grass")
		assert_lt(world.islands.rim_fraction(island, p.x, p.z), 0.8, "well inside the rim")


func test_ground_height_merges_the_terrain_and_the_islands() -> void:
	var heart := world.islands.index_of("Heart Isle")
	var c := world.islands.centres[heart]
	var top := world.islands.surface_at(c.x, c.y)
	var terrain := world.heightmap.ground_height_at(c.x, c.y)
	assert_almost_eq(world.ground_height_at(c.x, c.y), top, 0.001, "from above: the island")
	assert_almost_eq(world.ground_height_at(c.x, c.y, top + 30.0), top, 0.001, "flying over it: the island")
	assert_almost_eq(world.ground_height_at(c.x, c.y, top - 0.3), top, 0.001, "standing on it")
	assert_almost_eq(world.ground_height_at(c.x, c.y, 120.0), terrain, 0.001, "under it: the terrain")
	# Away from the islands nothing changes.
	assert_eq(world.ground_height_at(-640.0, 470.0), world.heightmap.ground_height_at(-640.0, 470.0))


func test_heartbloom_gameplay_markers_are_in_the_zone_metadata() -> void:
	var data := world.zone(&"heartbloom_gardens")
	assert_true(data.has_meta("petal_whirlwinds"))
	assert_true(data.has_meta("wishing_fountain"))
	var winds: Array = data.get_meta("petal_whirlwinds", [])
	assert_gte(winds.size(), 2, "a few whirlwinds")
	for w in winds:
		var c: Vector3 = w.centre
		assert_gt(float(w.radius), 3.0)
		assert_gt(float(w.lift), 0.0)
		assert_gt(float(w.height), 20.0)
		assert_eq(world.zone_at(c.x, c.z, c.y + w.height * 0.5).id, &"heartbloom_gardens", "whirlwind in the zone")
		assert_lt(world.islands.island_at(c.x, c.z), 0, "whirlwinds stand in open sky between islands")
		# Rises from below the lowest island top to above the highest one.
		assert_lt(c.y, Array(world.islands.tops).min(), "starts below the island tops")
		assert_gt(c.y + float(w.height), Array(world.islands.tops).max(), "lifts above every island")
	var fountain: Dictionary = data.get_meta("wishing_fountain", {})
	var fc: Vector3 = fountain.get("centre", Vector3.ZERO)
	assert_gt(float(fountain.get("heal_per_second", 0)), 0.0)
	assert_gt(float(fountain.get("radius", 0.0)), 3.0)
	assert_eq(world.islands.island_at(fc.x, fc.z), world.islands.index_of("Wishing Isle"), "fountain on Wishing Isle")
	assert_almost_eq(fc.y, world.islands.surface_at(fc.x, fc.z), 0.05, "fountain centre on the ground")


func test_heartbloom_landmarks_and_markers_are_built() -> void:
	var group := world.props.get_node("HeartbloomGardens")
	for name in ["Islands", "HeartArch", "WishingFountain", "FountainWater", "Stream", "Waterfall",
			"PetalWhirlwinds", "Canopies", "Lanterns", "LanternHalos", "BridgeWood", "FountainSpray"]:
		assert_not_null(group.get_node_or_null(name), name)
	assert_eq(group.get_node("Lanterns").get_meta("breaks_into"), "petal_burst")
	assert_eq(group.get_node("Canopies").get_meta("breaks_into"), "petal_burst")


func test_fireflies_only_show_at_night() -> void:
	var group := world.props.get_node("HeartbloomGardens")
	var flies := group.find_children("Fireflies*", "GPUParticles3D", false, false)
	assert_gt(flies.size(), 2)
	world.set_time_of_day(WorldAtmosphere.TimeOfDay.NIGHT)
	for f in flies:
		assert_true((f as GPUParticles3D).visible and (f as GPUParticles3D).emitting, "%s at night" % f.name)
	world.set_time_of_day(WorldAtmosphere.TimeOfDay.DUSK)
	for f in flies:
		assert_false((f as GPUParticles3D).visible, "%s hidden at dusk" % f.name)
	world.set_time_of_day(WorldAtmosphere.TimeOfDay.DAY)
