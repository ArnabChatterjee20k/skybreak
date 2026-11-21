extends SceneTree
## Measures each voxel zone match at the WEB tier against the Compatibility
## limits (WebTierBudget): instance-uniform instances, lights, textures, surfaces.
##   godot --headless --path . -s res://game/debug/web_tier_probe.gd [-- zone_a,zone_b]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ArtStyle.set_current(ArtStyle.Kind.VOXEL)
	VoxelQuality.tier = GraphicsSettings.Quality.WEB
	var args := OS.get_cmdline_user_args()
	var zones: Array = Array(args[0].split(",")) if not args.is_empty() else ZoneLayout.ZONE_IDS
	var failed := false
	for zone: String in zones:
		var spec := QaMatchSpec.parse("7:%s:1v1:kael,brann:33" % zone)
		var run := QaMatchRun.new(spec)
		run.check_view = false
		run.build(root)
		await process_frame
		var whole := WebTierBudget.measure(run.level)
		var zone_only := WebTierBudget.measure(run.level.voxel_zone) if run.level.voxel_zone != null else {}
		print("[web] %s match: %s" % [zone, _brief(whole)])
		print("[web] %s directional: %s" % [zone, whole.directional_nodes])
		if not zone_only.is_empty():
			print("[web] %s zone:  %s" % [zone, _brief(zone_only)])
			for p in WebTierBudget.problems(zone_only):
				print("[web] %s zone PROBLEM: %s" % [zone, p])
				failed = true
		if whole.instance_uniform_instances > WebTierBudget.MATCH_INSTANCE_UNIFORM_INSTANCES:
			print("[web] %s match PROBLEM: %d instance-uniform instances (max %d): %s" % [zone,
				whole.instance_uniform_instances, WebTierBudget.MATCH_INSTANCE_UNIFORM_INSTANCES,
				whole.instance_uniform_nodes])
			failed = true
		run.level.queue_free()
		await process_frame
	quit(1 if failed else 0)


static func _brief(r: Dictionary) -> String:
	return "iu_instances=%d geometry=%d omni_spot=%d directional=%d shadowed=%d max_tex=%d max_verts=%d" % [
		r.instance_uniform_instances, r.geometry_instances, r.omni_spot_lights, r.directional_lights,
		r.shadowed_lights, r.max_texture_side, r.max_surface_vertices]
