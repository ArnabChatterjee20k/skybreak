extends SceneTree
## Runs the visual-QA match in several zones and prints the violation table (T-D30).
##
## godot --headless --path . -s res://game/debug/qa/visual_qa_run.gd -- [ticks] [zone ...]

const ZONES: Array[StringName] = [&"heartbloom_gardens", &"frozen_peaks", &"shattered_mesa"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var ticks := int(args[0]) if not args.is_empty() else 3600
	var zones: Array = args.slice(1) if args.size() > 1 else ZONES
	var failed := 0
	for i in zones.size():
		var qa := VisualQa.new()
		qa.zone = StringName(zones[i])
		qa.ticks = ticks
		qa.seed_value = i + 1
		root.add_child(qa)
		var started := Time.get_ticks_msec()
		await qa.run()
		print(qa.summary())
		print("  frames %d, %.1f s" % [qa.frames, (Time.get_ticks_msec() - started) / 1000.0])
		var worst: Array = qa.worst_frames.duplicate()
		worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(a.value) > absf(b.value))
		for frame: Dictionary in worst.slice(0, 5):
			print("  worst: ", frame)
		failed += qa.failures()
		qa.queue_free()
		await process_frame
	print("VISUAL QA %s: %d failing violations" % ["PASS" if failed == 0 else "FAIL", failed])
	quit(1 if failed > 0 else 0)
