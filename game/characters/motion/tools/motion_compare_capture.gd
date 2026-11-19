extends SceneTree
## Side-by-side review renders: chunky Kael with his OLD hand-keyed clips (left) and the NEW mocap
## clips plus MotionLayers (right). One contact sheet (two rows, OLD over NEW) and one frame strip
## (consecutive ticks around the key moment) per pair.
##   godot --path . --rendering-method gl_compatibility --resolution 1280x720 \
##     -s res://game/characters/motion/tools/motion_compare_capture.gd -- <out dir> [pair ...]

const MODEL := "res://game/characters/kael_chunky/kael_chunky.glb"
const OLD_CLIPS := "res://game/characters/kael_chunky/kael_chunky_clip_set.tres"
const NEW_CLIPS := "res://game/characters/motion/motion_library.res"
const CELL := Vector2i(220, 300)
const COLUMNS := 10
const STRIP := 16
const TICK := 1.0 / 60.0
## Pair -> [old clips, new clips]; several clips play back to back.
const PAIRS := {
	"idle": [["idle"], ["fight_idle"]],
	"run": [["run"], ["run"]],
	"light_string": [["light_1", "light_2", "light_3", "light_4"], ["light_1", "light_2", "light_3", "light_4"]],
	"smash": [["smash"], ["smash"]],
	"launcher": [["launcher"], ["launcher"]],
	"block_hit": [["block_hit"], ["block_hit"]],
	"heavy_hit": [["hit"], ["hit_heavy"]],
	"ko_fall": [["knockdown"], ["ko_fall"]],
}

var _out := ""
var _camera: Camera3D
var _old: Dictionary
var _new: Dictionary
var _layers: MotionLayers


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://motion_compare"
	DirAccess.make_dir_recursive_absolute(_out)
	var stage := _stage()
	root.add_child(stage)
	_old = _character(stage, Vector3(-0.75, 0, 0), (load(OLD_CLIPS) as ClipSet).library)
	_new = _character(stage, Vector3(0.75, 0, 0), load(NEW_CLIPS) as AnimationLibrary)
	_layers = MotionLayers.new()
	(_new["skeleton"] as Skeleton3D).add_child(_layers)
	var pairs: Array = args.slice(1) if args.size() > 1 else PAIRS.keys()
	_run.call_deferred(pairs)


func _run(pairs: Array) -> void:
	await _frames(3)
	for pair: String in pairs:
		var old_clips: Array = PAIRS[pair][0]
		var new_clips: Array = PAIRS[pair][1]
		var old_len := _total(_old, old_clips)
		var new_len := _total(_new, new_clips)
		var sheet := Image.create(CELL.x * COLUMNS, CELL.y * 2, false, Image.FORMAT_RGB8)
		for c in COLUMNS:
			var k := float(c) / (COLUMNS - 1)
			await _show(_old, old_clips, old_len * k)
			await _show(_new, new_clips, new_len * k, true)
			_blit(sheet, await _shot(_old), Vector2i(CELL.x * c, 0))
			_blit(sheet, await _shot(_new), Vector2i(CELL.x * c, CELL.y))
		sheet.save_png(_out.path_join("%s_sheet.png" % pair))
		var strip := Image.create(CELL.x * STRIP / 2, CELL.y, false, Image.FORMAT_RGB8)
		var small := Vector2i(CELL.x / 2, CELL.y / 2)
		var start := maxf(new_len * 0.3 - STRIP * TICK, 0.0)
		for i in STRIP:
			var t := start + i * 2 * TICK
			await _show(_old, old_clips, minf(t * old_len / maxf(new_len, 0.001), old_len))
			await _show(_new, new_clips, minf(t, new_len), true)
			var a := await _shot(_old)
			var b := await _shot(_new)
			a.resize(small.x, small.y)
			b.resize(small.x, small.y)
			strip.blit_rect(a, Rect2i(Vector2i.ZERO, small), Vector2i(small.x * i, 0))
			strip.blit_rect(b, Rect2i(Vector2i.ZERO, small), Vector2i(small.x * i, small.y))
		strip.save_png(_out.path_join("%s_strip.png" % pair))
		print("wrote %s (old %.2fs, new %.2fs)" % [pair, old_len, new_len])
	quit(0)


func _character(stage: Node3D, offset: Vector3, library: AnimationLibrary) -> Dictionary:
	var holder := Node3D.new()
	holder.position = offset
	stage.add_child(holder)
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	holder.add_child(model)
	var player := AnimationPlayer.new()
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	holder.add_child(player)
	player.root_node = player.get_path_to(model)
	player.add_animation_library(&"lib", library)
	return {"player": player, "skeleton": model.get_node("%GeneralSkeleton"), "library": library, "holder": holder}


func _total(character: Dictionary, clips: Array) -> float:
	var total := 0.0
	for clip: String in clips:
		total += (character["library"] as AnimationLibrary).get_animation(clip).length
	return total


## Poses a character at time t along its clips played back to back.
func _show(character: Dictionary, clips: Array, t: float, layered := false) -> void:
	var library: AnimationLibrary = character["library"]
	var clip: String = clips[-1]
	var local := t
	for name: String in clips:
		var length := library.get_animation(name).length
		if local <= length or name == clips[-1]:
			clip = name
			break
		local -= length
	var player: AnimationPlayer = character["player"]
	player.play("lib/" + clip)
	player.seek(clampf(local, 0.0, library.get_animation(clip).length), true)
	if layered:
		_layers.lean = Vector3.ZERO
		_layers.reset()


func _shot(character: Dictionary) -> Image:
	var target: Vector3 = (character["holder"] as Node3D).global_position + Vector3(0, 0.95, 0)
	var yaw := deg_to_rad(35.0)
	_camera.fov = 40.0
	_camera.look_at_from_position(target + Vector3(sin(yaw), 0.15, cos(yaw)) * 4.2, target)
	(_old["holder"] as Node3D).visible = character == _old
	(_new["holder"] as Node3D).visible = character == _new
	await _frames(2)
	var image := root.get_texture().get_image()
	var size := image.get_size()
	var w := int(size.y * CELL.x / float(CELL.y))
	var crop := image.get_region(Rect2i((size.x - w) / 2, 0, w, size.y))
	crop.resize(CELL.x, CELL.y)
	crop.convert(Image.FORMAT_RGB8)
	return crop


func _blit(dest: Image, image: Image, at: Vector2i) -> void:
	dest.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), at)


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _stage() -> Node3D:
	var stage := Node3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.7, 0.8)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.72, 0.78)
	environment.ambient_light_energy = 0.6
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
	# Grid lines on the floor make foot sliding visible.
	for i in range(-6, 7):
		for axis in 2:
			var line := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(12, 0.004, 0.01) if axis == 0 else Vector3(0.01, 0.004, 12)
			line.mesh = box
			line.position = Vector3(0, 0.002, i * 0.5) if axis == 0 else Vector3(i * 0.5, 0.002, 0)
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.28, 0.31, 0.28)
			line.material_override = m
			stage.add_child(line)
	_camera = Camera3D.new()
	stage.add_child(_camera)
	_camera.current = true
	return stage
