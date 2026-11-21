class_name FlightClearance
extends RefCounted
## How close a zone's fly-through camera passes to the zone's solid geometry:
## every opaque mesh triangle under the zone (terrain chunks, props and their
## MultiMesh copies; see-through blend_* surfaces like water, mist and rain
## are skipped) and the visible ground (VoxelZone.ground_at). Copies come from
## PropKit.INSTANCE_TRANSFORMS_META where set (VoxelProp sets it): the headless
## renderer keeps no MultiMesh data. Only the LOD tier the renderer would draw
## at each camera position counts (visibility ranges). The camera
## follows the same Catmull-Rom spline as the capture and the benchmark.
##   var report := FlightClearance.sweep(zone)   # zone built or loaded from a bake

## The camera must stay at least this far (m) from any solid geometry.
const MIN_CLEARANCE := 1.0
## Spline samples per control-point segment.
const SAMPLES_PER_SEGMENT := 160
## Lookup grid cell (m) for path samples.
const CELL := 4.0
## Further than this (m) below VoxelZone.ground_at, a sample is under a floating
## surface, not in the ground.
const UNDER := 8.0


## Catmull-Rom through pts[key], as zone_capture and zone_bench move the camera.
static func spline(pts: Array[Dictionary], key: String, u: float) -> Vector3:
	var i := clampi(floori(u), 0, pts.size() - 2)
	var t := u - i
	var p0: Vector3 = pts[maxi(i - 1, 0)][key]
	var p1: Vector3 = pts[i][key]
	var p2: Vector3 = pts[i + 1][key]
	var p3: Vector3 = pts[mini(i + 2, pts.size() - 1)][key]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


## The camera positions along pts (default zone.flight()), SAMPLES_PER_SEGMENT per segment.
static func path(zone: VoxelZone, pts: Array[Dictionary] = []) -> PackedVector3Array:
	if pts.is_empty():
		pts = zone.flight()
	var out := PackedVector3Array()
	var n := (pts.size() - 1) * SAMPLES_PER_SEGMENT
	for k in n + 1:
		out.append(spline(pts, "from", float(k) / float(SAMPLES_PER_SEGMENT)))
	return out


## {min: float, triangles: int (tested), samples: [{u, at, clearance, what}]}
## for pts (default zone.flight())
## with every sample closer than `limit` to solid geometry or the visible
## ground, the nearest per sample.
static func sweep(zone: VoxelZone, limit := MIN_CLEARANCE, pts: Array[Dictionary] = []) -> Dictionary:
	var samples := path(zone, pts)
	var grid := {}
	for i in samples.size():
		var key := _cell(samples[i])
		# Packed arrays are values: append to a copy and store it back.
		var list: PackedInt32Array = grid.get(key, PackedInt32Array())
		list.append(i)
		grid[key] = list
	var best := PackedFloat32Array()
	best.resize(samples.size())
	best.fill(INF)
	var what: Array[String] = []
	what.resize(samples.size())
	for i in samples.size():
		# Deep under the visible ground is under a floating island: its meshes count there.
		var g := zone.ground_at(samples[i].x, samples[i].z)
		if g > -INF and samples[i].y > g - UNDER:
			best[i] = samples[i].y - g
			what[i] = "ground"
	var tested := 0
	var path_box := AABB(samples[0], Vector3.ZERO)
	for p in samples:
		path_box = path_box.expand(p)
	path_box = path_box.grow(limit)
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
		if mesh == null or not _solid(gi, mesh):
			continue
		var local_box := mesh.get_aabb()
		# Visibility ranges are measured from the node's whole box (all its copies).
		var whole := xforms[0] * local_box if not xforms.is_empty() else AABB()
		for xf in xforms:
			whole = whole.merge(xf * local_box)
		if gi.custom_aabb.has_volume():
			whole = gi.global_transform * gi.custom_aabb
		var centre := whole.get_center()
		var begin := gi.visibility_range_begin
		var end := gi.visibility_range_end
		var faces := PackedVector3Array()
		for xf in xforms:
			var box := xf * local_box
			if not box.intersects(path_box) or not _near(grid, box.grow(limit)):
				continue
			if faces.is_empty():
				faces = mesh.get_faces()
			var label := String(gi.get_path()).get_file()
			for t in range(0, faces.size(), 3):
				var a := xf * faces[t]
				var b := xf * faces[t + 1]
				var c := xf * faces[t + 2]
				var tb := AABB(a, Vector3.ZERO).expand(b).expand(c).grow(limit)
				tested += 1
				for key in _cells(tb):
					if not grid.has(key):
						continue
					for i: int in grid[key]:
						if not tb.has_point(samples[i]):
							continue
						var seen := samples[i].distance_to(centre)
						if seen < begin or (end > 0.0 and seen >= end):
							continue  # another LOD tier draws here
						var d := samples[i].distance_to(closest_on_triangle(samples[i], a, b, c))
						if d < best[i]:
							best[i] = d
							what[i] = label
	var out := {"min": INF, "samples": [], "triangles": tested}
	for i in samples.size():
		out.min = minf(out.min, best[i])
		if best[i] < limit:
			(out.samples as Array).append({"u": float(i) / float(SAMPLES_PER_SEGMENT), "at": samples[i],
				"clearance": best[i], "what": what[i]})
	return out


## Opaque geometry only: blend_* (water, mist, rain, light shafts) is see-through.
static func _solid(gi: GeometryInstance3D, mesh: Mesh) -> bool:
	if not gi.is_visible_in_tree():
		return false
	var mat := gi.material_override
	if mat == null and mesh.get_surface_count() > 0:
		mat = mesh.surface_get_material(0)
	if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null:
		return not (mat as ShaderMaterial).shader.code.contains("blend_")
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
	return true


static func _cell(p: Vector3) -> Vector3i:
	return Vector3i((p / CELL).floor())


static func _cells(box: AABB) -> Array[Vector3i]:
	var lo := _cell(box.position)
	var hi := _cell(box.end)
	var out: Array[Vector3i] = []
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				out.append(Vector3i(x, y, z))
	return out


static func _near(grid: Dictionary, box: AABB) -> bool:
	var lo := _cell(box.position)
	var hi := _cell(box.end)
	if (hi - lo).x * (hi - lo).y * (hi - lo).z > grid.size():
		for key: Vector3i in grid:
			if key.x >= lo.x and key.x <= hi.x and key.y >= lo.y and key.y <= hi.y and key.z >= lo.z and key.z <= hi.z:
				return true
		return false
	for key in _cells(box):
		if grid.has(key):
			return true
	return false


## The point of triangle abc nearest p (Ericson, Real-Time Collision Detection 5.1.5).
static func closest_on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denom := 1.0 / (va + vb + vc)
	return a + ab * (vb * denom) + ac * (vc * denom)
