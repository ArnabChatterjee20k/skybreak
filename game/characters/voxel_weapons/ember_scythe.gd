extends VoxelWeaponDesign
## The Ember Scythe (shared pickup, docs/lookdev/weapons.md), in the item gold
## family. Big: a charcoal shaft and a long crescent blade sweeping forward and
## down. Medium: gold collars and a gold blade spine, the ember cutting edge,
## a leather grip at each hand. Tiny: spine rivets, the item spark mark on the
## blade root (fine cell), an ember gem in the butt cap.

const SPINE_SAMPLES := 18


func kind() -> Weapon.Kind:
	return Weapon.Kind.EMBER_SCYTHE


func palette() -> Dictionary:
	return {
		Mat.BODY: Color("#7c828c"), Mat.BODY_DARK: Color("#555a64"), Mat.EDGE: Color("#c9ced6"),
		Mat.WOOD: Color("#2a2830"),
		Mat.TRIM: Color("#d9a441"), Mat.TRIM_DARK: Color("#8c6020"),
		Mat.RIVET: Color("#f0cd78"), Mat.ENGRAVE: Color("#5a3a12"), Mat.EMBLEM: Color("#f0cd78"),
		Mat.GRIP: Color("#5a3420"), Mat.GRIP_DARK: Color("#2e1a10"),
		Mat.GLOW: Color("#ff5c1a"), Mat.GLOW_CORE: Color("#ffd29a"),
	}


func build_grids() -> Array[VoxelGrid]:
	return [_scythe(), _root_plate()]


## The blade spine (the old model's crescent), in the YZ plane.
static func spine() -> PackedVector3Array:
	var pts := PackedVector3Array([Vector3(0, 1.42, 0)])
	for i in SPINE_SAMPLES:
		var t := float(i + 1) / SPINE_SAMPLES
		var angle := lerpf(0.15, 2.2, t)
		pts.append(Vector3(0, 1.42 + sin(angle) * 0.32, -(1.0 - cos(angle)) * 0.55 - t * 0.35))
	return pts


## (distance below the spine toward the inside of the curve, t along it, distance) for p.
static func spine_hit(p: Vector3, pts: PackedVector3Array) -> Vector3:
	var best := INF
	var best_t := 0.0
	var below := 0.0
	var q := Vector3(0, p.y, p.z)
	for i in pts.size() - 1:
		var a := pts[i]
		var ab := pts[i + 1] - a
		var h := clampf((q - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
		var d := q.distance_to(a + ab * h)
		if d < best:
			best = d
			best_t = (i + h) / (pts.size() - 1)
			var n := Vector3(0, -ab.z, ab.y).normalized()
			if n.y > 0.0:
				n = -n
			below = (q - a - ab * h).dot(n)
	return Vector3(below, best_t, best)


func _scythe() -> VoxelGrid:
	var all := AABB(Vector3(-0.08, -0.52, -1.1), Vector3(0.16, 2.3, 1.2))
	var g := grid(all)
	var c := g.cell
	var shaft := AABB(Vector3(-0.08, -0.5, -0.08), Vector3(0.16, 2.0, 0.16))
	g.paint(shaft, func(p: Vector3) -> float:
		return maxf(maxf(maxf(absf(p.x), absf(p.z)), (absf(p.x) + absf(p.z)) * 0.75) - 0.042,
			maxf(-0.4 - p.y, p.y - 1.42)), Mat.WOOD)
	grip_wrap(g, Vector3(0, -0.12, 0), Vector3(0, 0.12, 0), 0.046, 0.05)
	grip_wrap(g, Vector3(0, 0.6, 0), Vector3(0, 0.8, 0), 0.046, 0.05)
	for y: float in [-0.13, 0.13, 0.59, 0.81, 0.32]:
		g.paint(shaft, func(p: Vector3) -> float:
			return maxf(Vector2(p.x, p.z).length() - 0.058, absf(p.y - y) - 0.013), Mat.TRIM)
	# Head collar and butt cap with an ember gem.
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.box(p, Vector3(0, 1.4, -0.02), Vector3(0.06, 0.09, 0.075), c), Mat.TRIM)
	g.paint(all, func(p: Vector3) -> float:
		return -1.0 if absf(p.y - 1.4) < c * 0.6 else 1.0, Mat.TRIM_DARK, -1, PAINT)
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.cylinder(p, Vector3(0, -0.38, 0), Vector3(0, -0.46, 0), 0.06, 0.04), Mat.TRIM)
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.sphere(p, Vector3(0, -0.47, 0), 0.032), Mat.GLOW)
	# The blade: hangs below the spine, thinning to the ember edge; a gold spine bar on top.
	var pts := spine()
	var blade := AABB(Vector3(-0.05, 0.9, -1.1), Vector3(0.1, 0.9, 1.15))
	g.paint(blade, func(p: Vector3) -> float:
		var hit := spine_hit(p, pts)
		var w := lerpf(0.24, 0.035, pow(hit.y, 1.2))
		if hit.z > w + 0.03:
			return 1.0
		var f := clampf(hit.x / w, 0.0, 1.0)
		var t := lerpf(0.022, 0.008, f)
		return maxf(maxf(-hit.x - 0.012, hit.x - w), absf(p.x) - t), Mat.BODY)
	g.paint(blade, func(p: Vector3) -> float:
		if not holds(g, p, Mat.BODY):
			return 1.0
		var hit := spine_hit(p, pts)
		var w := lerpf(0.24, 0.035, pow(hit.y, 1.2))
		if hit.x > w - c * 1.6:
			return -1.0
		return -1.0 if hit.x > w - c * 3.2 and hit.y > 0.05 else 1.0, Mat.GLOW, -1, PAINT)
	g.paint(blade, func(p: Vector3) -> float:
		if not holds(g, p, Mat.GLOW):
			return 1.0
		var hit := spine_hit(p, pts)
		var w := lerpf(0.24, 0.035, pow(hit.y, 1.2))
		return -1.0 if hit.x > w - c * 1.2 and hit.y > 0.25 and hit.y < 0.75 else 1.0, Mat.GLOW_CORE, -1, PAINT)
	g.paint(blade, func(p: Vector3) -> float:
		if not holds(g, p, Mat.BODY):
			return 1.0
		var hit := spine_hit(p, pts)
		var w := lerpf(0.24, 0.035, pow(hit.y, 1.2))
		var mid := hit.x > w * 0.3 and hit.x < w * 0.45
		return -1.0 if mid else 1.0, Mat.BODY_DARK, -1, PAINT)
	g.paint(blade, func(p: Vector3) -> float:
		var hit := spine_hit(p, pts)
		if hit.y > 0.92:
			return 1.0
		return maxf(maxf(hit.x - 0.004, -hit.x - 0.028), absf(p.x) - 0.03), Mat.TRIM, -1, FILL)
	for k in 5:
		var at := pts[2 + k * 3]
		for s: float in [-1.0, 1.0]:
			rivet(g, at + Vector3(0.03 * s, -0.012, 0), Vector3(s, 0, 0), c * 0.8)
	return g


## The item spark plate at the blade root, both faces (half cell).
func _root_plate() -> VoxelGrid:
	var centre := Vector3(0, 1.36, -0.13)
	var face := snap(0.022) + cell()
	var box := AABB(centre - Vector3(face + 0.02, 0.06, 0.06), Vector3((face + 0.02) * 2, 0.12, 0.12))
	var g := grid(box, 2.0)
	var c := g.cell
	g.paint(box, func(p: Vector3) -> float:
		var d := p - centre
		return maxf(absf(d.y) + absf(d.z) - 0.055, absf(p.x) - face), Mat.TRIM)
	for s: float in [-1.0, 1.0]:
		mark(g, Vector3(face * s, centre.y, centre.z), Vector3(0, 0, -s), Vector3.UP, 0.045, item_spark,
			Mat.GLOW, true, Mat.GLOW)
	return g
