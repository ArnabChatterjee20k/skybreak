extends SceneTree
## Checks the fly-through path against the ground and the hoodoos (no render):
##   godot --headless --path . -s res://game/world/zones_voxel/shattered_mesa/flight_check.gd


func _initialize() -> void:
	var z := ShatteredMesaVoxel.new()
	var p := MesaProps.new(z)
	z.props = p
	p.root = Node3D.new()
	p._placements()
	var b := p._arch.basis
	p.arch_centre = p._arch.origin - b.y * 0.5
	p.arch_base_y = p.arch_centre.y
	p.arch_forward = b.z.normalized()
	p._camp()
	for xf in p._pillars:
		if Vector2(xf.origin.x, xf.origin.z).distance_to(Vector2(580, 620)) < 60.0:
			print("pillar ", xf.origin, " r ", xf.basis.x.length() * 0.5, " h ", xf.basis.y.length())
	print("arch ", p.arch_centre, " fwd ", p.arch_forward, " camp ", p.camp_at)
	var pts := z.flight()
	var frames := 600
	var worst := []
	for f in frames:
		var u := float(f) / float(frames - 1) * float(pts.size() - 1)
		var from := _spline(pts, "from", u)
		var clear := from.y - z.ground_at(from.x, from.z)
		for dx: float in [-3.0, 3.0]:
			for dz: float in [-3.0, 3.0]:
				clear = minf(clear, from.y - z.ground_at(from.x + dx, from.z + dz))
		var hood := INF
		for xf in p._pillars:
			var r := xf.basis.x.length() * 0.62
			var top := xf.origin.y + xf.basis.y.length() * 0.5
			if from.y < top + 3.0:
				hood = minf(hood, Vector2(from.x - xf.origin.x, from.z - xf.origin.z).length() - r)
		var local := Basis(Vector3.UP, 0.6).inverse() * (from - p.arch_centre)
		var arch_note := ""
		if absf(local.z) < 6.0:
			arch_note = " ARCH local x %.1f y %.1f" % [local.x, local.y]
		if clear < 4.0 or hood < 4.0 or arch_note != "" or f % 30 == 0:
			print("f%03d %s clear %.1f hoodoo %.1f%s" % [f, from.snapped(Vector3.ONE * 0.1), clear, hood, arch_note])
	z.free()
	quit()


static func _spline(pts: Array[Dictionary], key: String, u: float) -> Vector3:
	var i := clampi(floori(u), 0, pts.size() - 2)
	var t := u - i
	var p0: Vector3 = pts[maxi(i - 1, 0)][key]
	var p1: Vector3 = pts[i][key]
	var p2: Vector3 = pts[i + 1][key]
	var p3: Vector3 = pts[mini(i + 2, pts.size() - 1)][key]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)
