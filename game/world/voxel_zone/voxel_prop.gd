class_name VoxelProp
extends RefCounted
## Static (unskinned) voxel meshes for zone props, built with the character
## kit's VoxelGrid and VoxelMesher, so props share the characters' voxel look
## (per-voxel colour, cavity AO, corner AO, bevelled edges) at their own cell
## size. Meshes are cached on disk by key: they're generated once, not on
## every launch.

const SHADER := preload("res://game/characters/voxel_kit/voxel_figure.gdshader")
const CACHE_DIR := "user://voxel_prop_cache/"

static var _materials: Array[Material] = []


## Builds (or loads) a mesh. paint(grid) fills the grid; color(mat, p, c, n,
## occlusion, exposure) -> Color and surface(mat) -> int as for a VoxelDesign;
## version invalidates the cache when the design changes.
static func mesh(key: String, version: int, bounds: AABB, cell: float, paint: Callable, color: Callable,
		surface: Callable, soft := []) -> ArrayMesh:
	var path := CACHE_DIR + "%s_v%d.res" % [key, version]
	if ResourceLoader.exists(path):
		var cached := load(path) as ArrayMesh
		if cached != null:
			_apply_materials(cached, surface)
			return cached
	var g := VoxelGrid.new(bounds, cell)
	paint.call(g)
	if not soft.is_empty():
		g.smooth(soft)
	var none := [PackedInt32Array([0, 0, 0, 0]), PackedFloat32Array([1, 0, 0, 0])]
	var m := VoxelMesher.build(g, color, surface, func(_t: int, _p: Vector3) -> Array: return none,
		materials(), 2 if cell > 0.05 else 3)
	var out := _strip_skin(m)
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	ResourceSaver.save(out, path)
	return out


## The six shared surfaces (CLOTH-like matte, METAL, GLASS, SKIN-like, GLOW,
## HAIR-like), tuned for world materials: stone, bark and petals are matte.
static func materials() -> Array[Material]:
	if _materials.is_empty():
		var params := [
			{"roughness_value": 0.9, "specular_value": 0.25, "bevel_tilt": 0.45, "edge_lift": 0.16},  # 0 stone/wood/matte
			{"roughness_value": 0.4, "metallic_value": 0.7, "specular_value": 0.6, "edge_lift": 0.25},  # 1 metal
			{"roughness_value": 0.1, "specular_value": 0.8, "emission_value": 0.15},  # 2 water/glass
			{"roughness_value": 0.75, "specular_value": 0.3, "bevel_tilt": 0.3, "edge_lift": 0.1},  # 3 blossom
			{"roughness_value": 0.6, "emission_value": 1.2, "edge_lift": 0.0},  # 4 lantern glow
			{"roughness_value": 0.85, "specular_value": 0.3, "edge_lift": 0.12},  # 5 bark
		]
		for p: Dictionary in params:
			var m := ShaderMaterial.new()
			m.shader = SHADER
			for k: String in p:
				m.set_shader_parameter(k, p[k])
			_materials.append(m)
	return _materials


## Re-attaches the shared materials to a loaded mesh (surfaces keep their order).
static func _apply_materials(m: ArrayMesh, _surface: Callable) -> void:
	for s in m.get_surface_count():
		var idx: int = m.surface_get_name(s).to_int()
		m.surface_set_material(s, materials()[idx])


## Drops the bone/weight arrays (static props) and names each surface by its
## material index, so a cached mesh can get its materials back.
static func _strip_skin(m: ArrayMesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	var format := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	for s in m.get_surface_count():
		var arrays := m.surface_get_arrays(s)
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format)
		var idx := materials().find(m.surface_get_material(s))
		out.surface_set_name(out.get_surface_count() - 1, str(idx))
		out.surface_set_material(out.get_surface_count() - 1, m.surface_get_material(s))
	return out


## Places many copies of a mesh with a MultiMesh (optionally tinted per instance
## through the vertex colour multiplier is not available: tint by variants).
static func instances(parent: Node3D, node_name: String, m: Mesh, transforms: Array[Transform3D],
		visibility_end := 0.0) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	if visibility_end > 0.0:
		node.visibility_range_end = visibility_end
	parent.add_child(node)
	return node
