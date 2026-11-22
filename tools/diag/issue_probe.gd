extends SceneTree
## Issue sweep probe: all-AI ZoneMatch runs (classic zone look, headless) measuring
## #128 spawn gaps, #73 body overlap / head stands and #106 repeated AI strings.
##   godot --headless --path . -s res://tools/diag/issue_probe.gd -- [spawns|fight] [ticks]

const ZONE_MATCH := "res://game/levels/zone_match.tscn"
## A string is the hits one attacker lands on one target with gaps under this (ticks).
const STRING_GAP := 45
## Head stand: planar distance under the pushbox reach and the higher body's centre this high above.
const HEAD_STAND_DY := Vector2(1.2, 2.4)

var _runs: Array = [
	{"name": "1v1 stormfall kael-brann", "zone": &"stormfall_city", "legends": [&"kael", &"brann"], "level": 3},
	{"name": "ffa4 frozen_peaks", "zone": &"frozen_peaks", "legends": [&"vexa", &"lyra", &"kael", &"brann"], "level": 3},
	{"name": "1v1 shattered_mesa vexa-lyra lv4", "zone": &"shattered_mesa", "legends": [&"vexa", &"lyra"], "level": 4},
	{"name": "ffa4 heartbloom lv4", "zone": &"heartbloom_gardens", "legends": [&"kael", &"brann", &"vexa", &"lyra"], "level": 4},
]


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	var what := args[0] if args.size() > 0 else "fight"
	var ticks := int(args[1]) if args.size() > 1 else 3600
	var seeds: Array[int] = [7]
	if args.size() > 2:
		seeds.clear()
		for part in args[2].split(","):
			seeds.append(int(part))
	if what == "spawns":
		await _spawns()
	else:
		for seed_value in seeds:
			for run: Dictionary in _runs:
				await _fight(run, ticks, seed_value)
	quit(0)


func _build(zone: StringName, legends: Array, level: int, seed_value: int) -> ZoneMatch:
	var fighters := []
	for i in legends.size():
		fighters.append({"character": legends[i], "team": i, "is_ai": true, "ai_level": level})
	var node: ZoneMatch = (load(ZONE_MATCH) as PackedScene).instantiate()
	node.sim.rng.seed = seed_value
	node.configure({"zone": zone, "fighters": fighters, "rounds": 99,
		"mode": &"ffa" if legends.size() > 2 else &"versus", "voxel_zone": false})
	root.add_child(node)
	node.set_process(false)
	node.set_physics_process(false)
	await process_frame
	return node


func _spawns() -> void:
	for zone: StringName in ZoneLayout.ZONE_IDS:
		var node := await _build(zone, [&"kael", &"vexa", &"lyra", &"brann"], 3, 1)
		node.step_tick()
		var sim := node.sim
		var closest := INF
		var surface := INF
		for a in sim.fighters.size():
			for b in range(a + 1, sim.fighters.size()):
				closest = minf(closest, sim.fighters[a].position.distance_to(sim.fighters[b].position))
				surface = minf(surface, Pushboxes.gap(sim.fighters[a], sim.fighters[a].position,
					sim.fighters[b], sim.fighters[b].position))
		print("SPAWN %s ffa4 closest_centres=%.2f m closest_surfaces=%.2f m" % [zone, closest, surface])
		node.queue_free()
		await process_frame


func _fight(run: Dictionary, ticks: int, seed_value: int = 7) -> void:
	var node := await _build(run.zone, run.legends, run.level, seed_value)
	var sim := node.sim
	var deep_ticks := 0
	var head_ticks := 0
	var worst_gap := INF
	var strings := {}
	var current := {}
	var last_hit := {}
	for t in ticks:
		node.step_tick()
		var deep := false
		var head := false
		for a in sim.fighters.size():
			for b in range(a + 1, sim.fighters.size()):
				var one := sim.fighters[a]
				var two := sim.fighters[b]
				if one.health <= 0 or two.health <= 0:
					continue
				var gap := Pushboxes.gap(one, one.position, two, two.position)
				if Pushboxes.collide(sim, a, b):
					worst_gap = minf(worst_gap, gap)
					if gap < -0.10:
						deep = true
				var d := two.position - one.position
				var planar := Vector2(d.x, d.z).length()
				var reach := one.stats.pushbox_radius + two.stats.pushbox_radius
				if planar < reach and absf(d.y) > HEAD_STAND_DY.x and absf(d.y) < HEAD_STAND_DY.y:
					head = true
		deep_ticks += int(deep)
		head_ticks += int(head)
		for event: Dictionary in sim.events:
			if event.type != CombatSim.EventType.HIT and event.type != CombatSim.EventType.COUNTER:
				continue
			if not event.has("move_id") or not event.has("attacker"):
				continue
			var key := "%d>%d" % [event.attacker, event.target]
			if t - int(last_hit.get(key, -1000)) > STRING_GAP and current.has(key):
				strings.get_or_add(event.attacker, []).append(current[key])
				current.erase(key)
			current[key] = (current.get(key, []) as Array) + [String(event.move_id).get_file()]
			last_hit[key] = t
	for key: String in current:
		strings.get_or_add(int(key.get_slice(">", 0)), []).append(current[key])
	var total := 0
	var repeats := 0
	var distinct := {}
	var long_total := 0
	var long_repeats := 0
	for attacker: int in strings:
		var list: Array = strings[attacker]
		for i in list.size():
			total += 1
			distinct[str(attacker) + ":" + "-".join(list[i])] = true
			var repeat: bool = i > 0 and list[i] == list[i - 1]
			repeats += int(repeat)
			if (list[i] as Array).size() >= 3:
				long_total += 1
				long_repeats += int(repeat)
	print("FIGHT %s ticks=%d deep_overlap_ticks=%d (%.2f%%) head_stand_ticks=%d (%.2f%%) worst_pushbox_gap=%.3f m" % [
		run.name, ticks, deep_ticks, 100.0 * deep_ticks / ticks, head_ticks, 100.0 * head_ticks / ticks, worst_gap])
	print("STRINGS %s strings=%d distinct=%d back_to_back_repeats=%d (%.1f%%) 3+hit=%d repeats=%d (%.1f%%)" % [
		run.name, total, distinct.size(), repeats, 100.0 * repeats / maxf(total, 1), long_total, long_repeats,
		100.0 * long_repeats / maxf(long_total, 1)])
	var shown := 0
	for attacker: int in strings:
		print("  attacker %d: %s" % [attacker, " | ".join((strings[attacker] as Array).slice(0, 10).map(
			func(s: Array) -> String: return "-".join(s)))])
		shown += 1
	node.queue_free()
	await process_frame
