extends GutTest


func _zone(points: PackedVector3Array) -> ZoneData:
	var zone := ZoneData.new()
	zone.id = &"test_zone"
	zone.centre = Vector2(100, -50)
	zone.spawn_points = points
	return zone


func test_fighter_spawns_are_the_authored_points() -> void:
	var points := PackedVector3Array([Vector3(1, 2, 3), Vector3(41, 2, 3)])
	assert_eq(_zone(points).fighter_spawns(), points)


func test_a_zone_with_no_spawn_points_gets_two_across_its_centre() -> void:
	var spawns := _zone(PackedVector3Array()).fighter_spawns()
	assert_eq(spawns.size(), 2)
	assert_almost_eq(spawns[0].distance_to(spawns[1]), ZoneData.FALLBACK_SPAWN_GAP, 0.001)
	var middle := (spawns[0] + spawns[1]) * 0.5
	assert_almost_eq(Vector2(middle.x, middle.z), Vector2(100, -50), Vector2(0.001, 0.001))


func test_a_zone_with_one_spawn_point_gets_a_second() -> void:
	var spawns := _zone(PackedVector3Array([Vector3(5, 7, 9)])).fighter_spawns()
	assert_eq(spawns.size(), 2)
	assert_eq(spawns[0], Vector3(5, 7, 9))
	assert_almost_eq(spawns[0].distance_to(spawns[1]), ZoneData.FALLBACK_SPAWN_GAP, 0.001)


func test_every_zone_resource_has_two_spawn_points() -> void:
	for zone in ZoneLayout.load_default().zones:
		assert_eq(zone.spawn_points.size(), 2, "%s" % zone.id)
