class_name EmberRiftProps
extends RefCounted
## Ember Rift grey-block: obsidian spires in and around the crater, glowing geyser vents,
## and lava fissures across the floor around the fight spawns.

## Meta on the zone's prop group: the fissure strips' transforms, drawn by the Lava plane node.
const FISSURES_META := &"lava_fissures"
## Fissure chains per spawn area, segments per chain, and one segment's length and width (m).
const FISSURE_CHAINS := 7
const FISSURE_SEGMENTS := 6
const FISSURE_LENGTH := 6.5
const FISSURE_WIDTH := 2.4
## Chains start this far (m) from the spawns' midpoint, so the duel's floor reads as volcanic.
const FISSURE_NEAR := 9.0
const FISSURE_FAR := 38.0
## No segment within this far (m) of a spawn point, so nobody starts the round on one.
const FISSURE_SPAWN_CLEARANCE := 1.5
## Segments only go where the floor under them varies less than this (m).
const FISSURE_ROUGHNESS := 0.9
## A segment lies on the floor this far above its highest corner (m).
const FISSURE_LIFT := 0.04


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
	_fissures(parent, kit, zone)


## Molten seams in chains around the spawns' midpoint: flat strips laid on smooth floor,
## each turned a little from the last so a chain wanders like a crack. Stored as a meta on
## parent; WorldMap draws them as extra instances of the Lava plane (no new prop node).
static func _fissures(parent: Node3D, kit: PropKit, zone: ZoneData) -> void:
	var transforms: Array[Transform3D] = []
	parent.set_meta(FISSURES_META, transforms)
	if zone.spawn_points.is_empty():
		return
	var middle := Vector3.ZERO
	for point in zone.spawn_points:
		middle += point / zone.spawn_points.size()
	for chain in FISSURE_CHAINS:
		var angle := TAU * (chain + kit.rng.randf_range(0.15, 0.85)) / FISSURE_CHAINS
		var at := Vector2(middle.x, middle.z) + Vector2(cos(angle), sin(angle)) * kit.rng.randf_range(FISSURE_NEAR, FISSURE_FAR * 0.5)
		var heading := angle + kit.rng.randf_range(-0.9, 0.9)
		for segment in FISSURE_SEGMENTS:
			heading += kit.rng.randf_range(-0.45, 0.45)
			var along := Vector2(cos(heading), sin(heading))
			var centre := at + along * FISSURE_LENGTH * 0.45
			at += along * FISSURE_LENGTH * 0.9
			if centre.distance_to(Vector2(middle.x, middle.z)) > FISSURE_FAR \
					or kit.roughness(centre.x, centre.y, FISSURE_LENGTH * 0.5) > FISSURE_ROUGHNESS \
					or _near_spawn(centre, zone.spawn_points):
				continue
			var top := kit.ground(centre.x, centre.y)
			for corner in [along * FISSURE_LENGTH * 0.5, -along * FISSURE_LENGTH * 0.5]:
				top = maxf(top, kit.ground(centre.x + corner.x, centre.y + corner.y))
			var basis := Basis(Vector3.UP, -heading).scaled_local(Vector3(FISSURE_LENGTH, 1.0, FISSURE_WIDTH))
			transforms.append(Transform3D(basis, Vector3(centre.x, top + FISSURE_LIFT, centre.y)))


static func _near_spawn(at: Vector2, spawns: PackedVector3Array) -> bool:
	for point in spawns:
		if at.distance_to(Vector2(point.x, point.z)) < FISSURE_SPAWN_CLEARANCE + FISSURE_LENGTH * 0.5:
			return true
	return false
