class_name VoxelStage
extends Node3D
## The lighting and atmosphere stage of a voxel zone: sky (gradient, sun disc,
## puff clouds), sun with soft shadows, rim light, ambient, distance fog and a
## cloud sea (a white floor of T3 voxel puffs over a soft deck). Values come
## from presets (Dictionaries, keys below); a zone can pass its own.
##   var stage := VoxelStage.new()
##   add_child(stage)
##   stage.setup(zone.presets(), zone.cloud_sea())
##   stage.apply("dusk")

const SKY_SHADER := preload("res://game/world/voxel_zone_kit/voxel_sky.gdshader")
const DECK_SHADER := preload("res://game/world/voxel_zone_kit/voxel_cloud_deck.gdshader")
const T3 := 1.4

## Default presets: pink stays the accent, so the sky runs lavender-blue to
## warm gold, the fog is light and neutral, the cloud sea white.
## Keys: sky_top, sky_horizon, sky_below, cloud, cloud_shadow, cloud_cover,
## sun_dir (towards the ground), sun_color, sun_energy, sun_size, moon, stars,
## rim_color, rim_energy, ambient_color, ambient_energy, fog_color,
## fog_density, exposure, lantern (emission multiplier).
const PRESETS := {
	"day": {
		"sky_top": Color("#7fa6e0"), "sky_horizon": Color("#eae4dc"), "sky_below": Color("#f4f4f6"),
		"cloud": Color("#ffffff"), "cloud_shadow": Color("#c9d0e0"), "cloud_cover": 0.42,
		"sun_dir": Vector3(-0.62, -0.62, -0.48), "sun_color": Color("#fff4e6"), "sun_energy": 2.6,
		"sun_size": 0.022, "moon": false, "stars": 0.0,
		"rim_color": Color("#fff0f2"), "rim_energy": 0.35,
		"ambient_color": Color("#b9bdd2"), "ambient_energy": 0.55,
		"fog_color": Color("#e4e8ee"), "fog_density": 0.0009, "exposure": 0.95, "lantern": 0.4,
	},
	"dusk": {
		"sky_top": Color("#6f7cc0"), "sky_horizon": Color("#f6c27a"), "sky_below": Color("#f3ece6"),
		"cloud": Color("#fff2dc"), "cloud_shadow": Color("#a99ac0"), "cloud_cover": 0.45,
		"sun_dir": Vector3(-0.88, -0.2, -0.42), "sun_color": Color("#ffd6a8"), "sun_energy": 2.5,
		"sun_size": 0.04, "moon": false, "stars": 0.0,
		"rim_color": Color("#ffc9a0"), "rim_energy": 0.55,
		"ambient_color": Color("#a99cba"), "ambient_energy": 0.5,
		"fog_color": Color("#ebe0d6"), "fog_density": 0.0011, "exposure": 1.0, "lantern": 1.0,
	},
	"night": {
		"sky_top": Color("#131a3a"), "sky_horizon": Color("#3c3f6a"), "sky_below": Color("#2e3150"),
		"cloud": Color("#5a6090"), "cloud_shadow": Color("#262a48"), "cloud_cover": 0.38,
		"sun_dir": Vector3(0.35, -0.62, 0.7), "sun_color": Color("#c4ccff"), "sun_energy": 0.9,
		"sun_size": 0.0, "moon": true, "stars": 0.8,
		"rim_color": Color("#b4c0ff"), "rim_energy": 0.6,
		"ambient_color": Color("#3a4070"), "ambient_energy": 0.55,
		"fog_color": Color("#2c3050"), "fog_density": 0.0012, "exposure": 1.15, "lantern": 1.5,
	},
}

var env: Environment
var sun: DirectionalLight3D
var rim: DirectionalLight3D
var presets := PRESETS
var current := {}
## Emissive materials that follow the preset's lantern value (emission_value).
var lantern_materials: Array[ShaderMaterial] = []
var _sky_mat: ShaderMaterial
var _deck_mat: ShaderMaterial


## Builds the environment, lights and, if sea is given, the cloud sea:
## {rect: Rect2 (x, z), height: float, puffs: int, seed: int}.
func setup(zone_presets: Dictionary = PRESETS, sea := {}) -> void:
	presets = zone_presets
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4
	env.ssao_power = 1.4
	env.ssao_light_affect = 0.1
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_aerial_perspective = 0.3
	env.fog_sun_scatter = 0.2
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.02
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.light_angular_distance = 1.2
	# Two splits, blended: the near one carries the contact shadows.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = 0.18
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.0
	add_child(sun)
	rim = DirectionalLight3D.new()
	rim.name = "Rim"
	rim.light_specular = 0.2
	add_child(rim)
	if not sea.is_empty():
		_cloud_sea(sea)


## Sets the global shadow quality for the stage (call once per process).
static func shadow_quality(atlas := 4096) -> void:
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	RenderingServer.directional_shadow_atlas_set_size(atlas, true)


## Applies a preset by name (or a Dictionary of values).
func apply(preset: Variant) -> void:
	var p: Dictionary = presets[preset] if preset is String else preset
	current = p
	var dir: Vector3 = (p.sun_dir as Vector3).normalized()
	sun.basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	sun.light_color = p.sun_color
	sun.light_energy = p.sun_energy
	rim.basis = Basis.looking_at(Vector3(-dir.x, -0.35, -dir.z).normalized(), Vector3.UP)
	rim.light_color = p.rim_color
	rim.light_energy = p.rim_energy
	env.ambient_light_color = p.ambient_color
	env.ambient_light_energy = p.ambient_energy
	env.fog_light_color = p.fog_color
	env.fog_density = p.fog_density
	env.tonemap_exposure = p.exposure
	_sky_mat.set_shader_parameter("top_color", p.sky_top)
	_sky_mat.set_shader_parameter("horizon_color", p.sky_horizon)
	_sky_mat.set_shader_parameter("below_color", p.sky_below)
	_sky_mat.set_shader_parameter("cloud_color", p.cloud)
	_sky_mat.set_shader_parameter("cloud_shadow", p.cloud_shadow)
	_sky_mat.set_shader_parameter("cloud_cover", p.cloud_cover)
	_sky_mat.set_shader_parameter("sun_size", p.sun_size)
	_sky_mat.set_shader_parameter("moon", p.moon)
	_sky_mat.set_shader_parameter("star_amount", p.stars)
	if _deck_mat != null:
		_deck_mat.set_shader_parameter("top_color", p.cloud)
		_deck_mat.set_shader_parameter("shadow_color", p.cloud_shadow)
	for m in lantern_materials:
		m.set_shader_parameter("emission_value", 1.2 * float(p.lantern))


## The cloud sea: a soft deck shader plane plus T3 voxel puffs on it.
func _cloud_sea(sea: Dictionary) -> void:
	var rect: Rect2 = sea.rect
	var height: float = sea.height
	var deck := MeshInstance3D.new()
	deck.name = "CloudDeck"
	var plane := PlaneMesh.new()
	plane.size = rect.size * 3.0
	plane.subdivide_width = 0
	deck.mesh = plane
	_deck_mat = ShaderMaterial.new()
	_deck_mat.shader = DECK_SHADER
	deck.material_override = _deck_mat
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	deck.position = Vector3(rect.get_center().x, height, rect.get_center().y)
	add_child(deck)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(sea.get("seed", 77))
	var meshes: Array[ArrayMesh] = []
	for v in 3:
		meshes.append(puff_mesh(v))
	var lists: Array = [[], [], []]
	for k in int(sea.get("puffs", 90)):
		var p := Vector3(rng.randf_range(rect.position.x, rect.end.x), height + rng.randf_range(-6.0, 10.0),
			rng.randf_range(rect.position.y, rect.end.y))
		var s := rng.randf_range(0.8, 1.9)
		(lists[k % 3] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.8, s)), p))
	for v in 3:
		var list: Array[Transform3D] = []
		list.assign(lists[v])
		var one: Array[ArrayMesh] = [meshes[v]]
		VoxelProp.place(self, "CloudPuffs%d" % v, one, [0.0], list, 0)


## A T3 voxel puff cloud: flat-bottomed cumulus lumps, white with soft
## lilac-grey undersides.
static func puff_mesh(v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 300 + v
	var bounds := AABB(Vector3(-26, -6, -26), Vector3(52, 18, 52))
	var paint := func(g: VoxelGrid) -> void:
		for k in 9:
			var c := Vector3(rng.randf_range(-14, 14), rng.randf_range(0, 4), rng.randf_range(-14, 14))
			var r := rng.randf_range(5.0, 9.0)
			g.paint(AABB(c - Vector3(r, r * 0.6, r), Vector3(r, r * 0.6, r) * 2), func(p: Vector3) -> float:
				return maxf(VoxelSdf.ellipsoid(p, c, Vector3(r, r * 0.55, r)), -1.0 - p.y), 1, -1, VoxelGrid.Mode.ADD)
	return VoxelProp.mesh("kit_puff%d" % v, 2, bounds, T3, paint, _puff_colour,
		func(_m: int) -> int: return VoxelProp.Surf.PETAL)


static func _puff_colour(_mat: int, _p: Vector3, c: Vector3i, n: Vector3, occlusion: float, _exposure: float) -> Color:
	var col := Color("#ffffff").lerp(Color("#d4d6e4"), clampf(-n.y, 0.0, 1.0) * 0.7 + occlusion * 0.5)
	col *= 0.98 + 0.04 * VoxelSdf.hash3(c, 5)
	col.a = 1.0
	return col
