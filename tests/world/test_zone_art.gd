extends GutTest
## Zone art pass (T-ART1): crisp ground detail in every zone, fog only on the far
## backdrop, inked props and a contact shadow under each fighter.

const WORLD_SCENE := preload("res://game/world/world_map.tscn")


func _flat(_x: float, _z: float) -> float:
	return 10.0


func _slope(x: float, _z: float) -> float:
	return x * 0.5


func test_every_ground_zone_draws_a_ground_pattern() -> void:
	for zone in ZoneLayout.load_default().zones:
		assert_ne(zone.ground_pattern, 0, "%s has ground detail" % zone.id)


func test_ground_palettes_are_saturated_but_never_neon_or_near_black() -> void:
	for zone in ZoneLayout.load_default().zones:
		for c: Color in [zone.ground_low, zone.ground_high]:
			assert_between(c.v, 0.4, 0.95, "%s ground value" % zone.id)
			assert_lt(c.s, 0.6, "%s ground saturation" % zone.id)


func test_terrain_shader_reads_zone_colours_as_srgb() -> void:
	var code: String = (load("res://game/world/shaders/terrain_toon.gdshader") as Shader).code
	assert_string_contains(code, "to_linear(zone_low[i].rgb)")
	assert_string_contains(code, "to_linear(zone_rock[i].rgb)")


func test_fog_only_starts_on_the_far_backdrop_and_never_hides_it() -> void:
	var world: WorldMap = WORLD_SCENE.instantiate()
	world.focus_zone = &"skyhold_ruins"
	add_child(world)
	world.atmosphere.set_process(false)
	var zone := world.zone(&"skyhold_ruins")
	world.atmosphere.apply_at(Vector3(zone.centre.x, 100.0, zone.centre.y))
	var env := world.environment_node.environment
	assert_gte(env.fog_depth_begin, 120.0)
	assert_gte(env.fog_depth_end, 1000.0)
	assert_lte(env.fog_density, 0.8, "the backdrop always shows through")
	world.free()


func test_props_get_an_ink_outline_except_soft_shapes() -> void:
	var kit := PropKit.new(null, 1)
	var rock := kit.material("rock", Color(0.5, 0.4, 0.3))
	var mist := kit.material("mist", Color(1, 1, 1))
	assert_not_null(rock.next_pass)
	assert_eq((rock.next_pass as ShaderMaterial).shader, PropKit.OUTLINE_SHADER)
	assert_null(mist.next_pass)
	assert_same(kit.material("bark", Color.BROWN).next_pass, rock.next_pass, "one shared outline material")


func test_contact_shadow_sits_on_the_floor_straight_under_the_feet() -> void:
	var shadows := ContactShadows.new()
	add_child_autofree(shadows)
	shadows.setup(2)
	shadows.place(0, 3.0, -4.0, 10.0, 10.0, _flat)
	var disc := shadows.disc(0)
	assert_true(disc.visible)
	assert_almost_eq(disc.global_position, Vector3(3.0, 10.0, -4.0), Vector3.ONE * 0.001)
	assert_almost_eq(disc.global_transform.basis.y.normalized().dot(Vector3.UP), 1.0, 0.001)
	assert_eq(disc.layers, WorldAtmosphere.WORLD_LAYERS, "not lit by the fighters' rim light")


func test_contact_shadow_grows_fades_with_height_and_hides_high_up() -> void:
	var shadows := ContactShadows.new()
	add_child_autofree(shadows)
	shadows.setup(1)
	var disc := shadows.disc(0)
	var material := disc.material_override as ShaderMaterial
	shadows.place(0, 0.0, 0.0, 10.0, 10.0, _flat)
	var low_size := disc.global_transform.basis.x.length()
	var low_strength: float = material.get_shader_parameter("strength")
	shadows.place(0, 0.0, 0.0, 20.0, 10.0, _flat)
	assert_gt(disc.global_transform.basis.x.length(), low_size)
	assert_lt(material.get_shader_parameter("strength"), low_strength)
	shadows.place(0, 0.0, 0.0, 10.0 + ContactShadows.FADE_HEIGHT + 1.0, 10.0, _flat)
	assert_false(disc.visible)


func test_contact_shadow_tilts_with_the_slope() -> void:
	var shadows := ContactShadows.new()
	add_child_autofree(shadows)
	shadows.setup(1)
	shadows.place(0, 4.0, 0.0, 2.0, 2.0, _slope)
	var up := shadows.disc(0).global_transform.basis.y.normalized()
	assert_almost_eq(up, Vector3(-0.5, 1.0, 0.0).normalized(), Vector3.ONE * 0.001)


func test_contact_shadow_adds_a_team_ring_only_when_airborne() -> void:
	var shadows := ContactShadows.new()
	add_child_autofree(shadows)
	shadows.setup(1)
	shadows.set_ring_color(0, Color.RED)
	var material := shadows.disc(0).material_override as ShaderMaterial
	shadows.place(0, 0.0, 0.0, 10.0, 10.0, _flat)
	assert_eq(material.get_shader_parameter("ring_strength"), 0.0, "no ring while standing")
	var height := ContactShadows.RING_ABOVE + ContactShadows.RING_FADE_IN
	shadows.place(0, 0.0, 0.0, 10.0 + height, 10.0, _flat)
	assert_almost_eq(float(material.get_shader_parameter("ring_strength")), ContactShadows.ring_strength(height), 0.001)
	assert_gt(ContactShadows.ring_strength(height), 0.8, "fully in")
	assert_eq(material.get_shader_parameter("ring_color"), Color.RED)


func test_the_team_ring_stays_visible_above_the_shadow_fade() -> void:
	var shadows := ContactShadows.new()
	add_child_autofree(shadows)
	shadows.setup(1)
	shadows.set_ring_color(0, Color.BLUE)
	shadows.place(0, 0.0, 0.0, 10.0 + ContactShadows.FADE_HEIGHT + 5.0, 10.0, _flat)
	var material := shadows.disc(0).material_override as ShaderMaterial
	assert_true(shadows.disc(0).visible)
	assert_almost_eq(float(material.get_shader_parameter("strength")), 0.0, 0.001)
