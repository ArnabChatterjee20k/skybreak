extends SceneTree
## Measures how long each voxel zone takes to appear at match start from its bake,
## as a match does it: a threaded load of the bake (LoadingScreen), then
## VoxelZoneView.build() (instantiate, restore, stage). Prints one line per zone.
##   godot --path . -s res://tools/diag/zone_load_times.gd [-- --tier=high --zone=<id>]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tier := GraphicsSettings.Quality.HIGH
	var zones: Array[StringName] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tier="):
			tier = VoxelQuality.from_name(a.trim_prefix("--tier="))
		elif a.begins_with("--zone="):
			zones.append(StringName(a.trim_prefix("--zone=")))
	if zones.is_empty():
		zones.assign(VoxelZoneView.BUILDERS.keys())
	var failed := false
	for id in zones:
		var path := VoxelZoneBake.path_for(id, tier)
		var t0 := Time.get_ticks_msec()
		if ResourceLoader.load_threaded_request(path, "", true) != OK:
			printerr("zone_load_times: %s: no bake" % id)
			failed = true
			continue
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await process_frame
		VoxelZoneBake.preloaded[path] = ResourceLoader.load_threaded_get(path)
		var loaded := Time.get_ticks_msec() - t0
		var view := VoxelZoneView.new()
		root.add_child(view)
		var t1 := Time.get_ticks_msec()
		view.build(id, tier)
		var built := Time.get_ticks_msec() - t1
		await process_frame
		var first_frame := Time.get_ticks_msec() - t0
		print("zone_load_times: %s %s: threaded load %d ms, build from bake %d ms, total to first frame %d ms, from bake %s" % [
			id, GraphicsSettings.Quality.keys()[tier], loaded, built, first_frame, view.from_bake])
		failed = failed or not view.from_bake
		view.free()
		await process_frame
	quit(1 if failed else 0)
