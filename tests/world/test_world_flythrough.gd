extends GutTest

const FLYTHROUGH := preload("res://game/world/preview/world_flythrough.tscn")


func test_flythrough_visits_all_seven_zones_above_the_ground() -> void:
	var fly := FLYTHROUGH.instantiate()
	add_child(fly)
	fly.set_process(false)
	var world: WorldMap = fly.world
	var seen := {}
	for i in 400:
		var pose: Transform3D = fly.pose_at(float(i) / 400.0)
		var p := pose.origin
		seen[world.zone_at(p.x, p.z, p.y).id] = true
		assert_gt(p.y, world.ground_height_at(p.x, p.z, p.y) + 10.0, "above ground at %d" % i)
		assert_false(world.islands.contains(p), "not inside an island at %d" % i)
		assert_true(world.bounds().has_point(p), "inside the dome at %d" % i)
	assert_eq(seen.size(), 7, "visits every zone")
	assert_almost_eq(fly.DURATION, 90.0, 0.01)
	fly.free()


func test_map_mode_shows_the_whole_map_from_above() -> void:
	var fly := FLYTHROUGH.instantiate()
	add_child(fly)
	fly.set_process(false)
	fly.set_map_mode(true)
	var camera: Camera3D = fly.camera
	assert_eq(camera.projection, Camera3D.PROJECTION_ORTHOGONAL)
	assert_gte(camera.size, 2000.0)
	assert_false(fly.world.environment_node.environment.fog_enabled, "no fog on the map")
	fly.set_map_mode(false)
	assert_eq(camera.projection, Camera3D.PROJECTION_PERSPECTIVE)
	assert_true(fly.world.environment_node.environment.fog_enabled)
	fly.free()


func test_flythrough_lingers_in_heartbloom_at_dusk() -> void:
	var fly := FLYTHROUGH.instantiate()
	add_child(fly)
	var world: WorldMap = fly.world
	world.set_time_of_day(WorldAtmosphere.TimeOfDay.NIGHT)
	var inside := 0
	var dusk_inside := 0
	var restored := false
	for i in 4000:
		fly._process(0.1)
		var p: Vector3 = fly.camera.global_position
		var in_zone := world.zone_at(p.x, p.z, p.y).id == &"heartbloom_gardens"
		if in_zone:
			inside += 1
			if world.atmosphere.time_of_day == WorldAtmosphere.TimeOfDay.DUSK:
				dusk_inside += 1
		elif inside > 0 and world.atmosphere.time_of_day == WorldAtmosphere.TimeOfDay.NIGHT:
			restored = true
	assert_gt(inside, 0, "passes through Heartbloom")
	assert_eq(dusk_inside, inside, "always at dusk there")
	assert_true(restored, "the previous time of day comes back after")
	# Lingering: a large share of flight time is spent there.
	assert_gt(float(inside) / 4000.0, 0.2, "lingers in Heartbloom")
	fly.free()
