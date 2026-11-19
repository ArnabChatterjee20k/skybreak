class_name FigureKit
extends RefCounted
## Chunky stylised parts for code-built fighters. Every builder is a pure
## function of its parameters and returns a closed FigureShape with smooth,
## outward normals. Units are metres; +Y is up and +Z is the figure's front.


## Rings swept along a path. Each ring is a superellipse (roundness 1 = ellipse,
## towards 0 = boxy) with radii (side, front) across the path. Optional poles
## close the ends: a Vector3 tip, or null for a flat cap.
static func loft(centers: PackedVector3Array, radii: PackedVector2Array, segments: int,
		roundness := 1.0, start_pole: Variant = null, end_pole: Variant = null,
		front_hint := Vector3.BACK) -> FigureShape:
	var shape := FigureShape.new()
	var rings: Array[PackedInt32Array] = []
	var front := Vector3.ZERO
	var previous_tangent := Vector3.ZERO
	for i in centers.size():
		var tangent := _tangent(centers, i)
		if i == 0:
			front = front_hint - tangent * tangent.dot(front_hint)
			if front.length_squared() < 1e-6:
				front = Vector3.UP - tangent * tangent.y
		else:
			# Parallel transport: turn the frame with the path so rings never twist.
			var axis := previous_tangent.cross(tangent)
			if axis.length_squared() > 1e-12:
				front = front.rotated(axis.normalized(), previous_tangent.angle_to(tangent))
			front -= tangent * tangent.dot(front)
		front = front.normalized()
		previous_tangent = tangent
		var side := tangent.cross(front)
		var ring := PackedInt32Array()
		for j in segments:
			var angle := TAU * j / segments
			var offset := side * radii[i].x * _signed_pow(cos(angle), roundness) \
				+ front * radii[i].y * _signed_pow(sin(angle), roundness)
			ring.append(shape.add_vertex(centers[i] + offset))
		rings.append(ring)
	for i in rings.size() - 1:
		for j in segments:
			var k := (j + 1) % segments
			shape.add_quad(rings[i][j], rings[i + 1][j], rings[i + 1][k], rings[i][k])
	_close_ring(shape, rings[0], start_pole if start_pole != null else centers[0], false)
	_close_ring(shape, rings[-1], end_pole if end_pole != null else centers[-1], true)
	return _finish(shape)


## Rounded box: a superellipsoid filling size. roundness 1 is an ellipsoid;
## lower values square it off (edges stay round, so normals stay smooth).
static func rounded_box(size: Vector3, roundness := 0.5, segments := 16, rows := 10) -> FigureShape:
	var half := size * 0.5
	var centers := PackedVector3Array()
	var radii := PackedVector2Array()
	for i in range(1, rows):
		var lat := -PI / 2 + PI * i / rows
		centers.append(Vector3(0, half.y * _signed_pow(sin(lat), roundness), 0))
		var scale := _signed_pow(cos(lat), roundness)
		radii.append(Vector2(half.x, half.z) * scale)
	return loft(centers, radii, segments, roundness, Vector3(0, -half.y, 0), Vector3(0, half.y, 0))


## Capsule from a to b with round ends; radii (side, front) may differ per end,
## so it doubles as a tapered limb.
static func capsule(a: Vector3, b: Vector3, radius_a: Vector2, radius_b: Vector2,
		segments := 12, cap_rings := 3, roundness := 1.0, front_hint := Vector3.BACK) -> FigureShape:
	var axis := (b - a).normalized()
	var centers := PackedVector3Array()
	var radii := PackedVector2Array()
	for k in range(1, cap_rings + 1):
		var angle := PI / 2 * k / cap_rings
		centers.append(a - axis * radius_a.length() * 0.7071 * cos(angle))
		radii.append(radius_a * sin(angle))
	for k in range(cap_rings, 0, -1):
		var angle := PI / 2 * k / cap_rings
		centers.append(b + axis * radius_b.length() * 0.7071 * cos(angle))
		radii.append(radius_b * sin(angle))
	var start := a - axis * radius_a.length() * 0.7071
	var end := b + axis * radius_b.length() * 0.7071
	return loft(centers, radii, segments, roundness, start, end, front_hint)


## A tapering point (hood ear, horn, spike) along a path, closing to its last
## point. fullness > 1 keeps it wide for longer before the tip.
static func point(path: PackedVector3Array, base_radius: Vector2, segments := 10,
		roundness := 1.0, front_hint := Vector3.BACK, fullness := 1.0) -> FigureShape:
	var centers := path.slice(0, path.size() - 1)
	var radii := PackedVector2Array()
	for i in centers.size():
		var t := float(i) / (path.size() - 1)
		radii.append(base_radius * (1.0 - pow(t, fullness)))
	return loft(centers, radii, segments, roundness, null, path[-1], front_hint)


## Ring around +Y: a torus with radii (major, minor); minor_scale squashes its
## cross-section (x = radial, y = height).
static func torus(major: float, minor: float, segments := 24, sides := 8,
		minor_scale := Vector2.ONE) -> FigureShape:
	var shape := FigureShape.new()
	for i in segments:
		var around := TAU * i / segments
		var out := Vector3(cos(around), 0, sin(around))
		for j in sides:
			var angle := TAU * j / sides
			var p := out * (major + minor * minor_scale.x * cos(angle)) \
				+ Vector3.UP * minor * minor_scale.y * sin(angle)
			shape.add_vertex(p)
	for i in segments:
		for j in sides:
			var a := i * sides + j
			var b := ((i + 1) % segments) * sides + j
			var c := ((i + 1) % segments) * sides + (j + 1) % sides
			var d := i * sides + (j + 1) % sides
			shape.add_quad(a, b, c, d)
	return _finish(shape)


## A flat 2D outline (XY, any winding) extruded along Z by depth, with a
## bevel on both faces so the outline shader gets smooth edges.
static func extrude(profile: PackedVector2Array, depth: float, bevel := 0.0) -> FigureShape:
	var outline := profile.duplicate()
	if _signed_area(outline) < 0.0:
		outline.reverse()
	var inset := _inset(outline, bevel)
	var half := depth * 0.5
	var layers: Array = [[inset, -half], [outline, -half + bevel], [outline, half - bevel], [inset, half]]
	if bevel <= 0.0:
		layers = [[outline, -half], [outline, half]]
	var shape := FigureShape.new()
	var rings: Array[PackedInt32Array] = []
	for layer: Array in layers:
		var ring := PackedInt32Array()
		for p: Vector2 in layer[0]:
			ring.append(shape.add_vertex(Vector3(p.x, p.y, layer[1])))
		rings.append(ring)
	var n := outline.size()
	for i in rings.size() - 1:
		for j in n:
			var k := (j + 1) % n
			shape.add_quad(rings[i][j], rings[i][k], rings[i + 1][k], rings[i + 1][j])
	var caps := Geometry2D.triangulate_polygon(inset)
	for t in range(0, caps.size(), 3):
		shape.add_triangle(rings[-1][caps[t]], rings[-1][caps[t + 1]], rings[-1][caps[t + 2]])
		shape.add_triangle(rings[0][caps[t]], rings[0][caps[t + 2]], rings[0][caps[t + 1]])
	return _finish(shape)


## Hanging cloth (scarf tail, tabard, belt flap): a thin rounded strip along a
## path, width tapering to tip_width.
static func cloth_flap(path: PackedVector3Array, width: float, thickness: float,
		tip_width := 0.3, segments := 8, front_hint := Vector3.BACK) -> FigureShape:
	var radii := PackedVector2Array()
	for i in path.size():
		var t := float(i) / (path.size() - 1)
		radii.append(Vector2(width * 0.5 * lerpf(1.0, tip_width, t), thickness * 0.5))
	return loft(path, radii, segments, 0.6, null, null, front_hint)


## Hood: a rounded shell of size, open at the bottom and with a face opening
## at the front (+Z). The opening follows the grid (half-width in radians of
## longitude, top as a latitude in radians), so its edge stays smooth.
## bottom is the latitude below which the shell is open. Thickness makes it solid.
static func hood_shell(size: Vector3, roundness: float, thickness: float, opening_half_width: float,
		opening_top: float, bottom := -0.9, segments := 32, rows := 20) -> FigureShape:
	var half := size * 0.5
	var shape := FigureShape.new()
	var grid: Array[PackedInt32Array] = []
	var lats := PackedFloat32Array()
	for i in range(1, rows):
		var lat := -PI / 2 + PI * i / rows
		lats.append(lat)
		var ring := PackedInt32Array()
		for j in segments:
			var lon := PI / 2 + TAU * j / segments
			var r := _signed_pow(cos(lat), roundness)
			ring.append(shape.add_vertex(Vector3(half.x * r * _signed_pow(cos(lon), roundness),
				half.y * _signed_pow(sin(lat), roundness), half.z * r * _signed_pow(sin(lon), roundness))))
		grid.append(ring)
	var top := shape.add_vertex(Vector3(0, half.y, 0))
	for i in grid.size() - 1:
		var lat := (lats[i] + lats[i + 1]) * 0.5
		if lat < bottom:
			continue
		for j in segments:
			var lon := TAU * (j + 0.5) / segments
			var from_front := minf(lon, TAU - lon)
			if from_front < opening_half_width and lat < opening_top:
				continue
			var k := (j + 1) % segments
			shape.add_quad(grid[i][j], grid[i + 1][j], grid[i + 1][k], grid[i][k])
	for j in segments:
		shape.add_triangle(grid[-1][j], top, grid[-1][(j + 1) % segments])
	_orient_open(shape, Vector3.ZERO)
	return solidify(shape, thickness)


## Gives an open, outward-facing sheet a thickness: an inner copy offset
## along the normals plus a rim along every open edge.
static func solidify(sheet: FigureShape, thickness: float) -> FigureShape:
	sheet.compute_smooth_normals()
	var shape := FigureShape.new()
	var count := sheet.vertices.size()
	for v in sheet.vertices:
		shape.add_vertex(v)
	for i in count:
		shape.add_vertex(sheet.vertices[i] - sheet.normals[i] * thickness)
	var edges := {}
	for t in range(0, sheet.indices.size(), 3):
		var a := sheet.indices[t]
		var b := sheet.indices[t + 1]
		var c := sheet.indices[t + 2]
		shape.add_triangle(a, b, c)
		shape.add_triangle(c + count, b + count, a + count)
		for edge: Vector2i in [Vector2i(a, b), Vector2i(b, c), Vector2i(c, a)]:
			edges[edge] = true
	for edge: Vector2i in edges:
		if not edges.has(Vector2i(edge.y, edge.x)):
			shape.add_quad(edge.y, edge.x, edge.x + count, edge.y + count)
	shape.compute_smooth_normals()
	return shape


static func _finish(shape: FigureShape) -> FigureShape:
	if _signed_volume(shape) < 0.0:
		_flip(shape)
	shape.compute_smooth_normals()
	return shape


## Orients an open sheet so its faces point away from center.
static func _orient_open(shape: FigureShape, center: Vector3) -> void:
	var outward := 0.0
	for t in range(0, shape.indices.size(), 3):
		var a := shape.vertices[shape.indices[t]]
		var face := (shape.vertices[shape.indices[t + 1]] - a).cross(shape.vertices[shape.indices[t + 2]] - a)
		outward += face.dot(a - center)
	if outward < 0.0:
		_flip(shape)


static func _flip(shape: FigureShape) -> void:
	for t in range(0, shape.indices.size(), 3):
		var swap := shape.indices[t + 1]
		shape.indices[t + 1] = shape.indices[t + 2]
		shape.indices[t + 2] = swap


static func _signed_volume(shape: FigureShape) -> float:
	var volume := 0.0
	for t in range(0, shape.indices.size(), 3):
		var a := shape.vertices[shape.indices[t]]
		volume += a.dot(shape.vertices[shape.indices[t + 1]].cross(shape.vertices[shape.indices[t + 2]]))
	return volume / 6.0


## Fans a ring to a pole; the end ring winds the other way from the start.
static func _close_ring(shape: FigureShape, ring: PackedInt32Array, pole: Vector3, is_end: bool) -> void:
	var center := shape.add_vertex(pole)
	for j in ring.size():
		var k := (j + 1) % ring.size()
		if is_end:
			shape.add_triangle(center, ring[k], ring[j])
		else:
			shape.add_triangle(center, ring[j], ring[k])


static func _tangent(points: PackedVector3Array, i: int) -> Vector3:
	var before := points[maxi(i - 1, 0)]
	var after := points[mini(i + 1, points.size() - 1)]
	var tangent := after - before
	return tangent.normalized() if tangent.length_squared() > 1e-12 else Vector3.UP


static func _signed_pow(value: float, exponent: float) -> float:
	return signf(value) * pow(absf(value), exponent)


static func _signed_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		area += a.x * b.y - b.x * a.y
	return area * 0.5


## Moves each point of a CCW outline inward along its corner bisector.
static func _inset(outline: PackedVector2Array, amount: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var n := outline.size()
	for i in n:
		var prev := outline[(i - 1 + n) % n]
		var next := outline[(i + 1) % n]
		var in_a := (outline[i] - prev).normalized().orthogonal() * -1.0
		var in_b := (next - outline[i]).normalized().orthogonal() * -1.0
		var bisector := (in_a + in_b).normalized()
		var miter := clampf(1.0 / maxf(bisector.dot(in_a), 0.35), 1.0, 2.5)
		result.append(outline[i] + bisector * amount * miter)
	return result
