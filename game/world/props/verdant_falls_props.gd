class_name VerdantFallsProps
extends RefCounted
## Verdant Falls grey-block: giant trees with layered canopies, smaller trees, the lake
## and the waterfall curtain down the north cliff.

const WATERFALL_SHADER := preload("res://game/world/shaders/waterfall.gdshader")


static func build(parent: Node3D, kit: PropKit, zone: ZoneData, layout: ZoneLayout) -> Array[ShaderMaterial]:
	var zi := layout.index_of(zone.id)
	var c := zone.centre
	var bark := kit.material("bark", Color(0.46, 0.32, 0.22), {"strata": 0.3, "strata_spacing": 2.0})
	var leaves := kit.material("leaves", Color(0.3, 0.62, 0.24))
	var trunks: Array[Transform3D] = []
	var canopies: Array[Transform3D] = []
	var leaf_tint := PackedColorArray()
	var trees: Array[Vector3] = []
	var tries := 0
	while trees.size() < 150 and tries < 6000:
		tries += 1
		var giant := trees.size() < 40
		var x := c.x + kit.rng.randf_range(-320.0, 320.0)
		var z := c.y + kit.rng.randf_range(-430.0, 430.0)
		var r := kit.rng.randf_range(4.5, 8.0) if giant else kit.rng.randf_range(1.5, 3.0)
		var spacing := 30.0 if giant else 10.0
		if layout.weights_at(x, z)[zi] < 0.85 or not kit.is_clear(x, z, spacing):
			continue
		var g := kit.ground(x, z)
		if g < 1.5 or kit.roughness(x, z, 4.0) > 5.0:
			continue
		var crowded := false
		for t in trees:
			if Vector2(x - t.x, z - t.z).length() < spacing + t.y * 2.0:
				crowded = true
				break
		if crowded:
			continue
		trees.append(Vector3(x, r, z))
		var h := r * kit.rng.randf_range(11.0, 15.0)
		trunks.append(PropKit.placed(Vector3(x, g - 2.0, z), Vector3(r * 2.0, h, r * 2.0), kit.rng.randf() * TAU))
		# Two flattened canopy layers.
		var w := r * kit.rng.randf_range(8.0, 11.0)
		var tint := kit.jitter(Color(1, 1, 1), 0.15)
		canopies.append(PropKit.placed(Vector3(x, g + h * 0.82, z), Vector3(w, w * 0.32, w), kit.rng.randf() * TAU))
		canopies.append(PropKit.placed(Vector3(x + r, g + h * 0.62, z - r), Vector3(w * 0.75, w * 0.26, w * 0.75), kit.rng.randf() * TAU))
		leaf_tint.append(tint)
		leaf_tint.append(tint * Color(0.85, 0.9, 0.85))
	kit.multimesh(parent, "Trunks", PropKit.cylinder(0.4, 0.5, 8), bark, trunks, PackedColorArray(), "giant_trunk")
	kit.multimesh(parent, "Canopies", PropKit.sphere(9, 4), leaves, canopies, leaf_tint)
	# Waterfall: an inclined curtain from the cliff lip to the lake.
	var unshaded: Array[ShaderMaterial] = []
	for i in zone.landmark_names.size():
		if not zone.landmark_names[i].contains("Falls"):
			continue
		var p := zone.landmark_positions[i]
		var top_z := p.z
		while kit.ground(p.x, top_z + 2.0) > kit.ground(p.x, p.z) - 6.0 and top_z < p.z + 60.0:
			top_z += 2.0
		var bottom_z := top_z
		while kit.ground(p.x, bottom_z) > 1.0 and bottom_z < top_z + 80.0:
			bottom_z += 2.0
		var top := Vector3(p.x, kit.ground(p.x, top_z - 4.0) + 1.0, top_z - 2.0)
		var bottom := Vector3(p.x, -0.5, bottom_z + 6.0)
		var mat := ShaderMaterial.new()
		mat.shader = WATERFALL_SHADER
		var curtain := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var half := 30.0
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([top + Vector3(-half, 0, 0), top + Vector3(half, 0, 0),
			bottom + Vector3(-half * 1.2, 0, 0), bottom + Vector3(half * 1.2, 0, 0)])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2])
		curtain.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var node := kit.single(parent, "Waterfall", curtain, mat, Transform3D.IDENTITY)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_to_group(PropKit.DESTRUCTIBLE_GROUP)
		node.set_meta("destructible", "waterfall_curtain")
		unshaded.append(mat)
		# Spray puffs at the base.
		var mist := kit.material("mist", Color(0.92, 0.97, 1.0), {"rim_strength": 0.0})
		var puffs: Array[Transform3D] = []
		for k in 7:
			var s := kit.rng.randf_range(8.0, 16.0)
			puffs.append(PropKit.placed(bottom + Vector3(kit.rng.randf_range(-24, 24), -s * 0.4, kit.rng.randf_range(-4, 8)), Vector3(s * 1.4, s, s), 0.0))
		kit.multimesh(parent, "Spray", PropKit.sphere(8, 4), mist, puffs, PackedColorArray(), "", false)
	return unshaded
