extends SceneTree
## Look-dev renders of a voxel zone: hero stills at each time of day with voxel
## Kael for scale, and a fly-through video.
##   godot --path . --disable-vsync -s res://game/world/voxel_zone_kit/zone_capture.gd -- <out dir>
##       draft|heroes|flythrough|all|preview [--zone=<VoxelZone script>] [--time=dusk|day|night]
##       [--kael=<scene>] [--fps=30] [--seconds=20] [--size=1920x1080] [--from=<frame>] [--shots=a,b]
## draft: every shot at one time (--time, default dusk); heroes: every shot at
## the times it lists; preview: draft, then the fly-through. Stills are PNG at --size through a SubViewport; the
## fly-through writes JPG frames to <out>/frames and, if ffmpeg is on PATH,
## encodes <out>/<zone>_flythrough.mp4 (H.264, yuv420p). Each still prints
## the GPU time, primitives and draw calls of its frame.

const DEFAULT_ZONE := "res://game/world/voxel_zones/heartbloom/heartbloom_voxel.gd"
const DEFAULT_KAEL := "res://game/characters/kael_voxel/kael_voxel.tscn"

var _out := ""
var _viewport: SubViewport
var _zone: VoxelZone
var _stage: VoxelStage
var _camera: Camera3D
var _kael: CharacterView
var _kael_body: Node3D
var _kael_f := FighterState.new()
var _clock := 0.0
var _args: LookdevArgs


func _initialize() -> void:
	_args = LookdevArgs.parse()
	_out = _args.pos(0)
	DirAccess.make_dir_recursive_absolute(_out)
	var sz := _args.get_option("size", "1920x1080").split("x")
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(sz[0]), int(sz[1]))
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	RenderingServer.viewport_set_measure_render_time(_viewport.get_viewport_rid(), true)
	VoxelStage.shadow_quality()
	_run.call_deferred(_args.pos(1, "draft"))


func _run(what: String) -> void:
	var t := Time.get_ticks_msec()
	_zone = (load(_args.get_option("zone", DEFAULT_ZONE)) as GDScript).new() as VoxelZone
	_viewport.add_child(_zone)
	_zone.build()
	print("zone built in %d ms: %s" % [Time.get_ticks_msec() - t, _zone.stats])
	_stage = VoxelStage.new()
	_viewport.add_child(_stage)
	_stage.setup(_zone.presets(), _zone.cloud_sea())
	_stage.lantern_materials = _zone.lantern_materials
	_stage.apply(_args.get_option("time", "dusk"))
	_camera = Camera3D.new()
	_camera.near = 0.1
	_camera.far = 4000.0
	_viewport.add_child(_camera)
	_camera.make_current()
	_spawn_kael(_args.get_option("kael", DEFAULT_KAEL))
	for i in 20:
		await _step()
	if what in ["draft", "heroes", "all", "preview"]:
		await _stills(what in ["draft", "preview"])
	if what in ["flythrough", "all", "preview"]:
		await _flythrough()
	quit()


# ---------------------------------------------------------------- Kael

func _spawn_kael(scene: String) -> void:
	_kael_body = Node3D.new()
	_viewport.add_child(_kael_body)
	if scene == "none":
		return
	_kael = (load(scene) as PackedScene).instantiate() as CharacterView
	_kael_body.add_child(_kael)
	_kael_f.enter_state(FighterState.State.IDLE)


## Stands Kael (capsule centre 1 m up) on the zone's visible ground.
func _place_kael(spec: Array, y_override := NAN) -> void:
	_kael_body.visible = not spec.is_empty()
	if spec.is_empty():
		return
	var at: Vector2 = spec[0]
	var y := y_override if not is_nan(y_override) else _zone.ground_at(at.x, at.y)
	_kael_body.position = Vector3(at.x, y + 1.0, at.y)
	_kael_body.rotation.y = spec[1]


func _step(dt := 1.0 / 60.0) -> void:
	_clock += dt
	_kael_f.state_ticks += 1
	if _kael != null:
		_kael.apply_state(_kael_f, dt)
	_zone.animate(_clock)
	await process_frame


# ---------------------------------------------------------------- stills

func _look(from: Vector3, at: Vector3, fov := 50.0) -> void:
	_camera.fov = fov
	_camera.global_position = from
	_camera.look_at(at, Vector3.UP)


func _stills(draft: bool) -> void:
	var only := _args.get_option("shots", "")
	for shot: Dictionary in _zone.shots():
		if only != "" and not (shot.name in only.split(",")):
			continue
		var times: Array = [_args.get_option("time", "dusk")] if draft else shot.get("times", ["dusk"])
		for time: String in times:
			_stage.apply(time)
			_place_kael(shot.get("kael", []), shot.get("kael_y", NAN))
			_look(shot.from, shot.at, shot.get("fov", 50.0))
			await _shot("%s_%s" % [shot.name, time])


func _shot(name: String) -> void:
	for i in 4:
		await _step()
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(_out.path_join(name + ".png"))
	var rid := _viewport.get_viewport_rid()
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var prims := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	var draws := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var shadow_prims := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
		RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	var shadow_draws := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
		RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	print("%s: gpu %.1f ms (software), %d tris, %d draws, shadow %d tris, %d draws"
		% [name, gpu, prims, draws, shadow_prims, shadow_draws])


# ---------------------------------------------------------------- fly-through

## Catmull-Rom through the zone's flight() points, evenly in time, rendered at
## --fps for --seconds (default 30 fps, 20 s); time and particles advance by
## exactly one frame per frame.
func _flythrough() -> void:
	var pts := _zone.flight()
	if pts.size() < 2:
		push_error("zone has no flight path")
		return
	var fps := int(_args.get_option("fps", "30"))
	var seconds := float(_args.get_option("seconds", "20"))
	var frames := roundi(fps * seconds)
	var start := int(_args.get_option("from", "0"))
	var dir := _out.path_join("frames")
	DirAccess.make_dir_recursive_absolute(dir)
	_stage.apply(_args.get_option("time", "dusk"))
	_place_kael(_zone.flight_kael())
	Engine.max_fps = 0
	var t0 := Time.get_ticks_msec()
	for f in frames:
		var u := float(f) / float(frames - 1) * float(pts.size() - 1)
		var from := _spline(pts, "from", u)
		var at := _spline(pts, "at", u)
		var fov := lerpf(float(pts[floori(u)].get("fov", 55.0)), float(pts[mini(floori(u) + 1, pts.size() - 1)].get("fov", 55.0)),
			u - floorf(u))
		_look(from, at, fov)
		# Advance the world by one video frame (two 60 Hz steps at 30 fps),
		# drawing only the last step: the frame that is saved.
		var sub := maxi(1, roundi(60.0 / fps))
		var keep := f >= start
		for s in sub:
			var last := s == sub - 1
			_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if last and keep \
				else SubViewport.UPDATE_DISABLED
			await _step(1.0 / (fps * sub))
		if not keep:
			continue
		await RenderingServer.frame_post_draw
		_viewport.get_texture().get_image().save_jpg(dir.path_join("f%05d.jpg" % f), 0.94)
		if f % 30 == 0:
			print("frame %d/%d, %.1f s per frame" % [f, frames, (Time.get_ticks_msec() - t0) / 1000.0 / (f - start + 1)])
	var mp4 := _out.path_join("%s_flythrough.mp4" % _zone.name.to_snake_case())
	var code := OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-framerate", str(fps), "-i", dir.path_join("f%05d.jpg"),
		"-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", mp4])
	print("fly-through: %d frames -> %s (ffmpeg exit %d)" % [frames, mp4, code])


static func _spline(pts: Array[Dictionary], key: String, u: float) -> Vector3:
	var i := clampi(floori(u), 0, pts.size() - 2)
	var t := u - i
	var p0: Vector3 = pts[maxi(i - 1, 0)][key]
	var p1: Vector3 = pts[i][key]
	var p2: Vector3 = pts[i + 1][key]
	var p3: Vector3 = pts[mini(i + 2, pts.size() - 1)][key]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)
