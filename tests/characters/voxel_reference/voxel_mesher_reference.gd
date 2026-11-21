extends RefCounted
## The voxel_mesher.gd of the approved voxel kit (lookdev-heartbloom-v1, 3246c72), kept
## verbatim as the reference the optimised kit must match bit for bit.
## Turns a VoxelGrid into a skinned ArrayMesh, one face per open voxel side.
## Each vertex carries:
## - COLOR: the cell's material colour with per-voxel variation, darkened by
##   cavity occlusion (a blurred-occupancy field) and lifted on exposed edges;
## - CUSTOM0: classic voxel corner AO for the face's 4 corners (bilinear in the shader);
## - CUSTOM1: which face edges are convex (for the bevel highlight);
## - UV: the face's own 0..1 square; TANGENT: the face's u axis.
## Skin weights come from weight_fn(tag, position) -> [PackedInt32Array, PackedFloat32Array].

const DIRS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
const U_AXES: Array[Vector3i] = [
	Vector3i(0, 0, -1), Vector3i(0, 0, 1), Vector3i(1, 0, 0),
	Vector3i(1, 0, 0), Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
]
const CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]


class Surface:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var custom0 := PackedFloat32Array()
	var custom1 := PackedFloat32Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()


## color_fn(mat, cell_center, cell, normal, occlusion, exposure) -> Color
## surface_of(mat) -> int index into materials
static func build(grid: VoxelGrid, color_fn: Callable, surface_of: Callable, weight_fn: Callable,
		materials: Array[Material], blur_cells := 2) -> ArrayMesh:
	var density := _blurred_occupancy(grid, blur_cells)
	var surfaces: Array[Surface] = []
	for m in materials:
		surfaces.append(Surface.new())
	var weight_cache := {}
	var s := grid.size
	for z in s.z:
		for y in s.y:
			for x in s.x:
				var mat := grid.mats[x + s.x * (y + s.y * z)]
				if mat == 0:
					continue
				var tag := grid.tags[x + s.x * (y + s.y * z)]
				var c := Vector3i(x, y, z)
				var centre := grid.center(x, y, z)
				var surface := surfaces[surface_of.call(mat)]
				for d in 6:
					var n := DIRS[d]
					if grid.get_mat(x + n.x, y + n.y, z + n.z) != 0:
						continue
					_add_face(grid, surface, c, centre, d, mat, tag, density, blur_cells, color_fn,
						weight_fn, weight_cache)
	var mesh := ArrayMesh.new()
	var format := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	for i in surfaces.size():
		var sf := surfaces[i]
		if sf.verts.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = sf.verts
		arrays[Mesh.ARRAY_NORMAL] = sf.normals
		arrays[Mesh.ARRAY_TANGENT] = sf.tangents
		arrays[Mesh.ARRAY_COLOR] = sf.colors
		arrays[Mesh.ARRAY_TEX_UV] = sf.uvs
		arrays[Mesh.ARRAY_CUSTOM0] = sf.custom0
		arrays[Mesh.ARRAY_CUSTOM1] = sf.custom1
		arrays[Mesh.ARRAY_BONES] = sf.bones
		arrays[Mesh.ARRAY_WEIGHTS] = sf.weights
		arrays[Mesh.ARRAY_INDEX] = sf.indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format)
		mesh.surface_set_material(mesh.get_surface_count() - 1, materials[i])
	return mesh


static func _add_face(grid: VoxelGrid, sf: Surface, c: Vector3i, centre: Vector3, d: int, mat: int,
		tag: int, density: PackedFloat32Array, blur_cells: int, color_fn: Callable,
		weight_fn: Callable, cache: Dictionary) -> void:
	var n := DIRS[d]
	var u := U_AXES[d]
	var v := Vector3i(Vector3(n).cross(Vector3(u)).round())
	var nf := Vector3(n)
	# Convex edges: the neighbour across that edge is empty (u-, u+, v-, v+).
	var edges := PackedFloat32Array([
		1.0 if grid.get_mat(c.x - u.x, c.y - u.y, c.z - u.z) == 0 else 0.0,
		1.0 if grid.get_mat(c.x + u.x, c.y + u.y, c.z + u.z) == 0 else 0.0,
		1.0 if grid.get_mat(c.x - v.x, c.y - v.y, c.z - v.z) == 0 else 0.0,
		1.0 if grid.get_mat(c.x + v.x, c.y + v.y, c.z + v.z) == 0 else 0.0,
	])
	var ao := PackedFloat32Array()
	var base := sf.verts.size()
	for corner in CORNERS:
		var su := corner.x * 2 - 1
		var sv := corner.y * 2 - 1
		var o := c + n
		var side1 := 1 if grid.get_mat(o.x + u.x * su, o.y + u.y * su, o.z + u.z * su) != 0 else 0
		var side2 := 1 if grid.get_mat(o.x + v.x * sv, o.y + v.y * sv, o.z + v.z * sv) != 0 else 0
		var diag := 1 if grid.get_mat(o.x + u.x * su + v.x * sv, o.y + u.y * su + v.y * sv,
			o.z + u.z * su + v.z * sv) != 0 else 0
		var level := 0 if side1 + side2 == 2 else 3 - side1 - side2 - diag
		ao.append([0.42, 0.62, 0.82, 1.0][level])
		# Integer corner position, so shared corners get identical floats and weights.
		var ic := c + (n + u * su + v * sv + Vector3i.ONE) / 2
		var pos := grid.origin + Vector3(ic) * grid.cell
		# Cavity and exposure from the blurred occupancy just outside this
		# corner (smooth across faces, so steps don't flicker light/dark).
		var occupancy := _sample(grid, density, pos + nf * grid.cell * (blur_cells * 0.75 + 0.5))
		var near := _sample(grid, density, pos + nf * grid.cell * 0.9)
		var occlusion := clampf((occupancy - 0.18) / 0.45, 0.0, 1.0)
		var exposure := clampf((0.32 - near) / 0.25, 0.0, 1.0)
		sf.verts.append(pos)
		sf.normals.append(nf)
		sf.tangents.append_array([float(u.x), float(u.y), float(u.z), 1.0])
		sf.colors.append(color_fn.call(mat, centre, c, nf, occlusion, exposure))
		sf.uvs.append(Vector2(corner))
		var key := Vector4i(ic.x, ic.y, ic.z, tag)
		var w: Array = cache.get(key, [])
		if w.is_empty():
			w = weight_fn.call(tag, pos)
			cache[key] = w
		sf.bones.append_array(w[0])
		sf.weights.append_array(w[1])
	# Every corner carries the whole face's AO and edge flags (4 floats each).
	for i in 4:
		sf.custom0.append_array(ao)
		sf.custom1.append_array(edges)
	sf.indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])


## Occupancy (0..1) box-blurred over (2r+1)^3 cells, separably.
static func _blurred_occupancy(grid: VoxelGrid, r: int) -> PackedFloat32Array:
	var s := grid.size
	var field := PackedFloat32Array()
	field.resize(s.x * s.y * s.z)
	for i in field.size():
		field[i] = 1.0 if grid.mats[i] != 0 else 0.0
	var strides := [1, s.x, s.x * s.y]
	var dims := [s.x, s.y, s.z]
	for axis in 3:
		var out := PackedFloat32Array()
		out.resize(field.size())
		var stride: int = strides[axis]
		var length: int = dims[axis]
		for i in field.size():
			var coord := (i / stride) % length
			var sum := 0.0
			for k in range(-r, r + 1):
				var cc := coord + k
				if cc >= 0 and cc < length:
					sum += field[i + k * stride]
			out[i] = sum / (2 * r + 1)
		field = out
	return field


## Trilinear sample of a per-cell field at p (cell values sit at cell centres).
static func _sample(grid: VoxelGrid, field: PackedFloat32Array, p: Vector3) -> float:
	var f := (p - grid.origin) / grid.cell - Vector3(0.5, 0.5, 0.5)
	var base := Vector3i(f.floor())
	var t := f - Vector3(base)
	var s := grid.size
	var total := 0.0
	for dz in 2:
		for dy in 2:
			for dx in 2:
				var x := base.x + dx
				var y := base.y + dy
				var z := base.z + dz
				if x < 0 or y < 0 or z < 0 or x >= s.x or y >= s.y or z >= s.z:
					continue
				var w := (t.x if dx else 1.0 - t.x) * (t.y if dy else 1.0 - t.y) * (t.z if dz else 1.0 - t.z)
				total += field[x + s.x * (y + s.y * z)] * w
	return total
