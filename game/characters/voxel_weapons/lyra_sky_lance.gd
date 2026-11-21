extends VoxelWeaponDesign
## Lyra's Sky Lance (docs/lookdev/weapons.md). Big: a long octagonal
## midnight-lacquered shaft, a broad leaf head, a cerulean pennant. Medium:
## brass bands and a socket collar with a broken ring, two leather grips (main
## and off hand), a brass butt spike. Tiny: band rivets, degree ticks on the
## socket, the energy channel and pale edges on the head, constellation dots on
## the pennant, a Wayfinder Star on each face of the head (fine cell).

const SHAFT_LOW := -0.8
const SHAFT_HIGH := 1.4
const HEAD_LOW := 1.4
const HEAD_HIGH := 1.96
const HEAD_HALF_T := 0.024


func kind() -> Weapon.Kind:
	return Weapon.Kind.SKY_LANCE


func palette() -> Dictionary:
	return {
		Mat.WOOD: Color("#26305a"), Mat.BODY_DARK: Color("#5f6a80"),
		Mat.BODY: Color("#98a2b4"), Mat.EDGE: Color("#d6dde8"),
		Mat.TRIM: Color("#b49a64"), Mat.TRIM_DARK: Color("#7a6540"),
		Mat.RIVET: Color("#d8c48e"), Mat.ENGRAVE: Color("#4e3f26"), Mat.EMBLEM: Color("#b49a64"),
		Mat.GRIP: Color("#5a4c47"), Mat.GRIP_DARK: Color("#2d2523"),
		Mat.ACCENT: Color("#1e7fd8"), Mat.CLOTH: Color("#1e7fd8"), Mat.CLOTH_DARK: Color("#12509a"),
		Mat.STITCH: Color("#cdb892"),
		Mat.GLOW: Color("#7fc0ff"), Mat.GLOW_CORE: Color("#eaf4ff"),
	}


func build_grids() -> Array[VoxelGrid]:
	return [_lance(), _star(1.0), _star(-1.0)]


## Half-width (along z) of the leaf head at height y.
static func head_width(y: float) -> float:
	var f := clampf((y - HEAD_LOW) / (HEAD_HIGH - HEAD_LOW), 0.0, 1.0)
	return 0.11 * pow(sin(PI * pow(f, 0.7)), 0.85) * (1.0 - f * 0.15) + 0.002


func _lance() -> VoxelGrid:
	var all := AABB(Vector3(-0.08, -0.92, -0.14), Vector3(0.16, 2.92, 0.5))
	var g := grid(all)
	var c := g.cell
	var shaft_box := AABB(Vector3(-0.07, SHAFT_LOW - 0.02, -0.07), Vector3(0.14, SHAFT_HIGH - SHAFT_LOW + 0.04, 0.14))
	var octagon := func(p: Vector3, r: float) -> float:
		return maxf(maxf(absf(p.x), absf(p.z)), (absf(p.x) + absf(p.z)) * 0.75) - r
	g.paint(shaft_box, func(p: Vector3) -> float:
		return maxf(octagon.call(p, 0.04), maxf(SHAFT_LOW - p.y, p.y - SHAFT_HIGH)), Mat.WOOD)
	# A thin cerulean inlay line spiralling up the shaft.
	g.paint(shaft_box, func(p: Vector3) -> float:
		var ang := atan2(p.z, p.x) / TAU
		return -1.0 if fposmod(p.y / 0.36 - ang, 1.0) < 0.06 else 1.0, Mat.ACCENT, -1, PAINT)
	# Brass bands with rivets.
	for y: float in [-0.62, -0.3, 0.3, 0.9, 1.15]:
		g.paint(shaft_box, func(p: Vector3) -> float:
			return maxf(octagon.call(p, 0.048), absf(p.y - y) - 0.018), Mat.TRIM)
		for k in 4:
			var a := TAU * k / 4.0 + PI * 0.25
			rivet(g, Vector3(cos(a) * 0.048, y, sin(a) * 0.048), Vector3(cos(a), 0, sin(a)), c * 0.8)
	# Two leather grips: the main hand at the origin, the off hand higher up.
	grip_wrap(g, Vector3(0, -0.13, 0), Vector3(0, 0.13, 0), 0.043, 0.05)
	grip_wrap(g, Vector3(0, 0.52, 0), Vector3(0, 0.72, 0), 0.043, 0.05)
	for y: float in [-0.14, 0.14, 0.51, 0.73]:
		g.paint(shaft_box, func(p: Vector3) -> float:
			return maxf(octagon.call(p, 0.054), absf(p.y - y) - 0.012), Mat.TRIM_DARK)
	# Butt spike: a brass cap tapering to a point.
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.cylinder(p, Vector3(0, -0.8, 0), Vector3(0, -0.92, 0), 0.05, 0.012), Mat.TRIM)
	g.paint(all, func(p: Vector3) -> float:
		return -1.0 if absf(p.y + 0.83) < c * 0.6 else 1.0, Mat.TRIM_DARK, -1, PAINT)
	# Socket collar: brass, with degree ticks and a broken ring around it.
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.cylinder(p, Vector3(0, 1.28, 0), Vector3(0, 1.42, 0), 0.058, 0.044), Mat.TRIM)
	g.paint(all, func(p: Vector3) -> float:
		var ang := atan2(p.z, p.x) / TAU * 24.0
		return -1.0 if absf(p.y - 1.33) < 0.012 and fposmod(ang, 1.0) < 0.3 else 1.0, Mat.ENGRAVE, -1, PAINT)
	g.paint(all, func(p: Vector3) -> float:
		var d := VoxelSdf.torus(p, Vector3(0, 1.35, 0), Vector3(1, 0, 0), 0.1, 0.011)
		return d if atan2(p.y - 1.35, p.z) < 0.9 or atan2(p.y - 1.35, p.z) > 1.6 else 1.0, Mat.TRIM_DARK, -1, ADD)
	_head(g)
	_pennant(g)
	return g


## The leaf head: diamond section, flat faces toward +-X, pale edges, an energy channel.
func _head(g: VoxelGrid) -> void:
	var c := g.cell
	var box := AABB(Vector3(-0.05, HEAD_LOW - 0.02, -0.14), Vector3(0.1, HEAD_HIGH - HEAD_LOW + 0.06, 0.28))
	g.paint(box, func(p: Vector3) -> float:
		if p.y < HEAD_LOW or p.y > HEAD_HIGH:
			return 1.0
		var w := head_width(p.y)
		var t := HEAD_HALF_T * (1.0 - 0.6 * clampf(absf(p.z) / w, 0.0, 1.0))
		return maxf(absf(p.z) - w, absf(p.x) - t), Mat.BODY, -1, ADD)
	g.paint(box, func(p: Vector3) -> float:
		return -1.0 if absf(p.z) > head_width(p.y) - c * 1.6 else 1.0, Mat.EDGE, -1, PAINT)
	g.paint(box, func(p: Vector3) -> float:
		return -1.0 if absf(p.z) < head_width(p.y) * 0.4 and absf(p.z) > c * 0.5 else 1.0, Mat.BODY_DARK, -1, PAINT)
	# The channel: a glowing line up the middle of each face, hotter in the centre.
	for s: float in [-1.0, 1.0]:
		g.paint(box, func(p: Vector3) -> float:
			var on := absf(p.z) < c * 0.6 and p.y > HEAD_LOW + 0.12 and p.y < HEAD_HIGH - 0.1
			return -1.0 if on and p.x * s > HEAD_HALF_T - c * 1.5 else 1.0, Mat.GLOW, -1, PAINT)
	g.paint(box, func(p: Vector3) -> float:
		var cc := g.cell_of(p)
		return -1.0 if g.get_mat(cc.x, cc.y, cc.z) == Mat.GLOW and p.y > 1.62 and p.y < 1.78 else 1.0,
		Mat.GLOW_CORE, -1, PAINT)


## The pennant: cerulean cloth with a slight wave, a swallowtail end, constellation dots and lines.
func _pennant(g: VoxelGrid) -> void:
	var c := g.cell
	var box := AABB(Vector3(-0.04, 1.0, 0.0), Vector3(0.08, 0.36, 0.38))
	g.paint(box, func(p: Vector3) -> float:
		var f := (p.z - 0.03) / 0.32
		if f < 0.0 or f > 1.0:
			return 1.0
		var half_h := lerpf(0.15, 0.11, f)
		var mid := 1.18 - f * 0.03
		var notch := f > 0.8 and absf(p.y - mid) < (f - 0.8) / 0.2 * 0.07
		if notch:
			return 1.0
		var wave := sin(f * 7.0) * c * 1.1
		return maxf(absf(p.y - mid) - half_h, absf(p.x - wave) - c * 0.55), Mat.CLOTH)
	# The hem: a parchment-stitched border, darker fold bands.
	g.paint(box, func(p: Vector3) -> float:
		var f := (p.z - 0.03) / 0.32
		var mid := 1.18 - f * 0.03
		return -1.0 if absf(absf(p.y - mid) - lerpf(0.15, 0.11, f)) < c * 0.6 and fposmod(p.z / (c * 2.0), 1.0) < 0.5 else 1.0,
		Mat.STITCH, -1, PAINT)
	g.paint(box, func(p: Vector3) -> float:
		var f := (p.z - 0.03) / 0.32
		return -1.0 if cos(f * 7.0) < -0.7 else 1.0, Mat.CLOTH_DARK, -1, PAINT)
	# A small constellation: four stars joined by parchment lines.
	var stars := [Vector2(0.09, 1.25), Vector2(0.15, 1.2), Vector2(0.22, 1.23), Vector2(0.27, 1.14)]
	for i in stars.size():
		var s: Vector2 = stars[i]
		g.paint(box, func(p: Vector3) -> float:
			return Vector2(p.z - s.x, p.y - s.y).length() - c * 0.9, Mat.GLOW_CORE, -1, PAINT)
		if i + 1 < stars.size():
			var e: Vector2 = stars[i + 1]
			g.paint(box, func(p: Vector3) -> float:
				var q := Vector2(p.z, p.y)
				var ab := e - s
				var h := clampf((q - s).dot(ab) / ab.dot(ab), 0.0, 1.0)
				var cc := g.cell_of(p)
				if g.get_mat(cc.x, cc.y, cc.z) == Mat.GLOW_CORE:
					return 1.0
				return q.distance_to(s + ab * h) - c * 0.45, Mat.STITCH, -1, PAINT)
	# Lashed to the shaft with two parchment ties.
	for y: float in [1.06, 1.3]:
		g.paint(AABB(Vector3(-0.07, y - 0.03, -0.07), Vector3(0.14, 0.06, 0.14)), func(p: Vector3) -> float:
			return maxf(Vector2(p.x, p.z).length() - 0.052, absf(p.y - y) - c * 0.6), Mat.STITCH)


## A Wayfinder Star plate on the head's base, one per face (half cell).
func _star(s: float) -> VoxelGrid:
	var face := snap(HEAD_HALF_T) + cell()
	var centre := Vector3(face * s, 1.5, 0.0)
	var box := AABB(centre - Vector3(0.03, 0.06, 0.06), Vector3(0.06, 0.12, 0.12))
	var g := grid(box, 2.0)
	var c := g.cell
	g.paint(box, func(p: Vector3) -> float:
		var d := p - centre
		var out := d.x * s
		if out > c * 0.5 or out < -c * 3.5:
			return 1.0
		return Vector2(d.y, d.z).length() - (0.048 - maxf(out + c * 0.5, 0.0) * 0.6), Mat.TRIM)
	mark(g, centre, Vector3(0, 0, -s), Vector3.UP, 0.044, wayfinder_star, Mat.GLOW_CORE, true, Mat.GLOW)
	return g
