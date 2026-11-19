class_name TerrainGrid
extends RefCounted
## Shared flat grid meshes per LOD for one terrain chunk. The terrain shader lifts
## each vertex to the baked height, so every chunk reuses the same 4 meshes.

## Cells per chunk side at LOD 0 (128 m with 2 m cells).
const CHUNK_CELLS := 64
const LOD_COUNT := 4
## Far edge (m) of each LOD band, from the camera to the chunk centre.
const LOD_END: Array[float] = [230.0, 470.0, 820.0, 1300.0]
## Skirt depth (m) per LOD step, hides cracks between neighbouring LODs.
const SKIRT_DEPTH := 6.0

static var _meshes: Array[ArrayMesh] = []


## LOD for a chunk whose centre is `distance` metres away; -1 when beyond the last band.
static func lod_for_distance(distance: float) -> int:
	for lod in LOD_COUNT:
		if distance < LOD_END[lod]:
			return lod
	return -1


static func lod_begin(lod: int) -> float:
	return 0.0 if lod == 0 else LOD_END[lod - 1]


## Cells between vertices at this LOD.
static func lod_step(lod: int) -> int:
	return 1 << lod


static func mesh_for_lod(lod: int, cell_size: float) -> ArrayMesh:
	if _meshes.is_empty() or not is_equal_approx(float(_meshes[0].get_meta("cell_size")), cell_size):
		_meshes.clear()
		for l in LOD_COUNT:
			_meshes.append(_build(l, cell_size))
	return _meshes[lod]


## Triangles drawn for one chunk at this LOD, skirts included.
static func triangle_count(lod: int) -> int:
	var quads := CHUNK_CELLS >> lod
	return quads * quads * 2 + 4 * quads * 2


# Grid of (quads + 1)² vertices in chunk-local metres; skirt vertices have UV.x = 1.
static func _build(lod: int, cell_size: float) -> ArrayMesh:
	var quads := CHUNK_CELLS >> lod
	var spacing := cell_size * float(lod_step(lod))
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var row_len := quads + 1
	for j in row_len:
		for i in row_len:
			verts.append(Vector3(i * spacing, 0.0, j * spacing))
			uvs.append(Vector2.ZERO)
	for j in quads:
		for i in quads:
			var a := j * row_len + i
			var b := a + 1
			var c := a + row_len
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])
	# Skirts: a dropped copy of each border edge.
	var edges: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
	for k in row_len:
		edges[0].append(k)  # north, z = 0
		edges[1].append(quads * row_len + k)  # south
		edges[2].append(k * row_len)  # west, x = 0
		edges[3].append(k * row_len + quads)  # east
	for side in 4:
		var edge := edges[side]
		var base := verts.size()
		for k in edge.size():
			verts.append(verts[edge[k]])
			uvs.append(Vector2(1.0, 0.0))
		for k in quads:
			var top_a := edge[k]
			var top_b := edge[k + 1]
			var low_a := base + k
			var low_b := base + k + 1
			# Winding faces outward; north and east sides flip.
			if side == 0 or side == 3:
				indices.append_array([top_a, low_a, top_b, top_b, low_a, low_b])
			else:
				indices.append_array([top_a, top_b, low_a, top_b, low_b, low_a])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.set_meta("cell_size", cell_size)
	mesh.set_meta("triangles", indices.size() / 3)
	return mesh
