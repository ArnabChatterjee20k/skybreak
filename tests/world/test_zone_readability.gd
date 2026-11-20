extends GutTest
## Figure-ground readability (#81): the contrast metric, the rim light that lifts the
## fighters, and zone looks that keep bright ground off white.

const WORLD_SCENE := preload("res://game/world/world_map.tscn")


func _filled(size: Vector2i, color: Color) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	image.fill(color)
	return image


func test_luminance_runs_from_black_to_white() -> void:
	assert_almost_eq(FigureGround.luminance(Color.BLACK), 0.0, 0.0001)
	assert_almost_eq(FigureGround.luminance(Color.WHITE), 1.0, 0.0001)
	assert_almost_eq(FigureGround.luminance(Color(0.5, 0.5, 0.5)), 0.214, 0.002)


func test_black_on_white_has_full_contrast_and_equal_colours_none() -> void:
	assert_almost_eq(FigureGround.apca(Color.BLACK, Color.WHITE), 106.0, 1.0)
	assert_almost_eq(FigureGround.apca(Color.WHITE, Color.BLACK), 108.0, 1.5)
	assert_eq(FigureGround.apca(Color(0.4, 0.5, 0.6), Color(0.4, 0.5, 0.6)), 0.0)
	assert_almost_eq(FigureGround.weber(0.2, 0.8), 0.75, 0.001)


func test_near_white_fraction_counts_only_clipped_pixels() -> void:
	var image := _filled(Vector2i(10, 10), Color(0.7, 0.75, 0.8))
	for x in 10:
		for y in 3:
			image.set_pixel(x, y, Color.WHITE)
	assert_almost_eq(FigureGround.near_white_fraction(image), 0.3, 0.001)


func test_a_dark_figure_on_snow_measures_against_its_ring_only() -> void:
	var size := Vector2i(80, 80)
	var empty := _filled(size, Color(0.9, 0.92, 0.95))
	# A far dark band that the ring must not reach.
	for x in 80:
		empty.set_pixel(x, 79, Color.BLACK)
	var frame := empty.duplicate() as Image
	for x in range(30, 40):
		for y in range(20, 50):
			frame.set_pixel(x, y, Color(0.2, 0.2, 0.25))
	var figure := FigureGround.mask(frame, empty)
	var result := FigureGround.measure(frame, figure, figure)
	assert_eq(result.figure_pixels, 300)
	assert_gt(result.ring_pixels, 300)
	assert_almost_eq(result.ring_l, FigureGround.luminance(empty.get_pixel(0, 0)), 0.001)
	assert_gt(result.weber, 0.9)
	assert_gt(result.apca, 70.0)


func test_a_figure_the_same_colour_as_the_ground_has_no_contrast() -> void:
	var empty := _filled(Vector2i(40, 40), Color(0.8, 0.85, 0.9))
	var frame := empty.duplicate() as Image
	frame.set_pixel(20, 20, Color(0.82, 0.85, 0.9))
	var figure := PackedByteArray()
	figure.resize(1600)
	figure[20 * 40 + 20] = 1
	var result := FigureGround.measure(frame, figure, PackedByteArray())
	assert_lt(result.weber, 0.05)
	assert_lt(result.apca, 5.0)


func test_every_zone_has_an_exposure_and_a_rim_light_for_each_time_of_day() -> void:
	var layout := ZoneLayout.load_default()
	for zone in layout.zones:
		assert_eq(zone.exposures.size(), 3, "%s exposures" % zone.id)
		assert_eq(zone.rim_colors.size(), 3, "%s rim colours" % zone.id)
		assert_eq(zone.rim_energies.size(), 3, "%s rim energies" % zone.id)
		for t in 3:
			assert_between(zone.exposures[t], 0.6, 1.2, "%s exposure %d" % [zone.id, t])
			assert_between(zone.rim_energies[t], 0.1, 2.0, "%s rim energy %d" % [zone.id, t])


func test_frozen_peaks_snow_stays_below_white() -> void:
	var zone := ZoneLayout.load_default().zones.filter(func(z: ZoneData) -> bool: return z.id == &"frozen_peaks")[0] as ZoneData
	# Snow sits at about 70-85% value before light, with a darker rock to break it up.
	assert_lte(zone.ground_high.v, 0.851)
	assert_lte(zone.ground_low.v, 0.851)
	assert_lt(zone.rock.v, zone.ground_low.v * 0.6)
	assert_lt(zone.exposures[0], 1.0, "bright snow is exposed down")
	assert_lt(zone.fog_colors[0].v, 0.85, "haze is not near white")
	assert_eq(zone.ground_pattern, 2, "sastrugi on the snow")


func test_rim_light_reaches_fighters_but_not_the_world() -> void:
	var world: WorldMap = WORLD_SCENE.instantiate()
	world.focus_zone = &"frozen_peaks"
	add_child(world)
	world.atmosphere.set_process(false)
	assert_eq(world.rim_light.light_cull_mask, WorldAtmosphere.RIM_LAYERS)
	assert_false(world.rim_light.shadow_enabled)
	assert_eq(world.sun.light_cull_mask & WorldAtmosphere.WORLD_LAYERS, WorldAtmosphere.WORLD_LAYERS, "sun still lights the world")
	var on_rim_layers := 0
	for parent: Node in [world.terrain, world.props]:
		for node in parent.find_children("*", "VisualInstance3D", true, false):
			if (node as VisualInstance3D).layers & WorldAtmosphere.RIM_LAYERS:
				on_rim_layers += 1
	assert_eq(on_rim_layers, 0, "no terrain or prop on the fighters' layer")
	assert_almost_eq(world.environment_node.environment.tonemap_exposure, 0.98, 0.001)
	assert_almost_eq(world.rim_light.light_energy, 0.5, 0.001)
	world.free()


func test_rim_light_comes_from_behind_the_fighters_toward_the_camera() -> void:
	# Camera looking down -Z: the light travels back toward +Z and down.
	var dir := WorldAtmosphere.rim_direction(Basis.IDENTITY, Vector2(0.0, 30.0))
	assert_almost_eq(dir.z, cos(deg_to_rad(30.0)), 0.001)
	assert_almost_eq(dir.y, -0.5, 0.001)
	# Swung around: still behind the camera's view, now partly from the side.
	var side := WorldAtmosphere.rim_direction(Basis(Vector3.UP, 1.0), Vector2(40.0, 25.0))
	var back := Basis(Vector3.UP, 1.0).z
	assert_gt(side.dot(back), 0.5)
	assert_lt(side.y, 0.0)


func test_lava_has_crust_plates_cracks_and_shimmer() -> void:
	var shader: Shader = load("res://game/world/shaders/lava.gdshader")
	var names := shader.get_shader_uniform_list().map(func(u: Dictionary) -> String: return u.name)
	for uniform in ["core_color", "hot_color", "crust_color", "plate_size", "night"]:
		assert_has(names, uniform)
	var code := shader.code
	assert_string_contains(code, "cells(")
	assert_string_contains(code, "shimmer")
	assert_false(code.contains("glow = 1.6"), "the old over-bright core is gone")
