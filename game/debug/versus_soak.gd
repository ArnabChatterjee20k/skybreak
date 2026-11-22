extends SceneTree
## Bot-vs-bot Versus on a voxel zone (Kael vs Vexa, AI 5, specials on), one tick per
## frame, chaining matches until `fight_seconds` of FIGHT phase have run: counts the
## specials used and the frames a hand glow was lit; saves a few lit frames when rendered.
##   godot [--headless] --path . -s res://game/debug/versus_soak.gd -- <zone> <fight_seconds> <out dir>

const DT := 1.0 / 60.0
## Ticks one match may run before the next starts anyway.
const MATCH_LIMIT := 9000


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var zone := StringName(args[0]) if args.size() > 0 else &"shattered_mesa"
	var wanted := float(args[1]) if args.size() > 1 else 150.0
	var out := args[2] if args.size() > 2 else "user://versus_soak"
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	var rendered := DisplayServer.get_name() != "headless"
	var starts := [0, 0]
	var counters := 0
	var decoys := 0
	var kos := 0
	var shots := 0
	var lit_frames := 0
	var fight_ticks := 0
	var ticks := 0
	var matches := 0
	var t0 := Time.get_ticks_msec()
	while fight_ticks * DT < wanted:
		var zone_match: ZoneMatch = load("res://game/levels/zone_match.tscn").instantiate()
		zone_match.configure({"zone": zone, "mode": &"versus", "voxel_zone": true,
			"quality": GraphicsSettings.Quality.MEDIUM, "fighters": [
			{"character": &"kael", "team": 0, "is_ai": true, "ai_level": 5},
			{"character": &"vexa", "team": 1, "is_ai": true, "ai_level": 5}]})
		zone_match.sim.rng.seed = 2026 + matches
		root.add_child(zone_match)
		zone_match.set_physics_process(false)
		zone_match.set_process(false)
		print("SOAK match %d zone=%s from_bake=%s" % [matches, zone, zone_match.voxel_zone.from_bake])
		for t in MATCH_LIMIT:
			zone_match.step_tick()
			zone_match.present_frame(1.0, DT)
			ticks += 1
			for e in zone_match.sim.events:
				match e.get("type", -1):
					CombatSim.EventType.SPECIAL_START:
						starts[e.fighter] += 1
					CombatSim.EventType.SPECIAL_COUNTER:
						counters += 1
					CombatSim.EventType.DECOY_SPAWN:
						decoys += 1
					CombatSim.EventType.KO:
						kos += 1
			var lit := false
			for v in zone_match.fighter_views:
				var cv: CharacterView = v._character
				if cv != null and cv.special_glow != null and cv.special_glow.orbs[0].visible:
					lit = true
			lit_frames += int(lit)
			fight_ticks += int(zone_match.match_flow.phase == MatchFlow.Phase.FIGHT)
			await process_frame
			if rendered and lit and shots < 6 and t % 5 == 0:
				root.get_texture().get_image().save_png(out.path_join("special_%d_%d.png" % [matches, t]))
				shots += 1
			if zone_match.match_flow.phase == MatchFlow.Phase.MATCH_OVER or fight_ticks * DT >= wanted:
				break
		print("SOAK after match %d: fight_s=%.1f specials kael=%d vexa=%d lit=%d" % [matches, fight_ticks * DT, starts[0], starts[1], lit_frames])
		zone_match.free()
		matches += 1
	print("SOAK matches=%d ticks=%d fight_seconds=%.1f specials kael=%d vexa=%d counters=%d decoys=%d lit_frames=%d kos=%d shots=%d wall_s=%.0f" % [
		matches, ticks, fight_ticks * DT, starts[0], starts[1], counters, decoys, lit_frames, kos, shots, (Time.get_ticks_msec() - t0) / 1000.0])
	quit()
