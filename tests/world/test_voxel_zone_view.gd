extends GutTest
## The voxel zone hookup (VoxelZoneView): a builder for all seven zones, the
## zone and its stage as siblings, the classic look hidden but its sim data
## kept, the kit building at the view's tier and the tiers' shadows and lamps. Uses a small stand-in
## zone; the real builders have their own tests in tests/world/.

const WORLD := preload("res://game/world/world_map.tscn")


## A two-tier prop and a single mesh, like VoxelProp.place makes.
class StubZone:
	extends VoxelZone
	var animated := -1.0
	var built_tier := -1

	func build() -> void:
		built_tier = VoxelQuality.tier
		var lamp := OmniLight3D.new()
		lamp.shadow_enabled = true
		add_child(lamp)
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


var _saved_tier: GraphicsSettings.Quality


func before_all() -> void:
	_saved_tier = VoxelQuality.tier


func after_each() -> void:
	VoxelQuality.tier = _saved_tier


func _view(tier: GraphicsSettings.Quality) -> VoxelZoneView:
	var view := VoxelZoneView.new()
	add_child_autofree(view)
	view.show_zone(StubZone.new(), &"heartbloom_gardens", tier)
	return view


func _tiers(view: VoxelZoneView) -> Array:
	return view.zone.get_children().filter(func(n: Node) -> bool:
		return n is GeometryInstance3D and (n as GeometryInstance3D).visibility_range_end > 0.0)


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


func test_the_zone_builds_at_the_views_quality_tier() -> void:
	for tier: GraphicsSettings.Quality in [GraphicsSettings.Quality.LOW, GraphicsSettings.Quality.HIGH]:
		assert_eq((_view(tier).zone as StubZone).built_tier, tier, "the kit reads the tier while building")


func test_the_view_keeps_the_ranges_the_kit_built() -> void:
	# VoxelQuality scales ranges while the zone builds; the view must not scale them again.
	var low := _tiers(_view(GraphicsSettings.Quality.LOW))
	assert_eq((low[0] as GeometryInstance3D).visibility_range_end, 40.0)
	assert_eq((low[1] as GeometryInstance3D).visibility_range_begin, 40.0)


func test_the_stage_takes_the_tiers_shadows_and_ssao() -> void:
	for tier: GraphicsSettings.Quality in [GraphicsSettings.Quality.HIGH, GraphicsSettings.Quality.WEB]:
		var view := _view(tier)
		var values: Dictionary = VoxelQuality.VALUES[tier]
		assert_eq(view.stage.sun.directional_shadow_max_distance, float(values.shadow_distance))
		assert_eq(view.stage.env.ssao_enabled, bool(values.ssao))


func test_web_lamps_cast_no_shadows_and_fade_out() -> void:
	var lamp := _view(GraphicsSettings.Quality.WEB).zone.find_children("*", "OmniLight3D", true, false)[0] as OmniLight3D
	assert_false(lamp.shadow_enabled)
	assert_true(lamp.distance_fade_enabled)
	var high_lamp := _view(GraphicsSettings.Quality.HIGH).zone.find_children("*", "OmniLight3D", true, false)[0] as OmniLight3D
	assert_true(high_lamp.shadow_enabled, "desktop tiers keep the zone's lamps as built")


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
