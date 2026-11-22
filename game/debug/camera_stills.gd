extends SceneTree
## Stills of the fight camera on every voxel zone: the VoxelCameraFight all-AI
## fight (Kael vs Vexa, seed 7), a frame saved at each listed tick.
##   godot --path . --resolution 1920x1080 -s res://game/debug/camera_stills.gd -- <out dir> [ticks,..] [zone]

const TICKS := [360, 700, 1040]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://camera_stills"
	var ticks: Array = TICKS
	if args.size() > 1:
		ticks = Array(args[1].split(",")).map(func(s: String) -> int: return int(s))
	DirAccess.make_dir_recursive_absolute(out)
	for id: StringName in VoxelZoneView.BUILDERS:
		if args.size() > 2 and String(id) != args[2]:
			continue
		var zone_match: ZoneMatch = load("res://game/levels/zone_match.tscn").instantiate()
		zone_match.configure({"zone": id, "voxel_zone": true, "quality": GraphicsSettings.Quality.HIGH,
			"fighters": [{"character": &"kael", "team": 0, "is_ai": true, "ai_level": 4},
				{"character": &"vexa", "team": 1, "is_ai": true, "ai_level": 4}]})
		zone_match.sim.rng.seed = 7
		root.add_child(zone_match)
		zone_match.set_physics_process(false)
		zone_match.set_process(false)
		var t := 0
		for wanted: int in ticks:
			while t < wanted:
				zone_match.step_tick()
				zone_match.present_frame(1.0, VoxelCameraFight.DT)
				t += 1
			for _f in 3:
				await process_frame
			var cam: FighterCamera = zone_match.camera
			var me := zone_match.sim.fighters[zone_match.player]
			var a: Vector3 = zone_match.fighter_views[zone_match.player].position
			var b: Vector3 = zone_match.fighter_views[1 - zone_match.player].position
			var both := VoxelCameraFight.on_screen(cam.global_transform, cam.fov, a) \
				and VoxelCameraFight.on_screen(cam.global_transform, cam.fov, b)
			var img := root.get_viewport().get_texture().get_image()
			var path := "%s/%s_t%04d.png" % [out, id, t]
			img.save_png(path)
			print("STILL %s tick %d phase %s locked %s both_on %s fov %.1f gap %.1f -> %s" % [id, t,
				MatchFlow.Phase.keys()[zone_match.match_flow.phase], me.lock_on_target >= 0, both, cam.fov,
				a.distance_to(b), path])
		zone_match.free()
		await process_frame
	quit()
