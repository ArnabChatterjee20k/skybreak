extends SceneTree
## Renders chunky Kael for review with the real toon shader. Each turnaround image is a close-up
## next to the same view at fight distance (6 m, the game's 75 degree FOV, native 1080p pixels).
##   godot --path . --resolution 1920x1080 -s res://game/characters/kael_chunky/preview/kael_chunky_capture.gd -- <out dir> [turnaround|poses|attacks|states|all]

const SCENE := "res://game/characters/kael_chunky/kael_chunky.tscn"
const MOVE_DIR := "res://game/combat/moves/kael/"
const CLOSE := Vector2i(300, 400)
const FAR := Vector2i(300, 400)
const CELL := Vector2i(240, 320)
const FIGHT_DISTANCE := 6.0
const GAME_FOV := 75.0
const ENERGY := Color(1.0, 0.6, 0.2, 0.0)
## Key poses for the pose sheet: label, state or move, tick.
const POSES := [
	["idle", "IDLE", 20], ["jab", "light_1", 7], ["kick", "light_4", 11], ["spike", "spike", 16],
	["power-up", "CHARGING", 30], ["flight", "FLYING_FAST", 20],
]

var _out := ""
var _view: CharacterView
var _camera: Camera3D
var _fighter := FighterState.new()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://kael_chunky_capture"
	var what := args[1] if args.size() > 1 else "all"
	DirAccess.make_dir_recursive_absolute(_out)
	var stage := _stage()
	root.add_child(stage)
	_view = (load(SCENE) as PackedScene).instantiate() as CharacterView
	var body := Node3D.new()
	body.position = Vector3(0, 1, 0)
	stage.add_child(body)
	body.add_child(_view)
	_view.set_energy_color(ENERGY)
	_run.call_deferred(what)


func _run(what: String) -> void:
	await _frames(3)
	if what in ["turnaround", "all"]:
		for shot: Array in [["front", 0.0], ["three_quarter", 35.0], ["side", 90.0], ["back", 180.0]]:
			await _pose("IDLE", 20)
			var sheet := Image.create(CLOSE.x + FAR.x, CLOSE.y, false, Image.FORMAT_RGB8)
			_blit(sheet, await _close(shot[1], CLOSE), Vector2i.ZERO)
			_blit(sheet, await _far(shot[1], FAR), Vector2i(CLOSE.x, 0))
			sheet.save_png(_out.path_join("kael_chunky_turnaround_%s.png" % shot[0]))
	if what in ["poses", "all"]:
		var sheet := Image.create(CELL.x * POSES.size(), CELL.y * 2, false, Image.FORMAT_RGB8)
		for i in POSES.size():
			await _pose(POSES[i][1], POSES[i][2])
			var yaw := 60.0 if POSES[i][1] in ["light_4", "spike", "light_1"] else 30.0
			_blit(sheet, await _close(yaw, CELL), Vector2i(CELL.x * i, 0))
			_blit(sheet, await _far(yaw, CELL), Vector2i(CELL.x * i, CELL.y))
		sheet.save_png(_out.path_join("kael_chunky_poses.png"))
	if what in ["attacks", "all"]:
		for file in DirAccess.get_files_at(MOVE_DIR):
			if not file.ends_with(".tres") or file == "kael_move_set.tres":
				continue
			var move: MoveData = load(MOVE_DIR + file)
			var s := move.startup_ticks
			var a := move.active_ticks
			var ticks := [0, maxi(s - 4, 0), s, s + a / 2, s + a + 3, move.total_ticks() - 1]
			var sheet := Image.create(CELL.x * ticks.size(), CELL.y, false, Image.FORMAT_RGB8)
			for i in ticks.size():
				await _pose(String(move.id), ticks[i])
				_blit(sheet, await _close(70.0, CELL), Vector2i(CELL.x * i, 0))
			sheet.save_png(_out.path_join("attack_%s.png" % move.id))
	if what in ["states", "all"]:
		var states := ["IDLE", "MOVING", "FLYING", "FLYING_FAST", "DASHING", "CHARGING", "FALLING", "BLOCKING",
			"HITSTUN", "BLOCKSTUN", "KNOCKDOWN", "GUARD_BROKEN"]
		var columns := 4
		var sheet := Image.create(CELL.x * columns, CELL.y * states.size(), false, Image.FORMAT_RGB8)
		for row in states.size():
			for i in columns:
				await _pose(states[row], 1 + i * 12)
				_blit(sheet, await _close(35.0, CELL), Vector2i(CELL.x * i, CELL.y * row))
		sheet.save_png(_out.path_join("states.png"))
	quit()


## Poses the view: a FighterState state name (FLYING_FAST and BLOCKING are variants) at a state
## tick, or a move id at a move tick. Steps every tick so the scarf has its real lag.
func _pose(what: String, tick: int) -> void:
	_fighter = FighterState.new()
	var move_path := MOVE_DIR + what + ".tres"
	if ResourceLoader.exists(move_path):
		_fighter.begin_move(load(move_path))
		for t in tick + 1:
			_fighter.move_tick = t
			_view.apply_state(_fighter, 1.0 / 60.0)
			await process_frame
		return
	var state := what.trim_suffix("_FAST")
	if what == "BLOCKING":
		state = "IDLE"
		_fighter.blocking = true
	_fighter.enter_state(FighterState.State[state])
	_fighter.stun_ticks = 60
	if what == "FLYING_FAST":
		_fighter.velocity = Vector3(0, 0, -25)
	if what == "MOVING":
		_fighter.velocity = Vector3(0, 0, -9)
	for t in tick + 1:
		_fighter.state_ticks = t
		_view.apply_state(_fighter, 1.0 / 60.0)
		await process_frame


## Tight framing on the whole body. Yaw 0 = in front, positive toward his left.
func _close(yaw_deg: float, size: Vector2i) -> Image:
	_aim(yaw_deg, 6.4, 24.0, 1.0)
	var image := await _grab()
	var h := image.get_height()
	var w := int(h * float(size.x) / size.y)
	image = image.get_region(Rect2i((image.get_width() - w) / 2, 0, w, h))
	image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return image


## Fight distance at the game FOV: a native-pixel crop around him (no scaling).
func _far(yaw_deg: float, size: Vector2i) -> Image:
	_aim(yaw_deg, FIGHT_DISTANCE, GAME_FOV, 1.0)
	var image := await _grab()
	var centre := image.get_size() / 2
	return image.get_region(Rect2i(centre - size / 2, size))


func _aim(yaw_deg: float, distance: float, fov: float, height: float) -> void:
	var yaw := deg_to_rad(yaw_deg)
	var target := Vector3(0, height, 0)
	_camera.fov = fov
	_camera.global_position = target + Vector3(-sin(yaw), 0.08, -cos(yaw)) * distance
	_camera.look_at(target)


func _grab() -> Image:
	await _frames(2)
	var image := _camera.get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	return image


func _blit(sheet: Image, image: Image, at: Vector2i) -> void:
	sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), at)


func _frames(count: int) -> void:
	for i in count:
		await RenderingServer.frame_post_draw


func _stage() -> Node3D:
	var stage := Node3D.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.32, 0.5, 0.8)
	sky_material.sky_horizon_color = Color(0.72, 0.78, 0.86)
	sky_material.ground_horizon_color = Color(0.72, 0.78, 0.86)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-45), deg_to_rad(30), 0)), Vector3(0, 6, 0))
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.36, 0.4, 0.36)
	ground.material_override = ground_material
	stage.add_child(ground)
	_camera = Camera3D.new()
	stage.add_child(_camera)
	_camera.current = true
	return stage
