extends SceneTree
## Renders the same FFA-4 airborne fight shot in every zone for art review (T-ART1):
## four fighters climb a few metres off the ground, then the gameplay camera frames them.
##   godot --path . --resolution 1280x720 --rendering-method gl_compatibility \
##     -s res://game/world/preview/zone_art_capture.gd -- <out dir> [zone id]

const SCENE := preload("res://game/levels/zone_match.tscn")
const CLIMB_TICKS := 20
const HOVER_TICKS := 50
const SETTLE_FRAMES := 60
const LEGENDS: Array[StringName] = [&"kael", &"vexa", &"brann", &"lyra"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var zones: Array[StringName] = ZoneLayout.ZONE_IDS.duplicate()
	if args.size() > 1:
		zones = [StringName(args[1])]
	for zone_id in zones:
		var fighters: Array = []
		for i in LEGENDS.size():
			fighters.append({"character": LEGENDS[i], "team": i, "is_ai": false, "ai_level": 0})
		var zone_match: ZoneMatch = SCENE.instantiate()
		zone_match.configure({"zone": zone_id, "fighters": fighters})
		zone_match.input_override = _climb
		root.add_child(zone_match)
		zone_match.match_flow.enabled = false
		zone_match.set_physics_process(false)
		zone_match.set_process(false)
		if OS.has_environment("ART_NO_SHADOW"):
			zone_match.world.sun.shadow_enabled = false
		for i in CLIMB_TICKS + HOVER_TICKS:
			zone_match.step_tick()
		for i in SETTLE_FRAMES:
			zone_match.present_frame(1.0, 1.0 / 60.0)
			await process_frame
		while not zone_match.vfx_prewarm.is_finished:
			await process_frame
		for i in 10:
			zone_match.present_frame(1.0, 1.0 / 60.0)
			await process_frame
		await RenderingServer.frame_post_draw
		var path := out_dir.path_join("zone_art_%s.png" % zone_id)
		root.get_texture().get_image().save_png(path)
		var heights := zone_match.sim.fighters.map(func(f: FighterState) -> String:
			return "%.1f" % (f.position.y - f.stand_height))
		print("%s: heights above ground %s -> %s" % [zone_id, heights, path])
		if OS.has_environment("ART_GROUND_VIEW"):
			await _save_ground_view(zone_match, out_dir.path_join("zone_art_%s_ground.png" % zone_id))
		zone_match.free()
		await process_frame
	quit(0)


# A steep look down past the fighters at their ground markers and the floor detail.
func _save_ground_view(zone_match: ZoneMatch, path: String) -> void:
	var centre := zone_match.fighter_views[0].position
	var floor_y := zone_match.sim.fighters[0].stand_height - zone_match.sim.tuning.ground_height
	var look_at := Vector3(centre.x, floor_y, centre.z)
	var camera := zone_match.camera.get_viewport().get_camera_3d()
	var back := (camera.global_position - look_at) * Vector3(1, 0, 1)
	camera.look_at_from_position(look_at + back.normalized() * 7.0 + Vector3.UP * 13.0, look_at)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


# Everyone climbs, then hovers.
func _climb(_slot: int, tick: int) -> FighterInput:
	var input := FighterInput.new()
	if tick < CLIMB_TICKS:
		input.vertical = 1
	return input
