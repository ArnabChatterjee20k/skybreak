extends GutTest
## Zone art round 2 (T-ART2): Skyhold's opaque cloud sea, Heartbloom's lawn shader,
## Stormfall's neon night and Ember Rift's shaded spires.

const WORLD_SCENE := preload("res://game/world/world_map.tscn")


func _world(zone_id: StringName) -> WorldMap:
	var world: WorldMap = WORLD_SCENE.instantiate()
	world.focus_zone = zone_id
	add_child_autofree(world)
	world.atmosphere.set_process(false)
	return world


func _props(world: WorldMap, node_name: String) -> GeometryInstance3D:
	return world.props.find_child(node_name, true, false) as GeometryInstance3D


func test_skyhold_cloud_sea_is_opaque_so_the_basin_never_shows_through() -> void:
	var code: String = (load("res://game/world/shaders/cloud_sea.gdshader") as Shader).code
	assert_string_contains(code, "depth_draw_opaque")
	assert_false(code.contains("ALPHA"), "no see-through alpha")


func test_skyhold_haze_is_light_and_matches_its_horizon() -> void:
	var zone: ZoneData = load("res://game/world/zones/skyhold_ruins.tres")
	assert_lt(zone.fog_density, 0.3)
	assert_eq(zone.fog_colors[0], zone.sky_horizon_colors[0])
	assert_eq(zone.strata, 0.0, "no stripe strata on Skyhold's fangs")


func test_prop_strata_fade_out_before_they_alias_into_stripes() -> void:
	var code: String = (load("res://game/world/shaders/prop_toon.gdshader") as Shader).code
	assert_string_contains(code, "fwidth(y)")


func test_heartbloom_lawns_use_the_lawn_shader_with_island_data() -> void:
	var world := _world(&"heartbloom_gardens")
	var islands := _props(world, "Islands") as MeshInstance3D
	var lawn := islands.mesh.surface_get_material(0) as ShaderMaterial
	assert_eq(lawn.shader, HeartbloomProps.LAWN_SHADER)
	var arrays := islands.mesh.surface_get_arrays(0)
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var radii := 0
	for v in uv2:
		if v.x > 0.0:
			radii += 1
	assert_gt(radii, 0, "top vertices carry the island radius")
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var tops := {}
	for i in colors.size():
		if uv2[i].x > 0.0:
			tops[colors[i]] = true
	assert_eq(tops.size(), 1, "one lawn colour: no per-triangle fan shading")


func test_stormfall_signs_glow_in_several_colours_and_windows_are_always_lit() -> void:
	var world := _world(&"stormfall_city")
	var signs := _props(world, "NeonSigns") as MultiMeshInstance3D
	assert_gt(signs.multimesh.instance_count, 100, "signs and shop-front bands")
	var neon := signs.material_override as ShaderMaterial
	assert_gt(neon.get_shader_parameter("night_emission"), 0.0, "instance colour tints the glow")
	assert_gte(StormfallCityProps.NEON.size(), 3, "magenta, cyan and gold signs")
	var buildings := _props(world, "Buildings") as MultiMeshInstance3D
	var concrete := buildings.material_override as ShaderMaterial
	assert_eq(concrete.get_shader_parameter("night"), 1.0)
	world.set_time_of_day(WorldAtmosphere.TimeOfDay.DAY)
	assert_eq(concrete.get_shader_parameter("night"), 1.0, "the city stays a night city")


func test_stormfall_is_a_dark_night_sky_but_fighters_keep_a_key_and_rim_light() -> void:
	var zone: ZoneData = load("res://game/world/zones/stormfall_city.tres")
	assert_lt(zone.sky_top_colors[0].v, 0.2)
	assert_gt(zone.sun_energies[0], 0.4)
	assert_gt(zone.rim_energies[0], 1.0)


func test_ember_spires_keep_near_uniform_scale_so_their_normals_shade() -> void:
	var world := _world(&"ember_rift")
	var spires := _props(world, "ObsidianSpires") as MultiMeshInstance3D
	assert_gt(spires.multimesh.instance_count, 10)
	for i in spires.multimesh.instance_count:
		var s := spires.multimesh.get_instance_transform(i).basis.get_scale()
		assert_lt(s.y / minf(s.x, s.z), 5.0, "spire %d stretch" % i)
