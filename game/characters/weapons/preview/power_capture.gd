extends SceneTree
## Renders the power and gadget models on one contact sheet, staged in-action
## frames in the test arena (auras, tether, mine, decoy, bomb), then frames of
## a PowerBot fight, for review by eye.
##
## godot --path . --resolution 1920x1080 -s res://game/characters/weapons/preview/power_capture.gd -- <out dir>
##
## Keep the output dir outside the repo.

const CELL := Vector2i(400, 400)
const COLUMNS := 4
const FIGHT_SEED := 5
const FIGHT_TICKS := 2400


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if not args.is_empty() else ProjectSettings.globalize_path("user://powers")
	out_dir = out_dir.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _capture_models(out_dir)
	await _capture_staged(out_dir)
	await _capture_fight(out_dir)
	print("Power frames written to ", out_dir)
	quit()


## Every power/gadget drop model, the gadgets as they sit in the world, and the bow's nocked arrow.
func _models() -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	for kind: int in Power.Kind.values().slice(1):
		cells.append({"name": Power.power_name(kind), "node": PowerModels.build(kind), "size": 1.0})
	for kind: Power.Kind in Power.GADGETS:
		var gadget := Gadget.new()
		gadget.kind = kind
		var node := WeaponLayer.make_gadget(gadget)
		var size := 2.6 if kind == Power.Kind.MIRROR_DECOY else 1.6
		if kind == Power.Kind.GRAVITY_MINE:
			node.get_node("Field").visible = false
		cells.append({"name": "world_%s" % Power.power_name(kind), "node": node, "size": size})
	for level in [0, 3]:
		var bow := WeaponModels.build(Weapon.Kind.KI_BOW)
		var arrow := PowerModels.nocked_arrow(false)
		arrow.position = Vector3(0, 0, WeaponLayer.nock_offset(level))
		bow.add_child(arrow)
		var holder := Node3D.new()
		holder.add_child(bow)
		bow.rotation_degrees = Vector3(0, 90, 0)
		cells.append({"name": "bow_draw_%d" % level, "node": holder, "size": 1.8})
	return cells


func _capture_models(out_dir: String) -> void:
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
	camera.position = Vector3(0, 0, 6)
	stage.add_child(camera)
	var cells := _models()
	var rows := ceili(cells.size() / float(COLUMNS))
	var sheet: Image
	root.size = CELL
	for i in cells.size():
		var node: Node3D = cells[i].node
		var turn := Node3D.new()
		turn.rotation_degrees = Vector3(15, -30, 0)
		turn.add_child(node)
		stage.add_child(turn)
		camera.size = cells[i].size
		for _f in 3:
			await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.resize(CELL.x, CELL.y)
		if sheet == null:
			sheet = Image.create(CELL.x * COLUMNS, CELL.y * rows, false, image.get_format())
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i(i % COLUMNS, i / COLUMNS) * CELL)
		turn.queue_free()
		await process_frame
	sheet.save_png(out_dir + "power_models_sheet.png")
	stage.queue_free()
	root.size = Vector2i(1920, 1080)
	await process_frame


func _open_arena(bots: Array) -> Node:
	var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
	var current := {}
	arena.input_override = func(index: int, tick: int) -> FighterInput:
		if bots.is_empty():
			return FighterInput.new()
		if not current.has([index, tick]):
			current[[index, tick]] = bots[index].next_input(arena.sim)
		return current[[index, tick]]
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.set_process(false)
	await process_frame
	if not arena.vfx_prewarm.is_finished:
		await arena.vfx_prewarm.finished
	return arena


func _shoot(arena: Node, path: String) -> void:
	for _f in 2:
		arena.present_frame(1.0, 1.0 / 60.0)
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


## Auras, a tether, a pulling mine, a decoy and a bomb, set up directly on the sim.
func _capture_staged(out_dir: String) -> void:
	var arena: Node = await _open_arena([])
	var sim: CombatSim = arena.sim
	sim.pickups_enabled = false
	for _t in 30:
		arena.step_tick()
		arena.present_frame(1.0, 1.0 / 60.0)
	var me := sim.fighters[0]
	var them := sim.fighters[1]
	me.powers.aegis = true
	me.powers.haste_ticks = 600
	them.powers.overdrive_ticks = 600
	WeaponEffects.tie(sim, 0, 1)
	me.powers.gadget = Power.Kind.MIRROR_DECOY
	PowerRules.use_gadget(sim, 0)
	for _t in 20:
		arena.step_tick()
	await _shoot(arena, out_dir + "staged_auras_tether_decoy.png")
	var mine := Gadget.new()
	mine.id = sim._new_entity_id()
	mine.kind = Power.Kind.GRAVITY_MINE
	mine.owner = 0
	mine.position = (me.position + them.position) * 0.5 + Vector3(0, 1.5, 0)
	mine.phase = Gadget.Phase.PULLING
	mine.ticks_left = 600
	sim.gadgets.append(mine)
	for _t in 10:
		arena.step_tick()
	await _shoot(arena, out_dir + "staged_mine_pulling.png")
	them.powers.gadget = Power.Kind.SPIKE_BOMB
	PowerRules.use_gadget(sim, 1)
	for _t in 6:
		arena.step_tick()
	await _shoot(arena, out_dir + "staged_bomb_flying.png")
	arena.queue_free()
	await process_frame


func _capture_fight(out_dir: String) -> void:
	var bots: Array = [PowerBot.new(0, FIGHT_SEED * 3 + 1), PowerBot.new(1, FIGHT_SEED * 3 + 2)]
	var arena: Node = await _open_arena(bots)
	var sim: CombatSim = arena.sim
	sim.pickup_tuning.spawn_interval_min_ticks = 240
	sim.pickup_tuning.spawn_interval_max_ticks = 360
	var log := PackedStringArray()
	var last_shot := -1000
	for tick in FIGHT_TICKS:
		arena.step_tick()
		if sim.round_over:
			sim.start_round()
		var interesting := not sim.gadgets.is_empty() or sim.events.any(func(e: Dictionary) -> bool:
			return e.type in [CombatSim.EventType.POWER_PICKUP, CombatSim.EventType.GADGET_EXPLODE,
				CombatSim.EventType.PICKUP_SPAWN])
		if interesting and tick - last_shot >= 20:
			last_shot = tick
			await _shoot(arena, out_dir + "fight_t%04d.png" % tick)
			log.append("t%04d gadgets=%s auras=%s events=%s" % [tick,
				sim.gadgets.map(func(g: Gadget) -> StringName: return Power.power_name(g.kind)),
				sim.fighters.map(func(f: FighterState) -> Array: return f.powers.active_auras()),
				sim.events.map(func(e: Dictionary) -> String: return CombatSim.EventType.keys()[e.type])])
		else:
			arena.present_frame(1.0, 1.0 / 60.0)
	FileAccess.open(out_dir + "fight.txt", FileAccess.WRITE).store_string("\n".join(log) + "\n")
	arena.queue_free()
	await process_frame
