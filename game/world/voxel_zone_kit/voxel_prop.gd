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
## Tiles per side of a far region (HLOD, see _far_regions).
const REGION := 4

## The shared surfaces a design's surface(mat) picks from.
enum Surf { MATTE, METAL, WATER, PETAL, GLOW, BARK }

const MERGED_SHADER := preload("res://game/world/voxel_zone_kit/voxel_merged_prop.gdshader")

## voxel_figure.gdshader's parameters and defaults, copied per surface into
## the merged meshes' materials.
const MERGED_PARAMS := {
	"roughness_value": 0.8, "metallic_value": 0.0, "specular_value": 0.4, "bevel_width": 0.16,
	"bevel_tilt": 0.7, "edge_lift": 0.12, "corner_ao": 0.85, "emission_value": 0.0,
}

static var _materials: Array[Material] = []
## The merged meshes' materials, kept in step by sync_materials().
static var _merged_materials: Array[ShaderMaterial] = []
## Set false to rebuild every mesh (ignores the disk cache).
static var use_cache := true
## Greedy-merge coplanar faces (VoxelFaceMerge): same look, a fraction of the
## triangles. False keeps one quad per voxel face.
static var merge_faces := true


## Builds (or loads) a mesh. paint(grid) fills a VoxelGrid; color(mat, p, c, n,
## occlusion, exposure) -> Color and surface(mat) -> Surf as for a VoxelDesign;
## bump version when the design changes. soft: materials smooth() may clean.
static func mesh(key: String, version: int, bounds: AABB, cell: float, paint: Callable, color: Callable,
		surface: Callable, soft := []) -> ArrayMesh:
	var path := CACHE_DIR + "%s_c%d_v%d%s.res" % [key, roundi(cell * 1000.0), version, "_m3" if merge_faces else ""]
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
	if merge_faces:
		out = VoxelFaceMerge.merge(out)
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	ResourceSaver.save(out, path)
	_apply_materials(out)
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
## ranges: where each tier ends (m), same length (0 = never ends); tiers
## switch hard at the range (fade is unused, kept for callers). shadow_tiers: how many of the finest tiers
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
	# WEB starts at the second tier, which then covers the first tier's range too.
	if VoxelQuality.value("skip_finest") and meshes.size() >= 2:
		var kept: Array[ArrayMesh] = meshes.slice(1)
		meshes = kept
		ranges = ranges.slice(1)
		shadow_tiers = mini(shadow_tiers, 1)
	# Quality tier: scaled ranges, fewer shadow tiers, no shadows from clutter.
	var scale: float = VoxelQuality.value("clutter_range" if float(ranges[0]) > 0.0 and float(ranges[0]) < 60.0
		else "range_scale")
	var cap: int = VoxelQuality.value("shadow_tiers")
	if cap > 0:
		shadow_tiers = mini(shadow_tiers, cap)
	if meshes[0].get_aabb().get_longest_axis_size() < float(VoxelQuality.value("clutter_size")):
		shadow_tiers = 0
	var tile_nodes := {}
	var last_begin := 0.0
	for key: Vector2i in tiles:
		var list: Array[Transform3D] = tiles[key]
		var begin := 0.0
		tile_nodes[key] = [] as Array[MultiMeshInstance3D]
		for t in meshes.size():
			var end := float(ranges[t]) * scale
			last_begin = begin
			var node := _multimesh(meshes[t], list)
			(tile_nodes[key] as Array[MultiMeshInstance3D]).append(node)
			node.name = "%s_%d_%d_t%d" % [node_name, key.x, key.y, t]
			# Hard switches, no margins: with fading off, Godot treats margins as
			# hysteresis, and after a camera cut a tile can sit in neither tier.
			node.visibility_range_begin = begin
			node.visibility_range_end = end
			node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if t < shadow_tiers \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(node)
			begin = end
	if float(ranges[-1]) == 0.0:
		_far_regions(root, node_name, meshes[-1], tiles, tile_nodes, last_begin, meshes.size() - 1 < shadow_tiers)
	return root


## HLOD for a placement whose last tier never ends: each REGION x REGION
## block of tiles also gets one node with the last tier of all its copies,
## shown from far enough that every tile in the block would show its last
## tier anyway (its begin plus the farthest tile centre), and the tiles take
## it as visibility parent, so they hide while it shows. The same picture,
## one draw per block instead of one per tile.
static func _far_regions(root: Node3D, node_name: String, far_mesh: ArrayMesh, tiles: Dictionary,
		tile_nodes: Dictionary, last_begin: float, shadows: bool) -> void:
	var regions := {}
	for key: Vector2i in tiles:
		var r := Vector2i(floori(key.x / float(REGION)), floori(key.y / float(REGION)))
		if not regions.has(r):
			regions[r] = []
		(regions[r] as Array).append(key)
	for r: Vector2i in regions:
		var keys: Array = regions[r]
		if keys.size() < 2:
			continue
		var all: Array[Transform3D] = []
		for key: Vector2i in keys:
			all.append_array(tiles[key])
		var far := _multimesh(far_mesh, all)
		far.name = "%s_far_%d_%d" % [node_name, r.x, r.y]
		var centre := _bounds(far_mesh, all).get_center()
		var reach := 0.0
		for key: Vector2i in keys:
			var n: MultiMeshInstance3D = tile_nodes[key][0]
			var list: Array[Transform3D] = tiles[key]
			reach = maxf(reach, _bounds(n.multimesh.mesh, list).get_center().distance_to(centre))
		far.visibility_range_begin = last_begin + reach + 1.0
		far.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(far)
		for key: Vector2i in keys:
			for n: MultiMeshInstance3D in tile_nodes[key]:
				n.visibility_parent = n.get_path_to(far)


## One mesh placed once (a landmark), optionally with a coarser far tier.
static func single(parent: Node3D, node_name: String, meshes: Array[ArrayMesh], ranges: Array,
		xf: Transform3D) -> Node3D:
	var list: Array[Transform3D] = [xf]
	return place(parent, node_name, meshes, ranges, list, meshes.size())


## The bounds of a mesh's copies (what the renderer measures visibility ranges from).
static func _bounds(m: Mesh, transforms: Array[Transform3D]) -> AABB:
	var box := transforms[0] * m.get_aabb()
	for xf in transforms:
		box = box.merge(xf * m.get_aabb())
	return box


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


## Copies the shared materials' values to the merged meshes' materials (call
## after changing a shared material, e.g. the lantern emission).
static func sync_materials() -> void:
	for m: ShaderMaterial in _merged_materials:
		_copy_params(m)


## Attaches the shared materials to a loaded mesh (surfaces keep their
## order); a merged mesh gets one material that reads its face texture and
## carries every shared material's values per surface.
static func _apply_materials(m: ArrayMesh) -> void:
	if not m.has_meta("faces"):
		for s in m.get_surface_count():
			m.surface_set_material(s, materials()[m.surface_get_name(s).to_int()])
		return
	var mat := ShaderMaterial.new()
	mat.shader = MERGED_SHADER
	mat.set_shader_parameter("faces", ImageTexture.create_from_image(m.get_meta("faces") as Image))
	_copy_params(mat)
	_merged_materials.append(mat)
	m.surface_set_material(0, mat)


static func _copy_params(mat: ShaderMaterial) -> void:
	for p: String in MERGED_PARAMS:
		var values := PackedFloat32Array()
		for shared: ShaderMaterial in materials():
			var v: Variant = shared.get_shader_parameter(p)
			values.append(float(v) if v != null else float(MERGED_PARAMS[p]))
		mat.set_shader_parameter(p, values)


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
