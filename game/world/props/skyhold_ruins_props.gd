class_name SkyholdRuinsProps
extends RefCounted
## Skyhold Ruins grey-block: floating stone islands with grass caps, columns and arches.


static func build(parent: Node3D, kit: PropKit, zone: ZoneData, layout: ZoneLayout) -> void:
	var zi := layout.index_of(zone.id)
	var c := zone.centre
	var stone := kit.material("sky_stone", Color(0.72, 0.64, 0.54))
	var grass := kit.material("sky_grass", Color(0.36, 0.62, 0.26))
	var marble := kit.material("sky_marble", Color(0.88, 0.85, 0.78))
	# Islands as spheres (x, y, z, radius) kept apart by tight 14-40 m gaps.
	var islands: Array[Vector4] = []
	for i in zone.landmark_names.size():
		if zone.landmark_names[i].contains("Island"):
			var p := zone.landmark_positions[i]
			islands.append(Vector4(p.x, p.y, p.z, 55.0))
	var tries := 0
	while islands.size() < 34 and tries < 4000:
		tries += 1
		var r := kit.rng.randf_range(12.0, 42.0)
		var x := c.x + kit.rng.randf_range(-300.0, 300.0)
		var z := c.y + kit.rng.randf_range(-380.0, 380.0)
		var y := kit.rng.randf_range(80.0, 230.0)
		if layout.weights_at(x, z)[zi] < 0.85 or not kit.is_clear(x, z, r + 10.0):
			continue
		if y - r * 1.4 < kit.ground(x, z) + 30.0:
			continue
		var ok := true
		for o in islands:
			var gap := Vector2(x - o.x, z - o.z).length() - (r + o.w)
			if gap < 14.0 and absf(y - o.y) < (r + o.w) * 1.2:
				ok = false
				break
		if ok:
			islands.append(Vector4(x, y, z, r))
	var bodies: Array[Transform3D] = []
	var caps: Array[Transform3D] = []
	var columns: Array[Transform3D] = []
	var arches: Array[Transform3D] = []
	var body_tint := PackedColorArray()
	for isl in islands:
		var yaw := kit.rng.randf() * TAU
		var depth := isl.w * kit.rng.randf_range(1.2, 1.7)
		bodies.append(PropKit.placed(Vector3(isl.x, isl.y - depth, isl.z), Vector3(isl.w * 2.0, depth, isl.w * 2.0), yaw))
		body_tint.append(kit.jitter(Color(1, 1, 1), 0.08))
		caps.append(PropKit.placed(Vector3(isl.x, isl.y - 0.2, isl.z), Vector3(isl.w * 2.04, 1.6, isl.w * 2.04), yaw))
		# Ruined colonnade around the rim; some columns broken short.
		var count := int(isl.w / 5.0)
		for k in count:
			var a := yaw + TAU * float(k) / float(count)
			var rr := isl.w * 0.72
			var h := 16.0 if kit.rng.randf() > 0.35 else kit.rng.randf_range(4.0, 10.0)
			columns.append(PropKit.placed(Vector3(isl.x + cos(a) * rr, isl.y + 1.0, isl.z + sin(a) * rr), Vector3(2.6, h, 2.6), a))
		if isl.w > 26.0:
			arches.append(PropKit.placed(Vector3(isl.x, isl.y + 1.0, isl.z), Vector3(18, 20, 4), yaw))
	var body_mesh := PropKit.cylinder(0.5, 0.07, 8)
	kit.multimesh(parent, "IslandBodies", body_mesh, stone, bodies, body_tint, "island_chunk")
	kit.multimesh(parent, "IslandCaps", PropKit.cylinder(0.5, 0.5, 8), grass, caps)
	kit.multimesh(parent, "Columns", PropKit.cylinder(0.45, 0.5, 8), marble, columns, PackedColorArray(), "column")
	var arch := PropKit.merged_boxes([AABB(Vector3(-0.5, 0, -0.5), Vector3(0.18, 0.85, 1)),
		AABB(Vector3(0.32, 0, -0.5), Vector3(0.18, 0.85, 1)), AABB(Vector3(-0.56, 0.82, -0.6), Vector3(1.12, 0.18, 1.2))])
	kit.multimesh(parent, "Arches", arch, marble, arches, PackedColorArray(), "arch")
	parent.set_meta("island_count", islands.size())
