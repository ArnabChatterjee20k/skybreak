class_name CameraClearance
extends RefCounted
## How close fight-camera positions come to a voxel zone's solid triangles (opaque
## meshes and their MultiMesh copies at the LOD tier drawn there), as FlightClearance
## measures the fly-through, plus points inside a closed prop copy (upward ray
## parity): the no-clip check for the fight camera on voxel zones.

## Closer than this (m) to a solid triangle, the near plane (0.05 m) is about to cut it.
const MIN_CLEARANCE := 0.15
const CELL := 4.0
## Mostly up, skewed so it misses the shared edges of axis-aligned faces.
const PARITY_RAY := Vector3(0.0137, 1.0, 0.0291)


## {min, samples: [{index, at, clearance, what}]} for every point closer than limit.
static func sweep(zone: VoxelZone, points: PackedVector3Array, limit := MIN_CLEARANCE) -> Dictionary:
	var out := {"min": INF, "samples": []}
	if points.is_empty():
		return out
	var grid := {}
	var all := AABB(points[0], Vector3.ZERO)
	for i in points.size():
		all = all.expand(points[i])
		var key := _cell(points[i])
		var list: PackedInt32Array = grid.get(key, PackedInt32Array())
		list.append(i)
		grid[key] = list
	all = all.grow(limit)
	var best := PackedFloat32Array()
	best.resize(points.size())
	best.fill(INF)
	var what: Array[String] = []
	what.resize(points.size())
	for i in points.size():
		# Under the visible ground (but not deep under a floating island) counts as inside it.
		var g := zone.ground_at(points[i].x, points[i].z)
		if g > -INF and points[i].y < g and points[i].y > g - FlightClearance.UNDER:
			best[i] = 0.0
			what[i] = "ground"
	for gi: GeometryInstance3D in zone.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = null
		var xforms: Array[Transform3D] = []
		if gi is MeshInstance3D:
			mesh = (gi as MeshInstance3D).mesh
			xforms.append(gi.global_transform)
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
			var mm := (gi as MultiMeshInstance3D).multimesh
			mesh = mm.mesh
			if gi.has_meta(PropKit.INSTANCE_TRANSFORMS_META):
				for xf: Transform3D in gi.get_meta(PropKit.INSTANCE_TRANSFORMS_META):
					xforms.append(gi.global_transform * xf)
			else:
				for k in mm.instance_count:
					xforms.append(gi.global_transform * mm.get_instance_transform(k))
		if mesh == null or xforms.is_empty() or not FlightClearance._solid(gi, mesh):
			continue
		var local_box := mesh.get_aabb()
		var whole := xforms[0] * local_box
		for xf in xforms:
			whole = whole.merge(xf * local_box)
		if gi.custom_aabb.has_volume():
			whole = gi.global_transform * gi.custom_aabb
		var centre := whole.get_center()
		var faces := PackedVector3Array()
		for xf in xforms:
			var box := (xf * local_box).grow(limit)
			if not box.intersects(all):
				continue
			var near := _points_in(grid, points, box)
			if near.is_empty():
				continue
			if faces.is_empty():
				faces = mesh.get_faces()
			# Points inside the copy's box: count an upward ray's crossings (odd = inside a closed mesh).
			var inner := xf * local_box
			var crossings := {}
			for i in near:
				if inner.has_point(points[i]):
					crossings[i] = 0
			for t in range(0, faces.size(), 3):
				var a := xf * faces[t]
				var b := xf * faces[t + 1]
				var c := xf * faces[t + 2]
				for i: int in crossings:
					if Geometry3D.ray_intersects_triangle(points[i], PARITY_RAY, a, b, c) != null:
						crossings[i] += 1
				var tb := AABB(a, Vector3.ZERO).expand(b).expand(c).grow(limit)
				for i in near:
					if not tb.has_point(points[i]):
						continue
					var seen := points[i].distance_to(centre)
					if seen < gi.visibility_range_begin or (gi.visibility_range_end > 0.0 and seen >= gi.visibility_range_end):
						continue  # another LOD tier draws here
					var d := points[i].distance_to(FlightClearance.closest_on_triangle(points[i], a, b, c))
					if d < best[i]:
						best[i] = d
						what[i] = String(gi.name)
			for i: int in crossings:
				var seen := points[i].distance_to(centre)
				if crossings[i] % 2 == 1 and not (seen < gi.visibility_range_begin \
						or (gi.visibility_range_end > 0.0 and seen >= gi.visibility_range_end)):
					best[i] = 0.0
					what[i] = "%s (inside)" % gi.name
	for i in points.size():
		out.min = minf(out.min, best[i])
		if best[i] < limit:
			(out.samples as Array).append({"index": i, "at": points[i], "clearance": best[i], "what": what[i]})
	return out


static func _cell(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / CELL), floori(p.y / CELL), floori(p.z / CELL))


## Indices of the points inside box: through the grid cells it covers, or every
## point when the box covers more cells than there are points (backdrop slabs).
static func _points_in(grid: Dictionary, points: PackedVector3Array, box: AABB) -> PackedInt32Array:
	var out := PackedInt32Array()
	var lo := _cell(box.position)
	var hi := _cell(box.end)
	var cells := (hi.x - lo.x + 1) * (hi.y - lo.y + 1) * (hi.z - lo.z + 1)
	if cells > grid.size():
		for key: Vector3i in grid:
			if key.x >= lo.x and key.x <= hi.x and key.y >= lo.y and key.y <= hi.y and key.z >= lo.z and key.z <= hi.z:
				for i: int in grid[key]:
					if box.has_point(points[i]):
						out.append(i)
		return out
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				for i: int in grid.get(Vector3i(x, y, z), PackedInt32Array()):
					if box.has_point(points[i]):
						out.append(i)
	return out
