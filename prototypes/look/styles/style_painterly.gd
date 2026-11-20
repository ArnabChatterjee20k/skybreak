extends "res://prototypes/look/styles/style_anime.gd"
## Style C: painterly stylised. Same rig as B, but soft wrap light, heavy brush strokes
## (Kuwahara on the frame, stroke noise on surfaces), warm light shafts, thin coloured ink.

const SHAFT_SHADER := preload("res://prototypes/look/shaders/light_shaft.gdshader")


func _init() -> void:
	super._init()
	painterly = 1.0
	distance_scale = 1.05


func setup(zone_match: ZoneMatch) -> void:
	super.setup(zone_match)
	_shafts()


func zone_palette(zone: StringName) -> Dictionary:
	var p := super.zone_palette(zone)
	if zone == &"ember_rift":
		# Golden hour: sunlit ochre against blue-violet shadow.
		p.ground_a = Color(0.62, 0.45, 0.32)
		p.ground_b = Color(0.85, 0.62, 0.38)
		p.ground_c = Color(0.48, 0.4, 0.46)
		p.rock_a = Color(0.36, 0.28, 0.36)
		p.rock_b = Color(0.78, 0.5, 0.34)
		p.shadow = Color(0.3, 0.32, 0.62)
		p.sky_top = Color(0.22, 0.3, 0.58)
		p.sky_horizon = Color(1.0, 0.76, 0.45)
		p.fog = Color(0.98, 0.78, 0.55)
		p.sun = Color(1.0, 0.82, 0.55)
		p.ambient = Color(0.5, 0.52, 0.72)
		p.fog_begin = 60.0
		p.fog_end = 700.0
	else:
		p.ground_a = Color(0.42, 0.62, 0.34)
		p.ground_b = Color(0.82, 0.84, 0.46)
		p.ground_c = Color(0.3, 0.52, 0.5)
		p.shadow = Color(0.55, 0.5, 0.78)
		p.sky_top = Color(0.42, 0.6, 0.92)
		p.sky_horizon = Color(1.0, 0.9, 0.8)
		p.fog = Color(1.0, 0.88, 0.85)
		p.fog_begin = 50.0
		p.fog_end = 700.0
	return p


func grade() -> void:
	post_material.set_shader_parameter("kuwahara_radius", 4)
	post_material.set_shader_parameter("paper", 1.0)
	post_material.set_shader_parameter("saturation", 1.08)
	post_material.set_shader_parameter("contrast", 1.08)
	post_material.set_shader_parameter("lift", Vector3(0.02, 0.012, 0.03))
	post_material.set_shader_parameter("gain", Vector3(1.03, 1.0, 0.95))
	post_material.set_shader_parameter("vignette", 0.5)
	post_material.set_shader_parameter("vignette_color", Vector3(0.25, 0.15, 0.2))
	post_material.set_shader_parameter("edge_ink", 0.6)
	post_material.set_shader_parameter("impact_dark", Vector3(0.12, 0.05, 0.08))


func _light_world() -> void:
	super._light_world()
	var env: Environment = match_node.world.environment_node.environment
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_intensity = 1.0
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.8
	env.fog_sun_scatter = 0.25
	env.fog_aerial_perspective = 0.4
	env.fog_density = 0.6
	env.ambient_light_energy = 0.9


func _toon(sm: ShaderMaterial) -> void:
	sm.set_shader_parameter("rim_width", 0.4)
	sm.set_shader_parameter("rim_softness", 0.18)
	sm.set_shader_parameter("rim_strength", 0.8)
	sm.set_shader_parameter("rim_color", palette.rim.lightened(0.4))
	sm.set_shader_parameter("shadow_tint", Color(palette.shadow).lightened(0.3))
	sm.set_shader_parameter("band_count", 3)
	sm.set_shader_parameter("band_softness", 0.12)


func _ink(next: ShaderMaterial) -> void:
	next.set_shader_parameter("outline_width", 1.8)
	next.set_shader_parameter("outline_color", Color(0.25, 0.12, 0.14))


## Warm light shafts slanting down behind the fight.
func _shafts() -> void:
	var m := ShaderMaterial.new()
	m.shader = SHAFT_SHADER
	m.set_shader_parameter("tint", Color(palette.sun, 0.22))
	var sun_dir: Vector3 = (palette.sun_dir as Vector3).normalized()
	for i in 9:
		var q := QuadMesh.new()
		q.size = Vector2(rng.randf_range(6.0, 16.0), 140.0)
		var card := MeshInstance3D.new()
		card.mesh = q
		card.material_override = m
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := rng.randf() * TAU
		var d := rng.randf_range(30.0, 110.0)
		var at := fight_centre + Vector3(cos(a) * d, 40.0, sin(a) * d)
		card.set_instance_shader_parameter("seed", rng.randf() * 50.0)
		dressing.add_child(card)
		# Long axis along the sun ray.
		var y := -sun_dir
		var x := y.cross(Vector3.UP).normalized()
		card.global_transform = Transform3D(Basis(x, y, x.cross(y)), at)
