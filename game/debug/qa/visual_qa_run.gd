extends SceneTree
## Runs the visual-QA match in several zones and prints the violation table (T-D30).
##
## Every zone runs with seeds 1-3.
## godot --headless --path . -s res://game/debug/qa/visual_qa_run.gd -- [ticks] [zone ...]

const ZONES: Array[StringName] = [&"heartbloom_gardens", &"frozen_peaks", &"shattered_mesa"]
const SEEDS: Array[int] = [1, 2, 3]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var ticks := int(args[0]) if not args.is_empty() else 3600
	var zones: Array = args.slice(1) if args.size() > 1 else ZONES
	var failed := 0
	var reach := {}
	for run in zones.size() * SEEDS.size():
		var qa := VisualQa.new()
		qa.zone = StringName(zones[run / SEEDS.size()])
		qa.ticks = ticks
		qa.seed_value = SEEDS[run % SEEDS.size()]
		root.add_child(qa)
		var started := Time.get_ticks_msec()
		await qa.run()
		print("seed %d" % qa.seed_value)
		print(qa.summary())
		print("  frames %d, %.1f s" % [qa.frames, (Time.get_ticks_msec() - started) / 1000.0])
		var dump := OS.get_environment("VISUAL_QA_DUMP")
		if dump != "":
			# Every violation, for offline breakdowns.
			var file := FileAccess.open("%s/%s_%d.txt" % [dump, qa.zone, qa.seed_value], FileAccess.WRITE)
			for frame: Dictionary in qa.worst_frames:
				file.store_line(str(frame))
			file.close()
		var worst: Array = qa.worst_frames.duplicate()
		worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absf(a.value) > absf(b.value))
		for check in VisualQa.CHECKS:
			var shown := 0
			for frame: Dictionary in worst:
				if frame.check == check and shown < 3:
					print("  worst: ", frame)
					shown += 1
		failed += qa.failures()
		for legend: StringName in qa.core_reach:
			if not reach.has(legend):
				reach[legend] = []
			(reach[legend] as Array).append_array(qa.core_reach[legend])
		qa.queue_free()
		await process_frame
	# Drawn core body around the sim position: what each legend's pushbox should cover.
	for legend: StringName in reach:
		var values: Array = reach[legend]
		var flat: Array = values.map(func(v: Vector3) -> float: return v.x)
		var top: Array = values.map(func(v: Vector3) -> float: return v.y)
		var bottom: Array = values.map(func(v: Vector3) -> float: return v.z)
		flat.sort()
		top.sort()
		bottom.sort()
		print("core %s: reach p50 %.3f p95 %.3f p99 %.3f max %.3f; top p99 %.3f; bottom p01 %.3f" % [legend,
			flat[flat.size() / 2], flat[int(flat.size() * 0.95)], flat[int(flat.size() * 0.99)], flat[-1],
			top[int(top.size() * 0.99)], bottom[int(bottom.size() * 0.01)]])
	print("VISUAL QA %s: %d failing violations" % ["PASS" if failed == 0 else "FAIL", failed])
	quit(1 if failed > 0 else 0)
