extends GutTest

const FLYTHROUGH := preload("res://game/world/preview/world_flythrough.tscn")


func test_flythrough_visits_all_six_zones_above_the_ground() -> void:
	var fly := FLYTHROUGH.instantiate()
	add_child(fly)
	fly.set_process(false)
	var world: WorldMap = fly.world
	var seen := {}
	for i in 400:
		var pose: Transform3D = fly.pose_at(float(i) / 400.0)
		var p := pose.origin
		seen[world.zone_at(p.x, p.z).id] = true
		assert_gt(p.y, world.ground_height_at(p.x, p.z) + 10.0, "above ground at %d" % i)
		assert_true(world.bounds().has_point(p), "inside the dome at %d" % i)
	assert_eq(seen.size(), 6, "visits every zone")
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
