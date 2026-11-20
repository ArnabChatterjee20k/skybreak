class_name VoxelHeightfield
extends RefCounted
## Island-scale voxel terrain as columns of cells on a square grid: each column
## spans [hidden, shown] in whole cells. Meshed per 32x32-column chunk with
## coplanar faces merged into strips (a lawn of millions of cells stays a few
## hundred thousand quads), while the per-cell look survives in textures the
## voxel terrain shader reads cell by cell:
## - colour_texture: the column's colour (sRGB) with baked AO and painted
##   detail (paths, petals, clover); alpha is a material code for the shader;
## - level_texture: the column's shown level in cells, so the shader can find
##   each face's neighbours for the bevel highlight and the step AO.
## `down` builds an underside: bottoms show, steps face downward.

const CHUNK := 32
const NONE := -2147483648

var cell := 0.088
var origin := Vector2.ZERO  # world (x, z) of column (0, 0)'s corner
var size := Vector2i.ZERO
var down := false
var shown := PackedInt32Array()  # per column, in cells; NONE = no column
var hidden := PackedInt32Array()
var colours := PackedByteArray()  # RGBA8 per column
## Smooth top (a lawn): when set, height(x, z) -> world y gives the shown
## surface exactly (no contour steps; feet stay on it), meshed as a grid of
## 4x4-cell quads; walls only at the rim. The per-cell look stays in the shader.
var smooth_height: Callable
const SMOOTH_STEP := 4


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


func index(x: int, z: int) -> int:
	return x + size.x * z


func centre(x: int, z: int) -> Vector2:
	return origin + (Vector2(x, z) + Vector2(0.5, 0.5)) * cell


func set_column(x: int, z: int, shown_level: int, hidden_level: int, colour: Color) -> void:
	var i := index(x, z)
	shown[i] = shown_level
	hidden[i] = hidden_level
	colours[i * 4] = int(clampf(colour.r, 0.0, 1.0) * 255.0)
	colours[i * 4 + 1] = int(clampf(colour.g, 0.0, 1.0) * 255.0)
	colours[i * 4 + 2] = int(clampf(colour.b, 0.0, 1.0) * 255.0)
	colours[i * 4 + 3] = int(clampf(colour.a, 0.0, 1.0) * 255.0)


func level_at(x: int, z: int) -> int:
	if x < 0 or z < 0 or x >= size.x or z >= size.y:
		return NONE
	return shown[index(x, z)]


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


## Shader parameters that tie a material to this field.
func bind(material: ShaderMaterial) -> void:
	material.set_shader_parameter("cell", cell)
	material.set_shader_parameter("field_origin", origin)
	material.set_shader_parameter("field_size", size)
	material.set_shader_parameter("colour_tex", colour_texture())
	material.set_shader_parameter("level_tex", level_texture())
	material.set_shader_parameter("down", down)
	material.set_shader_parameter("smooth_top", smooth_height.is_valid())


## One MeshInstance3D per non-empty chunk, all sharing `material`.
func build(parent: Node3D, material: Material, node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	for cz in ceili(float(size.y) / CHUNK):
		for cx in ceili(float(size.x) / CHUNK):
			var mesh := _chunk(cx * CHUNK, cz * CHUNK)
			if mesh == null:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = material
			root.add_child(mi)
	return root


## Quad count of the whole field (for the perf notes).
static func count_quads(root: Node3D) -> int:
	var total := 0
	for mi: MeshInstance3D in root.get_children():
		total += mi.mesh.surface_get_array_len(0) / 6
	return total


func _chunk(x0: int, z0: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var x1 := mini(x0 + CHUNK, size.x)
	var z1 := mini(z0 + CHUNK, size.y)
	var up := Vector3(0, -1 if down else 1, 0)
	if smooth_height.is_valid() and not down:
		_smooth_top(verts, normals, x0, z0, x1, z1)
	# Shown faces: runs of equal level along x.
	var rows: Array = [] if smooth_height.is_valid() and not down else range(z0, z1)
	for z: int in rows:
		var x := x0
		while x < x1:
			var lv := shown[index(x, z)]
			if lv == NONE:
				x += 1
				continue
			var end := x + 1
			while end < x1 and shown[index(end, z)] == lv:
				end += 1
			var y := lv * cell
			var ax := origin.x + x * cell
			var bx := origin.x + end * cell
			var az := origin.y + z * cell
			var bz := origin.y + (z + 1) * cell
			_quad(verts, normals, Vector3(ax, y, az), Vector3(bx, y, az), Vector3(bx, y, bz), Vector3(ax, y, bz), up)
			x = end
	# Step walls, merged along the wall where neighbouring columns' spans match:
	# x-facing walls run along z, z-facing walls along x.
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
	if verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


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


## The smooth top of a chunk: SMOOTH_STEP-cell quads where all their columns
## exist, single-cell quads along the rim.
func _smooth_top(verts: PackedVector3Array, normals: PackedVector3Array, x0: int, z0: int, x1: int, z1: int) -> void:
	var st := SMOOTH_STEP
	for bz in range(z0, z1, st):
		for bx in range(x0, x1, st):
			var ex := mini(bx + st, x1)
			var ez := mini(bz + st, z1)
			var full := true
			for z in range(bz, ez):
				for x in range(bx, ex):
					if shown[index(x, z)] == NONE:
						full = false
						break
				if not full:
					break
			if full:
				_smooth_quad(verts, normals, bx, bz, ex, ez)
				continue
			for z in range(bz, ez):
				for x in range(bx, ex):
					if shown[index(x, z)] != NONE:
						_smooth_quad(verts, normals, x, z, x + 1, z + 1)


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
