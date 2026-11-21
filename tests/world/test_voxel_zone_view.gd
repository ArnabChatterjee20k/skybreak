extends GutTest
## The voxel zone hookup (VoxelZoneView): a builder for all seven zones, the
## zone and its stage as siblings, the classic look hidden but its sim data
## kept, and the quality tiers' LOD ranges and shadows. Uses a small stand-in
## zone; the real builders have their own tests in tests/world/.

const WORLD := preload("res://game/world/world_map.tscn")


## A two-tier prop and a single mesh, like VoxelProp.place makes.
class StubZone:
	extends VoxelZone
	var animated := -1.0

	func build() -> void:
		for range_pair: Vector2 in [Vector2(0, 40), Vector2(40, 120)]:
			var tier := MeshInstance3D.new()
			tier.mesh = BoxMesh.new()
			tier.visibility_range_begin = range_pair.x
			tier.visibility_range_end = range_pair.y
			add_child(tier)
		var landmark := MeshInstance3D.new()
		landmark.mesh = BoxMesh.new()
		add_child(landmark)

	func animate(t: float) -> void:
		animated = t


func _view(tier: GraphicsSettings.Quality) -> VoxelZoneView:
	var view := VoxelZoneView.new()
	add_child_autofree(view)
	view.show_zone(StubZone.new(), &"heartbloom_gardens", tier)
	return view


func _tiers(view: VoxelZoneView) -> Array:
	return view.zone.get_children().filter(func(n: Node) -> bool:
		return (n as GeometryInstance3D).visibility_range_end > 0.0)


func test_every_zone_has_a_voxel_builder_that_loads() -> void:
	for id in ZoneMatch.ARENAS:
		assert_true(VoxelZoneView.supports(id), String(id))
		var script := load(VoxelZoneView.BUILDERS[id]) as GDScript
		assert_not_null(script, String(id))
		var zone := script.new() as VoxelZone
		assert_not_null(zone, "%s builder is a VoxelZone" % id)
		zone.free()
		assert_true(VoxelZoneView.HERO_PRESETS.has(id), "%s has a hero preset" % id)


func test_the_zone_and_its_stage_are_siblings_under_the_view() -> void:
	var view := _view(GraphicsSettings.Quality.HIGH)
	assert_eq(view.zone.get_parent(), view)
	assert_eq(view.stage.get_parent(), view)
	assert_not_null(view.stage.sun)
	assert_eq(view.stage.current, view.stage.presets["dusk"], "Heartbloom starts at its hero dusk")


func test_the_view_animates_the_zone_every_frame() -> void:
	var view := _view(GraphicsSettings.Quality.HIGH)
	view._process(0.5)
	assert_almost_eq((view.zone as StubZone).animated, 0.5, 0.0001)


func test_high_keeps_the_lod_ranges_and_low_brings_coarse_tiers_in_sooner() -> void:
	var high := _tiers(_view(GraphicsSettings.Quality.HIGH))
	assert_eq((high[0] as GeometryInstance3D).visibility_range_end, 40.0)
	var low := _tiers(_view(GraphicsSettings.Quality.LOW))
	assert_almost_eq((low[0] as GeometryInstance3D).visibility_range_end, 24.0, 0.001)
	assert_almost_eq((low[1] as GeometryInstance3D).visibility_range_begin, 24.0, 0.001,
		"the coarse tier starts where the fine one ends")


func test_low_drops_far_tier_shadows_and_ssao() -> void:
	var view := _view(GraphicsSettings.Quality.LOW)
	var tiers := _tiers(view)
	assert_ne((tiers[0] as GeometryInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_eq((tiers[1] as GeometryInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_false(view.stage.env.ssao_enabled)
	assert_lt(view.stage.sun.directional_shadow_max_distance, 180.0)
	assert_true(_view(GraphicsSettings.Quality.HIGH).stage.env.ssao_enabled)


func test_web_uses_the_low_tier() -> void:
	var view := _view(GraphicsSettings.Quality.WEB)
	assert_almost_eq((_tiers(view)[0] as GeometryInstance3D).visibility_range_end, 24.0, 0.001)


func test_hiding_the_classic_look_keeps_its_sim_data() -> void:
	var world: WorldMap = WORLD.instantiate()
	world.focus_zone = &"heartbloom_gardens"
	add_child_autofree(world)
	var before := world.ground_height_at(0.0, 0.0)
	VoxelZoneView.hide_classic(world)
	assert_false(world.terrain.visible)
	assert_false(world.props.visible)
	assert_false(world.sun.visible)
	assert_null(world.environment_node.environment)
	assert_false(world.atmosphere.is_processing())
	assert_eq(world.ground_height_at(0.0, 0.0), before, "the ground the sim reads is unchanged")
	assert_gt(world.props.get_child_count(), 0, "props stay for the camera obstacles")
