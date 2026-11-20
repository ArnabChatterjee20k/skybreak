class_name VoxelMesher
extends RefCounted
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
## surface_of(mat) -> int index into materials (asked once per material)
static func build(grid: VoxelGrid, color_fn: Callable, surface_of: Callable, weight_fn: Callable,
		materials: Array[Material], blur_cells := 2) -> ArrayMesh:
	# Both fields are zero-padded, so the hot loops never bounds-check: pad
	# covers the farthest cavity sample (blur_cells * 0.75 + 0.5 cells out).
	var pad := ceili(blur_cells * 0.75 + 0.5) + 2
	var s := grid.size
	var px := s.x + 2 * pad
	var pxy := px * (s.y + 2 * pad)
	var solid := _padded_mats(grid, pad)
	var density := _blurred_occupancy(grid, blur_cells, pad)
	var surfaces: Array[Surface] = []
	for m in materials:
		surfaces.append(Surface.new())
	var surface_of_mat := PackedInt32Array()
	surface_of_mat.resize(256)
	surface_of_mat.fill(-1)
	var face := FaceContext.new()
	face.grid = grid
	face.solid = solid
	face.density = density
	face.px = px
	face.pxy = pxy
	face.pad = pad
	face.color_fn = color_fn
	face.weight_fn = weight_fn
	face.setup(blur_cells)
	var dir_offset := PackedInt32Array()
	for d in 6:
		dir_offset.append(DIRS[d].x + DIRS[d].y * px + DIRS[d].z * pxy)
	for z in s.z:
		for y in s.y:
			var row := s.x * (y + s.y * z)
			var prow := pad + px * (y + pad) + pxy * (z + pad)
			for x in s.x:
				var mat := grid.mats[x + row]
				if mat == 0:
					continue
				var pi := prow + x
				var surface_index := surface_of_mat[mat]
				if surface_index < 0:
					surface_index = surface_of.call(mat)
					surface_of_mat[mat] = surface_index
				var surface: Surface = null
				var c := Vector3i(x, y, z)
				var centre := Vector3.ZERO
				var tag := 0
				for d in 6:
					if solid[pi + dir_offset[d]] != 0:
						continue
					if surface == null:
						surface = surfaces[surface_index]
						centre = grid.center(x, y, z)
						tag = grid.tags[x + row]
					face.add(surface, c, pi, centre, d, mat, tag)
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


## Per-grid state and per-direction tables for emitting faces.
class FaceContext:
	const AO_LEVELS: Array[float] = [0.42, 0.62, 0.82, 1.0]
	var grid: VoxelGrid
	var solid: PackedByteArray
	var density: PackedFloat32Array
	var px: int
	var pxy: int
	var pad: int
	var color_fn: Callable
	var weight_fn: Callable
	var weight_cache := {}
	## Per direction: padded offsets of n, u, v; the normal; its tangent; the
	## two cavity sample offsets; per corner (d * 4 + k): the integer corner offset.
	var off_n := PackedInt32Array()
	var off_u := PackedInt32Array()
	var off_v := PackedInt32Array()
	var normals := PackedVector3Array()
	var tangents: Array[PackedFloat32Array] = []
	var far_offsets := PackedVector3Array()
	var near_offsets := PackedVector3Array()
	var corner_offsets: Array[Vector3i] = []
	var key_x := 0
	var key_xy := 0
	var key_xyz := 0
	## Occlusion and exposure per (corner, direction): index into light.
	var light_cache := {}
	var light := PackedFloat64Array()
	## A face's CUSTOM0 (4 corner AO levels, 2 bits each) and CUSTOM1 (4 edge
	## bits) rows, repeated for its 4 vertices.
	var ao_rows: Array[PackedFloat32Array] = []
	var edge_rows: Array[PackedFloat32Array] = []

	func setup(blur_cells: int) -> void:
		for d in 6:
			var n := DIRS[d]
			var u := U_AXES[d]
			var v := Vector3i(Vector3(n).cross(Vector3(u)).round())
			var nf := Vector3(n)
			off_n.append(n.x + n.y * px + n.z * pxy)
			off_u.append(u.x + u.y * px + u.z * pxy)
			off_v.append(v.x + v.y * px + v.z * pxy)
			normals.append(nf)
			tangents.append(PackedFloat32Array([float(u.x), float(u.y), float(u.z), 1.0]))
			far_offsets.append(nf * grid.cell * (blur_cells * 0.75 + 0.5))
			near_offsets.append(nf * grid.cell * 0.9)
			for corner in CORNERS:
				var su := corner.x * 2 - 1
				var sv := corner.y * 2 - 1
				corner_offsets.append((n + u * su + v * sv + Vector3i.ONE) / 2)
		for key in 256:
			var row := PackedFloat32Array()
			for i in 4:
				for k in 4:
					row.append(AO_LEVELS[(key >> (k * 2)) & 3])
			ao_rows.append(row)
		for mask in 16:
			var row := PackedFloat32Array()
			for i in 4:
				for k in 4:
					row.append(1.0 if mask & (1 << k) else 0.0)
			edge_rows.append(row)
		key_x = grid.size.x + 1
		key_xy = key_x * (grid.size.y + 1)
		key_xyz = key_xy * (grid.size.z + 1)

	## One open face of cell c (padded index pi) toward DIRS[d].
	func add(sf: Surface, c: Vector3i, pi: int, centre: Vector3, d: int, mat: int, tag: int) -> void:
		var ou := off_u[d]
		var ov := off_v[d]
		var nf := normals[d]
		# Convex edges: the neighbour across that edge is empty (u-, u+, v-, v+).
		var edge_mask := (1 if solid[pi - ou] == 0 else 0) | (2 if solid[pi + ou] == 0 else 0) \
			| (4 if solid[pi - ov] == 0 else 0) | (8 if solid[pi + ov] == 0 else 0)
		var ao_key := 0
		var base := sf.verts.size()
		var o := pi + off_n[d]
		var far := far_offsets[d]
		var near_off := near_offsets[d]
		var tangent := tangents[d]
		for k in 4:
			var su := -ou if k == 0 or k == 3 else ou
			var sv := -ov if k < 2 else ov
			var side1 := 1 if solid[o + su] != 0 else 0
			var side2 := 1 if solid[o + sv] != 0 else 0
			var diag := 1 if solid[o + su + sv] != 0 else 0
			var level := 0 if side1 + side2 == 2 else 3 - side1 - side2 - diag
			ao_key |= level << (k * 2)
			# Integer corner position, so shared corners get identical floats and weights.
			var ic := c + corner_offsets[d * 4 + k]
			var pos := grid.origin + Vector3(ic) * grid.cell
			# Cavity and exposure from the blurred occupancy just outside this
			# corner (smooth across faces, so steps don't flicker light/dark).
			# Coplanar faces share corners, so cache per (corner, direction).
			var light_key := (ic.x + ic.y * key_x + ic.z * key_xy) * 6 + d
			var slot: int = light_cache.get(light_key, -1)
			var occlusion: float
			var exposure: float
			if slot < 0:
				var occupancy := _sample(pos + far)
				var near := _sample(pos + near_off)
				occlusion = clampf((occupancy - 0.18) / 0.45, 0.0, 1.0)
				exposure = clampf((0.32 - near) / 0.25, 0.0, 1.0)
				light_cache[light_key] = light.size()
				light.append(occlusion)
				light.append(exposure)
			else:
				occlusion = light[slot]
				exposure = light[slot + 1]
			sf.verts.append(pos)
			sf.normals.append(nf)
			sf.tangents.append_array(tangent)
			sf.colors.append(color_fn.call(mat, centre, c, nf, occlusion, exposure))
			sf.uvs.append(Vector2(CORNERS[k]))
			var key := ic.x + ic.y * key_x + ic.z * key_xy + tag * key_xyz
			var w: Array = weight_cache.get(key, [])
			if w.is_empty():
				w = weight_fn.call(tag, pos)
				weight_cache[key] = w
			sf.bones.append_array(w[0])
			sf.weights.append_array(w[1])
		# Every corner carries the whole face's AO and edge flags (4 floats each).
		sf.custom0.append_array(ao_rows[ao_key])
		sf.custom1.append_array(edge_rows[edge_mask])
		sf.indices.append(base)
		sf.indices.append(base + 2)
		sf.indices.append(base + 1)
		sf.indices.append(base)
		sf.indices.append(base + 3)
		sf.indices.append(base + 2)

	## Trilinear sample of the padded density at p (cell values at cell centres).
	## Same arithmetic and summation order as an unpadded, bounds-checked
	## sample: the padding only adds exact zeros.
	func _sample(p: Vector3) -> float:
		var f := (p - grid.origin) / grid.cell - Vector3(0.5, 0.5, 0.5)
		var b := Vector3i(f.floor())
		var t := f - Vector3(b)
		var i := (b.x + pad) + px * (b.y + pad) + pxy * (b.z + pad)
		var x0 := 1.0 - t.x
		var y0 := 1.0 - t.y
		var z0 := 1.0 - t.z
		var total := 0.0
		total += density[i] * (x0 * y0 * z0)
		total += density[i + 1] * (t.x * y0 * z0)
		total += density[i + px] * (x0 * t.y * z0)
		total += density[i + px + 1] * (t.x * t.y * z0)
		total += density[i + pxy] * (x0 * y0 * t.z)
		total += density[i + pxy + 1] * (t.x * y0 * t.z)
		total += density[i + pxy + px] * (x0 * t.y * t.z)
		total += density[i + pxy + px + 1] * (t.x * t.y * t.z)
		return total


## The grid's materials, padded with `pad` empty cells on every side.
static func _padded_mats(grid: VoxelGrid, pad: int) -> PackedByteArray:
	var s := grid.size
	var px := s.x + 2 * pad
	var py := s.y + 2 * pad
	var out := PackedByteArray()
	out.resize(px * py * (s.z + 2 * pad))
	for z in s.z:
		for y in s.y:
			var src := s.x * (y + s.y * z)
			var dst := pad + px * (y + pad) + px * py * (z + pad)
			for x in s.x:
				out[dst + x] = grid.mats[src + x]
	return out


## Occupancy (0..1) box-blurred over (2r+1)^3 cells, separably, clipped at the
## grid edge, returned padded with `pad` zero cells. A sliding window per line:
## the double sums of these float32 values are exact, so the result matches
## summing each window from scratch bit for bit.
static func _blurred_occupancy(grid: VoxelGrid, r: int, pad: int) -> PackedFloat32Array:
	var s := grid.size
	var count := s.x * s.y * s.z
	var field := PackedFloat32Array()
	field.resize(count)
	for i in count:
		field[i] = 1.0 if grid.mats[i] != 0 else 0.0
	var denom := float(2 * r + 1)
	var out := PackedFloat32Array()
	out.resize(count)
	for axis in 3:
		var stride: int = [1, s.x, s.x * s.y][axis]
		var length: int = [s.x, s.y, s.z][axis]
		# The other two axes enumerate line starts.
		var a_stride: int = [s.x, 1, 1][axis]
		var a_count: int = [s.y, s.x, s.x][axis]
		var b_stride: int = [s.x * s.y, s.x * s.y, s.x][axis]
		var b_count: int = [s.z, s.z, s.y][axis]
		var first := mini(r, length - 1)
		for b in b_count:
			for a in a_count:
				var start := a * a_stride + b * b_stride
				var sum := 0.0
				for k in first + 1:
					sum += field[start + k * stride]
				for coord in length:
					out[start + coord * stride] = sum / denom
					if coord - r >= 0:
						sum -= field[start + (coord - r) * stride]
					if coord + r + 1 < length:
						sum += field[start + (coord + r + 1) * stride]
		var swap := field
		field = out
		out = swap
	var px := s.x + 2 * pad
	var py := s.y + 2 * pad
	var padded := PackedFloat32Array()
	padded.resize(px * py * (s.z + 2 * pad))
	for z in s.z:
		for y in s.y:
			var src := s.x * (y + s.y * z)
			var dst := pad + px * (y + pad) + px * py * (z + pad)
			for x in s.x:
				padded[dst + x] = field[src + x]
	return padded
