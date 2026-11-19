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
]
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
	var turns: Array[float] = []
	var previous_basis := Basis()
	for t in ticks:
		zone_match.step_tick()
		zone_match.present_frame(1.0, DT)
		var camera: FighterCamera = zone_match.camera
		var view := camera.global_transform
		var turn := rad_to_deg(previous_basis.get_rotation_quaternion().angle_to(view.basis.get_rotation_quaternion()))
		previous_basis = view.basis
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
		inside += int(obstacles.is_inside(view.origin))
		occluded += int(obstacles.blocks(player_pos, view.origin))
	zone_match.free()
	return "%-15s frames %d | player on %.1f%% | target on %.1f%% | both %.1f%% | blank %d | inside geometry %d | occluded %d | worst accel %.0f deg/s^2" % [
		config.name, frames, 100.0 * player_on / maxi(frames, 1), 100.0 * target_on / maxi(frames, 1),
		100.0 * both_on / maxi(frames, 1), blank, inside, occluded, worst_accel]


static func _on_screen(view: Transform3D, fov: float, point: Vector3) -> bool:
	var local := view.affine_inverse() * point
	if local.z >= -0.05:
		return false
	var tan_v := tan(deg_to_rad(fov) / 2.0)
	return absf(local.x / -local.z) <= tan_v * ASPECT and absf(local.y / -local.z) <= tan_v
