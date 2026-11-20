class_name VoxelBody
extends Node
## Swaps a character rig's mesh for a code-built voxel body (a VoxelDesign),
## skinned to the same skeleton so the character's existing clips drive it.
## Add it as a child of the CharacterView scene root; it runs before
## CharacterView's _ready (children are ready first). It loads the design's
## bake (VoxelBake, made by tools/voxel_bake.gd) and only builds live, with a
## warning, when the bake is missing or stale. Meshes are cached per design
## per process, so a second instance doesn't load or rebuild.

const SHADER := preload("res://game/characters/voxel_kit/voxel_figure.gdshader")

## A script extending VoxelDesign.
@export var design: Script
## The rig's MeshInstance3D to replace (a child of its Skeleton3D).
@export var mesh_path: NodePath

static var _cache := {}


func _ready() -> void:
	var target := get_node(mesh_path) as MeshInstance3D
	var skeleton := target.get_parent() as Skeleton3D
	var key := design.resource_path
	if not _cache.has(key):
		var why := []
		var bake := VoxelBake.load_for(design, skeleton, why)
		if bake != null:
			_cache[key] = [bake.mesh, bake.skin]
		else:
			push_warning("VoxelBody: building %s live (%s); run tools/voxel_bake.gd" % [key, why[0]])
			_cache[key] = [build(design.new(skeleton) as VoxelDesign), rest_skin(skeleton)]
	target.mesh = _cache[key][0]
	for i in target.get_surface_override_material_count():
		target.set_surface_override_material(i, null)
	target.material_overlay = null
	target.skin = _cache[key][1]


static func build(d: VoxelDesign) -> ArrayMesh:
	var materials := materials_for(d)
	var mesh := ArrayMesh.new()
	var soft := d.soft_materials()
	for g in d.build_grids():
		if not soft.is_empty():
			g.smooth(soft)
		var part := VoxelMesher.build(g, d.color, d.surface_of, d.weights, materials, d.blur_cells(g))
		append_part(mesh, part)
	return mesh


static func materials_for(d: VoxelDesign) -> Array[Material]:
	var list: Array[Material] = []
	for p: Dictionary in d.surface_params():
		var m := ShaderMaterial.new()
		m.shader = SHADER
		for k: String in p:
			m.set_shader_parameter(k, p[k])
		list.append(m)
	return list


static func append_part(into: ArrayMesh, part: ArrayMesh) -> void:
	var format := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	for s in part.get_surface_count():
		into.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part.surface_get_arrays(s), [], {}, format)
		into.surface_set_material(into.get_surface_count() - 1, part.surface_get_material(s))


## One bind per bone, posed at its rest (vertices are in rest skeleton space).
static func rest_skin(skeleton: Skeleton3D) -> Skin:
	var skin := Skin.new()
	for i in skeleton.get_bone_count():
		skin.add_bind(i, skeleton.get_bone_global_rest(i).affine_inverse())
	return skin
