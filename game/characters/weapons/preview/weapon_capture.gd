extends SceneTree
## Renders every weapon model on one contact sheet, then frames of a recorded
## bot fight (two WeaponBots with drops on) in the test arena, for review by eye.
##
## godot --path . --resolution 1920x1080 -s res://game/characters/weapons/preview/weapon_capture.gd -- <out dir>
##
## Keep the output dir outside the repo.

const CELL := Vector2i(480, 480)
const COLUMNS := 4
## Bot fight: seed, ticks to simulate, and the ticks to save frames at.
const FIGHT_SEED := 3
const FIGHT_TICKS := 3600
const FRAME_EVERY := 360


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if not args.is_empty() else ProjectSettings.globalize_path("user://weapons")
	out_dir = out_dir.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _capture_models(out_dir)
	await _capture_held(out_dir)
	if not args.has("--no-fight"):
		await _capture_fight(out_dir)
	print("Weapon frames written to ", out_dir)
	quit()


func _capture_models(out_dir: String) -> void:
	var kinds: Array = Weapon.Kind.values().slice(1)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.22, 0.26, 0.34)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.6, 0.6, 0.7)
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	stage.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.add_child(camera)
	var sheet: Image
	for i in kinds.size():
		var kind: Weapon.Kind = kinds[i]
		var model := WeaponModels.build(kind)
		var length := WeaponModels.length_of(kind)
		model.rotation_degrees = Vector3(0, 35, -35)
		model.position = -WeaponModels.centre_of(model)
		stage.add_child(model)
		camera.size = maxf(length * 1.25, 1.2)
		camera.position = Vector3(0, 0, 5)
		root.size = CELL
		for _f in 3:
			await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.resize(CELL.x, CELL.y)
		if sheet == null:
			var rows := ceili(kinds.size() / float(COLUMNS))
			sheet = Image.create(CELL.x * COLUMNS, CELL.y * rows, false, image.get_format())
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i(i % COLUMNS, i / COLUMNS) * CELL)
		image.save_png(out_dir + "model_%s.png" % Weapon.weapon_name(kind))
		model.queue_free()
	sheet.save_png(out_dir + "weapon_models_sheet.png")
	stage.queue_free()
	root.size = Vector2i(1920, 1080)
	await process_frame


## Kael holding each weapon: idle, then mid-attack on the weapon's first move.
func _capture_held(out_dir: String) -> void:
	var kinds: Array = Weapon.Kind.values().slice(1)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.5, 0.62, 0.78)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.6, 0.6, 0.7)
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	stage.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 40
	camera.position = Vector3(-2.6, 0.4, -4.6)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.1, 0))
	root.size = CELL
	var unarmed: MoveSet = (CombatSim.DEFAULT_FIGHTER_STATS as FighterStats).move_set
	var sheet: Image
	for i in kinds.size():
		var kind: Weapon.Kind = kinds[i]
		var kael: CharacterView = load("res://game/characters/kael_chunky/kael_chunky.tscn").instantiate()
		stage.add_child(kael)
		var skeleton: Skeleton3D = kael.find_children("*", "Skeleton3D", true, false)[0]
		WeaponLayer.attach(skeleton, kind)
		var fighter := FighterState.new()
		fighter.stats = CombatSim.DEFAULT_FIGHTER_STATS
		for pose in 2:
			if pose == 1:
				var move := WeaponMoves.move_set(kind, unarmed).light_string[0]
				fighter.begin_move(move)
				fighter.move_tick = move.startup_ticks
			for _f in 3:
				kael.apply_state(fighter, 1.0 / 60.0)
				await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.resize(CELL.x, CELL.y)
			if sheet == null:
				sheet = Image.create(CELL.x * 6, CELL.y * 4, false, image.get_format())
			var cell := i * 2 + pose
			sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i(cell % 6, cell / 6) * CELL)
		kael.queue_free()
		await process_frame
	sheet.save_png(out_dir + "held_weapons_sheet.png")
	stage.queue_free()
	root.size = Vector2i(1920, 1080)
	await process_frame


func _capture_fight(out_dir: String) -> void:
	var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
	var bots: Array[WeaponBot] = [WeaponBot.new(0, FIGHT_SEED * 3 + 1), WeaponBot.new(1, FIGHT_SEED * 3 + 2)]
	var current := {}
	arena.input_override = func(index: int, tick: int) -> FighterInput:
		if not current.has([index, tick]):
			current[[index, tick]] = bots[index].next_input(arena.sim)
		return current[[index, tick]]
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.set_process(false)
	await process_frame
	if not arena.vfx_prewarm.is_finished:
		await arena.vfx_prewarm.finished
	var log := PackedStringArray()
	for tick in FIGHT_TICKS:
		arena.step_tick()
		if arena.sim.round_over:
			arena.sim.start_round()
		var interesting := _has_weapon_action(arena.sim)
		if tick % FRAME_EVERY == FRAME_EVERY - 1 or (interesting and tick % 37 == 0):
			for _f in 2:
				arena.present_frame(1.0, 1.0 / 60.0)
				await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.save_png(out_dir + "fight_t%04d.png" % tick)
			log.append(_describe(arena.sim, tick))
		else:
			arena.present_frame(1.0, 1.0 / 60.0)
	FileAccess.open(out_dir + "fight.txt", FileAccess.WRITE).store_string("\n".join(log) + "\n")
	arena.queue_free()
	await process_frame


func _has_weapon_action(sim: CombatSim) -> bool:
	return not sim.projectiles.is_empty() or sim.fighters.any(func(f: FighterState) -> bool:
		return f.held_weapon() != Weapon.Kind.NONE and f.state == FighterState.State.ATTACKING)


func _describe(sim: CombatSim, tick: int) -> String:
	var parts := PackedStringArray(["t%04d" % tick])
	for i in sim.fighters.size():
		var f := sim.fighters[i]
		parts.append("f%d %s %s held=%s inv=%s hp=%d" % [i, FighterState.State.keys()[f.state], f.move_id(),
			Weapon.weapon_name(f.held_weapon()), Array(f.weapons).map(func(k: int) -> StringName: return Weapon.weapon_name(k)),
			int(f.health_display())])
	parts.append("pickups=%d projectiles=%d" % [sim.pickups.size(), sim.projectiles.size()])
	return " | ".join(parts)
