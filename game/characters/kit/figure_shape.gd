class_name FigureShape
extends RefCounted
## An indexed triangle mesh in plain arrays, built by FigureKit. Shared
## vertices give smooth normals, which the inverted-hull outline needs.

var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var indices := PackedInt32Array()


func add_vertex(position: Vector3) -> int:
	vertices.append(position)
	return vertices.size() - 1


func add_triangle(a: int, b: int, c: int) -> void:
	indices.append_array([a, b, c])


func add_quad(a: int, b: int, c: int, d: int) -> void:
	add_triangle(a, b, c)
	add_triangle(a, c, d)


func triangle_count() -> int:
	return indices.size() / 3


## Adds another shape, moved by xform. Normals must already be computed.
func append(other: FigureShape, xform := Transform3D.IDENTITY) -> void:
	var offset := vertices.size()
	var normal_basis := xform.basis.inverse().transposed()
	for i in other.vertices.size():
		vertices.append(xform * other.vertices[i])
		normals.append((normal_basis * other.normals[i]).normalized())
	for index in other.indices:
		indices.append(index + offset)


func transformed(xform: Transform3D) -> FigureShape:
	var shape := FigureShape.new()
	shape.append(self, xform)
	return shape


## Mirror across the X = 0 plane (left part -> right part), keeping winding.
func mirrored_x() -> FigureShape:
	var shape := transformed(Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO))
	for i in range(0, shape.indices.size(), 3):
		var swap := shape.indices[i + 1]
		shape.indices[i + 1] = shape.indices[i + 2]
		shape.indices[i + 2] = swap
	return shape


## Area-weighted vertex normals; vertices at the same spot share one normal,
## so seams and rims stay smooth.
func compute_smooth_normals() -> void:
	var sums := {}
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var face := (vertices[indices[i + 1]] - a).cross(vertices[indices[i + 2]] - a)
		for k in 3:
			var key := _weld_key(vertices[indices[i + k]])
			sums[key] = sums.get(key, Vector3.ZERO) + face
	normals.resize(vertices.size())
	for i in vertices.size():
		var sum: Vector3 = sums.get(_weld_key(vertices[i]), Vector3.UP)
		normals[i] = sum.normalized() if sum.length_squared() > 1e-20 else Vector3.UP


## Smallest triangle area, for degenerate-triangle checks.
func min_triangle_area() -> float:
	var smallest := INF
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var area := (vertices[indices[i + 1]] - a).cross(vertices[indices[i + 2]] - a).length() * 0.5
		smallest = minf(smallest, area)
	return smallest


func aabb() -> AABB:
	var box := AABB(vertices[0], Vector3.ZERO)
	for v in vertices:
		box = box.expand(v)
	return box


func _weld_key(v: Vector3) -> Vector3i:
	return Vector3i((v * 1e5).round())
