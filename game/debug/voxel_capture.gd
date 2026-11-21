extends SceneTree
## Screenshots of the voxel art in the game for review: real ZoneMatch fights
## (AI vs AI) in Voxel art style per zone, plus character select and zone
## select. Each match shot is taken after a few seconds of fighting.
##   godot --path . --resolution 1280x720 -s res://game/debug/voxel_capture.gd -- <out dir> \
##       [zone:legend,legend ...] [--select] [--ticks=N] [--style=voxel|classic] [--quality=high|web|...]
## Default shots: heartbloom_gardens:kael,vexa shattered_mesa:lyra,brann stormfall_city:vexa,lyra

const SIZE := Vector2i(1280, 720)
const DEFAULT_SHOTS := ["heartbloom_gardens:kael,vexa", "shattered_mesa:lyra,brann", "stormfall_city:vexa,lyra"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://voxel_capture"
	DirAccess.make_dir_recursive_absolute(out)
	var shots: Array[String] = []
	var select := false
	var ticks := 420
	var style := ArtStyle.Kind.VOXEL
	var quality := GraphicsSettings.load_saved().quality
	for a in args.slice(1):
		if a == "--select":
			select = true
		elif a.begins_with("--ticks="):
			ticks = int(a.trim_prefix("--ticks="))
		elif a.begins_with("--quality="):
			quality = VoxelQuality.from_name(a.trim_prefix("--quality="))
		elif a.begins_with("--style="):
			style = ArtStyle.Kind.CLASSIC if a.ends_with("classic") else ArtStyle.Kind.VOXEL
		else:
			shots.append(a)
	if shots.is_empty() and not select:
		shots.assign(DEFAULT_SHOTS)
	ArtStyle.set_current(style)
	root.size = SIZE
	for shot in shots:
		var parts := shot.split(":")
		await _match_shot(out, StringName(parts[0]), parts[1].split(","), ticks, quality)
	if select:
		await _select_shots(out)
	quit(0)


func _match_shot(out: String, zone: StringName, legends: PackedStringArray, ticks: int,
		quality: GraphicsSettings.Quality) -> void:
	var level: ZoneMatch = load("res://game/levels/zone_match.tscn").instantiate()
	var fighters := []
	for i in legends.size():
		fighters.append({"character": StringName(legends[i]), "team": i, "is_ai": true, "ai_level": 4})
	level.configure({"zone": zone, "fighters": fighters, "rounds": 3, "quality": quality})
	var t0 := Time.get_ticks_msec()
	root.add_child(level)
	var load_ms := Time.get_ticks_msec() - t0
	await process_frame
	level.set_physics_process(false)
	level.set_process(false)
	level.match_flow.enabled = false
	for t in ticks:
		level.step_tick()
		if t % 20 == 0:
			level.present_frame(1.0, 20.0 / 60.0)
	for f in 6:
		level.step_tick()
		level.present_frame(1.0, 1.0 / 60.0)
		await process_frame
	var name := "%s_%s" % [zone, "_".join(legends)]
	var path := "%s/%s.png" % [out, name]
	root.get_texture().get_image().save_png(path)
	var voxel := level.voxel_zone != null
	print("saved %s (voxel zone %s, from bake %s, level ready in %d ms, zone %d ms)" % [
		path, voxel, level.voxel_zone.from_bake if voxel else false, load_ms, level.voxel_zone.build_ms if voxel else 0])
	level.queue_free()
	await process_frame


func _select_shots(out: String) -> void:
	var front: FrontEnd = load("res://game/ui/menus/front_end.tscn").instantiate()
	front.light_backdrop = true
	front.skip_splash = true
	root.add_child(front)
	await process_frame
	front.go(&"character_select")
	for f in 30:
		await process_frame
	root.get_texture().get_image().save_png("%s/character_select.png" % out)
	print("saved %s/character_select.png" % out)
	front.go(&"zone_select")
	for f in 10:
		await process_frame
	root.get_texture().get_image().save_png("%s/zone_select.png" % out)
	print("saved %s/zone_select.png" % out)
	front.queue_free()
	await process_frame
