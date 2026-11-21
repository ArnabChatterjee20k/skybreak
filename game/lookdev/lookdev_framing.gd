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
static func skinned_points(skeleton: Skeleton3D, keep: Callable, stride := 1) -> PackedVector3Array:
	var out := PackedVector3Array()
	for node in skeleton.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.skin == null or not mi.is_visible_in_tree():
			continue
		var baked := mi.bake_mesh_from_current_skeleton_pose()
		if baked == null:
			continue
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var posed: PackedVector3Array = baked.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / maxi(posed.size(), 1)
			if per < 1:
				continue
			var names := {}
			for v in range(0, posed.size(), stride):
				var top := 0
				for j in per:
					if ws[v * per + j] > ws[v * per + top]:
						top = j
				var bind := bones[v * per + top]
				if not names.has(bind):
					var bone := mi.skin.get_bind_bone(bind)
					names[bind] = skeleton.get_bone_name(bone) if bone >= 0 else String(mi.skin.get_bind_name(bind))
				if keep.call(names[bind]):
					out.append(mi.global_transform * posed[v])
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
