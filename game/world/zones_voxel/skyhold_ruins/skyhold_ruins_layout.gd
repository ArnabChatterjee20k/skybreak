class_name SkyholdRuinsLayout
extends RefCounted
## The sim's Skyhold Ruins layout, read back from the grey-block builder
## (SkyholdRuinsProps with PropKit seed 4242, as ZoneMatch builds it with
## focus_zone set), so the voxel pass sits exactly on the islands, columns and
## arches the game places. Nothing here changes the sim.

## One island: centre top (x, top, z), radius, underside depth and yaw.
class Island:
	var centre := Vector2.ZERO
	var top := 0.0
	var radius := 0.0
	var depth := 0.0
	var yaw := 0.0
	var name := ""
	var columns: Array[Dictionary] = []  # {at: Vector3 base, height, angle}
	var arch := false

var islands: Array[Island] = []
var zone: ZoneData
var heightmap: TerrainHeightmap
var layout: ZoneLayout


static func read() -> SkyholdRuinsLayout:
	var out := SkyholdRuinsLayout.new()
	out._read()
	return out


func _read() -> void:
	heightmap = load(WorldMap.HEIGHTMAP_PATH) as TerrainHeightmap
	layout = ZoneLayout.load_default()
	zone = load("res://game/world/zones/skyhold_ruins.tres") as ZoneData
	var kit := PropKit.new(heightmap, WorldMap.PROP_SEED)
	for zd in layout.ground_zones():
		for p in zd.spawn_points:
			kit.keep_clear.append(Vector3(p.x, p.z, WorldMap.SPAWN_CLEAR_RADIUS))
	var scratch := Node3D.new()
	SkyholdRuinsProps.build(scratch, kit, zone, layout)
	var bodies: Array = _transforms(scratch, "IslandBodies")
	var columns: Array = _transforms(scratch, "Columns")
	var arches: Array = _transforms(scratch, "Arches")
	scratch.free()
	for t: Transform3D in bodies:
		var isl := Island.new()
		var s := t.basis.get_scale()
		isl.radius = s.x * 0.5
		isl.depth = s.y
		isl.top = t.origin.y + s.y * 0.5
		isl.centre = Vector2(t.origin.x, t.origin.z)
		var xa := t.basis.x.normalized()
		isl.yaw = atan2(-xa.z, xa.x)
		islands.append(isl)
	for i in zone.landmark_names.size():
		var p := zone.landmark_positions[i]
		for isl in islands:
			if isl.centre.distance_to(Vector2(p.x, p.z)) < 1.0:
				isl.name = zone.landmark_names[i]
	for t: Transform3D in columns:
		var base := t.origin - t.basis.y * 0.5
		var isl := _owner(base)
		var xa := t.basis.x.normalized()
		isl.columns.append({"at": base, "height": t.basis.get_scale().y, "angle": atan2(-xa.z, xa.x)})
	for t: Transform3D in arches:
		# An arch's origin sits 11 m over its island's top, at the centre.
		var best: Island = islands[0]
		for isl in islands:
			var e := absf(t.origin.y - 11.0 - isl.top) + Vector2(t.origin.x, t.origin.z).distance_to(isl.centre)
			if e < absf(t.origin.y - 11.0 - best.top) + Vector2(t.origin.x, t.origin.z).distance_to(best.centre):
				best = isl
		best.arch = true


## The island a column stands on: its base sits 1 m over that island's top,
## at 0.72 r from its centre (islands can stack, so the nearest centre isn't enough).
func _owner(base: Vector3) -> Island:
	var best: Island = islands[0]
	var best_err := INF
	for isl in islands:
		var err := absf(base.y - isl.top - 1.0) * 10.0 \
			+ absf(Vector2(base.x, base.z).distance_to(isl.centre) - isl.radius * 0.72)
		if err < best_err:
			best_err = err
			best = isl
	return best


func nearest(p: Vector2) -> Island:
	var best: Island = islands[0]
	for isl in islands:
		if isl.centre.distance_to(p) < best.centre.distance_to(p):
			best = isl
	return best


func named(n: String) -> Island:
	for isl in islands:
		if isl.name == n:
			return isl
	return null


static func _transforms(root: Node3D, node_name: String) -> Array:
	var node := root.get_node_or_null(node_name)
	if node == null:
		return []
	return node.get_meta(PropKit.INSTANCE_TRANSFORMS_META, [])
