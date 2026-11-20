class_name KaelVoxelBody
extends Node
## Swaps the rig's mesh for the code-built voxel Kael (KaelVoxelDesign),
## skinned to the same skeleton so the existing clips drive it. Runs before
## CharacterView's _ready (children are ready first). The built mesh is cached
## per process, so a second Kael doesn't rebuild it.

const SHADER := preload("res://game/characters/kael_voxel/voxel_figure.gdshader")

@export var mesh_path: NodePath

static var _cache: ArrayMesh


func _ready() -> void:
	var target := get_node(mesh_path) as MeshInstance3D
	var skeleton := target.get_parent() as Skeleton3D
	if _cache == null:
		_cache = build(skeleton)
	target.mesh = _cache
	for i in target.get_surface_override_material_count():
		target.set_surface_override_material(i, null)
	target.material_overlay = null
	target.skin = _skin(skeleton)


static func build(skeleton: Skeleton3D) -> ArrayMesh:
	var design := KaelVoxelDesign.new(skeleton)
	var materials := materials()
	var color_fn := KaelVoxelDesign.color
	var surface_fn := KaelVoxelDesign.surface_of
	var weight_fn := design.weights
	var grids: Array[VoxelGrid] = [design.build_body(), design.build_head(),
		design.build_gauntlet(1.0), design.build_gauntlet(-1.0)]
	var mesh := ArrayMesh.new()
	var soft := [KaelVoxelDesign.Mat.COAT, KaelVoxelDesign.Mat.TUNIC, KaelVoxelDesign.Mat.PANTS,
		KaelVoxelDesign.Mat.SCARF, KaelVoxelDesign.Mat.BOOT, KaelVoxelDesign.Mat.HAIR, KaelVoxelDesign.Mat.SKIN,
		KaelVoxelDesign.Mat.GLOVE, KaelVoxelDesign.Mat.LAPEL]
	for g in grids:
		g.smooth(soft)
		var blur := 2 if g.cell > KaelVoxelDesign.FINE_CELL * 1.5 else 3
		var part := VoxelMesher.build(g, color_fn, surface_fn, weight_fn, materials, blur)
		_append(mesh, part)
	return mesh


static func materials() -> Array[Material]:
	var list: Array[Material] = []
	# CLOTH, METAL, GLASS, SKIN, GLOW, HAIR
	var params := [
		{"roughness_value": 0.86, "specular_value": 0.3, "bevel_tilt": 0.35, "edge_lift": 0.05},
		{"roughness_value": 0.44, "metallic_value": 0.75, "specular_value": 0.6, "edge_lift": 0.25},
		{"roughness_value": 0.08, "metallic_value": 0.1, "specular_value": 0.9, "emission_value": 0.25},
		{"roughness_value": 0.62, "specular_value": 0.35, "edge_lift": 0.06},
		{"roughness_value": 0.5, "emission_value": 0.35, "edge_lift": 0.0},
		{"roughness_value": 0.7, "specular_value": 0.45, "edge_lift": 0.18},
	]
	for p: Dictionary in params:
		var m := ShaderMaterial.new()
		m.shader = SHADER
		for k: String in p:
			m.set_shader_parameter(k, p[k])
		list.append(m)
	return list


static func _append(into: ArrayMesh, part: ArrayMesh) -> void:
	for s in part.get_surface_count():
		into.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part.surface_get_arrays(s), [], {}, _custom_format())
		into.surface_set_material(into.get_surface_count() - 1, part.surface_get_material(s))


static func _custom_format() -> int:
	return (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)


## One bind per bone, posed at its rest (vertices are in rest skeleton space).
static func _skin(skeleton: Skeleton3D) -> Skin:
	var skin := Skin.new()
	for i in skeleton.get_bone_count():
		skin.add_bind(i, skeleton.get_bone_global_rest(i).affine_inverse())
	return skin
