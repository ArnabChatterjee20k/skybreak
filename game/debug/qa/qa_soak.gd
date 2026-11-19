extends SceneTree
## Gameplay QA soak runner (tools/qa/run_qa.sh drives it). Commands after `--`:
##   soak --matrix quick|full [--shard i/n] [--ticks N] --out DIR
##       plays the matrix's AI matches with sim and view checks; one JSON per match.
##   capture --spec ID --tick T [--frames 120] [--fighter N] --out DIR
##       replays one match to tick T and saves its last frames as PNGs (needs a renderer).
##   shots --out DIR
##       renders the fixed visual-golden camera shots (needs a renderer).
##   feel --out DIR
##       press-to-active latency per legend and attack (sim only).

const QUICK_TICKS := 2400
const FULL_TICKS := 3600
const CAPTURE_SIZE := Vector2i(960, 540)

var _args := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var raw := OS.get_cmdline_user_args()
	var command := raw[0] if not raw.is_empty() else "soak"
	for i in range(1, raw.size()):
		if raw[i].begins_with("--"):
			var has_value := i + 1 < raw.size() and not raw[i + 1].begins_with("--")
			_args[raw[i].trim_prefix("--")] = raw[i + 1] if has_value else "1"
	var out_dir: String = _args.get("out", "user://qa")
	DirAccess.make_dir_recursive_absolute(out_dir)
	match command:
		"soak":
			await _soak(out_dir)
		"capture":
			await _capture(QaMatchSpec.parse(_args.spec), int(_args.tick), int(_args.get("frames", "120")),
				int(_args.get("fighter", "0")), out_dir)
		"shots":
			await _shots(out_dir)
		"feel":
			var file := FileAccess.open(out_dir.path_join("feel.json"), FileAccess.WRITE)
			file.store_string(JSON.stringify(QaFeel.latencies(), "\t"))
			file.close()
	quit()


func _soak(out_dir: String) -> void:
	var full: bool = _args.get("matrix", "quick") == "full"
	var specs := QaMatchSpec.full_matrix() if full else QaMatchSpec.quick_matrix()
	if _args.has("only"):
		specs = [QaMatchSpec.parse(_args.only)]
	var shard := (_args.get("shard", "0/1") as String).split("/")
	var index := int(shard[0])
	var count := int(shard[1])
	var ticks := int(_args.get("ticks", str(FULL_TICKS if full else QUICK_TICKS)))
	for n in specs.size():
		if n % count != index:
			continue
		var spec := specs[n]
		var started := Time.get_ticks_msec()
		var run := QaMatchRun.new(spec)
		run.check_view = not _args.has("no-view")
		run.build(root)
		await process_frame
		while run.tick < ticks and not run.is_over():
			await process_frame
			run.advance()
		run.finish()
		var result := run.result()
		result.wall_seconds = (Time.get_ticks_msec() - started) / 1000.0
		var file := FileAccess.open(out_dir.path_join("match_%03d.json" % n), FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
		print("[qa] match %d %s: %d ticks, %d violation kinds, %.1f s" % [n, spec.id(), run.tick,
			result.violations.size(), result.wall_seconds])
		run.level.queue_free()
		await process_frame


## Replays spec to `at` without drawing 3D, then draws and saves the last `frames` frames,
## the camera on `fighter` (input stays with the AI, so the match is the same).
func _capture(spec: QaMatchSpec, at: int, frames: int, fighter: int, out_dir: String) -> void:
	_size_window()
	var run := QaMatchRun.new(spec)
	run.check_view = false
	run.build(root)
	run.level.player = clampi(fighter, 0, spec.fighter_count() - 1)
	await process_frame
	await _prewarm(run.level)
	var first := maxi(at - frames + 1, 1)
	root.disable_3d = true
	while run.tick < at and not run.is_over():
		await process_frame
		if run.tick + 1 == first:
			root.disable_3d = false
		run.advance()
		if run.tick >= first:
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.save_png(out_dir.path_join("frame_%05d.png" % run.tick))
	print("[qa] captured %s ticks %d-%d into %s" % [spec.id(), first, run.tick, out_dir])


## The visual-golden shots: each legend idle and mid-attack in Heartbloom, and one wide shot per zone.
func _shots(out_dir: String) -> void:
	_size_window()
	for shot in QaShots.all():
		if _args.has("only") and not (shot.name as String).begins_with(_args.only):
			continue
		var spec := QaMatchSpec.parse(shot.spec)
		var run := QaMatchRun.new(spec)
		run.check_view = false
		run.build(root)
		run.level.match_flow.enabled = false
		# Live fps text would differ every run.
		(run.level.get_node(^"DebugOverlay") as CanvasLayer).visible = false
		if shot.get("scene_only", false):
			_hide_overlays(run.level)
		var plan: Callable = shot.plan
		run.level.input_override = func(slot: int, t: int) -> FighterInput: return plan.call(run.level.sim, slot, t)
		await process_frame
		await _prewarm(run.level)
		root.disable_3d = true
		while run.tick < shot.tick:
			await process_frame
			if run.tick + 2 >= shot.tick:
				root.disable_3d = false
			run.advance()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join(shot.name + ".png"))
		print("[qa] shot ", shot.name)
		run.level.queue_free()
		await process_frame


func _prewarm(level: ZoneMatch) -> void:
	if not level.vfx_prewarm.is_finished:
		await level.vfx_prewarm.finished


func _size_window() -> void:
	root.size = CAPTURE_SIZE
	DisplayServer.window_set_size(CAPTURE_SIZE)


## Hides every 2D layer (HUD, menus, overlays) so a shot shows only the 3D scene.
static func _hide_overlays(level: Node) -> void:
	for layer: CanvasLayer in level.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
