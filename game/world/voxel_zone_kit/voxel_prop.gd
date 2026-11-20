class_name VoxelProp
extends RefCounted
## Static (unskinned) voxel meshes for zone props, built with the character
## kit's VoxelGrid and VoxelMesher, so props share the characters' voxel look
## (per-voxel colour, cavity AO, corner AO, bevelled edges) at their own cell
## size. Meshes are cached on disk by key and version: generated once, then
## loaded. Placement goes through MultiMesh tiles with LOD tiers, so the far
## field costs little and the scatter only draws near the camera.

const SHADER := preload("res://game/characters/voxel_kit/voxel_figure.gdshader")
const CACHE_DIR := "user://voxel_prop_cache/"
## Side of a placement tile (m): each tile is its own MultiMesh, so visibility
## ranges and frustum culling work per tile, not per zone.
const TILE := 48.0

## The shared surfaces a design's surface(mat) picks from.
enum Surf { MATTE, METAL, WATER, PETAL, GLOW, BARK }

static var _materials: Array[Material] = []
## Set false to rebuild every mesh (ignores the disk cache).
static var use_cache := true


## Builds (or loads) a mesh. paint(grid) fills a VoxelGrid; color(mat, p, c, n,
## occlusion, exposure) -> Color and surface(mat) -> Surf as for a VoxelDesign;
## bump version when the design changes. soft: materials smooth() may clean.
static func mesh(key: String, version: int, bounds: AABB, cell: float, paint: Callable, color: Callable,
		surface: Callable, soft := []) -> ArrayMesh:
	var path := CACHE_DIR + "%s_c%d_v%d.res" % [key, roundi(cell * 1000.0), version]
	if use_cache and ResourceLoader.exists(path):
		var cached := load(path) as ArrayMesh
		if cached != null:
			_apply_materials(cached)
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


## The same design at several cells, finest first (one mesh per LOD tier).
static func tiers(key: String, version: int, bounds: AABB, cells: Array, paint: Callable, color: Callable,
		surface: Callable, soft := []) -> Array[ArrayMesh]:
	var out: Array[ArrayMesh] = []
	for c: float in cells:
		out.append(mesh(key, version, bounds, c, paint, color, surface, soft))
	return out


## The shared world surfaces (indexed by Surf), tuned for matte stone, bark
## and petals.
static func materials() -> Array[Material]:
	if _materials.is_empty():
		var params := [
			{"roughness_value": 0.9, "specular_value": 0.25, "bevel_tilt": 0.45, "edge_lift": 0.16},  # MATTE
			{"roughness_value": 0.4, "metallic_value": 0.7, "specular_value": 0.6, "edge_lift": 0.25},  # METAL
			{"roughness_value": 0.1, "specular_value": 0.8, "emission_value": 0.15},  # WATER
			{"roughness_value": 0.75, "specular_value": 0.3, "bevel_tilt": 0.3, "edge_lift": 0.1},  # PETAL
			{"roughness_value": 0.6, "emission_value": 1.2, "edge_lift": 0.0},  # GLOW
			{"roughness_value": 0.85, "specular_value": 0.3, "edge_lift": 0.12},  # BARK
		]
		for p: Dictionary in params:
			var m := ShaderMaterial.new()
			m.shader = SHADER
			for k: String in p:
				m.set_shader_parameter(k, p[k])
			_materials.append(m)
	return _materials


## Quads in a mesh (two triangles each).
static func quads(m: Mesh) -> int:
	var total := 0
	for s in m.get_surface_count():
		var n: int = m.surface_get_array_index_len(s)
		total += (n if n > 0 else m.surface_get_array_len(s)) / 6
	return total


## Places copies of a mesh with LOD tiers, tiled. meshes: finest first;
## ranges: where each tier ends (m), same length (0 = never ends). Tiers fade
## into each other over `fade` m. shadow_tiers: how many of the finest tiers
## cast shadows (the far ones never do). tile: the tile side (m); 0 picks
## TILE, or a third of it for short-range scatter (first range < 40 m), so
## the range switches small patches. Returns the parent node.
static func place(parent: Node3D, node_name: String, meshes: Array[ArrayMesh], ranges: Array,
		transforms: Array[Transform3D], shadow_tiers := 1, fade := 6.0, tile := 0.0) -> Node3D:
	if tile <= 0.0:
		tile = TILE / 3.0 if float(ranges[0]) > 0.0 and float(ranges[0]) < 40.0 else TILE
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	var tiles := {}
	for xf in transforms:
		var key := Vector2i(floori(xf.origin.x / tile), floori(xf.origin.z / tile))
		if not tiles.has(key):
			tiles[key] = [] as Array[Transform3D]
		(tiles[key] as Array[Transform3D]).append(xf)
	for key: Vector2i in tiles:
		var list: Array[Transform3D] = tiles[key]
		var begin := 0.0
		for t in meshes.size():
			var node := _multimesh(meshes[t], list)
			node.name = "%s_%d_%d_t%d" % [node_name, key.x, key.y, t]
			node.visibility_range_begin = begin
			node.visibility_range_end = float(ranges[t])
			if begin > 0.0:
				node.visibility_range_begin_margin = fade
			if float(ranges[t]) > 0.0:
				node.visibility_range_end_margin = fade
			node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if t < shadow_tiers \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(node)
			begin = float(ranges[t])
	return root


## One mesh placed once (a landmark), optionally with a coarser far tier.
static func single(parent: Node3D, node_name: String, meshes: Array[ArrayMesh], ranges: Array,
		xf: Transform3D) -> Node3D:
	var list: Array[Transform3D] = [xf]
	return place(parent, node_name, meshes, ranges, list, meshes.size())


static func _multimesh(m: Mesh, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	return node


## Re-attaches the shared materials to a loaded mesh (surfaces keep their order).
static func _apply_materials(m: ArrayMesh) -> void:
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
