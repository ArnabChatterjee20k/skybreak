class_name PureFightStage
extends Node3D
## The Pure Fight platform (GAME_DESIGN §16.4): a flat spot found in the zone's ground data,
## a stone slab on it in the voxel look with a stepped edge and corner posts, and the fight
## line across it. The zone around stays fully 3D as the backdrop.

const LENGTH := 17.0
const DEPTH := 5.0
const THICKNESS := 0.5
const SEARCH_RADIUS := 70.0
const SEARCH_STEP := 10.0
const BLOCK := 0.5

## Fight line start (its middle, on the slab top), direction (screen right) and the slab top.
var origin := Vector3.ZERO
var line_dir := Vector3.RIGHT
var floor_y := 0.0
## Spread of ground height under the slab (m): how flat the chosen spot was.
var roughness := 0.0


## Picks the flattest spot near the zone's spawns, the line turned so the camera looks
## toward the zone centre. ground: func(x, z) -> float.
func place(ground: Callable, near: Vector2, zone_centre: Vector2) -> void:
	var best := INF
	var best_centre := near
	var best_dir := Vector3.RIGHT
	var best_top := 0.0
	var steps := int(SEARCH_RADIUS / SEARCH_STEP)
	for i in range(-steps, steps + 1):
		for j in range(-steps, steps + 1):
			var centre := near + Vector2(i, j) * SEARCH_STEP
			for k in 12:
				var angle := k * PI / 12.0
				var dir := Vector3(cos(angle), 0.0, sin(angle))
				var spread := _spread(ground, centre, dir)
				var score: float = spread.x + centre.distance_to(near) * 0.01
				if score < best:
					best = score
					best_centre = centre
					best_dir = dir
					best_top = spread.y
					roughness = spread.x
	line_dir = best_dir
	floor_y = best_top + 0.05
	origin = Vector3(best_centre.x, floor_y, best_centre.y)
	var look := Vector3.UP.cross(line_dir)
	var to_centre := Vector3(zone_centre.x - origin.x, 0.0, zone_centre.y - origin.z)
	if to_centre.length_squared() > 1.0 and look.dot(to_centre) < 0.0:
		line_dir = -line_dir
	_build()


## [max - min, max] of the ground under a slab at centre along dir.
func _spread(ground: Callable, centre: Vector2, dir: Vector3) -> Vector2:
	var low := INF
	var high := -INF
	var across := Vector3(-dir.z, 0.0, dir.x)
	for a in range(-8, 9, 2):
		for b in [-2.0, 0.0, 2.0]:
			var p: Vector3 = Vector3(centre.x, 0.0, centre.y) + dir * float(a) + across * float(b)
			var h: float = ground.call(p.x, p.z)
			low = minf(low, h)
			high = maxf(high, h)
	return Vector2(high - low, high)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	var right := line_dir
	var depth_axis := Vector3.UP.cross(right).normalized()
	transform = Transform3D(Basis(right, Vector3.UP, depth_axis), origin)
	var stone := _material(Color(0.52, 0.5, 0.47))
	var trim := _material(Color(0.36, 0.33, 0.31))
	var gold := _material(Color(0.78, 0.6, 0.28))
	_box(Vector3(0, -THICKNESS * 0.5, 0), Vector3(LENGTH, THICKNESS, DEPTH), stone)
	# Stepped edge: a lower ledge all round, then a foot down into the ground.
	_box(Vector3(0, -THICKNESS - 0.25, 0), Vector3(LENGTH + 1.0, 0.5, DEPTH + 1.0), trim)
	_box(Vector3(0, -THICKNESS - 2.5, 0), Vector3(LENGTH + 0.6, 4.0, DEPTH + 0.6), trim)
	# Tile seams on the top, one block apart, so the slab reads as voxel stone.
	var seam := _material(Color(0.42, 0.40, 0.38))
	for i in range(1, int(LENGTH / 1.0)):
		_box(Vector3(-LENGTH * 0.5 + i, 0.002, 0), Vector3(0.04, 0.01, DEPTH), seam)
	for j in range(1, int(DEPTH / 1.0)):
		_box(Vector3(0, 0.002, -DEPTH * 0.5 + j), Vector3(LENGTH, 0.01, 0.04), seam)
	# Corner posts mark the walls at the line ends.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var at := Vector3(sx * (LENGTH * 0.5 - 0.25), 0.0, sz * (DEPTH * 0.5 - 0.25))
			_box(at + Vector3(0, 0.5, 0), Vector3(0.5, 1.0, 0.5), trim)
			_box(at + Vector3(0, 1.05, 0), Vector3(0.6, 0.1, 0.6), gold)
	# A painted fight line down the middle.
	_box(Vector3(0, 0.004, 0), Vector3(LENGTH - 1.0, 0.01, 0.06), gold)


func _box(at: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	add_child(node)


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
