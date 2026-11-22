extends SceneTree
## T-SP1 strips: each Kael and Vexa special against Brann, 8 frames side by side in one small PNG.
##   xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/qa/special_strip.gd -- OUT_DIR

const A := FighterInput.Action
const SIZE := Vector2i(320, 220)
## name, legend, gap (m), my key, my vertical, opponent [tick, held], frames after the press.
const SCENARIOS := [
	["kael_comet_drive", &"kael", 7.0, A.SPECIAL_1, 0, [], [0, 6, 11, 14, 17, 20, 26, 36]],
	["kael_comet_drive_rise", &"kael", 6.0, A.SPECIAL_1, 1, [], [0, 6, 11, 14, 17, 22, 30, 40]],
	["kael_gale_counter", &"kael", 1.6, A.SPECIAL_2, 0, [[4, A.LIGHT]], [0, 3, 6, 9, 13, 17, 22, 30]],
	["kael_skyfall", &"kael", 4.0, A.SPECIAL_3, 0, [[0, A.BLOCK]], [0, 5, 10, 15, 19, 22, 27, 36]],
	["vexa_shade_flicker", &"vexa", 5.0, A.SPECIAL_1, 0, [], [0, 4, 8, 10, 12, 15, 20, 28]],
	["vexa_mirage_step", &"vexa", 1.7, A.SPECIAL_2, 0, [[2, A.LIGHT]], [0, 3, 6, 9, 12, 15, 20, 30]],
	["vexa_razor_waltz", &"vexa", 2.5, A.SPECIAL_3, 0, [], [0, 7, 10, 14, 18, 22, 27, 36]],
]

var sim: CombatSim
var views: Array[CharacterView] = []
var bodies: Array[Node3D] = []
var prev: Array[FighterInput] = []
var decoy: MeshInstance3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://strip"
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE
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
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	world.add_child(ground)
	decoy = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.45
	capsule.height = 1.9
	decoy.mesh = capsule
	var ghost := StandardMaterial3D.new()
	ghost.albedo_color = Color(0.72, 0.38, 1.0, 0.45)
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	decoy.material_override = ghost
	world.add_child(decoy)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	for scenario: Array in SCENARIOS:
		var gap: float = scenario[2]
		cam.position = Vector3(8.0 + gap * 0.4, 3.0, -gap * 0.5)
		cam.look_at(Vector3(0, 1.2, -gap * 0.5))
		sim = CombatSim.new(3)
		sim.add_fighter(Vector3.ZERO, Roster.character(scenario[1]).stats)
		sim.add_fighter(Vector3(0, 0, -gap), Roster.character(&"brann").stats)
		sim.lock_everyone_onto_nearest()
		prev = [FighterInput.new(), FighterInput.new()]
		for body in bodies:
			body.queue_free()
		bodies.clear()
		views.clear()
		for id: StringName in [scenario[1], &"brann"]:
			var body := Node3D.new()
			world.add_child(body)
			var view := Roster.character(id).scene_for().instantiate() as CharacterView
			body.add_child(view)
			bodies.append(body)
			views.append(view)
		var press_at := 10
		var frames: Array = scenario[6]
		var strip := Image.create(SIZE.x * frames.size(), SIZE.y, false, Image.FORMAT_RGBA8)
		var held_by_opponent := 0
		for t in press_at + (frames.back() as int) + 1:
			var rel := t - press_at
			var a := FighterInput.from_held(scenario[3] if rel == 0 else 0, prev[0])
			a.vertical = scenario[4] if rel == 0 else 0
			for step: Array in scenario[5]:
				if rel == step[0]:
					held_by_opponent = step[1]
				elif step[1] != A.BLOCK and rel == step[0] + 2:
					held_by_opponent = 0
			var b := FighterInput.from_held(held_by_opponent, prev[1])
			var inputs: Array[FighterInput] = [a, b]
			sim.tick(inputs)
			prev = inputs
			for i in 2:
				var f := sim.fighters[i]
				bodies[i].position = f.position
				bodies[i].rotation = Vector3(0, f.facing_yaw, 0)
				views[i].apply_state(f, 1.0 / 60.0)
			var specials := sim.fighters[0].specials
			decoy.visible = specials.has_decoy()
			decoy.position = specials.decoy_position
			for event in sim.events:
				var type: String = CombatSim.EventType.keys()[event.type]
				if type in ["HIT", "COUNTER", "BLOCK", "GUARD_BREAK", "SPECIAL_START", "SPECIAL_COUNTER",
						"SPECIAL_BLINK", "DECOY_SPAWN", "DECOY_BURST"]:
					print("%s f%d %s %s" % [scenario[0], rel + 1, type, event.get("move_id", "")])
			var index := frames.find(rel)
			if index >= 0:
				await process_frame
				await RenderingServer.frame_post_draw
				var img := root.get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				strip.blit_rect(img, Rect2i(Vector2i.ZERO, SIZE), Vector2i(index * SIZE.x, 0))
		strip.save_png("%s/%s.png" % [out, scenario[0]])
		print("wrote %s/%s.png" % [out, scenario[0]])
	quit()
