class_name ShatteredMesaProps
extends RefCounted
## Shattered Mesa grey-block: hoodoo pillars on the open floor, boulders, arch bridges.


static func build(parent: Node3D, kit: PropKit, zone: ZoneData, layout: ZoneLayout) -> void:
	var zi := layout.index_of(zone.id)
	var c := zone.centre
	var rock := kit.material("mesa_rock", Color(0.74, 0.34, 0.2), {"strata": 0.8, "strata_spacing": 3.5})
	var pillars: Array[Transform3D] = []
	var boulders: Array[Transform3D] = []
	var tint := PackedColorArray()
	var boulder_tint := PackedColorArray()
	var tries := 0
	while pillars.size() < 46 and tries < 2000:
		tries += 1
		var x := c.x + kit.rng.randf_range(-320.0, 320.0)
		var z := c.y + kit.rng.randf_range(-420.0, 420.0)
		if layout.index_at(x, z) != zi or layout.weights_at(x, z)[zi] < 0.9:
			continue
		var g := kit.ground(x, z)
		if g > 30.0 or kit.roughness(x, z, 6.0) > 4.0 or not kit.is_clear(x, z, 10.0):
			continue
		var r := kit.rng.randf_range(3.5, 8.0)
		var h := kit.rng.randf_range(28.0, 72.0)
		pillars.append(PropKit.placed(Vector3(x, g - 2.0, z), Vector3(r * 2.0, h, r * 2.0), kit.rng.randf() * TAU,
			Vector3(kit.rng.randf_range(-0.06, 0.06), 0.0, kit.rng.randf_range(-0.06, 0.06))))
		tint.append(kit.jitter(Color(1, 1, 1), 0.1))
	tries = 0
	while boulders.size() < 220 and tries < 3000:
		tries += 1
		var x := c.x + kit.rng.randf_range(-330.0, 330.0)
		var z := c.y + kit.rng.randf_range(-430.0, 430.0)
		if layout.weights_at(x, z)[zi] < 0.7 or not kit.is_clear(x, z, 4.0):
			continue
		var s := kit.rng.randf_range(2.0, 7.0)
		boulders.append(PropKit.placed(Vector3(x, kit.ground(x, z) - s * 0.3, z), Vector3(s * 1.4, s, s * 1.2), kit.rng.randf() * TAU))
		boulder_tint.append(kit.jitter(Color(0.95, 0.85, 0.8), 0.12))
	var hoodoo := PropKit.cylinder(0.62, 0.5, 7)
	kit.multimesh(parent, "MesaPillars", hoodoo, rock, pillars, tint, "rock_pillar")
	kit.multimesh(parent, "MesaBoulders", PropKit.sphere(6, 3), rock, boulders, boulder_tint, "", false)
	# Natural arches spanning canyons: landmark rock bridges.
	var arch := PropKit.merged_boxes([AABB(Vector3(-0.5, 0, -0.08), Vector3(0.16, 0.8, 0.16)),
		AABB(Vector3(0.34, 0, -0.08), Vector3(0.16, 0.8, 0.16)), AABB(Vector3(-0.55, 0.72, -0.1), Vector3(1.1, 0.28, 0.2))])
	var arches: Array[Transform3D] = []
	for i in zone.landmark_names.size():
		if zone.landmark_names[i].contains("Arch"):
			var p := zone.landmark_positions[i]
			arches.append(PropKit.placed(Vector3(p.x, kit.ground(p.x, p.z) - 4.0, p.z), Vector3(90, 70, 40), p.y))
	kit.multimesh(parent, "MesaArches", arch, rock, arches, PackedColorArray(), "rock_arch")
