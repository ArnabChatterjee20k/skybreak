extends GutTest
## Aura v2: flame layers, voxel motes with soft halos, the ki gather, lightning arcs,
## the aura light, quality tiers and Compatibility-safe materials.

const AURA_SCENE := "res://game/view/shaders/vfx/fighter_aura.tscn"
const SPARK_PATH := "res://game/view/shaders/aura_spark.gdshader"
const SOFT_SHADERS := [
	"res://game/view/shaders/aura.gdshader",
	"res://game/view/shaders/aura_spark.gdshader",
	"res://game/view/shaders/aura_flame.gdshader",
	"res://game/view/shaders/aura_voxel.gdshader",
	"res://game/view/shaders/aura_arc.gdshader",
]
## Shader features the Compatibility renderer (GLES3, web) lacks or caps.
const COMPATIBILITY_UNSAFE := ["instance uniform", "hint_screen_texture", "hint_depth_texture",
	"hint_normal_roughness_texture", "SCREEN_TEXTURE", "DEPTH_TEXTURE", "global uniform"]
const HIGH_BUDGET := 72


func _aura(level := 0.0, charging := false, quality := 1.0) -> FighterAura:
	var aura := (load(AURA_SCENE) as PackedScene).instantiate() as FighterAura
	aura.particle_quality = quality
	add_child_autofree(aura)
	aura.power_level = level
	aura.charging = charging
	aura.snap()
	return aura


func _fragment(path: String) -> String:
	var code := RegEx.create_from_string("//[^\\n]*").sub(FileAccess.get_file_as_string(path), "", true)
	return code.substr(code.find("void fragment()"))


func _densities() -> Array[float]:
	var found: Array[float] = []
	for tier: GraphicsSettings.Quality in [GraphicsSettings.Quality.HIGH, GraphicsSettings.Quality.MEDIUM,
			GraphicsSettings.Quality.LOW, GraphicsSettings.Quality.WEB]:
		found.append(float(GraphicsSettings.QUALITY_VALUES[tier]["vfx_density"]))
	return found


func test_motes_are_voxel_cubes_with_a_round_soft_halo() -> void:
	var motes: GPUParticles3D = _aura().get_node("Motes")
	assert_eq(motes.draw_passes, 2)
	assert_true(motes.draw_pass_1 is BoxMesh, "the mote is a voxel cube")
	var halo := motes.draw_pass_2 as QuadMesh
	assert_not_null(halo, "a camera-facing halo around each cube")
	var halo_material := halo.material as ShaderMaterial
	assert_eq(halo_material.shader.resource_path, SPARK_PATH)
	assert_eq(halo_material.get_shader_parameter(&"spark_shape"), 0, "round falloff halo")
	assert_gt(halo.size.x, (motes.draw_pass_1 as BoxMesh).size.x * 3.0, "the halo glows well past the cube")


func test_the_round_halo_fades_by_distance_from_the_centre() -> void:
	var code := _fragment(SPARK_PATH)
	var halo := code.substr(code.find("if (spark_shape == 0)"), 260)
	assert_string_contains(halo, "length(p)", "radial distance, so the quad's square edge never shows")
	assert_string_contains(halo, "1.0 - d", "falls to zero before the quad edge")


func test_no_aura_shader_cuts_a_hard_edge_in_its_fragment() -> void:
	var hard := RegEx.create_from_string("(?<!smooth)step\\s*\\(")
	for path: String in SOFT_SHADERS:
		assert_null(hard.search(_fragment(path)), "%s draws only soft (smoothstep) edges" % path.get_file())


func test_every_quad_the_aura_draws_uses_a_soft_aura_shader() -> void:
	var aura := _aura(3.0, true)
	var quads := 0
	for node in aura.find_children("*", "GeometryInstance3D", true, false):
		var meshes: Array[Mesh] = []
		var materials: Array[Material] = []
		if node is MeshInstance3D:
			meshes.append((node as MeshInstance3D).mesh)
			materials.append((node as MeshInstance3D).material_override)
		elif node is GPUParticles3D:
			for i in (node as GPUParticles3D).draw_passes:
				var mesh := (node as GPUParticles3D).get_draw_pass_mesh(i)
				meshes.append(mesh)
				materials.append((mesh as PrimitiveMesh).material)
		for i in meshes.size():
			if not meshes[i] is QuadMesh:
				continue
			quads += 1
			var shader := (materials[i] as ShaderMaterial).shader
			var soft := shader.resource_path in SOFT_SHADERS or shader == VfxKit.DEBRIS
			assert_true(soft, "%s draws its quad with a soft shader, not a flat material" % node.name)
	assert_gt(quads, 4)


func test_the_aura_is_off_at_power_level_zero() -> void:
	var aura := _aura(0.0)
	for node in aura.find_children("*", "GeometryInstance3D", true, false):
		if node is GPUParticles3D:
			assert_false((node as GPUParticles3D).emitting, node.name)
		else:
			assert_false((node as Node3D).visible, node.name)
	assert_false(aura.light().visible)
	assert_eq(aura.particle_count(), 0)


func test_level_one_has_flames_motes_and_light_but_no_lightning() -> void:
	var aura := _aura(1.0)
	for flame in aura.flames():
		assert_true(flame.visible, flame.name)
	assert_true((aura.get_node("Motes") as GPUParticles3D).emitting)
	assert_true(aura.light().visible)
	for arc in aura.arcs():
		assert_false(arc.visible, "%s waits for level 2" % arc.name)


func test_lightning_arcs_crackle_from_level_two_and_brighten_at_three() -> void:
	var two := _aura(2.0)
	var lit := two.arcs().filter(func(arc: MeshInstance3D) -> bool: return arc.visible).size()
	assert_eq(lit, FighterAura.MAX_ARCS)
	var three := _aura(3.0)
	var strength_two: float = (two.arcs()[0].material_override as ShaderMaterial).get_shader_parameter(&"strength")
	var strength_three: float = (three.arcs()[0].material_override as ShaderMaterial).get_shader_parameter(&"strength")
	assert_gt(strength_three, strength_two)


func test_the_ki_gather_shows_only_while_charging() -> void:
	var idle := _aura(1.0, false)
	assert_false((idle.get_node("Gather") as GPUParticles3D).emitting)
	assert_false((idle.get_node("Orb") as MeshInstance3D).visible)
	var charging := _aura(1.0, true)
	assert_true((charging.get_node("Gather") as GPUParticles3D).emitting, "streaks converge into the chest")
	assert_true((charging.get_node("Dust") as GPUParticles3D).emitting, "dust pushed along the floor")
	assert_true((charging.get_node("Orb") as MeshInstance3D).visible, "a pulsing orb")
	assert_true((charging.get_node("FloorRing") as MeshInstance3D).visible, "shock rings on the floor")


func test_gather_streaks_are_pulled_inward() -> void:
	var gather: GPUParticles3D = _aura(1.0, true).get_node("Gather")
	var process := gather.process_material as ParticleProcessMaterial
	assert_lt(process.radial_velocity_max, 0.0, "negative radial velocity pulls toward the chest")
	assert_true(process.particle_flag_align_y, "streaks point along their flight")


func test_particle_counts_follow_the_quality_tiers() -> void:
	var previous := 1 << 30
	for density in _densities():
		var aura := _aura(3.0, true, density)
		var expected := 0
		for particles in aura.particle_systems():
			expected += roundi(particles.amount * density)
		assert_eq(aura.particle_count(), expected, "quality %s" % density)
		assert_lt(aura.particle_count(), previous, "fewer particles at quality %s" % density)
		previous = aura.particle_count()


func test_high_quality_stays_within_the_particle_budget() -> void:
	assert_lte(_aura(3.0, true, 1.0).particle_count(), HIGH_BUDGET)


func test_lightning_and_flame_layers_follow_the_quality_tiers() -> void:
	var densities := _densities()
	assert_eq(FighterAura.arc_count(densities[0]), 6, "HIGH")
	assert_eq(FighterAura.arc_count(densities[3]), 2, "WEB")
	var web := _aura(3.0, true, densities[3])
	var shown_arcs := web.arcs().filter(func(arc: MeshInstance3D) -> bool: return arc.visible).size()
	assert_eq(shown_arcs, 2)
	var shown_flames := web.flames().filter(func(flame: MeshInstance3D) -> bool: return flame.visible).size()
	assert_eq(shown_flames, FighterAura.FLAME_LAYERS.size() - 1, "WEB drops the hot middle layer")


func test_changing_quality_live_rescales_the_particles() -> void:
	var aura := _aura(3.0, false, 1.0)
	aura.particle_quality = 0.5
	assert_almost_eq((aura.get_node("Motes") as GPUParticles3D).amount_ratio, 0.5, 0.001)


func test_the_aura_eases_toward_a_new_level_instead_of_jumping() -> void:
	var aura := _aura(0.0)
	aura.power_level = 3.0
	simulate(aura, 1, 0.1)
	assert_between(aura.shown_level, 0.01, 2.99)
	simulate(aura, 20, 0.1)
	assert_eq(aura.shown_level, 3.0)


func test_the_energy_colour_reaches_every_layer_and_the_light() -> void:
	var aura := _aura(3.0, true)
	var violet := Color(0.62, 0.32, 1.0)
	aura.color = violet
	var tinted := 0
	for made in aura.materials():
		if made.has_meta(&"dust"):
			continue
		var key := &"color" if made.shader.resource_path.ends_with("/aura.gdshader") else &"tint"
		assert_eq(made.get_shader_parameter(key), violet, made.shader.resource_path)
		tinted += 1
	assert_gt(tinted, 8)
	assert_true(aura.light().light_color.is_equal_approx(violet.lerp(Color.WHITE, 0.15)))


func test_each_aura_owns_its_materials_so_fighters_keep_their_own_colour() -> void:
	var a := _aura(1.0)
	var b := _aura(1.0)
	a.color = Color.RED
	b.color = Color.BLUE
	assert_ne(a.materials()[0], b.materials()[0])
	assert_eq(a.materials()[0].get_shader_parameter(&"color"), Color.RED)


func test_the_aura_light_is_cheap_and_grows_with_the_level() -> void:
	var aura := _aura(3.0)
	assert_false(aura.light().shadow_enabled, "no shadow map for the aura light")
	assert_lt(FighterAura.light_energy(1.0, 0.0, 0.0), FighterAura.light_energy(3.0, 0.0, 0.0))
	assert_eq(FighterAura.light_energy(0.0, 1.0, 0.3), 0.0)


func test_every_layer_clamps_its_hdr_so_bloom_cannot_blow_out() -> void:
	for path: String in SOFT_SHADERS:
		assert_string_contains(_fragment(path), "min(", path)
		assert_string_contains(FileAccess.get_file_as_string(path), "uniform float max_hdr", path)
	for made in _aura(3.0, true).materials():
		if made.has_meta(&"dust"):
			continue
		var ceiling: Variant = made.get_shader_parameter(&"max_hdr")
		assert_true(ceiling == null or float(ceiling) <= 2.0, made.shader.resource_path)


func test_aura_shaders_use_only_compatibility_renderer_features() -> void:
	for path: String in SOFT_SHADERS:
		var code := RegEx.create_from_string("//[^\\n]*").sub(FileAccess.get_file_as_string(path), "", true)
		for feature: String in COMPATIBILITY_UNSAFE:
			assert_false(code.contains(feature), "%s avoids %s (GLES3/web)" % [path.get_file(), feature])


func test_the_aura_uses_only_nodes_the_compatibility_renderer_draws() -> void:
	var aura := _aura(3.0, true)
	var lights := aura.find_children("*", "Light3D", true, false)
	assert_eq(lights.size(), 1, "one omni light")
	for node in aura.find_children("*", "", true, false):
		assert_true(node is MeshInstance3D or node is GPUParticles3D or node is OmniLight3D,
			"%s is a %s" % [node.name, node.get_class()])
		if node is GPUParticles3D:
			assert_lte((node as GPUParticles3D).draw_passes, 2, "GLES3 particles: few draw passes")


func test_building_the_aura_makes_no_new_materials_per_frame() -> void:
	var aura := _aura(3.0, true)
	var before := aura.materials().size()
	simulate(aura, 30, 1.0 / 60.0)
	aura.power_level = 1.0
	simulate(aura, 30, 1.0 / 60.0)
	assert_eq(aura.materials().size(), before)
