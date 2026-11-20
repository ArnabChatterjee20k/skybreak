class_name FrozenHeightfield
extends VoxelHeightfield
## A heightfield whose smooth top uses quads no wider than `max_block_metres`,
## so a wide valley floor follows the 2 m sim heightmap within ~2 cm (the kit's
## 32-cell blocks are tuned for gentle island domes).

var max_block_metres := 1.41
var _blocks: Array[int] = []


func _smooth_top(verts: PackedVector3Array, normals: PackedVector3Array, x0: int, z0: int, x1: int, z1: int) -> void:
	if _blocks.is_empty():
		var b := maxi(1, floori(max_block_metres / cell))
		while b > 1:
			_blocks.append(b)
			b = maxi(1, b / 4)
		_blocks.append(1)
	_fine_block(verts, normals, x0, z0, x1, z1, 0)


func _fine_block(verts: PackedVector3Array, normals: PackedVector3Array, x0: int, z0: int, x1: int, z1: int,
		level: int) -> void:
	var st := _blocks[level]
	for bz in range(z0, z1, st):
		for bx in range(x0, x1, st):
			var ex := mini(bx + st, x1)
			var ez := mini(bz + st, z1)
			var full := true
			var any := false
			for z in range(bz, ez):
				for x in range(bx, ex):
					if shown[index(x, z)] == NONE:
						full = false
					else:
						any = true
			if not any:
				continue
			if full:
				_smooth_quad(verts, normals, bx, bz, ex, ez)
			elif level + 1 < _blocks.size():
				_fine_block(verts, normals, bx, bz, ex, ez, level + 1)
