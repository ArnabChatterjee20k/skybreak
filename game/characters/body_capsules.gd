class_name BodyCapsules
extends RefCounted
## A legend's body as capsules on its bones (T-D30), measured once from the rest mesh:
## each capsule's radius covers most of the vertices skinned to its bones. Used by the
## weapon clearance solver and the visual-QA suite, with the shared overlap tests below.

## Capsule name -> [from bone, to bone]; "" as the end bone means the head's own top.
const SEGMENTS := {
	&"pelvis": [&"Hips", &"Chest"],
	&"chest": [&"Chest", &"Neck"],
	&"head": [&"Head", &""],
	&"upper_arm_l": [&"LeftUpperArm", &"LeftLowerArm"],
	&"lower_arm_l": [&"LeftLowerArm", &"LeftHand"],
	&"hand_l": [&"LeftHand", &"LeftMiddleProximal"],
	&"upper_arm_r": [&"RightUpperArm", &"RightLowerArm"],
	&"lower_arm_r": [&"RightLowerArm", &"RightHand"],
	&"hand_r": [&"RightHand", &"RightMiddleProximal"],
	&"thigh_l": [&"LeftUpperLeg", &"LeftLowerLeg"],
	&"shin_l": [&"LeftLowerLeg", &"LeftFoot"],
	&"thigh_r": [&"RightUpperLeg", &"RightLowerLeg"],
	&"shin_r": [&"RightLowerLeg", &"RightFoot"],
}
## Bone -> capsule its vertices count towards (others walk up to their parent).
const BONE_SEGMENT := {
	&"Hips": &"pelvis", &"Spine": &"pelvis", &"Chest": &"chest", &"UpperChest": &"chest",
	&"LeftShoulder": &"chest", &"RightShoulder": &"chest", &"Neck": &"head", &"Head": &"head",
	&"LeftUpperArm": &"upper_arm_l", &"LeftLowerArm": &"lower_arm_l", &"LeftHand": &"hand_l",
	&"RightUpperArm": &"upper_arm_r", &"RightLowerArm": &"lower_arm_r", &"RightHand": &"hand_r",
	&"LeftUpperLeg": &"thigh_l", &"LeftLowerLeg": &"shin_l", &"RightUpperLeg": &"thigh_r",
	&"RightLowerLeg": &"shin_r",
}
## The torso, head and arms: what a held weapon must stay out of.
const UPPER_BODY: Array[StringName] = [&"pelvis", &"chest", &"head", &"upper_arm_l", &"lower_arm_l",
	&"upper_arm_r", &"lower_arm_r"]
## Share of a capsule's vertices inside its radius.
const COVER := 0.6
const MIN_RADIUS := 0.04

## Capsule name -> radius (m), in skeleton space.
var radii := {}
## Capsule name -> [from bone index, to bone index, end offset in the from bone's space].
var bones := {}
## Lowest sole points per foot (in that foot or toe bone's space): [[bone, Vector3], ...].
var soles: Array = []


## Measures a skeleton's capsules from the meshes skinned to it, at the rest pose.
static func measure(skeleton: Skeleton3D, meshes: Array) -> BodyCapsules:
	var body := BodyCapsules.new()
	var rest: Array[Transform3D] = []
	for i in skeleton.get_bone_count():
		rest.append(skeleton.get_bone_global_rest(i))
	var segment_of: Array[StringName] = []
	for i in skeleton.get_bone_count():
		var j := i
		var found := &""
		while j >= 0 and found == &"":
			found = BONE_SEGMENT.get(StringName(skeleton.get_bone_name(j)), &"")
			if found == &"" and String(skeleton.get_bone_name(j)).contains("Hand"):
				found = &"hand_l" if String(skeleton.get_bone_name(j)).begins_with("Left") else &"hand_r"
			j = skeleton.get_bone_parent(j)
		segment_of.append(found)
	var points := {}
	var foot_points := {}
	for name: StringName in SEGMENTS:
		points[name] = []
	var feet := [skeleton.find_bone(&"LeftFoot"), skeleton.find_bone(&"RightFoot"),
		skeleton.find_bone(&"LeftToes"), skeleton.find_bone(&"RightToes")]
	for i in feet:
		foot_points[i] = []
	for node: MeshInstance3D in meshes:
		if node.mesh == null:
			continue
		var to_skeleton := skeleton.global_transform.affine_inverse() * node.global_transform
		var parent_bone := -1
		if node.get_parent() is BoneAttachment3D:
			parent_bone = skeleton.find_bone((node.get_parent() as BoneAttachment3D).bone_name)
		for s in node.mesh.get_surface_count():
			var arrays := node.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bone_ids: Variant = arrays[Mesh.ARRAY_BONES]
			var weights: Variant = arrays[Mesh.ARRAY_WEIGHTS]
			var per := 0
			if bone_ids != null and (bone_ids as PackedInt32Array).size() > 0:
				per = (bone_ids as PackedInt32Array).size() / verts.size()
			var step := maxi(1, verts.size() / 1500)
			for v in range(0, verts.size(), step):
				var bone := parent_bone
				var at := to_skeleton * verts[v]
				if per > 0:
					var best := 0
					for k in per:
						if (weights as PackedFloat32Array)[v * per + k] > (weights as PackedFloat32Array)[v * per + best]:
							best = k
					var bind: int = (bone_ids as PackedInt32Array)[v * per + best]
					if node.skin != null and bind < node.skin.get_bind_count():
						var bound := node.skin.get_bind_bone(bind)
						if bound < 0:
							bound = skeleton.find_bone(node.skin.get_bind_name(bind))
						at = rest[bound] * node.skin.get_bind_pose(bind) * verts[v]
						bind = bound
					bone = bind
				if bone < 0:
					continue
				if foot_points.has(bone):
					(foot_points[bone] as Array).append(at)
				var segment := segment_of[bone]
				if segment != &"":
					(points[segment] as Array).append(at)
	for name: StringName in SEGMENTS:
		var ends: Array = SEGMENTS[name]
		var a := skeleton.find_bone(ends[0])
		if a < 0:
			continue
		var b := skeleton.find_bone(ends[1]) if ends[1] != &"" else -1
		var start := rest[a].origin
		var end := rest[b].origin if b >= 0 else start
		var pts: Array = points[name]
		if b < 0:
			# The head: up to its highest vertex, less the radius.
			var top := start.y
			for p in pts:
				top = maxf(top, p.y)
			end = start + Vector3.UP * maxf(top - start.y, 0.0)
		var distances := PackedFloat32Array()
		for p: Vector3 in pts:
			distances.append(_point_segment(p, start, end))
		distances.sort()
		var radius := distances[int(distances.size() * COVER)] if distances.size() > 8 else MIN_RADIUS
		radius = maxf(radius, MIN_RADIUS)
		if b < 0:
			end = start + Vector3.UP * maxf(end.y - start.y - radius, 0.01)
		body.radii[name] = radius
		var offset := rest[a].affine_inverse() * end
		body.bones[name] = [a, b, offset]
	for i in feet:
		if i < 0:
			continue
		var pts: Array = foot_points[i]
		var low := INF
		for p in pts:
			low = minf(low, p.y)
		for p in pts:
			if p.y < low + 0.03:
				body.soles.append([i, rest[i].affine_inverse() * p])
	return body


## World capsules for the current pose: name -> [a, b, radius]. pose(bone) gives a bone's
## transform in `space` (e.g. Skeleton3D.get_bone_global_pose and its global_transform).
func capsules(pose: Callable, space: Transform3D, names: Array = []) -> Dictionary:
	var out := {}
	for name: StringName in bones:
		if not names.is_empty() and not names.has(name):
			continue
		var entry: Array = bones[name]
		var from: Transform3D = pose.call(entry[0])
		var a := space * from.origin
		var b := space * ((pose.call(entry[1]) as Transform3D).origin if entry[1] >= 0 else from * (entry[2] as Vector3))
		out[name] = [a, b, float(radii[name])]
	return out


## Lowest world height of the soles for the current pose.
func lowest_sole(pose: Callable, space: Transform3D) -> Vector3:
	var best := Vector3(0, INF, 0)
	for item: Array in soles:
		var p := space * ((pose.call(item[0]) as Transform3D) * (item[1] as Vector3))
		if p.y < best.y:
			best = p
	return best


static func _point_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	return p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, b))


## How deep box (a transform of the unit cube) reaches into capsule a-b of radius r, and the
## direction that moves the box out: [depth, push, contact point]. depth <= 0 means clear.
static func box_depth(a: Vector3, b: Vector3, r: float, box: Transform3D) -> Array:
	var inverse := box.affine_inverse()
	var deepest := -INF
	var push := Vector3.ZERO
	var contact := box.origin
	var half := Vector3(box.basis.x.length(), box.basis.y.length(), box.basis.z.length())
	var samples := 9
	# Sampled in the box's space (affine, so the samples land on the same segment points).
	var local_a := inverse * a
	var local_b := inverse * b
	for k in samples:
		var p := a.lerp(b, float(k) / (samples - 1))
		var local := local_a.lerp(local_b, float(k) / (samples - 1))
		var clamped := local.clamp(-Vector3.ONE, Vector3.ONE)
		var depth: float
		var direction: Vector3
		var at := p
		if clamped.is_equal_approx(local):
			# Inside: the distance to the nearest face, pushed out through it.
			var room := (Vector3.ONE - local.abs()) * half
			var axis := room.min_axis_index()
			depth = r + room[axis]
			var out := Vector3.ZERO
			out[axis] = -signf(local[axis]) if local[axis] != 0.0 else 1.0
			direction = (box.basis * out).normalized()
		else:
			var q := box * clamped
			depth = r - p.distance_to(q)
			direction = (q - p).normalized()
			at = q
		if depth > deepest:
			deepest = depth
			push = direction
			contact = at
	return [deepest, push, contact]


## Overlap of two capsules (m); <= 0 when apart.
static func capsule_depth(a: Array, b: Array) -> float:
	var closest := Geometry3D.get_closest_points_between_segments(a[0], a[1], b[0], b[1])
	return float(a[2]) + float(b[2]) - closest[0].distance_to(closest[1])


## Whether segment p-q passes through capsule c ([a, b, r]); depth (m), <= 0 when clear.
static func segment_depth(p: Vector3, q: Vector3, c: Array) -> float:
	var closest := Geometry3D.get_closest_points_between_segments(p, q, c[0], c[1])
	return float(c[2]) - closest[0].distance_to(closest[1])


## Deepest overlap of boxes with capsules ({name: [a, b, r]}):
## [depth, push, capsule name, contact point, the overlapping box's centre].
## Same result as box_depth over every pair near enough, with the box sizes and inverses shared.
static func deepest_box(capsule_set: Dictionary, boxes: Array[Transform3D]) -> Array:
	var result := [-INF, Vector3.ZERO, &"", Vector3.ZERO, Vector3.ZERO]
	var count := boxes.size()
	if count == 0:
		return result
	var reaches := PackedFloat32Array()
	reaches.resize(count)
	var centre := Vector3.ZERO
	for i in count:
		var box := boxes[i]
		reaches[i] = box.basis.x.length() + box.basis.y.length() + box.basis.z.length()
		centre += box.origin
	centre /= count
	# A sphere round every box's own sphere: a capsule clear of it is clear of every box.
	var bound := 0.0
	for i in count:
		bound = maxf(bound, centre.distance_to(boxes[i].origin) + reaches[i])
	bound += 1e-3
	var inverses: Array = []
	inverses.resize(count)
	var best := -INF
	for name: StringName in capsule_set:
		var c: Array = capsule_set[name]
		var a: Vector3 = c[0]
		var b: Vector3 = c[1]
		var r: float = c[2]
		if _point_segment(centre, a, b) > bound + r:
			continue
		for i in count:
			var box := boxes[i]
			if _point_segment(box.origin, a, b) > reaches[i] + r:
				continue
			var inverse: Transform3D
			if inverses[i] == null:
				inverse = box.affine_inverse()
				inverses[i] = inverse
			else:
				inverse = inverses[i]
			var half := Vector3(box.basis.x.length(), box.basis.y.length(), box.basis.z.length())
			var deepest := -INF
			var push := Vector3.ZERO
			var contact := box.origin
			var local_a := inverse * a
			var local_b := inverse * b
			for k in 9:
				var p := a.lerp(b, float(k) / 8)
				var local := local_a.lerp(local_b, float(k) / 8)
				var clamped := local.clamp(-Vector3.ONE, Vector3.ONE)
				var depth: float
				if clamped.is_equal_approx(local):
					var room := (Vector3.ONE - local.abs()) * half
					var axis := room.min_axis_index()
					depth = r + room[axis]
					if depth > deepest:
						var out := Vector3.ZERO
						out[axis] = -signf(local[axis]) if local[axis] != 0.0 else 1.0
						deepest = depth
						push = (box.basis * out).normalized()
						contact = p
				else:
					var q := box * clamped
					depth = r - p.distance_to(q)
					if depth > deepest:
						deepest = depth
						push = (q - p).normalized()
						contact = q
			if deepest > best:
				best = deepest
				result = [deepest, push, name, contact, box.origin]
	return result
