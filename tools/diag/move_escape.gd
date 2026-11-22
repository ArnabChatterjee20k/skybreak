extends SceneTree
## Issue #150 repro: an attacker runs light strings at a defender who tries to get
## out (back off, strafe round, dodge, vanish, fly up), with and without the guard,
## pressing between hits or as a hit lands. Prints a table and writes frame logs.
##   godot --headless --path . -s res://tools/diag/move_escape.gd -- [--out DIR] [--ai]

const A := FighterInput.Action
const S := FighterState.State
const E := CombatSim.EventType
const LEGENDS: Array[StringName] = [&"kael", &"vexa", &"brann", &"lyra"]
const WATCH_TICKS := 120

var out_dir := ""
var use_ai := false
var log_legend: StringName = &"kael"


func _initialize() -> void:
	var raw := OS.get_cmdline_user_args()
	var at := raw.find("--out")
	if at >= 0 and at + 1 < raw.size():
		out_dir = raw[at + 1]
		DirAccess.make_dir_recursive_absolute(out_dir)
	use_ai = raw.has("--ai")
	var legend_at := raw.find("--log-legend")
	if legend_at >= 0 and legend_at + 1 < raw.size():
		log_legend = StringName(raw[legend_at + 1])
	var failures := 0
	var total := 0
	for attacker in LEGENDS:
		print("\n### attacker %s (%s), defender kael\n" % [attacker, "AI level 5" if use_ai else "scripted strings"])
		print("| option | guard | timing | escaped at | hits | blocks | refused |")
		print("|---|---|---|---|---|---|---|")
		for option: String in EscapeRepro.OPTIONS:
			for guard in [false, true]:
				for timing: String in EscapeRepro.TIMINGS:
					var repro := EscapeRepro.new(attacker, option, guard, timing, use_ai)
					var result := repro.run(WATCH_TICKS)
					total += 1
					if result.escaped_at < 0:
						failures += 1
					print("| %s | %s | %s | %s | %d | %d | %s |" % [option, "held" if guard else "-", timing,
						"NO" if result.escaped_at < 0 else "%d %s" % [result.escaped_at, result.how], result.hits, result.blocks,
						", ".join(PackedStringArray(result.refused.keys()))])
					if out_dir != "" and attacker == log_legend:
						var name := "%s_%s_%s.log" % [option, "guard" if guard else "open", timing]
						var file := FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
						file.store_string("\n".join(repro.log_lines))
						file.close()
	print("\nescaped %d of %d runs" % [total - failures, total])
	quit(0)
