extends SceneTree
## Renders the match HUD, control hints and ground markers for review (T-UX1):
## a 1v1 and an FFA-4 with a duplicate legend, fighters lifted into the air.
## godot --path . --rendering-driver opengl3 -s res://game/debug/ux_capture.gd -- <out dir> [prefix]

const SIZE := Vector2i(1280, 720)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://ux"
	var prefix := args[1] if args.size() > 1 else "after"
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE
	await _shoot(out, "%s_1v1" % prefix, [
		{"character": &"kael", "team": 0, "is_ai": false},
		{"character": &"vexa", "team": 1, "is_ai": true, "ai_level": 1},
	])
	await _shoot(out, "%s_ffa" % prefix, [
		{"character": &"vexa", "team": 0, "is_ai": false},
		{"character": &"vexa", "team": 1, "is_ai": true, "ai_level": 1},
		{"character": &"lyra", "team": 2, "is_ai": true, "ai_level": 1},
		{"character": &"brann", "team": 3, "is_ai": true, "ai_level": 1},
	])
	quit(0)


func _shoot(out: String, shot: String, fighters: Array) -> void:
	var level: Node3D = load("res://game/levels/zone_match.tscn").instantiate()
	level.configure({"zone": &"shattered_mesa", "fighters": fighters, "rounds": 3, "mode": &"ffa"})
	root.add_child(level)
	await process_frame
	level.set_physics_process(false)
	level.set_process(false)
	# Hold everyone still, so the shot only shows the lift below.
	level.input_override = func(_slot: int, _tick: int) -> FighterInput: return FighterInput.new()
	for i in 200:
		level.step_tick()
	var sim: CombatSim = level.sim
	for i in sim.fighters.size():
		sim.fighters[i].position.y += [12.0, 6.0, 20.0, 3.0][i]
		sim.fighters[i].velocity = Vector3.ZERO
	level.step_tick()
	level.step_tick()
	level.input_override = Callable()
	for f in 8:
		level.present_frame(1.0, 1.0 / 60.0)
		var hints: Variant = level.get("control_hints")
		if hints != null:
			hints._air_idle = 10.0
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png("%s/%s.png" % [out, shot])
	print("saved %s/%s.png" % [out, shot])
	level.queue_free()
	await process_frame
