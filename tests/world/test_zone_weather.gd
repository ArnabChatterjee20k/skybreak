extends GutTest
## T-D19: a zone's atmosphere, weather, sky and ambience never leak into another zone.

const WORLD_SCENE := preload("res://game/world/world_map.tscn")


func _world(zone_id: StringName) -> WorldMap:
	var world: WorldMap = WORLD_SCENE.instantiate()
	world.focus_zone = zone_id
	add_child_autofree(world)
	world.atmosphere.set_process(false)
	return world


func test_heartbloom_has_no_rain_anywhere_even_below_its_islands() -> void:
	var world := _world(&"heartbloom_gardens")
	var atmosphere := world.atmosphere
	var rain: GPUParticles3D = atmosphere.weather[WorldAtmosphere.WEATHER_RAIN]
	for at in [Vector3(0, 300, 0), Vector3(0, 120, 0), Vector3(-10, 60, 300), Vector3(280, 250, -200)]:
		atmosphere.apply_at(at)
		assert_false(rain.emitting, "no rain at %s" % at)
		assert_false(atmosphere.current.weather.has(WorldAtmosphere.WEATHER_RAIN))
	assert_false(rain.visible)
	var petals: GPUParticles3D = atmosphere.weather[WorldAtmosphere.WEATHER_PETALS]
	assert_true(petals.emitting, "Heartbloom's own petals fall")


func test_a_pinned_zone_uses_its_own_sky_everywhere() -> void:
	var world := _world(&"heartbloom_gardens")
	var heartbloom := world.zone(&"heartbloom_gardens")
	var stormfall := world.zone(&"stormfall_city")
	world.atmosphere.apply_at(Vector3(stormfall.centre.x, 20, stormfall.centre.y))
	assert_eq(world.atmosphere.current.sky_top, heartbloom.sky_top_colors[world.atmosphere.time_of_day])


func test_stormfall_rains_but_never_snows_or_drops_petals() -> void:
	var world := _world(&"stormfall_city")
	var atmosphere := world.atmosphere
	atmosphere.apply_at(Vector3(0, 300, 0))
	assert_true((atmosphere.weather[WorldAtmosphere.WEATHER_RAIN] as GPUParticles3D).emitting)
	for type in [WorldAtmosphere.WEATHER_SNOW, WorldAtmosphere.WEATHER_PETALS, WorldAtmosphere.WEATHER_EMBERS]:
		assert_false((atmosphere.weather[type] as GPUParticles3D).emitting)


func test_a_focused_world_builds_only_that_zones_props() -> void:
	var world := _world(&"ember_rift")
	assert_eq(world.props.get_children().filter(func(n: Node) -> bool: return n.has_meta("zone_id")).size(), 1)
	assert_not_null(world.props.get_node_or_null("EmberRift"))
	assert_null(world.props.get_node_or_null("HeartbloomGardens"))
	assert_null(world.props.get_node_or_null("Rain"))


func test_far_terrain_keeps_only_its_lowest_lod() -> void:
	var world := _world(&"frozen_peaks")
	var centre := world.zone(&"frozen_peaks").centre
	for chunk: MeshInstance3D in world.terrain.get_children():
		var middle := Vector2(chunk.position.x + 64, chunk.position.z + 64)
		if middle.distance_to(centre) > WorldMap.FOCUS_TERRAIN_RADIUS + 100.0:
			assert_eq(int(chunk.get_meta("lod")), TerrainGrid.LOD_COUNT - 1)
