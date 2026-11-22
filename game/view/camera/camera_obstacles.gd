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
## Wider voxel meshes (m) are terrain chunks or backdrop, left to ground_height.
const VOXEL_MAX_WIDTH := 25.0
## Taller voxel props (m), trees and spires, are mostly air inside their box: as
## boxes they push the camera off good framing for nothing, so they're left out.
const VOXEL_MAX_HEIGHT := 6.0
## Keep the camera this far from a prop box and above the ground (m).
const CLEARANCE := 0.4
## Terrain samples along a pivot-to-camera segment.
const TERRAIN_SAMPLES := 12
## Meta on the merged island mesh (HeartbloomProps).
const ISLANDS_META := &"islands"

## func(x, z, from_y) -> ground height; null means no terrain.
var ground_height: Callable
## Floating island bodies (tops and undersides); null when the zone has none.
var islands: IslandField
## The visible voxel floor where it stands above ground_height; null without voxel art.
var voxel_floor: CameraFloor
var boxes: Array[AABB] = []
## Other fighters' bodies this frame (set_bodies); the camera pulls in front of them too.
var bodies: Array[AABB] = []
## The locked target's body: never on the boom (pulling in front of it loses
## them beside the lens); the camera only keeps out of it. Empty when unset.
var target_body := AABB()
var _grid: Dictionary = {}


## Obstacles of a zone_match: its ZoneGround and its zone's prop group.
static func from_zone_match(zone_match: Node) -> CameraObstacles:
	var obstacles := CameraObstacles.new()
	obstacles.ground_height = zone_match.ground.height_at
	obstacles.islands = zone_match.world.islands
	var props: Node = zone_match.world.props
	var centre: Vector2 = zone_match.sim.arena_centre
	var reach: float = zone_match.sim.tuning.arena_half_size + 40.0
	for group in props.get_children():
		obstacles.add_props(group, centre, reach)
	# Voxel art: the classic props are hidden, the voxel zone's own props are what's seen.
	var voxel: VoxelZoneView = zone_match.get("voxel_zone")
	if voxel != null and voxel.zone != null:
		obstacles.add_voxel_props(voxel.zone, centre, reach)
		obstacles.voxel_floor = CameraFloor.from_zone(voxel.zone, centre, reach)
	return obstacles


## Adds one box per low solid voxel prop copy (and per small solid mesh) of a
## voxel zone: ferns, boulders, crates. Terrain chunks and backdrop slabs wider than
## VOXEL_MAX_WIDTH are the ground's (ground_height); see VOXEL_MAX_HEIGHT.
func add_voxel_props(zone: Node, centre: Vector2, reach: float) -> void:
	for node in zone.find_children("*", "GeometryInstance3D", true, false):
		if node is MultiMeshInstance3D:
			var mmi := node as MultiMeshInstance3D
			var mm := mmi.multimesh
			if mm == null or mm.mesh == null or not FlightClearance._solid(mmi, mm.mesh):
				continue
			var mesh_box := mm.mesh.get_aabb()
			if mmi.has_meta(PropKit.INSTANCE_TRANSFORMS_META):
				for xform: Transform3D in mmi.get_meta(PropKit.INSTANCE_TRANSFORMS_META):
					_add_voxel_box(mmi.global_transform * xform * mesh_box, centre, reach)
			else:
				for i in mm.instance_count:
					_add_voxel_box(mmi.global_transform * mm.get_instance_transform(i) * mesh_box, centre, reach)
		elif node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mi := node as MeshInstance3D
			if FlightClearance._solid(mi, mi.mesh):
				_add_voxel_box(mi.global_transform * mi.mesh.get_aabb(), centre, reach)


func _add_voxel_box(box: AABB, centre: Vector2, reach: float) -> void:
	if maxf(box.size.x, box.size.z) <= VOXEL_MAX_WIDTH and box.size.y <= VOXEL_MAX_HEIGHT:
		_add_box(box, centre, reach)


## Adds one box per prop instance under root within reach of centre (planar).
func add_props(root: Node, centre: Vector2, reach: float) -> void:
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		# One merged mesh for every island: its box spans the zone; islands covers it.
		if islands != null and node.has_meta(ISLANDS_META):
			continue
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
	var ground: float = ground_height.call(point.x, point.z, point.y) if ground_height.is_valid() else -INF
	if voxel_floor != null:
		ground = maxf(ground, voxel_floor.height_at(point.x, point.z, point.y))
	return ground


## Highest ground within radius of point (centre and 8 around it): on a steep
## bank the floor beside the lens is nearer than the floor straight below.
func ground_near(point: Vector3, radius: float = CLEARANCE) -> float:
	var top := ground_at(point)
	if top == -INF:
		return top
	for k in 8:
		var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 8.0) * radius
		top = maxf(top, ground_at(point + d))
	return top


## True when point is below the ground or inside a prop box.
func is_inside(point: Vector3) -> bool:
	if point.y < ground_at(point):
		return true
	if _in_island(point, _islands_near(point, point)):
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
	var lift := Vector3.UP * clearance
	var near := _islands_near(pivot, camera)
	if ground_height.is_valid() or not near.is_empty():
		for s in range(1, TERRAIN_SAMPLES + 1):
			var f := float(s) / TERRAIN_SAMPLES
			if f >= best:
				break
			var point := pivot + segment * f
			var in_island := _in_island(point - lift, near) or _in_island(point + lift, near)
			if in_island or point.y < ground_at(point) + clearance:
				best = minf(best, float(s - 1) / TERRAIN_SAMPLES)
				break
	return best


## Replaces the fighter bodies: upright boxes of `size` centred on each of `centres`.
func set_bodies(centres: PackedVector3Array, size: Vector3) -> void:
	bodies.clear()
	for centre in centres:
		bodies.append(AABB(centre - size * 0.5, size))


## Sets the locked target's body (an upright box of size centred on centre).
func set_target_body(centre: Vector3, size: Vector3) -> void:
	target_body = AABB(centre - size * 0.5, size)


## The point moved out of the target's body (grown by clearance) the shortest
## way: up over its head or out through a side; unchanged when outside.
func out_of_target(point: Vector3, clearance: float = CLEARANCE) -> Vector3:
	if not target_body.has_volume():
		return point
	var box := target_body.grow(clearance)
	if not box.has_point(point):
		return point
	var exits: Array[Vector3] = [
		Vector3(point.x, box.end.y + 0.01, point.z),
		Vector3(box.position.x - 0.01, point.y, point.z), Vector3(box.end.x + 0.01, point.y, point.z),
		Vector3(point.x, point.y, box.position.z - 0.01), Vector3(point.x, point.y, box.end.z + 0.01)]
	var best := exits[0]
	for e in exits:
		if point.distance_to(e) < point.distance_to(best) and not is_inside(e):
			best = e
	return best


## Like clear_fraction, for the fighter bodies only; a body around the pivot is ignored.
func body_clear_fraction(pivot: Vector3, camera: Vector3, clearance: float = CLEARANCE) -> float:
	var length := pivot.distance_to(camera)
	if length < 0.001:
		return 1.0
	var best := 1.0
	for body in bodies:
		var box := body.grow(clearance)
		if box.has_point(pivot):
			continue
		var hit = box.intersects_segment(pivot, camera)
		if hit != null:
			best = minf(best, pivot.distance_to(hit) / length)
	return best


## Islands whose outline can reach the planar segment a-b.
func _islands_near(a: Vector3, b: Vector3) -> PackedInt32Array:
	var found := PackedInt32Array()
	if islands == null:
		return found
	var from := Vector2(a.x, a.z)
	var to := Vector2(b.x, b.z)
	for i in islands.size():
		var c := islands.centres[i]
		var closest := Geometry2D.get_closest_point_to_segment(c, from, to)
		# Rim radius wobbles at most 11% over the base radius.
		if closest.distance_to(c) <= islands.radii[i] * 1.12:
			found.append(i)
	return found


func _in_island(p: Vector3, near: PackedInt32Array) -> bool:
	for i in near:
		var s := islands.rim_fraction(i, p.x, p.z)
		if s <= 1.0 and p.y < islands.top_profile(i, s) and p.y > islands.underside_profile(i, s):
			return true
	return false


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
