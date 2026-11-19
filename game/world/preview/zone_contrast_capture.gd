extends SceneTree
## Figure-ground check (#81): renders the fight-start frame of every zone with the
## default fighters, masks each fighter (render with and without it) and measures its
## contrast against the ring of background around it, plus the near-white share of the
## frame. Writes the frames and masks to the directory after `--`; exits 1 on a miss.
##   xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 1280x720 \
##     -s res://game/world/preview/zone_contrast_capture.gd -- <out dir> [zone]

const SCENE := preload("res://game/levels/zone_match.tscn")
const SETTLE_FRAMES := 90
## Every fighter must reach this Weber contrast against its ring. APCA Lc is printed
## too; it reads near 0 for any dark-on-dark pair, so it is not the gate.
const MIN_WEBER := 0.35
## No zone frame may be more than this share near white.
const MAX_NEAR_WHITE := 0.25


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var zones: Array[StringName] = ZoneLayout.ZONE_IDS.duplicate()
	if args.size() > 1:
		zones = [StringName(args[1])]
	var failed := false
	print("| Zone | Fighter | Pixels | Fighter L | Ring L | Weber | APCA Lc | Near-white |")
	print("|---|---|---|---|---|---|---|---|")
	for zone_id in zones:
		var zone_match: ZoneMatch = SCENE.instantiate()
		zone_match.configure({"zone": zone_id})
		zone_match.input_override = func(_i: int, _t: int) -> FighterInput: return FighterInput.new()
		root.add_child(zone_match)
		zone_match.match_flow.enabled = false
		zone_match.set_physics_process(false)
		zone_match.set_process(false)
		for i in 30:
			zone_match.step_tick()
		for i in SETTLE_FRAMES:
			zone_match.present_frame(1.0, 1.0 / 60.0)
			await process_frame
		while not zone_match.vfx_prewarm.is_finished:
			await process_frame
		for i in 10:
			zone_match.present_frame(1.0, 1.0 / 60.0)
			await process_frame
		# Freeze everything that moves between the renders.
		for node in zone_match.find_children("*", "GPUParticles3D", true, false):
			(node as GPUParticles3D).speed_scale = 0.0
		var sun := zone_match.world.sun
		var frame := await _grab()
		var white := FigureGround.near_white_fraction(frame)
		frame.save_png(out_dir.path_join("contrast_%s.png" % zone_id))
		# Masks without sun shadows so a fighter's own shadow is not part of it.
		sun.shadow_enabled = false
		_show_fighters(zone_match, -1)
		var empty := await _grab()
		var masks: Array[PackedByteArray] = []
		var all := PackedByteArray()
		all.resize(frame.get_width() * frame.get_height())
		for i in zone_match.fighter_views.size():
			_show_fighters(zone_match, i)
			var alone := await _grab()
			var m := _clip_to_fighter(FigureGround.mask(alone, empty), zone_match, i, frame)
			masks.append(m)
			for k in m.size():
				all[k] = all[k] | m[k]
		_show_fighters(zone_match, -2)
		sun.shadow_enabled = true
		_save_mask(frame, all, out_dir.path_join("contrast_%s_mask.png" % zone_id))
		for i in masks.size():
			var r := FigureGround.measure(frame, masks[i], all)
			var ok: bool = r.weber >= MIN_WEBER and white <= MAX_NEAR_WHITE
			failed = failed or not ok
			print("| %s | %s | %d | %.3f | %.3f | %.2f | %.1f | %.1f%% |%s" % [zone_id,
				zone_match.fighter_views[i].character_id, r.figure_pixels, r.figure_l, r.ring_l, r.weber, r.apca,
				white * 100.0, "" if ok else " FAIL"])
		zone_match.free()
		await process_frame
	quit(1 if failed else 0)


func _grab() -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	return image


# Shows only fighter `only` (-1: none, -2: all); their height markers stay as they are.
func _show_fighters(zone_match: ZoneMatch, only: int) -> void:
	for i in zone_match.fighter_views.size():
		for child in zone_match.fighter_views[i].get_children():
			if child is Node3D and not child is HeightMarker:
				(child as Node3D).visible = only == -2 or only == i


# Keeps mask pixels inside the fighter's projected 2.6 m capsule box.
func _clip_to_fighter(m: PackedByteArray, zone_match: ZoneMatch, i: int, frame: Image) -> PackedByteArray:
	var cam: Camera3D = zone_match.camera
	var centre := zone_match.fighter_views[i].global_position
	var right := cam.global_transform.basis.x
	var corners: Array[Vector3] = [centre + Vector3.UP * 1.4 + right, centre - Vector3.UP * 1.4 - right,
		centre + Vector3.UP * 1.4 - right, centre - Vector3.UP * 1.4 + right]
	var box := Rect2(cam.unproject_position(corners[0]), Vector2.ZERO)
	for c in corners:
		box = box.expand(cam.unproject_position(c))
	var scale := Vector2(frame.get_size()) / cam.get_viewport().get_visible_rect().size
	box = Rect2(box.position * scale, box.size * scale).grow(4.0)
	var w := frame.get_width()
	for k in m.size():
		if m[k] == 1 and not box.has_point(Vector2(k % w, k / w)):
			m[k] = 0
	return m


func _save_mask(frame: Image, m: PackedByteArray, path: String) -> void:
	var image := frame.duplicate() as Image
	var w := image.get_width()
	for k in m.size():
		if m[k] == 1:
			image.set_pixel(k % w, k / w, Color(1, 0, 1))
	image.save_png(path)
