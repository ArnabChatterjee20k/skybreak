extends SceneTree
## Prints where the fly-through passes through solid geometry (look-dev aid).
##   godot --headless --path . -s res://game/world/zones_voxel/skyhold_ruins/flight_probe.gd

func _initialize() -> void:
	var zone := SkyholdRuinsVoxel.new()
	root.add_child(zone)
	zone.build()
	var pts := zone.flight()
	var capture: GDScript = load("res://game/world/voxel_zone_kit/zone_capture.gd")
	var bad := 0
	for k in 600:
		var u := float(k) / 599.0 * float(pts.size() - 1)
		var p: Vector3 = capture._spline(pts, "from", u)
		if zone.inside_solid(p, float(OS.get_environment("MARGIN")) if OS.get_environment("MARGIN") != "" else 2.5):
			bad += 1
			print("frame %d (u %.2f): inside at %s" % [k, u, p])
	print("spots: ", zone.spots)
	print("bad frames: %d" % bad)
	zone.free()
	quit()
