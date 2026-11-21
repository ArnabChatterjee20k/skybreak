extends VoxelWeaponDesign
## Lyra's Ki Bow (docs/lookdev/weapons.md): a star-cartographer's recurve.
## Big: two midnight-lacquered limbs curving back to the string, a brass riser.
## Medium: brass edge strips, a cerulean inlay down each limb's back, a leather
## grip, an arrow shelf, brass nock caps. Tiny: three star lights per limb, a
## glowing eight-point star on each tip, a Wayfinder Star medallion (fine
## cell), a parchment ribbon tied on the upper limb.

const LIMB_START := 0.13
const TIP_Y := 0.69
const SAMPLES := 14


func kind() -> Weapon.Kind:
	return Weapon.Kind.KI_BOW


func palette() -> Dictionary:
	return {
		Mat.WOOD: Color("#26305a"), Mat.BODY_DARK: Color("#161b36"),
		Mat.TRIM: Color("#b49a64"), Mat.TRIM_DARK: Color("#7a6540"), Mat.EDGE: Color("#d4bf8a"),
		Mat.RIVET: Color("#d8c48e"), Mat.ENGRAVE: Color("#4e3f26"), Mat.EMBLEM: Color("#eaf4ff"),
		Mat.GRIP: Color("#5a4c47"), Mat.GRIP_DARK: Color("#2d2523"), Mat.LEATHER: Color("#4a3e3a"),
		Mat.ACCENT: Color("#1e7fd8"), Mat.CLOTH: Color("#cdb892"), Mat.CLOTH_DARK: Color("#9a8564"),
		Mat.STITCH: Color("#4a3e3a"),
		Mat.GLOW: Color("#7fc0ff"), Mat.GLOW_CORE: Color("#eaf4ff"),
	}


## The medallion's mark (the Heartstring Bow swaps in a heart).
func emblem() -> Callable:
	return wayfinder_star


func matte_roles() -> Array:
	return [Mat.BODY_DARK, Mat.ACCENT]


func build_grids() -> Array[VoxelGrid]:
	return [_bow(), _medallion()]


## Limb centreline point at t (0 at the riser, 1 at the tip) for side (+1 up, -1 down): curving
## back toward the string, then a small recurve flick at the tip.
static func limb_point(t: float, side: float) -> Vector3:
	var y := LIMB_START + t * (TIP_Y - LIMB_START)
	var z := 0.3 * t * t - 0.05 * smoothstep(0.8, 1.0, t)
	return Vector3(0, y * side, z)


static func limb_pts(side: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in SAMPLES + 1:
		pts.append(limb_point(float(i) / SAMPLES, side))
	return pts


## Distance in the YZ plane to the limb and the t there, as Vector2(distance, t).
static func limb_hit(p: Vector3, pts: PackedVector3Array) -> Vector2:
	var best := INF
	var best_t := 0.0
	var q := Vector3(0, p.y, p.z)
	for i in pts.size() - 1:
		var a := pts[i]
		var ab := pts[i + 1] - a
		var h := clampf((q - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
		var d := q.distance_to(a + ab * h)
		if d < best:
			best = d
			best_t = (i + h) / (pts.size() - 1)
	return Vector2(best, best_t)


func _bow() -> VoxelGrid:
	var all := AABB(Vector3(-0.07, -0.76, -0.12), Vector3(0.14, 1.52, 0.44))
	var g := grid(all)
	var c := g.cell
	for side: float in [-1.0, 1.0]:
		var pts := limb_pts(side)
		var half := AABB(Vector3(-0.07, 0.08 if side > 0 else -0.76, -0.12), Vector3(0.14, 0.68, 0.44))
		g.paint(half, func(p: Vector3) -> float:
			if p.y * side < LIMB_START - c:
				return 1.0
			var hit := limb_hit(p, pts)
			var w := lerpf(0.04, 0.022, hit.y)
			var th := lerpf(0.03, 0.017, hit.y)
			return maxf(absf(p.x) - w, hit.x - th), Mat.WOOD)
		# Brass edge strips down both sides of the limb, and the cerulean inlay on its back.
		g.paint(half, func(p: Vector3) -> float:
			var hit := limb_hit(p, pts)
			var lp := limb_point(hit.y, side)
			var back_edge := p.z < lp.z - lerpf(0.03, 0.017, hit.y) * 0.35
			return -1.0 if absf(p.x) > lerpf(0.04, 0.022, hit.y) - c * 0.9 and back_edge and hit.y < 0.86 else 1.0,
			Mat.TRIM, -1, PAINT)
		g.paint(half, func(p: Vector3) -> float:
			var hit := limb_hit(p, pts)
			var lp := limb_point(hit.y, side)
			var back := p.z < lp.z - c * 0.2
			return -1.0 if back and absf(p.x) < c * 0.9 and hit.y > 0.05 and hit.y < 0.84 else 1.0, Mat.ACCENT, -1, PAINT)
		# Three star lights on the limb's back.
		for k in 3:
			var t := 0.25 + k * 0.22
			var lp := limb_point(t, side)
			g.paint(AABB(lp - Vector3.ONE * 0.05, Vector3.ONE * 0.1), func(p: Vector3) -> float:
				return VoxelSdf.sphere(p, lp + Vector3(0, 0, -0.026), c * 1.1), Mat.GLOW_CORE, -1, FILL)
		# Nock cap: brass, with a glowing eight-point star facing out.
		var tip := limb_point(1.0, side)
		g.paint(AABB(tip - Vector3.ONE * 0.07, Vector3.ONE * 0.14), func(p: Vector3) -> float:
			return VoxelSdf.box(p, tip + Vector3(0, side * 0.01, 0), Vector3(0.028, 0.032, 0.026), c * 0.8), Mat.TRIM)
		g.paint(AABB(tip - Vector3.ONE * 0.07, Vector3.ONE * 0.14), func(p: Vector3) -> float:
			var q := Vector2(p.y - tip.y - side * 0.01, p.z - tip.z)
			var a := atan2(q.y, q.x)
			var r := q.length()
			var star := r < 0.012 + 0.024 * pow(absf(cos(a * 2.0)), 4.0) + 0.012 * pow(absf(sin(a * 2.0)), 4.0)
			return -1.0 if star and absf(p.x) < 0.034 and absf(p.x) > 0.018 else 1.0, Mat.GLOW, -1, FILL)
		# The string notch: a dark groove across the cap's inner face.
		g.paint(AABB(tip - Vector3.ONE * 0.07, Vector3.ONE * 0.14), func(p: Vector3) -> float:
			return -1.0 if absf(p.y - tip.y + side * 0.012) < c * 0.5 else 1.0, Mat.TRIM_DARK, -1, PAINT)
	# Riser: brass, chamfered, with an arrow shelf, and a leather grip in slanted bands.
	g.paint(all, func(p: Vector3) -> float:
		var q := p - Vector3(0, 0, 0.0)
		var cham := (absf(q.x) + absf(q.z)) * 0.8 - 0.05
		return maxf(maxf(VoxelSdf.box(q, Vector3.ZERO, Vector3(0.038, 0.17, 0.046), c), cham),
			-0.0), Mat.TRIM)
	g.paint(all, func(p: Vector3) -> float:
		return -1.0 if absf(p.y) < 0.075 else 1.0, Mat.GRIP_DARK, -1, PAINT)
	g.paint(all, func(p: Vector3) -> float:
		if absf(p.y) > 0.07:
			return 1.0
		var band := fposmod((p.y + p.x * 0.4 + 0.1) / 0.03, 1.0)
		var r := maxf(maxf(absf(p.x) - 0.038, absf(p.z) - 0.046), (absf(p.x) + absf(p.z)) * 0.8 - 0.05)
		return r - c * 0.95 if band < 0.6 else 1.0, Mat.GRIP, -1, ADD)
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.box(p, Vector3(0.035, 0.09, 0.0), Vector3(0.016, 0.006, 0.03)), Mat.EDGE, -1, ADD)
	for y: float in [-0.13, 0.13]:
		g.paint(all, func(p: Vector3) -> float:
			return -1.0 if absf(p.y - y) < c * 0.5 else 1.0, Mat.TRIM_DARK, -1, PAINT)
		if y < 0.0:
			rivet(g, Vector3(0, y - 0.02, -0.046), Vector3(0, 0, -1), c * 0.9)
	# The parchment ribbon tied round the upper limb, a tail hanging.
	var knot := limb_point(0.08, 1.0)
	g.paint(AABB(knot - Vector3(0.07, 0.12, 0.07), Vector3(0.14, 0.16, 0.14)), func(p: Vector3) -> float:
		var hit := limb_hit(p, limb_pts(1.0))
		var band := absf(hit.y - 0.08) < 0.03 and hit.x < 0.042 and absf(p.x) < 0.052
		var tail := absf(p.x - 0.045) < c * 0.6 and p.z > knot.z - 0.025 and p.z < knot.z + 0.005 \
			and p.y < knot.y and p.y > knot.y - 0.09 + absf(p.z - knot.z) * 0.6
		return -1.0 if band or tail else 1.0, Mat.CLOTH, -1, FILL)
	g.paint(AABB(knot - Vector3(0.07, 0.12, 0.07), Vector3(0.14, 0.16, 0.14)), func(p: Vector3) -> float:
		return -1.0 if fposmod(p.y / (c * 2.0), 1.0) < 0.5 else 1.0, Mat.CLOTH_DARK, -1, PAINT)
	return g


## The Wayfinder Star medallion on the riser's back (toward the target), half cell.
func _medallion() -> VoxelGrid:
	var z0 := snap(-0.046) - cell()
	var centre := Vector3(0, 0.112, z0)
	var box := AABB(centre - Vector3(0.045, 0.05, 0.03), Vector3(0.09, 0.1, 0.03))
	var g := grid(box, 2.0)
	var c := g.cell
	g.paint(box, func(p: Vector3) -> float:
		var d := p - centre
		if d.z > c * 0.5 or d.z < -c * 3.0:
			return 1.0
		return Vector2(d.x, d.y).length() - (0.04 - maxf(-d.z - c * 2.0, 0.0)), Mat.TRIM)
	mark(g, centre + Vector3(0, 0, -c * 2.5), Vector3(-1, 0, 0), Vector3.UP, 0.036, emblem(), Mat.EMBLEM,
		true, Mat.GLOW)
	return g
