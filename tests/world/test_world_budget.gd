extends GutTest

const WORLD_SCENE := preload("res://game/world/world_map.tscn")
## Name, camera position, look-at point.
const VIEWS := [
	["city street", Vector3(-20, 20, 402), Vector3(-20, 20, 900)],
	["over the city towards the mesa", Vector3(0, 120, 480), Vector3(700, 40, 480)],
	["map centre looking north", Vector3(0, 80, 0), Vector3(0, 60, -900)],
	["high overview at 45 degrees", Vector3(0, 380, 300), Vector3(0, 0, -100)],
	["among the floating islands", Vector3(40, 150, -560), Vector3(60, 140, -900)],
	["crater rim over the lava", Vector3(660, 160, -800), Vector3(660, 30, -400)],
	["mesa floor across the canyons", Vector3(490, 25, 490), Vector3(900, 40, 800)],
	["verdant valley towards the falls", Vector3(-640, 30, 700), Vector3(-660, 60, 300)],
	["frozen valley", Vector3(-450, 90, -520), Vector3(-900, 90, -560)],
]

var world: WorldMap


func before_all() -> void:
	world = WORLD_SCENE.instantiate()
	add_child(world)


func after_all() -> void:
	world.free()


func _count(view: Array) -> Dictionary:
	var eye: Vector3 = view[1]
	var xform := Transform3D(Basis.looking_at((view[2] as Vector3) - eye, Vector3.UP), eye)
	return WorldViewBudget.count(world, xform)


func test_every_view_stays_within_the_draw_call_budget() -> void:
	for view in VIEWS:
		var counts := _count(view)
		gut.p("%s: %s" % [view[0], counts])
		assert_lte(counts.draw_calls, WorldViewBudget.DRAW_CALL_BUDGET, "%s draw calls" % view[0])


func test_every_view_stays_within_the_triangle_budget() -> void:
	for view in VIEWS:
		var counts := _count(view)
		assert_lte(counts.triangles, WorldViewBudget.TRIANGLE_BUDGET, "%s triangles" % view[0])


func test_every_view_draws_terrain_chunks_and_props() -> void:
	for view in VIEWS:
		var counts := _count(view)
		assert_gt(counts.chunks, 10, "%s sees terrain" % view[0])
		assert_gt(counts.multimeshes, 0, "%s sees props" % view[0])


func test_looking_away_from_the_map_culls_most_of_it() -> void:
	var view := ["at the north wall", Vector3(0, 100, -950), Vector3(0, 120, -1400)]
	var away := _count(view)
	var across := _count(["across the map", Vector3(0, 100, -950), Vector3(0, 60, 0)])
	assert_lt(away.draw_calls, across.draw_calls)
	assert_lt(away.triangles, across.triangles)


func test_nothing_is_drawn_past_the_fog() -> void:
	for node in world.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		if gi is GPUParticles3D or gi.name == "EnergyDome":
			continue
		assert_gt(gi.visibility_range_end, 0.0, "%s has a far cull distance" % gi.name)
		assert_lte(gi.visibility_range_end, 1300.0, "%s culled by ~1.2 km" % gi.name)


func test_repeated_props_use_multimeshes() -> void:
	var multimeshes := world.find_children("*", "MultiMeshInstance3D", true, false)
	var instances := 0
	for node in multimeshes:
		instances += (node as MultiMeshInstance3D).multimesh.instance_count
	var singles := 0
	for node in world.props.find_children("*", "MeshInstance3D", true, false):
		singles += 1
	assert_gt(instances, 1500, "thousands of props")
	assert_lt(multimeshes.size() + singles, 40, "but only a few dozen nodes draw them")


func test_one_directional_light_with_a_modest_shadow_distance() -> void:
	var lights := world.find_children("*", "DirectionalLight3D", true, false)
	assert_eq(lights.size(), 1)
	var sun := lights[0] as DirectionalLight3D
	assert_lte(sun.directional_shadow_max_distance, 200.0)
	assert_eq(world.find_children("*", "OmniLight3D", true, false).size(), 0)
	assert_eq(world.find_children("*", "SpotLight3D", true, false).size(), 0)


func test_environment_keeps_to_the_performance_budget() -> void:
	var env := world.environment_node.environment
	assert_false(env.sdfgi_enabled, "no SDFGI")
	assert_false(env.volumetric_fog_enabled, "no volumetric fog")
	assert_false(env.ssr_enabled, "no SSR")
	assert_false(env.ssao_enabled, "no SSAO")
	assert_true(env.fog_enabled, "distance fog hides the far LOD")


func test_weather_particle_counts_are_small() -> void:
	for node in world.find_children("*", "GPUParticles3D", true, false):
		assert_lte((node as GPUParticles3D).amount, 1000, "%s" % node.name)
