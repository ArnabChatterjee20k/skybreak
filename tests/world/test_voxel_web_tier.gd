extends GutTest
## The web build (Compatibility / WebGL2) draws every voxel zone within the
## renderer's fixed limits: no zone instance takes global-uniform slots (each
## instance-uniform user takes 16 of 4096), few lights, one shadowed light,
## face textures and surfaces in WebGL2 sizes; a whole 4-player match with
## its worst-case VFX stays under the 256 instances the buffer holds.

const ZONES: Array[StringName] = [
	&"heartbloom_gardens", &"shattered_mesa", &"skyhold_ruins", &"stormfall_city",
	&"frozen_peaks", &"verdant_falls", &"ember_rift",
]
const ZONE_MATCH := preload("res://game/levels/zone_match.tscn")

var _keep_tier: GraphicsSettings.Quality
var _keep_builders: Dictionary


func before_each() -> void:
	_keep_tier = VoxelQuality.tier
	_keep_builders = VoxelZoneView.builders.duplicate()


func after_each() -> void:
	VoxelQuality.tier = _keep_tier
	VoxelZoneView.builders = _keep_builders


func test_the_tests_cover_every_voxel_zone() -> void:
	var listed: Array = VoxelZoneView.BUILDERS.keys()
	listed.sort()
	var covered: Array = ZONES.duplicate()
	covered.sort()
	assert_eq(covered, listed)


func test_the_detector_sees_instance_uniforms_only_where_they_compile() -> void:
	var on := Shader.new()
	on.code = "shader_type spatial;\ninstance uniform float a = 0.0;\nvoid fragment() {}\n"
	var off := Shader.new()
	off.code = "shader_type spatial;\n#ifdef NOPE\ninstance uniform float a = 0.0;\n#endif\nvoid fragment() {}\n"
	var defined := Shader.new()
	defined.code = "shader_type spatial;\n#define YES\n#ifdef YES\ninstance uniform float a = 0.0;\n#endif\n"
	for case: Array in [[on, true], [off, false], [defined, true]]:
		var m := ShaderMaterial.new()
		m.shader = case[0]
		assert_eq(WebTierBudget.has_instance_uniforms(m), case[1], (case[0] as Shader).code)


func test_figures_keep_the_energy_rim_and_zone_props_leave_it_out() -> void:
	var figure := ShaderMaterial.new()
	figure.shader = VoxelBody.SHADER
	assert_true(WebTierBudget.has_instance_uniforms(figure), "voxel figures keep the per-instance rim")
	for m in VoxelProp.materials():
		assert_false(WebTierBudget.has_instance_uniforms(m), "unmerged prop surfaces take no global slots")
	var merged := ShaderMaterial.new()
	merged.shader = VoxelProp.MERGED_SHADER
	assert_false(WebTierBudget.has_instance_uniforms(merged), "merged props take no global slots")


func test_no_zone_shader_declares_instance_uniforms() -> void:
	var checked := 0
	for dir in ["res://game/world/voxel_zone_kit", "res://game/world/zones_voxel", "res://game/world/voxel_zones"]:
		for path in _shaders(dir):
			var m := ShaderMaterial.new()
			m.shader = load(path) as Shader
			assert_false(WebTierBudget.has_instance_uniforms(m), path)
			checked += 1
	assert_gt(checked, 5)


func test_every_voxel_zone_fits_the_web_tier(zone: StringName = use_parameters(ZONES)) -> void:
	VoxelQuality.tier = GraphicsSettings.Quality.WEB
	var view := VoxelZoneView.new()
	add_child_autofree(view)
	view.build(zone, GraphicsSettings.Quality.WEB)
	var r := WebTierBudget.measure(view)
	assert_eq(WebTierBudget.problems(r), [] as Array[String], "%s: %s" % [zone, r])
	assert_eq(r.instance_uniform_instances, 0, "%s: zone instances take no global-uniform slots" % zone)
	assert_lte(r.omni_spot_lights, WebTierBudget.ZONE_OMNI_SPOT_LIGHTS, "%s: omni/spot lights" % zone)
	assert_lte(r.directional_lights, WebTierBudget.ZONE_DIRECTIONAL_LIGHTS, "%s: directional lights" % zone)
	assert_eq(r.shadowed_lights, 1, "%s: only the sun casts shadows" % zone)
	assert_lte(r.max_texture_side, WebTierBudget.MAX_TEXTURE_SIDE, "%s: texture sides" % zone)
	assert_lte(r.max_surface_vertices, WebTierBudget.MAX_SURFACE_VERTICES, "%s: vertices per surface" % zone)
	assert_eq(view.stage.sun.directional_shadow_mode, DirectionalLight3D.SHADOW_ORTHOGONAL,
		"%s: one shadow split on the web" % zone)
	assert_false(view.stage.env.ssao_enabled, "%s: no SSAO on the web (Compatibility has none)" % zone)


func test_a_four_player_voxel_match_with_its_worst_vfx_fits_the_uniform_buffer() -> void:
	VoxelZoneView.builders[&"heartbloom_gardens"] = "res://tests/world/stub_voxel_zone.gd"
	var zone_match: ZoneMatch = ZONE_MATCH.instantiate()
	zone_match.configure({"zone": &"heartbloom_gardens", "voxel_zone": true, "fighters": [
		{"character": &"kael"}, {"character": &"vexa"}, {"character": &"lyra"}, {"character": &"brann"}]})
	add_child_autofree(zone_match)
	zone_match.set_physics_process(false)
	zone_match.set_process(false)
	var fighters: int = WebTierBudget.measure(zone_match).instance_uniform_instances
	# Every world effect at once, CombatFeedback's spark cap of each, plus four auras.
	var per_effect := 0
	for scene: PackedScene in VfxPrewarm.WORLD_EFFECTS:
		var fx := scene.instantiate()
		add_child_autofree(fx)
		per_effect += WebTierBudget.measure(fx).instance_uniform_instances
	var aura := VfxPrewarm.AURA.instantiate()
	add_child_autofree(aura)
	var auras: int = WebTierBudget.measure(aura).instance_uniform_instances * 4
	var worst := fighters + per_effect * CombatFeedback.MAX_LIVE_SPARKS + auras
	assert_gt(fighters, 0, "the fighters' energy rims are counted")
	assert_lte(worst, WebTierBudget.MATCH_INSTANCE_UNIFORM_INSTANCES,
		"fighters %d + effects %d x %d + auras %d" % [fighters, per_effect, CombatFeedback.MAX_LIVE_SPARKS, auras])


static func _shaders(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gdshader"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_shaders(dir.path_join(sub)))
	return out
