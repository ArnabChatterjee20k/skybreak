class_name LyraAstrolabe
extends Node3D
## Lyra's three floating astrolabe rings (docs/lookdev/lyra.md): view-only,
## not skinned. Sits under a BoneAttachment3D on UpperChest, so it follows the
## chest rigidly; each ring turns slowly about its own axis (a nested gimbal).

## A script extending VoxelDesign with build_ring(i) and RINGS (LyraVoxelDesign).
@export var design: Script
## Turn rate per ring, radians per second.
@export var spin := Vector3(0.35, -0.5, 0.8)

const AXES: Array[Vector3] = [Vector3.UP, Vector3.RIGHT, Vector3.BACK]
## Scripts besides the design chain and the kit that shape the rings, and the bake's key.
const BAKE_SOURCES: Array[String] = ["res://game/characters/lyra_voxel/lyra_astrolabe.gd"]
const BAKE_KEY := "astrolabe"

static var _cache := {}

var rings: Array[MeshInstance3D] = []


func _ready() -> void:
	var attachment := get_parent() as BoneAttachment3D
	var skeleton := attachment.get_parent() as Skeleton3D
	var bone := skeleton.find_bone(attachment.bone_name)
	var d := design.new(skeleton) as LyraVoxelDesign
	# Place the centre at its rest-pose spot, axes aligned with the skeleton.
	transform = skeleton.get_bone_global_rest(bone).affine_inverse() * Transform3D(Basis(), LyraVoxelDesign.ASTROLABE_CENTER)
	var key := design.resource_path
	if not _cache.has(key):
		var why := []
		var baked := VoxelBake.load_rigid(design, BAKE_SOURCES, BAKE_KEY, why)
		if baked.is_empty():
			push_warning("LyraAstrolabe: building %s live (%s); run tools/voxel_bake.gd" % [key, why[0]])
			_cache[key] = build(d)
		else:
			_cache[key] = baked
	var meshes: Array = _cache[key]
	for i in meshes.size():
		var mi := MeshInstance3D.new()
		mi.name = "Ring%d" % i
		mi.mesh = meshes[i]
		add_child(mi)
		rings.append(mi)
	# Start the gimbals at different angles so they never line up flat.
	rings[0].rotation = Vector3(0.0, 0.6, 0.0)
	rings[1].rotation = Vector3(1.1, 0.0, 0.0)
	rings[2].rotation = Vector3(0.4, 0.9, 0.0)


func _process(delta: float) -> void:
	for i in rings.size():
		rings[i].rotate_object_local(AXES[i], spin[i] * delta)


## One unskinned mesh per ring.
static func build(d: LyraVoxelDesign) -> Array:
	var materials := VoxelBody.materials_for(d)
	var list := []
	for i in LyraVoxelDesign.RINGS.size():
		var g := d.build_ring(i)
		var skinned := VoxelMesher.build(g, d.color, d.surface_of, d.weights, materials, d.blur_cells(g))
		list.append(_unskinned(skinned))
	return list


static func _unskinned(src: ArrayMesh) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var format := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format)
		mesh.surface_set_material(mesh.get_surface_count() - 1, src.surface_get_material(s))
	return mesh
