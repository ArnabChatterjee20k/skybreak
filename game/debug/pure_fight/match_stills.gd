extends SceneTree
## Pure Fight stills: the side-on camera in each zone after an AI exchange, 1920x1080.
##   godot --path . --disable-vsync --resolution 1920x1080 -s res://game/debug/pure_fight/match_stills.gd -- <out dir> [zone ...] [--ticks N] [--classic]

const ZONES: Array[StringName] = [&"heartbloom_gardens", &"skyhold_ruins", &"shattered_mesa",
	&"stormfall_city", &"frozen_peaks", &"verdant_falls", &"ember_rift"]
const PAIRS := [[&"kael", &"vexa"], [&"lyra", &"brann"], [&"vexa", &"lyra"], [&"brann", &"kael"]]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://pure_fight_stills"
	DirAccess.make_dir_recursive_absolute(out)
	var ticks := 520
	var at := args.find("--ticks")
	if at >= 0:
		ticks = int(args[at + 1])
	var zones: Array[StringName] = []
	for arg in args.slice(1):
		if StringName(arg) in ZONES:
			zones.append(StringName(arg))
	if zones.is_empty():
		zones = ZONES.duplicate()
	root.size = Vector2i(1920, 1080)
	for i in zones.size():
		var zone := zones[i]
		var pair: Array = PAIRS[i % PAIRS.size()]
		var level := PureFightMatch.new()
		var cfg := {"zone": zone, "seed": 3 + i, "fighters": [
			{"character": pair[0], "is_ai": true, "ai_level": 4},
			{"character": pair[1], "is_ai": true, "ai_level": 4}]}
		cfg["quality"] = GraphicsSettings.Quality.LOW
		if args.has("--classic"):
			cfg["voxel_zone"] = false
		level.configure(cfg)
		var started := Time.get_ticks_msec()
		root.add_child(level)
		await process_frame
		for t in ticks:
			level.step_tick()
			if t % 4 == 0:
				level.present_frame(1.0, 4.0 / 60.0)
		for f in 6:
			level.present_frame(1.0, 1.0 / 60.0)
			await process_frame
		# No impact-frame flash in the review still.
		level.effects.impact_frame.queue_free()
		level.effects.impact_frame = null
		await process_frame
		await RenderingServer.frame_post_draw
		var path := out.path_join("zone_%s.png" % zone)
		root.get_texture().get_image().save_png(path)
		var a := level.views[0].position
		var b := level.views[1].position
		print("[stills] %s %s v %s flat=%.2fm both_framed=%s build+run %d ms" % [path, pair[0], pair[1],
			level.stage.roughness, level.camera.frames_point(a + Vector3.UP) and level.camera.frames_point(b + Vector3.UP),
			Time.get_ticks_msec() - started])
		level.queue_free()
		await process_frame
	quit()
