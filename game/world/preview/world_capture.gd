extends SceneTree
## Renders review stills of the world map: the top-down map, a hero shot per zone and
## border transitions. Writes PNGs to the directory after `--`.
##
## godot --path . --rendering-method gl_compatibility --resolution 1920x1080 \
##   -s res://game/world/preview/world_capture.gd -- <out dir> [day|dusk|night] [small] [heartbloom]
##
## `small` writes the 960x540 (map 600x600) versions committed in preview/renders/.
## `heartbloom` renders only the map and the Heartbloom Gardens shots.

const SETTLE_FRAMES := 6

var _small := false
## Name, camera position, look-at point; y is height above the ground.
const SHOTS := [
	["zone_shattered_mesa", Vector3(690, 50, 150), Vector3(620, 20, 560)],
	["zone_skyhold_ruins", Vector3(-170, 185, -560), Vector3(150, 160, -640)],
	["zone_stormfall_city", Vector3(-150, 40, 330), Vector3(0, 25, 520)],
	["zone_frozen_peaks", Vector3(-480, 40, -500), Vector3(-700, 30, -540)],
	["zone_verdant_falls", Vector3(-600, 35, 650), Vector3(-660, 60, 330)],
	["zone_ember_rift", Vector3(500, 60, -340), Vector3(690, 10, -560)],
	["border_city_to_mesa", Vector3(220, 60, 520), Vector3(520, 20, 520)],
	["border_peaks_to_skyhold", Vector3(-400, 90, -560), Vector3(-60, 140, -620)],
	["border_ember_to_mesa", Vector3(700, 60, -120), Vector3(680, 20, 260)],
]
## Heartbloom Gardens: name, camera, look-at (absolute heights), time of day.
const HEARTBLOOM_SHOTS := [
	["zone_heartbloom_arch_dusk", Vector3(-6, 296, 78), Vector3(0, 306, -26), WorldAtmosphere.TimeOfDay.DUSK],
	["zone_heartbloom_fountain", Vector3(-124, 292, 78), Vector3(-151, 281.5, 71), WorldAtmosphere.TimeOfDay.DAY],
	["zone_heartbloom_bridges", Vector3(42, 293, 30), Vector3(128, 283, 70), WorldAtmosphere.TimeOfDay.DUSK],
	["zone_heartbloom_night", Vector3(-236, 297, 52), Vector3(-60, 296, 10), WorldAtmosphere.TimeOfDay.NIGHT],
	["zone_heartbloom_from_below", Vector3(-320, 200, -190), Vector3(-70, 282, 10), WorldAtmosphere.TimeOfDay.DUSK],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var tod := maxi(0, ["day", "dusk", "night"].find(args[1] if args.size() > 1 else "day"))
	_small = args.has("small")
	var heartbloom_only := args.has("heartbloom")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var fly: Node = load("res://game/world/preview/world_flythrough.tscn").instantiate()
	root.add_child(fly)
	await process_frame
	fly.paused = true
	fly.set_process(false)
	var world: WorldMap = fly.world
	world.set_time_of_day(tod)
	var camera: Camera3D = fly.camera
	fly.set_map_mode(true)
	world.atmosphere.apply_at(Vector3(0, 0, 0))
	await _save(out_dir.path_join("map_top_down.png"), true)
	fly.set_map_mode(false)
	for shot in HEARTBLOOM_SHOTS:
		world.set_time_of_day(shot[3])
		var at: Vector3 = shot[1]
		camera.global_transform = Transform3D(Basis.looking_at(shot[2] - at, Vector3.UP), at)
		world.atmosphere.apply_at(at)
		await _save(out_dir.path_join("%s.png" % shot[0]))
	world.set_time_of_day(tod)
	if heartbloom_only:
		quit()
		return
	for shot in SHOTS:
		var eye := _above_ground(world, shot[1])
		var target := _above_ground(world, shot[2])
		camera.global_transform = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
		await _save(out_dir.path_join("%s.png" % shot[0]))
	quit()


# Fewer bits per channel: barely visible on flat toon colours, and the PNGs stay small.
func _quantized(image: Image, mask: int) -> Image:
	image.convert(Image.FORMAT_RGB8)
	var data := image.get_data()
	for i in data.size():
		data[i] = data[i] & mask
	return Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGB8, data)


func _above_ground(world: WorldMap, p: Vector3) -> Vector3:
	return Vector3(p.x, world.ground_height_at(p.x, p.z) + p.y, p.z)


func _save(path: String, square: bool = false) -> void:
	for i in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if square:
		var side := mini(image.get_width(), image.get_height())
		image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
	if _small:
		var width := 600 if square else 960
		image.resize(width, width if square else 540, Image.INTERPOLATE_LANCZOS)
		image = _quantized(image, 0xF0 if square else 0xFC)
	image.save_png(path)
	print("saved ", path)
