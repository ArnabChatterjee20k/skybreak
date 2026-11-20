extends SceneTree
## T-DEF2 strip: Kael sidesteps (then perfect-dodges with a spot dodge) a Brann attack;
## renders every few ticks to small PNGs.
##   xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/qa/dodge_strip.gd -- OUT_DIR

const A := FighterInput.Action
const FRAMES := [0, 2, 4, 6, 8, 10, 12, 14, 18, 24]

var sim: CombatSim
var views: Array[CharacterView] = []
var bodies: Array[Node3D] = []
var prev: Array[FighterInput] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://strip"
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(480, 300)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.7, 0.9)
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.environment.ambient_light_energy = 0.8
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor.mesh = plane
	world.add_child(floor)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(5.5, 3.2, -1.0)
	cam.look_at(Vector3(0, 1.0, -1.0))
	cam.current = true
	for scenario in ["sidestep_vs_sweep", "spot_perfect_vs_smash"]:
		sim = CombatSim.new(3)
		sim.add_fighter(Vector3(0, 0, 0), Roster.character(&"kael").stats)
		sim.add_fighter(Vector3(0, 0, -1.8), Roster.character(&"brann").stats)
		sim.lock_everyone_onto_nearest()
		prev = [FighterInput.new(), FighterInput.new()]
		for v in bodies:
			v.queue_free()
		bodies.clear()
		views.clear()
		for id in [&"kael", &"brann"]:
			var body := Node3D.new()
			world.add_child(body)
			var view := Roster.character(id).scene.instantiate() as CharacterView
			body.add_child(view)
			bodies.append(body)
			views.append(view)
		var attack_move := Vector2(1, 0) if scenario == "sidestep_vs_sweep" else Vector2.ZERO
		var move: MoveData = sim.fighters[1].stats.move_set.sweep if scenario == "sidestep_vs_sweep" \
			else sim.fighters[1].stats.move_set.smash
		var press_at := 20 + move.startup_ticks - 4
		for t in 20 + move.startup_ticks + 30:
			var a := FighterInput.from_held(A.DASH if t == press_at else 0, prev[0])
			if t == press_at and scenario == "sidestep_vs_sweep":
				a.move = Vector2(1, 0)
			var b := FighterInput.from_held(A.HEAVY if t == 20 else 0, prev[1])
			b.move = attack_move if t >= 20 and t < 22 else Vector2.ZERO
			var inputs: Array[FighterInput] = [a, b]
			sim.tick(inputs)
			prev = inputs
			for i in 2:
				var f := sim.fighters[i]
				bodies[i].position = f.position - Vector3(0, 1, 0) + Vector3(0, 1, 0)
				bodies[i].rotation = Vector3(0, f.facing_yaw, 0)
				views[i].apply_state(f, 1.0 / 60.0)
			for event in sim.events:
				if event.type in [CombatSim.EventType.PERFECT_DODGE, CombatSim.EventType.HIT, CombatSim.EventType.DODGE]:
					print("%s t%d %s" % [scenario, t, CombatSim.EventType.keys()[event.type]])
			var rel := t - press_at
			if rel in FRAMES:
				await process_frame
				await RenderingServer.frame_post_draw
				var img := root.get_texture().get_image()
				img.save_png("%s/%s_f%02d.png" % [out, scenario, rel + 1])
	quit()
