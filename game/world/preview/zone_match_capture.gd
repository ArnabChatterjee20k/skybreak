extends SceneTree
## Renders one fight frame per zone from the real zone match and prints draw calls and
## triangles per zone. Writes PNGs to the directory after `--`:
##   godot --path . --resolution 1920x1080 -s res://game/world/preview/zone_match_capture.gd -- <out dir>

const SCENE := preload("res://game/levels/zone_match.tscn")
const SETTLE_FRAMES := 90


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
		await RenderingServer.frame_post_draw
		var viewport := root.get_viewport_rid()
		var draws := RenderingServer.viewport_get_render_info(viewport,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var triangles := RenderingServer.viewport_get_render_info(viewport,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		var estimate := WorldViewBudget.count(zone_match.world, zone_match.camera.global_transform)
		var path := out_dir.path_join("zone_match_%s.png" % zone_id)
		root.get_texture().get_image().save_png(path)
		var standing := zone_match.sim.fighters.map(func(f: FighterState) -> String:
			return "%s y=%.2f stand=%.2f" % [FighterState.State.keys()[f.state], f.position.y, f.stand_height])
		print("%s: draw calls %d, triangles %d (estimate %d / %d), fighters %s -> %s" % [
			zone_id, draws, triangles, estimate.draw_calls, estimate.triangles, standing, path])
		zone_match.free()
		await process_frame
	quit(0)
