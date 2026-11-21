class_name LyraVoxelDesign
extends VoxelDesign
## Voxel Lyra (docs/lookdev/lyra.md), the star-cartographer mage, built with the
## voxel kit on the humanoid rig's rest pose (T-pose, +Z front, her left = +X).
## Grids: the body at 2.2 cm; the head and hair at 8.5 mm; the hat, hands,
## stole and clasp, and scroll cases at 1.1 cm. The three astrolabe rings are
## built here too (build_ring) but meshed unskinned by LyraAstrolabe.

const BODY_CELL := 0.022
const FINE_CELL := 0.011
const HEAD_CELL := 0.0085

enum Mat {
	EMPTY, COAT, COAT_DARK, CAPE, LINING, HAT, HAT_BAND, STOLE, INK, SCROLL, BRASS, BRASS_DARK,
	RIVET, ENGRAVE, LEATHER, LEATHER_DARK, SOLE, LEGGING, GLOVE, HAIR, HAIR_DARK, BROW, SKIN,
	SKIN_SHADE, BLUSH, LID, IRIS, IRIS_DEEP, EYE_WHITE, GLINT, MOUTH, STITCH, STAR, STARLINE,
	PENCIL, EMBLEM, QUILL, PETAL, STRING, INK_STAIN, BRASS_FILED, LINING_SHADE,
}
enum Tag {
	TORSO, COLLAR, ARM_L, ARM_R, LEG_L, LEG_R, SKIRT, CAPE, STOLE, HEAD, HAIR, HAT,
	BRACER_L, BRACER_R, THUMB_L, THUMB_R, RING,
}
## Per-finger rig tags: FINGER_BASE + side (0 left, 1 right) * 4 + finger.
const FINGER_BASE := 32
const FINGERS: Array[String] = ["Index", "Middle", "Ring", "Little"]

const COLORS := {
	Mat.COAT: Color("#1e2546"), Mat.COAT_DARK: Color("#11152b"),
	Mat.CAPE: Color("#161a33"), Mat.LINING: Color("#44709f"),
	Mat.HAT: Color("#1e2546"), Mat.HAT_BAND: Color("#1e7fd8"),
	Mat.STOLE: Color("#cdb892"), Mat.INK: Color("#4a3f52"), Mat.SCROLL: Color("#c6b08a"),
	Mat.BRASS: Color("#b49a64"), Mat.BRASS_DARK: Color("#7a6540"), Mat.RIVET: Color("#d0bc8c"),
	Mat.ENGRAVE: Color("#5c4b2e"), Mat.BRASS_FILED: Color("#dccba0"),
	Mat.LEATHER: Color("#4a3e3a"), Mat.LEATHER_DARK: Color("#2d2523"), Mat.SOLE: Color("#1e1918"),
	Mat.LEGGING: Color("#24253a"), Mat.GLOVE: Color("#3d3330"),
	Mat.HAIR: Color("#9c93b4"), Mat.HAIR_DARK: Color("#706890"), Mat.BROW: Color("#6a6188"),
	Mat.SKIN: Color("#f0c8ae"), Mat.SKIN_SHADE: Color("#d8a990"), Mat.BLUSH: Color("#f0aea0"),
	Mat.LID: Color("#2a2238"), Mat.IRIS: Color("#2f62c4"), Mat.IRIS_DEEP: Color("#142a66"),
	Mat.EYE_WHITE: Color("#f4f4f2"), Mat.GLINT: Color("#ffffff"), Mat.MOUTH: Color("#b0655e"),
	Mat.STITCH: Color("#363f66"), Mat.STAR: Color("#eaf4ff"), Mat.STARLINE: Color("#9fcaf2"),
	Mat.PENCIL: Color("#5a8cc8"), Mat.EMBLEM: Color("#cdb892"), Mat.QUILL: Color("#e6e0d2"),
	Mat.PETAL: Color("#e48aae"), Mat.STRING: Color("#b8a47a"), Mat.INK_STAIN: Color("#1a1c30"),
	Mat.LINING_SHADE: Color("#2a496b"),
}
## Shadow tones from the sheet, used where a part's own shadow side is painted.
const HAT_SHADOW := Color("#11152b")

## Big cloth: calm noise, never edge-lightened.
const QUIET: Array = [Mat.COAT, Mat.COAT_DARK, Mat.CAPE, Mat.LINING, Mat.LINING_SHADE, Mat.HAT, Mat.HAT_BAND, Mat.LEGGING]
## Worn on exposed edges (stole edges, leather, brass, boot toes, caps).
const WEARS: Array = [Mat.STOLE, Mat.SCROLL, Mat.BRASS, Mat.RIVET, Mat.LEATHER, Mat.GLOVE, Mat.SOLE]
## Small parts get up to +-6% value noise (the house recipe gives +-3.5%).
const NOISY: Array = [Mat.STOLE, Mat.SCROLL, Mat.BRASS, Mat.LEATHER, Mat.LEATHER_DARK, Mat.GLOVE]

## Astrolabe rings: major radius, band half width (radial) and half depth.
const RINGS := [Vector3(0.15, 0.0165, 0.011), Vector3(0.12, 0.0165, 0.011), Vector3(0.09, 0.0155, 0.011)]
## Where the rings float in rest skeleton space: behind her left shoulder.
const ASTROLABE_CENTER := Vector3(0.31, 1.42, -0.34)

const HAT_Y := 1.672  # underside of the brim
const BRIM_R := 0.36
## The brim's wave: the front tilts up, the back droops, from the crown's edge.
const BRIM_FRONT_TILT := 13.0
const BRIM_BACK_DROOP := 6.0
const CROWN_BASE_R := 0.172
## The hat's own bone: a child of Head at Head's rest, added at runtime.
const HAT_BONE := &"Hat"


func build_grids() -> Array[VoxelGrid]:
	return [build_body(), build_head(), build_brim(), build_crown(), build_front(), build_scrolls(),
		build_hand(1.0), build_hand(-1.0)]


func soft_materials() -> Array:
	return [Mat.COAT, Mat.CAPE, Mat.LEGGING, Mat.HAIR, Mat.SKIN, Mat.LEATHER]


func surface_of(mat: int) -> int:
	match mat:
		Mat.BRASS, Mat.BRASS_DARK, Mat.RIVET, Mat.ENGRAVE, Mat.BRASS_FILED:
			return Surf.METAL
		Mat.SKIN, Mat.SKIN_SHADE, Mat.BLUSH, Mat.MOUTH, Mat.LID:
			return Surf.SKIN
		Mat.STAR, Mat.GLINT, Mat.EYE_WHITE:
			return Surf.GLOW
		Mat.IRIS, Mat.IRIS_DEEP:
			return Surf.GLASS
		Mat.HAIR, Mat.HAIR_DARK, Mat.BROW:
			return Surf.HAIR
	return Surf.CLOTH


func color(mat: int, p: Vector3, c: Vector3i, n: Vector3, occlusion: float, exposure: float) -> Color:
	var base: Color = COLORS.get(mat, Color.MAGENTA)
	if mat in NOISY:
		base *= 1.0 + (VoxelSdf.hash3(c, mat + 77) - 0.5) * 0.05
	if mat == Mat.HAT and n.y < -0.5:
		# The brim's underside sits in its own shadow tone.
		base = base.lerp(HAT_SHADOW, 0.55)
	elif mat == Mat.COAT and p.y < 0.8:
		# A darker band low in the bell skirt's folds.
		base = base.lerp(COLORS[Mat.COAT_DARK], clampf((0.66 - p.y) / 0.2, 0.0, 1.0) * 0.35)
	elif mat == Mat.LINING and n.z < -0.5:
		# The lining's back side never shows; keep cape edges navy-dark.
		base = base.lerp(COLORS[Mat.CAPE], 0.5)
	return default_color(base, mat, c, occlusion, exposure, mat in QUIET, mat in WEARS,
		mat == Mat.HAIR or mat == Mat.HAIR_DARK or mat == Mat.BROW)


func surface_params() -> Array:
	var list := super.surface_params()
	# Star lights and eye whites: a clamped glow, so a star blooms to a dot, not a smear.
	list[Surf.GLOW] = {"roughness_value": 0.5, "emission_value": 0.3, "edge_lift": 0.0}
	return list


# ---------------------------------------------------------------- shapes

## Chamfered-box slice (an octagon): flat planes with 45-degree corners.
static func octagon(dx: float, dz: float, rx: float, rz: float, chamfer := 1.42) -> float:
	var ax := absf(dx) / rx
	var az := absf(dz) / rz
	return (maxf(maxf(ax, az), (ax + az) / chamfer) - 1.0) * minf(rx, rz)


static func _keys(y: float, keys: Array) -> Variant:
	if y >= keys[0][0]:
		return keys[0][1]
	for i in keys.size() - 1:
		if y >= keys[i + 1][0]:
			var t: float = (keys[i][0] - y) / (keys[i][0] - keys[i + 1][0])
			return lerp(keys[i][1], keys[i + 1][1], t)
	return keys[-1][1]


## Coat profile at height y: (half width, half depth, centre z); slim and
## upright, a narrow shoulder line (0.42 m across with the sleeves).
static func coat_profile(y: float) -> Vector3:
	return _keys(y, [
		[1.31, Vector3(0.07, 0.07, 0.0)], [1.29, Vector3(0.125, 0.088, 0.0)],
		[1.25, Vector3(0.172, 0.104, 0.0)], [1.19, Vector3(0.180, 0.112, 0.004)],
		[1.06, Vector3(0.170, 0.112, 0.006)], [0.92, Vector3(0.138, 0.100, 0.004)],
		[0.78, Vector3(0.160, 0.112, 0.0)],
	])


static func coat_sdf(p: Vector3, inset := 0.0) -> float:
	if p.y < 0.76 or p.y > 1.31:
		return 1.0
	var prof := coat_profile(p.y)
	return octagon(p.x, p.z - prof.z, prof.x - inset, prof.y - inset)


## Half width of the coat's V opening (from the collar to mid-chest).
static func opening(y: float) -> float:
	return 0.012 + maxf(y - 1.10, 0.0) * 0.34 if y > 1.08 else -1.0


## Bell skirt half extents at height y (waist 0.80 to hem 0.44).
static func skirt_radii(y: float) -> Vector2:
	var t := clampf((0.80 - y) / 0.36, 0.0, 1.0)
	return Vector2(0.162 + 0.112 * t, 0.114 + 0.092 * t)


const SKIRT_HEM := 0.44
## Centre of the body grid's voxel column nearest x = 0 (the skirt's front split).
const SPLIT_X := -0.009


## The skirt's outer surface without folds (for parts laid over it).
static func skirt_sdf(p: Vector3) -> float:
	if p.y > 0.80 or p.y < SKIRT_HEM:
		return 1.0
	var r := skirt_radii(p.y)
	return octagon(p.x, p.z, r.x, r.y)


## The cape (all planar): its half width at height y (narrow where the arms
## swing past, flaring below the hands), the inner face's depth behind the
## body, and four flat pleat planes per side, stepped in whole voxels.
static func cape_half_w(y: float) -> float:
	return _keys(y, [[1.31, 0.15], [1.12, 0.175], [0.86, 0.215], [0.08, 0.45]])


## Inner face z down the centre at height y, before the pleat steps.
static func cape_base_z(y: float) -> float:
	return _keys(y, [[1.31, -0.112], [1.18, -0.142], [1.0, -0.168], [0.80, -0.2], [0.44, -0.248], [0.08, -0.29]])


## How much of the cape at height y rides with the pelvis instead of its chain.
static func cape_hips_share(y: float) -> float:
	return 0.35 * smoothstep(1.08, 0.86, y) * smoothstep(0.42, 0.66, y)


## Pleat plane across the cape (0 centre panel, 1 box pleat, 2 and 3 the
## sides wrapping forward).
static func cape_strip(x: float, y: float) -> int:
	var u := absf(x) / cape_half_w(y)
	return 0 if u < 0.3 else (1 if u < 0.6 else (2 if u < 0.82 else 3))


## Inner face z at (x, y): the box pleat stands one voxel back, the sides step
## forward one and two voxels below the hands; each plane's depth snaps to
## the voxel grid on its own phase, so the steps down the length stagger.
static func cape_inner_z(x: float, y: float) -> float:
	var strip := cape_strip(x, y)
	var z := cape_base_z(y)
	var wrap := clampf((0.98 - y) / 0.14, 0.0, 1.0)
	var steps: Array[float] = [0.0, -1.0, roundf(wrap), roundf(wrap * 2.0)]
	var phases: Array[float] = [0.0, 0.5, 0.25, 0.75]
	z += steps[strip] * BODY_CELL
	var phase := phases[strip] * BODY_CELL
	return snappedf(z + phase, BODY_CELL) - phase + BODY_CELL * 0.5


## Width of the navy facing along the lining's sides.
static func facing_w(y: float) -> float:
	return _keys(y, [[1.31, 0.04], [0.08, 0.15]])


## The Wayfinder Star (original emblem) in its own 2D frame (unit = r): an
## eight-point star whose lower point runs on as a plumb line with a bob,
## inside a circle broken at the upper right (u > 0 is the viewer's right).
## Strokes never thin below one line_w, so it holds at the body cell.
static func wayfinder(q: Vector2, r: float, line_w: float) -> bool:
	if q.length() < r * 0.24:
		return true
	for k in 8:
		var d := Vector2(cos(k * PI / 4.0), sin(k * PI / 4.0))
		var along := q.dot(d)
		var length := r if k % 2 == 0 else r * 0.62
		var base := (0.3 if k % 2 == 0 else 0.22) * r
		if along > 0.0 and along < length and absf(q.cross(d)) < maxf(base * (1.0 - along / length), line_w * 0.5):
			return true
	# The plumb line down from the lower point, and its bob.
	if q.y < -r and q.y > -r * 2.0 and absf(q.x) < line_w * 0.5:
		return true
	if Vector2(q.x, q.y + r * 2.1).length() < line_w * 1.1:
		return true
	var angle := rad_to_deg(atan2(q.y, q.x))
	return absf(q.length() - r * 1.38) < line_w * 0.5 and not (angle > 15.0 and angle < 65.0)


# ---------------------------------------------------------------- body grid

func build_body() -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(-0.68, -0.01, -0.37), Vector3(1.36, 1.45, 0.63)), BODY_CELL)
	_legs(g)
	_torso(g)
	_skirt(g)
	_arms(g)
	_collar(g)
	_cape(g)
	_seams(g)
	return g


func _torso(g: VoxelGrid) -> void:
	var box := AABB(Vector3(-0.22, 0.74, -0.16), Vector3(0.44, 0.6, 0.32))
	# Undershirt (shows in the V) and the robe coat over it, flat panels.
	g.paint(box, func(p: Vector3): return coat_sdf(p, 0.022), Mat.COAT_DARK, Tag.TORSO)
	g.paint(box, func(p: Vector3): return coat_sdf(p), Mat.COAT, Tag.TORSO, ADD)
	g.paint(box, func(p: Vector3):
		var o := opening(p.y)
		return -1.0 if o > 0.0 and absf(p.x) < o and p.z > 0.02 and coat_sdf(p, 0.022) > 0.0 else 1.0,
		0, -1, CARVE)
	# A dark edge along the opening (a turned facing).
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		var o := opening(p.y)
		return o > 0.0 and p.z > 0.04 and absf(absf(p.x) - o) < BODY_CELL * 0.8, Mat.STITCH, [Mat.COAT])
	# Belt: a leather band with a small brass buckle off-centre.
	g.paint(box, func(p: Vector3):
		if p.y < 0.80 or p.y > 0.846:
			return 1.0
		var prof := coat_profile(p.y)
		return octagon(p.x, p.z - prof.z, prof.x + 0.014, prof.y + 0.014), Mat.LEATHER, Tag.TORSO)
	var buckle := Vector3(0.05, 0.823, coat_profile(0.823).y + 0.03)
	var bb := AABB(buckle - Vector3(0.05, 0.04, 0.03), Vector3(0.1, 0.08, 0.06))
	g.paint(bb, func(p: Vector3): return VoxelSdf.box(p, buckle, Vector3(0.033, 0.024, 0.011)), Mat.BRASS, Tag.TORSO)
	g.paint(bb, func(p: Vector3): return VoxelSdf.box(p, buckle + Vector3(0, 0, 0.01), Vector3(0.011, 0.011, 0.006)),
		Mat.LEATHER_DARK, Tag.TORSO, PAINT)


func _skirt(g: VoxelGrid) -> void:
	# Bell skirt: flat octagonal panels flaring to the knee, crisp fold
	# ridges growing downward, a front split to the knee, a hard level hem.
	var box := AABB(Vector3(-0.32, SKIRT_HEM - 0.02, -0.26), Vector3(0.64, 0.4, 0.52))
	g.paint(box, func(p: Vector3):
		if p.y > 0.80 or p.y < SKIRT_HEM:
			return 1.0
		var angle := atan2(p.x, -p.z)  # 0 at the back
		# The split: one voxel column at the top (y 0.6), opening toward the hem.
		var split := lerpf(0.0, 0.03, clampf((0.6 - p.y) / 0.16, 0.0, 1.0))
		if p.z > 0.0 and p.y < 0.6 and absf(p.x - SPLIT_X) < BODY_CELL * 0.5 + split:
			return 1.0
		var r := skirt_radii(p.y)
		var t := clampf((0.78 - p.y) / 0.3, 0.0, 1.0)
		var ridge := 0.022 * t if absf(sin(angle * 6.0)) > 0.94 else 0.0
		var outer := octagon(p.x, p.z, r.x + ridge, r.y + ridge)
		var inner := octagon(p.x, p.z, r.x - 0.034, r.y - 0.034)
		return maxf(outer, -inner), Mat.COAT, Tag.SKIRT)
	# Hem band and stitched hem line.
	g.paint_surface(box, func(p: Vector3, _c: Vector3i): return p.y < SKIRT_HEM + BODY_CELL, Mat.COAT_DARK, [Mat.COAT])
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		return p.y > SKIRT_HEM + BODY_CELL * 1.5 and p.y < SKIRT_HEM + BODY_CELL * 2.5 and posmod(c.x + c.z, 2) == 0,
		Mat.STITCH, [Mat.COAT])


func _legs(g: VoxelGrid) -> void:
	var box := AABB(Vector3(-0.24, -0.01, -0.14), Vector3(0.48, 0.84, 0.36))
	for side: float in [1.0, -1.0]:
		var tag := Tag.LEG_L if side > 0 else Tag.LEG_R
		var hip := Vector3(0.105 * side, 0.80, 0.0)
		var knee := Vector3(0.128 * side, 0.44, 0.008)
		g.paint(box, func(p: Vector3): return VoxelSdf.capsule(p, hip, knee, 0.072, 0.054), Mat.LEGGING, tag)
		# Slim knee-high boots: planar octagon shaft, a folded cuff, foot, sole.
		var bx := 0.132 * side
		g.paint(box, func(p: Vector3):
			if p.y < 0.07 or p.y > 0.43:
				return 1.0
			var t := (p.y - 0.07) / 0.36
			return octagon(p.x - bx, p.z + 0.004, lerpf(0.05, 0.058, t), lerpf(0.054, 0.06, t)), Mat.LEATHER, tag)
		g.paint(box, func(p: Vector3):
			if p.y < 0.39 or p.y > 0.47:
				return 1.0
			return octagon(p.x - bx, p.z + 0.002, 0.07, 0.072), Mat.LEATHER_DARK, tag)
		g.paint(box, func(p: Vector3):
			if p.y < 0.026:
				return 1.0
			var foot := VoxelSdf.box(p, Vector3(bx, 0.06, 0.04), Vector3(0.05, 0.048, 0.1), 0.03)
			var toe := VoxelSdf.box(p, Vector3(bx, 0.05, 0.13), Vector3(0.046, 0.038, 0.05), 0.03)
			return minf(foot, toe), Mat.LEATHER, tag)
		g.paint(box, func(p: Vector3): return VoxelSdf.box(p, Vector3(bx, 0.014, 0.05), Vector3(0.056, 0.015, 0.14), 0.01),
			Mat.SOLE, tag)
		# Heel block.
		g.paint(box, func(p: Vector3): return VoxelSdf.box(p, Vector3(bx, 0.03, -0.04), Vector3(0.046, 0.03, 0.035)),
			Mat.SOLE, tag)
		# Ankle strap with a brass buckle on the outside.
		g.paint(box, func(p: Vector3):
			if absf(p.y - 0.13) > 0.012:
				return 1.0
			return octagon(p.x - bx, p.z + 0.004, 0.06, 0.064), Mat.LEATHER_DARK, tag)
		var b := Vector3(bx + 0.064 * side, 0.13, -0.004)
		g.paint(box, func(p: Vector3): return VoxelSdf.box(p, b, Vector3(0.01, 0.014, 0.016)), Mat.BRASS, tag)
		# Back seam stitches up the shaft.
		g.paint_surface(box, func(p: Vector3, c: Vector3i):
			return p.y > 0.1 and p.y < 0.38 and p.z < -0.04 and absf(p.x - bx) < BODY_CELL * 0.5 and c.y % 2 == 0,
			Mat.STITCH, [Mat.LEATHER])


func _arms(g: VoxelGrid) -> void:
	var box := AABB(Vector3(-0.68, 1.16, -0.11), Vector3(1.36, 0.22, 0.22))
	var y := 1.27
	for side: float in [1.0, -1.0]:
		var tag := Tag.ARM_L if side > 0 else Tag.ARM_R
		# Slim sleeve with a short flared cuff over the bracer.
		g.paint(box, func(p: Vector3):
			if p.x * side < 0.0:
				return 1.0
			return VoxelSdf.capsule(p, Vector3(0.15 * side, y, 0.0), Vector3(0.62 * side, y, 0.0), 0.066, 0.052),
			Mat.COAT, tag)
		g.paint(box, func(p: Vector3):
			var ax := p.x * side
			if ax < 0.585 or ax > 0.655:
				return 1.0
			return octagon(p.y - y, p.z, 0.066, 0.066), Mat.COAT, tag)
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			var ax := p.x * side
			return ax > 0.632 and ax < 0.66, Mat.COAT_DARK, [Mat.COAT])
		# Seam stitches along the top of the sleeve.
		g.paint_surface(box, func(p: Vector3, c: Vector3i):
			var ax := p.x * side
			return ax > 0.3 and ax < 0.58 and p.y > y + 0.03 and absf(p.z) < BODY_CELL * 0.5 and c.x % 2 == 0,
			Mat.STITCH, [Mat.COAT])


func _collar(g: VoxelGrid) -> void:
	var box := AABB(Vector3(-0.16, 1.18, -0.16), Vector3(0.32, 0.26, 0.3))
	g.paint(box, func(p: Vector3): return VoxelSdf.capsule(p, Vector3(0, 1.24, -0.004), Vector3(0, 1.42, 0.0), 0.046, 0.043),
		Mat.SKIN, Tag.TORSO)
	# Standing collar, open in a V at the front.
	var top := func(p: Vector3) -> float: return 1.36 - maxf(p.z, 0.0) * 0.45
	g.paint(box, func(p: Vector3):
		if p.y < 1.24 or p.y > top.call(p):
			return 1.0
		if p.z > 0.0 and absf(p.x) < 0.035 + (p.y - 1.24) * 0.5:
			return 1.0
		var flare := (p.y - 1.24) * 0.22
		var outer := octagon(p.x, p.z + 0.006, 0.098 + flare, 0.09 + flare)
		var inner := octagon(p.x, p.z + 0.006, 0.074 + flare, 0.066 + flare)
		return maxf(outer, -inner), Mat.COAT, Tag.COLLAR)
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		return g.tags[g.index(c.x, c.y, c.z)] == Tag.COLLAR and p.y > top.call(p) - BODY_CELL, Mat.COAT_DARK, [Mat.COAT])
	# Cape shoulder bands: from the cape's top corners over each shoulder to
	# the clasp discs on the chest.
	for side: float in [1.0, -1.0]:
		g.paint(AABB(Vector3(-0.2, 1.14, -0.16), Vector3(0.4, 0.2, 0.3)), func(p: Vector3):
			var ax := p.x * side
			if ax < 0.105 or ax > 0.165 or p.y < 1.17 or (p.z > 0.0 and p.y < 1.19):
				return 1.0
			var d := coat_sdf(p)
			return -1.0 if d > 0.0 and coat_sdf(p, -BODY_CELL * 1.05) <= 0.0 else 1.0, Mat.CAPE, Tag.TORSO, ADD)


func _cape(g: VoxelGrid) -> void:
	# Planar pleated panel two voxels thick (navy outside, muted blue lining
	# inside) from the shoulders to the ankles; each pleat plane is flat, the
	# fold ridges are where the planes step; a hard level hem.
	var box := AABB(Vector3(-0.47, 0.07, -0.37), Vector3(0.94, 1.26, 0.29))
	g.paint(box, func(p: Vector3):
		if p.y < 0.08 or p.y > 1.31 or absf(p.x) > cape_half_w(p.y):
			return 1.0
		var zi := cape_inner_z(p.x, p.y)
		# Where a pleat plane steps, its edge folds back to meet the next
		# plane (a fold return), so the cape never shows daylight between them.
		var lo := zi
		for dx: float in [-BODY_CELL, BODY_CELL]:
			if absf(p.x + dx) <= cape_half_w(p.y):
				lo = minf(lo, cape_inner_z(p.x + dx, p.y))
		return -1.0 if p.z < zi and p.z >= lo - BODY_CELL * 2.0 else 1.0, Mat.CAPE, Tag.CAPE, ADD)
	var lining := func(p: Vector3) -> bool: return p.z >= cape_inner_z(p.x, p.y) - BODY_CELL
	g.paint(box, func(p: Vector3): return -1.0 if lining.call(p) else 1.0, Mat.LINING, Tag.CAPE, PAINT)
	# Crease shade on the outside where a pleat plane steps in.
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		if g.tags[g.index(c.x, c.y, c.z)] != Tag.CAPE or lining.call(p):
			return false
		var here := cape_strip(p.x, p.y)
		var beside := cape_strip(p.x + BODY_CELL * signf(p.x), p.y)
		return here != beside and (here == 0 or here == 2), Mat.COAT_DARK, [Mat.CAPE])
	# A navy facing down both sides of the lining (so at rest only a strip of
	# lining shows past her; it opens up in flight), edged in the lining's
	# shadow tone so the edge never reads brighter than the stole.
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		if g.tags[g.index(c.x, c.y, c.z)] != Tag.CAPE or not lining.call(p):
			return false
		return absf(p.x) > cape_half_w(p.y) - facing_w(p.y), Mat.CAPE, [Mat.LINING])
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		if g.tags[g.index(c.x, c.y, c.z)] != Tag.CAPE or not lining.call(p):
			return false
		return absf(absf(p.x) - (cape_half_w(p.y) - facing_w(p.y))) < BODY_CELL * 0.5, Mat.LINING_SHADE, [Mat.LINING, Mat.CAPE])
	# The lining shows as piping along the hem on the outside, in its shadow tone.
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		return g.tags[g.index(c.x, c.y, c.z)] == Tag.CAPE and p.y < 0.08 + BODY_CELL, Mat.LINING_SHADE, [Mat.CAPE])
	# Emblem embroidered on the outer back (viewed from behind, u = -x is right).
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		if g.tags[g.index(c.x, c.y, c.z)] != Tag.CAPE or lining.call(p):
			return false
		return wayfinder(Vector2(-p.x, p.y - EMBLEM_Y), EMBLEM_R, BODY_CELL), Mat.EMBLEM, [Mat.CAPE, Mat.COAT_DARK])
	_star_map(g, box)


const EMBLEM_Y := 0.94
const EMBLEM_R := 0.12


## The constellation map on the lining: dots (glowing) joined by pale lines,
## and an unfinished corner (her left, low) with only a pencil grid.
func _star_map(g: VoxelGrid, box: AABB) -> void:
	var groups := [
		[Vector2(-0.10, 1.12), Vector2(-0.02, 1.02), Vector2(0.09, 1.06), Vector2(0.14, 0.94)],
		[Vector2(-0.22, 0.86), Vector2(-0.14, 0.74), Vector2(-0.24, 0.62), Vector2(-0.12, 0.52), Vector2(-0.02, 0.62)],
		[Vector2(0.10, 0.80), Vector2(0.22, 0.70), Vector2(0.16, 0.58)],
		[Vector2(-0.25, 0.40), Vector2(-0.2, 0.30), Vector2(-0.08, 0.34), Vector2(-0.12, 0.20)],
		[Vector2(0.02, 0.44), Vector2(0.06, 0.28)],
	]
	var unfinished := func(p: Vector3) -> bool: return p.x > 0.14 and p.y < 0.42
	var inner := func(p: Vector3, c: Vector3i) -> bool:
		return g.tags[g.index(c.x, c.y, c.z)] == Tag.CAPE and p.z >= cape_inner_z(p.x, p.y) - BODY_CELL
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		if not inner.call(p, c) or unfinished.call(p):
			return false
		var q := Vector2(p.x, p.y)
		for grp: Array in groups:
			for i in grp.size() - 1:
				var a: Vector2 = grp[i]
				var b: Vector2 = grp[i + 1]
				var t := clampf((q - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
				if q.distance_to(a + (b - a) * t) < BODY_CELL * 0.5:
					return true
		return false, Mat.STARLINE, [Mat.LINING])
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		if not inner.call(p, c) or unfinished.call(p):
			return false
		for grp: Array in groups:
			for s: Vector2 in grp:
				if Vector2(p.x, p.y).distance_to(s) < BODY_CELL * 0.75:
					return true
		# A scatter of faint single stars between the figures.
		return VoxelSdf.hash3(c, 911) > 0.993, Mat.STAR, [Mat.LINING, Mat.STARLINE])
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		return inner.call(p, c) and unfinished.call(p) and (c.x % 3 == 0 or c.y % 3 == 0), Mat.PENCIL, [Mat.LINING])


func _seams(g: VoxelGrid) -> void:
	var box := AABB(Vector3(-0.22, 0.46, -0.16), Vector3(0.44, 0.86, 0.32))
	# Side seams (dashed) and princess seams down the front panels.
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		if g.mats[g.index(c.x, c.y, c.z)] != Mat.COAT or p.y < 0.86 or p.y > 1.2:
			return false
		var prof := coat_profile(p.y)
		var side_seam := absf(p.z - prof.z) < BODY_CELL * 0.6 and absf(p.x) > 0.1
		var princess := p.z > 0.05 and absf(absf(p.x) - 0.095) < BODY_CELL * 0.5 and p.y < 1.06
		return (side_seam or princess) and c.y % 2 == 0, Mat.STITCH)


# ---------------------------------------------------------------- head grid

func build_head() -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(-0.175, 1.10, -0.23), Vector3(0.35, 0.59, 0.41)), HEAD_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	var t := Tag.HEAD
	var face := AABB(Vector3(-0.15, 1.36, -0.16), Vector3(0.3, 0.3, 0.31))
	g.paint(face, func(p: Vector3):
		var cranium := VoxelSdf.ellipsoid(p, Vector3(0, 1.552, -0.004), Vector3(0.122, 0.144, 0.136))
		var jaw := VoxelSdf.ellipsoid(p, Vector3(0, 1.462, 0.018), Vector3(0.094, 0.09, 0.106))
		var chin := VoxelSdf.sphere(p, Vector3(0, 1.402, 0.066), 0.03)
		return VoxelSdf.smooth_union(VoxelSdf.smooth_union(cranium, jaw, 0.04), chin, 0.035), Mat.SKIN, t)
	g.paint(face, func(p: Vector3): return VoxelSdf.box(p, Vector3(0, 1.474, 0.13), Vector3(0.006, 0.014, 0.008)), Mat.SKIN, t, ADD)
	_face(g, face)
	_hair(g, box)
	return g


func _face(g: VoxelGrid, box: AABB) -> void:
	var front := [Mat.SKIN, Mat.SKIN_SHADE, Mat.BLUSH]
	for s: float in [1.0, -1.0]:
		var e := Vector2(0.05 * s, 1.5)
		var q_of := func(p: Vector3, rx: float, ry: float, dx: float, dy: float) -> float:
			return Vector2((p.x - e.x - dx) / rx, (p.y - e.y - dy) / ry).length()
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			return p.z > 0.06 and q_of.call(p, 0.027, 0.032, 0.0, 0.0) < 1.0, Mat.EYE_WHITE, front)
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			return p.z > 0.06 and q_of.call(p, 0.02, 0.029, -0.004 * s, -0.002) < 1.0, Mat.IRIS, [Mat.EYE_WHITE] + front)
		# Deep blue top of the iris and a dark pupil.
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			var top: bool = q_of.call(p, 0.02, 0.029, -0.004 * s, -0.002) < 1.0 and p.y > e.y + 0.008
			var pupil: bool = q_of.call(p, 0.007, 0.012, -0.004 * s, -0.003) < 1.0
			return p.z > 0.06 and (top or pupil), Mat.IRIS_DEEP, [Mat.IRIS])
		# Two highlights each, from the same light (upper right of the image).
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			var big := absf(p.x - (e.x - 0.01)) < 0.0065 and absf(p.y - (e.y + 0.011)) < 0.0065
			var small := absf(p.x - (e.x + 0.004)) < 0.0045 and absf(p.y - (e.y - 0.014)) < 0.0045
			return p.z > 0.06 and (big or small), Mat.GLINT, [Mat.IRIS, Mat.IRIS_DEEP])
		# Upper lid and lashes: a dark arc, two flicks at the outer corner, a
		# short lower lash line.
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			if p.z < 0.06:
				return false
			var q := Vector2((p.x - e.x) / 0.03, (p.y - e.y) / 0.036)
			var arc := q.length() > 0.84 and q.length() < 1.16 and q.y > 0.15
			var ox := (p.x - e.x) * s
			var flick1 := ox > 0.022 and ox < 0.036 and absf(p.y - (e.y + 0.016 + (ox - 0.022) * 0.6)) < 0.0045
			var flick2 := ox > 0.024 and ox < 0.034 and absf(p.y - (e.y + 0.004 + (ox - 0.024) * 0.4)) < 0.004
			var lower := ox > 0.008 and ox < 0.026 and absf(q.length() - 1.06) < 0.14 and q.y < -0.4
			return arc or flick1 or flick2 or lower, Mat.LID, [Mat.EYE_WHITE, Mat.IRIS, Mat.IRIS_DEEP] + front)
		# Thin, gently arched brows, a little raised.
		g.paint(box, func(p: Vector3):
			var along := (p.x * s - 0.022) / 0.062
			if along < 0.0 or along > 1.0:
				return 1.0
			var by := 1.552 + sin(along * PI) * 0.007 - along * 0.004
			return VoxelSdf.box(p, Vector3(p.x, by, 0.128 - along * 0.026), Vector3(0.1, 0.0045, 0.008)), Mat.BROW, Tag.HEAD, ADD)
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			return p.z > 0.06 and Vector2((p.x - 0.068 * s) / 0.02, (p.y - 1.462) / 0.011).length() < 1.0, Mat.BLUSH, [Mat.SKIN])
	# Small calm mouth, both corners just lifted.
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		if p.z < 0.06:
			return false
		var ax := absf(p.x)
		return (ax < 0.012 and absf(p.y - 1.427) < 0.004) or (ax >= 0.012 and ax < 0.019 and absf(p.y - 1.431) < 0.004),
		Mat.MOUTH, [Mat.SKIN, Mat.SKIN_SHADE])
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		var side := p.x > 0.004 and p.x < 0.016 and p.y > 1.46 and p.y < 1.486
		var under := absf(p.x) < 0.011 and p.y > 1.452 and p.y < 1.461
		var lip := absf(p.x) < 0.009 and p.y > 1.413 and p.y < 1.42
		return p.z > 0.09 and (side or under or lip), Mat.SKIN_SHADE, [Mat.SKIN])


func _hair(g: VoxelGrid, box: AABB) -> void:
	var t := Tag.HAIR
	var top := HAT_Y + 0.006  # everything above is inside the hat's crown
	g.paint(box, func(p: Vector3):
		if p.y > top:
			return 1.0
		if p.z > 0.03 and p.y < 1.6 - maxf(0.0, p.z - 0.03) * 0.3 and absf(p.x) < 0.108:
			return 1.0
		if p.y < 1.47 and p.z > -0.03:
			return 1.0
		var mass := VoxelSdf.ellipsoid(p, Vector3(0, 1.598, -0.018), Vector3(0.14, 0.13, 0.152))
		var back := VoxelSdf.ellipsoid(p, Vector3(0, 1.53, -0.058), Vector3(0.134, 0.12, 0.116))
		return minf(mass, back), Mat.HAIR, t)
	# Back sheet: straight hair to the shoulder blades, a ragged pointed hem
	# and darker strand grooves.
	var sheet_z := func(y: float) -> float: return _keys(y, [[1.52, -0.142], [1.31, -0.17], [1.12, -0.205]])
	var sheet_box := AABB(Vector3(-0.15, 1.10, -0.225), Vector3(0.3, 0.44, 0.125))
	g.paint(sheet_box, func(p: Vector3):
		var hw: float = _keys(p.y, [[1.5, 0.128], [1.3, 0.126], [1.12, 0.112]])
		var ax := absf(p.x)
		if ax > hw or p.y > 1.52:
			return 1.0
		var tri := absf(fposmod(p.x / 0.044, 1.0) - 0.5) * 2.0
		var hem := 1.115 + 0.045 * pow(ax / hw, 2.0) + 0.03 * tri
		if p.y < hem:
			return 1.0
		return absf(p.z - sheet_z.call(p.y)) - 0.017, Mat.HAIR, t, ADD)
	g.paint_surface(sheet_box, func(p: Vector3, c: Vector3i):
		return p.z < sheet_z.call(p.y) - 0.006 and p.y < 1.46 and posmod(c.x, 4) == 0, Mat.HAIR_DARK, [Mat.HAIR])
	# Straight locks (start, bend, tip, root radius, tip radius): bangs over
	# the forehead, two face-framing locks per side, and loose strands over
	# the brim's shadow.
	var locks := [
		[Vector3(-0.086, 1.64, 0.09), Vector3(-0.094, 1.61, 0.128), Vector3(-0.098, 1.565, 0.124), 0.024, 0.009],
		[Vector3(-0.052, 1.645, 0.1), Vector3(-0.056, 1.612, 0.138), Vector3(-0.058, 1.556, 0.132), 0.024, 0.009],
		[Vector3(-0.018, 1.645, 0.104), Vector3(-0.02, 1.614, 0.142), Vector3(-0.02, 1.566, 0.136), 0.024, 0.009],
		[Vector3(0.022, 1.645, 0.104), Vector3(0.024, 1.614, 0.142), Vector3(0.026, 1.574, 0.138), 0.022, 0.008],
		[Vector3(0.056, 1.645, 0.1), Vector3(0.06, 1.612, 0.137), Vector3(0.063, 1.558, 0.131), 0.024, 0.009],
		[Vector3(0.09, 1.64, 0.088), Vector3(0.097, 1.61, 0.124), Vector3(0.102, 1.568, 0.12), 0.024, 0.009],
	]
	for s: float in [1.0, -1.0]:
		locks.append([Vector3(0.112 * s, 1.63, 0.06), Vector3(0.13 * s, 1.49, 0.072), Vector3(0.122 * s, 1.335, 0.058), 0.026, 0.01])
		locks.append([Vector3(0.126 * s, 1.62, 0.0), Vector3(0.142 * s, 1.46, 0.004), Vector3(0.136 * s, 1.31, -0.012), 0.03, 0.012])
	for lock: Array in locks:
		_lock(g, box, lock[0], lock[1], lock[2], lock[3], lock[4])
	_lock(g, box, Vector3(0.066, 1.636, 0.118), Vector3(0.104, 1.58, 0.15), Vector3(0.094, 1.5, 0.14), 0.007, 0.005)
	_lock(g, box, Vector3(-0.07, 1.638, 0.114), Vector3(-0.112, 1.586, 0.148), Vector3(-0.108, 1.52, 0.134), 0.007, 0.005)
	_lock(g, box, Vector3(0.004, 1.64, 0.12), Vector3(0.012, 1.6, 0.152), Vector3(0.002, 1.55, 0.146), 0.006, 0.0045)


## A hair lock: a tapered tube along a quadratic curve.
func _lock(g: VoxelGrid, box: AABB, a: Vector3, bend: Vector3, tip: Vector3, r0: float, r1: float) -> void:
	var pts := PackedVector3Array()
	for k in 7:
		var u := k / 6.0
		pts.append(a.lerp(bend, u).lerp(bend.lerp(tip, u), u))
	var lo := pts[0]
	var hi := pts[0]
	for q in pts:
		lo = Vector3(minf(lo.x, q.x), minf(lo.y, q.y), minf(lo.z, q.z))
		hi = Vector3(maxf(hi.x, q.x), maxf(hi.y, q.y), maxf(hi.z, q.z))
	var bounds := AABB(lo - Vector3.ONE * r0, hi - lo + Vector3.ONE * r0 * 2.0).intersection(box)
	g.paint(bounds, func(p: Vector3):
		if p.y > HAT_Y + 0.006:
			return 1.0
		var best := 1e9
		for i in 6:
			best = minf(best, VoxelSdf.capsule(p, pts[i], pts[i + 1], lerpf(r0, r1, i / 6.0), lerpf(r0, r1, (i + 1) / 6.0)))
		return best, Mat.HAIR, Tag.HAIR)


# ---------------------------------------------------------------- hat grids

## The brim's flat profile at radius r: the outer third one voxel lower (a
## planar tier, so the brim reads as curving down, not as a card).
static func brim_base(r: float) -> float:
	return HAT_Y - (FINE_CELL if r > BRIM_R * 0.62 else 0.0)


## The brim's underside at (x, z): the flat profile plus the wave, which lifts
## the front (eyes read from a high camera) and droops the back.
static func brim_base_at(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	if r <= CROWN_BASE_R:
		return brim_base(r)
	var f := (z / r + 1.0) * 0.5
	var down := tan(deg_to_rad(BRIM_BACK_DROOP))
	var slope := -down + (tan(deg_to_rad(BRIM_FRONT_TILT)) + down) * f * f
	return brim_base(r) + (r - CROWN_BASE_R) * slope


## The brim: fine-cell planar tiers, three voxels thick round the crown and
## two further out, the outer edge turned up three voxels, a stitched ring
## inside the edge and star lights set in it.
func build_brim() -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(-0.375, HAT_Y - 0.044, -0.375), Vector3(0.75, 0.165, 0.75)), FINE_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	g.paint(box, func(p: Vector3):
		var r := Vector2(p.x, p.z).length()
		if r > BRIM_R:
			return 1.0
		var h := p.y - brim_base_at(p.x, p.z)
		if h < 0.0:
			return 1.0
		var thick := 3.0 if r < 0.24 else 2.0
		if r > BRIM_R - FINE_CELL * 2.0:
			thick = 5.0
		return -1.0 if h < FINE_CELL * thick else 1.0, Mat.HAT, Tag.HAT)
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		var r := Vector2(p.x, p.z).length()
		var h := p.y - brim_base_at(p.x, p.z)
		return h > FINE_CELL and h < FINE_CELL * 2.0 and absf(r - (BRIM_R - FINE_CELL * 4.5)) < FINE_CELL * 0.6 \
			and posmod(c.x + c.z, 3) != 0, Mat.STITCH, [Mat.HAT])
	# A dark crease where the tiers meet.
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		var r := Vector2(p.x, p.z).length()
		return absf(r - BRIM_R * 0.62) < FINE_CELL * 0.7 and p.y > brim_base_at(p.x, p.z) + FINE_CELL, Mat.COAT_DARK, [Mat.HAT])
	# Star lights: a bright core with four dim arms, seven round the brim.
	for s: Vector2 in [Vector2(-60, 0.80), Vector2(-24, 0.64), Vector2(18, 0.84), Vector2(52, 0.66),
			Vector2(108, 0.78), Vector2(160, 0.70), Vector2(-128, 0.74)]:
		var a := deg_to_rad(s.x)
		var at := Vector2(sin(a), cos(a)) * BRIM_R * s.y
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			if p.y < brim_base_at(p.x, p.z) + FINE_CELL:
				return false
			var d := Vector2(p.x, p.z) - at
			return absf(d.x) < FINE_CELL * 1.0 and absf(d.y) < FINE_CELL * 1.0 or \
				(absf(d.x) < FINE_CELL * 0.5 and absf(d.y) < FINE_CELL * 1.6) or (absf(d.y) < FINE_CELL * 0.5 and absf(d.x) < FINE_CELL * 1.6),
			Mat.STAR, [Mat.HAT, Mat.STITCH])
	return g


## Crown points: from the brim, up and bending back to a hook (0.40 m tall,
## 0.24 m back), with radii.
const CROWN := [
	[Vector3(0, HAT_Y + 0.01, -0.01), 0.172], [Vector3(0, 1.83, -0.022), 0.13], [Vector3(0, 1.96, -0.06), 0.086],
	[Vector3(0, 2.045, -0.14), 0.05], [Vector3(0, 2.075, -0.225), 0.03], [Vector3(0, 2.06, -0.268), 0.02],
]


static func crown_sdf(p: Vector3, grow := 0.0) -> float:
	var best := 1e9
	for i in CROWN.size() - 1:
		best = minf(best, VoxelSdf.capsule(p, CROWN[i][0], CROWN[i + 1][0], CROWN[i][1] + grow, CROWN[i + 1][1] + grow))
	return maxf(best, HAT_Y + 0.012 - p.y)


func build_crown() -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(-0.19, HAT_Y + 0.01, -0.33), Vector3(0.38, 0.43, 0.53)), FINE_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	g.paint(box, func(p: Vector3): return crown_sdf(p), Mat.HAT, Tag.HAT)
	# A crease where the crown bends back.
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		return absf(p.y - (1.995 + p.z * 0.25)) < FINE_CELL * 0.6 and p.z > -0.12, Mat.COAT_DARK, [Mat.HAT])
	# Hat band (cerulean, one voxel proud) with a small brass buckle.
	g.paint(box, func(p: Vector3):
		return crown_sdf(p, FINE_CELL) if p.y < HAT_Y + 0.058 else 1.0, Mat.HAT_BAND, Tag.HAT, ADD)
	g.paint(box, func(p: Vector3): return crown_sdf(p, FINE_CELL) if p.y < HAT_Y + 0.058 else 1.0, Mat.HAT_BAND, Tag.HAT, PAINT)
	var bk := Vector3(0.07, HAT_Y + 0.036, 0.16)
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, bk, Vector3(0.018, 0.02, 0.012)), Mat.BRASS, Tag.HAT)
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, bk + Vector3(0, 0, 0.008), Vector3(0.008, 0.01, 0.008)), Mat.HAT_BAND, Tag.HAT, PAINT)
	# Quill tucked into the band on her right, a pressed Heartbloom petal by it.
	var quill := PackedVector3Array([Vector3(-0.15, HAT_Y + 0.03, 0.08), Vector3(-0.172, 1.79, 0.03), Vector3(-0.17, 1.89, -0.06)])
	g.paint(box, func(p: Vector3):
		var best := 1e9
		for i in 2:
			best = minf(best, VoxelSdf.capsule(p, quill[i], quill[i + 1], 0.006 + i * 0.004, 0.012 - i * 0.008))
		return best, Mat.QUILL, Tag.HAT, ADD)
	g.paint(box, func(p: Vector3): return VoxelSdf.capsule(p, quill[0], quill[1], 0.005, 0.005) if p.y < HAT_Y + 0.06 else 1.0,
		Mat.INK_STAIN, Tag.HAT, PAINT)
	g.paint(box, func(p: Vector3):
		return minf(VoxelSdf.ellipsoid(p, Vector3(-0.168, HAT_Y + 0.04, 0.11), Vector3(0.012, 0.016, 0.014)),
			VoxelSdf.ellipsoid(p, Vector3(-0.172, HAT_Y + 0.05, 0.095), Vector3(0.01, 0.012, 0.012))), Mat.PETAL, Tag.HAT, ADD)
	# Star lights on the crown.
	for s: Vector3 in [Vector3(0.12, 1.77, 0.06), Vector3(-0.07, 1.89, 0.075), Vector3(0.05, 1.98, 0.03), Vector3(-0.04, 2.06, -0.13)]:
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			return p.distance_to(s) < FINE_CELL * 1.6, Mat.STAR, [Mat.HAT])
	# The star charm on two chain links, hanging from the hook.
	var tip: Vector3 = CROWN[-1][0]
	var l1 := tip + Vector3(0, -0.03, 0)
	var l2 := l1 + Vector3(0, -0.026, 0)
	g.paint(box, func(p: Vector3): return VoxelSdf.torus(p, l1, Vector3(1, 0, 0), 0.014, 0.0062), Mat.BRASS, Tag.HAT, ADD)
	g.paint(box, func(p: Vector3): return VoxelSdf.torus(p, l2, Vector3(0, 0, 1), 0.014, 0.0062), Mat.BRASS, Tag.HAT, ADD)
	var charm := l2 + Vector3(0, -0.05, 0)
	g.paint(box, func(p: Vector3):
		if absf(p.x - charm.x) > FINE_CELL:
			return 1.0
		return -1.0 if wayfinder_star(Vector2(p.z - charm.z, p.y - charm.y), 0.04) else 1.0, Mat.BRASS, Tag.HAT, ADD)
	g.paint(box, func(p: Vector3): return VoxelSdf.sphere(p, charm, 0.009), Mat.STAR, Tag.HAT, PAINT)
	return g


## The hat's extreme points in rest skeleton space, as (x, y, z, radius):
## the brim's rim (underside and turned-up top), the crown's spine, the charm
## and the quill. LyraHatClearance keeps their lowest point off the floor.
static func hat_extremes() -> PackedVector4Array:
	var out := PackedVector4Array()
	for k in 48:
		var a := TAU * k / 48.0
		for r: float in [BRIM_R, BRIM_R * 0.62]:
			var x := sin(a) * r
			var z := cos(a) * r
			var y := brim_base_at(x, z)
			out.append(Vector4(x, y, z, 0.0))
			out.append(Vector4(x, y + FINE_CELL * 5.0, z, 0.0))
	for i in CROWN.size() - 1:
		for k in 4:
			var t := k / 4.0
			var c: Vector3 = (CROWN[i][0] as Vector3).lerp(CROWN[i + 1][0], t)
			out.append(Vector4(c.x, c.y, c.z, lerpf(CROWN[i][1], CROWN[i + 1][1], t) + FINE_CELL))
	var tip: Vector3 = CROWN[-1][0]
	out.append(Vector4(tip.x, tip.y - 0.03, tip.z, 0.022))
	out.append(Vector4(tip.x, tip.y - 0.106, tip.z, 0.046))
	out.append(Vector4(-0.17, 1.89, -0.06, 0.012))
	return out


## A plain eight-point star of radius r (the charm).
static func wayfinder_star(q: Vector2, r: float) -> bool:
	for k in 8:
		var d := Vector2(cos(k * PI / 4.0), sin(k * PI / 4.0))
		var along := q.dot(d)
		var length := r if k % 2 == 0 else r * 0.6
		if along > 0.0 and along < length and absf(q.cross(d)) < 0.3 * r * (1.0 - along / length) + 0.004:
			return true
	return q.length() < r * 0.25


# ------------------------------------------------- stole and clasp (fine grid)

## Front face of the stole where it hangs free.
const STOLE_Z := 0.142


func build_front() -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(-0.2, 0.6, 0.0), Vector3(0.4, 0.7, 0.32)), FINE_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	var robe := func(p: Vector3) -> float: return minf(coat_sdf(p), skirt_sdf(p))
	for side: float in [1.0, -1.0]:
		# A parchment strip lying on the robe front, hard-cut fringed tip.
		var xc := func(y: float) -> float: return 0.102 + (1.27 - y) * 0.035
		g.paint(box, func(p: Vector3):
			var ax := p.x * side
			if ax < 0.0 or p.y > 1.275 or absf(ax - xc.call(p.y)) > 0.034:
				return 1.0
			var tip := 0.66 if posmod(int(floor(ax / FINE_CELL)), 2) == 0 else 0.67
			if p.y < tip:
				return 1.0
			# Lies on the robe over the shoulders and where the skirt flares;
			# in between it hangs as one flat plane.
			var d: float = robe.call(p)
			var on_robe := d > 0.016 and d <= 0.034
			var hangs := p.y < 1.17 and d > 0.004 and p.z >= STOLE_Z - FINE_CELL * 1.6 and p.z < STOLE_Z
			return -1.0 if (on_robe and (p.y >= 1.17 or p.z >= STOLE_Z - FINE_CELL * 1.6)) or hangs else 1.0, Mat.STOLE, Tag.STOLE, ADD)
		# Inked latitude lines and a dashed meridian; the left strip carries a compass rose.
		g.paint_surface(box, func(p: Vector3, c: Vector3i):
			var ax := p.x * side
			if ax < 0.0 or g.mats[g.index(c.x, c.y, c.z)] != Mat.STOLE:
				return false
			var u: float = ax - xc.call(p.y)
			var edge := false
			var latitude := posmod(c.y, 6) == 0 and absf(u) < 0.017
			var meridian := absf(u) < FINE_CELL * 0.5 and posmod(c.y, 3) != 0 and p.y < 0.9
			var rose := false
			if side > 0.0:
				var q := Vector2(u, p.y - 1.0)
				var r := q.length()
				rose = (absf(r - 0.024) < FINE_CELL * 0.55) or (r < 0.03 and (absf(q.x) < FINE_CELL * 0.5 or absf(q.y) < FINE_CELL * 0.5))
				if r < 0.033 and not rose:
					return false
			return edge or latitude or meridian or rose, Mat.INK, [Mat.STOLE])
	# The ink stain on her right glove cuff is on the hand grid; the cape
	# clasp: two brass discs with four rivets each and a short chain.
	var discs: Array[Vector3] = []
	for side: float in [1.0, -1.0]:
		var at := Vector3(0.135 * side, 1.2, _front_z(0.135 * side, 1.2) + 0.026)
		discs.append(at)
		var n := Vector3(0.3 * side, 0.0, 1.0).normalized()
		g.paint(box, func(p: Vector3): return VoxelSdf.cylinder(p, at - n * 0.012, at + n * 0.006, 0.03, 0.03), Mat.BRASS, Tag.TORSO)
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			var q := p - at
			var radial := (q - n * q.dot(n)).length()
			return q.dot(n) > 0.0 and radial > 0.021 and radial < 0.028, Mat.RIVET, [Mat.BRASS])
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			var q := p - at
			var radial := (q - n * q.dot(n)).length()
			return q.dot(n) > 0.0 and radial < 0.012, Mat.ENGRAVE, [Mat.BRASS])
		for k in 4:
			var a := TAU * (k + 0.5) / 4.0
			var u := n.cross(Vector3.UP).normalized()
			var rv := at + n * 0.008 + (u * cos(a) + Vector3.UP * sin(a)) * 0.0175
			g.paint(box, func(p: Vector3): return VoxelSdf.sphere(p, rv, FINE_CELL * 0.75), Mat.RIVET, Tag.TORSO, ADD)
	for k in 5:
		var at := discs[0].lerp(discs[1], (k + 0.5) / 5.0) + Vector3(0, -0.012 - sin((k + 0.5) / 5.0 * PI) * 0.018, 0.004)
		var axis := Vector3(1, 0, 0) if k % 2 == 0 else Vector3(0, 0, 1)
		g.paint(box, func(p: Vector3): return VoxelSdf.torus(p, at, axis, 0.0125, 0.0058), Mat.BRASS, Tag.TORSO, ADD)
	return g


## The coat's front surface z at (x, y).
static func _front_z(x: float, y: float) -> float:
	var z := 0.3
	while z > -0.1 and coat_sdf(Vector3(x, y, z)) > 0.0:
		z -= 0.002
	return z


# ---------------------------------------------------------- scroll cases (fine)

func build_scrolls() -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(-0.32, 0.54, -0.12), Vector3(0.14, 0.33, 0.22)), FINE_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	# Three cases on her right hip, outside the skirt's flare, each hung from
	# the belt on a strap: parchment tubes with brass caps and bands.
	var cases := [[-0.055, 0.2], [0.0, 0.17], [0.055, 0.22]]
	for i in cases.size():
		var z: float = cases[i][0]
		var length: float = cases[i][1]
		var top := Vector3(-0.212, 0.83, z)
		var bottom := Vector3(-skirt_radii(0.83 - length).x - 0.034, 0.83 - length, z)
		var axis := (bottom - top).normalized()
		g.paint(box, func(p: Vector3): return VoxelSdf.cylinder(p, top, bottom, 0.024, 0.024), Mat.SCROLL, Tag.TORSO)
		for cap: Array in [[top, top + axis * 0.024], [bottom - axis * 0.024, bottom + axis * 0.006]]:
			g.paint(box, func(p: Vector3): return VoxelSdf.cylinder(p, cap[0], cap[1], 0.027, 0.027), Mat.BRASS, Tag.TORSO)
		var band := top.lerp(bottom, 0.55)
		g.paint(box, func(p: Vector3): return VoxelSdf.cylinder(p, band - axis * 0.006, band + axis * 0.006, 0.027, 0.027),
			Mat.LEATHER, Tag.TORSO)
		# Strap up to the belt.
		g.paint(box, func(p: Vector3): return VoxelSdf.box(p, top + Vector3(0.004, 0.015, 0), Vector3(0.026, 0.014, 0.008)),
			Mat.LEATHER_DARK, Tag.TORSO, ADD)
		if i == 1:
			# The dented case, re-tied with string.
			var dent := top.lerp(bottom, 0.32) + Vector3(-0.026, 0, 0.0)
			g.paint(box, func(p: Vector3): return VoxelSdf.sphere(p, dent, 0.016), 0, -1, CARVE)
			for k in 3:
				var at := top.lerp(bottom, 0.38 + k * 0.05)
				g.paint(box, func(p: Vector3):
					var q := p - at
					var along := q.dot(axis) - (q.z) * 0.25
					return absf(along) - FINE_CELL * 0.45 if VoxelSdf.cylinder(p, top, bottom, 0.0262, 0.0262) <= 0.0 else 1.0,
					Mat.STRING, Tag.TORSO, PAINT)
	return g


# ---------------------------------------------------------------- hand grids

func build_hand(side: float) -> VoxelGrid:
	var x0 := 0.6 * side
	var x1 := 1.0 * side
	var g := VoxelGrid.new(AABB(Vector3(minf(x0, x1), 1.19, -0.08), Vector3(0.4, 0.15, 0.17)), FINE_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	var prefix := "Left" if side > 0 else "Right"
	var tag := Tag.BRACER_L if side > 0 else Tag.BRACER_R
	var thumb_tag := Tag.THUMB_L if side > 0 else Tag.THUMB_R
	var y := 1.27
	# Leather bracer from mid-forearm to the wrist, planar (octagon) faces.
	g.paint(box, func(p: Vector3):
		var ax := p.x * side
		if ax < 0.6 or ax > 0.775:
			return 1.0
		var r := lerpf(0.05, 0.043, (ax - 0.6) / 0.175)
		return octagon(p.z, p.y - y, r, r), Mat.LEATHER, tag)
	# Wrist strap with a tiny buckle, stitched edges, brass stylus clips.
	g.paint(box, func(p: Vector3):
		var ax := p.x * side
		return octagon(p.z, p.y - y, 0.047, 0.047) if ax > 0.745 and ax < 0.766 else 1.0, Mat.LEATHER_DARK, tag)
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, Vector3(0.756 * side, y, 0.048), Vector3(0.009, 0.011, 0.004)),
		Mat.BRASS, tag, ADD)
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		var ax := p.x * side
		return ax > 0.61 and ax < 0.74 and absf(absf(p.z) - 0.03) < FINE_CELL * 0.5 and p.y > y + 0.02 and c.x % 2 == 0,
		Mat.STITCH, [Mat.LEATHER])
	var stylus_a := Vector3(0.615 * side, y + 0.054, -0.012)
	var stylus_b := Vector3(0.79 * side, y + 0.05, -0.012)
	g.paint(box, func(p: Vector3): return VoxelSdf.capsule(p, stylus_a, stylus_b, 0.0058, 0.0058), Mat.BRASS, tag, ADD)
	g.paint(box, func(p: Vector3): return VoxelSdf.sphere(p, stylus_b, 0.0075), Mat.RIVET, tag, ADD)
	for cx: float in [0.65, 0.72]:
		g.paint(box, func(p: Vector3):
			var ax := p.x * side
			if absf(ax - cx) > FINE_CELL * 0.6:
				return 1.0
			return VoxelSdf.box(p, Vector3(p.x, y + 0.05, -0.012), Vector3(0.01, 0.011, 0.014)), Mat.BRASS, tag, ADD)
	# Fingerless glove over a slim hand (about 1.1x).
	var palm := Vector3(0.845 * side, y - 0.002, 0.0)
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, palm, Vector3(0.05, 0.02, 0.046), 0.012), Mat.GLOVE, tag)
	g.paint(box, func(p: Vector3): return VoxelSdf.capsule(p, Vector3(0.765 * side, y, 0), Vector3(0.81 * side, y, 0), 0.034, 0.036),
		Mat.GLOVE, tag)
	g.paint(box, func(p: Vector3):
		var ax := p.x * side
		return VoxelSdf.box(p, palm + Vector3(0, 0.02, 0), Vector3(0.036, 0.004, 0.034), 0.002) if ax > 0.81 else 1.0,
		Mat.LEATHER_DARK, tag, PAINT)
	for f in 4:
		var chain := PackedVector3Array()
		for part: String in ["Proximal", "Intermediate", "Distal"]:
			var b: Vector3 = rest[StringName(prefix + FINGERS[f] + part)]
			chain.append(Vector3(b.x, b.y, b.z * 0.8))
		chain.append(chain[2] + (chain[2] - chain[1]) * 1.15)
		var ftag := FINGER_BASE + (0 if side > 0 else 4) + f
		var r := 0.0128 if f < 3 else 0.0115
		for i in 3:
			var a := chain[i]
			var b := chain[i + 1]
			g.paint(box, func(p: Vector3): return VoxelSdf.capsule(p, a, b, r, r * 0.92), Mat.SKIN, ftag)
		# The glove covers the proximal segment and its knuckle.
		var a0 := chain[0] - (chain[1] - chain[0]) * 0.3
		var a1 := chain[0].lerp(chain[1], 0.65)
		g.paint(box, func(p: Vector3): return VoxelSdf.capsule(p, a0, a1, r + 0.0015, r + 0.0015), Mat.GLOVE, ftag)
		if side < 0.0 and f == 0:
			# Ink on her right index fingertip.
			var tip := chain[3]
			g.paint(box, func(p: Vector3): return VoxelSdf.sphere(p, tip, 0.016), Mat.INK_STAIN, ftag, PAINT)
	# Thumb: modelled tucked along the index finger, rigid with the hand.
	var root: Vector3 = rest[StringName(prefix + "ThumbMetacarpal")] + Vector3(0.0, -0.006, 0.006)
	var mid := Vector3(0.85 * side, y - 0.024, 0.056)
	var tip := Vector3(0.895 * side, y - 0.026, 0.052)
	g.paint(box, func(p: Vector3): return minf(VoxelSdf.capsule(p, root, mid, 0.017, 0.014),
		VoxelSdf.capsule(p, mid, tip, 0.014, 0.012)), Mat.SKIN, thumb_tag)
	g.paint(box, func(p: Vector3): return VoxelSdf.capsule(p, root, mid, 0.0185, 0.0155), Mat.GLOVE, thumb_tag, PAINT)
	if side < 0.0:
		# Ink spots on the right glove's cuff.
		g.paint_surface(box, func(p: Vector3, c: Vector3i):
			var ax := p.x * side
			return ax > 0.765 and ax < 0.8 and p.z > 0.0 and VoxelSdf.hash3(c, 5) > 0.72, Mat.INK_STAIN, [Mat.GLOVE])
	return g


# ---------------------------------------------------------------- astrolabe

## One astrolabe ring in its own frame (centre at the origin, in the xy plane):
## a square brass band, 24 degree ticks on the rim, and per ring: a sighting
## bar with the emblem engraved (largest), pivot studs (middle), spokes to a
## glowing hub with one tick filed flat (smallest).
func build_ring(i: int) -> VoxelGrid:
	var spec: Vector3 = RINGS[i]
	var big := spec.x + spec.y + 0.08
	var g := VoxelGrid.new(AABB(Vector3(-big, -big, -0.03), Vector3(big * 2.0, big * 2.0, 0.06)), FINE_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	var band := func(p: Vector3) -> float:
		return maxf(absf(Vector2(p.x, p.y).length() - spec.x) - spec.y, absf(p.z) - spec.z)
	g.paint(box, band, Mat.BRASS, Tag.RING)
	for k in 24:
		var a := TAU * k / 24.0
		var d := Vector2(cos(a), sin(a))
		var filed := i == 2 and k == 5
		g.paint(box, func(p: Vector3):
			var q := Vector2(p.x, p.y)
			var along := q.dot(d)
			if absf(q.cross(d)) > FINE_CELL * 0.55 or along < spec.x or absf(p.z) > spec.z:
				return 1.0
			return along - (spec.x + spec.y + (0.0 if filed else FINE_CELL * (1.6 if k % 6 == 0 else 1.0))),
			Mat.BRASS_FILED if filed else Mat.RIVET, Tag.RING, FILL if filed else ADD)
	# Bright worn inner edge.
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		return Vector2(p.x, p.y).length() < spec.x - spec.y + FINE_CELL * 0.8, Mat.RIVET, [Mat.BRASS])
	match i:
		0:
			# Sighting bar riding on top of the ring, two vanes, emblem engraved.
			var c := Vector3(0, spec.x + spec.y + 0.016, 0)
			g.paint(box, func(p: Vector3): return VoxelSdf.box(p, c, Vector3(0.07, 0.016, 0.012)), Mat.BRASS, Tag.RING, ADD)
			for vx: float in [-0.064, 0.064]:
				g.paint(box, func(p: Vector3): return VoxelSdf.box(p, c + Vector3(vx, 0.02, 0), Vector3(0.0055, 0.02, 0.011)),
					Mat.BRASS, Tag.RING, ADD)
			# The emblem, as far as three voxels allow: a star cross, its plumb
			# line running down, and a broken ring of dots.
			g.paint_surface(box, func(p: Vector3, _c: Vector3i):
				var q := Vector2(p.x, p.y - c.y)
				var cross := (absf(q.x) < FINE_CELL * 0.6 and q.y > -0.02) or (absf(q.y) < FINE_CELL * 0.6 and absf(q.x) < 0.014)
				var dots := absf(absf(q.x) - 0.034) < FINE_CELL * 0.6 and absf(q.y) < FINE_CELL * 0.6 and q.x < 0.0
				return p.z > 0.0 and (cross or dots), Mat.ENGRAVE, [Mat.BRASS])
		1:
			for sx: float in [-1.0, 1.0]:
				g.paint(box, func(p: Vector3):
					return VoxelSdf.cylinder(p, Vector3(sx * (spec.x + spec.y), 0, 0), Vector3(sx * (spec.x + spec.y + 0.016), 0, 0), 0.009, 0.009),
					Mat.RIVET, Tag.RING, ADD)
		2:
			for k in 4:
				var a := TAU * (k + 0.5) / 4.0
				var d := Vector3(cos(a), sin(a), 0)
				g.paint(box, func(p: Vector3): return VoxelSdf.capsule(p, d * 0.02, d * spec.x, 0.0055, 0.0055), Mat.BRASS, Tag.RING, ADD)
			g.paint(box, func(p: Vector3): return VoxelSdf.cylinder(p, Vector3(0, 0, -0.012), Vector3(0, 0, 0.012), 0.022, 0.022),
				Mat.BRASS, Tag.RING, ADD)
			g.paint(box, func(p: Vector3): return VoxelSdf.sphere(p, Vector3(0, 0, 0.012), 0.012), Mat.STAR, Tag.RING, FILL)
			g.paint(box, func(p: Vector3): return VoxelSdf.sphere(p, Vector3(0, 0, -0.012), 0.012), Mat.STAR, Tag.RING, FILL)
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
		Tag.STOLE:
			var k := 0.2 * smoothstep(0.8, 0.66, p.y)
			var tmp := {}
			_torso_w(p, tmp, Tag.TORSO)
			for b: StringName in tmp:
				_add(w, b, tmp[b] * (1.0 - k))
			_add(w, &"LeftUpperLeg" if p.x > 0.0 else &"RightUpperLeg", k)
		Tag.ARM_L, Tag.ARM_R:
			_arm_w(p, w, "Left" if tag == Tag.ARM_L else "Right")
		Tag.LEG_L, Tag.LEG_R:
			_leg_w(p, w, "Left" if tag == Tag.LEG_L else "Right")
		Tag.SKIRT:
			# The front and sides follow the thighs; the back (under the cape) far less,
			# so a high kick doesn't tear the back panels.
			# The front panels are cut apart at the split, so each follows its
			# thigh right up to the split edge; the back is one piece, so it
			# blends across the middle.
			# The split is one voxel column wide, centred on SPLIT_X.
			var sx := p.x - SPLIT_X
			var cut := smoothstep(0.0, 0.1, p.z) * smoothstep(0.66, 0.6, p.y)
			var across := smoothstep(0.0, lerpf(0.14, BODY_CELL * 0.5, cut), absf(sx))
			var k := 0.6 * smoothstep(0.8, SKIRT_HEM, p.y) * across * lerpf(0.3, 1.0, smoothstep(-0.12, 0.02, p.z))
			# Right by the top of the split both sides meet, so the legs fade in below it.
			var near_split := smoothstep(0.0, 0.1, p.z) * (1.0 - smoothstep(0.03, 0.12, absf(sx)))
			k *= lerpf(1.0, smoothstep(0.615, 0.5, p.y), near_split)
			_add(w, &"Hips", 1.0 - k)
			_add(w, &"LeftUpperLeg" if sx > 0.0 else &"RightUpperLeg", k)
		Tag.CAPE:
			var chain := _cape_chain()
			var tmp := {}
			_chain_w(Vector3(chain[1].x, p.y, p.z), tmp, chain,
				[&"UpperChest", &"Scarf1", &"Scarf2", &"Scarf3", &"Scarf4", &"Scarf5"])
			# Round the hips the cape rides with the pelvis a little, so a
			# hips-back stance doesn't push the coat through it. Legs and
			# forearms are kept out by LyraCapeClearance swinging the chain.
			var hips := cape_hips_share(p.y)
			for b: StringName in tmp:
				_add(w, b, tmp[b] * (1.0 - hips))
			_add(w, &"Hips", hips)
		Tag.HEAD:
			_add(w, &"Head", 1.0)
		Tag.HAT:
			# Its own bone (added by LyraHatClearance) so the hat can tip off the floor.
			_add(w, HAT_BONE if bones.has(HAT_BONE) else &"Head", 1.0)
		Tag.HAIR:
			_piecewise(p.y, [[1.18, "UpperChest"], [1.31, "Neck"], [1.44, "Head"]], w, true)
		Tag.BRACER_L, Tag.BRACER_R:
			var prefix := "Left" if tag == Tag.BRACER_L else "Right"
			var t := smoothstep(0.76, 0.80, absf(p.x))
			_add(w, StringName(prefix + "LowerArm"), 1.0 - t)
			_add(w, StringName(prefix + "Hand"), t)
		Tag.THUMB_L, Tag.THUMB_R:
			_add(w, &"LeftHand" if tag == Tag.THUMB_L else &"RightHand", 1.0)
		_:
			_add(w, &"UpperChest", 1.0)
	return _pack(w)


## The cape's bone chain (x of the scarf bones; the cape ignores x).
func _cape_chain() -> PackedVector3Array:
	var pts := PackedVector3Array([rest[&"Scarf1"] + Vector3(0, 0.14, 0.0)])
	for b: StringName in [&"Scarf1", &"Scarf2", &"Scarf3", &"Scarf4", &"Scarf5"]:
		pts.append(rest[b])
	pts.append(pts[-1] + (pts[-1] - pts[-2]) * 2.4)
	return pts


func _torso_w(p: Vector3, w: Dictionary, tag: int) -> void:
	var spine := {}
	_piecewise(p.y, [[0.80, "Hips"], [0.90, "Spine"], [1.01, "Chest"], [1.12, "UpperChest"]], spine, false)
	var neck := 0.0
	if tag == Tag.TORSO:
		neck = smoothstep(1.27, 1.34, p.y) * (1.0 - smoothstep(0.05, 0.075, Vector2(p.x, p.z).length()))
	elif tag == Tag.COLLAR:
		neck = 0.3
	var shoulder := smoothstep(0.10, 0.2, absf(p.x)) * smoothstep(1.02, 1.16, p.y)
	for b: StringName in spine:
		_add(w, b, spine[b] * (1.0 - shoulder) * (1.0 - neck))
	_add(w, &"LeftShoulder" if p.x > 0.0 else &"RightShoulder", shoulder * (1.0 - neck))
	_add(w, &"Neck", neck)


func _arm_w(p: Vector3, w: Dictionary, prefix: String) -> void:
	if absf(p.x) < 0.2:
		_torso_w(p, w, Tag.TORSO)
		return
	_piecewise(absf(p.x), [[0.2, prefix + "Shoulder"], [0.31, prefix + "UpperArm"], [0.48, prefix + "UpperArm"],
		[0.60, prefix + "LowerArm"], [0.74, prefix + "LowerArm"], [0.80, prefix + "Hand"]], w, true)


func _leg_w(p: Vector3, w: Dictionary, prefix: String) -> void:
	if p.y >= 0.78:
		_torso_w(p, w, Tag.TORSO)
		return
	var tmp := {}
	_piecewise(p.y, [[0.10, prefix + "Foot"], [0.18, prefix + "LowerLeg"], [0.38, prefix + "LowerLeg"],
		[0.50, prefix + "UpperLeg"], [0.66, prefix + "UpperLeg"], [0.78, "Hips"]], tmp, true)
	var foot := StringName(prefix + "Foot")
	if tmp.has(foot):
		var toes: float = smoothstep(0.09, 0.17, p.z) * tmp[foot]
		tmp[foot] -= toes
		tmp[StringName(prefix + "Toes")] = toes
	for b: StringName in tmp:
		_add(w, b, tmp[b])


func _finger_w(p: Vector3, w: Dictionary, prefix: String, best: String) -> void:
	var pts := PackedVector3Array([rest[StringName(prefix + "Hand")]])
	var names: Array = [StringName(prefix + "Hand")]
	for part: String in ["Proximal", "Intermediate", "Distal"]:
		var b: Vector3 = rest[StringName(prefix + best + part)]
		pts.append(Vector3(b.x, b.y, b.z * 0.8))
		names.append(StringName(prefix + best + part))
	pts.append(pts[3] + (pts[3] - pts[2]) * 1.2)
	_chain_w(p, w, pts, names)
