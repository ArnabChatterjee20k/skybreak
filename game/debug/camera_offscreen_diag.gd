extends SceneTree
## Lists the locked fight frames where a fighter leaves the screen in the
## VoxelCameraFight scripted fight, with both fighters' states and the camera.
##   godot --headless --path . -s res://game/debug/camera_offscreen_diag.gd -- <zone> [ticks] [seed]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var zone := StringName(args[0]) if args.size() > 0 else &"shattered_mesa"
	var ticks := int(args[1]) if args.size() > 1 else 1200
	var fight_seed := int(args[2]) if args.size() > 2 else 7
	# Optional tick range [from, to] that prints every locked frame, on screen or not.
	var trace_from := int(args[3]) if args.size() > 3 else -1
	var trace_to := int(args[4]) if args.size() > 4 else -1
	var zone_match: ZoneMatch = load("res://game/levels/zone_match.tscn").instantiate()
	zone_match.configure({"zone": zone, "voxel_zone": true, "quality": GraphicsSettings.Quality.HIGH,
		"fighters": [{"character": &"kael", "team": 0, "is_ai": true, "ai_level": 4},
			{"character": &"vexa", "team": 1, "is_ai": true, "ai_level": 4}]})
	zone_match.sim.rng.seed = fight_seed
	root.add_child(zone_match)
	zone_match.set_physics_process(false)
	zone_match.set_process(false)
	var locked := 0
	var off := 0
	var cats := {}
	for t in ticks:
		zone_match.step_tick()
		zone_match.present_frame(1.0, VoxelCameraFight.DT)
		if zone_match.match_flow.phase != MatchFlow.Phase.FIGHT:
			continue
		var me := zone_match.sim.fighters[zone_match.player]
		if me.lock_on_target < 0 or me.is_ko_state() or zone_match.sim.fighters[me.lock_on_target].is_ko_state():
			continue
		var cam: FighterCamera = zone_match.camera
		var view := cam.global_transform
		var a: Vector3 = zone_match.fighter_views[zone_match.player].position
		var b: Vector3 = zone_match.fighter_views[me.lock_on_target].position
		var a_on := VoxelCameraFight.on_screen(view, cam.fov, a)
		var b_on := VoxelCameraFight.on_screen(view, cam.fov, b)
		locked += 1
		if a_on and b_on and (t < trace_from or t > trace_to):
			continue
		off += int(not (a_on and b_on))
		var them := zone_match.sim.fighters[me.lock_on_target]
		var la := view.affine_inverse() * a
		var lb := view.affine_inverse() * b
		var look_from: Vector3 = cam._anchor + Vector3.UP * 0.5
		var want: Vector3 = cam._anchor + cam._offset
		var terr := cam.obstacles.clear_fraction(look_from, want) if cam.obstacles else 1.0
		var body := cam.obstacles.body_clear_fraction(look_from, want) if cam.obstacles else 1.0
		var cat := "body" if body < 0.99 else ("terrain" if terr < 0.99 else ("clip" if cam._clip_length < cam._offset.length() - 0.5 else ("exch" if cam.exchange_weight() > 0.0 else "free")))
		cats[cat] = cats.get(cat, 0) + 1
		print("    %s offset %.1f clip %.1f shift %s push %s terrain %.2f body %.2f lag %.2f" % [cat, cam._offset.length(),
			cam._clip_length, cam._clip_shift.snapped(Vector3.ONE * 0.1), cam._wall_push.snapped(Vector3.ONE * 0.1), terr, body, cam._lag])
		if cam.obstacles and cam.obstacles.voxel_floor:
			var sim_g: float = cam.obstacles.ground_height.call(a.x, a.z, a.y)
			var fl := cam.obstacles.voxel_floor.height_at(a.x, a.z, a.y + 50.0)
			var mid := (look_from + want) * 0.5
			print("    me %s sim ground %.2f floor %.2f | boom mid %s sim %.2f floor %.2f" % [a.snapped(Vector3.ONE * 0.01), sim_g, fl,
				mid.snapped(Vector3.ONE * 0.1), cam.obstacles.ground_height.call(mid.x, mid.z, mid.y), cam.obstacles.voxel_floor.height_at(mid.x, mid.z, mid.y + 50.0)])
		print("t%4d off=%s%s gap %.1f fov %.1f cam-me %.1f exch %.2f me %s them %s | me_local %s them_local %s" % [
			t, "" if a_on else "ME ", "" if b_on else "THEM", a.distance_to(b), cam.fov,
			view.origin.distance_to(a), cam.exchange_weight(), _detail(me), _detail(them),
			la.snapped(Vector3.ONE * 0.1), lb.snapped(Vector3.ONE * 0.1)])
	print("%s locked %d off %d both %.2f%% %s" % [zone, locked, off, 100.0 - 100.0 * off / maxi(locked, 1), cats])
	quit()


## State plus the move, dash or dodge kind behind it.
static func _detail(f: FighterState) -> String:
	var s: String = FighterState.State.keys()[f.state]
	if f.state == FighterState.State.DASHING:
		s += ":" + str(FighterState.DashKind.keys()[f.dash_kind])
		if f.dash_kind == FighterState.DashKind.DODGE:
			s += ":" + str(FighterDodge.Kind.keys()[f.dodge.kind])
	elif f.state == FighterState.State.ATTACKING and f.move != null:
		s += ":" + str(f.move.id)
	elif f.state == FighterState.State.ESCAPING:
		s += ":" + str(FighterEscapes.Kind.keys()[f.escapes.kind])
	elif f.state == FighterState.State.VANISHING:
		s += ":anchor%d" % f.vanish_anchor
	return s
