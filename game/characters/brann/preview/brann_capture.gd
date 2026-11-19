extends SceneTree
## Renders Brann for review: turnarounds, a key-pose sheet of his moves at
## fight distance and close up, and a lineup next to Kael and Vexa with his P2
## palette, and prints the build time and render cost. Needs a window:
## xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-method gl_compatibility \
##   --rendering-driver opengl3 --resolution 1920x1080 -s res://game/characters/brann/preview/brann_capture.gd -- <out dir> [turn|poses|lineup|all]

const SCENE := "res://game/characters/brann/brann.tscn"
const MOVE_SET := "res://game/combat/moves/brann/brann_move_set.tres"
const TURN_ANGLES := {"front": 0.0, "three_quarter": 35.0, "side": 90.0, "back": 180.0}
const SHEET_TILE := Vector2i(320, 360)
const BRANN_ENERGY := Color(1.0, 0.45, 0.15, 0.45)

var _out := ""
var _root: Node3D
var _view: BrannView
var _body: Node3D
var _camera: Camera3D
var _fighter := FighterState.new()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://brann_renders"
	var mode := args[1] if args.size() > 1 else "all"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred(mode)


func _setup_stage() -> void:
	_root = Node3D.new()
	get_root().add_child(_root)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.62, 0.72)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.78, 0.9)
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	_root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-40), deg_to_rad(-150), 0)), Vector3(0, 6, 0))
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	_root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16, 16)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.38, 0.42, 0.4)
	ground.material_override = ground_material
	_root.add_child(ground)
	_body = Node3D.new()
	_body.position = Vector3(0, 1, 0)
	_root.add_child(_body)
	var started := Time.get_ticks_usec()
	_view = (load(SCENE) as PackedScene).instantiate() as BrannView
	_body.add_child(_view)
	var built_ms := (Time.get_ticks_usec() - started) / 1000.0
	_view.set_energy_color(BRANN_ENERGY)
	var cost := FigureRig.render_cost((_view.model as BrannFigure).meshes)
	print("brann: built in %.1f ms, %d triangles, %d draw calls, %d bones" % [built_ms, cost.x, cost.y,
		_view.skeleton().get_bone_count()])
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_root.add_child(_camera)


func _run(mode: String) -> void:
	_setup_stage()
	var started := Time.get_ticks_msec()
	if mode in ["turn", "all"]:
		await _turnarounds()
	if mode in ["poses", "all"]:
		await _pose_sheet()
	if mode in ["lineup", "all"]:
		await _lineup()
	print("brann: rendered in %d ms" % (Time.get_ticks_msec() - started))
	quit()


func _turnarounds() -> void:
	_set_state(FighterState.State.IDLE)
	await _advance(0.5)
	for shot: String in TURN_ANGLES:
		_body.rotation = Vector3(0, deg_to_rad(TURN_ANGLES[shot]), 0)
		_aim(Vector3(0, 1.0, -3.8), Vector3(0, 1.0, 0), 40.0)
		await _frames(2)
		_crop(480, 540).save_png(_out.path_join("brann_turnaround_%s.png" % shot))
	_body.rotation = Vector3.ZERO


## Key poses: at 6 m fight distance (top row) and close up (bottom row).
func _pose_sheet() -> void:
	var moves := load(MOVE_SET) as MoveSet
	var poses := [
		["idle", func() -> void: _set_state(FighterState.State.IDLE), 0.6],
		["hit", func() -> void: _set_state(FighterState.State.HITSTUN), 3.0 / 60.0],
		["smash windup", func() -> void: _set_move(moves.smash), moves.smash.startup_ticks - 4],
		["smash", func() -> void: _set_move(moves.smash), moves.smash.startup_ticks + 2],
		["hammerfall", func() -> void: _set_move(moves.light_string[2]), moves.light_string[2].startup_ticks + 1],
		["ground pound", func() -> void: _set_move(moves.spike), moves.spike.startup_ticks + 2],
		["quake stomp", func() -> void: _set_move(moves.sweep), moves.sweep.startup_ticks + 2],
		["uppercut", func() -> void: _set_move(moves.launcher), moves.launcher.startup_ticks + 2],
	]
	var sheet := Image.create(SHEET_TILE.x * poses.size(), SHEET_TILE.y * 2, false, Image.FORMAT_RGB8)
	for row in 2:
		for i in poses.size():
			await _pose(poses[i])
			_body.rotation = Vector3(0, deg_to_rad(-30), 0)
			if row == 0:
				_aim(Vector3(1.2, 1.7, -5.9), Vector3(0, 1.0, 0), 24.0)
			else:
				_aim(Vector3(0.7, 2.0, -2.0), Vector3(0, 1.2, 0), 46.0)
			await _frames(2)
			var crop := _crop(SHEET_TILE.x, SHEET_TILE.y)
			sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, SHEET_TILE), Vector2i(i * SHEET_TILE.x, row * SHEET_TILE.y))
	sheet.save_png(_out.path_join("brann_poses.png"))


## Kael, Vexa, Brann and Brann's P2 palette side by side, idle, 3/4 view.
func _lineup() -> void:
	_body.visible = false
	var row := Node3D.new()
	_root.add_child(row)
	var entries := [[&"kael", 0], [&"vexa", 0], [&"brann", 0], [&"brann", 1]]
	var views: Array[CharacterView] = []
	for i in entries.size():
		var character := Roster.character(entries[i][0])
		var holder := Node3D.new()
		holder.position = Vector3(2.4 - 1.6 * i, 1, 0)
		holder.rotation = Vector3(0, deg_to_rad(-25), 0)
		row.add_child(holder)
		var view := character.scene.instantiate() as CharacterView
		holder.add_child(view)
		FighterPalette.apply(view, character.palette_for(entries[i][1]))
		views.append(view)
	var idle := FighterState.new()
	idle.enter_state(FighterState.State.IDLE)
	for tick in 36:
		idle.state_ticks += 1
		for view in views:
			view.apply_state(idle, 1.0 / 60.0)
	_camera.position = Vector3(0, 1.3, -7.8)
	_camera.fov = 36.0
	_camera.look_at(Vector3(0, 1.0, 0))
	await _frames(3)
	var image := get_root().get_viewport().get_texture().get_image()
	image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	image.save_png(_out.path_join("brann_lineup.png"))
	row.queue_free()
	_body.visible = true


func _crop(width: int, height: int) -> Image:
	var image := get_root().get_viewport().get_texture().get_image()
	var crop := image.get_region(Rect2i(image.get_width() / 2 - 480, 0, 960, 1080))
	crop.resize(width, height, Image.INTERPOLATE_LANCZOS)
	crop.convert(Image.FORMAT_RGB8)
	return crop


## Sets up one pose entry and plays it for its duration (seconds, or ticks for moves).
func _pose(entry: Array) -> void:
	_view.queue_free()
	_view = (load(SCENE) as PackedScene).instantiate() as BrannView
	_body.add_child(_view)
	_view.set_energy_color(BRANN_ENERGY)
	(entry[1] as Callable).call()
	if _fighter.move:
		for tick in int(entry[2]):
			_fighter.move_tick = tick
			_view.apply_state(_fighter, 1.0 / 60.0)
		await _frames(1)
	else:
		await _advance(entry[2])


func _set_state(state: FighterState.State) -> void:
	_fighter = FighterState.new()
	_fighter.enter_state(state)
	_fighter.stun_ticks = 60


func _set_move(move: MoveData) -> void:
	_fighter = FighterState.new()
	_fighter.begin_move(move)


## Steps the fake fighter at 60 ticks a second for the given seconds.
func _advance(seconds: float) -> void:
	for tick in int(round(seconds * 60.0)):
		_fighter.state_ticks += 1
		_view.apply_state(_fighter, 1.0 / 60.0)
	await _frames(1)


func _aim(from: Vector3, at: Vector3, fov: float) -> void:
	_camera.position = from
	_camera.fov = fov
	_camera.look_at(at)


func _frames(count: int) -> void:
	for i in count:
		await process_frame
