extends SceneTree
## Render cost of a real match: zone_match with N AI fighters, pickups and
## projectiles, at one graphics preset. Reports GPU/CPU p95 and what was on
## screen (projectiles, pickups) so the numbers mean something.
##
## godot --path . --resolution 1920x1080 --disable-vsync -s res://game/debug/match_benchmark.gd -- [fighters] [preset] [zone] [armed]
## armed: every fighter starts holding a Storm Repeater and the FightBot
## (game/debug/fight_bot.gd, 2 fighters) keeps firing, as a projectile load test.

const WARMUP_FRAMES := 200
const MEASURED_FRAMES := 1500
const CHARACTERS: Array[StringName] = [&"kael", &"vexa", &"lyra", &"brann"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size() > 0 else 2
	var preset := String(args[1]).to_upper() if args.size() > 1 else "HIGH"
	var zone := StringName(args[2]) if args.size() > 2 else &"heartbloom_gardens"
	var armed := args.size() > 3 and args[3] == "armed"
	var fighters := []
	for i in count:
		fighters.append({"character": CHARACTERS[i % CHARACTERS.size()], "team": i, "is_ai": true, "ai_level": 4})
	var zone_match: ZoneMatch = load("res://game/levels/zone_match.tscn").instantiate()
	zone_match.configure({"zone": zone, "fighters": fighters})
	root.add_child(zone_match)
	if armed:
		zone_match.match_flow.enabled = false
		for fighter in zone_match.sim.fighters:
			fighter.weapons[0] = Weapon.Kind.STORM_REPEATER
			fighter.ammo[0] = 100000
			fighter.active_slot = 0
		var bot_script: GDScript = load("res://game/debug/fight_bot.gd")
		var bot = bot_script.new(zone_match.sim)
		zone_match.input_override = func(i: int, tick: int) -> FighterInput:
			return bot.input_for(i % 2, tick) if i < 2 else FighterInput.new()
	await process_frame
	if not zone_match.vfx_prewarm.is_finished:
		await zone_match.vfx_prewarm.finished
	var settings := GraphicsSettings.new()
	settings.quality = GraphicsSettings.Quality[preset]
	settings.vsync_enabled = false
	settings.apply_to(root)
	var viewport := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	for f in WARMUP_FRAMES:
		await process_frame
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var most_projectiles := 0
	var most_pickups := 0
	for f in MEASURED_FRAMES:
		await process_frame
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport) + RenderingServer.get_frame_setup_time_cpu())
		most_projectiles = maxi(most_projectiles, zone_match.sim.projectiles.size())
		most_pickups = maxi(most_pickups, zone_match.sim.pickups.size())
	gpu.sort()
	cpu.sort()
	print("match benchmark: %s, %d fighters, %s, %s | GPU p95 %.2f max %.2f | CPU p95 %.2f max %.2f | peak projectiles %d, pickups %d" % [
		RenderingServer.get_video_adapter_name(), count, preset, zone,
		gpu[int(gpu.size() * 0.95)], gpu[-1], cpu[int(cpu.size() * 0.95)], cpu[-1],
		most_projectiles, most_pickups])
	quit()
