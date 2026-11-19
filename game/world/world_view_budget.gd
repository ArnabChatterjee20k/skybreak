class_name WorldViewBudget
extends RefCounted
## Counts draw calls and triangles a camera would see in the world, from mesh data:
## visibility ranges, frustum and per-mesh triangle counts. A CPU estimate for tests;
## the real GPU cost is measured with the render benchmark.

const DRAW_CALL_BUDGET := 300
const TRIANGLE_BUDGET := 600000


## Returns {draw_calls, triangles, chunks, multimeshes} for a camera at `xform`.
static func count(root: Node, xform: Transform3D, fov_degrees: float = 75.0, aspect: float = 16.0 / 9.0,
		far: float = 1300.0) -> Dictionary:
	var planes := frustum_planes(xform, fov_degrees, aspect, 0.1, far)
	var result := {"draw_calls": 0, "triangles": 0, "chunks": 0, "multimeshes": 0}
	_visit(root, xform.origin, planes, result)
	return result


static func _visit(node: Node, eye: Vector3, planes: Array[Plane], result: Dictionary) -> void:
	if node is Node3D and not (node as Node3D).visible:
		return
	if node is GeometryInstance3D and not node is GPUParticles3D:
		var gi := node as GeometryInstance3D
		var local_box := gi.custom_aabb
		if not local_box.has_volume() and node is MeshInstance3D and (node as MeshInstance3D).mesh:
			local_box = (node as MeshInstance3D).mesh.get_aabb()
		var aabb := gi.global_transform * local_box
		var distance := aabb.get_center().distance_to(eye)
		var in_range := distance >= gi.visibility_range_begin and (gi.visibility_range_end <= 0.0 or distance < gi.visibility_range_end)
		if in_range and _intersects(aabb, planes):
			var mesh_tris := 0
			var surfaces := 1
			if node is MeshInstance3D:
				var mesh := (node as MeshInstance3D).mesh
				mesh_tris = int(node.get_meta("triangles")) if node.has_meta("triangles") else triangles(mesh)
				surfaces = mesh.get_surface_count()
				if node.has_meta("lod"):
					result.chunks += 1
			elif node is MultiMeshInstance3D:
				var mm := (node as MultiMeshInstance3D).multimesh
				mesh_tris = triangles(mm.mesh) * mm.instance_count
				surfaces = mm.mesh.get_surface_count()
				result.multimeshes += 1
			result.draw_calls += surfaces
			result.triangles += mesh_tris
	for child in node.get_children():
		_visit(child, eye, planes, result)


static func triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	if mesh.has_meta("triangles"):
		return int(mesh.get_meta("triangles"))
	var total := 0
	var arrays_list: Array = []
	if mesh is PrimitiveMesh:
		arrays_list.append((mesh as PrimitiveMesh).get_mesh_arrays())
	else:
		for s in mesh.get_surface_count():
			arrays_list.append((mesh as ArrayMesh).surface_get_arrays(s))
	for arrays in arrays_list:
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		total += indices.size() / 3 if indices.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	mesh.set_meta("triangles", total)
	return total


## Six planes with normals pointing out of the view volume.
static func frustum_planes(xform: Transform3D, fov_degrees: float, aspect: float, near: float, far: float) -> Array[Plane]:
	var eye := xform.origin
	var forward := -xform.basis.z.normalized()
	var right := xform.basis.x.normalized()
	var up := xform.basis.y.normalized()
	var half_v := deg_to_rad(fov_degrees) * 0.5
	var half_h := atan(tan(half_v) * aspect)
	var planes: Array[Plane] = []
	planes.append(Plane(-forward, eye + forward * near))
	planes.append(Plane(forward, eye + forward * far))
	planes.append(Plane((right * cos(half_h) - forward * sin(half_h)).normalized(), eye))
	planes.append(Plane((-right * cos(half_h) - forward * sin(half_h)).normalized(), eye))
	planes.append(Plane((up * cos(half_v) - forward * sin(half_v)).normalized(), eye))
	planes.append(Plane((-up * cos(half_v) - forward * sin(half_v)).normalized(), eye))
	return planes


static func _intersects(aabb: AABB, planes: Array[Plane]) -> bool:
	for plane in planes:
		# The AABB corner furthest inside the plane; if even that is outside, cull.
		var p := aabb.position
		if plane.normal.x < 0.0:
			p.x += aabb.size.x
		if plane.normal.y < 0.0:
			p.y += aabb.size.y
		if plane.normal.z < 0.0:
			p.z += aabb.size.z
		if plane.is_point_over(p):
			return false
	return true
