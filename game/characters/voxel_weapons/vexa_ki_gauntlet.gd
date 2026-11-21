extends VoxelWeaponDesign
## Vexa's Ki Gauntlet (docs/lookdev/weapons.md), one fist (the view puts one in
## each hand). Big: a flared wrapped cuff and a gunmetal hand shell. Medium:
## four two-segment finger plates, a thumb plate, the raised back plate, a
## cuff ring. Tiny: diagonal wrap lattice, violet energy slits on every
## knuckle with one hot glint, back-plate rivets, the Crescent Eye inlaid in
## violet (fine cell), a crack stitched with silver wire.

const SHELL_C := Vector3(0, 0.1, 0)
const SHELL_HALF := Vector3(0.16, 0.115, 0.14)


func kind() -> Weapon.Kind:
	return Weapon.Kind.KI_GAUNTLETS


func palette() -> Dictionary:
	return {
		Mat.BODY: Color("#8a8f9c"), Mat.BODY_DARK: Color("#565a66"), Mat.EDGE: Color("#a9aeb9"),
		Mat.TRIM: Color("#6c707c"), Mat.TRIM_DARK: Color("#3e414b"),
		Mat.RIVET: Color("#c4c8d0"), Mat.ENGRAVE: Color("#2a2832"),
		Mat.GRIP: Color("#7a7484"), Mat.GRIP_DARK: Color("#4c4756"), Mat.LEATHER: Color("#2c2a30"),
		Mat.ACCENT: Color("#8a3cf0"), Mat.EMBLEM: Color("#8a3cf0"),
		Mat.GLOW: Color("#b070ff"), Mat.GLOW_CORE: Color("#f2e6ff"),
	}


func build_grids() -> Array[VoxelGrid]:
	return [_fist(), _back_plate()]


func _fist() -> VoxelGrid:
	var all := AABB(Vector3(-0.27, -0.26, -0.2), Vector3(0.54, 0.62, 0.38))
	var g := grid(all)
	var c := g.cell
	# Cuff: an octagonal charcoal sleeve flaring to the hand, bound in slanted ash-lilac
	# wrap bands, each band a cell proud.
	var octagon := func(p: Vector3, r: float) -> float:
		return maxf(maxf(absf(p.x), absf(p.z)), (absf(p.x) + absf(p.z)) * 0.75) - r
	g.paint(all, func(p: Vector3) -> float:
		if p.y < -0.245 or p.y > -0.005:
			return 1.0
		return octagon.call(p, lerpf(0.142, 0.164, (p.y + 0.245) / 0.24)), Mat.GRIP_DARK)
	g.paint(all, func(p: Vector3) -> float:
		if p.y < -0.21 or p.y > -0.045:
			return 1.0
		var band := fposmod((p.y + p.x * 0.3 + 0.245) / 0.046, 1.0)
		if band > 0.6:
			return 1.0
		return octagon.call(p, lerpf(0.142, 0.164, (p.y + 0.245) / 0.24) + c * 0.95), Mat.GRIP, -1, FILL)
	# Cuff rings: a gunmetal band at the hem and at the wrist.
	for y: float in [-0.235, -0.025]:
		g.paint(all, func(p: Vector3) -> float:
			return maxf(octagon.call(p, 0.172), absf(p.y - y) - 0.016), Mat.TRIM)
	# Hand shell: a planar gunmetal block with chamfered edges.
	g.paint(all, func(p: Vector3) -> float:
		var q := (p - SHELL_C).abs()
		var cham := (q.x + q.z) * 0.78 - (SHELL_HALF.x + SHELL_HALF.z) * 0.78 + 0.05
		return maxf(VoxelSdf.box(p, SHELL_C, SHELL_HALF, c), cham), Mat.BODY)
	# The violet energy band across the wrist (front), set into a gunmetal lip.
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.box(p, Vector3(0, -0.002, -0.148), Vector3(0.13, c * 0.5, c * 0.7)), Mat.GLOW, -1, ADD)
	# Raised side plates on the shell, riveted at the corners, with a seam.
	for s: float in [-1.0, 1.0]:
		g.paint(all, func(p: Vector3) -> float:
			var q := p - Vector3((SHELL_HALF.x + c * 0.5) * s, SHELL_C.y + 0.005, 0.005)
			return maxf(maxf(absf(q.x) - c * 0.6, absf(q.y) - 0.085), maxf(absf(q.z) - 0.1, absf(q.y) + absf(q.z) - 0.165)),
			Mat.TRIM, -1, ADD)
		for y: float in [-0.06, 0.06]:
			for z: float in [-0.07, 0.07]:
				rivet(g, Vector3((SHELL_HALF.x + c) * s, SHELL_C.y + y, z), Vector3(s, 0, 0), c * 0.75, Mat.RIVET)
		g.paint(all, func(p: Vector3) -> float:
			var on := absf(p.x * s - SHELL_HALF.x - c) < c * 0.6 and absf(p.y - SHELL_C.y) < 0.07
			return -1.0 if on and absf(p.z - 0.005) < c * 0.5 else 1.0, Mat.TRIM_DARK, -1, PAINT)
	# Finger plates: two segments each, curling forward, a gap line between.
	for i in 4:
		var x := -0.12 + i * 0.08
		var len_k := 1.0 if i in [1, 2] else 0.88
		for seg in 2:
			var y0 := 0.215 + seg * 0.07 * len_k
			var z0 := -0.035 - seg * 0.03
			g.paint(all, func(p: Vector3) -> float:
				return VoxelSdf.box(p, Vector3(x, y0 + 0.032 * len_k, z0), Vector3(0.034, 0.03 * len_k, 0.075 - seg * 0.01), c * 0.8),
				Mat.BODY if seg == 0 else Mat.EDGE, -1, ADD)
		# The knuckle slit: a slanted violet energy slit with a hot glint.
		g.paint(all, func(p: Vector3) -> float:
			var q := p - Vector3(x, 0.245, -0.11)
			var slant := q.y - q.x * 0.5
			return maxf(maxf(absf(slant) - c * 0.5, absf(q.x) - 0.022), absf(q.z + 0.005) - 0.02), Mat.GLOW, -1, FILL)
		g.paint(all, func(p: Vector3) -> float:
			return VoxelSdf.sphere(p, Vector3(x + 0.012, 0.252, -0.12), c * 0.7), Mat.GLOW_CORE, -1, PAINT)
	# Thumb plate, tilted out.
	g.paint(all, func(p: Vector3) -> float:
		var q := Basis(Vector3.BACK, deg_to_rad(25.0)) * (p - Vector3(0.195, 0.08, -0.04))
		return VoxelSdf.box(q, Vector3.ZERO, Vector3(0.045, 0.075, 0.048), c), Mat.BODY, -1, ADD)
	g.paint(all, func(p: Vector3) -> float:
		var q := Basis(Vector3.BACK, deg_to_rad(25.0)) * (p - Vector3(0.195, 0.08, -0.04))
		return -1.0 if absf(q.y) < c * 0.6 else 1.0, Mat.TRIM_DARK, -1, PAINT)
	# Darker plate seams on the shell sides and the palm.
	g.paint(all, func(p: Vector3) -> float:
		return -1.0 if p.z > 0.12 or absf(p.y - 0.1) < c * 0.5 and absf(p.x) > 0.15 else 1.0, Mat.BODY_DARK, -1, PAINT)
	return g


## The raised back plate on the front of the fist at half the cell: the Crescent Eye in violet,
## four rivets, and a hairline crack stitched with silver wire.
func _back_plate() -> VoxelGrid:
	var z0 := SHELL_C.z - SHELL_HALF.z
	var box := AABB(Vector3(-0.12, 0.0, z0 - 0.04), Vector3(0.24, 0.2, 0.04))
	var g := grid(box, 2.0)
	var c := g.cell
	var face := snap(z0)
	g.paint(box, func(p: Vector3) -> float:
		var q := p - Vector3(0, 0.1, 0)
		if p.z > face or p.z < face - c * 3.0:
			return 1.0
		var bevel := (face - p.z) - c * 2.0
		return maxf(maxf(absf(q.x) - 0.1 + maxf(bevel, 0.0), absf(q.y) - 0.082 + maxf(bevel, 0.0)),
			(absf(q.x) + absf(q.y)) * 0.75 - 0.118), Mat.BODY)
	g.paint(box, func(p: Vector3) -> float:
		var q := p - Vector3(0, 0.1, 0)
		return -1.0 if maxf(absf(q.x) / 0.1, absf(q.y) / 0.082) > 0.86 else 1.0, Mat.EDGE, -1, PAINT)
	var front := face - c * 2.5
	mark(g, Vector3(0, 0.1, front), Vector3(-1, 0, 0), Vector3.UP, 0.062, crescent_eye, Mat.EMBLEM, true, Mat.ACCENT)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			rivet(g, Vector3(0.078 * sx, 0.1 + 0.062 * sy, front - c * 0.3), Vector3(0, 0, -1), c * 1.4)
	# The crack across the lower left corner, with two wire staples.
	seam(g, PackedVector3Array([Vector3(0.1, 0.05, front), Vector3(0.07, 0.04, front), Vector3(0.05, 0.025, front)]),
		c * 0.5, Mat.ENGRAVE)
	for x: float in [0.085, 0.06]:
		g.paint(box, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(x, 0.035 + (x - 0.06) * 0.4, front - c * 0.6), Vector3(c * 0.5, c * 1.6, c * 0.6)), Mat.RIVET, -1, FILL)
	return g
