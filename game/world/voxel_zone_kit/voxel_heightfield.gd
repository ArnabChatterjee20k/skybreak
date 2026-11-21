class_name VoxelHeightfield
extends RefCounted
## Island-scale voxel terrain as columns of cells on a square grid: each column
## spans [hidden, shown] in whole cells. Meshed per ~32 m chunk with
## greedy 2D merging (coplanar shown faces become rectangles, walls become
## runs), while the per-cell look survives in two textures the voxel terrain
## shader reads cell by cell:
## - colour_texture: the column's colour (sRGB) with baked AO and painted
##   detail (paths, petals, clover); alpha is a free material code;
## - level_texture: the column's shown level in cells, so the shader can find
##   each face's neighbours for the bevel highlight and the step AO.
## `down` builds an underside: bottoms show, steps face downward.
## A smooth top (`smooth_height`) follows a height function exactly, meshed as
## a quadtree of quads (big where the whole block exists), walls only at the rim.

## Chunk side in world metres (at least MIN_CHUNK cells): one draw call and
## one frustum-cull test each. The build uses VoxelQuality's terrain_chunk.
const CHUNK_METRES := 32.0
const MIN_CHUNK := 32
const NONE := -2147483648
## Quadtree block sizes (cells) for a smooth top, biggest first.
const SMOOTH_BLOCKS: Array[int] = [32, 8, 2, 1]
## Side of an occluder box (m).
const OCCLUDER_BLOCK := 4.0

var cell := 0.088
var origin := Vector2.ZERO  # world (x, z) of column (0, 0)'s corner
var size := Vector2i.ZERO
var down := false
var shown := PackedInt32Array()  # per column, in cells; NONE = no column
var hidden := PackedInt32Array()
var colours := PackedByteArray()  # RGBA8 per column
## Columns per chunk side.
var chunk := MIN_CHUNK
## Smooth top: height(x, z) -> world y. The visible lawn equals it exactly, so
## feet placed with the same function stand on the mesh.
var smooth_height: Callable


func _init(cell_size: float, world_min: Vector2, world_max: Vector2, is_down := false) -> void:
	cell = cell_size
	down = is_down
	origin = (world_min / cell).floor() * cell
	size = Vector2i(((world_max - origin) / cell).ceil()) + Vector2i.ONE
	shown.resize(size.x * size.y)
	shown.fill(NONE)
	hidden.resize(size.x * size.y)
	hidden.fill(NONE)
	colours.resize(size.x * size.y * 4)
	chunk = maxi(MIN_CHUNK, ceili(float(VoxelQuality.value("terrain_chunk")) / cell))


func index(x: int, z: int) -> int:
	return x + size.x * z


## World (x, z) of a column's centre.
func centre(x: int, z: int) -> Vector2:
	return origin + (Vector2(x, z) + Vector2(0.5, 0.5)) * cell


func set_column(x: int, z: int, shown_level: int, hidden_level: int, colour: Color) -> void:
	var i := index(x, z)
	shown[i] = shown_level
	hidden[i] = hidden_level
	set_colour(x, z, colour)


func set_colour(x: int, z: int, colour: Color) -> void:
	var i := index(x, z) * 4
	colours[i] = int(clampf(colour.r, 0.0, 1.0) * 255.0)
	colours[i + 1] = int(clampf(colour.g, 0.0, 1.0) * 255.0)
	colours[i + 2] = int(clampf(colour.b, 0.0, 1.0) * 255.0)
	colours[i + 3] = int(clampf(colour.a, 0.0, 1.0) * 255.0)


func level_at(x: int, z: int) -> int:
	if x < 0 or z < 0 or x >= size.x or z >= size.y:
		return NONE
	return shown[index(x, z)]


## Bakes contact AO into the colours: a column darkens by up to `strength`
## for each neighbour within `radius` cells whose shown level is higher (lower,
## for an underside), so step feet and crevices read without SSAO.
func bake_step_ao(strength := 0.3, radius := 2) -> void:
	var sgn := -1 if down else 1
	var out := colours.duplicate()
	for z in size.y:
		for x in size.x:
			var lv := shown[index(x, z)]
			if lv == NONE:
				continue
			var occ := 0.0
			var total := 0.0
			for dz in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if dx == 0 and dz == 0:
						continue
					var w := 1.0 / float(absi(dx) + absi(dz))
					total += w
					var o := level_at(x + dx, z + dz)
					if o != NONE and (o - lv) * sgn > 0:
						occ += w * minf(float((o - lv) * sgn), 2.0) * 0.5
			var k := 1.0 - strength * clampf(occ / total * 2.0, 0.0, 1.0)
			var i := index(x, z) * 4
			for c in 3:
				out[i + c] = int(colours[i + c] * k)
	colours = out


func colour_texture() -> ImageTexture:
	return ImageTexture.create_from_image(Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, colours))


## Shown level per column as a float texture; a missing column reads as a far
## drop (or rise, for an underside), so its neighbours get an edge.
func level_texture() -> ImageTexture:
	var data := PackedFloat32Array()
	data.resize(size.x * size.y)
	var empty := 1.0e6 if down else -1.0e6
	for i in data.size():
		data[i] = float(shown[i]) if shown[i] != NONE else empty
	return ImageTexture.create_from_image(Image.create_from_data(size.x, size.y, false, Image.FORMAT_RF, data.to_byte_array()))


## Shader parameters that tie a terrain material to this field.
func bind(material: ShaderMaterial) -> void:
	material.set_shader_parameter("cell", cell)
	material.set_shader_parameter("field_origin", origin)
	material.set_shader_parameter("field_size", size)
	material.set_shader_parameter("colour_tex", colour_texture())
	material.set_shader_parameter("level_tex", level_texture())
	material.set_shader_parameter("down", down)
	material.set_shader_parameter("smooth_top", smooth_height.is_valid())


## One MeshInstance3D per non-empty chunk (frustum-culled separately), all
## sharing `material`. visibility_end > 0 hides chunks past that distance.
## cast_shadow false: a smooth lawn under a low sun self-shadows into contour
## bands (acne); let the underside and the props cast instead. occluders
## (opt-in): a conservative occluder per chunk (chunk_occluder) in a sibling node
## "<node_name>Occluders", so props and terrain hidden behind it skip the main
## pass (where the viewport culls occlusion).
func build(parent: Node3D, material: Material, node_name: String, visibility_end := 0.0,
		cast_shadow := true, occluders := false) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	var occ_root: Node3D = null  # a sibling, so root holds only the chunk meshes
	for cz in ceili(float(size.y) / chunk):
		for cx in ceili(float(size.x) / chunk):
			var mesh := chunk_mesh(cx * chunk, cz * chunk)
			if mesh == null:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = material
			if visibility_end > 0.0:
				mi.visibility_range_end = visibility_end
			if not cast_shadow:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
			if occluders:
				var occ := chunk_occluder(cx * chunk, cz * chunk)
				if occ != null:
					if occ_root == null:
						occ_root = Node3D.new()
						occ_root.name = node_name + "Occluders"
						parent.add_child(occ_root)
					var oi := OccluderInstance3D.new()
					oi.occluder = occ
					occ_root.add_child(oi)
	return root


## A conservative occluder for a chunk: one box per OCCLUDER_BLOCK of columns,
## spanning only what every column in the block fills (less a cell of slack
## at each end), with sides only where the neighbour box doesn't cover them.
## Null if the chunk has no solid block.
func chunk_occluder(x0: int, z0: int) -> ArrayOccluder3D:
	var b := maxi(2, roundi(OCCLUDER_BLOCK / cell))
	var x1 := mini(x0 + chunk, size.x)
	var z1 := mini(z0 + chunk, size.y)
	var nx := ceili(float(x1 - x0) / b)
	var nz := ceili(float(z1 - z0) / b)
	var spans: Array[Vector2] = []
	spans.resize(nx * nz)
	for bz in nz:
		for bx in nx:
			var lo := -INF
			var hi := INF
			for z in range(z0 + bz * b, mini(z0 + (bz + 1) * b, z1)):
				for x in range(x0 + bx * b, mini(x0 + (bx + 1) * b, x1)):
					var sv := shown[index(x, z)]
					var hv := hidden[index(x, z)]
					if sv == NONE or hv == NONE:
						lo = INF
						break
					lo = maxf(lo, float(mini(sv, hv)))
					hi = minf(hi, float(maxi(sv, hv)))
				if lo == INF:
					break
			spans[bx + bz * nx] = Vector2(lo + 1.0, hi - 1.0) * cell if lo != INF and hi - lo > 3.0 \
				else Vector2(INF, -INF)
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	for bz in nz:
		for bx in nx:
			var sp := spans[bx + bz * nx]
			if sp.x >= sp.y:
				continue
			var a := origin + Vector2(x0 + bx * b, z0 + bz * b) * cell
			var e := origin + Vector2(mini(x0 + (bx + 1) * b, x1), mini(z0 + (bz + 1) * b, z1)) * cell
			_occ_quad(verts, indices, Vector3(a.x, sp.y, a.y), Vector3(e.x, sp.y, a.y), Vector3(e.x, sp.y, e.y), Vector3(a.x, sp.y, e.y))
			_occ_quad(verts, indices, Vector3(a.x, sp.x, a.y), Vector3(e.x, sp.x, a.y), Vector3(e.x, sp.x, e.y), Vector3(a.x, sp.x, e.y))
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ox := bx + d.x
				var oz := bz + d.y
				if ox >= 0 and oz >= 0 and ox < nx and oz < nz:
					var o := spans[ox + oz * nx]
					if o.x <= sp.x and o.y >= sp.y:
						continue
				var p := Vector2(e.x if d.x > 0 else a.x, e.y if d.y > 0 else a.y)
				if d.y == 0:
					_occ_quad(verts, indices, Vector3(p.x, sp.x, a.y), Vector3(p.x, sp.x, e.y), Vector3(p.x, sp.y, e.y), Vector3(p.x, sp.y, a.y))
				else:
					_occ_quad(verts, indices, Vector3(a.x, sp.x, p.y), Vector3(e.x, sp.x, p.y), Vector3(e.x, sp.y, p.y), Vector3(a.x, sp.y, p.y))
	if verts.is_empty():
		return null
	var occ := ArrayOccluder3D.new()
	occ.set_arrays(verts, indices)
	return occ


static func _occ_quad(verts: PackedVector3Array, indices: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3) -> void:
	var i := verts.size()
	verts.append_array([a, b, c, d])
	indices.append_array([i, i + 1, i + 2, i, i + 2, i + 3])


## Quad count under a node built by build().
static func count_quads(root: Node3D) -> int:
	var total := 0
	for mi: MeshInstance3D in root.get_children():
		total += mi.mesh.surface_get_array_len(0) / 6
	return total


## The mesh of the chunk whose first column is (x0, z0), or null if empty.
func chunk_mesh(x0: int, z0: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var x1 := mini(x0 + chunk, size.x)
	var z1 := mini(z0 + chunk, size.y)
	if smooth_height.is_valid() and not down:
		_smooth_top(verts, normals, x0, z0, x1, z1)
	else:
		_greedy_top(verts, normals, x0, z0, x1, z1)
	_walls(verts, normals, x0, z0, x1, z1)
	if verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Shown faces of a stepped field: greedy rectangles of equal level.
func _greedy_top(verts: PackedVector3Array, normals: PackedVector3Array, x0: int, z0: int, x1: int, z1: int) -> void:
	var up := Vector3(0, -1 if down else 1, 0)
	var w := x1 - x0
	var used := PackedByteArray()
	used.resize(w * (z1 - z0))
	for z in range(z0, z1):
		var x := x0
		while x < x1:
			var lv := shown[index(x, z)]
			if lv == NONE or used[(x - x0) + (z - z0) * w] != 0:
				x += 1
				continue
			var end := x + 1
			while end < x1 and shown[index(end, z)] == lv and used[(end - x0) + (z - z0) * w] == 0:
				end += 1
			var zend := z + 1
			while zend < z1:
				var ok := true
				for xx in range(x, end):
					if shown[index(xx, zend)] != lv or used[(xx - x0) + (zend - z0) * w] != 0:
						ok = false
						break
				if not ok:
					break
				zend += 1
			for zz in range(z, zend):
				for xx in range(x, end):
					used[(xx - x0) + (zz - z0) * w] = 1
			var y := lv * cell
			var ax := origin.x + x * cell
			var bx := origin.x + end * cell
			var az := origin.y + z * cell
			var bz := origin.y + zend * cell
			_quad(verts, normals, Vector3(ax, y, az), Vector3(bx, y, az), Vector3(bx, y, bz), Vector3(ax, y, bz), up)
			x = end


## Step walls, merged along the wall where neighbouring columns' spans match:
## x-facing walls run along z, z-facing walls along x.
func _walls(verts: PackedVector3Array, normals: PackedVector3Array, x0: int, z0: int, x1: int, z1: int) -> void:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var x_facing := d.y == 0
		var line_range := range(x0, x1) if x_facing else range(z0, z1)
		var k_lo := z0 if x_facing else x0
		var k_hi := z1 if x_facing else x1
		for line: int in line_range:
			var run_start := -1
			var run_span := Vector2i(NONE, NONE)
			for k in range(k_lo, k_hi + 1):
				var span := Vector2i(NONE, NONE)
				if k < k_hi:
					span = _wall_span(line, k, d) if x_facing else _wall_span(k, line, d)
				if run_start >= 0 and span != run_span:
					_wall(verts, normals, run_start, k, line, d, run_span)
					run_start = -1
				if run_start < 0 and span.x != NONE:
					run_start = k
					run_span = span


## The wall on column (x, z)'s side facing d, as (from, to) levels, or NONE:
## from the neighbour's shown level (or our hidden end if it's lower, or if
## there is no neighbour) to ours.
func _wall_span(x: int, z: int, d: Vector2i) -> Vector2i:
	var lv := shown[index(x, z)]
	if lv == NONE:
		return Vector2i(NONE, NONE)
	var other := level_at(x + d.x, z + d.y)
	var hid := hidden[index(x, z)]
	if smooth_height.is_valid() and not down and other != NONE:
		return Vector2i(NONE, NONE)  # a smooth top has walls only at its rim
	if not down:
		var lo := hid if other == NONE else maxi(other, hid)
		return Vector2i(lo, lv) if lo < lv else Vector2i(NONE, NONE)
	var hi := hid if other == NONE else mini(other, hid)
	return Vector2i(lv, hi) if hi > lv else Vector2i(NONE, NONE)


func _wall(verts: PackedVector3Array, normals: PackedVector3Array, k0: int, k1: int, line: int, d: Vector2i,
		span: Vector2i) -> void:
	var y0 := span.x * cell
	var y1 := span.y * cell
	var n := Vector3(d.x, 0, d.y)
	if d.y == 0:
		var fx := origin.x + (line + (1 if d.x > 0 else 0)) * cell
		var za := origin.y + k0 * cell
		var zb := origin.y + k1 * cell
		_quad(verts, normals, Vector3(fx, y0, za), Vector3(fx, y0, zb), Vector3(fx, y1, zb), Vector3(fx, y1, za), n)
	else:
		var fz := origin.y + (line + (1 if d.y > 0 else 0)) * cell
		var xa := origin.x + k0 * cell
		var xb := origin.x + k1 * cell
		_quad(verts, normals, Vector3(xa, y0, fz), Vector3(xb, y0, fz), Vector3(xb, y1, fz), Vector3(xa, y1, fz), n)


## The smooth top of a chunk: a quadtree of quads, each block as big as
## SMOOTH_BLOCKS allows while all its columns exist (the T-junction gap on a
## gentle dome stays under a millimetre).
func _smooth_top(verts: PackedVector3Array, normals: PackedVector3Array, x0: int, z0: int, x1: int, z1: int) -> void:
	_smooth_block(verts, normals, x0, z0, x1, z1, 0)


func _smooth_block(verts: PackedVector3Array, normals: PackedVector3Array, x0: int, z0: int, x1: int, z1: int,
		level: int) -> void:
	var st := SMOOTH_BLOCKS[level]
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
			elif level + 1 < SMOOTH_BLOCKS.size():
				_smooth_block(verts, normals, bx, bz, ex, ez, level + 1)


func _smooth_quad(verts: PackedVector3Array, normals: PackedVector3Array, xa: int, za: int, xb: int, zb: int) -> void:
	var corners: Array[Vector3] = []
	for c: Vector2i in [Vector2i(xa, za), Vector2i(xb, za), Vector2i(xb, zb), Vector2i(xa, zb)]:
		var w := origin + Vector2(c) * cell
		corners.append(Vector3(w.x, smooth_height.call(w.x, w.y), w.y))
	var n := (corners[2] - corners[0]).cross(corners[1] - corners[3]).normalized()
	if n.y < 0.0:
		n = -n
	_quad(verts, normals, corners[0], corners[1], corners[2], corners[3], n)


## Two triangles, wound so the front face looks along n.
static func _quad(verts: PackedVector3Array, normals: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, n: Vector3) -> void:
	# Godot's front face: -(b - a) x (c - a) points out.
	if (b - a).cross(c - a).dot(n) > 0.0:
		verts.append_array([a, c, b, a, d, c])
	else:
		verts.append_array([a, b, c, a, c, d])
	for i in 6:
		normals.append(n)
