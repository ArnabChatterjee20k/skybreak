extends SceneTree
## Progress-video capture: Kael vs Vexa bots over a world zone, with sound.
## godot --path . --write-movie out.avi --fixed-fps 60 -s res://game/debug/fight_capture.gd -- <zone> <max_frames>
## Stops a second into the second round's intro (or at max_frames).

const ZONE_DEFAULT := &"heartbloom_gardens"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var zone_id := StringName(args[0]) if args.size() > 0 else ZONE_DEFAULT
	var max_frames := int(args[1]) if args.size() > 1 else 3000
	# Optional third argument: solo one bus (audio measurement), muting the others.
	var solo := StringName(args[2]) if args.size() > 2 else &""
	if solo != &"":
		for bus in AudioBuses.ALL:
			if bus != AudioBuses.MASTER:
				AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), bus != solo)
	var world: WorldMap = load("res://game/world/world_map.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var spawn := world.spawn_points(zone_id)[0]
	world.position = -Vector3(spawn.x, world.ground_height_at(spawn.x, spawn.z), spawn.z)
	world.atmosphere.apply_at(spawn)
	for particles in world.atmosphere.weather.values():
		particles.emitting = false
	var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
	for node_name in ["WorldEnvironment", "Sun", "Ground"]:
		arena.get_node(node_name).free()
	arena.sim.zone = zone_id
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.get_node("DebugOverlay").visible = false
	arena.match_cues.zone = zone_id
	var director := root.get_node_or_null(^"AudioDirector")
	if director:
		director.set_zone(zone_id)
	var bot := FightBot.new(arena.sim)
	await process_frame
	if not arena.vfx_prewarm.is_finished:
		await arena.vfx_prewarm.finished
	arena.input_override = bot.input_for
	arena.set_physics_process(true)
	var tail := -1
	for f in max_frames:
		await process_frame
		if tail < 0 and arena.match_flow.round_number >= 2:
			tail = 90
		if tail > 0:
			tail -= 1
		elif tail == 0:
			break
	quit()
