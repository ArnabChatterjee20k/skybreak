class_name VoxelFaceMerge
extends RefCounted
## Greedy 2D merge of a static VoxelMesher mesh without changing its look.
## The mesher writes one quad per open voxel face, with the face's colour per
## corner (COLOR), corner AO (CUSTOM0) and convex edge flags (CUSTOM1). Here
## those per-face values move into a face texture (4 texels per face, one per
## corner: sRGB colour, alpha = AO level | edge flag << 2), and coplanar faces
## of one surface merge into rectangles. Each merged quad carries
##   UV: the face's cell coordinates (0..w, 0..h) and
##   CUSTOM0: (first face index, w, h, 0),
## so voxel_merged_prop.gdshader finds the cell under each pixel and rebuilds
## the original face exactly (same two-triangle colour interpolation, the
## same bilinear AO and bevel ramps).

const TEX_WIDTH := 4096
## The mesher's corner AO values, by level.
const AO_LEVELS: Array[float] = [0.42, 0.62, 0.82, 1.0]


## The merged copy of a mesher mesh; the face texture rides along as the
## "faces" meta (an Image), so a cached mesh keeps it.
static func merge(src: ArrayMesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	if src.get_surface_count() == 0:
		return out
	var first: PackedVector3Array = src.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var cell := (first[1] - first[0]).length()
	var p0 := first[0]
	var texels := PackedByteArray()
	var face_total := 0
	var format := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var ao: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
		var edges: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
		# Faces grouped by (direction, plane), keyed by their (a, b) cell in the plane.
		var groups := {}
		for f in verts.size() / 4:
			var d := _dir(normals[f * 4])
			var n := VoxelMesher.DIRS[d]
			var u := VoxelMesher.U_AXES[d]
			var v := Vector3i(Vector3(n).cross(Vector3(u)).round())
			var lc := Vector3i(((verts[f * 4] - p0) / cell).round())
			var key := Vector2i(d, _dot(lc, n))
			if not groups.has(key):
				groups[key] = {}
			(groups[key] as Dictionary)[Vector2i(_dot(lc, u), _dot(lc, v))] = f
		var o_verts := PackedVector3Array()
		var o_normals := PackedVector3Array()
		var o_tangents := PackedFloat32Array()
		var o_uvs := PackedVector2Array()
		var o_custom := PackedFloat32Array()
		var o_indices := PackedInt32Array()
		for key: Vector2i in groups:
			var faces: Dictionary = groups[key]
			var d := key.x
			var n := VoxelMesher.DIRS[d]
			var u := VoxelMesher.U_AXES[d]
			var v := Vector3i(Vector3(n).cross(Vector3(u)).round())
			# Seeds in (b, a) order, so every rectangle grows from its lowest corner.
			var order := PackedInt64Array()
			for c: Vector2i in faces:
				order.append((int(c.y) + 1048576) * 2097152 + (int(c.x) + 1048576))
			order.sort()
			var used := {}
			for packed in order:
				var a0 := int(packed % 2097152) - 1048576
				var b0 := int(packed / 2097152) - 1048576
				var seed := Vector2i(a0, b0)
				if used.has(seed):
					continue
				var a1 := a0 + 1
				while faces.has(Vector2i(a1, b0)) and not used.has(Vector2i(a1, b0)):
					a1 += 1
				var b1 := b0 + 1
				while true:
					var row_ok := true
					for a in range(a0, a1):
						var c := Vector2i(a, b1)
						if not faces.has(c) or used.has(c):
							row_ok = false
							break
					if not row_ok:
						break
					b1 += 1
				var w := a1 - a0
				var h := b1 - b0
				for b in range(b0, b1):
					for a in range(a0, a1):
						var c := Vector2i(a, b)
						used[c] = true
						_write_face(texels, faces[c], colors, ao, edges)
				var base := o_verts.size()
				for corner: Vector2i in [Vector2i(a0, b0), Vector2i(a1, b0), Vector2i(a1, b1), Vector2i(a0, b1)]:
					var lc := u * corner.x + v * corner.y + n * key.y
					o_verts.append(p0 + Vector3(lc) * cell)
					o_normals.append(Vector3(n))
					o_tangents.append_array([float(u.x), float(u.y), float(u.z), 1.0])
					o_uvs.append(Vector2(corner.x - a0, corner.y - b0))
					o_custom.append_array([float(face_total), float(w), float(h), 0.0])
				face_total += w * h
				o_indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
		var out_arrays := []
		out_arrays.resize(Mesh.ARRAY_MAX)
		out_arrays[Mesh.ARRAY_VERTEX] = o_verts
		out_arrays[Mesh.ARRAY_NORMAL] = o_normals
		out_arrays[Mesh.ARRAY_TANGENT] = o_tangents
		out_arrays[Mesh.ARRAY_TEX_UV] = o_uvs
		out_arrays[Mesh.ARRAY_CUSTOM0] = o_custom
		out_arrays[Mesh.ARRAY_INDEX] = o_indices
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrays, [], {}, format)
		out.surface_set_name(out.get_surface_count() - 1, src.surface_get_name(s))
	var rows := maxi(1, ceili(float(texels.size() / 4) / TEX_WIDTH))
	texels.resize(rows * TEX_WIDTH * 4)
	out.set_meta("faces", Image.create_from_data(TEX_WIDTH, rows, false, Image.FORMAT_RGBA8, texels))
	return out


## Appends one face's 4 corner texels.
static func _write_face(texels: PackedByteArray, f: int, colors: PackedColorArray, ao: PackedFloat32Array,
		edges: PackedFloat32Array) -> void:
	for k in 4:
		var c := colors[f * 4 + k]
		texels.append(_byte(c.r))
		texels.append(_byte(c.g))
		texels.append(_byte(c.b))
		texels.append(_ao_level(ao[f * 16 + k]) | (4 if edges[f * 16 + k] > 0.5 else 0))


## The source mesh's colours are already 8-bit (Godot stores vertex colours as
## unorm8), read back as k / 255: rounding recovers k exactly.
static func _byte(x: float) -> int:
	return clampi(roundi(x * 255.0), 0, 255)


static func _ao_level(x: float) -> int:
	var best := 0
	for i in AO_LEVELS.size():
		if absf(AO_LEVELS[i] - x) < absf(AO_LEVELS[best] - x):
			best = i
	return best


static func _dir(n: Vector3) -> int:
	if absf(n.x) > 0.5:
		return 0 if n.x > 0.0 else 1
	if absf(n.y) > 0.5:
		return 2 if n.y > 0.0 else 3
	return 4 if n.z > 0.0 else 5


static func _dot(a: Vector3i, b: Vector3i) -> int:
	return a.x * b.x + a.y * b.y + a.z * b.z
