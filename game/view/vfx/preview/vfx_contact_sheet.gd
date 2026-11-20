extends SceneTree
## Renders every T-D27 effect mid-flight into one contact sheet PNG for review by eye.
## godot --path . --rendering-method gl_compatibility --resolution 960x600 -s res://game/view/vfx/preview/vfx_contact_sheet.gd -- <out dir>

const CELL := Vector2i(480, 300)
const COLUMNS := 5
## Seconds into each effect when the cell is captured.
const SHOT_AT := {
	&"ki_blast": 0.15, &"ki_beam": 0.75, &"ko_burst": 0.3, &"lightning": 0.08, &"petals": 0.5,
	&"aura_flare": 0.18, &"landing_dust": 0.2, &"guard_shatter": 0.12,
}

var _out_dir := "."
var _vfx: MatchVfx
var _label: Label
var _camera: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_build_stage()
	_run.call_deferred()


func _build_stage() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.2, 0.32)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.65, 0.8)
	var env_node := WorldEnvironment.new()
	env_node.environment = environment
	world.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.36, 0.4, 0.34)
	ground.material_override = ground_material
	ground.position = Vector3(0, -1.0, 0)
	world.add_child(ground)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 2.0
	body.mesh = capsule
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.85, 0.4, 0.25)
	body.material_override = body_material
	body.position = Vector3(-1.6, 0, 0)
	world.add_child(body)
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 1.6, 7.5)
	_camera.fov = 60.0
	world.add_child(_camera)
	_camera.look_at_from_position(_camera.position, Vector3(0, 0.6, 0))
	_vfx = MatchVfx.new()
	world.add_child(_vfx)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	_label = Label.new()
	_label.position = Vector2(10, 6)
	_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(_label)


func _run() -> void:
	var kinds := VfxCatalog.kinds()
	var shots: Array[Image] = []
	for kind in kinds:
		_label.text = String(kind)
		var effect := _play(kind)
		effect.set_process(false)
		var at: float = SHOT_AT.get(kind, 0.1)
		# A few real frames so particles emit, then pin the animation at `at`.
		for i in 4:
			await process_frame
		effect.advance(maxf(at - effect.age(), 0.0))
		await process_frame
		await process_frame
		shots.append(_grab())
		effect.stop()
	var screen := _vfx.screen()
	for mode in ["lines", "impact", "pop"]:
		_label.text = "screen: " + mode
		var blast := _vfx.spawn(&"anime_burst", Vector3.ZERO, Color(1, 0.55, 0.2))
		blast.set_process(false)
		blast.advance(0.08)
		match mode:
			"lines":
				screen.burst_lines(Vector2(0.5, 0.5), Color.WHITE, 10.0)
			"impact":
				screen.impact(Color(1, 0.55, 0.2), Vector2(0.5, 0.5), 3)
			_:
				screen.color_pop(VfxScreen.SKY_POP, 10.0)
		await process_frame
		shots.append(_grab())
		blast.stop()
		await process_frame
		await process_frame
		screen.advance(20.0)
	var rows := ceili(float(shots.size()) / COLUMNS)
	var sheet := Image.create(CELL.x * COLUMNS, CELL.y * rows, false, Image.FORMAT_RGB8)
	for i in shots.size():
		var shot := shots[i]
		shot.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, CELL), Vector2i(i % COLUMNS, i / COLUMNS) * CELL)
	var path := _out_dir.path_join("vfx_contact_sheet.png")
	sheet.save_png(path)
	print("wrote ", path, " (", shots.size(), " cells)")
	quit()


func _grab() -> Image:
	var image := root.get_texture().get_image()
	image.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	return image


func _play(kind: StringName) -> VfxEffect:
	var warm := Color(1.0, 0.55, 0.2)
	match kind:
		&"ki_blast":
			return _vfx.play_ki_blast(Vector3(-3, 0.5, 0), Vector3(4, 0.5, 0), warm, 20.0)
		&"ki_beam":
			return _vfx.play_beam(Vector3(-3.5, 0.5, 0), Vector3(3.5, 0.5, 0), Color(0.35, 0.8, 1.0), 0.4, 1.5, true)
		&"lightning":
			return _vfx.spawn(kind, Vector3(0, -1, -4), Color.TRANSPARENT, 1.0)
		&"landing_dust":
			var dust := _vfx.spawn(kind, Vector3(0, -1, 0), MatchVfx.ground_for(&"shattered_mesa")[0], 1.2)
			dust.tint_secondary(MatchVfx.ground_for(&"shattered_mesa")[1])
			return dust
		&"sonic_ring":
			return _vfx.spawn(kind, Vector3(0, 0.5, 0), Color(0.9, 0.95, 1.0), 1.0, MatchVfx.facing_along(Vector3(1, 0, 0.6)))
		&"afterimage":
			return _vfx.spawn(kind, Vector3(0, 0, 0), warm, 1.0, MatchVfx.stretch_along(Vector3(40, 0, 0), 40.0))
		&"aura_flare", &"vanish_burst":
			return _vfx.spawn(kind, Vector3(0, 0, 0), warm)
		&"guard_shatter", &"petals", &"sparkles":
			return _vfx.spawn(kind, Vector3(0, 0.6, 0))
	if String(kind).begins_with("smear_"):
		var style := StringName(String(kind).trim_prefix("smear_"))
		var reach := 3.0 if style == &"lance" else 2.0
		return _vfx.spawn(kind, Vector3(0, 0.2, 0), warm.lerp(Color.WHITE, 0.35), reach, MatchVfx.swing_tilt(&"smash", 0) * Basis(Vector3.UP, -0.5))
	return _vfx.spawn(kind, Vector3(0, 0.6, 0), warm)
