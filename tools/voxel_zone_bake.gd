extends SceneTree
## Bakes every voxel zone's static look per quality tier to
## game/world/voxel_zone_kit/baked/<zone>_<tier>.scn (VoxelZoneBake), so a
## match loads it instead of building for minutes.
##   godot --headless --path . -s res://tools/voxel_zone_bake.gd [-- options]
## Options:
##   --zone=<id>    only this zone (repeatable); default: every VoxelZoneView builder
##   --tier=<name>  only this tier (high, medium, low, web; repeatable)
##   --check        write nothing; exit 1 if a bake is missing or stale
## Exits 1 on any error.


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var zones: Array[StringName] = []
	var tiers: Array[GraphicsSettings.Quality] = []
	var check := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--zone="):
			zones.append(StringName(a.trim_prefix("--zone=")))
		elif a.begins_with("--tier="):
			tiers.append(VoxelQuality.from_name(a.trim_prefix("--tier=")))
		elif a == "--check":
			check = true
		else:
			printerr("voxel_zone_bake: unknown option ", a)
			quit(1)
			return
	if zones.is_empty():
		zones.assign(VoxelZoneView.BUILDERS.keys())
	if tiers.is_empty():
		tiers = VoxelZoneBake.TIERS
	var failed := false
	for id in zones:
		if not VoxelZoneView.BUILDERS.has(id):
			printerr("voxel_zone_bake: unknown zone ", id)
			failed = true
			continue
		var builder: String = VoxelZoneView.BUILDERS[id]
		for tier in tiers:
			var ok := _check(id, tier, builder) if check else await _bake(id, tier, builder)
			failed = failed or not ok
	quit(1 if failed else 0)


func _check(id: StringName, tier: GraphicsSettings.Quality, builder: String) -> bool:
	var why := VoxelZoneBake.check(id, tier, builder)
	if why != "":
		printerr("voxel_zone_bake: %s: %s" % [VoxelZoneBake.path_for(id, tier), why])
		return false
	print("voxel_zone_bake: %s: current" % VoxelZoneBake.path_for(id, tier))
	return true


func _bake(id: StringName, tier: GraphicsSettings.Quality, builder: String) -> bool:
	VoxelQuality.tier = tier
	var zone := (load(builder) as GDScript).new() as VoxelZone
	root.add_child(zone)
	var t0 := Time.get_ticks_msec()
	zone.build()
	var build_ms := Time.get_ticks_msec() - t0
	var scene := VoxelZoneBake.pack(zone, id, tier, builder, build_ms)
	var out := VoxelZoneBake.path_for(id, tier)
	var nodes := zone.find_children("*", "Node", true, false).size()
	zone.free()
	await process_frame
	if scene == null:
		printerr("voxel_zone_bake: packing %s failed" % out)
		return false
	var err := VoxelZoneBake.save(scene, out)
	if err != OK:
		printerr("voxel_zone_bake: saving %s failed (%s)" % [out, error_string(err)])
		return false
	t0 = Time.get_ticks_usec()
	var loaded := ResourceLoader.load(out, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	var why := []
	var again := VoxelZoneBake.instantiate(id, tier, builder, why) if loaded != null else null
	var inst_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var ok := again != null and again.find_children("*", "Node", true, false).size() == nodes
	print("voxel_zone_bake: %s %s -> %s: built %d ms, loads %.0f ms, instantiates %.0f ms, %d nodes, %d KiB%s" % [
		id, GraphicsSettings.Quality.keys()[tier], out, build_ms, load_ms, inst_ms, nodes,
		FileAccess.get_file_as_bytes(out).size() / 1024, "" if ok else " RELOAD MISMATCH %s" % [why]])
	if again != null:
		again.free()
	return ok
