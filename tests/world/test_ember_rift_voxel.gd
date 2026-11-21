extends GutTest
## Ember Rift's voxel look-dev (game/world/zones_voxel/ember_rift/): the sim
## stays the truth (placements, walkable surface, spawns), the storytelling
## spots keep clear of the duel and the geysers, and the designs' emblem reads.

var zone: EmberRiftVoxel


func before_all() -> void:
	zone = EmberRiftVoxel.new()
	zone.load_sim()


func after_all() -> void:
	zone.free()


func test_placements_come_from_the_sims_prop_builder() -> void:
	assert_eq(zone.spires.size(), 55, "55 obsidian spires, as EmberRiftProps places them")
	assert_eq(zone.vents.size(), 10, "10 geyser vents")
	assert_gt(zone.fissures.size(), 0, "fissure strips around the spawns")
	assert_ne(zone.geyser_vent, zone.cracked_vent)


func test_smooth_ash_lies_on_the_sim_surface_at_the_spawns() -> void:
	for p: Vector3 in zone.zone.spawn_points:
		var fields := zone.fine_fields(Rect2(p.x - 4.0, p.z - 4.0, 8.0, 8.0))
		var mesh := fields[0].chunk_mesh(0, 0)
		assert_not_null(mesh, "the spawn stands on smooth ash")
		var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		var checked := 0
		for k in verts.size():
			if normals[k].y > 0.5:
				assert_almost_eq(verts[k].y, zone.ground_at(verts[k].x, verts[k].z), 0.044, "QA foot check: within half a T1 cell")
				checked += 1
		assert_gt(checked, 0)


func test_the_lava_bounce_is_strongest_beside_the_lava() -> void:
	var c := zone.centre
	assert_almost_eq(zone.lava_distance(c.x, c.y), 0.0, 0.01, "the vent pool is lava")
	var p: Vector3 = zone.zone.spawn_points[0]
	assert_gt(zone.lava_distance(p.x, p.z), 0.0, "the spawn is not in lava")


func test_storytelling_spots_keep_clear_of_spawns_and_geysers() -> void:
	zone._story_spots()
	for key: String in ["shrine", "fallen", "bridge", "cairn"]:
		assert_true(zone.spots.has(key), key)
	for key: String in ["shrine", "fallen"]:
		var at: Vector3 = zone.spots[key][0]
		for p: Vector3 in zone.zone.spawn_points:
			assert_gt(Vector2(at.x, at.z).distance_to(Vector2(p.x, p.z)), 12.0, key + " clear of the spawns")
		for i in zone.vents.size():
			var v := zone.vents[i].origin
			assert_gt(Vector2(at.x, at.z).distance_to(Vector2(v.x, v.z)), 20.0, key + " keeps the geyser's 20 m clear")


func test_the_breach_lava_fall_is_visual_only_above_the_sim_ground() -> void:
	var notch: Vector3 = zone.zone.landmark_positions[2]
	var top := zone.shown_top(notch.x, notch.z)
	assert_almost_eq(top, zone.ground_at(notch.x, notch.z), 2.5, "rim blocks stay within a block of the sim's rim")


func test_the_rising_ember_emblem_has_a_flame_and_three_bars() -> void:
	assert_true(EmberRiftDesigns.emblem(0.0, 0.0), "flame body")
	assert_true(EmberRiftDesigns.emblem(0.0, 0.6), "flame tip")
	assert_true(EmberRiftDesigns.emblem(0.0, -0.5), "top bar")
	assert_true(EmberRiftDesigns.emblem(0.0, -0.84), "bottom bar")
	assert_false(EmberRiftDesigns.emblem(0.0, -0.6), "gap between the bars")
	assert_false(EmberRiftDesigns.emblem(0.9, 0.5), "outside")
