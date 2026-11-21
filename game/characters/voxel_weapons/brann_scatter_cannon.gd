extends VoxelWeaponDesign
## Brann's Scatter Cannon (docs/lookdev/weapons.md): a hand-forged blunderbuss.
## Big: a blackened-iron barrel with a flared bell muzzle, a granite-and-iron
## forge breech. Medium: three barrel bands (one newer and brighter), a coal
## hopper on top, glowing vent grilles, a riveted foregrip under the barrel, a
## raked oxblood grip. Tiny: band rivets, the ember glow deep in the bore, the
## Hearth-Mark stamped on both sides of the breech, stitch lines, a trigger.

const GRIP_TILT := deg_to_rad(15.0)
const AXIS_Y := 0.2
const BREECH_C := Vector3(0, 0.17, -0.06)
const BREECH_HALF := Vector3(0.1, 0.11, 0.17)


func kind() -> Weapon.Kind:
	return Weapon.Kind.SCATTER_CANNON


func palette() -> Dictionary:
	return {
		Mat.STONE: Color("#6e6a6c"), Mat.CLOTH_DARK: Color("#57545a"),
		Mat.BODY: Color("#3c3c43"), Mat.BODY_DARK: Color("#2a2a30"), Mat.EDGE: Color("#6a6a72"),
		Mat.TRIM: Color("#7a7a82"), Mat.TRIM_DARK: Color("#1e1e22"),
		Mat.RIVET: Color("#6a6a72"), Mat.ENGRAVE: Color("#1e1e22"), Mat.EMBLEM: Color("#ff4a12"),
		Mat.GRIP: Color("#4a2c1e"), Mat.GRIP_DARK: Color("#2c1a12"), Mat.STITCH: Color("#6a4630"),
		Mat.GLOW: Color("#ff4a12"), Mat.GLOW_CORE: Color("#ffd9a0"),
	}


func matte_roles() -> Array:
	return [Mat.STONE, Mat.CLOTH_DARK]


func build_grids() -> Array[VoxelGrid]:
	return [_cannon()]


static func grip_local(p: Vector3) -> Vector3:
	return Basis(Vector3.RIGHT, GRIP_TILT) * (p - Vector3(0, 0, 0.04))


## Barrel radius at z (tapering out toward a flared bell).
static func barrel_r(z: float) -> float:
	var f := clampf((-z - 0.2) / 0.44, 0.0, 1.0)
	var r := lerpf(0.098, 0.112, f)
	if z < -0.6:
		r += pow((-z - 0.6) / 0.12, 2.0) * 0.06
	return r


func _cannon() -> VoxelGrid:
	var all := AABB(Vector3(-0.2, -0.16, -0.75), Vector3(0.4, 0.56, 0.9))
	var g := grid(all)
	var c := g.cell
	# Grip: raked, oxblood leather in slanted bands over iron, with an iron butt cap.
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.box(grip_local(p), Vector3(0, -0.01, 0), Vector3(0.042, 0.11, 0.058), 0.014), Mat.GRIP_DARK)
	g.paint(all, func(p: Vector3) -> float:
		var q := grip_local(p)
		if q.y > 0.08 or q.y < -0.09:
			return 1.0
		var band := fposmod((q.y + q.z * 0.5) / 0.032, 1.0)
		return VoxelSdf.box(q, Vector3(0, -0.01, 0), Vector3(0.042 + c * 0.9, 0.11, 0.058 + c * 0.9), 0.014) if band < 0.6 else 1.0,
		Mat.GRIP, -1, ADD)
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.box(grip_local(p), Vector3(0, -0.12, 0.003), Vector3(0.05, 0.018, 0.066), 0.008), Mat.BODY)
	# Stitch line up the back of the grip.
	g.paint(all, func(p: Vector3) -> float:
		var q := grip_local(p)
		return -1.0 if absf(q.x) < c * 0.6 and q.z > 0.05 and fposmod(q.y / (c * 2.0), 1.0) < 0.5 else 1.0, Mat.STITCH, -1, PAINT)
	# Trigger and its guard.
	g.paint(all, func(p: Vector3) -> float:
		var q := p - Vector3(0, 0.05, -0.08)
		var ring := Vector2(Vector2(q.z / 1.3, q.y).length() - 0.045, q.x).length() - 0.011
		return ring if q.y < 0.0 else 1.0, Mat.BODY_DARK, -1, ADD)
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.capsule(p, Vector3(0, 0.065, -0.075), Vector3(0, 0.025, -0.065), 0.01, 0.008), Mat.EDGE, -1, ADD)
	_breech(g)
	_barrel(g)
	return g


## The forge breech: granite block in an iron cage, vent grilles, a coal hopper, the Hearth-Mark.
func _breech(g: VoxelGrid) -> void:
	var c := g.cell
	var all := AABB(BREECH_C - BREECH_HALF - Vector3.ONE * 0.06, (BREECH_HALF + Vector3.ONE * 0.06) * 2.0)
	g.paint(all, func(p: Vector3) -> float:
		var q := p - BREECH_C
		var cham := (absf(q.x) + absf(q.y)) * 0.75 - (BREECH_HALF.x + BREECH_HALF.y) * 0.75 + 0.03
		return maxf(VoxelSdf.box(q, Vector3.ZERO, BREECH_HALF), cham), Mat.STONE)
	g.paint(all, func(p: Vector3) -> float:
		var cc := g.cell_of(p)
		return -1.0 if VoxelSdf.hash3(Vector3i(cc.x / 3, cc.y / 3, cc.z / 3), 13) < 0.3 else 1.0, Mat.CLOTH_DARK, -1, PAINT)
	# Iron cage: straps along the edges at front and back, riveted.
	for z: float in [-0.21, 0.08]:
		g.paint(all, func(p: Vector3) -> float:
			var q := p - BREECH_C
			var cham := (absf(q.x) + absf(q.y)) * 0.75 - (BREECH_HALF.x + BREECH_HALF.y) * 0.75 + 0.03 - c
			return maxf(maxf(VoxelSdf.box(q, Vector3.ZERO, BREECH_HALF + Vector3(c, c, 0) * 1.0), cham),
				absf(p.z - z) - 0.022), Mat.BODY)
		for s: float in [-1.0, 1.0]:
			for y: float in [0.1, 0.24]:
				rivet(g, Vector3((BREECH_HALF.x + c) * s, y, z), Vector3(s, 0, 0), c * 1.0)
	# Vent grilles: glowing slots low on each side, behind iron bars.
	for s: float in [-1.0, 1.0]:
		g.paint(all, func(p: Vector3) -> float:
			var on := absf(p.x * s - BREECH_HALF.x) < c * 1.2 and p.y > 0.085 and p.y < 0.125 and p.z > -0.17 and p.z < 0.04
			return -1.0 if on and fposmod(p.z / (c * 3.0), 1.0) < 0.5 else 1.0, Mat.EMPTY, -1, CARVE)
		# Slot floors glow; the bars between them are iron.
		g.paint(all, func(p: Vector3) -> float:
			var on := absf(p.x * s - BREECH_HALF.x) < c * 2.6 and p.y > 0.085 and p.y < 0.125 and p.z > -0.17 and p.z < 0.04
			if not on:
				return 1.0
			var cc := g.cell_of(p)
			var exposed := g.get_mat(cc.x + int(s), cc.y, cc.z) == 0
			return -1.0 if exposed and p.x * s < BREECH_HALF.x - c else 1.0, Mat.GLOW, -1, PAINT)
		g.paint(all, func(p: Vector3) -> float:
			var on := p.x * s > BREECH_HALF.x - c and p.y > 0.085 and p.y < 0.125 and p.z > -0.17 and p.z < 0.04
			return -1.0 if on else 1.0, Mat.BODY_DARK, -1, PAINT)
		mark(g, Vector3(BREECH_HALF.x * s, 0.205, -0.065), Vector3(0, 0, -s), Vector3.UP, 0.055, hearth_mark,
			Mat.EMBLEM, true, Mat.GLOW)
	# Coal hopper on top: an iron box, open, embers heaped inside.
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.box(p, Vector3(0, 0.31, 0.0), Vector3(0.055, 0.035, 0.06), c * 0.5), Mat.BODY)
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.box(p, Vector3(0, 0.33, 0.0), Vector3(0.042, 0.03, 0.047)), Mat.EMPTY, -1, CARVE)
	g.paint(all, func(p: Vector3) -> float:
		var cc := g.cell_of(p)
		var heap := VoxelSdf.ellipsoid(p, Vector3(0, 0.3, 0.0), Vector3(0.045, 0.028, 0.05))
		return heap + VoxelSdf.hash3(cc, 17) * 0.01, Mat.GLOW, -1, ADD)
	g.paint(AABB(Vector3(-0.05, 0.29, -0.05), Vector3(0.1, 0.05, 0.1)), func(p: Vector3) -> float:
		var cc := g.cell_of(p)
		return -1.0 if g.get_mat(cc.x, cc.y, cc.z) == Mat.GLOW and VoxelSdf.hash3(cc, 19) < 0.35 else 1.0,
		Mat.GLOW_CORE, -1, PAINT)


## The barrel: blackened iron, three bands (the middle one newer), a flared bell, embers in the bore.
func _barrel(g: VoxelGrid) -> void:
	var c := g.cell
	var all := AABB(Vector3(-0.2, AXIS_Y - 0.2, -0.75), Vector3(0.4, 0.4, 0.56))
	var axis := func(p: Vector3) -> float:
		return Vector2(p.x, p.y - AXIS_Y).length()
	g.paint(all, func(p: Vector3) -> float:
		if p.z > -0.2 or p.z < -0.72:
			return 1.0
		return axis.call(p) - barrel_r(p.z), Mat.BODY, -1, ADD)
	# A lighter worn line along the top, darker underside.
	g.paint(all, func(p: Vector3) -> float:
		return -1.0 if p.y < AXIS_Y - 0.06 else 1.0, Mat.BODY_DARK, -1, PAINT)
	# Bands: back, middle (newer, bright) and the muzzle lip.
	for band: Array in [[-0.26, Mat.BODY_DARK], [-0.44, Mat.TRIM], [-0.705, Mat.BODY_DARK]]:
		var z: float = band[0]
		g.paint(all, func(p: Vector3) -> float:
			return maxf(axis.call(p) - barrel_r(z) - 0.014, absf(p.z - z) - 0.02), band[1])
		for k in 6:
			var a := TAU * k / 6.0
			var r := barrel_r(z) + 0.014
			rivet(g, Vector3(cos(a) * r, AXIS_Y + sin(a) * r, z), Vector3(cos(a), sin(a), 0), c * 0.9)
	# Bore: hollow, the ember glow deep inside.
	g.paint(all, func(p: Vector3) -> float:
		return maxf(axis.call(p) - (barrel_r(p.z) - 0.025), p.z + 0.5), Mat.EMPTY, -1, CARVE)
	# The bore's back wall glows hot; embers speckle the deep half of its walls.
	g.paint(all, func(p: Vector3) -> float:
		return -1.0 if p.z > -0.515 and p.z < -0.48 and axis.call(p) < barrel_r(p.z) - 0.02 else 1.0, Mat.GLOW_CORE, -1, PAINT)
	g.paint(all, func(p: Vector3) -> float:
		var cc := g.cell_of(p)
		var deep := clampf((p.z + 0.66) / 0.16, 0.0, 1.0)
		return -1.0 if p.z < -0.5 and axis.call(p) < barrel_r(p.z) - 0.015 and VoxelSdf.hash3(cc, 23) < 0.25 + deep * 0.7 else 1.0,
		Mat.GLOW, -1, PAINT)
	# The ember strip on top of the barrel (the old model's read), as a molten seam.
	seam(g, PackedVector3Array([Vector3(0, AXIS_Y + 0.11, -0.3), Vector3(0, AXIS_Y + 0.115, -0.42),
		Vector3(0, AXIS_Y + 0.12, -0.58)]), c * 0.7, Mat.GLOW, [Mat.BODY])
	# Foregrip under the barrel for the off hand (WeaponGrip.OFF_HAND), leather over iron.
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.box(p, Vector3(0, AXIS_Y - 0.11, -0.42), Vector3(0.03, 0.03, 0.06), c * 0.5), Mat.BODY_DARK, -1, ADD)
	grip_wrap(g, Vector3(0, AXIS_Y - 0.2, -0.42), Vector3(0, AXIS_Y - 0.11, -0.42), 0.026, 0.04)
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.cylinder(p, Vector3(0, AXIS_Y - 0.215, -0.42), Vector3(0, AXIS_Y - 0.195, -0.42), 0.034, 0.034), Mat.BODY)
