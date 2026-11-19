extends SceneTree
## Dumps full-precision fighter state per tick for the flat-floor golden
## sequences, to diff platforms (Windows vs Linux).
## godot --headless --path . -s res://tools/diag/golden_dump.gd -- <out.txt>


func _initialize() -> void:
	_run.call_deferred()


func _line(name: String, sim: CombatSim) -> String:
	var parts := PackedStringArray(["%s t%d %s" % [name, sim.current_tick, FlatFloorSequences.fingerprint(sim)]])
	for f in sim.fighters:
		parts.append("p=%s v=%s s=%d" % [var_to_str(f.position), var_to_str(f.velocity), f.state])
	return " | ".join(parts)


func _run() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://golden_dump.txt"
	var lines := PackedStringArray()
	var combat := load("res://tests/combat/test_combat_sim.gd").new() as Node
	combat._run_match(FlatFloorSequences.FREE_FOR_ALL_SEED, 120, {}, 4,
		func(sim: CombatSim) -> void: lines.append(_line("ffa", sim)))
	combat.free()
	var weapons := load("res://tests/combat/test_weapons.gd").new() as Node
	weapons._bot_match(FlatFloorSequences.BOT_MATCH_SEED, 450, &"skyhold_ruins",
		func(sim: CombatSim) -> void: lines.append(_line("bot", sim)))
	weapons.free()
	FileAccess.open(out_path, FileAccess.WRITE).store_string("\n".join(lines) + "\n")
	print("wrote ", lines.size(), " lines to ", out_path)
	quit()
