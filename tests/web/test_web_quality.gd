extends GutTest
## The web tier must be the cheapest tier on every knob.

const KEYS_LOWER_IS_CHEAPER := [
	"directional_shadow_size", "vfx_density", "terrain_chunk_radius"]


func test_every_tier_defines_the_same_keys() -> void:
	var keys: Array = GraphicsSettings.QUALITY_VALUES[GraphicsSettings.Quality.HIGH].keys()
	keys.sort()
	for quality: int in GraphicsSettings.QUALITY_VALUES:
		var tier_keys: Array = GraphicsSettings.QUALITY_VALUES[quality].keys()
		tier_keys.sort()
		assert_eq(tier_keys, keys, "tier %d" % quality)


func test_web_tier_is_no_more_expensive_than_low() -> void:
	var web: Dictionary = GraphicsSettings.QUALITY_VALUES[GraphicsSettings.Quality.WEB]
	var low: Dictionary = GraphicsSettings.QUALITY_VALUES[GraphicsSettings.Quality.LOW]
	for key: String in KEYS_LOWER_IS_CHEAPER:
		assert_lte(web[key], low[key], key)
	assert_gte(web.mesh_lod_threshold, low.mesh_lod_threshold, "coarser LODs")
	assert_eq(web.msaa_3d, Viewport.MSAA_DISABLED)


func test_web_tier_has_no_post_effects() -> void:
	var settings := GraphicsSettings.new(true)
	assert_false(settings.quality_value("post_effects"))


func test_desktop_tiers_keep_post_effects() -> void:
	assert_true(GraphicsSettings.new(false).quality_value("post_effects"))
