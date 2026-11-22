class_name CameraFloor
extends RefCounted
## The visible voxel floor's height for the fight camera: the top of a voxel
## zone's floor chunks (wide, low, solid meshes drawn up close), which can stand
## above the sim's heightmap (a raised floor tier, T-135). Each chunk is turned
## into a CELL grid of its highest triangle the first time the camera nears it.

const CELL := 0.5
## Chunk lookup grid (m).
const BUCKET := 16.0
## Floor chunks are at least this wide (smaller pieces are prop boxes) and at
## most this tall (taller meshes are cliffs, buildings or backdrop).
const MIN_WIDTH := CameraObstacles.VOXEL_MAX_WIDTH
const MAX_HEIGHT := 12.0
## A floor top up to this far above the asking point still counts as its floor
## (the lens dipped into a raised tier); higher ones are something overhead.
const ABOVE := 1.5
## Chunks within this of the camera are rasterized ahead, one per warm() call.
const WARM_REACH := 12.0

var _boxes: Array[AABB] = []
var _meshes: Array[Mesh] = []
var _xforms: Array[Transform3D] = []
var _done: PackedByteArray = PackedByteArray()
var _buckets := {}
var _heights := {}


## Floor chunks of a voxel zone within reach (planar) of centre.
static func from_zone(zone: Node, centre: Vector2, reach: float) -> CameraFloor:
	var out := CameraFloor.new()
	for node in zone.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.visibility_range_begin > 0.0 or not FlightClearance._solid(mi, mi.mesh):
			continue
		var box := mi.global_transform * mi.mesh.get_aabb()
		if maxf(box.size.x, box.size.z) <= MIN_WIDTH or box.size.y > MAX_HEIGHT:
			continue
		var c := box.get_center()
		if Vector2(c.x, c.z).distance_to(centre) > reach + Vector2(box.size.x, box.size.z).length() * 0.5:
			continue
		out.add_chunk(mi.mesh, mi.global_transform)
	return out


func add_chunk(mesh: Mesh, xform: Transform3D) -> void:
	var box := xform * mesh.get_aabb()
	var index := _boxes.size()
	_boxes.append(box)
	_meshes.append(mesh)
	_xforms.append(xform)
	_done.append(0)
	for bx in range(floori(box.position.x / BUCKET), floori(box.end.x / BUCKET) + 1):
		for bz in range(floori(box.position.z / BUCKET), floori(box.end.z / BUCKET) + 1):
			var key := Vector2i(bx, bz)
			var list: PackedInt32Array = _buckets.get(key, PackedInt32Array())
			list.append(index)
			_buckets[key] = list


func chunk_count() -> int:
	return _boxes.size()


## Floor top under (x, z) at most ABOVE over from_y, or -INF.
func height_at(x: float, z: float, from_y: float) -> float:
	for index in _buckets.get(Vector2i(floori(x / BUCKET), floori(z / BUCKET)), PackedInt32Array()):
		if _done[index] == 0:
			var box := _boxes[index]
			if x >= box.position.x and x <= box.end.x and z >= box.position.z and z <= box.end.z:
				_rasterize(index)
	var h: float = _heights.get(Vector2i(floori(x / CELL), floori(z / CELL)), -INF)
	return h if h <= from_y + ABOVE else -INF


## Rasterizes at most one not yet done chunk within WARM_REACH of point, so
## height_at rarely has to do it mid-frame.
func warm(point: Vector3) -> void:
	var lo := Vector2i(floori((point.x - WARM_REACH) / BUCKET), floori((point.z - WARM_REACH) / BUCKET))
	var hi := Vector2i(floori((point.x + WARM_REACH) / BUCKET), floori((point.z + WARM_REACH) / BUCKET))
	for bx in range(lo.x, hi.x + 1):
		for bz in range(lo.y, hi.y + 1):
			for index in _buckets.get(Vector2i(bx, bz), PackedInt32Array()):
				if _done[index] == 0:
					_rasterize(index)
					return


func _rasterize(index: int) -> void:
	_done[index] = 1
	var faces := _meshes[index].get_faces()
	var xf := _xforms[index]
	for t in range(0, faces.size(), 3):
		var a := xf * faces[t]
		var b := xf * faces[t + 1]
		var c := xf * faces[t + 2]
		var top := maxf(a.y, maxf(b.y, c.y))
		var bottom := minf(a.y, minf(b.y, c.y))
		# Sloped faces: the plane's height at the cell corners, within the face's
		# own height range; steep faces (step sides) stand at their top edge.
		var n := (b - a).cross(c - a)
		var sloped := absf(n.y) > 0.2 * n.length()
		for cx in range(floori(minf(a.x, minf(b.x, c.x)) / CELL), floori(maxf(a.x, maxf(b.x, c.x)) / CELL) + 1):
			for cz in range(floori(minf(a.z, minf(b.z, c.z)) / CELL), floori(maxf(a.z, maxf(b.z, c.z)) / CELL) + 1):
				var h := top
				if sloped:
					h = -INF
					for corner: Vector2 in [Vector2(cx, cz), Vector2(cx + 1, cz), Vector2(cx, cz + 1), Vector2(cx + 1, cz + 1)]:
						var x := corner.x * CELL
						var z := corner.y * CELL
						h = maxf(h, a.y - (n.x * (x - a.x) + n.z * (z - a.z)) / n.y)
					h = clampf(h, bottom, top)
				var key := Vector2i(cx, cz)
				if h > _heights.get(key, -INF):
					_heights[key] = h
