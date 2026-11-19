class_name FrozenPeaksProps
extends RefCounted
## Frozen Peaks grey-block: ice spires along the glacier valley, ice shelves jutting from
## the cliffs, ice boulders.


static func build(parent: Node3D, kit: PropKit, zone: ZoneData, layout: ZoneLayout) -> void:
	var zi := layout.index_of(zone.id)
	var c := zone.centre
	var ice := kit.material("ice", Color(0.72, 0.88, 1.0), {"rim_strength": 0.5, "rim_color": Color(0.8, 0.95, 1.0)})
	var slab := kit.material("ice_slab", Color(0.86, 0.94, 1.0), {"strata": 0.5, "strata_spacing": 1.5})
	var spires: Array[Transform3D] = []
	var shelves: Array[Transform3D] = []
	var boulders: Array[Transform3D] = []
	var tries := 0
	while spires.size() < 60 and tries < 4000:
		tries += 1
		var x := c.x + kit.rng.randf_range(-330.0, 330.0)
		var z := c.y + kit.rng.randf_range(-420.0, 420.0)
		if layout.weights_at(x, z)[zi] < 0.85 or not kit.is_clear(x, z, 8.0):
			continue
		var g := kit.ground(x, z)
		if g > 140.0 or kit.roughness(x, z, 5.0) > 8.0:
			continue
		var r := kit.rng.randf_range(4.0, 10.0)
		spires.append(PropKit.placed(Vector3(x, g - 3.0, z), Vector3(r * 2.0, kit.rng.randf_range(22.0, 62.0), r * 2.0),
			kit.rng.randf() * TAU, Vector3(kit.rng.randf_range(-0.2, 0.2), 0, kit.rng.randf_range(-0.2, 0.2))))
	tries = 0
	while shelves.size() < 26 and tries < 6000:
		tries += 1
		var x := c.x + kit.rng.randf_range(-330.0, 330.0)
		var z := c.y + kit.rng.randf_range(-420.0, 420.0)
		if layout.weights_at(x, z)[zi] < 0.85:
			continue
		var g := kit.ground(x, z)
		var dx := kit.ground(x + 6.0, z) - kit.ground(x - 6.0, z)
		var dz := kit.ground(x, z + 6.0) - kit.ground(x, z - 6.0)
		var grade := Vector2(dx, dz) / 12.0
		if g < 100.0 or grade.length() < 1.0:
			continue
		# Shelf juts out downhill from the cliff face.
		var out := -grade.normalized()
		var yaw := atan2(-out.y, out.x)
		var size := Vector3(kit.rng.randf_range(26.0, 44.0), 4.0, kit.rng.randf_range(16.0, 26.0))
		shelves.append(PropKit.placed(Vector3(x + out.x * size.x * 0.3, g - 2.0, z + out.y * size.x * 0.3), size, yaw))
	tries = 0
	while boulders.size() < 120 and tries < 3000:
		tries += 1
		var x := c.x + kit.rng.randf_range(-330.0, 330.0)
		var z := c.y + kit.rng.randf_range(-420.0, 420.0)
		if layout.weights_at(x, z)[zi] < 0.7 or not kit.is_clear(x, z, 4.0):
			continue
		var s := kit.rng.randf_range(2.5, 8.0)
		boulders.append(PropKit.placed(Vector3(x, kit.ground(x, z) - s * 0.3, z), Vector3(s * 1.3, s, s * 1.1), kit.rng.randf() * TAU))
	kit.multimesh(parent, "IceSpires", PropKit.cylinder(0.0, 0.5, 6), ice, spires, PackedColorArray(), "ice_spire")
	kit.multimesh(parent, "IceShelves", PropKit.box(), slab, shelves, PackedColorArray(), "avalanche_slab")
	kit.multimesh(parent, "IceBoulders", PropKit.sphere(6, 3), ice, boulders, PackedColorArray(), "", false)
