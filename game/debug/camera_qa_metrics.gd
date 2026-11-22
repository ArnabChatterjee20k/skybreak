class_name CameraQaMetrics
extends RefCounted
## Screen-space camera measures shared by camera_qa.gd and camera_repro.gd.

const ASPECT := 16.0 / 9.0
const BODY_HEIGHT := 2.0
## Screen rays sampled for terrain_cover.
const TERRAIN_GRID := Vector2i(16, 9)


## Share of a grid of screen rays that hit terrain or a prop box before the
## depth of the nearest fighter: geometry in front of the action (#134).
static func terrain_cover(view: Transform3D, fov: float, obstacles: CameraObstacles, level: Node) -> float:
	var nearest := INF
	for v in level.fighter_views:
		nearest = minf(nearest, view.origin.distance_to(v.position))
	var reach := maxf(nearest - 1.0, 1.0)
	# The floor under the fighters is always "in front"; only hits above their
	# feet (walls, cliffs, props) count.
	var feet := INF
	for v in level.fighter_views:
		feet = minf(feet, v.position.y - 1.0)
	var tan_v := tan(deg_to_rad(fov) / 2.0)
	var tan_h := tan_v * ASPECT
	var hit := 0
	for gx in TERRAIN_GRID.x:
		for gy in TERRAIN_GRID.y:
			var nx := (gx + 0.5) / TERRAIN_GRID.x * 2.0 - 1.0
			var ny := (gy + 0.5) / TERRAIN_GRID.y * 2.0 - 1.0
			var dir := (view.basis * Vector3(nx * tan_h, ny * tan_v, -1.0)).normalized()
			var clear := obstacles.clear_fraction(view.origin, view.origin + dir * reach, 0.0)
			if clear < 0.999 and (view.origin + dir * reach * clear).y > feet + 0.5:
				hit += 1
	return float(hit) / (TERRAIN_GRID.x * TERRAIN_GRID.y)


## A fighter's on-screen height as a share of the screen (2 m body).
static func screen_height(view: Transform3D, fov: float, centre: Vector3) -> float:
	var depth := -(view.affine_inverse() * centre).z
	if depth < 0.05:
		return 1.0
	return minf(BODY_HEIGHT / (2.0 * depth * tan(deg_to_rad(fov) / 2.0)), 1.0)
