extends SceneTree
## Where drawn bodies overlap (#73 / QA-11): runs VisualQa on one zone and breaks its
## fighter_vs_fighter frames down by states, parts and depth, plus each legend's core reach.
##   godot --headless --path . -s res://tools/diag/body_overlap.gd -- [zone] [ticks] [seed]


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	var qa := VisualQa.new()
	qa.zone = StringName(args[0]) if args.size() > 0 else &"heartbloom_gardens"
	qa.ticks = int(args[1]) if args.size() > 1 else 1800
	qa.seed_value = int(args[2]) if args.size() > 2 else 1
	root.add_child(qa)
	await qa.run()
	var frames: Array = qa.worst_frames.filter(func(f: Dictionary) -> bool: return f.check == &"fighter_vs_fighter")
	print("OVERLAP %s: %d of %d samples, worst %.3f m" % [qa.zone, frames.size(), qa.samples[&"fighter_vs_fighter"],
		qa.worst[&"fighter_vs_fighter"]])
	var by_states := {}
	var by_parts := {}
	var depths := [0, 0, 0, 0]
	var apart := []
	for f: Dictionary in frames:
		var states: Array = f.states.duplicate()
		states.sort()
		var key := "%s+%s" % states
		by_states[key] = int(by_states.get(key, 0)) + 1
		var parts: Array = f.parts.duplicate()
		parts.sort()
		var part_key := "%s/%s" % parts
		by_parts[part_key] = int(by_parts.get(part_key, 0)) + 1
		var v: float = f.value
		depths[0 if v < 0.1 else 1 if v < 0.2 else 2 if v < 0.4 else 3] += 1
		apart.append(f.apart)
	apart.sort()
	print("  depth <10cm %d, 10-20cm %d, 20-40cm %d, >40cm %d" % depths)
	if not apart.is_empty():
		print("  centre distance at overlap: min %.2f median %.2f max %.2f m" % [apart[0], apart[apart.size() / 2], apart[-1]])
	print("  states: ", _top(by_states))
	print("  parts: ", _top(by_parts))
	for legend: StringName in qa.core_reach:
		var list: Array = qa.core_reach[legend]
		var reach := list.map(func(v: Vector3) -> float: return v.x)
		reach.sort()
		print("  core reach %s: median %.3f p95 %.3f max %.3f m (pushbox r %.2f)" % [legend, reach[reach.size() / 2],
			reach[int(reach.size() * 0.95)], reach[-1], Roster.character(legend).stats.pushbox_radius])
	var worst := frames.duplicate()
	worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.value > b.value)
	for f: Dictionary in worst.slice(0, 8):
		print("  t%d %.2f m %s vs %s %s %s parts %s apart %.2f" % [f.tick, f.value, f.legend, f.other_legend,
			f.states, f.moves, f.parts, f.apart])
	quit(0)


func _top(counts: Dictionary) -> String:
	var keys := counts.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return counts[a] > counts[b])
	return ", ".join(keys.slice(0, 8).map(func(k: String) -> String: return "%s %d" % [k, counts[k]]))
