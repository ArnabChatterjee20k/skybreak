class_name VoxelCameraFight
extends RefCounted
## A scripted all-AI fight on a voxel zone, measuring the fight camera: its
## positions (for CameraClearance), and how often both locked fighters are on
## screen at near (< NEAR m) and far (> FAR m) range. Used by the camera tests
## and camera_qa. Headless; one tick per frame.

const DT := 1.0 / 60.0
const NEAR := 3.5
const FAR := 12.0
const ASPECT := 16.0 / 9.0
## Fight ticks before a pinned scenario is measured.
const SETTLE_TICKS := 60
## A prop at least this tall (m) is a wall the camera cannot rise over.
const WALL_MIN_HEIGHT := 6.0


## {zone, points, locked, both_on, near, near_on, far, far_on, worst_gap, from_bake}
static func run(parent: Node, zone_id: StringName, fight_seed: int, ticks: int,
		fighters: Array = [&"kael", &"vexa"], level := 4) -> Dictionary:
	var entries := []
	for i in fighters.size():
		entries.append({"character": fighters[i], "team": i, "is_ai": true, "ai_level": level})
	var zone_match: ZoneMatch = load("res://game/levels/zone_match.tscn").instantiate()
	zone_match.configure({"zone": zone_id, "fighters": entries, "voxel_zone": true,
		"quality": GraphicsSettings.Quality.HIGH})
	zone_match.sim.rng.seed = fight_seed
	parent.add_child(zone_match)
	zone_match.set_physics_process(false)
	zone_match.set_process(false)
	var out := {"zone": zone_id, "points": PackedVector3Array(), "locked": 0, "both_on": 0,
		"near": 0, "near_on": 0, "far": 0, "far_on": 0, "worst_gap": 0.0,
		"from_bake": zone_match.voxel_zone != null and zone_match.voxel_zone.from_bake}
	var points := PackedVector3Array()
	for t in ticks:
		zone_match.step_tick()
		zone_match.present_frame(1.0, DT)
		var camera: FighterCamera = zone_match.camera
		var view := camera.global_transform
		points.append(view.origin)
		if zone_match.match_flow.phase != MatchFlow.Phase.FIGHT:
			continue
		var me := zone_match.sim.fighters[zone_match.player]
		if me.lock_on_target < 0 or me.is_ko_state() or zone_match.sim.fighters[me.lock_on_target].is_ko_state():
			continue
		var a: Vector3 = zone_match.fighter_views[zone_match.player].position
		var b: Vector3 = zone_match.fighter_views[me.lock_on_target].position
		var both := on_screen(view, camera.fov, a) and on_screen(view, camera.fov, b)
		var gap := a.distance_to(b)
		out.locked += 1
		out.both_on += int(both)
		out.worst_gap = maxf(out.worst_gap, gap)
		if gap < NEAR:
			out.near += 1
			out.near_on += int(both)
		elif gap > FAR:
			out.far += 1
			out.far_on += int(both)
	out.points = points
	out["zone_node"] = zone_match.voxel_zone.zone if zone_match.voxel_zone else null
	out["match"] = zone_match
	return out


static func on_screen(view: Transform3D, fov: float, point: Vector3) -> bool:
	var local := view.affine_inverse() * point
	if local.z >= -0.05:
		return false
	var tan_v := tan(deg_to_rad(fov) / 2.0)
	return absf(local.x / -local.z) <= tan_v * ASPECT and absf(local.y / -local.z) <= tan_v


## Solid prop copies (MultiMesh instance boxes) of this zone that are walls to
## stand against: WALL_MIN_HEIGHT-40 m tall, 1.5-25 m wide, base on the ground,
## within reach of the arena centre; nearest the centre first.
static func wall_props(zone: VoxelZone, centre: Vector2, ground: Callable, reach := 150.0) -> Array[AABB]:
	var found := []
	for gi: GeometryInstance3D in zone.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := (gi as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null or not FlightClearance._solid(gi, mm.mesh):
			continue
		var xforms: Array = gi.get_meta(PropKit.INSTANCE_TRANSFORMS_META, [])
		for xf: Transform3D in xforms:
			var box: AABB = gi.global_transform * xf * mm.mesh.get_aabb()
			var w := minf(box.size.x, box.size.z)
			if box.size.y < WALL_MIN_HEIGHT or box.size.y > 40.0 or w < 1.5 or maxf(box.size.x, box.size.z) > 25.0:
				continue
			var c := box.get_center()
			var d := Vector2(c.x, c.z).distance_to(centre)
			if d > reach:
				continue
			var floor_y: float = ground.call(c.x, c.z, box.end.y + 5.0)
			if absf(box.position.y - floor_y) > 1.5:
				continue
			found.append([d, box])
	found.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var out: Array[AABB] = []
	for f: Array in found:
		out.append(f[1])
	return out


## Where to stand backed against wall on side (0 toward the centre, 1-4 +X -X +Z -Z):
## [me, them], or [] when the ground there isn't level (within 1 m of the wall's base
## for both, so the wall stands over the camera).
static func wall_spots(wall: AABB, side: int, gap: float, centre: Vector2, ground: Callable) -> Array:
	var c := wall.get_center()
	var dirs := [Vector3(centre.x - c.x, 0, centre.y - c.z).normalized(),
		Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
	var out_dir: Vector3 = dirs[side % dirs.size()]
	if out_dir.length() < 0.5:
		out_dir = Vector3.BACK
	var half := absf(out_dir.x) * wall.size.x * 0.5 + absf(out_dir.z) * wall.size.z * 0.5
	var flat := Vector3(c.x, 0, c.z)
	var me_at := flat + out_dir * (half + 1.0)
	var them_at := flat + out_dir * (half + 1.0 + gap)
	me_at.y = ground.call(me_at.x, me_at.z, wall.position.y + 4.0) + 1.0
	them_at.y = ground.call(them_at.x, them_at.z, wall.position.y + 4.0) + 1.0
	if absf(me_at.y - 1.0 - wall.position.y) > 1.0 or absf(them_at.y - me_at.y) > 1.5:
		return []
	return [me_at, them_at]


## The player backed against `wall` (a prop box), facing a target `gap` m away, so
## the camera behind the player looks from inside the prop unless it avoids it.
## Both fighters are pinned in place for `ticks`. Same result keys as run().
static func backed_against(parent: Node, zone_id: StringName, gap: float, ticks: int,
		side := 0) -> Dictionary:
	var zone_match: ZoneMatch = load("res://game/levels/zone_match.tscn").instantiate()
	zone_match.configure({"zone": zone_id, "voxel_zone": true, "quality": GraphicsSettings.Quality.HIGH,
		"fighters": [{"character": &"kael", "team": 0, "is_ai": false, "ai_level": 0},
			{"character": &"vexa", "team": 1, "is_ai": true, "ai_level": 1}]})
	parent.add_child(zone_match)
	zone_match.set_physics_process(false)
	zone_match.set_process(false)
	var out := {"zone": zone_id, "points": PackedVector3Array(), "locked": 0, "both_on": 0,
		"near": 0, "near_on": 0, "far": 0, "far_on": 0, "worst_gap": gap, "wall": AABB(),
		"zone_node": zone_match.voxel_zone.zone, "match": zone_match}
	var sim := zone_match.sim
	var me_at := Vector3.ZERO
	var them_at := Vector3.ZERO
	for wall in wall_props(zone_match.voxel_zone.zone, sim.arena_centre, sim.ground_height):
		var spots := wall_spots(wall, side, gap, sim.arena_centre, sim.ground_height)
		if not spots.is_empty():
			out.wall = wall
			me_at = spots[0]
			them_at = spots[1]
			break
	if not (out.wall as AABB).has_volume():
		return out
	out["me_at"] = me_at
	out["them_at"] = them_at
	var points := PackedVector3Array()
	var fight_ticks := 0
	for t in ticks:
		for k in 2:
			var f := sim.fighters[k]
			f.position = me_at if k == 0 else them_at
			f.velocity = Vector3.ZERO
		sim.fighters[0].lock_on_target = 1
		zone_match.step_tick()
		zone_match.present_frame(1.0, DT)
		if zone_match.match_flow.phase != MatchFlow.Phase.FIGHT:
			continue
		# The first second eases out of the round intro's camera move.
		fight_ticks += 1
		if fight_ticks <= SETTLE_TICKS:
			continue
		var camera: FighterCamera = zone_match.camera
		var view := camera.global_transform
		points.append(view.origin)
		var a: Vector3 = zone_match.fighter_views[0].position
		var b: Vector3 = zone_match.fighter_views[1].position
		out.locked += 1
		out.both_on += int(on_screen(view, camera.fov, a) and on_screen(view, camera.fov, b))
	out.points = points
	return out
