extends VoxelWeaponDesign
## Brann's Titan Hammer (docs/lookdev/weapons.md). Big: a chisel-faceted
## granite head with blackened-iron striking faces, a long haft. Medium: two
## iron bands round the head, iron langets down the haft, two oxblood leather
## grips, the pommel ring. Tiny: band rivets, hammer-peened dimples, molten
## crack seams on the stone and both faces, the Hearth-Mark glowing on both
## sides, a moss tuft with a tiny white flower on top.

const HEAD_C := Vector3(0, 1.0, 0)
const HEAD_HALF := Vector3(0.19, 0.19, 0.3)
const FACE_Z := 0.36


func kind() -> Weapon.Kind:
	return Weapon.Kind.TITAN_HAMMER


func palette() -> Dictionary:
	return {
		Mat.STONE: Color("#6e6a6c"), Mat.CLOTH_DARK: Color("#57545a"),
		Mat.BODY: Color("#46464e"), Mat.BODY_DARK: Color("#35353b"), Mat.EDGE: Color("#6a6a72"),
		Mat.TRIM: Color("#7a7a82"), Mat.TRIM_DARK: Color("#1e1e22"),
		Mat.RIVET: Color("#6a6a72"), Mat.ENGRAVE: Color("#2a170f"), Mat.EMBLEM: Color("#ff4a12"),
		Mat.GRIP: Color("#4a2c1e"), Mat.GRIP_DARK: Color("#2c1a12"), Mat.WOOD: Color("#3a2a20"),
		Mat.STITCH: Color("#6a4630"),
		Mat.ACCENT: Color("#5e7a42"), Mat.CLOTH: Color("#f2efe6"),
		Mat.GLOW: Color("#ff4a12"), Mat.GLOW_CORE: Color("#ffd9a0"),
	}


func matte_roles() -> Array:
	return [Mat.STONE, Mat.CLOTH_DARK, Mat.ACCENT, Mat.CLOTH]


func build_grids() -> Array[VoxelGrid]:
	return [_head(), _haft()]


func _head() -> VoxelGrid:
	var all := AABB(Vector3(-0.26, 0.76, -0.42), Vector3(0.52, 0.5, 0.84))
	var g := grid(all)
	var c := g.cell
	# Granite core: a block with chiselled, uneven chamfers on its long edges.
	g.paint(all, func(p: Vector3) -> float:
		var q := p - HEAD_C
		var chisel := (VoxelSdf.hash3(Vector3i(int(floor(q.z / 0.07)), 0, 0), 5) - 0.5) * 0.02
		var cham := (absf(q.x) + absf(q.y)) * 0.72 - (HEAD_HALF.x + HEAD_HALF.y) * 0.72 + 0.045 + chisel
		return maxf(VoxelSdf.box(q, Vector3.ZERO, HEAD_HALF + Vector3(0, 0, 0.04)), cham), Mat.STONE)
	# Basalt patches and lighter chips on the edges.
	g.paint(all, func(p: Vector3) -> float:
		var cc := g.cell_of(p)
		return -1.0 if VoxelSdf.hash3(Vector3i(cc.x / 4, cc.y / 4, cc.z / 4), 11) < 0.3 else 1.0, Mat.CLOTH_DARK, -1, PAINT)
	# Striking faces: blackened-iron caps, bevelled, peened.
	for s: float in [-1.0, 1.0]:
		g.paint(all, func(p: Vector3) -> float:
			var q := p - Vector3(0, HEAD_C.y, (FACE_Z - 0.035) * s)
			var bevel := maxf(q.z * s - 0.0, 0.0)
			var cham := (absf(q.x) + absf(q.y)) * 0.72 - 0.26 + bevel * 1.2
			return maxf(VoxelSdf.box(q, Vector3.ZERO, Vector3(0.215 - bevel, 0.215 - bevel, 0.04)), cham), Mat.BODY)
		g.paint(all, func(p: Vector3) -> float:
			var q := p - Vector3(0, HEAD_C.y, (FACE_Z - 0.035) * s)
			return -1.0 if q.z * s < -0.025 or maxf(absf(q.x), absf(q.y)) > 0.19 else 1.0, Mat.EDGE, -1, PAINT)
		# Peen dimples: single cells knocked out of the face.
		g.paint(all, func(p: Vector3) -> float:
			var cc := g.cell_of(p)
			var on := p.z * s > FACE_Z - c * 0.5 and absf(p.x) < 0.15 and absf(p.y - HEAD_C.y) < 0.15
			return -1.0 if on and VoxelSdf.hash3(cc, 21) < 0.07 else 1.0, Mat.EMPTY, -1, CARVE)
		# Molten seams radiating across the face.
		for k in 5:
			var a := TAU * k / 5.0 + 0.4 * s
			var pts := PackedVector3Array()
			var r := 0.0
			var wobble := 0.0
			for i in 5:
				pts.append(Vector3(cos(a + wobble) * r, HEAD_C.y + sin(a + wobble) * r, FACE_Z * s))
				r += 0.035 + VoxelSdf.hash3(Vector3i(k, i, int(s)), 3) * 0.015
				wobble += (VoxelSdf.hash3(Vector3i(i, k, 7), 4) - 0.5) * 0.6
			seam(g, pts, c * 0.55, Mat.GLOW)
		g.paint(all, func(p: Vector3) -> float:
			return VoxelSdf.sphere(p, Vector3(0, HEAD_C.y, FACE_Z * s), 0.022), Mat.GLOW_CORE, -1, PAINT)
		# The iron band round the head, with five rivets on each side face.
		g.paint(all, func(p: Vector3) -> float:
			var q := p - HEAD_C
			var cham := (absf(q.x) + absf(q.y)) * 0.72 - (HEAD_HALF.x + HEAD_HALF.y + 0.04) * 0.72 + 0.045
			return maxf(maxf(maxf(absf(q.x) - HEAD_HALF.x - 0.018, absf(q.y) - HEAD_HALF.y - 0.018), cham),
				absf(q.z - 0.2 * s) - 0.032), Mat.BODY_DARK if s < 0.0 else Mat.TRIM)
		for side: float in [-1.0, 1.0]:
			for k in 5:
				var y := HEAD_C.y - 0.14 + k * 0.07
				rivet(g, Vector3((HEAD_HALF.x + 0.018) * side, y, 0.2 * s), Vector3(side, 0, 0), c * 0.9)
	# Cracks across the stone, glowing.
	for s: float in [-1.0, 1.0]:
		seam(g, PackedVector3Array([Vector3(0.19 * s, 1.17, 0.15), Vector3(0.19 * s, 1.1, 0.11),
			Vector3(0.19 * s, 1.06, 0.13), Vector3(0.19 * s, 0.98, 0.08)]), c * 0.5, Mat.GLOW, [Mat.STONE, Mat.CLOTH_DARK])
	seam(g, PackedVector3Array([Vector3(-0.12, 1.19, -0.15), Vector3(-0.05, 1.19, -0.11), Vector3(0.02, 1.19, -0.14),
		Vector3(0.1, 1.19, -0.09)]), c * 0.5, Mat.GLOW, [Mat.STONE, Mat.CLOTH_DARK])
	# The Hearth-Mark stamped deep into both side faces, its floor glowing.
	for s: float in [-1.0, 1.0]:
		mark(g, Vector3(HEAD_HALF.x * s, HEAD_C.y, 0.0), Vector3(0, 0, -s), Vector3.UP, 0.135, hearth_mark,
			Mat.EMBLEM, true, Mat.GLOW)
	# A moss tuft on top with a tiny white flower.
	g.paint(all, func(p: Vector3) -> float:
		var cc := g.cell_of(p)
		var q := p - Vector3(0.08, HEAD_C.y + HEAD_HALF.y, -0.12)
		var blob := VoxelSdf.ellipsoid(q, Vector3.ZERO, Vector3(0.07, 0.025, 0.09))
		return blob + VoxelSdf.hash3(cc, 9) * 0.012, Mat.ACCENT, -1, FILL)
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.sphere(p, Vector3(0.1, HEAD_C.y + HEAD_HALF.y + 0.03, -0.1), c * 1.2), Mat.CLOTH, -1, FILL)
	# The haft socket opening on the underside.
	g.paint(all, func(p: Vector3) -> float:
		return maxf(Vector2(p.x, p.z).length() - 0.07, absf(p.y - (HEAD_C.y - HEAD_HALF.y)) - 0.025), Mat.BODY_DARK, -1, FILL)
	return g


func _haft() -> VoxelGrid:
	var all := AABB(Vector3(-0.1, -0.42, -0.1), Vector3(0.2, 1.22, 0.2))
	var g := grid(all)
	var c := g.cell
	var top := snap(HEAD_C.y - HEAD_HALF.y - 0.025)
	g.paint(all, func(p: Vector3) -> float:
		return maxf(maxf(maxf(absf(p.x), absf(p.z)), (absf(p.x) + absf(p.z)) * 0.74) - 0.05, maxf(-0.26 - p.y, p.y - top)),
		Mat.WOOD)
	# Iron langets down both sides from the head, riveted.
	for s: float in [-1.0, 1.0]:
		g.paint(all, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0.05 * s, top - 0.1, 0), Vector3(c * 0.9, 0.1, 0.022)), Mat.BODY_DARK, -1, ADD)
		for y: float in [top - 0.05, top - 0.15]:
			rivet(g, Vector3(0.06 * s, y, 0), Vector3(s, 0, 0), c * 0.8)
	# Grips: main hand at the origin, off hand higher (WeaponGrip.OFF_HAND), oxblood leather.
	grip_wrap(g, Vector3(0, -0.2, 0), Vector3(0, 0.16, 0), 0.054, 0.06)
	grip_wrap(g, Vector3(0, 0.4, 0), Vector3(0, 0.6, 0), 0.054, 0.06)
	for y: float in [-0.21, 0.17, 0.39, 0.61]:
		g.paint(all, func(p: Vector3) -> float:
			return maxf(Vector2(p.x, p.z).length() - 0.066, absf(p.y - y) - 0.013), Mat.BODY_DARK)
	# Pommel: an iron cap and a heavy ring (the beard-ring motif).
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.box(p, Vector3(0, -0.28, 0), Vector3(0.068, 0.04, 0.068), c), Mat.BODY)
	g.paint(all, func(p: Vector3) -> float:
		return -1.0 if absf(p.y + 0.28) < c * 0.6 else 1.0, Mat.TRIM, -1, PAINT)
	g.paint(all, func(p: Vector3) -> float:
		return VoxelSdf.torus(p, Vector3(0, -0.35, 0), Vector3(1, 0, 0), 0.04, 0.013), Mat.BODY_DARK, -1, ADD)
	return g
