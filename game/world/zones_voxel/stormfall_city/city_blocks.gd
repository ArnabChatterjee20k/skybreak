class_name CityBlocks
extends RefCounted
## Stormfall City's block mesher: a list of boxes (each with its own transform,
## colour, material code and voxel cell) merged into one mesh. Everything in the
## city is rectilinear, so a box is already the greedy-merged shape of its cells
## (12 triangles however many cells it covers); the cell look (per-cell colour
## noise, bevelled edges, windows snapped to cells) comes from city_block.gdshader,
## which reads each face's local metres from UV2 and its size and cell from CUSTOM0.

## Material codes (COLOR.a * 255), read by city_block.gdshader.
enum Code {
	CONCRETE, FACADE, BRICK, STONE, STEEL, RUST, NEON, NEON_WHITE, WARM_GLOW, BACKING,
	GLASS, SODIUM, WOOD, CLOTH, PLANT, WATER, BEACON, STROBE, ROAD, SHUTTER, PAINT, RUBBER, SHOP,
}

## Face masks.
const NO_BOTTOM := 0b111110
const ALL := 0b111111

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _uv := PackedVector2Array()
var _uv2 := PackedVector2Array()
var _custom := PackedFloat32Array()
## Height of the building base (m): UV.y on facades is the height above it.
var base_y := 0.0
var boxes := 0

const _FACES := [
	# normal, u axis, v axis (unit box corners from -0.5..0.5)
	[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
]


func is_empty() -> bool:
	return _verts.is_empty()


## An axis-aligned box from its centre and size.
func box(centre: Vector3, size: Vector3, color: Color, code: int, cell: float, faces := ALL, seed_value := 0.0) -> void:
	add(Transform3D(Basis.from_scale(size), centre), color, code, cell, faces, seed_value)


## A box from min corner to max corner.
func span(a: Vector3, b: Vector3, color: Color, code: int, cell: float, faces := ALL, seed_value := 0.0) -> void:
	box((a + b) * 0.5, (b - a).abs(), color, code, cell, faces, seed_value)


## A unit box under `xf` (scale = size). Faces bit i = _FACES[i].
func add(xf: Transform3D, color: Color, code: int, cell: float, faces := ALL, seed_value := 0.0) -> void:
	boxes += 1
	var size := xf.basis.get_scale()
	var rot := xf.basis.orthonormalized()
	var col := Color(color.r, color.g, color.b, (float(code) + 0.5) / 255.0)
	for f in 6:
		if faces & (1 << f) == 0:
			continue
		var n: Vector3 = _FACES[f][0]
		var u: Vector3 = _FACES[f][1]
		var v: Vector3 = _FACES[f][2]
		var w := absf(u.dot(size))
		var h := absf(v.dot(size))
		var c := n * 0.5
		var corners := [c - u * 0.5 - v * 0.5, c + u * 0.5 - v * 0.5, c + u * 0.5 + v * 0.5, c - u * 0.5 + v * 0.5]
		var local := [Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]
		var world_n := (rot * n).normalized()
		var ids := [0, 2, 1, 0, 3, 2]
		for k: int in ids:
			var p: Vector3 = xf * (corners[k] as Vector3)
			_verts.append(p)
			_normals.append(world_n)
			_colors.append(col)
			# UV: along the face (m) and height above the building base (for window storeys).
			_uv.append(Vector2((local[k] as Vector2).x, p.y - base_y))
			_uv2.append(local[k])
			_custom.append_array([w, h, cell, seed_value])


## The merged mesh (null if empty).
func commit() -> ArrayMesh:
	if _verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2
	arrays[Mesh.ARRAY_CUSTOM0] = _custom
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return m


## Triangles so far.
func triangles() -> int:
	return _verts.size() / 3
