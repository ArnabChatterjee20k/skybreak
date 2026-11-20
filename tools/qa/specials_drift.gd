extends SceneTree
## T-SP1 drift table: replays every golden with its recorded inputs and names the first tick
## where the state differs, what happened on it, and each Kael's Momentum / Vexa's decoy then.
##   godot --headless --path . -s res://tools/qa/specials_drift.gd


func _initialize() -> void:
	print("| golden | first drift (tick) | events on that tick | special state then |")
	print("|---|---|---|---|")
	for spec in GoldenReplayCatalog.specs():
		var replay := GoldenReplay.load_file(GoldenReplayCatalog.path_for(spec.name))
		print(_first_drift(replay))
	quit()


func _first_drift(replay: GoldenReplay) -> String:
	var sim := replay.build_sim()
	for index in replay.inputs.size() + 1:
		if index > 0:
			if replay.round_starts.has(index - 1):
				sim.start_round()
			var tick_inputs: Array[FighterInput] = []
			tick_inputs.assign(replay.inputs[index - 1])
			sim.tick(tick_inputs)
		if GoldenReplay.digest_row(sim) != replay.digests[index]:
			var events := PackedStringArray()
			for event in sim.events:
				var who: int = event.get("attacker", event.get("fighter", -1))
				events.append("%s(f%d %s)" % [CombatSim.EventType.keys()[int(event.type)], who,
					event.get("move_id", "")])
			var specials := PackedStringArray()
			for i in sim.fighters.size():
				var fighter := sim.fighters[i]
				if SpecialRules.kit_of(fighter) != null:
					specials.append("f%d %s momentum %d decoy %d used %d" % [i, SpecialRules.kit_of(fighter).legend,
						fighter.specials.momentum, fighter.specials.decoy_ticks, fighter.specials.used])
			return "| %s | %d | %s | %s |" % [replay.name, index - 1, ", ".join(events), "; ".join(specials)]
	return "| %s | none | | |" % replay.name
