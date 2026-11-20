class_name VexaVoxelDesign
extends VoxelDesign
## Voxel Vexa (docs/lookdev/vexa.md), the shadow rogue, on the voxel kit
## (game/characters/voxel_kit/README.md). Painted in the rest pose of her
## code-built humanoid skeleton (VexaFigure: T-pose, +Z front, her left = +X;
## hips 0.86, neck 1.30, head 1.37, hands at x 0.64).
## Grids: body and mantle at the body cell (2.2 cm, 1/78 of 1.72 m); hood,
## ears, hands, lower legs, holster and chakram at the fine cell; the face at
## the head cell. Each painted part carries a rig tag that decides its skin
## weights (see weights()).

const BODY_CELL := 0.022
const FINE_CELL := 0.011
const HEAD_CELL := 0.0085

enum Mat {
	EMPTY, HOOD, HOOD_DARK, LINING, SUIT, SUIT_SEAM, JACKET, JACKET_EDGE, JACKET_DARK, ZIP,
	WRAP, WRAP_RIDGE, BOOT, SOLE, STEEL, VISOR, VISOR_GLINT, SLIT, GLINT, SKIN, SKIN_SHADE,
	MOUTH, HAIR, HAIR_STREAK, ACCENT, ACCENT_DARK, COIN, CHALK, THREAD, CHAKRAM, CHAKRAM_EDGE,
	ENGRAVE, CRACK, PAD,
}
enum Tag {
	TORSO, ARM_L, ARM_R, LEG_L, LEG_R, MANTLE, HOOD, HEAD, EARS, SASH, COLLAR,
	GAUNT_L, GAUNT_R, THUMB_L, THUMB_R, CHAKRAM,
}
## Per-finger rig tags: FINGER_BASE + side (0 left, 1 right) * 4 + finger.
const FINGER_BASE := 32
const FINGERS: Array[String] = ["Index", "Middle", "Ring", "Little"]

const COLORS := {
	Mat.HOOD: Color("#3a2650"), Mat.HOOD_DARK: Color("#271a37"), Mat.LINING: Color("#8a3cf0"),
	Mat.SUIT: Color("#1a1c24"), Mat.SUIT_SEAM: Color("#2a2d3a"),
	Mat.JACKET: Color("#8a8f9c"), Mat.JACKET_EDGE: Color("#a9aeb9"), Mat.JACKET_DARK: Color("#565a66"),
	Mat.ZIP: Color("#3c3f48"),
	Mat.WRAP: Color("#7a7484"), Mat.WRAP_RIDGE: Color("#8e8898"),
	Mat.BOOT: Color("#2c2a30"), Mat.SOLE: Color("#141316"), Mat.PAD: Color("#3a3840"),
	Mat.STEEL: Color("#bcc0ca"),
	Mat.VISOR: Color("#18141f"), Mat.VISOR_GLINT: Color("#4a4358"),
	Mat.SLIT: Color("#b070ff"), Mat.GLINT: Color("#f2e6ff"),
	Mat.SKIN: Color("#e9c9b8"), Mat.SKIN_SHADE: Color("#c9a497"), Mat.MOUTH: Color("#8e5e5e"),
	Mat.HAIR: Color("#2b2830"), Mat.HAIR_STREAK: Color("#9a86b8"),
	Mat.ACCENT: Color("#8a3cf0"), Mat.ACCENT_DARK: Color("#5a22a8"),
	Mat.COIN: Color("#b07a3a"), Mat.CHALK: Color("#d6d2ca"), Mat.THREAD: Color("#9a86b8"),
	Mat.CHAKRAM: Color("#9ca1ae"), Mat.CHAKRAM_EDGE: Color("#d4d8e0"), Mat.ENGRAVE: Color("#454852"),
	Mat.CRACK: Color("#6e6880"),
}
## Big calm panels: about +-2% value noise, no edge lightening.
const QUIET := [Mat.HOOD, Mat.HOOD_DARK, Mat.SUIT, Mat.JACKET, Mat.LINING, Mat.VISOR]
## Worn spots lighten on exposed edges (leather, metal, wraps, the chakram edge).
const WEARS := [Mat.BOOT, Mat.PAD, Mat.STEEL, Mat.WRAP, Mat.WRAP_RIDGE, Mat.CHAKRAM, Mat.CHAKRAM_EDGE, Mat.COIN]

## Torso slices (y: half width, half depth, centre z), planar between keys:
## wide hips, a 0.22 m waist, a narrow chest, the shoulder chamfer.
const SUIT_KEYS := [
	[0.72, Vector3(0.100, 0.080, 0.0)], [0.76, Vector3(0.150, 0.100, 0.0)],
	[0.85, Vector3(0.158, 0.106, 0.0)], [0.92, Vector3(0.128, 0.090, 0.004)],
	[0.98, Vector3(0.112, 0.082, 0.006)], [1.06, Vector3(0.126, 0.090, 0.008)],
	[1.16, Vector3(0.148, 0.100, 0.012)], [1.24, Vector3(0.166, 0.094, 0.0)],
	[1.28, Vector3(0.150, 0.080, -0.005)], [1.31, Vector3(0.075, 0.062, -0.005)],
]
## Mantle slices: from the hood's cowl out to 1.3x her shoulders.
const MANTLE_KEYS := [
	[1.06, Vector3(0.300, 0.192, -0.01)], [1.20, Vector3(0.286, 0.182, -0.01)],
	[1.29, Vector3(0.256, 0.166, -0.01)], [1.34, Vector3(0.172, 0.142, -0.015)],
	[1.41, Vector3(0.118, 0.118, -0.02)],
]
## Hood outer slices: cowl round the neck, a full dome, closing at the crown.
const HOOD_KEYS := [
	[1.33, Vector3(0.168, 0.158, -0.03)], [1.38, Vector3(0.150, 0.150, -0.03)],
	[1.44, Vector3(0.150, 0.165, -0.025)], [1.52, Vector3(0.162, 0.182, -0.02)],
	[1.60, Vector3(0.168, 0.188, -0.02)], [1.68, Vector3(0.156, 0.174, -0.025)],
	[1.73, Vector3(0.122, 0.138, -0.03)], [1.765, Vector3(0.066, 0.078, -0.035)],
	[1.785, Vector3(0.004, 0.004, -0.035)],
]
const HOOD_THICK := 0.024
## Mantle tatter tips: angle from the front (degrees, + toward her left) and
## tip height; one right tatter is shorter (re-tied).
const TATTERS := [[34.0, 1.10], [92.0, 1.11], [150.0, 1.12], [-34.0, 1.10], [-92.0, 1.165], [-150.0, 1.12]]
const TATTER_VALLEY := 1.25
const TATTER_HALF := 0.5
## The chakram on its back mount: centre, plane normal (top tilted back).
const CHAKRAM_AT := Vector3(0.0, 1.06, -0.226)
const CHAKRAM_R := Vector2(0.124, 0.166)


func build_grids() -> Array[VoxelGrid]:
	return [build_body(), build_mantle(), build_hood(), build_ear(1.0), build_ear(-1.0), build_head(),
		build_hand(1.0), build_hand(-1.0), build_lower_leg(1.0), build_lower_leg(-1.0), build_holster(),
		build_chakram()]


func soft_materials() -> Array:
	return [Mat.SUIT, Mat.HOOD, Mat.SKIN, Mat.HAIR, Mat.JACKET]


func surface_of(mat: int) -> int:
	match mat:
		Mat.STEEL, Mat.CHAKRAM, Mat.CHAKRAM_EDGE, Mat.ENGRAVE, Mat.COIN, Mat.ZIP:
			return Surf.METAL
		Mat.VISOR, Mat.VISOR_GLINT, Mat.CRACK:
			return Surf.GLASS
		Mat.SKIN, Mat.SKIN_SHADE, Mat.MOUTH:
			return Surf.SKIN
		Mat.SLIT, Mat.GLINT:
			return Surf.GLOW
		Mat.HAIR, Mat.HAIR_STREAK:
			return Surf.HAIR
	return Surf.CLOTH


func surface_params() -> Array:
	var params := super.surface_params()
	# The eye slits are her energy: a thin glow, clamped well below a bloom blob.
	params[Surf.GLOW] = {"roughness_value": 0.5, "emission_value": 0.6, "edge_lift": 0.0}
	# Smoked glass: dark, glossy, no emission of its own.
	params[Surf.GLASS] = {"roughness_value": 0.1, "metallic_value": 0.2, "specular_value": 0.8, "emission_value": 0.0}
	return params


func color(mat: int, p: Vector3, c: Vector3i, _n: Vector3, occlusion: float, exposure: float) -> Color:
	var base: Color = COLORS.get(mat, Color.MAGENTA)
	if mat == Mat.HOOD and p.y < 1.3 and p.y > 1.0:
		# The mantle darkens toward the tatter tips.
		base = base.lerp(COLORS[Mat.HOOD_DARK], clampf((1.24 - p.y) / 0.14, 0.0, 1.0) * 0.45)
	return default_color(base, mat, c, occlusion, exposure, mat in QUIET, mat in WEARS,
		mat == Mat.HAIR or mat == Mat.HAIR_STREAK)


# ---------------------------------------------------------------- shapes

static func keyed(keys: Array, y: float) -> Vector3:
	if y <= keys[0][0]:
		return keys[0][1]
	for i in keys.size() - 1:
		if y <= keys[i + 1][0]:
			var t: float = (y - keys[i][0]) / (keys[i + 1][0] - keys[i][0])
			return (keys[i][1] as Vector3).lerp(keys[i + 1][1], t)
	return keys[-1][1]


## Chamfered-box slice (an octagon): flat planes with 45-degree corners.
static func octagon(dx: float, dz: float, rx: float, rz: float, chamfer := 1.42) -> float:
	var ax := absf(dx) / maxf(rx, 0.001)
	var az := absf(dz) / maxf(rz, 0.001)
	return (maxf(maxf(ax, az), (ax + az) / chamfer) - 1.0) * minf(rx, rz)


static func suit_sdf(p: Vector3, grow := 0.0) -> float:
	if p.y < 0.72 or p.y > 1.31:
		return 1.0
	var s := keyed(SUIT_KEYS, p.y)
	return octagon(p.x, p.z - s.z, s.x + grow, s.y + grow)


## Hem height of the mantle at an angle (radians from the front): a sawtooth
## of six tatters.
static func tatter_hem(angle: float) -> float:
	var hem := TATTER_VALLEY
	for t: Array in TATTERS:
		var d := absf(angle_difference(angle, deg_to_rad(t[0])))
		hem = minf(hem, lerpf(t[1], TATTER_VALLEY, clampf(d / TATTER_HALF, 0.0, 1.0)))
	return hem


static func hood_outer(p: Vector3) -> float:
	if p.y < 1.33 or p.y > 1.785:
		return 1.0
	var s := keyed(HOOD_KEYS, p.y)
	return octagon(p.x, p.z - s.z, maxf(s.x, 0.001), maxf(s.y, 0.001), 1.3)


static func hood_inner(p: Vector3) -> float:
	var y := p.y + HOOD_THICK
	if p.y < 1.33 or y > 1.785:
		return 1.0
	var s := keyed(HOOD_KEYS, y)
	return octagon(p.x, p.z - s.z, maxf(s.x - HOOD_THICK, 0.001), maxf(s.y - HOOD_THICK, 0.001), 1.3)


## The hood's face opening, seen from the front: open below the brim, with a
## widow's peak at the centre; returns how far inside (> 0) in metres.
static func face_opening(p: Vector3) -> float:
	if p.z < 0.0:
		return -1.0
	var top := 1.672 - 0.034 * clampf(1.0 - absf(p.x) / 0.06, 0.0, 1.0)
	var half_w := 0.118 * sqrt(clampf((1.71 - p.y) / 0.09, 0.0, 1.0))
	return minf(top - p.y, half_w - absf(p.x))


## Points of a quadratic curve a -> bend -> tip.
static func curve(a: Vector3, bend: Vector3, tip: Vector3, n := 6) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for k in n + 1:
		var u := float(k) / n
		pts.append(a.lerp(bend, u).lerp(bend.lerp(tip, u), u))
	return pts


static func chain_sdf(p: Vector3, pts: PackedVector3Array, r0: float, r1: float) -> float:
	var best := 1e9
	var n := pts.size() - 1
	for i in n:
		best = minf(best, VoxelSdf.capsule(p, pts[i], pts[i + 1], lerpf(r0, r1, float(i) / n),
			lerpf(r0, r1, float(i + 1) / n)))
	return best


## A flat band of cloth along a polyline (width across x, thickness in z),
## ends cut square.
static func ribbon(p: Vector3, pts: PackedVector3Array, half_w: float, half_t: float) -> float:
	var best := 1e9
	var last := pts.size() - 2
	for i in last + 1:
		var a := pts[i]
		var ab := pts[i + 1] - a
		var h := (p - a).dot(ab) / ab.dot(ab)
		if (i == 0 and h < 0.0) or (i == last and h > 1.0):
			continue
		h = clampf(h, 0.0, 1.0)
		var q := p - (a + ab * h)
		best = minf(best, maxf(absf(q.x) - half_w * (1.0 + 0.15 * h), absf(q.z) - half_t))
	return best


# ---------------------------------------------------------------- body grid

func build_body() -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(-0.52, 0.36, -0.2), Vector3(1.04, 1.1, 0.38)), BODY_CELL)
	_legs(g)
	_torso(g)
	_jacket(g)
	_arms(g)
	_sash(g)
	return g


func _legs(g: VoxelGrid) -> void:
	for side: float in [1.0, -1.0]:
		var tag := Tag.LEG_L if side > 0 else Tag.LEG_R
		var box := AABB(Vector3(0.0 if side > 0 else -0.22, 0.36, -0.12), Vector3(0.22, 0.48, 0.24))
		# Leggings: profile slices, thigh to calf; the wraps and boot below
		# are on the fine lower-leg grid.
		g.paint(box, func(p: Vector3):
			if p.y < 0.38 or p.y > 0.83:
				return 1.0
			var r := keyed([[0.38, Vector3(0.050, 0.054, -0.006)], [0.46, Vector3(0.054, 0.058, 0.0)],
				[0.62, Vector3(0.066, 0.070, 0.0)], [0.80, Vector3(0.080, 0.084, 0.002)]], p.y)
			return VoxelSdf.slice(p.x - 0.11 * side, p.z - r.z, r.x, r.y, 2.2), Mat.SUIT, tag)
		# Knee pad: a bevelled plate with a strap above and below.
		var knee := Vector3(0.11 * side, 0.47, 0.054)
		g.paint(box, func(p: Vector3): return VoxelSdf.box(p, knee, Vector3(0.046, 0.05, 0.018), 0.012), Mat.PAD, tag)
		for sy: float in [0.41, 0.53]:
			g.paint(box, func(p: Vector3):
				if absf(p.y - sy) > 0.011:
					return 1.0
				return VoxelSdf.slice(p.x - 0.11 * side, p.z, 0.066, 0.07, 2.2), Mat.BOOT, tag, ADD)
		# Leggings seam down the outside of each leg.
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			return p.x * side > 0.11 + 0.04 and absf(p.z) < BODY_CELL * 0.6 and p.y > 0.42, Mat.SUIT_SEAM, [Mat.SUIT])


func _torso(g: VoxelGrid) -> void:
	var box := AABB(Vector3(-0.2, 0.7, -0.13), Vector3(0.4, 0.62, 0.26))
	g.paint(box, func(p: Vector3): return suit_sdf(p), Mat.SUIT, Tag.TORSO)
	# Neck in the bodysuit.
	g.paint(AABB(Vector3(-0.08, 1.26, -0.08), Vector3(0.16, 0.2, 0.16)), func(p: Vector3):
		return VoxelSdf.capsule(p, Vector3(0, 1.28, -0.004), Vector3(0, 1.45, 0.0), 0.05, 0.048), Mat.SUIT, Tag.TORSO)
	# Bodysuit panel seams: a curved line from the hip to the waist each side.
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		if p.y < 0.76 or p.y > 1.0 or p.z < 0.02:
			return false
		var sx := 0.05 + (1.0 - p.y) * 0.32
		return absf(absf(p.x) - sx) < BODY_CELL * 0.55, Mat.SUIT_SEAM, [Mat.SUIT])


func _jacket(g: VoxelGrid) -> void:
	var box := AABB(Vector3(-0.22, 1.0, -0.14), Vector3(0.44, 0.44, 0.28))
	var hem := 1.02
	# Cropped jacket: the suit slices grown by one cell, from the lower ribs up.
	g.paint(box, func(p: Vector3):
		if p.y < hem:
			return 1.0
		return suit_sdf(p, 0.02), Mat.JACKET, Tag.TORSO)
	# Fold ridge at each side seam, with a dashed stitch line on it.
	for side: float in [1.0, -1.0]:
		g.paint(box, func(p: Vector3):
			if p.y < hem + 0.03 or p.y > 1.2:
				return 1.0
			var s := keyed(SUIT_KEYS, p.y)
			var ridge := absf(p.x * side - (s.x + 0.02 + BODY_CELL * 0.8))
			return maxf(ridge - BODY_CELL * 0.5, absf(p.z - s.z) - BODY_CELL * 0.5), Mat.JACKET, Tag.TORSO, ADD)
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		var s := keyed(SUIT_KEYS, clampf(p.y, 0.72, 1.31))
		return p.y > hem + 0.04 and p.y < 1.21 and absf(p.z - s.z) < BODY_CELL * 0.6 and absf(p.x) > 0.12 \
			and c.y % 2 == 0, Mat.JACKET_DARK, [Mat.JACKET])
	# Hard hem band: the light edge value.
	g.paint_surface(box, func(p: Vector3, _c: Vector3i): return p.y < hem + BODY_CELL, Mat.JACKET_EDGE, [Mat.JACKET])
	# Zip down the front, a touch off-centre (it meets the collar clasp).
	var zx := -0.022
	for zip_mat: int in [Mat.JACKET_EDGE, Mat.ZIP]:
		g.paint_surface(box, func(p: Vector3, c: Vector3i):
			return p.z > 0.06 and absf(p.x - zx) < BODY_CELL * 0.55 and p.y < 1.3 and (zip_mat == Mat.JACKET_EDGE or c.y % 2 == 0),
			zip_mat, [Mat.JACKET, Mat.JACKET_EDGE])
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, Vector3(zx, 1.27, 0.115), Vector3(0.008, 0.016, 0.01)),
		Mat.STEEL, Tag.TORSO, ADD)
	# High collar, open off-centre at the front, light top edge, a steel clasp.
	var collar_box := AABB(Vector3(-0.12, 1.24, -0.12), Vector3(0.24, 0.2, 0.24))
	g.paint(collar_box, func(p: Vector3):
		if p.y < 1.25 or p.y > 1.41 - maxf(p.z, 0.0) * 0.35:
			return 1.0
		if p.z > 0.04 and absf(p.x - zx) < BODY_CELL * 0.5:
			return 1.0
		var flare := (p.y - 1.25) * 0.18
		var outer := VoxelSdf.slice(p.x, p.z + 0.004, 0.09 + flare, 0.088 + flare, 2.4)
		var inner := VoxelSdf.slice(p.x, p.z + 0.004, 0.062 + flare, 0.06 + flare, 2.4)
		return maxf(outer, -inner), Mat.JACKET, Tag.COLLAR)
	g.paint_surface(collar_box, func(p: Vector3, c: Vector3i):
		return g.tags[g.index(c.x, c.y, c.z)] == Tag.COLLAR and p.y > 1.41 - maxf(p.z, 0.0) * 0.35 - BODY_CELL * 1.1,
		Mat.JACKET_EDGE, [Mat.JACKET])
	g.paint_surface(collar_box, func(p: Vector3, c: Vector3i):
		return g.tags[g.index(c.x, c.y, c.z)] == Tag.COLLAR and absf(p.y - 1.30) < BODY_CELL * 0.5 and c.x % 2 == 0,
		Mat.JACKET_DARK, [Mat.JACKET])
	var clasp := Vector3(zx - 0.03, 1.355, 0.092)
	g.paint(collar_box, func(p: Vector3): return VoxelSdf.box(p, clasp, Vector3(0.022, 0.012, 0.012)), Mat.STEEL, Tag.COLLAR)
	# The Crescent Eye on the back, between the shoulder blades (inside the chakram ring).
	var centre := Vector2(0.0, 1.105)
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		if p.z > -0.05:
			return false
		return _crescent_eye((Vector2(p.x, p.y) - centre) / BODY_CELL), Mat.ACCENT, [Mat.JACKET])


## The Crescent Eye in emblem units (one unit per cell): a crescent cupped
## around a diamond pupil, three short rays fanning from its open top.
static func _crescent_eye(q: Vector2) -> bool:
	var r := q.length()
	if r > 2.1 and r < 3.2 and q.y < 0.9:
		return true
	if absf(q.x) + absf(q.y - 0.2) < 1.25:
		return true
	for a: float in [deg_to_rad(45.0), deg_to_rad(90.0), deg_to_rad(135.0)]:
		var dir := Vector2(cos(a), sin(a))
		var along := q.dot(dir)
		if along > 2.6 and along < 4.1 and absf(q.dot(Vector2(-dir.y, dir.x))) < 0.55:
			return true
	return false


func _arms(g: VoxelGrid) -> void:
	var y := 1.27
	for side: float in [1.0, -1.0]:
		var tag := Tag.ARM_L if side > 0 else Tag.ARM_R
		var box := AABB(Vector3(0.1 if side > 0 else -0.5, 1.18, -0.1), Vector3(0.4, 0.18, 0.2))
		# Upper arm in the bodysuit, then the jacket sleeve (an octagon tube)
		# to just past the elbow, a light cuff band.
		g.paint(box, func(p: Vector3):
			var ax := p.x * side
			if ax < 0.12 or ax > 0.47:
				return 1.0
			var r := lerpf(0.046, 0.04, clampf((ax - 0.2) / 0.27, 0.0, 1.0))
			return octagon(p.y - y, p.z, r, r), Mat.SUIT, tag)
		g.paint(box, func(p: Vector3):
			var ax := p.x * side
			if ax < 0.13 or ax > 0.45:
				return 1.0
			var r := lerpf(0.06, 0.052, clampf((ax - 0.2) / 0.25, 0.0, 1.0))
			return octagon(p.y - y + 0.002, p.z, r, r), Mat.JACKET, tag)
		g.paint(box, func(p: Vector3): return VoxelSdf.ellipsoid(p, Vector3(0.175 * side, y - 0.008, 0.0),
			Vector3(0.06, 0.062, 0.064)), Mat.JACKET, tag)
		g.paint_surface(box, func(p: Vector3, _c: Vector3i): return p.x * side > 0.43, Mat.JACKET_EDGE, [Mat.JACKET])
		# Shoulder seam, stitched.
		g.paint_surface(box, func(p: Vector3, c: Vector3i):
			return absf(p.x * side - 0.205) < BODY_CELL * 0.5 and posmod(c.y + c.z, 2) == 0, Mat.JACKET_DARK, [Mat.JACKET])


func _sash(g: VoxelGrid) -> void:
	var box := AABB(Vector3(-0.2, 0.62, -0.14), Vector3(0.42, 0.34, 0.3))
	g.paint(box, func(p: Vector3):
		if p.y < 0.862 or p.y > 0.918:
			return 1.0
		return suit_sdf(p, 0.016), Mat.ACCENT, Tag.TORSO)
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		return p.y > 0.86 and p.y < 0.92 and c.y % 2 == 0 and posmod(c.x + c.z, 3) == 0, Mat.ACCENT_DARK, [Mat.ACCENT])
	# Knot on the left hip, the lucky coin tucked into it.
	var knot := Vector3(0.15, 0.888, 0.07)
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, knot, Vector3(0.03, 0.03, 0.026), 0.01), Mat.ACCENT, Tag.SASH)
	g.paint_surface(box, func(p: Vector3, _c: Vector3i): return absf(p.y - knot.y) < BODY_CELL * 0.5 and absf(p.x - knot.x) < 0.035,
		Mat.ACCENT_DARK, [Mat.ACCENT])
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, knot + Vector3(0.022, 0.024, 0.02), Vector3(0.012, 0.012, 0.008)),
		Mat.COIN, Tag.SASH, ADD)
	# Two short tails down the front of the left thigh (<= 0.25 m).
	var tails := [
		PackedVector3Array([Vector3(0.13, 0.87, 0.112), Vector3(0.134, 0.78, 0.118), Vector3(0.128, 0.668, 0.112)]),
		PackedVector3Array([Vector3(0.172, 0.87, 0.098), Vector3(0.186, 0.785, 0.103), Vector3(0.196, 0.70, 0.094)]),
	]
	for tail: PackedVector3Array in tails:
		g.paint(box, func(p: Vector3): return ribbon(p, tail, 0.019, 0.011), Mat.ACCENT, Tag.SASH, ADD)
		# Notched ends.
		g.paint(box, func(p: Vector3):
			return VoxelSdf.box(p, tail[-1] + Vector3(0, 0.006, 0), Vector3(0.008, 0.016, 0.03)), 0, -1, CARVE)


# ---------------------------------------------------------------- mantle grid

func build_mantle() -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(-0.34, 1.04, -0.24), Vector3(0.68, 0.4, 0.46)), BODY_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	var thick := BODY_CELL * 2.0
	var shell := func(p: Vector3, grow: float) -> float:
		if p.y > 1.41:
			return 1.0
		var s := keyed(MANTLE_KEYS, p.y)
		return octagon(p.x, p.z - s.z, s.x + grow, s.y + grow)
	g.paint(box, func(p: Vector3):
		var angle := atan2(p.x, p.z)
		if p.y < tatter_hem(angle):
			return 1.0
		# Open at the throat so the collar and clasp show.
		if p.z > 0.0 and absf(p.x) < 0.05 + maxf(0.0, 1.38 - p.y) * 0.3:
			return 1.0
		# Bevelled tips: one cell thick over the last few centimetres.
		var t := thick if p.y > tatter_hem(angle) + 0.04 else thick * 0.5
		return maxf(shell.call(p, 0.0), -shell.call(p, -t)), Mat.HOOD, Tag.MANTLE)
	# A centre fold ridge down each tatter, the folds beside it darker.
	for t: Array in TATTERS:
		var a := deg_to_rad(t[0])
		var tip: float = t[1]
		g.paint(box, func(p: Vector3):
			if p.y > 1.28 or p.y < tip + 0.03:
				return 1.0
			var s := keyed(MANTLE_KEYS, p.y)
			var along := Vector2(sin(a), cos(a))
			var q := Vector2(p.x, p.z - s.z)
			var across := absf(q.x * along.y - q.y * along.x)
			var out := octagon(p.x, p.z - s.z, s.x + BODY_CELL, s.y + BODY_CELL)
			return maxf(out, across - BODY_CELL * 0.55), Mat.HOOD, Tag.MANTLE, ADD)
	# The short right tatter's re-tied tip: a thread wrap and a knot.
	var short_a := deg_to_rad(-92.0)
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		var d := absf(angle_difference(atan2(p.x, p.z), short_a))
		return d < 0.2 and absf(p.y - 1.2) < BODY_CELL * 0.5, Mat.THREAD, [Mat.HOOD, Mat.HOOD_DARK])
	var s_tie := keyed(MANTLE_KEYS, 1.2)
	var knot := Vector3(-(s_tie.x + BODY_CELL * 1.2), 1.2, s_tie.z + 0.01)
	g.paint(box, func(p: Vector3): return VoxelSdf.sphere(p, knot, BODY_CELL * 0.6), Mat.THREAD, Tag.MANTLE, ADD)
	# A lining band of accent along the top edge, where it meets the hood.
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		return p.z > 0.0 and absf(p.x) < 0.05 + maxf(0.0, 1.38 - p.y) * 0.3 + BODY_CELL * 0.9, Mat.LINING, [Mat.HOOD])
	return g


# ---------------------------------------------------------------- hood grid

func build_hood() -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(-0.19, 1.32, -0.24), Vector3(0.38, 0.48, 0.44)), FINE_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	var t := Tag.HOOD
	g.paint(box, func(p: Vector3):
		if face_opening(p) > 0.0:
			return 1.0
		# The cowl is open down the front, so the collar shows.
		if p.y < 1.46 and p.z > 0.03 and absf(p.x) < 0.075 + (1.46 - p.y) * 0.5:
			return 1.0
		return maxf(hood_outer(p), -hood_inner(p)), Mat.HOOD, t)
	# Centre seam: a ridge over the crown from the brim to the nape, stitched.
	g.paint(box, func(p: Vector3):
		if absf(p.x) > FINE_CELL * 0.5 or p.y < 1.48:
			return 1.0
		if face_opening(p) > -0.01:
			return 1.0
		return maxf(hood_outer(p) - FINE_CELL, -hood_outer(p)), Mat.HOOD, t, ADD)
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		return absf(absf(p.x) - FINE_CELL * 1.2) < FINE_CELL * 0.55 and p.y > 1.5 and c.y % 2 == 0 and c.z % 2 == 0,
		Mat.HOOD_DARK, [Mat.HOOD])
	# Inner surface: darker, and the accent lining band round the opening.
	g.paint_surface(box, func(p: Vector3, _c: Vector3i): return hood_inner(p) < FINE_CELL * 1.2, Mat.HOOD_DARK, [Mat.HOOD])
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		var f := face_opening(p)
		var cowl := p.y < 1.46 and p.z > 0.0 and absf(p.x) < 0.075 + (1.46 - p.y) * 0.5 + FINE_CELL * 1.1
		return p.z > -0.02 and ((f > -FINE_CELL * 2.2 and f <= 0.0) or cowl), Mat.LINING, [Mat.HOOD, Mat.HOOD_DARK])
	return g


## A hood ear point: a flat tapered blade rising from the hood top, swept back
## 35 degrees and splayed 20, with one fold ridge; the left one carries the
## silenced bell.
func build_ear(side: float) -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(0.02 if side > 0 else -0.29, 1.64, -0.33), Vector3(0.27, 0.37, 0.4)), FINE_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	var base := Vector3(0.085 * side, 1.705, -0.05)
	var dir := Vector3(sin(deg_to_rad(20.0)) * side, cos(deg_to_rad(35.0)), -sin(deg_to_rad(35.0))).normalized()
	var length := 0.33
	var tip := base + dir * length + Vector3(0.0, 0.02, -0.03)
	var bend := base + dir * length * 0.55 + Vector3(0.0, 0.025, 0.012)
	var pts := curve(base, bend, tip, 8)
	# Blade frame: width roughly across the head (x), thickness front-back.
	var thick_axis := Vector3(0.0, sin(deg_to_rad(35.0)), cos(deg_to_rad(35.0)))
	var blade := func(p: Vector3, grow: float) -> float:
		var best := 1e9
		for i in pts.size() - 1:
			var a := pts[i]
			var ab := pts[i + 1] - a
			var h := clampf((p - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
			var u := (float(i) + h) / (pts.size() - 1)
			var q := p - (a + ab * h)
			var n := thick_axis
			var w := lerpf(0.07, 0.006, pow(u, 0.85)) + grow
			var d := lerpf(0.04, 0.007, u) + grow
			var across := q - n * q.dot(n)
			best = minf(best, Vector2(across.length() / w, q.dot(n) / d).length() - 1.0)
		return best * 0.02
	g.paint(box, func(p: Vector3): return blade.call(p, 0.0), Mat.HOOD, Tag.EARS)
	# Fold ridge up the front face of the point.
	g.paint(box, func(p: Vector3):
		var best := 1e9
		for i in pts.size() - 2:
			var a := pts[i] + thick_axis * lerpf(0.036, 0.008, float(i) / (pts.size() - 1))
			var b := pts[i + 1] + thick_axis * lerpf(0.036, 0.008, float(i + 1) / (pts.size() - 1))
			best = minf(best, VoxelSdf.capsule(p, a, b, FINE_CELL * 0.75, FINE_CELL * 0.6))
		return best, Mat.HOOD, Tag.EARS, ADD)
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		return (p - base).dot(thick_axis) < -0.012, Mat.HOOD_DARK, [Mat.HOOD])
	# The rim of the point's inner face in accent lining.
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		var q := p - base
		var along := q.dot(dir) / length
		var across := (q - dir * q.dot(dir) - thick_axis * q.dot(thick_axis)).length()
		return along < 0.7 and along > 0.08 and q.dot(thick_axis) > 0.004 and across < 0.022 * (1.0 - along),
		Mat.LINING, [Mat.HOOD])
	if side > 0:
		# A tiny bell hanging under the tip, silenced with a wrap of thread.
		var bell := pts[6] + Vector3(0.0, -0.028, -0.012)
		g.paint(box, func(p: Vector3): return VoxelSdf.capsule(p, pts[6], bell, 0.004, 0.004), Mat.THREAD, Tag.EARS, ADD)
		g.paint(box, func(p: Vector3): return VoxelSdf.sphere(p, bell + Vector3(0, -0.012, 0), 0.017), Mat.STEEL, Tag.EARS, ADD)
		g.paint(box, func(p: Vector3):
			return VoxelSdf.sphere(p, bell + Vector3(0, -0.012, 0), 0.02) if absf(p.y - bell.y + 0.012) < FINE_CELL * 0.6 else 1.0,
			Mat.THREAD, Tag.EARS, FILL)
	return g


# ---------------------------------------------------------------- head grid

func build_head() -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(-0.17, 1.40, -0.15), Vector3(0.34, 0.34, 0.33)), HEAD_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	var t := Tag.HEAD
	g.paint(box, func(p: Vector3):
		var cranium := VoxelSdf.ellipsoid(p, Vector3(0, 1.585, -0.008), Vector3(0.112, 0.128, 0.122))
		var jaw := VoxelSdf.ellipsoid(p, Vector3(0, 1.505, 0.018), Vector3(0.08, 0.072, 0.094))
		return VoxelSdf.smooth_union(cranium, jaw, 0.035), Mat.SKIN, t)
	# Nose tip under the visor.
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, Vector3(0, 1.512, 0.118), Vector3(0.005, 0.01, 0.008)), Mat.SKIN, t, ADD)
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		return p.z > 0.1 and absf(p.x) < 0.012 and p.y > 1.494 and p.y < 1.502, Mat.SKIN_SHADE, [Mat.SKIN])
	# The smirk: a short line, her right corner ticked up, a dimple.
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		if p.z < 0.07:
			return false
		var line := p.x > -0.01 and p.x < 0.016 and absf(p.y - 1.47) < 0.0038
		var corner := p.x <= -0.008 and p.x > -0.026 and absf(p.y - (1.47 + (-0.008 - p.x) * 0.5)) < 0.0038
		return line or corner, Mat.MOUTH, [Mat.SKIN])
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		return p.z > 0.06 and Vector2(p.x + 0.032, p.y - 1.478).length() < 0.005, Mat.SKIN_SHADE, [Mat.SKIN])
	# Cheek shade under the visor edge.
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		return p.z > 0.04 and p.y > 1.512 and p.y < 1.53 and absf(p.x) > 0.03, Mat.SKIN_SHADE, [Mat.SKIN])
	_hair(g, box)
	_visor(g, box)
	return g


func _hair(g: VoxelGrid, box: AABB) -> void:
	g.paint(box, func(p: Vector3):
		if p.y < 1.585 and p.z > -0.04:
			return 1.0
		return VoxelSdf.ellipsoid(p, Vector3(0, 1.598, -0.012), Vector3(0.122, 0.134, 0.132)), Mat.HAIR, Tag.HEAD)
	# Fringe: three bent locks over the brow, and the lilac-streaked lock
	# escaping the hood on her right, down past the visor.
	var locks := [
		[Vector3(0.03, 1.668, 0.10), Vector3(0.012, 1.628, 0.134), Vector3(-0.024, 1.596, 0.13), 0.021, 0.008],
		[Vector3(-0.035, 1.672, 0.098), Vector3(-0.058, 1.626, 0.126), Vector3(-0.084, 1.594, 0.118), 0.019, 0.008],
		[Vector3(0.078, 1.662, 0.088), Vector3(0.086, 1.624, 0.112), Vector3(0.072, 1.594, 0.124), 0.017, 0.007],
	]
	for l: Array in locks:
		var pts := curve(l[0], l[1], l[2])
		var lb := AABB(l[0], Vector3.ZERO).expand(l[1]).expand(l[2]).grow(0.025)
		g.paint(lb, func(p: Vector3): return chain_sdf(p, pts, l[3], l[4]), Mat.HAIR, Tag.HEAD)
	var stray := curve(Vector3(-0.075, 1.655, 0.112), Vector3(-0.118, 1.585, 0.15), Vector3(-0.108, 1.494, 0.13))
	var sb := AABB(stray[0], Vector3.ZERO).expand(stray[3]).expand(stray[6]).grow(0.03)
	g.paint(sb, func(p: Vector3): return chain_sdf(p, stray, 0.019, 0.008), Mat.HAIR, Tag.HEAD)
	var streak := PackedVector3Array()
	for q in stray:
		streak.append(q + Vector3(-0.004, 0.0, 0.009))
	g.paint(sb, func(p: Vector3): return chain_sdf(p, streak, 0.008, 0.004), Mat.HAIR_STREAK, Tag.HEAD, PAINT)


func _visor(g: VoxelGrid, head_box: AABB) -> void:
	var t := Tag.HEAD
	var box := head_box.intersection(AABB(Vector3(-0.16, 1.5, -0.04), Vector3(0.32, 0.12, 0.2)))
	var axis := Vector3(0, 0, -0.012)
	var ro := 0.142
	var ri := 0.124
	var mid := func(x: float) -> float: return 1.558 + absf(x) * 0.07
	var in_band := func(p: Vector3) -> bool:
		var a := atan2(p.x, p.z - axis.z)
		return absf(a) < deg_to_rad(72.0) and absf(p.y - mid.call(p.x)) < 0.03 - absf(a) * 0.006
	var radial := func(p: Vector3) -> float: return Vector2(p.x, p.z - axis.z).length()
	g.paint(box, func(p: Vector3):
		if not in_band.call(p):
			return 1.0
		var r: float = radial.call(p)
		return maxf(r - ro, ri - r), Mat.VISOR, t)
	# A specular glint row along the top edge.
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		var a := atan2(p.x, p.z - axis.z)
		return absf(p.y - (mid.call(p.x) + 0.024)) < HEAD_CELL * 0.5 and a > -0.9 and a < 0.2, Mat.VISOR_GLINT, [Mat.VISOR])
	# Two slanted eye slits, rising toward the outside: a recessed groove
	# with the glow at its floor and a hot glint at the outer end.
	for s: float in [1.0, -1.0]:
		var in_slit := func(p: Vector3) -> bool:
			var dx := p.x * s - 0.05
			if absf(dx) > 0.028:
				return false
			var cy: float = mid.call(p.x) - 0.002 + dx * 0.32
			return absf(p.y - cy) < 0.0075 * sqrt(1.0 - absf(dx) / 0.03) + 0.002
		g.paint(box, func(p: Vector3): return -1.0 if in_slit.call(p) else 1.0, Mat.SLIT, t, PAINT)
		g.paint(box, func(p: Vector3):
			return -1.0 if in_slit.call(p) and radial.call(p) > ro - HEAD_CELL else 1.0, 0, -1, CARVE)
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			return in_slit.call(p) and p.x * s > 0.064 and p.x * s < 0.074, Mat.GLINT, [Mat.SLIT])
	# Hairline crack across the left slit, stapled with two silver wire stitches.
	var c0 := Vector2(0.024, 1.578)
	var c1 := Vector2(0.088, 1.551)
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		var q := Vector2(p.x, p.y)
		var h := clampf((q - c0).dot(c1 - c0) / (c1 - c0).length_squared(), 0.0, 1.0)
		return p.x > 0.0 and q.distance_to(c0.lerp(c1, h)) < HEAD_CELL * 0.6, Mat.CRACK, [Mat.VISOR, Mat.SLIT, Mat.VISOR_GLINT])
	var normal := (c1 - c0).orthogonal().normalized()
	for h: float in [0.3, 0.7]:
		var at := c0.lerp(c1, h)
		var a3 := Vector3(at.x - normal.x * 0.009, at.y - normal.y * 0.009, 0.0)
		var b3 := Vector3(at.x + normal.x * 0.009, at.y + normal.y * 0.009, 0.0)
		var za := sqrt(maxf(pow(ro + 0.005, 2) - a3.x * a3.x, 0.0)) + axis.z
		var zb := sqrt(maxf(pow(ro + 0.005, 2) - b3.x * b3.x, 0.0)) + axis.z
		a3.z = za
		b3.z = zb
		g.paint(box, func(p: Vector3): return VoxelSdf.capsule(p, a3, b3, 0.0055, 0.0055), Mat.STEEL, t, ADD)
	# Hinge tabs at the temples, four rivets each.
	for s: float in [1.0, -1.0]:
		var hinge := Vector3(0.124 * s, 1.566, 0.02)
		g.paint(box, func(p: Vector3): return VoxelSdf.box(p, hinge, Vector3(0.014, 0.024, 0.026), 0.003), Mat.VISOR, t)
		for k in 4:
			var at := hinge + Vector3(0.016 * s, 0.012 * (1 if k < 2 else -1), 0.012 * (1 if k % 2 == 0 else -1))
			g.paint(box, func(p: Vector3): return VoxelSdf.sphere(p, at, HEAD_CELL * 0.62), Mat.STEEL, t, ADD)


# ---------------------------------------------------------------- hand grids

func build_hand(side: float) -> VoxelGrid:
	var x0 := 0.44 * side
	var x1 := 0.93 * side
	var g := VoxelGrid.new(AABB(Vector3(minf(x0, x1), 1.19, -0.11), Vector3(0.49, 0.16, 0.22)), FINE_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	var prefix := "Left" if side > 0 else "Right"
	var tag := Tag.GAUNT_L if side > 0 else Tag.GAUNT_R
	var thumb_tag := Tag.THUMB_L if side > 0 else Tag.THUMB_R
	var y := 1.27
	# Forearm in the bodysuit under wraps: wrapped bands with diagonal step
	# ridges (a spiral one way, painted crossings the other: a lattice).
	g.paint(box, func(p: Vector3):
		var ax := p.x * side
		if ax < 0.44 or ax > 0.66:
			return 1.0
		var r := lerpf(0.043, 0.034, clampf((ax - 0.46) / 0.18, 0.0, 1.0))
		return VoxelSdf.slice(p.y - y, p.z, r, r * 1.05, 2.2), Mat.WRAP, tag)
	g.paint(box, func(p: Vector3):
		var ax := p.x * side
		if ax < 0.47 or ax > 0.63:
			return 1.0
		var r := lerpf(0.043, 0.034, clampf((ax - 0.46) / 0.18, 0.0, 1.0)) + FINE_CELL
		var u := atan2(p.z, p.y - y) / TAU
		var band := fposmod((ax + u * 0.03) / 0.032, 1.0) < 0.36
		return VoxelSdf.slice(p.y - y, p.z, r, r * 1.05, 2.2) if band else 1.0, Mat.WRAP_RIDGE, tag, ADD)
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		var ax := p.x * side
		var u := atan2(p.z, p.y - y) / TAU
		return ax > 0.47 and ax < 0.63 and fposmod((ax - u * 0.03) / 0.032, 1.0) < 0.2, Mat.WRAP_RIDGE, [Mat.WRAP])
	# Elbow edge of the wraps tucked under the jacket cuff.
	g.paint(box, func(p: Vector3):
		var ax := p.x * side
		if ax < 0.44 or ax > 0.465:
			return 1.0
		return VoxelSdf.slice(p.y - y, p.z, 0.05, 0.052, 2.2), Mat.JACKET_EDGE, tag)
	# Palm: slim, wrapped across the knuckles, a small steel Ki plate on the back.
	var palm := Vector3(0.69 * side, y, 0.0)
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, palm, Vector3(0.05, 0.018, 0.046), 0.012), Mat.SKIN, tag)
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, palm + Vector3(0.005 * side, 0.0, 0.0), Vector3(0.042, 0.023, 0.05), 0.01),
		Mat.WRAP, tag)
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		return p.y > y and posmod(c.x * int(side) + c.z, 3) == 0, Mat.WRAP_RIDGE, [Mat.WRAP])
	var plate := palm + Vector3(-0.004 * side, 0.025, 0.0)
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, plate, Vector3(0.026, 0.006, 0.032), 0.003), Mat.STEEL, tag)
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, plate + Vector3(0, 0.006, 0), Vector3(0.016, 0.004, 0.005)),
		Mat.SLIT, tag, ADD)
	for k in 4:
		var at := plate + Vector3(0.02 * side * (1 if k < 2 else -1), 0.006, 0.026 * (1 if k % 2 == 0 else -1))
		g.paint(box, func(p: Vector3): return VoxelSdf.sphere(p, at, FINE_CELL * 0.6), Mat.STEEL, tag, ADD)
	# Fingers: slim, wrapped on the first segment, bare beyond, a lighter
	# worn knuckle wrap on each.
	for f in 4:
		var chain := PackedVector3Array()
		for part: String in ["Proximal", "Intermediate", "Distal"]:
			chain.append(rest[StringName(prefix + FINGERS[f] + part)])
		chain.append(chain[2] + (chain[2] - chain[1]) * 0.9)
		var ftag := FINGER_BASE + (0 if side > 0 else 4) + f
		var r0 := 0.0125 if f < 3 else 0.011
		for i in 3:
			var a := chain[i]
			var b := chain[i + 1]
			g.paint(box, func(p: Vector3): return VoxelSdf.capsule(p, a, b, r0 - i * 0.0008, r0 - (i + 1) * 0.0008),
				Mat.SKIN if i > 0 else Mat.WRAP, ftag)
		var knuckle := chain[0] + Vector3(0.0, 0.01, 0.0)
		g.paint(box, func(p: Vector3): return VoxelSdf.box(p, knuckle, Vector3(0.009, 0.006, 0.011), 0.003),
			Mat.WRAP_RIDGE, ftag, ADD)
	# Thumb: modelled tucked along the index finger's first segment, rigid
	# with the hand (the clips splay the thumb bones).
	var root: Vector3 = rest[StringName(prefix + "ThumbMetacarpal")] + Vector3(0.0, -0.006, 0.01)
	var mid := Vector3(0.718 * side, y - 0.018, 0.058)
	var tip := Vector3(0.758 * side, y - 0.022, 0.052)
	g.paint(box, func(p: Vector3): return minf(VoxelSdf.capsule(p, root, mid, 0.016, 0.013),
		VoxelSdf.capsule(p, mid, tip, 0.013, 0.011)), Mat.SKIN, thumb_tag)
	g.paint(box, func(p: Vector3): return VoxelSdf.capsule(p, root, mid, 0.018, 0.015), Mat.WRAP, thumb_tag, PAINT)
	return g


# ---------------------------------------------------------- lower-leg grids

## Shin wraps (a diagonal lattice of step ridges) and the split-toe soft
## boot with its pointed toe; the left shin carries the chalk tally.
func build_lower_leg(side: float) -> VoxelGrid:
	var bx := 0.11 * side
	var g := VoxelGrid.new(AABB(Vector3(bx - 0.085, -0.004, -0.1), Vector3(0.17, 0.45, 0.33)), FINE_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	var tag := Tag.LEG_L if side > 0 else Tag.LEG_R
	var shin := func(y: float) -> Vector3:
		return keyed([[0.14, Vector3(0.04, 0.042, -0.004)], [0.24, Vector3(0.046, 0.05, -0.008)],
			[0.34, Vector3(0.056, 0.06, -0.01)], [0.43, Vector3(0.054, 0.058, -0.004)]], y)
	g.paint(box, func(p: Vector3):
		if p.y < 0.14 or p.y > 0.43:
			return 1.0
		var r: Vector3 = shin.call(p.y)
		return VoxelSdf.slice(p.x - bx, p.z - r.z, r.x, r.y, 2.2), Mat.WRAP, tag)
	g.paint(box, func(p: Vector3):
		if p.y < 0.17 or p.y > 0.42:
			return 1.0
		var r: Vector3 = shin.call(p.y)
		var u := atan2(p.x - bx, p.z - r.z) / TAU
		if fposmod((p.y + u * 0.05) / 0.05, 1.0) > 0.3:
			return 1.0
		return VoxelSdf.slice(p.x - bx, p.z - r.z, r.x + FINE_CELL, r.y + FINE_CELL, 2.2), Mat.WRAP_RIDGE, tag, ADD)
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		var r: Vector3 = shin.call(clampf(p.y, 0.14, 0.43))
		var u := atan2(p.x - bx, p.z - r.z) / TAU
		return p.y > 0.17 and p.y < 0.42 and fposmod((p.y - u * 0.05) / 0.05, 1.0) < 0.16, Mat.WRAP_RIDGE, [Mat.WRAP])
	if side > 0:
		# Chalk tally on the left shin: seven strokes, the last crossed through.
		g.paint_surface(box, func(p: Vector3, c: Vector3i):
			if p.z < 0.0:
				return false
			var r: Vector3 = shin.call(clampf(p.y, 0.14, 0.43))
			var u := atan2(p.x - bx, p.z - r.z)
			if u < -0.35 or u > 1.25:
				return false
			var k := int(floor((u + 0.35) / 0.2))
			var stroke := posmod(c.x + c.z, 2) == 0 and absf(fposmod((u + 0.35) / 0.2, 1.0) - 0.5) < 0.3
			var on := k < 7 and stroke and p.y > 0.25 and p.y < 0.3
			var cross := absf(p.y - 0.275 - (u - 0.95) * 0.04) < FINE_CELL * 0.6 and u > 0.8 and u < 1.15
			return on or cross, Mat.CHALK, [Mat.WRAP, Mat.WRAP_RIDGE])
	# Soft boot: planar upper narrowing to a pointed toe, a turned cuff, a
	# thin sole and the toe split.
	var half_w := func(z: float) -> float:
		return 0.042 if z < 0.06 else lerpf(0.042, 0.01, clampf((z - 0.06) / 0.16, 0.0, 1.0))
	var top := func(z: float) -> float:
		if z < 0.0:
			return 0.15
		if z < 0.08:
			return lerpf(0.15, 0.075, z / 0.08)
		return lerpf(0.075, 0.036, clampf((z - 0.08) / 0.14, 0.0, 1.0))
	g.paint(box, func(p: Vector3):
		if p.z < -0.066 or p.z > 0.222 or p.y < 0.016:
			return 1.0
		var w: float = half_w.call(p.z)
		var h: float = top.call(p.z)
		var heel := 0.0 if p.z > -0.04 else (-0.04 - p.z) * 0.6
		return maxf(absf(p.x - bx) - w + heel, p.y - h), Mat.BOOT, tag)
	g.paint(box, func(p: Vector3):
		if p.y < 0.06 or p.y > 0.2:
			return 1.0
		return VoxelSdf.slice(p.x - bx, p.z + 0.008, 0.047, 0.05, 2.2), Mat.BOOT, tag)
	g.paint(box, func(p: Vector3):
		if p.y < 0.175 or p.y > 0.205:
			return 1.0
		return VoxelSdf.slice(p.x - bx, p.z + 0.008, 0.054, 0.058, 2.2), Mat.PAD, tag)
	g.paint(box, func(p: Vector3):
		if p.z < -0.072 or p.z > 0.228 or p.y > 0.016 or p.y < 0.0:
			return 1.0
		return absf(p.x - bx) - half_w.call(p.z) - 0.005, Mat.SOLE, tag)
	# Toe split: the big toe on the inside.
	var split_x := bx - 0.008 * side
	g.paint(box, func(p: Vector3):
		return -1.0 if p.z > 0.13 and p.y > 0.016 and absf(p.x - split_x) < FINE_CELL * 0.55 else 1.0, 0, -1, CARVE)
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		return p.z > 0.15 and p.y > 0.03, Mat.PAD, [Mat.BOOT])
	# A seam up the instep and a strap round the ankle.
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		return absf(p.x - bx) < FINE_CELL * 0.55 and p.z > 0.0 and p.y > 0.05 and c.y % 2 == 0, Mat.SOLE, [Mat.BOOT])
	g.paint(box, func(p: Vector3):
		if absf(p.y - 0.115) > 0.008:
			return 1.0
		return VoxelSdf.slice(p.x - bx, p.z + 0.008, 0.05, 0.054, 2.2), Mat.PAD, tag, ADD)
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, Vector3(bx + 0.05 * side, 0.115, 0.0), Vector3(0.006, 0.012, 0.012)),
		Mat.STEEL, tag, ADD)
	return g


# ------------------------------------------------------------- holster grid

## Throwing-pin holster on the right thigh: a strap, a pouch with three slots
## and three pins with ring ends.
func build_holster() -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(-0.23, 0.55, -0.1), Vector3(0.16, 0.2, 0.2)), FINE_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	var cx := -0.11
	var t := Tag.LEG_R
	g.paint(box, func(p: Vector3):
		if absf(p.y - 0.62) > 0.014:
			return 1.0
		var outer := VoxelSdf.slice(p.x - cx, p.z, 0.088, 0.09, 2.2)
		var inner := VoxelSdf.slice(p.x - cx, p.z, 0.07, 0.072, 2.2)
		return maxf(outer, -inner), Mat.BOOT, t)
	var pouch := Vector3(-0.2, 0.635, 0.0)
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, pouch, Vector3(0.014, 0.045, 0.044), 0.004), Mat.BOOT, t)
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, Vector3(-0.188, 0.635, 0.0), Vector3(0.006, 0.02, 0.04)), Mat.PAD, t)
	for k in 3:
		var z := (k - 1) * 0.026
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			return p.x < -0.205 and absf(p.z - z) < FINE_CELL * 0.6 and p.y > 0.6, Mat.SOLE, [Mat.BOOT])
		var pin := Vector3(-0.2, 0.69, z)
		g.paint(box, func(p: Vector3): return VoxelSdf.box(p, pin + Vector3(0, -0.01, 0), Vector3(0.0055, 0.022, 0.0055)),
			Mat.STEEL, t, ADD)
		g.paint(box, func(p: Vector3):
			var q := p - (pin + Vector3(0, 0.022, 0))
			return maxf(maxf(absf(q.x) - 0.0055, absf(q.y) - 0.0165), absf(q.z) - 0.0165) if maxf(absf(q.y), absf(q.z)) > 0.006 else 1.0,
			Mat.STEEL, t, ADD)
	return g


# ------------------------------------------------------------ chakram grid

## The Orbit Chakram on its back mount: a flat ring with bevelled light edges,
## four swept blade teeth, a grip bar engraved with a small Crescent Eye, two
## leather mount brackets to the jacket.
func build_chakram() -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(-0.25, 0.8, -0.26), Vector3(0.5, 0.52, 0.16)), FINE_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	var t := Tag.CHAKRAM
	var n := Vector3(0.0, 0.17, -0.985).normalized()
	var ux := Vector3.RIGHT
	var uy := n.cross(ux).normalized() * -1.0
	var local := func(p: Vector3) -> Vector3:
		var q := p - CHAKRAM_AT
		return Vector3(q.dot(ux), q.dot(uy), q.dot(n))
	g.paint(box, func(p: Vector3):
		var l: Vector3 = local.call(p)
		var r := Vector2(l.x, l.y).length()
		return maxf(maxf(r - CHAKRAM_R.y, CHAKRAM_R.x - r), absf(l.z) - 0.011), Mat.CHAKRAM, t)
	for k in 4:
		var a := PI / 4.0 + PI / 2.0 * k
		var tri := PackedVector2Array([
			Vector2(cos(a - 0.3), sin(a - 0.3)) * (CHAKRAM_R.y - 0.01),
			Vector2(cos(a + 0.12), sin(a + 0.12)) * (CHAKRAM_R.y - 0.01),
			Vector2(cos(a + 0.2), sin(a + 0.2)) * (CHAKRAM_R.y + 0.062),
		])
		var tooth_at := CHAKRAM_AT + (ux * cos(a) + uy * sin(a)) * (CHAKRAM_R.y + 0.01)
		var tb := AABB(tooth_at - Vector3(0.08, 0.08, 0.03), Vector3(0.16, 0.16, 0.06))
		g.paint(tb, func(p: Vector3):
			var l: Vector3 = local.call(p)
			if absf(l.z) > 0.0075:
				return 1.0
			return -1.0 if Geometry2D.is_point_in_polygon(Vector2(l.x, l.y), tri) else 1.0, Mat.CHAKRAM, t)
		# The leading edge of each tooth: a light bevel.
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			var l: Vector3 = local.call(p)
			var q := Vector2(l.x, l.y)
			if q.length() < CHAKRAM_R.y:
				return false
			var e0 := tri[1]
			var e1 := tri[2]
			var h := clampf((q - e0).dot(e1 - e0) / (e1 - e0).length_squared(), 0.0, 1.0)
			return q.distance_to(e0.lerp(e1, h)) < FINE_CELL * 1.2, Mat.CHAKRAM_EDGE, [Mat.CHAKRAM])
	# Bevelled outer and inner rims; an engraved groove ring.
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		var l: Vector3 = local.call(p)
		var r := Vector2(l.x, l.y).length()
		return r > CHAKRAM_R.y - FINE_CELL * 1.1 and r < CHAKRAM_R.y + 0.002 or r < CHAKRAM_R.x + FINE_CELL * 0.9,
		Mat.CHAKRAM_EDGE, [Mat.CHAKRAM])
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		var l: Vector3 = local.call(p)
		var r := Vector2(l.x, l.y).length()
		return absf(r - (CHAKRAM_R.x + CHAKRAM_R.y) * 0.5) < FINE_CELL * 0.5 and absf(l.z) > 0.006, Mat.ENGRAVE, [Mat.CHAKRAM])
	# Grip bar across the lower inside, leather-wrapped ends, a small
	# engraved Crescent Eye in the middle.
	g.paint(box, func(p: Vector3):
		var l: Vector3 = local.call(p)
		return maxf(maxf(absf(l.x) - 0.1, absf(l.y + 0.09) - 0.014), absf(l.z) - 0.009), Mat.CHAKRAM, t)
	g.paint(box, func(p: Vector3):
		var l: Vector3 = local.call(p)
		return maxf(maxf(absf(absf(l.x) - 0.06) - 0.026, absf(l.y + 0.09) - 0.017), absf(l.z) - 0.012), Mat.BOOT, t)
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		var l: Vector3 = local.call(p)
		return absf(absf(l.x) - 0.06) < 0.026 and posmod(c.x + c.y, 3) == 0, Mat.PAD, [Mat.BOOT])
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		var l: Vector3 = local.call(p)
		if l.z > -0.005 or absf(l.x) > 0.03:
			return false
		return _crescent_eye(Vector2(l.x, l.y + 0.09) / (FINE_CELL * 0.62)), Mat.ENGRAVE, [Mat.CHAKRAM])
	# Mount brackets at 3 and 9 o'clock, leather straps with a steel clamp.
	for s: float in [1.0, -1.0]:
		var at := CHAKRAM_AT + ux * (CHAKRAM_R.y - 0.02) * s
		g.paint(box, func(p: Vector3):
			return VoxelSdf.box(p, Vector3(at.x, at.y, -0.17), Vector3(0.012, 0.016, 0.06)), Mat.BOOT, t, ADD)
		g.paint(box, func(p: Vector3): return VoxelSdf.box(p, at + n * 0.002, Vector3(0.016, 0.02, 0.016), 0.003), Mat.STEEL, t, FILL)
	return g


# ----------------------------------------------------------------- weights

func weights(tag: int, p: Vector3) -> Array:
	var w := {}
	if tag >= FINGER_BASE:
		var k := tag - FINGER_BASE
		_finger_w(p, w, "Left" if k < 4 else "Right", FINGERS[k % 4])
		return _pack(w)
	match tag:
		Tag.TORSO, Tag.COLLAR:
			_torso_w(p, w, tag)
		Tag.ARM_L, Tag.ARM_R:
			_arm_w(p, w, "Left" if tag == Tag.ARM_L else "Right")
		Tag.LEG_L, Tag.LEG_R:
			_leg_w(p, w, "Left" if tag == Tag.LEG_L else "Right")
		Tag.MANTLE:
			# UpperChest, the outer tatters 60% on their shoulder so a raised arm lifts them.
			var k := 0.6 * smoothstep(0.08, 0.27, absf(p.x))
			var neck := 0.25 * smoothstep(1.34, 1.40, p.y)
			_add(w, &"UpperChest", 1.0 - k - neck)
			_add(w, &"LeftShoulder" if p.x > 0.0 else &"RightShoulder", k)
			_add(w, &"Neck", neck)
		Tag.HOOD:
			_hood_w(p, w)
		Tag.HEAD, Tag.EARS:
			_add(w, &"Head", 1.0)
		Tag.SASH:
			var k := 0.3 * smoothstep(0.86, 0.66, p.y)
			_add(w, &"Hips", 1.0 - k)
			_add(w, &"LeftUpperLeg" if p.x > 0.0 else &"RightUpperLeg", k)
		Tag.GAUNT_L, Tag.GAUNT_R:
			var prefix := "Left" if tag == Tag.GAUNT_L else "Right"
			var elbow := smoothstep(0.47, 0.44, absf(p.x))
			var t := smoothstep(0.62, 0.66, absf(p.x))
			_add(w, StringName(prefix + "UpperArm"), elbow * 0.5)
			_add(w, StringName(prefix + "LowerArm"), (1.0 - t) * (1.0 - elbow * 0.5))
			_add(w, StringName(prefix + "Hand"), t)
		Tag.THUMB_L, Tag.THUMB_R:
			_add(w, &"LeftHand" if tag == Tag.THUMB_L else &"RightHand", 1.0)
		Tag.CHAKRAM:
			# Rigid: every vertex takes the jacket's weights at the mount point.
			_torso_w(Vector3(0.0, CHAKRAM_AT.y, -0.11), w, Tag.TORSO)
	return _pack(w)


func _torso_w(p: Vector3, w: Dictionary, tag: int) -> void:
	var spine := {}
	_piecewise(p.y, [[0.86, "Hips"], [0.95, "Spine"], [1.04, "Chest"], [1.13, "UpperChest"]], spine, false)
	var neck := 0.0
	if tag == Tag.TORSO:
		neck = smoothstep(1.30, 1.36, p.y) * (1.0 - smoothstep(0.055, 0.08, Vector2(p.x, p.z).length()))
	elif tag == Tag.COLLAR:
		neck = 0.3 * smoothstep(1.27, 1.38, p.y)
	var shoulder := smoothstep(0.10, 0.19, absf(p.x)) * smoothstep(1.14, 1.24, p.y)
	for b: StringName in spine:
		_add(w, b, spine[b] * (1.0 - shoulder) * (1.0 - neck))
	_add(w, &"LeftShoulder" if p.x > 0.0 else &"RightShoulder", shoulder * (1.0 - neck))
	_add(w, &"Neck", neck)


func _arm_w(p: Vector3, w: Dictionary, prefix: String) -> void:
	if absf(p.x) < 0.15:
		_torso_w(p, w, Tag.TORSO)
		return
	_piecewise(absf(p.x), [[0.15, prefix + "Shoulder"], [0.24, prefix + "UpperArm"], [0.39, prefix + "UpperArm"],
		[0.47, prefix + "LowerArm"]], w, true)


func _leg_w(p: Vector3, w: Dictionary, prefix: String) -> void:
	if p.y >= 0.84:
		_torso_w(p, w, Tag.TORSO)
		return
	var tmp := {}
	_piecewise(p.y, [[0.08, prefix + "Foot"], [0.15, prefix + "LowerLeg"], [0.42, prefix + "LowerLeg"],
		[0.50, prefix + "UpperLeg"], [0.72, prefix + "UpperLeg"], [0.84, "Hips"]], tmp, true)
	var foot := StringName(prefix + "Foot")
	if tmp.has(foot):
		var toes: float = smoothstep(0.1, 0.15, p.z) * tmp[foot]
		tmp[foot] -= toes
		tmp[StringName(prefix + "Toes")] = toes
	for b: StringName in tmp:
		_add(w, b, tmp[b])


## The hood follows the head; its back panel and cowl blend down Head ->
## Neck -> UpperChest so a head turn never opens a gap at the nape.
func _hood_w(p: Vector3, w: Dictionary) -> void:
	var back := smoothstep(0.04, -0.06, p.z)
	var low := smoothstep(1.52, 1.40, p.y) * back
	var chest := smoothstep(1.40, 1.34, p.y) * back
	_add(w, &"Head", 1.0 - low)
	_add(w, &"Neck", low - chest)
	_add(w, &"UpperChest", chest)


func _finger_w(p: Vector3, w: Dictionary, prefix: String, best: String) -> void:
	var pts := PackedVector3Array([rest[StringName(prefix + "Hand")]])
	var names: Array = [StringName(prefix + "Hand")]
	for part: String in ["Proximal", "Intermediate", "Distal"]:
		pts.append(rest[StringName(prefix + best + part)])
		names.append(StringName(prefix + best + part))
	pts.append(pts[3] + (pts[3] - pts[2]) * 1.2)
	_chain_w(p, w, pts, names)
