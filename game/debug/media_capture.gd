extends SceneTree
## Progress-video segments with Movie Maker (sound included):
##   menu  - main menu -> character select (Kael, Vexa) -> zone select (Heartbloom)
##   duel  - zone_match, Kael vs Vexa, both AI, seeded; stops ~3.5 s after the first KO
##   ffa   - zone_match, 4 legends AI, for a fixed number of frames
## godot --path . --write-movie out.avi --fixed-fps 60 -s res://game/debug/media_capture.gd -- <segment> [zone] [seed] [frames]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var segment: String = args[0] if args.size() > 0 else "duel"
	var zone := StringName(args[1]) if args.size() > 1 else &"heartbloom_gardens"
	var seed_value := int(args[2]) if args.size() > 2 else 2
	var frames := int(args[3]) if args.size() > 3 else 900
	match segment:
		"menu":
			await _menu(zone)
		"duel":
			await _match(zone, seed_value, [&"kael", &"vexa"], -1)
		"ffa":
			await _match(zone, seed_value, [&"kael", &"vexa", &"lyra", &"brann"], frames)
	quit()


func _wait(seconds: float) -> void:
	for f in roundi(seconds * 60.0):
		await process_frame


func _menu(zone: StringName) -> void:
	var front: Node = load("res://game/ui/menus/front_end.tscn").instantiate()
	front.skip_splash = true
	root.add_child(front)
	await _wait(1.6)
	front._on_mode_chosen(&"vs_ai")
	front.go(&"character_select")
	var select: CharacterSelect = front.screens[&"character_select"]
	select.set_active_slot(0)
	select.select_legend(&"kael")
	await _wait(1.0)
	if select.slots.size() > 1:
		select.set_active_slot(1)
		select.select_legend(&"vexa")
	await _wait(1.0)
	front.go(&"zone_select")
	var zones: ZoneSelect = front.screens[&"zone_select"]
	zones.select_zone(zone)
	await _wait(1.6)


func _match(zone: StringName, seed_value: int, characters: Array, frames: int) -> void:
	var fighters := []
	for i in characters.size():
		fighters.append({"character": characters[i], "team": i, "is_ai": true, "ai_level": 3})
	var zone_match: ZoneMatch = load("res://game/levels/zone_match.tscn").instantiate()
	zone_match.configure({"zone": zone, "fighters": fighters})
	zone_match.sim.rng.seed = seed_value
	root.add_child(zone_match)
	var ko_frame := -1
	var f := 0
	while true:
		await process_frame
		f += 1
		if frames > 0 and f >= frames:
			break
		if ko_frame < 0 and zone_match.match_flow.phase == MatchFlow.Phase.KO:
			ko_frame = f
		if ko_frame >= 0 and f > ko_frame + 210:
			break
		if f > 9000:
			break
