class_name LookdevFraming
extends RefCounted
## Look-dev only: camera placement from measured geometry (posed vertices), so
## close-ups and over-the-shoulder shots fit each character's real bounds.

const FINGERS: Array[String] = ["Thumb", "Index", "Middle", "Ring", "Little"]


## Camera position, for a camera with orientation `basis` (looking along -Z),
## that keeps every point inside a frame of `fov_deg` vertical field of view
## and `aspect`, with `pad` of each half-extent left as margin.
static func fit(points: PackedVector3Array, basis: Basis, fov_deg: float, aspect: float, pad := 0.12) -> Vector3:
	var ty := tan(deg_to_rad(fov_deg) * 0.5) * (1.0 - pad)
	var tx := ty * aspect
	var x := basis.x.normalized()
	var y := basis.y.normalized()
	var z := basis.z.normalized()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in points:
		var q := Vector2(p.dot(x), p.dot(y))
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	var c := (lo + hi) * 0.5
	var cz := -INF
	for p in points:
		var pz := p.dot(z)
		cz = maxf(cz, pz + absf(p.dot(x) - c.x) / tx)
		cz = maxf(cz, pz + absf(p.dot(y) - c.y) / ty)
	return x * c.x + y * c.y + z * cz


## Whether every point lies inside the frame of a camera at `eye`.
static func inside_frame(points: PackedVector3Array, eye: Vector3, basis: Basis, fov_deg: float, aspect: float) -> bool:
	var ty := tan(deg_to_rad(fov_deg) * 0.5) + 1e-4
	var tx := ty * aspect
	for p in points:
		var local := basis.inverse() * (p - eye)
		var depth := -local.z
		if depth <= 0.0 or absf(local.x) > depth * tx or absf(local.y) > depth * ty:
			return false
	return true


## Smallest distance (minus `margin`) between `obstacle` points and the sight
## lines from `eye` to each of `targets`, each line stopping `short` before its
## target (so what touches the target, like a neck under a chin, doesn't
## count): negative means something blocks.
static func clearance(eye: Vector3, targets: PackedVector3Array, obstacle: PackedVector3Array, margin: float, short := 0.0) -> float:
	var best := INF
	for t in targets:
		var end := t + (eye - t).normalized() * minf(short, eye.distance_to(t))
		for p in obstacle:
			best = minf(best, p.distance_to(Geometry3D.get_closest_point_to_segment(p, eye, end)))
	return best - margin


## How far along `lift` (a direction scaled per step) the eye must move from
## `base` before the sight lines to `targets` clear `obstacle` by `margin`.
static func clear_lift(base: Vector3, lift: Vector3, targets: PackedVector3Array, obstacle: PackedVector3Array, margin: float, steps := 40) -> float:
	for i in steps + 1:
		var t := float(i) / float(steps)
		if clearance(base + lift * t, targets, obstacle, margin) >= 0.0:
			return t
	return 1.0


## World-space posed vertices of `skeleton`'s skinned meshes whose strongest
## bone passes `keep` (a Callable taking the bone name), every `stride`-th.
## Skinned on the CPU, so it also works headless (the dummy renderer has no
## skin to bake from), from `poses` (a pose_snapshot() taken on
## skeleton_updated, with the modifiers applied) or else the skeleton's pose.
static func skinned_points(skeleton: Skeleton3D, keep: Callable, stride := 1, poses: Array[Transform3D] = []) -> PackedVector3Array:
	var out := PackedVector3Array()
	for node in skeleton.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.skin == null or not mi.is_visible_in_tree():
			continue
		var skin := mi.skin
		var mats: Array[Transform3D] = []
		var names: Array[String] = []
		for k in skin.get_bind_count():
			var bone := skin.get_bind_bone(k)
			if bone < 0:
				bone = skeleton.find_bone(skin.get_bind_name(k))
			names.append(skeleton.get_bone_name(bone) if bone >= 0 else String(skin.get_bind_name(k)))
			bone = maxi(bone, 0)
			var pose := poses[bone] if bone < poses.size() else skeleton.get_bone_global_pose(bone)
			# As the renderer and bake_mesh_from_current_skeleton_pose(): in the
			# mesh instance's space.
			mats.append(mi.global_transform * pose * skin.get_bind_pose(k))
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / maxi(verts.size(), 1)
			if per < 1:
				continue
			for v in range(0, verts.size(), stride):
				var top := 0
				for j in per:
					if ws[v * per + j] > ws[v * per + top]:
						top = j
				if not keep.call(names[bones[v * per + top]]):
					continue
				var p := Vector3.ZERO
				for j in per:
					var w := ws[v * per + j]
					if w > 0.0:
						p += (mats[bones[v * per + j]] * verts[v]) * w
				out.append(p)
	return out


## Every bone's global pose now. Read on skeleton_updated it includes the
## SkeletonModifier3Ds (outside it the skeleton reports the pose without them).
static func pose_snapshot(skeleton: Skeleton3D) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for b in skeleton.get_bone_count():
		out.append(skeleton.get_bone_global_pose(b))
	return out


## Bone-name filter for one side's hand (fingers included) and, optionally, forearm.
static func hand_bones(side: String, forearm := true) -> Callable:
	return func(name: String) -> bool:
		if not name.begins_with(side):
			return false
		var rest := name.substr(side.length())
		if rest == "Hand" or (forearm and rest == "LowerArm"):
			return true
		for f in FINGERS:
			if rest.begins_with(f):
				return true
		return false


## Screen-space bounds (frame fractions, y down) of the `points` in front of a
## camera at `xf`.
static func screen_box(points: PackedVector3Array, xf: Transform3D, fov_deg: float, aspect: float) -> Rect2:
	var inv := xf.affine_inverse()
	var ty := tan(deg_to_rad(fov_deg) * 0.5)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in points:
		var q := inv * p
		if q.z > -0.01:
			continue
		var s := Vector2(0.5 + q.x / (-q.z * ty * aspect) * 0.5, 0.5 - q.y / (-q.z * ty) * 0.5)
		lo = Vector2(minf(lo.x, s.x), minf(lo.y, s.y))
		hi = Vector2(maxf(hi.x, s.x), maxf(hi.y, s.y))
	return Rect2(lo, hi - lo)


## How far `box` (frame fractions) stays inside the `pad` safe area: negative
## means it pokes past the padding.
static func safe_margin(box: Rect2, pad: float) -> float:
	return minf(minf(box.position.x, 1.0 - box.end.x), minf(box.position.y, 1.0 - box.end.y)) - pad


## Share of `box` (frame fractions) covered by `clutter` points seen from a
## camera at `xf`, on a grid of `cells` across the box.
static func cover(box: Rect2, clutter: PackedVector3Array, xf: Transform3D, fov_deg: float, aspect: float, cells := 12) -> float:
	var inv := xf.affine_inverse()
	var ty := tan(deg_to_rad(fov_deg) * 0.5)
	var hit := {}
	for p in clutter:
		var q := inv * p
		if q.z > -0.01:
			continue
		var s := Vector2(0.5 + q.x / (-q.z * ty * aspect) * 0.5, 0.5 - q.y / (-q.z * ty) * 0.5)
		if box.has_point(s):
			var c := Vector2i(((s - box.position) / box.size * cells).floor())
			hit[c] = true
	return float(hit.size()) / float(cells * cells)


## World-space vertices of the visible meshes under `root` that aren't skinned
## (rigidly attached gear, stowed weapons), every `stride`-th.
static func rigid_points(root: Node, stride := 1) -> PackedVector3Array:
	var out := PackedVector3Array()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.skin != null or not mi.is_visible_in_tree():
			continue
		for s in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v in range(0, verts.size(), stride):
				out.append(mi.global_transform * verts[v])
	return out
