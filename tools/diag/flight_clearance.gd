extends SceneTree
## Prints where each zone's fly-through passes closer than FlightClearance.MIN_CLEARANCE
## to solid geometry (builds the zone, or loads its current HIGH bake).
##   godot --headless --path . -s res://tools/diag/flight_clearance.gd [-- --zone=<id> ...]
## Exits 1 if any zone's path is too close.


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var zones: Array[StringName] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--zone="):
			zones.append(StringName(a.trim_prefix("--zone=")))
	if zones.is_empty():
		zones.assign(VoxelZoneView.BUILDERS.keys())
	var failed := false
	VoxelQuality.tier = GraphicsSettings.Quality.HIGH
	for id in zones:
		var builder: String = VoxelZoneView.BUILDERS[id]
		var t := Time.get_ticks_msec()
		var zone := VoxelZoneBake.instantiate(id, VoxelQuality.tier, builder)
		var how := "bake"
		if zone == null:
			zone = (load(builder) as GDScript).new() as VoxelZone
			root.add_child(zone)
			zone.build()
			how = "build"
		else:
			root.add_child(zone)
		var load_ms := Time.get_ticks_msec() - t
		t = Time.get_ticks_msec()
		var r := FlightClearance.sweep(zone)
		print("%s (%s %d ms, sweep %d ms): %d triangles near the path, min clearance %.2f m, %d samples under %.1f m" % [id, how, load_ms,
			Time.get_ticks_msec() - t, r.triangles, r.min, (r.samples as Array).size(), FlightClearance.MIN_CLEARANCE])
		var last_what := ""
		for s: Dictionary in r.samples:
			if s.what != last_what or (s.u as float) == floorf(s.u):
				print("  u %.2f at %s: %.2f m from %s" % [s.u, (s.at as Vector3).snapped(Vector3.ONE * 0.1), s.clearance, s.what])
			last_what = s.what
		failed = failed or not (r.samples as Array).is_empty()
		zone.free()
	quit(1 if failed else 0)
