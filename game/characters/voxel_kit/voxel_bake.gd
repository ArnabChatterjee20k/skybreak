class_name VoxelBake
extends Resource
## A design's built mesh, skin and materials, saved by tools/voxel_bake.gd so
## VoxelBody loads it instead of building for seconds at startup. It is used
## only while its source hash matches the design script (and its base
## scripts) plus the kit sources, and its rig matches the skeleton.

## Bump when the saved layout changes.
const VERSION := 1
const DIR := "res://game/characters/voxel_kit/baked/"
## Kit sources that change the built mesh.
const KIT_SOURCES: Array[String] = [
	"res://game/characters/voxel_kit/voxel_sdf.gd",
	"res://game/characters/voxel_kit/voxel_grid.gd",
	"res://game/characters/voxel_kit/voxel_mesher.gd",
	"res://game/characters/voxel_kit/voxel_design.gd",
	"res://game/characters/voxel_kit/voxel_body.gd",
]
## Bone rest positions may differ by this much (metres) between machines.
const REST_SLACK := 0.0001

@export var version := VERSION
@export var source_hash := ""
@export var mesh: ArrayMesh
@export var skin: Skin
@export var bone_names := PackedStringArray()
@export var bone_rests := PackedVector3Array()
## Vertex count and SHA-256 of the mesh arrays, for tests and the bake log.
@export var vertex_count := 0
@export var mesh_checksum := ""


## Where the bake of a design script lives.
static func path_for(design: Script) -> String:
	return DIR + design.resource_path.get_file().get_basename() + ".res"


## SHA-256 of the design chain and kit sources, or "" when the sources can't
## be read (exported builds ship tokenised scripts; their bakes are trusted).
static func source_hash_for(design: Script) -> String:
	var paths: Array[String] = []
	var s := design
	while s != null and s.resource_path != "":
		paths.append(s.resource_path)
		s = s.get_base_script()
	for p in KIT_SOURCES:
		if not p in paths:
			paths.append(p)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for p in paths:
		if not FileAccess.file_exists(p):
			return ""
		var text := FileAccess.get_file_as_string(p).replace("\r", "")
		if text.is_empty():
			return ""
		ctx.update((p + "\n" + text + "\n").to_utf8_buffer())
	return ctx.finish().hex_encode()


## Vertex count and SHA-256 over every surface's arrays and material params.
static func checksum(m: ArrayMesh) -> Array:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var count := 0
	for s in m.get_surface_count():
		var arrays := m.surface_get_arrays(s)
		count += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		ctx.update(var_to_bytes(arrays))
		var mat := m.surface_get_material(s) as ShaderMaterial
		if mat != null:
			ctx.update(var_to_bytes([mat.shader.resource_path, _params(mat)]))
	return [count, ctx.finish().hex_encode()]


static func _params(mat: ShaderMaterial) -> Array:
	var out := []
	for u: Dictionary in mat.shader.get_shader_uniform_list():
		out.append([u.name, mat.get_shader_parameter(u.name)])
	return out


## Builds a design on a skeleton and wraps it, ready to save.
static func make(design: Script, skeleton: Skeleton3D) -> VoxelBake:
	var bake := VoxelBake.new()
	bake.source_hash = source_hash_for(design)
	bake.mesh = VoxelBody.build(design.new(skeleton) as VoxelDesign)
	bake.skin = VoxelBody.rest_skin(skeleton)
	for i in skeleton.get_bone_count():
		bake.bone_names.append(skeleton.get_bone_name(i))
		bake.bone_rests.append(skeleton.get_bone_global_rest(i).origin)
	var sum := checksum(bake.mesh)
	bake.vertex_count = sum[0]
	bake.mesh_checksum = sum[1]
	return bake


## Saves with fixed sub-resource ids, so the same build gives the same bytes.
func save_to(path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	mesh.resource_name = path.get_file().get_basename()
	mesh.resource_scene_unique_id = "mesh"
	skin.resource_scene_unique_id = "skin"
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s)
		if mat != null:
			mat.resource_scene_unique_id = "surface_%d" % s
	return ResourceSaver.save(self, path, ResourceSaver.FLAG_COMPRESS)


## The design's bake if present and current for this skeleton, else null
## (with the reason in why[0]).
static func load_for(design: Script, skeleton: Skeleton3D, why: Array = []) -> VoxelBake:
	var path := path_for(design)
	if not ResourceLoader.exists(path):
		why.append("no bake at %s" % path)
		return null
	var bake := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as VoxelBake
	if bake == null or bake.version != VERSION or bake.mesh == null or bake.skin == null:
		why.append("unreadable or old bake at %s" % path)
		return null
	var current := source_hash_for(design)
	if current != "" and current != bake.source_hash:
		why.append("stale bake (sources changed since it was baked)")
		return null
	if not bake.matches_rig(skeleton):
		why.append("bake rig differs from the skeleton (bone names or rest pose)")
		return null
	return bake


func matches_rig(skeleton: Skeleton3D) -> bool:
	if skeleton.get_bone_count() != bone_names.size():
		return false
	for i in bone_names.size():
		if skeleton.get_bone_name(i) != bone_names[i]:
			return false
		if skeleton.get_bone_global_rest(i).origin.distance_to(bone_rests[i]) > REST_SLACK:
			return false
	return true
