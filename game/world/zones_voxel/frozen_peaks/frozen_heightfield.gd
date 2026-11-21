class_name FrozenHeightfield
extends VoxelHeightfield
## A heightfield whose smooth top is a world-aligned lattice of `lattice`-metre
## quads instead of the kit's cell quadtree: on the sim's 2 m bilinear
## heightmap, 1 m quads on the sample grid keep the visible floor within ~2 cm
## of the sim floor (the kit's 32-cell blocks suit gentle island domes, not a
## noisy valley). The look stays per cell: the terrain shader picks each
## pixel's cell from its world position, whatever the triangles are.

var lattice := 1.0
## Which lattice squares (by world centre) this field draws; all by default.
var owns: Callable


func _smooth_top(verts: PackedVector3Array, normals: PackedVector3Array, x0: int, z0: int, x1: int, z1: int) -> void:
	var wx0 := origin.x + x0 * cell
	var wz0 := origin.y + z0 * cell
	var wx1 := origin.x + x1 * cell
	var wz1 := origin.y + z1 * cell
	# Lattice squares whose centre lies in this chunk belong to it.
	for j in range(floori(wz0 / lattice - 0.5), ceili(wz1 / lattice)):
		var cz := (j + 0.5) * lattice
		if cz < wz0 or cz >= wz1:
			continue
		for i in range(floori(wx0 / lattice - 0.5), ceili(wx1 / lattice)):
			var cx := (i + 0.5) * lattice
			if cx < wx0 or cx >= wx1:
				continue
			if owns.is_valid() and not owns.call(Vector2(cx, cz)):
				continue
			var col := Vector2i(floori((cx - origin.x) / cell), floori((cz - origin.y) / cell))
			if level_at(col.x, col.y) == NONE:
				continue
			var corners: Array[Vector3] = []
			for c: Vector2 in [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]:
				var w := c * lattice
				corners.append(Vector3(w.x, smooth_height.call(w.x, w.y), w.y))
			var n := (corners[2] - corners[0]).cross(corners[1] - corners[3]).normalized()
			if n.y < 0.0:
				n = -n
			_quad(verts, normals, corners[0], corners[1], corners[2], corners[3], n)
