extends SceneTree
## T-DEF2 drift table: replays every golden with its recorded inputs, ignoring only the new
## dodge fields (FighterDodge.state_values(), appended to each fighter), and names the first tick
## where anything else differs and what happened on it.
##   godot --headless --path . -s res://tools/qa/dodge_drift.gd

const DODGE_FIELDS := 12


func _initialize() -> void:
	print("| golden | first drift (tick) | fields | events on that tick |")
	print("|---|---|---|---|")
	for spec in GoldenReplayCatalog.specs():
		var replay := GoldenReplay.load_file(GoldenReplayCatalog.path_for(spec.name))
		print(_first_drift(replay))
	quit()


func _first_drift(replay: GoldenReplay) -> String:
	var sim := replay.build_sim()
	var per_fighter: int = (replay.fields.fighter as Array).size()
	for index in replay.inputs.size() + 1:
		if index > 0:
			if replay.round_starts.has(index - 1):
				sim.start_round()
			var tick_inputs: Array[FighterInput] = []
			tick_inputs.assign(replay.inputs[index - 1])
			sim.tick(tick_inputs)
		var row := _strip(GoldenReplay.digest_row(sim), sim, per_fighter)
		var golden: PackedByteArray = replay.digests[index]
		if row != golden:
			var names: Array[String] = []
			var sim_count: int = (replay.fields.sim as Array).size()
			for i in mini(row.size(), golden.size()):
				if row[i] != golden[i]:
					if i < sim_count:
						names.append("sim.%s" % replay.fields.sim[i])
					elif i < sim_count + per_fighter * sim.fighters.size():
						var j := i - sim_count
						names.append("f%d.%s" % [j / per_fighter, replay.fields.fighter[j % per_fighter]])
					else:
						names.append("list part")
			var events := PackedStringArray()
			for event in sim.events:
				var who: int = event.get("fighter", event.get("target", -1))
				events.append("%s(f%d)" % [CombatSim.EventType.keys()[int(event.type)], who])
			return "| %s | %d | %s | %s |" % [replay.name, index - 1, ", ".join(names.slice(0, 6)),
				", ".join(events)]
	return "| %s | none | | |" % replay.name


## The digest row without the dodge bytes at the end of each fighter's values.
func _strip(row: PackedByteArray, sim: CombatSim, golden_per_fighter: int) -> PackedByteArray:
	var sim_count := row.size() - sim.fighters.size() * (golden_per_fighter + DODGE_FIELDS) - GoldenReplay.LIST_PARTS.size()
	var out := row.slice(0, sim_count)
	for f in sim.fighters.size():
		var start := sim_count + f * (golden_per_fighter + DODGE_FIELDS)
		out.append_array(row.slice(start, start + golden_per_fighter))
	out.append_array(row.slice(row.size() - GoldenReplay.LIST_PARTS.size()))
	return out
