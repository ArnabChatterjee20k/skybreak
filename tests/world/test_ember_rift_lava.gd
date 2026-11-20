extends GutTest
## Media-2 #3: Ember Rift's lava reads from fight framing through floor fissures near the spawns.

const WORLD_SCENE := preload("res://game/world/world_map.tscn")

var world: WorldMap


func before_all() -> void:
	world = WORLD_SCENE.instantiate()
	add_child(world)


func after_all() -> void:
	world.free()


func _lava() -> MultiMeshInstance3D:
	return world.props.get_node("Lava") as MultiMeshInstance3D


## The strips after the sea (instance 0), from the CPU-side copy headless runs can read.
func _fissures() -> Array:
	return (_lava().get_meta(PropKit.INSTANCE_TRANSFORMS_META) as Array).slice(1)


func test_the_lava_sea_draws_a_dozen_fissure_strips_without_a_new_node() -> void:
	assert_eq(_lava().multimesh.instance_count, _fissures().size() + 1, "the sea plus one instance per strip")
	assert_gte(_fissures().size(), 12, "at least a dozen fissure strips")
	assert_true(_lava().multimesh.use_custom_data, "custom.r tells the shader a strip from the sea")


func test_fissures_lie_flat_on_the_floor_inside_the_fight_area_and_clear_of_the_spawns() -> void:
	var zone := world.zone(&"ember_rift")
	var middle := Vector3.ZERO
	for point in zone.spawn_points:
		middle += point / zone.spawn_points.size()
	var heightmap: TerrainHeightmap = world.heightmap
	for xform: Transform3D in _fissures():
		var at := Vector2(xform.origin.x, xform.origin.z)
		assert_lte(at.distance_to(Vector2(middle.x, middle.z)), EmberRiftProps.FISSURE_FAR + 0.01, "near the fight")
		assert_almost_eq(xform.basis.y.normalized().dot(Vector3.UP), 1.0, 0.001, "flat, so no camera obstacle")
		var ground := heightmap.ground_height_at(at.x, at.y)
		assert_between(xform.origin.y - ground, 0.0, EmberRiftProps.FISSURE_ROUGHNESS + 0.1, "on the floor")
		for point in zone.spawn_points:
			assert_gt(at.distance_to(Vector2(point.x, point.z)), EmberRiftProps.FISSURE_SPAWN_CLEARANCE,
				"nobody starts the round on a fissure")
