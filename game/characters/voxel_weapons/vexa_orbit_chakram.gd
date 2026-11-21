extends VoxelWeaponDesign
## Vexa's Orbit Chakram (docs/lookdev/weapons.md). Big: a flat steel ring
## with four crescent hook teeth. Medium: the violet energy inner ring on four
## struts, the wrapped grip bar under the ring, its boss plate. Tiny: the
## lighter bevelled blade edge, eight rivets a side, the Crescent Eye engraved
## small on the grip boss (fine cell), a bronze lucky-coin rivet.

const CENTRE := Vector3(0, 0.36, 0)
const INNER := 0.3
const OUTER := 0.42
const HALF_T := 0.026


func kind() -> Weapon.Kind:
	return Weapon.Kind.ORBIT_CHAKRAM


func palette() -> Dictionary:
	return {
		Mat.BODY: Color("#9ca1ae"), Mat.BODY_DARK: Color("#5e626e"), Mat.EDGE: Color("#d4d8e0"),
		Mat.TRIM: Color("#6c707c"), Mat.TRIM_DARK: Color("#3e414b"),
		Mat.RIVET: Color("#c4c8d0"), Mat.ENGRAVE: Color("#454852"),
		Mat.GRIP: Color("#7a7484"), Mat.GRIP_DARK: Color("#4c4756"), Mat.LEATHER: Color("#2c2a30"),
		Mat.ACCENT: Color("#8a3cf0"), Mat.EMBLEM: Color("#8a3cf0"), Mat.STONE: Color("#a8743c"),
		Mat.GLOW: Color("#b070ff"), Mat.GLOW_CORE: Color("#f2e6ff"),
	}


func matte_roles() -> Array:
	return []


func build_grids() -> Array[VoxelGrid]:
	return [_ring(), _boss()]


## Ring section: full thickness mid-ring, thinning to a sharp outer edge.
static func ring_sdf(p: Vector3) -> float:
	var r := Vector2(p.x - CENTRE.x, p.y - CENTRE.y).length()
	var t := HALF_T * clampf((OUTER - r) / 0.045, 0.3, 1.0)
	return maxf(maxf(INNER - r, r - OUTER), absf(p.z) - t)


func _ring() -> VoxelGrid:
	var all := AABB(Vector3(-0.58, -0.2, -0.06), Vector3(1.16, 1.16, 0.12))
	var g := grid(all)
	var c := g.cell
	g.paint(all, ring_sdf, Mat.BODY)
	# The sharpened rim and the inner lip: lighter steel.
	g.paint(all, func(p: Vector3) -> float:
		var r := Vector2(p.x, p.y - CENTRE.y).length()
		return -1.0 if r > OUTER - c * 1.7 or r < INNER + c * 0.9 else 1.0, Mat.EDGE, -1, PAINT)
	# A darker fuller groove around the middle of each face.
	g.paint(all, func(p: Vector3) -> float:
		var r := Vector2(p.x, p.y - CENTRE.y).length()
		return -1.0 if absf(r - 0.355) < c * 0.6 else 1.0, Mat.BODY_DARK, -1, PAINT)
	# Four crescent hook teeth, swept in the spin direction.
	for k in 4:
		var ang := TAU * k / 4.0 + PI * 0.25
		var radial := Vector2(cos(ang), sin(ang))
		var tangent := Vector2(-radial.y, radial.x)
		var tooth := func(p: Vector3) -> float:
			var d := Vector2(p.x, p.y - CENTRE.y)
			var t := d.dot(radial)
			var s := d.dot(tangent)
			var f := (t - 0.39) / 0.17
			if f < 0.0 or f > 1.0:
				return 1.0
			var curve := 0.075 * f * f
			var width := 0.062 * (1.0 - f) + 0.004
			var thick := HALF_T * lerpf(1.0, 0.35, f)
			return maxf(absf(s - curve) - width, absf(p.z) - thick)
		g.paint(all, tooth, Mat.BODY, -1, ADD)
		g.paint(all, func(p: Vector3) -> float:
			var d := Vector2(p.x, p.y - CENTRE.y)
			var t := d.dot(radial)
			var s := d.dot(tangent)
			var f := (t - 0.39) / 0.17
			return -1.0 if f > 0.12 and s - 0.075 * f * f > 0.062 * (1.0 - f) - c * 1.2 else 1.0, Mat.EDGE, -1, PAINT)
	# The energy inner ring on four struts.
	g.paint(all, func(p: Vector3) -> float:
		var r := Vector2(p.x, p.y - CENTRE.y).length()
		return maxf(absf(r - 0.262) - 0.018, absf(p.z) - c * 0.9), Mat.GLOW)
	g.paint(all, func(p: Vector3) -> float:
		var r := Vector2(p.x, p.y - CENTRE.y).length()
		return -1.0 if absf(r - 0.262) < c * 0.5 else 1.0, Mat.GLOW_CORE, -1, PAINT)
	for k in 4:
		var ang := TAU * k / 4.0
		var dir := Vector3(cos(ang), sin(ang), 0)
		g.paint(all, func(p: Vector3) -> float:
			return VoxelSdf.box(Basis(Vector3.BACK, -ang) * (p - CENTRE - dir * 0.29), Vector3.ZERO,
				Vector3(0.03, 0.016, HALF_T * 0.8), c * 0.5), Mat.TRIM, -1, FILL)
	# Rivets: eight a side on the ring.
	for k in 8:
		var ang := TAU * k / 8.0 + PI / 8.0
		var at := CENTRE + Vector3(cos(ang), sin(ang), 0) * 0.33
		for z: float in [-1.0, 1.0]:
			rivet(g, at + Vector3(0, 0, HALF_T * z), Vector3(0, 0, z), c * 0.85,
				Mat.STONE if k == 2 and z > 0.0 else Mat.RIVET)
	# Grip bar under the ring: ash-lilac wraps, a leather-capped end.
	grip_wrap(g, Vector3(0, -0.14, 0), Vector3(0, -0.035, 0), 0.03, 0.04)
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.cylinder(p, Vector3(0, -0.165, 0), Vector3(0, -0.135, 0), 0.04, 0.036), Mat.TRIM)
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.torus(p, Vector3(0, -0.185, 0), Vector3(0, 0, 1), 0.016, 0.006), Mat.TRIM_DARK, -1, ADD)
	return g


## The grip boss where the bar meets the ring, at half the cell, with the Crescent Eye.
func _boss() -> VoxelGrid:
	var box := AABB(Vector3(-0.07, -0.04, -HALF_T - 0.02), Vector3(0.14, 0.1, HALF_T * 2 + 0.04))
	var g := grid(box, 2.0)
	var c := g.cell
	var face := snap(HALF_T) + c * 2.0
	g.paint(box, func(p: Vector3) -> float:
		var q := p - Vector3(0, 0.005, 0)
		var shape := maxf(absf(q.x) * 0.9 + absf(q.y) * 0.55 - 0.05, absf(q.y) - 0.04)
		return maxf(shape, absf(p.z) - face), Mat.TRIM)
	g.paint(box, func(p: Vector3) -> float:
		var q := p - Vector3(0, 0.005, 0)
		return -1.0 if absf(q.x) * 0.9 + absf(q.y) * 0.55 > 0.05 - c * 1.2 else 1.0, Mat.EDGE, -1, PAINT)
	for z: float in [-1.0, 1.0]:
		mark(g, Vector3(0, 0.005, (face - c * 0.5) * z), Vector3(z, 0, 0), Vector3.UP, 0.04, crescent_eye,
			Mat.EMBLEM, true, Mat.ACCENT)
	return g
