extends RefCounted
## The voxel_grid.gd of the approved voxel kit (lookdev-heartbloom-v1, 3246c72), kept
## verbatim as the reference the optimised kit must match bit for bit.
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
	for z in range(lo.z, hi.z + 1):
		for y in range(lo.y, hi.y + 1):
			var row := size.x * (y + size.y * z)
			for x in range(lo.x, hi.x + 1):
				var i := x + row
				var current := mats[i]
				if mode == Mode.ADD and current != 0:
					continue
				if (mode == Mode.PAINT or mode == Mode.CARVE) and current == 0:
					continue
				if mode == Mode.PAINT and tag >= 0 and tags[i] != tag:
					continue
				if sdf.call(origin + (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * cell) > 0.0:
					continue
				if mode == Mode.CARVE:
					mats[i] = 0
				else:
					mats[i] = mat
					if tag >= 0 and mode != Mode.PAINT:
						tags[i] = tag


## Recolours the filled cells on the outer surface (a face open to air) that
## pass the test (and, if only is non-empty, hold one of those materials);
## used for trims, stitches and decals.
func paint_surface(bounds: AABB, test: Callable, mat: int, only: Array = []) -> void:
	var lo := Vector3i(((bounds.position - origin) / cell).floor()).clamp(Vector3i.ZERO, size - Vector3i.ONE)
	var hi := Vector3i(((bounds.end - origin) / cell).ceil()).clamp(Vector3i.ZERO, size - Vector3i.ONE)
	for z in range(lo.z, hi.z + 1):
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var i := index(x, y, z)
				if mats[i] == 0 or (not only.is_empty() and not mats[i] in only) or not is_surface(x, y, z):
					continue
				if test.call(center(x, y, z), Vector3i(x, y, z)):
					mats[i] = mat


func is_surface(x: int, y: int, z: int) -> bool:
	return get_mat(x + 1, y, z) == 0 or get_mat(x - 1, y, z) == 0 or get_mat(x, y + 1, z) == 0 \
		or get_mat(x, y - 1, z) == 0 or get_mat(x, y, z + 1) == 0 or get_mat(x, y, z - 1) == 0


## Cleans single-voxel noise on soft materials: removes cells of those
## materials with 5+ open sides (lone bumps) and fills empty cells with 5+
## filled sides (pits), taking a neighbour's material and tag.
func smooth(soft: Array) -> void:
	var remove := PackedInt32Array()
	var fill := {}
	for z in size.z:
		for y in size.y:
			for x in size.x:
				var i := index(x, y, z)
				var filled := 0
				var neighbour := -1
				for d: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
						Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
					var m := get_mat(x + d.x, y + d.y, z + d.z)
					if m != 0:
						filled += 1
						if m in soft:
							neighbour = index(x + d.x, y + d.y, z + d.z)
				if mats[i] != 0:
					if filled <= 1 and mats[i] in soft:
						remove.append(i)
				elif filled >= 5 and neighbour >= 0:
					fill[i] = neighbour
	for i in remove:
		mats[i] = 0
	for i: int in fill:
		mats[i] = mats[fill[i]]
		tags[i] = tags[fill[i]]
