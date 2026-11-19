extends SceneTree
## Renders the procedural Kael for review: a 4-view turnaround in his stance and contact sheets of
## each attack at its key ticks (0, anticipation, first active, mid active, follow-through, end).
##   godot --path . --resolution 960x1080 -s res://game/characters/kael_procedural/preview/kael_capture.gd -- <out dir> [turnaround|attacks|all]

const PREVIEW := "res://game/characters/kael_procedural/preview/kael_preview.tscn"
const TURN_SIZE := Vector2i(420, 560)
const CELL := Vector2i(300, 400)

var _out := ""
var _view: ProceduralKaelView
var _camera: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://kael_capture"
	var what := args[1] if args.size() > 1 else "all"
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = load(PREVIEW).instantiate()
	root.add_child(scene)
	_run.call_deferred(scene, what)


func _run(scene: Node, what: String) -> void:
	await process_frame
	# The preview cycles clips on its own; stop it and pose him by hand.
	scene.set_process(false)
	scene.set_physics_process(false)
	(scene.get_node("Label") as Label).visible = false
	_view = scene.get_node("ProceduralKael")
	_camera = scene.get_node("Camera3D")
	await _frames(3)
	if what in ["turnaround", "all"]:
		for shot: Array in [["front", 0.0], ["three_quarter", 35.0], ["side", 90.0], ["back", 180.0]]:
			_view.pose_at(&"idle", 0)
			var image := await _shot(shot[1], 4.6, 1.0)
			image = _crop(image, 0.62)
			image.resize(TURN_SIZE.x, TURN_SIZE.y, Image.INTERPOLATE_LANCZOS)
			image.save_png(_out.path_join("kael_turnaround_%s.png" % shot[0]))
	if what in ["attacks", "all"]:
		for clip: StringName in ProceduralKaelView.STRIKE_BONES:
			var move: MoveData = load("res://game/combat/moves/kael/%s.tres" % clip)
			var s := move.startup_ticks
			var a := move.active_ticks
			var ticks := [0, maxi(s - 3, 0), s, s + a / 2, s + a + 3, move.total_ticks() - 1]
			var sheet := Image.create(CELL.x * ticks.size(), CELL.y, false, Image.FORMAT_RGB8)
			for i in ticks.size():
				_view.pose_at(clip, ticks[i])
				var image := await _shot(70.0, 5.2, 0.9)
				image = _crop(image, 0.75)
				image.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
				image.convert(Image.FORMAT_RGB8)
				sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * i, 0))
			sheet.save_png(_out.path_join("kael_%s.png" % clip))
	quit()


## Camera on a circle around him: yaw 0 = in front, positive yaw toward his left.
func _shot(yaw_deg: float, distance: float, height: float) -> Image:
	var yaw := deg_to_rad(yaw_deg)
	var target := Vector3(0, height, 0)
	_camera.fov = 32.0
	_camera.global_position = target + Vector3(-sin(yaw), 0.05, -cos(yaw)) * distance
	_camera.look_at(target)
	await _frames(2)
	return _camera.get_viewport().get_texture().get_image()


func _crop(image: Image, width_fraction: float) -> Image:
	var size := image.get_size()
	var w := int(size.y * width_fraction)
	return image.get_region(Rect2i((size.x - w) / 2, 0, w, size.y))


func _frames(count: int) -> void:
	for i in count:
		await RenderingServer.frame_post_draw
