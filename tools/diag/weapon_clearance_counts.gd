extends SceneTree
## Held-weapon clipping frames per legend over the VisualQa zone runs (QA-20):
## weapon_vs_holder (VisualQa) and weapon_vs_body (QaViewChecks weapon_in_body).
## godot --headless --path . -s res://tools/diag/weapon_clearance_counts.gd [-- --ticks=3600]

const RUNS := [[&"heartbloom_gardens", 1], [&"frozen_peaks", 2], [&"shattered_mesa", 3]]


class CountingQa extends VisualQa:
	var view_checks: QaViewChecks
	var body_hits := {}
	var body_frames := {}

	func _measure(tick: int) -> void:
		super._measure(tick)
		if view_checks == null:
			view_checks = QaViewChecks.new(match_node)
		for v in view_checks.check_frame():
			if String(v.check) == "weapon_in_body":
				var legend := _legend(int(v.fighter))
				body_hits[legend] = int(body_hits.get(legend, 0)) + 1
				body_frames[legend] = body_frames.get(legend, []) + [[tick, v.detail]]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ticks := 3600
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ticks="):
			ticks = int(arg.get_slice("=", 1))
	var holder := {}
	var body := {}
	var zone := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--zone="):
			zone = arg.get_slice("=", 1)
	for run in RUNS:
		if zone != "" and String(run[0]) != zone:
			continue
		var qa := CountingQa.new()
		qa.zone = run[0]
		qa.seed_value = run[1]
		qa.ticks = ticks
		root.add_child(qa)
		await qa.run()
		var per := {}
		var kinds := {}
		for f: Dictionary in qa.worst_frames:
			if f.check == &"weapon_vs_holder":
				per[f.legend] = int(per.get(f.legend, 0)) + 1
				var solved := "solver_clear" if float(f.solver) <= 0.0 else ("trimmed" if float(f.trim) > 0.0 else "solver_left")
				var key := "%s/%s/%s %s %s %s" % [f.legend, f.kind, f.move, f.state, f.capsule, solved]
				kinds[key] = int(kinds.get(key, 0)) + 1
				if OS.get_cmdline_user_args().has("--frames"):
					print("  frame %s tick %d %s %s %s depth %.3f %s solver %.3f trim %.3f %s" % [f.legend, f.tick, f.kind, f.state, f.move, f.value, f.capsule, f.solver, f.trim, f.trim_bone])
		print("%s seed %d: weapon_vs_holder %d (worst %.3f m) %s; weapon_vs_body %s" % [run[0], run[1],
			qa.violations[&"weapon_vs_holder"], qa.worst[&"weapon_vs_holder"], per, qa.body_hits])
		for key: String in kinds:
			print("  holder %s: %d" % [key, kinds[key]])
		for legend: StringName in qa.body_frames:
			for frame: Array in (qa.body_frames[legend] as Array).slice(0, 6):
				print("  body %s tick %d: %s" % [legend, frame[0], frame[1]])
		for legend: StringName in qa.legends:
			holder[legend] = int(holder.get(legend, 0)) + int(per.get(legend, 0))
			body[legend] = int(body.get(legend, 0)) + int(qa.body_hits.get(legend, 0))
		qa.queue_free()
		await process_frame
	print("TOTAL weapon_vs_holder %s" % holder)
	print("TOTAL weapon_vs_body %s" % body)
	quit()
