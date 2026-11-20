extends VoxelWeaponDesign
## Kael's Storm Blade (docs/lookdev/weapons.md): a sky-knight's straight sword.
## Big: a broad diamond-section blade and a winged brass guard. Medium: the
## orange-white energy fuller, the guard's stepped feathers, a leather wrap,
## the octagonal pommel. Tiny: guard rivets, a winged-sky sigil inlaid on the
## ricasso (fine cell), a scarf-orange tassel, a nick in the edge.

const BLADE_LOW := 0.24
const BLADE_HIGH := 1.25
const TIP := 1.49
const HALF_W := 0.085
const HALF_T := 0.026
## The ricasso is painted on its own grid at half the cell, for the sigil (split snapped).
var ricasso_high := 0.42


func kind() -> Weapon.Kind:
	return Weapon.Kind.STORM_BLADE


func palette() -> Dictionary:
	return {
		Mat.BODY: Color(0.46, 0.50, 0.56), Mat.BODY_DARK: Color(0.33, 0.36, 0.42),
		Mat.EDGE: Color(0.74, 0.78, 0.83),
		Mat.TRIM: Color(0.72, 0.56, 0.31), Mat.TRIM_DARK: Color(0.45, 0.31, 0.13),
		Mat.RIVET: Color(0.90, 0.78, 0.52), Mat.ENGRAVE: Color(0.30, 0.22, 0.12),
		Mat.EMBLEM: Color(0.84, 0.68, 0.38),
		Mat.GRIP: Color(0.52, 0.30, 0.16), Mat.GRIP_DARK: Color(0.27, 0.17, 0.10),
		Mat.ACCENT: Color(0.86, 0.36, 0.11), Mat.CLOTH_DARK: Color(0.66, 0.25, 0.08),
		Mat.GLOW: Color(1.0, 0.70, 0.36), Mat.GLOW_CORE: Color(1.0, 0.95, 0.86),
	}


func build_grids() -> Array[VoxelGrid]:
	ricasso_high = snap(0.42)
	return [_hilt_and_blade(), _ricasso()]


## Blade half-width at height y (the tip tapers to a point).
static func half_width(y: float) -> float:
	if y <= BLADE_HIGH:
		return HALF_W
	return HALF_W * clampf((TIP - y) / (TIP - BLADE_HIGH), 0.0, 1.0)


## Diamond section: thick at the spine, thinning to the edge.
static func blade_sdf(p: Vector3) -> float:
	if p.y < BLADE_LOW or p.y > TIP:
		return 1.0
	var hw := half_width(p.y)
	if hw <= 0.0:
		return 1.0
	var t := HALF_T * (1.0 - 0.62 * clampf(absf(p.x) / hw, 0.0, 1.0))
	return maxf(absf(p.x) - hw, absf(p.z) - t)


func _blade(g: VoxelGrid, low: float, high: float) -> void:
	var c := g.cell
	var box := AABB(Vector3(-HALF_W - c, low, -HALF_T - c), Vector3(HALF_W * 2 + c * 2, high - low, HALF_T * 2 + c * 2))
	g.paint(box, func(p: Vector3) -> float: return 1.0 if p.y < low or p.y > high else blade_sdf(p), Mat.BODY)
	# The flat by the spine is a shade darker than the bevels.
	g.paint(box, func(p: Vector3) -> float:
		return -1.0 if absf(p.x) < half_width(p.y) * 0.45 else 1.0, Mat.BODY_DARK, -1, PAINT)
	# Sharpened edges: a lighter bevel band, two cells in.
	g.paint(box, func(p: Vector3) -> float:
		return -1.0 if absf(p.x) > half_width(p.y) - c * 1.6 else 1.0, Mat.EDGE, -1, PAINT)
	# Spine line: a slightly darker ridge down the centre.
	g.paint(box, func(p: Vector3) -> float:
		return -1.0 if absf(p.x) < c * 0.5 and p.y > ricasso_high + 0.08 else 1.0, Mat.BODY_DARK, -1, PAINT)


func _hilt_and_blade() -> VoxelGrid:
	var g := grid(AABB(Vector3(-0.25, -0.44, -0.08), Vector3(0.5, 1.96, 0.16)))
	var c := g.cell
	_blade(g, ricasso_high, TIP)
	# The energy fuller: a recessed channel either side of the spine, glowing.
	var fuller := AABB(Vector3(-0.04, ricasso_high, -0.04), Vector3(0.08, 0.8, 0.08))
	for s: float in [-1.0, 1.0]:
		g.paint(fuller, func(p: Vector3) -> float:
			var on := p.y > ricasso_high + 0.04 and p.y < 1.16 and absf(p.x) < 0.022 and absf(p.x) > c * 0.5
			return -1.0 if on and p.z * s > HALF_T - c * 1.2 else 1.0, Mat.EMPTY, -1, CARVE)
		g.paint(fuller, func(p: Vector3) -> float:
			var on := p.y > ricasso_high + 0.04 and p.y < 1.16 and absf(p.x) < 0.022 and absf(p.x) > c * 0.5
			return -1.0 if on and p.z * s > HALF_T - c * 2.2 else 1.0, Mat.GLOW, -1, PAINT)
	# The hot core: brighter cells down the fuller's middle third.
	g.paint(fuller, func(p: Vector3) -> float:
		var cc := g.cell_of(p)
		var glowing := g.get_mat(cc.x, cc.y, cc.z) == Mat.GLOW
		return -1.0 if glowing and absf(p.x) < 0.012 + c * 0.5 and p.y > 0.6 and p.y < 1.0 else 1.0,
		Mat.GLOW_CORE, -1, PAINT)
	# A nick in the left edge (storytelling: it has seen fights).
	g.paint(AABB(Vector3(0.05, 0.9, -0.05), Vector3(0.05, 0.06, 0.1)), func(p: Vector3) -> float:
		return VoxelSdf.sphere(p, Vector3(HALF_W + 0.008, 0.925, 0), 0.022), Mat.EMPTY, -1, CARVE)
	_guard(g)
	# Grip: a leather wrap in a diagonal lattice between two brass collars.
	grip_wrap(g, Vector3(0, -0.15, 0), Vector3(0, 0.16, 0), 0.04, 0.055)
	for y: float in [-0.16, 0.165]:
		g.paint(AABB(Vector3(-0.07, y - 0.03, -0.07), Vector3(0.14, 0.06, 0.14)), func(p: Vector3) -> float:
			return VoxelSdf.cylinder(p, Vector3(0, y - 0.016, 0), Vector3(0, y + 0.016, 0), 0.054, 0.054), Mat.TRIM_DARK)
	# Pommel: an octagonal brass cap with an energy gem front and back, and a ring.
	g.paint(AABB(Vector3(-0.08, -0.3, -0.08), Vector3(0.16, 0.14, 0.16)), func(p: Vector3) -> float:
		var oct := maxf(maxf(absf(p.x), absf(p.z)), (absf(p.x) + absf(p.z)) * 0.72) - 0.058
		return maxf(oct, absf(p.y + 0.22) - 0.045), Mat.TRIM)
	g.paint(AABB(Vector3(-0.08, -0.3, -0.08), Vector3(0.16, 0.14, 0.16)), func(p: Vector3) -> float:
		return -1.0 if absf(p.y + 0.22) > 0.032 else 1.0, Mat.TRIM_DARK, -1, PAINT)
	for s: float in [-1.0, 1.0]:
		g.paint(AABB(Vector3(-0.04, -0.26, -0.08), Vector3(0.08, 0.08, 0.16)), func(p: Vector3) -> float:
			return absf(p.x) + absf(p.y + 0.22) * 0.9 - 0.026 if p.z * s > 0.04 else 1.0, Mat.GLOW_CORE)
	g.paint(AABB(Vector3(-0.05, -0.33, -0.03), Vector3(0.1, 0.07, 0.06)), func(p: Vector3) -> float:
		return VoxelSdf.torus(p, Vector3(0, -0.29, 0), Vector3(0, 0, 1), 0.022, 0.009), Mat.TRIM_DARK)
	# Tassel: a scarf-orange ribbon knotted on the ring, two tails.
	for k in 2:
		var sx := -1.0 if k == 0 else 1.0
		var a := Vector3(0.0, -0.3, 0)
		# Short, so it stays inside the old model's clearance bounds (+10 cm).
		var b := Vector3(0.024 * sx + 0.028, -0.335 + k * 0.012, 0.0)
		g.paint(_segment_box(a, b, 0.03), func(p: Vector3) -> float:
			var q := p - a
			var ab := b - a
			var h := clampf(q.dot(ab) / ab.dot(ab), 0.0, 1.0)
			var d := q - ab * h
			return maxf(Vector2(d.x, d.y).length() - 0.013, absf(d.z) - c * 0.5), Mat.ACCENT if k == 0 else Mat.CLOTH_DARK)
	return g


## The winged guard: a centre block and three stepped brass feathers per side, rising outward.
func _guard(g: VoxelGrid) -> void:
	var c := g.cell
	var box := AABB(Vector3(-0.25, 0.15, -0.07), Vector3(0.5, 0.2, 0.14))
	g.paint(box, func(p: Vector3) -> float:
		return VoxelSdf.box(p, Vector3(0, 0.205, 0), Vector3(0.07, 0.04, 0.05), c), Mat.TRIM)
	for s: float in [-1.0, 1.0]:
		for k in 3:
			var x0 := 0.08 + k * 0.052
			var top := 0.255 + k * 0.03
			var bottom := 0.18 + k * 0.012
			g.paint(box, func(p: Vector3) -> float:
				var x := p.x * s
				var lean := (x - x0) * 0.5
				var d := maxf(absf(x - x0 - 0.024) - 0.026, maxf(p.y - top - lean, bottom - p.y))
				return maxf(d, absf(p.z) - (0.042 - k * 0.006)), Mat.TRIM if k != 1 else Mat.TRIM_DARK, -1, ADD)
		# Feather tips catch the light; the shafts between them are darker.
		g.paint(box, func(p: Vector3) -> float:
			return -1.0 if p.x * s > 0.07 and fposmod((p.x * s - 0.08) / 0.052, 1.0) > 0.86 else 1.0,
			Mat.TRIM_DARK, -1, PAINT)
		for z: float in [-1.0, 1.0]:
			rivet(g, Vector3(0.1 * s, 0.21, 0.042 * z), Vector3(0, 0, z), c * 0.9)
	# The guard's energy gem, front and back.
	for z: float in [-1.0, 1.0]:
		g.paint(box, func(p: Vector3) -> float:
			return VoxelSdf.ellipsoid(p, Vector3(0, 0.205, 0.05 * z), Vector3(0.026, 0.03, 0.016)), Mat.GLOW_CORE)
		g.paint(box, func(p: Vector3) -> float:
			return VoxelSdf.torus(p, Vector3(0, 0.205, 0.05 * z), Vector3(0, 0, 1), 0.034, 0.008), Mat.TRIM_DARK, -1, ADD)


## The ricasso (the blade's flat base) at half the cell, with the winged-sky sigil inlaid in brass.
func _ricasso() -> VoxelGrid:
	var g := grid(AABB(Vector3(-HALF_W, BLADE_LOW, -HALF_T), Vector3(HALF_W * 2, ricasso_high - BLADE_LOW, HALF_T * 2)), 2.0)
	_blade(g, BLADE_LOW, ricasso_high - g.cell * 0.01)
	for z: float in [-1.0, 1.0]:
		var u := Vector3(1, 0, 0) * z
		mark(g, Vector3(0, 0.33, HALF_T * z), u, Vector3.UP, 0.075, winged_sky, Mat.EMBLEM, true, Mat.EMBLEM)
	return g
