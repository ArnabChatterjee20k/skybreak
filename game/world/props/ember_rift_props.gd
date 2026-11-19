class_name EmberRiftProps
extends RefCounted
## Ember Rift grey-block: obsidian spires in and around the crater, glowing geyser vents.


static func build(parent: Node3D, kit: PropKit, zone: ZoneData, layout: ZoneLayout) -> void:
	var zi := layout.index_of(zone.id)
	var c := zone.centre
	var obsidian := kit.material("obsidian", Color(0.16, 0.13, 0.18), {"rim_strength": 0.45, "rim_color": Color(1.0, 0.45, 0.2)})
	var vent_mat := kit.material("vent", Color(0.2, 0.09, 0.06), {"emission_color": Color(1.0, 0.32, 0.06), "emission_strength": 0.7, "strata": 0.6, "strata_spacing": 0.8})
	var spires: Array[Transform3D] = []
	var vents: Array[Transform3D] = []
	var tries := 0
	while spires.size() < 55 and tries < 4000:
		tries += 1
		var x := c.x + kit.rng.randf_range(-330.0, 330.0)
		var z := c.y + kit.rng.randf_range(-420.0, 420.0)
		if layout.weights_at(x, z)[zi] < 0.85 or not kit.is_clear(x, z, 8.0):
			continue
		var g := kit.ground(x, z)
		if g < 33.0 or kit.roughness(x, z, 5.0) > 10.0:
			continue
		var r := kit.rng.randf_range(3.0, 8.0)
		spires.append(PropKit.placed(Vector3(x, g - 2.0, z), Vector3(r * 2.0, kit.rng.randf_range(24.0, 70.0), r * 2.0),
			kit.rng.randf() * TAU, Vector3(kit.rng.randf_range(-0.15, 0.15), 0, kit.rng.randf_range(-0.15, 0.15))))
	tries = 0
	while vents.size() < 10 and tries < 2000:
		tries += 1
		var a := kit.rng.randf() * TAU
		var d := kit.rng.randf_range(60.0, 180.0)
		var x := c.x + cos(a) * d
		var z := c.y + sin(a) * d
		var g := kit.ground(x, z)
		if g < 33.0 or not kit.is_clear(x, z, 10.0):
			continue
		vents.append(PropKit.placed(Vector3(x, g - 1.0, z), Vector3(9, 3.5, 9), 0.0))
	kit.multimesh(parent, "ObsidianSpires", PropKit.cylinder(0.0, 0.5, 5), obsidian, spires, PackedColorArray(), "obsidian_spire")
	var vent_node := kit.multimesh(parent, "GeyserVents", PropKit.cylinder(0.35, 0.5, 8), vent_mat, vents, PackedColorArray(), "geyser_vent", false)
	vent_node.set_meta("hazard", "lava_geyser")
