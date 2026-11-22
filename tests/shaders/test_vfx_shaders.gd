extends GutTest

const SHADER_DIR := "res://game/view/shaders/"
const AURA_PATH := SHADER_DIR + "aura.gdshader"
const SPARK_PATH := SHADER_DIR + "aura_spark.gdshader"
const FLAME_PATH := SHADER_DIR + "aura_flame.gdshader"
const VOXEL_PATH := SHADER_DIR + "aura_voxel.gdshader"
const ARC_PATH := SHADER_DIR + "aura_arc.gdshader"
const IMPACT_PATH := SHADER_DIR + "impact.gdshader"
const SHOCKWAVE_PATH := SHADER_DIR + "shockwave.gdshader"
const NOISE_PATH := SHADER_DIR + "vfx_noise.gdshaderinc"
const IMPACT_FRAME_SHADER_PATH := SHADER_DIR + "screen/impact_frame.gdshader"
const SPEED_LINES_SHADER_PATH := SHADER_DIR + "screen/speed_lines.gdshader"
const AURA_SCENE_PATH := SHADER_DIR + "vfx/fighter_aura.tscn"
const IMPACT_FRAME_SCENE_PATH := SHADER_DIR + "screen/impact_frame.tscn"
const SPEED_LINES_SCENE_PATH := SHADER_DIR + "screen/speed_lines.tscn"
const PREVIEW_PATH := SHADER_DIR + "preview/vfx_preview.tscn"

const IMPACT_SCENES := {
	"hit_spark_light": Color(1, 1, 1, 1),
	"hit_spark_heavy": Color(1, 0.55, 0.15, 1),
	"counter_hit": Color(1, 0.18, 0.12, 1),
	"perfect_block_flash": Color(0.3, 0.62, 1, 1),
	"guard_break_shatter": Color(1, 0.15, 0.1, 1),
	"shockwave": Color(1, 0.85, 0.6, 1),
}

const SPATIAL_SHADERS := [AURA_PATH, SPARK_PATH, FLAME_PATH, VOXEL_PATH, ARC_PATH, IMPACT_PATH, SHOCKWAVE_PATH]
const AURA_SHADERS := [AURA_PATH, SPARK_PATH, FLAME_PATH, VOXEL_PATH, ARC_PATH]
const SCREEN_SHADERS := [IMPACT_FRAME_SHADER_PATH, SPEED_LINES_SHADER_PATH]

const AURA_DEFAULTS := {
	"color": "vec4(1.0, 0.62, 0.22, 1.0)",
	"power_level": "0.0",
	"intensity": "1.0",
	"flame_speed": "1.6",
	"flame_height": "0.45",
	"flicker": "0.25",
	"grow": "0.12",
	"fresnel_power": "2.5",
	"flame_scale": "7.0",
	"tongue_stretch": "0.14",
	"root_threshold": "0.4",
	"tip_threshold": "0.66",
	"tongue_softness": "0.07",
	"root_glow": "0.7",
	"center_clear": "0.55",
	"rim_base": "0.0",
	"body_height": "1.85",
}

const SPARK_DEFAULTS := {
	"tint": "vec4(1.0, 0.62, 0.22, 1.0)",
	"intensity": "1.0",
	"spark_shape": "0",
	"core_whiteness": "0.5",
	"strength": "1.0",
	"pulse_rate": "1.6",
	"depth_offset": "0.0",
}

const IMPACT_DEFAULTS := {
	"tint": "vec4(1.0, 1.0, 1.0, 1.0)",
	"progress": "0.0",
	"shape": "0",
	"intensity": "1.4",
	"core_whiteness": "0.6",
	"start_scale": "0.5",
	"end_scale": "1.5",
	"fade_power": "1.5",
	"pace": "1.0",
	"ray_count": "8.0",
	"ray_sharpness": "8.0",
	"ring_width": "0.12",
	"use_particle_age": "false",
	"align_to_velocity": "false",
}

const SHOCKWAVE_DEFAULTS := {
	"tint": "vec4(1.0, 0.85, 0.6, 1.0)",
	"progress": "0.0",
	"billboard": "true",
	"intensity": "1.2",
	"ring_width": "0.1",
	"edge_softness": "0.7",
	"start_radius": "0.05",
	"inner_glow": "0.3",
	"lie_flat": "false",
	"surface_plane": "vec4(0.0, 1.0, 0.0, 0.0)",
	"surface_fade": "0.0",
}

const IMPACT_FRAME_DEFAULTS := {
	"amount": "0.0",
	"contrast": "0.8",
	"light_color": "vec4(1.0, 0.98, 0.94, 1.0)",
	"ink_color": "vec4(0.05, 0.03, 0.08, 1.0)",
}

const SPEED_LINES_DEFAULTS := {
	"amount": "0.0",
	"center": "vec2(0.5, 0.5)",
	"line_density": "120.0",
	"color": "vec4(1.0, 1.0, 1.0, 0.85)",
	"inner_radius": "0.28",
	"line_width": "0.3",
	"redraw_fps": "24.0",
}

const ADDITIVE_BLEND := "blend_add"
const NON_ADDITIVE_MODES := ["blend_mix", "blend_sub", "blend_mul", "blend_premul_alpha",
	"depth_draw_always", "depth_draw_opaque", "depth_prepass_alpha"]
const VFX_SCENES := [AURA_SCENE_PATH] + [
	SHADER_DIR + "vfx/hit_spark_light.tscn",
	SHADER_DIR + "vfx/hit_spark_heavy.tscn",
	SHADER_DIR + "vfx/counter_hit.tscn",
	SHADER_DIR + "vfx/perfect_block_flash.tscn",
	SHADER_DIR + "vfx/guard_break_shatter.tscn",
	SHADER_DIR + "vfx/shockwave.tscn",
]

const IMPACT_PARTICLE_BUDGET := 32
const MAX_NOISE_OCTAVES := 3


# The headless renderer can't report uniform defaults, so read them from the source.
func _declared_default(shader: Shader, uniform_name: String) -> String:
	var regex := RegEx.create_from_string(
		"uniform\\s+\\w+\\s+" + uniform_name + "\\b[^=;]*=\\s*([^;]+);")
	var found := regex.search(shader.code)
	return found.get_string(1).strip_edges() if found else "<none>"


func _is_instance_uniform(shader: Shader, uniform_name: String) -> bool:
	var regex := RegEx.create_from_string("instance\\s+uniform\\s+\\w+\\s+" + uniform_name + "\\b")
	return regex.search(shader.code) != null


func _assert_defaults(path: String, expected: Dictionary) -> void:
	var shader: Shader = load(path)
	for uniform_name: String in expected:
		assert_eq(_declared_default(shader, uniform_name), expected[uniform_name],
			"%s in %s" % [uniform_name, path.get_file()])


func _impact_path(effect_name: String) -> String:
	return SHADER_DIR + "vfx/" + effect_name + ".tscn"


func _instantiate(path: String) -> Node:
	var node: Node = (load(path) as PackedScene).instantiate()
	add_child_autofree(node)
	return node


func _particles(root: Node) -> Array[GPUParticles3D]:
	var found: Array[GPUParticles3D] = []
	for node in root.find_children("*", "GPUParticles3D", true, false):
		found.append(node as GPUParticles3D)
	return found


func _particle_count(root: Node) -> int:
	var total := 0
	for particles in _particles(root):
		total += particles.amount
	return total


func _source_without_comments(path: String) -> String:
	var regex := RegEx.create_from_string("//[^\\n]*")
	return regex.sub(FileAccess.get_file_as_string(path), "", true)


func _render_modes(shader: Shader) -> PackedStringArray:
	var found := RegEx.create_from_string("render_mode\\s+([^;]+);").search(shader.code)
	var modes := PackedStringArray()
	if found:
		for mode in found.get_string(1).split(","):
			modes.append(mode.strip_edges())
	return modes


# Every material a VFX node can draw with: overrides, mesh surfaces and particle draw passes.
func _materials_of(node: GeometryInstance3D) -> Array[Material]:
	var found: Array[Material] = []
	if node.material_override:
		found.append(node.material_override)
	var meshes: Array[Mesh] = []
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		meshes.append(mesh_node.mesh)
		for i in mesh_node.get_surface_override_material_count():
			if mesh_node.get_surface_override_material(i):
				found.append(mesh_node.get_surface_override_material(i))
	elif node is GPUParticles3D:
		var particles := node as GPUParticles3D
		for i in particles.draw_passes:
			meshes.append(particles.get_draw_pass_mesh(i))
	for mesh in meshes:
		if mesh is PrimitiveMesh and (mesh as PrimitiveMesh).material:
			found.append((mesh as PrimitiveMesh).material)
		elif mesh:
			for i in mesh.get_surface_count():
				if mesh.surface_get_material(i):
					found.append(mesh.surface_get_material(i))
	return found


func test_vfx_spatial_shaders_load_as_spatial_shaders() -> void:
	for path: String in SPATIAL_SHADERS:
		var shader: Shader = load(path)
		assert_not_null(shader, path)
		assert_eq(shader.get_mode(), Shader.MODE_SPATIAL, path)


func test_screen_shaders_load_as_canvas_item_shaders() -> void:
	for path: String in SCREEN_SHADERS:
		var shader: Shader = load(path)
		assert_not_null(shader, path)
		assert_eq(shader.get_mode(), Shader.MODE_CANVAS_ITEM, path)


func test_vfx_noise_include_loads() -> void:
	assert_not_null(load(NOISE_PATH))


func test_aura_uniforms_have_expected_defaults() -> void:
	_assert_defaults(AURA_PATH, AURA_DEFAULTS)


func test_aura_shaders_use_no_instance_uniforms_so_they_fit_the_gles3_cap() -> void:
	for path: String in AURA_SHADERS:
		assert_false(_source_without_comments(path).contains("instance uniform"), path)


func test_aura_power_level_spans_off_to_ultimate() -> void:
	var code: String = (load(AURA_PATH) as Shader).code
	assert_string_contains(code, "power_level : hint_range(0.0, 3.0)")


func test_aura_spark_uniforms_have_expected_defaults() -> void:
	_assert_defaults(SPARK_PATH, SPARK_DEFAULTS)


func test_impact_uniforms_have_expected_defaults() -> void:
	_assert_defaults(IMPACT_PATH, IMPACT_DEFAULTS)
	for uniform_name in ["tint", "progress"]:
		assert_true(_is_instance_uniform(load(IMPACT_PATH), uniform_name), uniform_name)


func test_shockwave_uniforms_have_expected_defaults() -> void:
	_assert_defaults(SHOCKWAVE_PATH, SHOCKWAVE_DEFAULTS)
	for uniform_name in ["tint", "progress"]:
		assert_true(_is_instance_uniform(load(SHOCKWAVE_PATH), uniform_name), uniform_name)


func test_impact_frame_uniforms_have_expected_defaults() -> void:
	_assert_defaults(IMPACT_FRAME_SHADER_PATH, IMPACT_FRAME_DEFAULTS)


func test_speed_lines_uniforms_have_expected_defaults() -> void:
	_assert_defaults(SPEED_LINES_SHADER_PATH, SPEED_LINES_DEFAULTS)


func test_world_vfx_shaders_are_additive_unshaded_and_skip_depth_writes() -> void:
	for path: String in SPATIAL_SHADERS:
		var code: String = (load(path) as Shader).code
		for mode in ["unshaded", "blend_add", "depth_draw_never", "shadows_disabled"]:
			assert_string_contains(code, mode, false)


func test_every_aura_and_impact_material_is_additive_and_never_writes_depth() -> void:
	for path: String in VFX_SCENES:
		var scene := _instantiate(path)
		var checked := 0
		for node in scene.find_children("*", "GeometryInstance3D", true, false):
			var materials := _materials_of(node as GeometryInstance3D)
			assert_gt(materials.size(), 0, "%s/%s has a material" % [path.get_file(), node.name])
			for material in materials:
				var label := "%s/%s" % [path.get_file(), node.name]
				assert_true(material is ShaderMaterial, "%s uses a VFX shader, not a StandardMaterial3D" % label)
				var modes := _render_modes((material as ShaderMaterial).shader)
				assert_has(modes, ADDITIVE_BLEND, label)
				assert_has(modes, "depth_draw_never", label)
				for mode: String in NON_ADDITIVE_MODES:
					assert_does_not_have(modes, mode, label)
				checked += 1
		assert_gt(checked, 0, path)


func test_world_vfx_shaders_clamp_their_output_so_they_never_darken() -> void:
	var clamped := RegEx.create_from_string("ALBEDO\\s*=\\s*max\\(.*,\\s*vec3\\(0\\.0\\)\\);")
	for path: String in SPATIAL_SHADERS:
		var code := _source_without_comments(path)
		assert_not_null(clamped.search(code), path)
		assert_false(code.contains("ALPHA"), "%s leaves ALPHA alone so blend_add stays purely additive" % path)


func test_only_the_impact_frame_reads_the_screen_texture() -> void:
	for path: String in SPATIAL_SHADERS + [SPEED_LINES_SHADER_PATH]:
		var code := _source_without_comments(path)
		assert_false(code.contains("hint_screen_texture"), path)
		assert_false(code.contains("SCREEN_TEXTURE"), path)
		assert_false(code.contains("hint_depth_texture"), "%s reads no depth texture" % path)
	assert_string_contains(_source_without_comments(IMPACT_FRAME_SHADER_PATH), "hint_screen_texture")


func test_vfx_shaders_have_no_loops() -> void:
	var loop := RegEx.create_from_string("\\b(for|while)\\s*\\(")
	for path: String in SPATIAL_SHADERS + SCREEN_SHADERS + [NOISE_PATH]:
		assert_null(loop.search(_source_without_comments(path)), path)


func test_flame_noise_uses_at_most_three_octaves() -> void:
	var source := _source_without_comments(NOISE_PATH)
	var start := source.find("float vfx_fbm3(")
	assert_gt(start, -1, "vfx_fbm3 exists")
	var body := source.substr(start, source.find("}", start) - start)
	var octaves := RegEx.create_from_string("vfx_noise3\\(").search_all(body).size()
	assert_between(octaves, 1, MAX_NOISE_OCTAVES)


func test_every_impact_scene_instantiates_as_an_impact_effect() -> void:
	for effect_name: String in IMPACT_SCENES:
		var effect := _instantiate(_impact_path(effect_name)) as ImpactEffect
		assert_not_null(effect, effect_name)
		assert_true(effect.has_method("play"), effect_name)
		assert_false(effect.visible, "%s is hidden until played" % effect_name)


func test_impact_scenes_use_the_impact_or_shockwave_shader_on_every_sprite() -> void:
	for effect_name: String in IMPACT_SCENES:
		var effect := _instantiate(_impact_path(effect_name))
		for node in effect.find_children("*", "GeometryInstance3D", true, false):
			var mesh: Mesh = node.mesh if node is MeshInstance3D else (node as GPUParticles3D).draw_pass_1
			var shader_path := ((mesh as PrimitiveMesh).material as ShaderMaterial).shader.resource_path
			assert_has([IMPACT_PATH, SHOCKWAVE_PATH], shader_path, "%s/%s" % [effect_name, node.name])


func test_impact_default_colours_follow_the_readability_palette() -> void:
	for effect_name: String in IMPACT_SCENES:
		var effect := _instantiate(_impact_path(effect_name)) as ImpactEffect
		assert_eq(effect.default_color, IMPACT_SCENES[effect_name], effect_name)


func test_play_tints_every_sprite_and_scales_the_effect() -> void:
	var effect := _instantiate(_impact_path("hit_spark_heavy")) as ImpactEffect
	var cyan := Color(0.35, 0.85, 1.0)
	effect.play(cyan, 2.0)
	assert_true(effect.visible)
	assert_true(effect.is_playing())
	assert_eq(effect.scale, Vector3.ONE * 2.0)
	for node in effect.find_children("*", "GeometryInstance3D", true, false):
		assert_eq((node as GeometryInstance3D).get_instance_shader_parameter("tint"), cyan, node.name)


func test_play_without_a_colour_uses_the_default_colour() -> void:
	var effect := _instantiate(_impact_path("perfect_block_flash")) as ImpactEffect
	effect.play()
	var ring: MeshInstance3D = effect.get_node("Ring")
	assert_eq(ring.get_instance_shader_parameter("tint"), effect.default_color)


func test_play_starts_every_particle_system() -> void:
	var effect := _instantiate(_impact_path("guard_break_shatter")) as ImpactEffect
	effect.play(Color.RED, 1.0)
	for particles in _particles(effect):
		assert_true(particles.emitting, particles.name)
		assert_true(particles.one_shot, particles.name)


func test_effect_progress_advances_while_playing() -> void:
	var effect := _instantiate(_impact_path("shockwave")) as ImpactEffect
	effect.play()
	simulate(effect, 1, effect.lifetime * 0.5)
	var ring: MeshInstance3D = effect.get_node("Ring")
	assert_almost_eq(float(ring.get_instance_shader_parameter("progress")), 0.5, 0.01)


func test_every_impact_effect_frees_itself_after_its_lifetime() -> void:
	for effect_name: String in IMPACT_SCENES:
		var effect := _instantiate(_impact_path(effect_name)) as ImpactEffect
		effect.play(Color.WHITE, 1.0)
		simulate(effect, 1, effect.lifetime * 0.5)
		assert_false(effect.is_queued_for_deletion(), "%s still alive mid-way" % effect_name)
		simulate(effect, 1, effect.lifetime * 0.6)
		assert_true(effect.is_queued_for_deletion(), "%s freed itself" % effect_name)


func test_effect_lifetime_covers_its_longest_particle_lifetime() -> void:
	for effect_name: String in IMPACT_SCENES:
		var effect := _instantiate(_impact_path(effect_name)) as ImpactEffect
		for particles in _particles(effect):
			assert_true(particles.lifetime <= effect.lifetime, "%s/%s" % [effect_name, particles.name])


func test_impact_particle_counts_stay_within_budget() -> void:
	for effect_name: String in IMPACT_SCENES:
		var effect := _instantiate(_impact_path(effect_name))
		assert_lte(_particle_count(effect), IMPACT_PARTICLE_BUDGET, effect_name)


func test_impact_particles_are_one_shot_and_explosive() -> void:
	for effect_name: String in IMPACT_SCENES:
		for particles in _particles(_instantiate(_impact_path(effect_name))):
			assert_true(particles.one_shot, "%s/%s" % [effect_name, particles.name])
			assert_eq(particles.explosiveness, 1.0, "%s/%s" % [effect_name, particles.name])


func test_impact_frame_is_hidden_until_flashed() -> void:
	var frame := _instantiate(IMPACT_FRAME_SCENE_PATH) as ImpactFrame
	assert_not_null(frame)
	assert_false(frame.visible)
	assert_eq(frame.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq((frame.material as ShaderMaterial).shader.resource_path, IMPACT_FRAME_SHADER_PATH)


func test_impact_frame_shows_for_its_frames_then_hides() -> void:
	var frame := _instantiate(IMPACT_FRAME_SCENE_PATH) as ImpactFrame
	frame.flash(2, 1.0)
	assert_true(frame.visible)
	assert_eq((frame.material as ShaderMaterial).get_shader_parameter("amount"), 1.0)
	await wait_process_frames(1)
	assert_true(frame.visible, "still shown on the second frame")
	await wait_process_frames(2)
	assert_false(frame.visible, "hidden after two frames")


func test_speed_lines_scene_uses_the_speed_lines_shader() -> void:
	var lines := _instantiate(SPEED_LINES_SCENE_PATH) as ColorRect
	assert_not_null(lines)
	assert_eq((lines.material as ShaderMaterial).shader.resource_path, SPEED_LINES_SHADER_PATH)
	assert_eq(lines.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_preview_scene_has_a_toon_fighter_with_an_aura_and_screen_effects() -> void:
	var preview := _instantiate(PREVIEW_PATH)
	var fighter: MeshInstance3D = preview.get_node("Fighter")
	var material := fighter.get_surface_override_material(0) as ShaderMaterial
	assert_eq(material.shader.resource_path, SHADER_DIR + "toon.gdshader")
	assert_true(preview.get_node("Fighter/FighterAura") is FighterAura)
	assert_true(preview.get_node("Screen/ImpactFrame") is ImpactFrame)
	assert_true(preview.get_node("Screen/SpeedLines") is ColorRect)
	assert_not_null(preview.get_node("Camera3D"))


func _press(preview: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	preview._unhandled_key_input(event)


func test_preview_number_keys_set_the_aura_power_level() -> void:
	var preview := _instantiate(PREVIEW_PATH)
	_press(preview, KEY_3)
	assert_eq((preview.get_node("Fighter/FighterAura") as FighterAura).power_level, 3.0)
	_press(preview, KEY_0)
	assert_eq((preview.get_node("Fighter/FighterAura") as FighterAura).power_level, 0.0)


func test_preview_keys_spawn_each_effect() -> void:
	var preview := _instantiate(PREVIEW_PATH)
	for keycode: Key in [KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N]:
		_press(preview, keycode)
	var spawned := preview.find_children("*", "Node3D", false, false).filter(
		func(node: Node) -> bool: return node is ImpactEffect)
	assert_eq(spawned.size(), 6)


func test_preview_g_key_drops_a_shockwave_flat_on_the_ground() -> void:
	var preview := _instantiate(PREVIEW_PATH)
	_press(preview, KEY_G)
	var spawned := preview.find_children("*", "Node3D", false, false).filter(
		func(node: Node) -> bool: return node is ShockwaveEffect)
	assert_eq(spawned.size(), 1)
	var ring: MeshInstance3D = (spawned[0] as Node).get_node("Ring")
	assert_true(ring.get_instance_shader_parameter("lie_flat"))


func test_preview_keys_drive_the_impact_frame_and_speed_lines() -> void:
	var preview := _instantiate(PREVIEW_PATH)
	_press(preview, KEY_M)
	assert_true((preview.get_node("Screen/ImpactFrame") as ImpactFrame).visible)
	_press(preview, KEY_S)
	var lines := (preview.get_node("Screen/SpeedLines") as ColorRect).material as ShaderMaterial
	assert_eq(lines.get_shader_parameter("amount"), 1.0)


func test_aura_flames_fade_out_on_faces_pointing_at_the_camera() -> void:
	var code := _source_without_comments(AURA_PATH)
	assert_string_contains(code, "center_clear")
	assert_string_contains(code, "dot(NORMAL, VIEW)")


func test_aura_flames_erode_more_toward_the_top() -> void:
	var shader: Shader = load(AURA_PATH)
	assert_gt(float(_declared_default(shader, "tip_threshold")), float(_declared_default(shader, "root_threshold")))
	assert_lt(float(_declared_default(shader, "tongue_stretch")), 1.0, "tongues are stretched vertically")


func test_shockwave_scene_is_a_shockwave_effect() -> void:
	assert_true(_instantiate(_impact_path("shockwave")) is ShockwaveEffect)


func test_shockwave_near_the_ground_lies_flat_on_it() -> void:
	var effect := _instantiate(_impact_path("shockwave")) as ShockwaveEffect
	effect.global_position = Vector3(2.0, 0.3, -1.0)
	effect.play(Color.TRANSPARENT, 2.0)
	var ring: MeshInstance3D = effect.get_node("Ring")
	assert_true(ring.get_instance_shader_parameter("lie_flat"))
	assert_eq(ring.get_instance_shader_parameter("surface_fade"), 0.0)
	var basis := effect.global_transform.basis
	assert_almost_eq(basis.z.normalized().dot(Vector3.UP), 1.0, 0.001, "ring faces up")
	assert_almost_eq(basis.get_scale(), Vector3.ONE * 2.0, Vector3.ONE * 0.001, "scale kept")
	assert_almost_eq(effect.global_position, Vector3(2.0, effect.surface_lift, -1.0), Vector3.ONE * 0.001)


func test_shockwave_in_the_air_faces_the_camera_and_fades_softly_into_the_ground() -> void:
	var effect := _instantiate(_impact_path("shockwave")) as ShockwaveEffect
	effect.global_position = Vector3(0.0, 1.5, 0.0)
	effect.play()
	var ring: MeshInstance3D = effect.get_node("Ring")
	assert_false(ring.get_instance_shader_parameter("lie_flat"))
	assert_eq(ring.get_instance_shader_parameter("surface_fade"), effect.ground_fade)
	assert_gt(effect.ground_fade, 0.0)
	assert_eq(ring.get_instance_shader_parameter("surface_plane"), Vector4(0.0, 1.0, 0.0, effect.ground_height))
	assert_almost_eq(effect.global_position.y, 1.5, 0.001, "stays where it was spawned")


func test_shockwave_on_a_surface_lies_flat_along_its_normal() -> void:
	var effect := _instantiate(_impact_path("shockwave")) as ShockwaveEffect
	effect.global_position = Vector3(0.0, 3.0, 0.0)
	effect.play_on_surface(Vector3.RIGHT, Color.CYAN)
	var ring: MeshInstance3D = effect.get_node("Ring")
	assert_true(ring.get_instance_shader_parameter("lie_flat"))
	assert_eq(ring.get_instance_shader_parameter("tint"), Color.CYAN)
	assert_almost_eq(effect.global_transform.basis.z.normalized().dot(Vector3.RIGHT), 1.0, 0.001)
