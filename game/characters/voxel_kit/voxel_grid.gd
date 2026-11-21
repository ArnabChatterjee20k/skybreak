class_name VoxelGrid
extends RefCounted
## A dense voxel volume: one material id (0 = empty) and one rig tag per cell.
## Parts are painted in with signed-distance functions (only the sign is used:
## a cell is inside when the function at its centre is <= 0).

enum Mode { FILL, ADD, CARVE, PAINT }

var cell: float
var origin: Vector3
var size: Vector3i
var mats := PackedByteArray()
var tags := PackedByteArray()


func _init(bounds: AABB, cell_size: float) -> void:
	cell = cell_size
	origin = bounds.position
	size = Vector3i((bounds.size / cell).ceil())
	mats.resize(size.x * size.y * size.z)
	tags.resize(size.x * size.y * size.z)


func index(x: int, y: int, z: int) -> int:
	return x + size.x * (y + size.y * z)


func get_mat(x: int, y: int, z: int) -> int:
	if x < 0 or y < 0 or z < 0 or x >= size.x or y >= size.y or z >= size.z:
		return 0
	return mats[x + size.x * (y + size.y * z)]


func center(x: int, y: int, z: int) -> Vector3:
	return origin + (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * cell


func cell_of(p: Vector3) -> Vector3i:
	return Vector3i(((p - origin) / cell).floor())


## Paints mat/tag into cells inside sdf within bounds. FILL overwrites, ADD only
## fills empty cells, CARVE empties, PAINT recolours filled cells (only those
## of that tag when tag >= 0; PAINT never changes tags).
func paint(bounds: AABB, sdf: Callable, mat: int, tag := -1, mode := Mode.FILL) -> void:
	var lo := Vector3i(((bounds.position - origin) / cell).floor()).clamp(Vector3i.ZERO, size - Vector3i.ONE)
	var hi := Vector3i(((bounds.end - origin) / cell).ceil()).clamp(Vector3i.ZERO, size - Vector3i.ONE)
	var xs := _centres(0, lo.x, hi.x)
	var ys := _centres(1, lo.y, hi.y)
	var zs := _centres(2, lo.z, hi.z)
	var needs_empty := mode == Mode.ADD
	var needs_filled := mode == Mode.PAINT or mode == Mode.CARVE
	var needs_tag := mode == Mode.PAINT and tag >= 0
	var carve := mode == Mode.CARVE
	var retag := tag >= 0 and mode != Mode.PAINT
	for z in range(lo.z, hi.z + 1):
		var pz := zs[z - lo.z]
		for y in range(lo.y, hi.y + 1):
			var py := ys[y - lo.y]
			var row := size.x * (y + size.y * z)
			for x in range(lo.x, hi.x + 1):
				var i := x + row
				var current := mats[i]
				if needs_empty and current != 0:
					continue
				if needs_filled and current == 0:
					continue
				if needs_tag and tags[i] != tag:
					continue
				if sdf.call(Vector3(xs[x - lo.x], py, pz)) > 0.0:
					continue
				if carve:
					mats[i] = 0
				else:
					mats[i] = mat
					if retag:
						tags[i] = tag


## One axis of center() for cells lo..hi: the same float32 vector arithmetic,
## so Vector3(xs[x], ys[y], zs[z]) equals center(x, y, z) bit for bit.
func _centres(axis: int, lo: int, hi: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in range(lo, hi + 1):
		var v := Vector3.ZERO
		v[axis] = k
		out.append((origin + (v + Vector3(0.5, 0.5, 0.5)) * cell)[axis])
	return out


## Recolours the filled cells on the outer surface (a face open to air) that
## pass the test (and, if only is non-empty, hold one of those materials);
## used for trims, stitches and decals.
func paint_surface(bounds: AABB, test: Callable, mat: int, only: Array = []) -> void:
	var lo := Vector3i(((bounds.position - origin) / cell).floor()).clamp(Vector3i.ZERO, size - Vector3i.ONE)
	var hi := Vector3i(((bounds.end - origin) / cell).ceil()).clamp(Vector3i.ZERO, size - Vector3i.ONE)
	var allowed := _material_set(only)
	var any := only.is_empty()
	for z in range(lo.z, hi.z + 1):
		for y in range(lo.y, hi.y + 1):
			var row := size.x * (y + size.y * z)
			for x in range(lo.x, hi.x + 1):
				var m := mats[x + row]
				if m == 0 or (not any and allowed[m] == 0) or not is_surface(x, y, z):
					continue
				if test.call(center(x, y, z), Vector3i(x, y, z)):
					mats[x + row] = mat


## 256 flags, 1 for each material id in list.
static func _material_set(list: Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(256)
	for m in list:
		if m is int and m >= 0 and m < 256:
			out[m] = 1
	return out


func is_surface(x: int, y: int, z: int) -> bool:
	return get_mat(x + 1, y, z) == 0 or get_mat(x - 1, y, z) == 0 or get_mat(x, y + 1, z) == 0 \
		or get_mat(x, y - 1, z) == 0 or get_mat(x, y, z + 1) == 0 or get_mat(x, y, z - 1) == 0


## Cleans single-voxel noise on soft materials: removes cells of those
## materials with 5+ open sides (lone bumps) and fills empty cells with 5+
## filled sides (pits), taking a neighbour's material and tag.
func smooth(soft: Array) -> void:
	var is_soft := _material_set(soft)
	# A padded copy (one empty cell each side) so neighbours need no bounds checks.
	var px := size.x + 2
	var py := size.y + 2
	var pxy := px * py
	var pm := PackedByteArray()
	pm.resize(pxy * (size.z + 2))
	var row_filled := PackedByteArray()
	row_filled.resize(py * (size.z + 2))
	for z in size.z:
		for y in size.y:
			var src := size.x * (y + size.y * z)
			var dst := 1 + px * (y + 1) + pxy * (z + 1)
			for x in size.x:
				var m := mats[src + x]
				if m != 0:
					pm[dst + x] = m
					row_filled[(y + 1) + py * (z + 1)] = 1
	# Neighbour order +x, -x, +y, -y, +z, -z; the last soft one is the donor.
	var padded_dirs := PackedInt32Array([1, -1, px, -px, pxy, -pxy])
	var dirs := PackedInt32Array([1, -1, size.x, -size.x, size.x * size.y, -size.x * size.y])
	var remove := PackedInt32Array()
	var fill_at := PackedInt32Array()
	var fill_from := PackedInt32Array()
	for z in size.z:
		for y in size.y:
			# An empty row's cells have at most 4 filled sides: nothing to do.
			if row_filled[(y + 1) + py * (z + 1)] == 0:
				continue
			var row := size.x * (y + size.y * z)
			var prow := 1 + px * (y + 1) + pxy * (z + 1)
			for x in size.x:
				var pi := prow + x
				var own := pm[pi]
				if own != 0 and is_soft[own] == 0:
					continue
				var filled := 0
				var neighbour := -1
				for d in 6:
					var m := pm[pi + padded_dirs[d]]
					if m != 0:
						filled += 1
						if is_soft[m] != 0:
							neighbour = x + row + dirs[d]
				if own != 0:
					if filled <= 1:
						remove.append(x + row)
				elif filled >= 5 and neighbour >= 0:
					fill_at.append(x + row)
					fill_from.append(neighbour)
	for i in remove:
		mats[i] = 0
	for k in fill_at.size():
		mats[fill_at[k]] = mats[fill_from[k]]
		tags[fill_at[k]] = tags[fill_from[k]]
