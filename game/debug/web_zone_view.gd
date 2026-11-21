extends SceneTree
## Boots straight into a voxel zone match at the WEB tier, idle (run it with
## --rendering-method gl_compatibility to see what the web build draws); prints
## "[web] ready" once drawn. Release web templates ignore -s, so not in-browser.
##   godot -s res://game/debug/web_zone_view.gd -- <zone_id> [legend_a,legend_b] [shot.png]
## With a shot path it saves the frame there and quits.

const READY_FRAMES := 30


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var zone := args[0] if not args.is_empty() else "heartbloom_gardens"
	var legends := args[1] if args.size() > 1 else "kael,brann"
	ArtStyle.set_current(ArtStyle.Kind.VOXEL)
	VoxelQuality.tier = GraphicsSettings.Quality.WEB
	print("[web] building %s (%s)" % [zone, RenderingServer.get_current_rendering_method()])
	var started := Time.get_ticks_msec()
	var run := QaMatchRun.new(QaMatchSpec.parse("7:%s:1v1:%s:33" % [zone, legends]))
	run.check_view = false
	run.build(root)
	run.level.match_flow.enabled = false
	run.level.input_override = func(_slot: int, _t: int) -> FighterInput: return FighterInput.new()
	print("[web] built %s in %d ms" % [zone, Time.get_ticks_msec() - started])
	for i in READY_FRAMES:
		await process_frame
		run.advance()
	var report := WebTierBudget.measure(run.level)
	print("[web] ready %s: %d instance-uniform instances, %d geometry, fps %.1f" % [zone,
		report.instance_uniform_instances, report.geometry_instances, Engine.get_frames_per_second()])
	if args.size() > 2:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[2])
		print("[web] saved ", args[2])
		quit()
