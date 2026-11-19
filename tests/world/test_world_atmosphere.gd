extends GutTest

const WORLD_SCENE := preload("res://game/world/world_map.tscn")
const DAY := WorldAtmosphere.TimeOfDay.DAY
const DUSK := WorldAtmosphere.TimeOfDay.DUSK
const NIGHT := WorldAtmosphere.TimeOfDay.NIGHT

var world: WorldMap


func before_each() -> void:
	world = WORLD_SCENE.instantiate()
	add_child(world)
	world.atmosphere.set_process(false)


func after_each() -> void:
	world.free()


func _color_step(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))


func _walk(from: Vector2, to: Vector2) -> Dictionary:
	var atmosphere := world.atmosphere
	var steps := int(from.distance_to(to))
	var previous := atmosphere.blend_at(from.x, from.y)
	var worst := {"fog": 0.0, "sun": 0.0, "energy": 0.0, "fog_end": 0.0}
	for i in range(1, steps + 1):
		var p := from.lerp(to, float(i) / float(steps))
		var current := atmosphere.blend_at(p.x, p.y)
		worst.fog = maxf(worst.fog, _color_step(previous.fog_color, current.fog_color))
		worst.sun = maxf(worst.sun, _color_step(previous.sun_color, current.sun_color))
		worst.energy = maxf(worst.energy, absf(previous.sun_energy - current.sun_energy))
		worst.fog_end = maxf(worst.fog_end, absf(previous.fog_end - current.fog_end))
		previous = current
	return worst


func test_blending_is_continuous_across_every_border() -> void:
	var pairs := [[&"stormfall_city", &"shattered_mesa"], [&"stormfall_city", &"verdant_falls"],
		[&"frozen_peaks", &"skyhold_ruins"], [&"skyhold_ruins", &"ember_rift"],
		[&"ember_rift", &"shattered_mesa"], [&"verdant_falls", &"frozen_peaks"], [&"stormfall_city", &"skyhold_ruins"]]
	for tod in [DAY, NIGHT]:
		world.set_time_of_day(tod)
		for pair in pairs:
			var worst := _walk(world.zone(pair[0]).centre, world.zone(pair[1]).centre)
			var label := "%s to %s" % pair
			# 1 m steps: no jump bigger than a few percent anywhere along the way.
			assert_lt(worst.fog, 0.03, "%s fog colour" % label)
			assert_lt(worst.sun, 0.03, "%s sun colour" % label)
			assert_lt(worst.energy, 0.03, "%s sun energy" % label)
			assert_lt(worst.fog_end, 15.0, "%s fog distance" % label)


func test_blend_band_is_about_100_m_wide() -> void:
	var layout := world.layout
	var city := layout.index_of(&"stormfall_city")
	var mesa := layout.index_of(&"shattered_mesa")
	var from := world.zone(&"stormfall_city").centre
	var to := world.zone(&"shattered_mesa").centre
	var mixed := 0
	var steps := int(from.distance_to(to))
	for i in steps:
		var p := from.lerp(to, float(i) / float(steps))
		var w := layout.weights_at(p.x, p.y)
		if w[city] > 0.02 and w[mesa] > 0.02:
			mixed += 1
	assert_between(mixed, 60, 160, "metres of blended border")


func test_zone_centre_uses_that_zone_preset() -> void:
	world.set_time_of_day(DAY)
	for id in world.zone_ids():
		var zone := world.zone(id)
		var y := zone.altitude_band.y + 40.0 if zone.is_floating() else -INF
		var blend := world.atmosphere.blend_at(zone.centre.x, zone.centre.y, y)
		assert_almost_eq(blend.sun_energy, zone.sun_energies[DAY], 0.001, "%s sun" % id)
		assert_lt(_color_step(blend.fog_color, zone.fog_colors[DAY]), 0.001, "%s fog" % id)


func test_apply_drives_environment_and_sun() -> void:
	var zone := world.zone(&"ember_rift")
	world.atmosphere.apply_at(Vector3(zone.centre.x, 100.0, zone.centre.y))
	var env := world.environment_node.environment
	assert_lt(_color_step(env.fog_light_color, zone.fog_colors[DAY]), 0.001)
	assert_almost_eq(world.sun.light_energy, zone.sun_energies[DAY], 0.001)
	var forward := -world.sun.global_transform.basis.z
	assert_almost_eq(forward.dot(zone.sun_directions[DAY].normalized()), 1.0, 0.001, "sun points along the preset")


func test_time_of_day_switching_changes_light_and_sky() -> void:
	var zone := world.zone(&"stormfall_city")
	var at := Vector3(zone.centre.x, 50.0, zone.centre.y)
	var energies: Array[float] = []
	for tod in [DAY, DUSK, NIGHT]:
		world.set_time_of_day(tod)
		assert_eq(world.atmosphere.time_of_day, tod)
		world.atmosphere.apply_at(at)
		assert_almost_eq(world.sun.light_energy, zone.sun_energies[tod], 0.001)
		energies.append(world.sun.light_energy)
	assert_gt(energies[0], energies[2], "night is darker than day")
	var sky: ShaderMaterial = world.environment_node.environment.sky.sky_material
	assert_eq(sky.get_shader_parameter("star_amount"), 1.0, "stars at night")
	world.set_time_of_day(DAY)
	assert_eq(sky.get_shader_parameter("star_amount"), 0.0, "no stars by day")


func test_city_windows_light_up_at_night() -> void:
	var lit := 0
	for material in world.atmosphere.night_materials:
		world.set_time_of_day(NIGHT)
		assert_eq(material.get_shader_parameter("night"), 1.0)
		world.set_time_of_day(DAY)
		assert_eq(material.get_shader_parameter("night"), 0.0)
		lit += 1
	assert_gt(lit, 0)


func test_weather_follows_the_zone_under_the_camera() -> void:
	var rain: GPUParticles3D = world.atmosphere.weather[WorldAtmosphere.WEATHER_RAIN]
	var snow: GPUParticles3D = world.atmosphere.weather[WorldAtmosphere.WEATHER_SNOW]
	var embers: GPUParticles3D = world.atmosphere.weather[WorldAtmosphere.WEATHER_EMBERS]
	var city := world.zone(&"stormfall_city").centre
	world.atmosphere.apply_at(Vector3(city.x, 60.0, city.y))
	assert_true(rain.emitting, "rain in Stormfall")
	assert_false(snow.emitting)
	assert_false(embers.emitting)
	assert_almost_eq(rain.global_position, Vector3(city.x, 60.0, city.y), Vector3.ONE * 0.01, "rain follows the camera")
	var peaks := world.zone(&"frozen_peaks").centre
	world.atmosphere.apply_at(Vector3(peaks.x, 150.0, peaks.y))
	assert_true(snow.emitting, "snow in Frozen Peaks")
	assert_false(rain.emitting)
	var ember := world.zone(&"ember_rift").centre
	world.atmosphere.apply_at(Vector3(ember.x, 80.0, ember.y))
	assert_true(embers.emitting, "embers in Ember Rift")
	var mesa := world.zone(&"shattered_mesa").centre
	world.atmosphere.apply_at(Vector3(mesa.x, 80.0, mesa.y))
	assert_false(rain.emitting or snow.emitting or embers.emitting, "clear sky over the mesa")


func test_zone_weights_sum_to_one_everywhere() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 300:
		var w := world.layout.weights_at(rng.randf_range(-1000, 1000), rng.randf_range(-1000, 1000), rng.randf_range(-50, 400))
		var total := 0.0
		for v in w:
			assert_between(v, 0.0, 1.0)
			total += v
		assert_almost_eq(total, 1.0, 0.0001)


func _walk_3d(from: Vector3, to: Vector3) -> Dictionary:
	var atmosphere := world.atmosphere
	var steps := int(from.distance_to(to))
	var previous := atmosphere.blend_at(from.x, from.z, from.y)
	var worst := {"fog": 0.0, "sun": 0.0, "energy": 0.0}
	for i in range(1, steps + 1):
		var p := from.lerp(to, float(i) / float(steps))
		var current := atmosphere.blend_at(p.x, p.z, p.y)
		worst.fog = maxf(worst.fog, _color_step(previous.fog_color, current.fog_color))
		worst.sun = maxf(worst.sun, _color_step(previous.sun_color, current.sun_color))
		worst.energy = maxf(worst.energy, absf(previous.sun_energy - current.sun_energy))
		previous = current
	return worst


func test_blending_into_heartbloom_is_continuous_from_below_and_from_the_side() -> void:
	var walks := [
		[Vector3(0, 100, 10), Vector3(0, 330, 10)],
		[Vector3(-600, 300, 10), Vector3(0, 300, 10)],
		[Vector3(0, 300, -600), Vector3(0, 300, 10)],
	]
	for tod in [DAY, DUSK, NIGHT]:
		world.set_time_of_day(tod)
		for walk in walks:
			var worst := _walk_3d(walk[0], walk[1])
			assert_lt(worst.fog, 0.03, "%s fog colour" % [walk])
			assert_lt(worst.sun, 0.03, "%s sun colour" % [walk])
			assert_lt(worst.energy, 0.03, "%s sun energy" % [walk])


func test_heartbloom_has_a_pink_gold_sky_by_day_and_dusk_and_violet_at_night() -> void:
	var zone := world.zone(&"heartbloom_gardens")
	for tod in [DAY, DUSK]:
		var horizon := zone.sky_horizon_colors[tod]
		assert_gt(horizon.r, horizon.b, "warm horizon")
		assert_gt(zone.fog_colors[tod].r, 0.9, "pink-gold fog")
	var night := zone.sky_top_colors[NIGHT]
	assert_gt(night.b, night.g, "violet night sky")
	assert_gt(night.r, night.g)


func test_petals_fall_in_heartbloom_and_only_there() -> void:
	var petals: GPUParticles3D = world.atmosphere.weather[WorldAtmosphere.WEATHER_PETALS]
	world.atmosphere.apply_at(Vector3(0, 300, 10))
	assert_true(petals.emitting, "petals over the islands")
	assert_almost_eq(petals.global_position, Vector3(0, 300, 10), Vector3.ONE * 0.01, "petals follow the camera")
	world.atmosphere.apply_at(Vector3(0, 60, 10))
	assert_false(petals.emitting, "no petals on the ground below")


func test_the_map_overview_ignores_the_floating_zone() -> void:
	world.set_overview(true)
	world.atmosphere.apply_at(Vector3(0, 1600, 0))
	assert_eq(world.atmosphere.current.weather.get(WorldAtmosphere.WEATHER_PETALS, 0.0), 0.0)
	world.set_overview(false)
