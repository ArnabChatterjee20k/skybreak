extends SceneTree
## Camera QA for issue #75: runs all-AI zone_match configs headless and reports,
## per config, the share of frames where the followed player / their target /
## both are on screen, frames with no fighter on screen ("blank"), frames with
## the camera inside world geometry (below the ground or inside a prop box),
## frames with geometry between player and camera, and the worst angular
## acceleration of the view. Counted from the end of the round intro.
##
## godot --headless --path . -s res://game/debug/camera_qa.gd -- [ticks]

const DT := 1.0 / 60.0
const CONFIGS := [
	{"name": "1v1_stormfall", "zone": &"stormfall_city", "seed": 1,
		"fighters": [&"kael", &"brann"]},
	{"name": "1v1_heartbloom", "zone": &"heartbloom_gardens", "seed": 2,
		"fighters": [&"kael", &"vexa"]},
	{"name": "ffa4_frozen", "zone": &"frozen_peaks", "seed": 3,
		"fighters": [&"vexa", &"lyra", &"kael", &"brann"]},
	{"name": "ffa4_skyhold", "zone": &"skyhold_ruins", "seed": 5,
		"fighters": [&"kael", &"vexa", &"lyra", &"brann"]},
	{"name": "media2_duel", "zone": &"heartbloom_gardens", "seed": 3,
		"fighters": [&"kael", &"vexa"]},
	{"name": "heartbloom_2621", "zone": &"heartbloom_gardens", "seed": 2621,
		"fighters": [&"kael", &"vexa"]},
	{"name": "1v1_mesa", "zone": &"shattered_mesa", "seed": 4,
		"fighters": [&"kael", &"brann"]},
]
## A fighter covering more than this share of the screen is "in the lens".
const MAX_COVERAGE := 0.40
## Terrain/props covering more than this share of the screen in front of the
## fighters fails (#134).
const MAX_TERRAIN_COVER := 0.25
## Drawn fighter box for coverage: half width and height (m), around the centre.
const BODY_HALF_WIDTH := 0.55
const BODY_HEIGHT := 2.0
const ASPECT := 16.0 / 9.0

var _last_player := Vector3.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var ticks := int(args[0]) if args.size() > 0 else 2400
	for config in CONFIGS:
		if OS.get_environment("CAMQA_ONLY") != "" and OS.get_environment("CAMQA_ONLY") != config.name:
			continue
		print(_measure(config, ticks))
	quit()


func _measure(config: Dictionary, ticks: int) -> String:
	var fighters := []
	for i in config.fighters.size():
		fighters.append({"character": config.fighters[i], "team": i, "is_ai": true, "ai_level": 3})
	var zone_match: ZoneMatch = load("res://game/levels/zone_match.tscn").instantiate()
	zone_match.configure({"zone": config.zone, "fighters": fighters})
	zone_match.sim.rng.seed = config.seed
	root.add_child(zone_match)
	zone_match.set_physics_process(false)
	zone_match.set_process(false)
	var obstacles := CameraObstacles.from_zone_match(zone_match)
	var frames := 0
	var player_on := 0
	var target_on := 0
	var both_on := 0
	var blank := 0
	var inside := 0
	var occluded := 0
	var worst_accel := 0.0
	var worst_coverage := 0.0
	var covered := 0
	var terrain_frames := 0
	var worst_terrain := 0.0
	var heights: Array[float] = []
	var turns: Array[float] = []
	var previous_basis := Basis()
	for t in ticks:
		zone_match.step_tick()
		zone_match.present_frame(1.0, DT)
		var camera: FighterCamera = zone_match.camera
		var view := camera.global_transform
		var turn := rad_to_deg(previous_basis.get_rotation_quaternion().angle_to(view.basis.get_rotation_quaternion()))
		previous_basis = view.basis
		# Coverage counts in every frame, intro included (it should start wide).
		var coverage := 0.0
		var who := -1
		for vi in zone_match.fighter_views.size():
			# Opaque coverage: a body faded for the camera (FighterView.fade_for_camera)
			# doesn't block the view, so it counts by its remaining opacity.
			var fv: FighterView = zone_match.fighter_views[vi]
			var c := _coverage(view, camera.fov, fv.position) * (1.0 - fv.camera_fade())
			if c > coverage:
				coverage = c
				who = vi
		worst_coverage = maxf(worst_coverage, coverage)
		covered += int(coverage > MAX_COVERAGE)
		if zone_match.match_flow.phase == MatchFlow.Phase.FIGHT:
			var cover_terrain := CameraQaMetrics.terrain_cover(view, camera.fov, obstacles, zone_match)
			worst_terrain = maxf(worst_terrain, cover_terrain)
			terrain_frames += int(cover_terrain > MAX_TERRAIN_COVER)
			if OS.get_environment("CAMQA_DETAIL") == config.name and cover_terrain > MAX_TERRAIN_COVER:
				print("  t%d TERRAIN %.0f%% cam=%s" % [t, cover_terrain * 100.0, view.origin.snapped(Vector3.ONE * 0.1)])
			var me_view: FighterView = zone_match.fighter_views[zone_match.player]
			heights.append(CameraQaMetrics.screen_height(view, camera.fov, me_view.position))
		if OS.get_environment("CAMQA_DETAIL") == config.name and coverage > MAX_COVERAGE:
			print("  t%d COVER %.0f%% by fighter %d (player %d) fade=%.2f xw=%.2f cam-other %.2f phase=%s cam-player %.2f m" % [t, coverage * 100.0, who, zone_match.player, zone_match.fighter_views[who].camera_fade(), zone_match.camera.exchange_weight(), view.origin.distance_to(zone_match.fighter_views[who].position),
				MatchFlow.Phase.find_key(zone_match.match_flow.phase),
				view.origin.distance_to(zone_match.fighter_views[zone_match.player].position)])
		if zone_match.match_flow.phase == MatchFlow.Phase.INTRO:
			turns.clear()
			continue
		var player_now: Vector3 = zone_match.fighter_views[zone_match.player].position
		if player_now.distance_to(_last_player) > zone_match.camera.cut_distance:
			turns.clear()  # a deliberate cut (huge teleport), not a snap
		_last_player = player_now
		turns.append(turn)
		if turns.size() >= 3:
			# deg/s^2 from three consecutive per-frame turns.
			var accel := absf(turns[-1] - turns[-2]) / DT / DT
			worst_accel = maxf(worst_accel, accel)
		frames += 1
		var me := zone_match.sim.fighters[zone_match.player]
		var player_pos: Vector3 = zone_match.fighter_views[zone_match.player].position
		var target_index := me.lock_on_target if me.lock_on_target >= 0 else -1
		var p_on := _on_screen(view, camera.fov, player_pos)
		var t_on := target_index < 0 or _on_screen(view, camera.fov, zone_match.fighter_views[target_index].position)
		var any_on := false
		for v in zone_match.fighter_views:
			any_on = any_on or _on_screen(view, camera.fov, v.position)
		if OS.get_environment("CAMQA_DETAIL") == config.name and (not t_on or not any_on):
			var tp: Vector3 = zone_match.fighter_views[target_index].position if target_index >= 0 else Vector3.ZERO
			print("  t%d phase=%s lock=%d p_on=%s t_on=%s any=%s gap=%.1f dy=%.1f states=%s/%s fov=%.0f" % [t,
				MatchFlow.Phase.find_key(zone_match.match_flow.phase), target_index, p_on, t_on, any_on,
				player_pos.distance_to(tp), tp.y - player_pos.y,
				FighterState.State.find_key(me.state), FighterState.State.find_key(zone_match.sim.fighters[maxi(target_index, 0)].state), camera.fov])
		player_on += int(p_on)
		target_on += int(t_on)
		both_on += int(p_on and t_on)
		blank += int(not any_on)
		if OS.get_environment("CAMQA_DETAIL") == config.name and obstacles.is_inside(view.origin):
			var below := view.origin.y < obstacles.ground_at(view.origin)
			var lf := player_pos + Vector3.UP * 0.5
			var boxes_hit := []
			for b in obstacles.boxes:
				if b.has_point(view.origin):
					boxes_hit.append("%s pivot_in=%s" % [b, b.grow(0.4).has_point(lf)])
			print("  t%d INSIDE %s cam=%s cam-player %.2f m prop_clear=%.2f body_clear=%.2f boxes=%s" % [t, "ground" if below else "prop",
				view.origin.snapped(Vector3.ONE * 0.01), view.origin.distance_to(player_pos),
				obstacles.clear_fraction(lf, view.origin), obstacles.body_clear_fraction(lf, view.origin), boxes_hit])
		inside += int(obstacles.is_inside(view.origin))
		occluded += int(obstacles.blocks(player_pos, view.origin))
	zone_match.free()
	heights.sort()
	var median_height := heights[heights.size() / 2] if not heights.is_empty() else 0.0
	return "%-15s frames %d | both on %.1f%% | blank %d | inside %d | >40%% cover %d (worst %.0f%%) | terrain>25%% %d (worst %.0f%%) | player height median %.1f%% | worst accel %.0f" % [
		config.name, frames, 100.0 * both_on / maxi(frames, 1), blank, inside, covered, worst_coverage * 100.0,
		terrain_frames, worst_terrain * 100.0, median_height * 100.0, worst_accel]


## Share of the screen a fighter's drawn box covers (0..1), clipped to the frame.
static func _coverage(view: Transform3D, fov: float, centre: Vector3) -> float:
	var local := view.affine_inverse() * centre
	var depth := -local.z
	if depth < 0.05:
		# At or behind the lens plane: if it's right at the camera it fills the view.
		return 1.0 if local.length() < BODY_HALF_WIDTH + 0.2 else 0.0
	var tan_v := tan(deg_to_rad(fov) / 2.0)
	var tan_h := tan_v * ASPECT
	var cx := local.x / depth / tan_h
	var cy := local.y / depth / tan_v
	var hx := BODY_HALF_WIDTH / depth / tan_h
	var hy := BODY_HEIGHT * 0.5 / depth / tan_v
	var w := maxf(0.0, minf(cx + hx, 1.0) - maxf(cx - hx, -1.0))
	var h := maxf(0.0, minf(cy + hy, 1.0) - maxf(cy - hy, -1.0))
	return w * h / 4.0


static func _on_screen(view: Transform3D, fov: float, point: Vector3) -> bool:
	var local := view.affine_inverse() * point
	if local.z >= -0.05:
		return false
	var tan_v := tan(deg_to_rad(fov) / 2.0)
	return absf(local.x / -local.z) <= tan_v * ASPECT and absf(local.y / -local.z) <= tan_v
