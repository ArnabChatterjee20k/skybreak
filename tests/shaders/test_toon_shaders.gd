extends GutTest

const TOON_PATH := "res://game/view/shaders/toon.gdshader"
const OUTLINE_PATH := "res://game/view/shaders/outline.gdshader"
const CHARACTER_PATH := "res://game/view/shaders/materials/toon_character.tres"
const PROP_PATH := "res://game/view/shaders/materials/toon_prop.tres"
const PREVIEW_PATH := "res://game/view/shaders/preview/shader_preview.tscn"

const TOON_DEFAULTS := {
	"albedo_color": "vec4(1.0)",
	"band_count": "3",
	"shadow_threshold": "0.15",
	"highlight_threshold": "0.55",
	"mid_band_level": "0.6",
	"band_softness": "0.01",
	"use_ramp_texture": "false",
	"shadow_tint": "vec4(0.42, 0.38, 0.58, 1.0)",
	"specular_enabled": "true",
	"specular_color": "vec4(1.0)",
	"specular_size": "0.12",
	"specular_softness": "0.01",
	"specular_strength": "0.6",
	"rim_color": "vec4(1.0, 0.96, 0.9, 1.0)",
	"rim_width": "0.3",
	"rim_softness": "0.05",
	"rim_strength": "0.35",
	"rim_energy_color": "vec4(0.3, 0.85, 1.0, 1.0)",
	"rim_energy_mix": "0.0",
}

const OUTLINE_DEFAULTS := {
	"outline_color": "vec4(0.06, 0.04, 0.1, 1.0)",
	"outline_width": "2.0",
	"outline_fade_distance": "25.0",
	"outline_min_width": "0.75",
	"use_vertex_color_mask": "false",
}


# The headless renderer can't report uniform defaults, so read them from the source.
func _declared_default(shader: Shader, uniform_name: String) -> String:
	var regex := RegEx.create_from_string(
		"uniform\\s+\\w+\\s+" + uniform_name + "\\b[^=;]*=\\s*([^;]+);")
	var found := regex.search(shader.code)
	return found.get_string(1).strip_edges() if found else "<none>"


func _uniform_names(shader: Shader) -> Array[String]:
	var names: Array[String] = []
	for uniform in shader.get_shader_uniform_list():
		names.append(uniform.name)
	return names


func _assert_defaults(shader: Shader, expected: Dictionary) -> void:
	var names := _uniform_names(shader)
	for uniform_name: String in expected:
		assert_has(names, uniform_name, "%s is a uniform" % uniform_name)
		assert_eq(_declared_default(shader, uniform_name), expected[uniform_name], uniform_name)


func test_toon_shader_loads_as_a_spatial_shader() -> void:
	var shader: Shader = load(TOON_PATH)
	assert_not_null(shader)
	assert_eq(shader.get_mode(), Shader.MODE_SPATIAL)


func test_outline_shader_loads_as_a_spatial_shader() -> void:
	var shader: Shader = load(OUTLINE_PATH)
	assert_not_null(shader)
	assert_eq(shader.get_mode(), Shader.MODE_SPATIAL)


func test_toon_uniforms_have_expected_defaults() -> void:
	_assert_defaults(load(TOON_PATH), TOON_DEFAULTS)


func test_toon_exposes_albedo_and_ramp_textures() -> void:
	var names := _uniform_names(load(TOON_PATH))
	assert_has(names, "albedo_texture")
	assert_has(names, "ramp_texture")


func test_outline_uniforms_have_expected_defaults() -> void:
	_assert_defaults(load(OUTLINE_PATH), OUTLINE_DEFAULTS)


func test_outline_draws_back_faces_unshaded() -> void:
	var code: String = (load(OUTLINE_PATH) as Shader).code
	assert_string_contains(code, "cull_front")
	assert_string_contains(code, "unshaded")


func test_character_material_uses_toon_with_outline_as_next_pass() -> void:
	var material: ShaderMaterial = load(CHARACTER_PATH)
	assert_not_null(material)
	assert_eq(material.shader.resource_path, TOON_PATH)
	var outline := material.next_pass as ShaderMaterial
	assert_not_null(outline, "next_pass is a ShaderMaterial")
	assert_eq(outline.shader.resource_path, OUTLINE_PATH)
	assert_eq(material.get_shader_parameter("specular_enabled"), true)


func test_prop_material_has_no_specular_and_a_thinner_outline() -> void:
	var prop: ShaderMaterial = load(PROP_PATH)
	var character: ShaderMaterial = load(CHARACTER_PATH)
	assert_eq(prop.shader.resource_path, TOON_PATH)
	assert_eq(prop.get_shader_parameter("specular_enabled"), false)
	var prop_outline := prop.next_pass as ShaderMaterial
	assert_not_null(prop_outline, "next_pass is a ShaderMaterial")
	assert_eq(prop_outline.shader.resource_path, OUTLINE_PATH)
	assert_lt(prop_outline.get_shader_parameter("outline_width"),
		(character.next_pass as ShaderMaterial).get_shader_parameter("outline_width"))


func test_preview_scene_instantiates_with_light_environment_and_toon_meshes() -> void:
	var scene: PackedScene = load(PREVIEW_PATH)
	assert_not_null(scene)
	var preview: Node = scene.instantiate()
	add_child_autofree(preview)
	assert_eq(preview.find_children("*", "DirectionalLight3D").size(), 1)
	assert_eq(preview.find_children("*", "WorldEnvironment").size(), 1)
	assert_not_null(preview.get_node("Camera3D"))
	var fighter: MeshInstance3D = preview.get_node("Fighter")
	assert_eq(fighter.get_surface_override_material(0).resource_path, CHARACTER_PATH)
	var box: MeshInstance3D = preview.get_node("Box")
	assert_eq(box.get_surface_override_material(0).resource_path, PROP_PATH)
	for mesh_name in ["Torus", "HairSphere"]:
		assert_true(preview.get_node(mesh_name) is MeshInstance3D, mesh_name)
