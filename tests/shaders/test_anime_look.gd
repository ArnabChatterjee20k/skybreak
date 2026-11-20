extends GutTest
## T-ART3 anime-arena look: the shared grade, fighter rim and outline rules (docs/ART_BIBLE.md).

const WORLD_SCENE := preload("res://game/world/world_map.tscn")
const OUTLINES: Array[String] = [
	"res://game/characters/kael/materials/kael_outline.tres",
	"res://game/characters/kael_chunky/materials/kael_chunky_outline.tres",
	"res://game/characters/vexa/materials/vexa_outline.tres",
	"res://game/characters/brann/materials/brann_outline.tres",
	"res://game/characters/lyra/materials/lyra_outline.tres",
]


func _environment() -> Environment:
	var world: WorldMap = WORLD_SCENE.instantiate()
	var env := (world.get_node(^"WorldEnvironment") as WorldEnvironment).environment
	world.free()
	return env


func test_the_grade_is_a_filmic_aces_tonemap() -> void:
	assert_eq(_environment().tonemap_mode, Environment.TONE_MAPPER_ACES)


func test_bloom_only_catches_overbright_effects() -> void:
	var env := _environment()
	assert_true(env.glow_enabled)
	assert_gte(env.glow_hdr_threshold, 1.0, "lit ground and skin never bloom")
	assert_lte(env.glow_intensity, 0.8, "controlled bloom")


func test_the_grade_adds_only_a_little_contrast_and_saturation() -> void:
	var env := _environment()
	assert_between(env.adjustment_contrast, 1.0, 1.15)
	assert_between(env.adjustment_saturation, 1.0, 1.2)


func test_every_fighter_outline_has_the_same_width() -> void:
	for path in OUTLINES:
		var material: ShaderMaterial = load(path)
		assert_almost_eq(float(material.get_shader_parameter("outline_width")), 2.5, 0.001, path)


func test_fighters_get_a_light_rim_and_props_do_not() -> void:
	var toon: Shader = load("res://game/view/shaders/toon.gdshader")
	var found := RegEx.create_from_string("light_rim_strength[^=]*=\\s*([0-9.]+)").search(toon.code)
	assert_not_null(found, "the toon shader has a light rim")
	if found:
		assert_gt(found.get_string(1).to_float(), 0.5)
	var prop: ShaderMaterial = load("res://game/view/shaders/materials/toon_prop.tres")
	assert_eq(float(prop.get_shader_parameter("light_rim_strength")), 0.0, "the fighters keep the highest contrast")


func test_day_zones_have_a_real_back_light() -> void:
	for zone_id in ZoneLayout.ZONE_IDS:
		var zone: ZoneData = load("res://game/world/zones/%s.tres" % zone_id)
		assert_gte(zone.rim_energies[0], 0.5, String(zone_id))


func test_the_power_up_flare_stays_about_the_fighters_size() -> void:
	var tall := VfxCatalog.AURA_FLARE_SHELL.y * 2.0 * float(VfxKit.LOOKS[&"flare"].end_scale)
	assert_lte(tall, 3.0, "about 1.5 fighter heights at most")


func test_the_web_renderer_gets_a_gentler_grade() -> void:
	var env := Environment.new()
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.1
	LookGrade.apply(env, true)
	assert_lte(env.adjustment_contrast, 1.0, "dark zones are not crushed")
	assert_lte(env.adjustment_saturation, 1.0)
	assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_FILMIC, "ACES crushes Ember Rift on the web renderer")
	assert_gte(LookGrade.exposure(1.0, true), 1.0)


func test_forward_plus_keeps_the_grade_and_the_zone_exposure() -> void:
	var env := Environment.new()
	env.adjustment_contrast = 1.08
	LookGrade.apply(env, false)
	assert_almost_eq(env.adjustment_contrast, 1.08, 0.001)
	assert_almost_eq(LookGrade.exposure(0.98, false), 0.98, 0.001)
