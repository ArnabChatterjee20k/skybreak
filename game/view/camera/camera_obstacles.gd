class_name CameraObstacles
extends RefCounted
## What the fight camera must not sit inside or look through (issue #75): the
## zone's terrain (ZoneGround heights) and its props (one box per prop
## instance, small clutter skipped). Built once per match; queried every frame.
## Props are MultiMeshes, so they can't be faded one by one: the camera pulls
## in front of them instead.

## Cell size of the prop lookup grid (m).
const CELL := 10.0
## Props smaller than this are clutter (grass, petals) and don't block.
const MIN_HEIGHT := 1.0
const MIN_WIDTH := 0.8
## Keep the camera this far from a prop box and above the ground (m).
const CLEARANCE := 0.4
## Terrain samples along a pivot-to-camera segment.
const TERRAIN_SAMPLES := 12

## func(x, z, from_y) -> ground height; null means no terrain.
var ground_height: Callable
var boxes: Array[AABB] = []
var _grid: Dictionary = {}


## Obstacles of a zone_match: its ZoneGround and its zone's prop group.
static func from_zone_match(zone_match: Node) -> CameraObstacles:
	var obstacles := CameraObstacles.new()
	obstacles.ground_height = zone_match.ground.height_at
	var props: Node = zone_match.world.props
	var centre: Vector2 = zone_match.sim.arena_centre
	var reach: float = zone_match.sim.tuning.arena_half_size + 40.0
	for group in props.get_children():
		obstacles.add_props(group, centre, reach)
	return obstacles


## Adds one box per prop instance under root within reach of centre (planar).
func add_props(root: Node, centre: Vector2, reach: float) -> void:
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		if node is MultiMeshInstance3D:
			var mmi := node as MultiMeshInstance3D
			var mm := mmi.multimesh
			if mm == null or mm.mesh == null:
				continue
			var mesh_box := mm.mesh.get_aabb()
			if mmi.has_meta(PropKit.INSTANCE_TRANSFORMS_META):
				for xform: Transform3D in mmi.get_meta(PropKit.INSTANCE_TRANSFORMS_META):
					_add_box(mmi.global_transform * xform * mesh_box, centre, reach)
			else:
				for i in mm.instance_count:
					_add_box(mmi.global_transform * mm.get_instance_transform(i) * mesh_box, centre, reach)
		elif node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mi := node as MeshInstance3D
			_add_box(mi.global_transform * mi.mesh.get_aabb(), centre, reach)


func add_box(box: AABB) -> void:
	_add_box(box, Vector2.ZERO, INF)


func _add_box(box: AABB, centre: Vector2, reach: float) -> void:
	if box.size.y < MIN_HEIGHT or maxf(box.size.x, box.size.z) < MIN_WIDTH:
		return
	var middle := box.get_center()
	if Vector2(middle.x, middle.z).distance_to(centre) > reach + box.size.length() * 0.5:
		return
	var index := boxes.size()
	boxes.append(box)
	for cx in range(floori(box.position.x / CELL), floori(box.end.x / CELL) + 1):
		for cz in range(floori(box.position.z / CELL), floori(box.end.z / CELL) + 1):
			var key := Vector2i(cx, cz)
			# Packed arrays are values: append to the stored one, not a copy.
			var cell: PackedInt32Array = _grid.get(key, PackedInt32Array())
			cell.append(index)
			_grid[key] = cell


## Ground height under point (terrain or an island top below it).
func ground_at(point: Vector3) -> float:
	if not ground_height.is_valid():
		return -INF
	return ground_height.call(point.x, point.z, point.y)


## True when point is below the ground or inside a prop box.
func is_inside(point: Vector3) -> bool:
	if point.y < ground_at(point):
		return true
	for index in _candidates(point, point):
		if boxes[index].has_point(point):
			return true
	return false


## True when terrain or a prop (the player is not inside) lies between them.
func blocks(from: Vector3, to: Vector3) -> bool:
	return clear_fraction(from, to, 0.0) < 0.999


## Fraction (0..1) of the way from pivot toward camera that is clear, keeping
## clearance. Boxes containing the pivot are ignored (flying through a canopy).
func clear_fraction(pivot: Vector3, camera: Vector3, clearance: float = CLEARANCE) -> float:
	var segment := camera - pivot
	var length := segment.length()
	if length < 0.001:
		return 1.0
	var best := 1.0
	for index in _candidates(pivot, camera):
		var box := boxes[index].grow(clearance)
		if box.has_point(pivot):
			continue
		var hit = box.intersects_segment(pivot, camera)
		if hit != null:
			best = minf(best, pivot.distance_to(hit) / length)
	if ground_height.is_valid():
		for s in range(1, TERRAIN_SAMPLES + 1):
			var f := float(s) / TERRAIN_SAMPLES
			if f >= best:
				break
			var point := pivot + segment * f
			if point.y < ground_at(point) + clearance:
				best = minf(best, float(s - 1) / TERRAIN_SAMPLES)
				break
	return best


func _candidates(a: Vector3, b: Vector3) -> PackedInt32Array:
	var found := PackedInt32Array()
	var seen := {}
	for cx in range(floori(minf(a.x, b.x) / CELL), floori(maxf(a.x, b.x) / CELL) + 1):
		for cz in range(floori(minf(a.z, b.z) / CELL), floori(maxf(a.z, b.z) / CELL) + 1):
			var key := Vector2i(cx, cz)
			if not _grid.has(key):
				continue
			for index in _grid[key]:
				if not seen.has(index):
					seen[index] = true
					found.append(index)
	return found
