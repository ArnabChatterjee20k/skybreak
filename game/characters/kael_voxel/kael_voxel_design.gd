class_name KaelVoxelDesign
extends RefCounted
## Voxel Kael (look-dev v1, docs/lookdev/kael.md), built in code on the
## existing humanoid skeleton's rest pose (T-pose, +Z front, his left = +X).
## Three kinds of grid: the body at ~1/82 of his height, and the head and both
## gauntlets at twice that density. Each painted part carries a rig tag that
## decides its skin weights (see weights()).

const BODY_CELL := 0.022
const FINE_CELL := 0.011

enum Mat {
	EMPTY, COAT, COAT_DARK, LAPEL, TRIM, TUNIC, PANTS, SCARF, BOOT, BOOT_CUFF, SOLE,
	HAIR, SKIN, LENS, STRAP, BRASS, RIVET, IRIS, EYE_WHITE, BROW, MOUTH, GLINT,
	STITCH, BELT, GLOVE, LACE, EMBLEM, BLUSH, ENGRAVE, BUCKLE_DARK, SCARF_FOLD,
}
enum Tag {
	TORSO, ARM_L, ARM_R, LEG_L, LEG_R, SKIRT, COLLAR, SCARF_WRAP, SCARF_TAIL, SCARF_FRONT,
	HEAD, GAUNT_L, GAUNT_R, FINGER_L, FINGER_R, THUMB_L, THUMB_R,
}
## Per-finger rig tags: FINGER_BASE + side (0 left, 1 right) * 4 + finger
## (index, middle, ring, little), so a face never blends two fingers.
const FINGER_BASE := 32
const FINGERS: Array[String] = ["Index", "Middle", "Ring", "Little"]
enum Surf { CLOTH, METAL, GLASS, SKIN, GLOW, HAIR }

const COLORS := {
	Mat.COAT: Color(0.11, 0.33, 0.36), Mat.COAT_DARK: Color(0.07, 0.21, 0.24),
	Mat.LAPEL: Color(0.14, 0.40, 0.42), Mat.TRIM: Color(0.76, 0.60, 0.33),
	Mat.TUNIC: Color(0.16, 0.16, 0.18), Mat.PANTS: Color(0.19, 0.20, 0.24),
	Mat.SCARF: Color(0.86, 0.36, 0.11), Mat.SCARF_FOLD: Color(0.70, 0.27, 0.08),
	Mat.BOOT: Color(0.52, 0.30, 0.16),
	Mat.BOOT_CUFF: Color(0.60, 0.37, 0.21), Mat.SOLE: Color(0.15, 0.11, 0.09),
	Mat.HAIR: Color(0.86, 0.88, 0.92), Mat.SKIN: Color(0.96, 0.79, 0.67),
	Mat.LENS: Color(0.95, 0.60, 0.14), Mat.STRAP: Color(0.27, 0.18, 0.12),
	Mat.BRASS: Color(0.72, 0.56, 0.31), Mat.RIVET: Color(0.90, 0.78, 0.52),
	Mat.IRIS: Color(0.12, 0.20, 0.30), Mat.EYE_WHITE: Color(0.96, 0.96, 0.95),
	Mat.BROW: Color(0.55, 0.57, 0.64), Mat.MOUTH: Color(0.55, 0.24, 0.21),
	Mat.GLINT: Color(1.0, 0.97, 0.9), Mat.STITCH: Color(0.32, 0.55, 0.55),
	Mat.BELT: Color(0.34, 0.21, 0.12), Mat.GLOVE: Color(0.30, 0.19, 0.12),
	Mat.LACE: Color(0.82, 0.73, 0.55), Mat.EMBLEM: Color(0.84, 0.68, 0.38),
	Mat.BLUSH: Color(0.97, 0.70, 0.62), Mat.ENGRAVE: Color(0.45, 0.30, 0.12),
	Mat.BUCKLE_DARK: Color(0.25, 0.17, 0.08),
}

const FILL := VoxelGrid.Mode.FILL
const ADD := VoxelGrid.Mode.ADD
const CARVE := VoxelGrid.Mode.CARVE
const PAINT := VoxelGrid.Mode.PAINT

var bones := {}  # name -> index
var rest := {}  # name -> rest position (skeleton space)


func _init(skeleton: Skeleton3D) -> void:
	for i in skeleton.get_bone_count():
		var bone_name := StringName(skeleton.get_bone_name(i))
		bones[bone_name] = i
		rest[bone_name] = skeleton.get_bone_global_rest(i).origin


static func surface_of(mat: int) -> int:
	match mat:
		Mat.TRIM, Mat.BRASS, Mat.RIVET, Mat.EMBLEM, Mat.ENGRAVE, Mat.BUCKLE_DARK:
			return Surf.METAL
		Mat.LENS:
			return Surf.GLASS
		Mat.SKIN, Mat.BLUSH, Mat.MOUTH:
			return Surf.SKIN
		Mat.GLINT, Mat.EYE_WHITE:
			return Surf.GLOW
		Mat.HAIR, Mat.BROW:
			return Surf.HAIR
	return Surf.CLOTH


## Per-voxel colour: base, a few % value noise and a slight hue drift per
## cell, cavity darkening (cool-tinted on hair), lighter worn edges on exposed
## spots of leather, brass and the scarf.
static func color(mat: int, p: Vector3, c: Vector3i, _n: Vector3, occlusion: float, exposure: float) -> Color:
	var base: Color = COLORS.get(mat, Color.MAGENTA)
	var noise := VoxelSdf.hash3(c, mat) * 2.0 - 1.0
	var drift := VoxelSdf.hash3(c, mat + 31) * 2.0 - 1.0
	var col := base * (1.0 + noise * 0.035)
	col = Color.from_hsv(fposmod(col.h + drift * 0.012, 1.0), clampf(col.s * (1.0 + drift * 0.05), 0.0, 1.0), col.v)
	if mat == Mat.SCARF and p.z < -0.1:
		# A touch lighter and warmer toward the tail.
		col = col.lerp(Color(0.93, 0.47, 0.17), clampf((1.2 - p.y) / 0.7, 0.0, 1.0) * 0.45)
	if mat == Mat.COAT:
		# The darker band low in the coat tail's folds.
		col = col.lerp(COLORS[Mat.COAT_DARK], clampf((0.74 - p.y) / 0.2, 0.0, 1.0) * 0.25)
	var tint := Color(0.62, 0.68, 0.86) if mat == Mat.HAIR or mat == Mat.BROW else Color(0.86, 0.82, 0.9)
	var shade := 1.0 - occlusion * 0.6
	col = Color(col.r * lerpf(1.0, tint.r, occlusion), col.g * lerpf(1.0, tint.g, occlusion),
		col.b * lerpf(1.0, tint.b, occlusion)) * shade
	if mat in [Mat.BRASS, Mat.RIVET, Mat.BOOT, Mat.BOOT_CUFF, Mat.TRIM, Mat.SCARF, Mat.BELT, Mat.GLOVE]:
		col = col.lerp(col.lightened(0.35), exposure * 0.7)
	col.a = 1.0
	return col


# ---------------------------------------------------------------- body grid

func build_body() -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(-0.66, -0.01, -0.40), Vector3(1.32, 1.44, 0.74)), BODY_CELL)
	_legs(g)
	_torso(g)
	_skirt(g)
	_arms(g)
	_collar_and_scarf(g)
	_details(g)
	return g


## Coat profile at height y: (half width, half depth, centre z). Broad
## shoulders, a narrow waist and a slight forward lean.
static func coat_profile(y: float) -> Vector3:
	var keys := [
		[0.76, Vector3(0.200, 0.135, 0.000)], [0.84, Vector3(0.182, 0.126, 0.004)],
		[0.93, Vector3(0.162, 0.118, 0.010)], [1.01, Vector3(0.186, 0.128, 0.018)],
		[1.10, Vector3(0.226, 0.146, 0.024)], [1.19, Vector3(0.246, 0.146, 0.018)],
		[1.25, Vector3(0.230, 0.128, 0.010)], [1.29, Vector3(0.150, 0.100, 0.002)],
		[1.31, Vector3(0.080, 0.080, 0.000)],
	]
	if y <= keys[0][0]:
		return keys[0][1]
	for i in keys.size() - 1:
		if y <= keys[i + 1][0]:
			var t := smoothstep(keys[i][0], keys[i + 1][0], y)
			return (keys[i][1] as Vector3).lerp(keys[i + 1][1], t)
	return keys[-1][1]


static func coat_sdf(p: Vector3, inset := 0.0) -> float:
	if p.y < 0.76 or p.y > 1.31:
		return 1.0
	var prof := coat_profile(p.y)
	return VoxelSdf.slice(p.x, p.z - prof.z, prof.x - inset, prof.y - inset, 3.2)


## Half width of the coat's open front (a V from the collar to the belt).
static func opening(y: float) -> float:
	return 0.018 + clampf(y - 0.86, 0.0, 0.5) * 0.24


static func lapel_width(y: float) -> float:
	return 0.035 + clampf(y - 1.0, 0.0, 0.3) * 0.25


func _torso(g: VoxelGrid) -> void:
	var box := AABB(Vector3(-0.3, 0.74, -0.2), Vector3(0.6, 0.6, 0.4))
	# Tunic underneath (it shows in the coat's open front).
	g.paint(box, func(p: Vector3): return coat_sdf(p, 0.024), Mat.TUNIC, Tag.TORSO)
	g.paint(box, func(p: Vector3): return coat_sdf(p), Mat.COAT, Tag.TORSO, ADD)
	# Open the front: the coat's panels part in a V.
	g.paint(box, func(p: Vector3):
		var prof := coat_profile(p.y)
		var inside_v := absf(p.x) < opening(p.y) and p.z > prof.z + 0.02
		return -1.0 if inside_v and coat_sdf(p, 0.024) > 0.0 else 1.0, 0, -1, CARVE)
	# Lapels: folded-back panels one voxel proud beside the opening, chest up.
	var on_lapel := func(p: Vector3) -> bool:
		var prof := coat_profile(p.y)
		var ax := absf(p.x)
		var o := opening(p.y)
		return p.y > 0.98 and p.y < 1.27 and ax >= o and ax <= o + lapel_width(p.y) and p.z > prof.z + 0.04
	g.paint(box, func(p: Vector3): return coat_sdf(p, -BODY_CELL * 1.2) if on_lapel.call(p) else 1.0, Mat.LAPEL, Tag.TORSO, ADD)
	g.paint_surface(box, func(p: Vector3, _c: Vector3i): return on_lapel.call(p), Mat.LAPEL, [Mat.COAT, Mat.LAPEL])
	# Gold trim along the opening edge.
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		var prof := coat_profile(p.y)
		return p.y > 0.8 and p.z > prof.z + 0.03 and absf(absf(p.x) - opening(p.y)) < BODY_CELL * 0.9, Mat.TRIM, [Mat.COAT, Mat.LAPEL])
	# Belt over the coat with a brass buckle (hole and prong).
	var belt_box := AABB(Vector3(-0.25, 0.82, -0.2), Vector3(0.5, 0.1, 0.4))
	g.paint(belt_box, func(p: Vector3):
		if p.y < 0.835 or p.y > 0.895:
			return 1.0
		var prof := coat_profile(p.y)
		return VoxelSdf.slice(p.x, p.z - prof.z, prof.x + 0.012, prof.y + 0.012, 3.2), Mat.BELT, Tag.TORSO)
	var prof_b := coat_profile(0.865)
	var buckle := Vector3(0.0, 0.866, prof_b.y + prof_b.z + 0.012)
	var bb := AABB(buckle - Vector3(0.06, 0.05, 0.04), Vector3(0.12, 0.1, 0.08))
	g.paint(bb, func(p: Vector3): return VoxelSdf.box(p, buckle, Vector3(0.042, 0.036, 0.016), 0.004), Mat.BRASS, Tag.TORSO)
	g.paint(bb, func(p: Vector3): return VoxelSdf.box(p, buckle + Vector3(0, 0, 0.012), Vector3(0.022, 0.016, 0.012)), 0, -1, CARVE)
	g.paint(bb, func(p: Vector3): return VoxelSdf.box(p, buckle + Vector3(0, 0, 0.004), Vector3(0.006, 0.016, 0.01)),
		Mat.BUCKLE_DARK, Tag.TORSO)


func _skirt(g: VoxelGrid) -> void:
	# Coat tails: from the hip to mid-thigh at the back and sides, open at the
	# front, with soft vertical folds; the tunic hem shows in front.
	var box := AABB(Vector3(-0.32, 0.5, -0.25), Vector3(0.64, 0.3, 0.5))
	var bottom_at := func(angle: float) -> float:
		return 0.57 + 0.07 * pow(clampf(absf(angle) / PI, 0.0, 1.0), 2.0)
	g.paint(box, func(p: Vector3):
		if p.y > 0.79:
			return 1.0
		var t := clampf((0.79 - p.y) / 0.22, 0.0, 1.0)
		var angle := atan2(p.x, -p.z)  # 0 at the back
		if p.y < bottom_at.call(angle) or absf(angle) > PI * 0.80:
			return 1.0
		var fold := 1.0 + 0.045 * sin(angle * 7.0) * t
		var rx := (0.200 + 0.05 * t) * fold
		var rz := (0.135 + 0.045 * t) * fold
		var outer := VoxelSdf.slice(p.x, p.z, rx, rz, 2.6)
		var inner := VoxelSdf.slice(p.x, p.z, rx - 0.03, rz - 0.03, 2.6)
		return maxf(outer, -inner), Mat.COAT, Tag.SKIRT)
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		var angle := atan2(p.x, -p.z)
		return p.y < 0.79 and (p.y < bottom_at.call(angle) + BODY_CELL * 1.2 or absf(angle) > PI * 0.80 - 0.07), Mat.TRIM, [Mat.COAT])
	# Tunic hem below the coat's front panels.
	g.paint(box, func(p: Vector3):
		if p.y > 0.80 or p.y < 0.66 + 0.012 * sin(p.x * 60.0):
			return 1.0
		var outer := VoxelSdf.slice(p.x, p.z - 0.004, 0.188, 0.126, 2.6)
		var inner := VoxelSdf.slice(p.x, p.z - 0.004, 0.160, 0.100, 2.6)
		return maxf(outer, -inner), Mat.TUNIC, Tag.SKIRT, ADD)


func _legs(g: VoxelGrid) -> void:
	var box := AABB(Vector3(-0.3, -0.01, -0.2), Vector3(0.6, 0.85, 0.45))
	for side: float in [1.0, -1.0]:
		var tag := Tag.LEG_L if side > 0 else Tag.LEG_R
		var hip := Vector3(0.115 * side, 0.80, 0.0)
		var knee := Vector3(0.132 * side, 0.44, 0.012)
		var shin := Vector3(0.136 * side, 0.32, -0.006)
		g.paint(box, func(p: Vector3):
			return minf(VoxelSdf.capsule(p, hip, knee, 0.098, 0.074), VoxelSdf.capsule(p, knee, shin, 0.074, 0.068)),
			Mat.PANTS, tag)
		# Chunky boots (~1.3x): shaft, a turned-over cuff, foot, toe cap, sole.
		var bx := 0.137 * side
		g.paint(box, func(p: Vector3):
			return VoxelSdf.cylinder(p, Vector3(bx, 0.06, -0.012), Vector3(bx, 0.40, -0.004), 0.084, 0.080), Mat.BOOT, tag)
		g.paint(box, func(p: Vector3):
			return VoxelSdf.cylinder(p, Vector3(bx, 0.37, -0.004), Vector3(bx, 0.45, -0.002), 0.094, 0.101), Mat.BOOT_CUFF, tag)
		g.paint(box, func(p: Vector3):
			if p.y < 0.028:
				return 1.0
			var foot := VoxelSdf.box(p, Vector3(bx, 0.075, 0.05), Vector3(0.078, 0.06, 0.125), 0.045)
			var toe := VoxelSdf.ellipsoid(p, Vector3(bx, 0.07, 0.15), Vector3(0.08, 0.07, 0.085))
			return minf(foot, toe), Mat.BOOT, tag)
		g.paint(box, func(p: Vector3):
			if p.z < 0.115 or p.y < 0.028:
				return 1.0
			return VoxelSdf.ellipsoid(p, Vector3(bx, 0.07, 0.155), Vector3(0.086, 0.076, 0.09)), Mat.BOOT_CUFF, tag)
		g.paint(box, func(p: Vector3): return VoxelSdf.box(p, Vector3(bx, 0.016, 0.055), Vector3(0.088, 0.017, 0.152), 0.03),
			Mat.SOLE, tag)
		# Two straps round the shaft, brass buckles on the outside.
		for sy: float in [0.17, 0.29]:
			g.paint(box, func(p: Vector3):
				return VoxelSdf.cylinder(p, Vector3(bx, sy - 0.018, -0.01), Vector3(bx, sy + 0.018, -0.01), 0.094, 0.094),
				Mat.STRAP, tag)
			var b := Vector3(bx + 0.095 * side, sy, -0.01)
			g.paint(box, func(p: Vector3): return VoxelSdf.box(p, b, Vector3(0.012, 0.026, 0.026)), Mat.BRASS, tag)
			g.paint(box, func(p: Vector3): return VoxelSdf.box(p, b + Vector3(0.008 * side, 0, 0), Vector3(0.008, 0.008, 0.008)),
				Mat.BUCKLE_DARK, tag)
		# Laces criss-crossing the instep.
		g.paint_surface(box, func(p: Vector3, c: Vector3i):
			if absf(p.x - bx) > 0.05 or p.z < 0.06 or p.y < 0.08 or p.y > 0.17:
				return false
			return posmod(c.y + c.x * (1 if side > 0 else -1), 3) == 0, Mat.LACE, [Mat.BOOT, Mat.BOOT_CUFF])


func _arms(g: VoxelGrid) -> void:
	var box := AABB(Vector3(-0.66, 1.08, -0.2), Vector3(1.32, 0.34, 0.4))
	var y := 1.268
	for side: float in [1.0, -1.0]:
		var tag := Tag.ARM_L if side > 0 else Tag.ARM_R
		# Coat sleeve, tapering to the gauntlet cuff.
		g.paint(box, func(p: Vector3):
			return VoxelSdf.capsule(p, Vector3(0.18 * side, y, 0.0), Vector3(0.62 * side, y, 0.0), 0.088, 0.070), Mat.COAT, tag)
		# Shoulder plates: two overlapping brass layers, rims and rivets.
		var top := Vector3(0.265 * side, 1.278, 0.0)
		var top_r := Vector3(0.125, 0.105, 0.145)
		var low := Vector3(0.345 * side, 1.255, 0.0)
		var low_r := Vector3(0.10, 0.098, 0.128)
		var top_cut := func(p: Vector3) -> float: return 1.255 - (absf(p.x) - 0.2) * 0.25
		g.paint(box, func(p: Vector3): return VoxelSdf.ellipsoid(p, top, top_r) if p.y > top_cut.call(p) else 1.0, Mat.BRASS, tag)
		g.paint(box, func(p: Vector3): return VoxelSdf.ellipsoid(p, low, low_r) if p.y > 1.215 else 1.0, Mat.BRASS, tag, ADD)
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			var in_top: bool = VoxelSdf.ellipsoid(p, top, top_r) <= 0.0 and p.y > top_cut.call(p)
			var rim_top: bool = in_top and p.y < top_cut.call(p) + BODY_CELL * 1.1
			var rim_low: bool = not in_top and VoxelSdf.ellipsoid(p, low, low_r) <= 0.0 and p.y < 1.215 + BODY_CELL * 1.1
			return rim_top or rim_low, Mat.ENGRAVE, [Mat.BRASS])
		for k in 5:
			var a := lerpf(-0.95, 0.95, k / 4.0)
			var dir := Vector3(sin(a) * 0.30 * side, 0.82, cos(a) * 0.62).normalized()
			var at := top + dir * top_r
			g.paint(box, func(p: Vector3): return VoxelSdf.sphere(p, at, BODY_CELL * 0.75), Mat.RIVET, tag)
	g.paint_surface(box, func(p: Vector3, _c: Vector3i): return absf(p.x) > 0.585 and absf(p.x) < 0.625, Mat.TRIM, [Mat.COAT])


func _collar_and_scarf(g: VoxelGrid) -> void:
	var box := AABB(Vector3(-0.2, 1.0, -0.36), Vector3(0.4, 0.44, 0.62))
	# Neck.
	g.paint(box, func(p: Vector3): return VoxelSdf.capsule(p, Vector3(0, 1.24, -0.004), Vector3(0, 1.42, 0.0), 0.058, 0.055),
		Mat.SKIN, Tag.TORSO)
	# Stand-up collar, open at the front, gold trim along the top edge.
	var collar_top := func(p: Vector3) -> float: return 1.36 - maxf(p.z, 0.0) * 0.5
	g.paint(box, func(p: Vector3):
		if p.y < 1.24 or p.y > collar_top.call(p) or (p.z > 0.05 and absf(p.x) < 0.06):
			return 1.0
		var flare := (p.y - 1.24) * 0.25
		var outer := VoxelSdf.slice(p.x, p.z + 0.004, 0.118 + flare, 0.108 + flare, 2.0)
		var inner := VoxelSdf.slice(p.x, p.z + 0.004, 0.092 + flare, 0.082 + flare, 2.0)
		return maxf(outer, -inner), Mat.COAT, Tag.COLLAR)
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		return g.tags[g.index(c.x, c.y, c.z)] == Tag.COLLAR and p.y > collar_top.call(p) - BODY_CELL * 1.1, Mat.TRIM, [Mat.COAT])
	# Scarf: a chunky wrap round the neck (lower at the front), a knot at the
	# back-left, a long tail down the back on the scarf bones, and a short end
	# hanging over his right chest.
	var axis := Vector3(0, 1, -0.22).normalized()
	g.paint(box, func(p: Vector3): return VoxelSdf.torus(p, Vector3(0, 1.295, 0.0), axis, 0.104, 0.046), Mat.SCARF, Tag.SCARF_WRAP)
	g.paint(box, func(p: Vector3): return VoxelSdf.ellipsoid(p, Vector3(0.1, 1.285, -0.14), Vector3(0.066, 0.054, 0.05)),
		Mat.SCARF, Tag.SCARF_WRAP)
	var tail := _scarf_points()
	var tail_box := AABB(Vector3(-0.15, 0.36, -0.4), Vector3(0.35, 0.99, 0.3))
	g.paint(tail_box, func(p: Vector3): return _ribbon(p, tail, 0.064, 0.016), Mat.SCARF, Tag.SCARF_TAIL, ADD)
	var front_end := PackedVector3Array([Vector3(-0.055, 1.27, 0.118), Vector3(-0.072, 1.17, 0.17),
		Vector3(-0.084, 1.06, 0.178)])
	g.paint(AABB(Vector3(-0.2, 1.0, 0.05), Vector3(0.25, 0.3, 0.2)), func(p: Vector3): return _ribbon(p, front_end, 0.05, 0.015),
		Mat.SCARF, Tag.SCARF_FRONT, ADD)
	# Fringe: alternate columns hang lower at both ends.
	for end: Vector3 in [tail[-1], front_end[-1]]:
		var end_tag := Tag.SCARF_TAIL if end.z < 0.0 else Tag.SCARF_FRONT
		var hw := 0.062 if end.z < 0.0 else 0.048
		g.paint(AABB(end - Vector3(0.1, 0.08, 0.05), Vector3(0.2, 0.1, 0.1)), func(p: Vector3):
			var col := int(floor((p.x - end.x) / BODY_CELL))
			if posmod(col, 2) != 0 or p.y > end.y:
				return 1.0
			return VoxelSdf.box(p, Vector3(end.x, end.y - 0.02, end.z), Vector3(hw, 0.022, 0.014)), Mat.SCARF, end_tag, ADD)
	# Fold lines along the tail.
	g.paint_surface(tail_box, func(p: Vector3, _c: Vector3i):
		return p.z < -0.17 and p.y < 1.22 and p.y > tail[-1].y + 0.01 \
			and absf(p.x - _tail_x(p.y, tail) + 0.024) < BODY_CELL * 0.55, Mat.SCARF_FOLD, [Mat.SCARF])


func _scarf_points() -> PackedVector3Array:
	var pts := PackedVector3Array()
	for b: StringName in [&"Scarf1", &"Scarf2", &"Scarf3", &"Scarf4", &"Scarf5"]:
		pts.append(rest[b] + Vector3(0.05, 0, 0.03))
	pts.append(pts[-1] + (pts[-1] - pts[-2]) * 0.55)
	return pts


static func _tail_x(y: float, pts: PackedVector3Array) -> float:
	for i in pts.size() - 1:
		if y <= pts[i].y and y >= pts[i + 1].y:
			return lerpf(pts[i].x, pts[i + 1].x, (pts[i].y - y) / (pts[i].y - pts[i + 1].y))
	return pts[-1].x


## A flat band along a polyline (half width across x, half thickness in z),
## with a gentle wave so it reads as cloth.
static func _ribbon(p: Vector3, pts: PackedVector3Array, half_w: float, half_t: float) -> float:
	var best := 1e9
	for i in pts.size() - 1:
		var a := pts[i]
		var ab := pts[i + 1] - a
		var h := (p - a).dot(ab) / ab.dot(ab)
		if h < 0.0 or h > 1.0:
			continue
		var q := p - (a + ab * h)
		var wave := sin((a.y + ab.y * h) * 22.0) * 0.008
		best = minf(best, maxf(absf(q.x) - half_w, absf(q.z - wave) - half_t))
	return best


func _details(g: VoxelGrid) -> void:
	var box := AABB(Vector3(-0.3, 0.6, -0.25), Vector3(0.6, 0.75, 0.5))
	# Stitched seams (dashed, lighter thread): coat sides, back centre, sleeves.
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		if g.mats[g.index(c.x, c.y, c.z)] != Mat.COAT:
			return false
		var prof := coat_profile(clampf(p.y, 0.76, 1.31))
		var side_seam := p.y < 1.2 and absf(p.z - prof.z) < BODY_CELL * 0.6 and absf(p.x) > 0.12
		var back_seam := p.y < 1.0 and p.y > 0.62 and absf(p.x) < BODY_CELL * 0.5 and p.z < 0.0
		return (side_seam or back_seam) and c.y % 2 == 0, Mat.STITCH)
	g.paint_surface(AABB(Vector3(-0.62, 1.15, -0.1), Vector3(1.24, 0.12, 0.2)), func(p: Vector3, c: Vector3i):
		return g.mats[g.index(c.x, c.y, c.z)] == Mat.COAT and absf(p.x) > 0.36 and absf(p.x) < 0.58 \
			and p.y < 1.21 and absf(p.z) < BODY_CELL * 0.6 and c.x % 2 == 0, Mat.STITCH)
	# Winged-sky sigil on the coat's back: a ring (the sky) with a centre dot
	# and three stepped feathers per side. Original design.
	var centre := Vector2(-0.05, 1.06)
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		if p.z > -0.05 or g.mats[g.index(c.x, c.y, c.z)] != Mat.COAT:
			return false
		var q := (Vector2(p.x, p.y) - centre) / BODY_CELL
		var r := q.length()
		if (r > 1.6 and r < 3.1) or r < 0.9:
			return true
		var ax := absf(q.x)
		for f in 2:
			var x0 := 3.9 + f * 1.7
			var top := 1.8 - f * 0.9
			if absf(ax - x0) < 0.8 and q.y < top and q.y > top - 3.8 + f * 0.7:
				return true
		return false, Mat.EMBLEM)


# ---------------------------------------------------------------- head grid

func build_head() -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(-0.27, 1.32, -0.31), Vector3(0.54, 0.58, 0.56)), FINE_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	var t := Tag.HEAD
	# Skull and jaw: a rounded cranium blended into a softer, narrower jaw.
	g.paint(box, func(p: Vector3):
		var cranium := VoxelSdf.ellipsoid(p, Vector3(0, 1.556, -0.004), Vector3(0.132, 0.150, 0.146))
		var jaw := VoxelSdf.ellipsoid(p, Vector3(0, 1.47, 0.026), Vector3(0.108, 0.098, 0.118))
		return VoxelSdf.smooth_union(cranium, jaw, 0.04), Mat.SKIN, t)
	for s: float in [1.0, -1.0]:
		g.paint(box, func(p: Vector3): return VoxelSdf.ellipsoid(p, Vector3(0.132 * s, 1.515, -0.004), Vector3(0.022, 0.036, 0.03)),
			Mat.SKIN, t)
	# Nose: a small ridge.
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, Vector3(0, 1.478, 0.152), Vector3(0.008, 0.016, 0.01)), Mat.SKIN, t, ADD)
	# Eyes: big and readable; white, a dark iris, a glint, and brows.
	for s: float in [1.0, -1.0]:
		var e := Vector2(0.054 * s, 1.512)
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			return p.z > 0.07 and Vector2((p.x - e.x) / 0.028, (p.y - e.y) / 0.036).length() < 1.0, Mat.EYE_WHITE, [Mat.SKIN])
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			return p.z > 0.07 and Vector2((p.x - e.x + 0.006 * s) / 0.021, (p.y - e.y + 0.002) / 0.033).length() < 1.0,
			Mat.IRIS, [Mat.EYE_WHITE, Mat.SKIN])
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			return p.z > 0.07 and absf(p.x - e.x) < 0.03 and p.y > e.y + 0.028 and p.y < e.y + 0.042, Mat.BROW, [Mat.SKIN, Mat.EYE_WHITE, Mat.IRIS])
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			return p.z > 0.07 and absf(p.x - e.x + 0.008 * s) < 0.006 and absf(p.y - e.y - 0.012) < 0.006, Mat.GLINT, [Mat.IRIS])
		# Brows: thick, angled up toward the outside (determined, brave).
		g.paint(box, func(p: Vector3):
			var along := (p.x * s - 0.022) / 0.07
			if along < 0.0 or along > 1.0:
				return 1.0
			return VoxelSdf.box(p, Vector3(p.x, 1.568 + along * 0.014, 0.142 - along * 0.018), Vector3(0.1, 0.0075, 0.012)),
			Mat.BROW, t)
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			return p.z > 0.07 and Vector2((p.x - 0.07 * s) / 0.024, (p.y - 1.468) / 0.014).length() < 1.0, Mat.BLUSH, [Mat.SKIN])
	# Mouth: a small lopsided smirk.
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		var curve := 1.432 + (0.006 if p.x > 0.008 else 0.0)
		return p.z > 0.07 and p.x > -0.022 and p.x < 0.026 and absf(p.y - curve) < 0.0055, Mat.MOUTH, [Mat.SKIN])
	_hair(g, box)
	_goggles(g, box)
	return g


func _hair(g: VoxelGrid, box: AABB) -> void:
	var t := Tag.HEAD
	g.paint(box, func(p: Vector3):
		# Keep the face clear below the hairline (sideburns at the sides).
		if p.z > 0.04 and p.y < 1.598 - maxf(0.0, p.z - 0.04) * 0.25 and absf(p.x) < 0.112:
			return 1.0
		if p.y < 1.46 and p.z > -0.02:
			return 1.0
		var mass := VoxelSdf.ellipsoid(p, Vector3(0, 1.605, -0.016), Vector3(0.152, 0.13, 0.162))
		var back := VoxelSdf.ellipsoid(p, Vector3(0, 1.53, -0.058), Vector3(0.142, 0.12, 0.118))
		return minf(mass, back), Mat.HAIR, t)
	# Chunky curved locks (start, bend, tip, root radius): a quiff rising off
	# the forehead and sweeping back, locks swept back over the crown and out
	# at the sides, back locks falling to the nape, and bangs beside the
	# goggles. Two thinner strands break the silhouette.
	var locks := [
		[Vector3(0.0, 1.66, 0.09), Vector3(0.012, 1.77, 0.07), Vector3(0.0, 1.80, -0.03), 0.056],
		[Vector3(0.05, 1.71, 0.0), Vector3(0.085, 1.79, -0.06), Vector3(0.075, 1.80, -0.17), 0.052],
		[Vector3(-0.06, 1.70, 0.0), Vector3(-0.095, 1.775, -0.07), Vector3(-0.10, 1.77, -0.18), 0.05],
		[Vector3(0.0, 1.68, -0.10), Vector3(0.0, 1.715, -0.19), Vector3(0.012, 1.66, -0.26), 0.052],
		[Vector3(0.12, 1.64, 0.0), Vector3(0.172, 1.675, -0.06), Vector3(0.195, 1.64, -0.145), 0.042],
		[Vector3(-0.12, 1.63, 0.01), Vector3(-0.176, 1.665, -0.05), Vector3(-0.205, 1.625, -0.135), 0.042],
		[Vector3(0.07, 1.58, -0.12), Vector3(0.11, 1.53, -0.19), Vector3(0.12, 1.465, -0.21), 0.042],
		[Vector3(-0.07, 1.57, -0.12), Vector3(-0.11, 1.52, -0.18), Vector3(-0.13, 1.46, -0.19), 0.042],
		[Vector3(0.085, 1.645, 0.10), Vector3(0.106, 1.60, 0.142), Vector3(0.112, 1.548, 0.14), 0.03],
		[Vector3(-0.09, 1.635, 0.10), Vector3(-0.11, 1.585, 0.136), Vector3(-0.118, 1.532, 0.13), 0.03],
		[Vector3(0.0, 1.665, 0.12), Vector3(0.012, 1.625, 0.162), Vector3(-0.008, 1.588, 0.166), 0.026],
	]
	for lock: Array in locks:
		_lock(g, box, lock[0], lock[1], lock[2], lock[3], 0.016)
	_lock(g, box, Vector3(0.03, 1.78, -0.04), Vector3(-0.02, 1.85, -0.02), Vector3(-0.065, 1.865, 0.045), 0.022, 0.011)
	_lock(g, box, Vector3(0.12, 1.74, -0.08), Vector3(0.18, 1.80, -0.085), Vector3(0.235, 1.80, -0.04), 0.022, 0.011)


## A hair lock: a tapered tube along a quadratic curve.
func _lock(g: VoxelGrid, box: AABB, a: Vector3, bend: Vector3, tip: Vector3, r0: float, r1: float) -> void:
	var pts := PackedVector3Array()
	for k in 7:
		var u := k / 6.0
		pts.append(a.lerp(bend, u).lerp(bend.lerp(tip, u), u))
	g.paint(box, func(p: Vector3):
		var best := 1e9
		for i in 6:
			best = minf(best, VoxelSdf.capsule(p, pts[i], pts[i + 1], lerpf(r0, r1, i / 6.0), lerpf(r0, r1, (i + 1) / 6.0)))
		return best, Mat.HAIR, Tag.HEAD)


func _goggles(g: VoxelGrid, box: AABB) -> void:
	var t := Tag.HEAD
	# Strap round the head, tilted: high on the forehead, lower at the back.
	var strap_n := Vector3(0, 1, -0.32).normalized()
	var strap_at := Vector3(0, 1.648, 0.0)
	g.paint(box, func(p: Vector3):
		var band := absf((p - strap_at).dot(strap_n)) - 0.017
		var outer := VoxelSdf.ellipsoid(p, Vector3(0, 1.6, -0.012), Vector3(0.166, 0.15, 0.176))
		var inner := VoxelSdf.ellipsoid(p, Vector3(0, 1.6, -0.012), Vector3(0.150, 0.134, 0.160))
		return maxf(maxf(band, outer), -inner), Mat.STRAP, t)
	# Two lens cups pushed up on the forehead, looking forward and up.
	var look := Vector3(0, 0.42, 0.91).normalized()
	for s: float in [1.0, -1.0]:
		var base := Vector3(0.058 * s, 1.64, 0.112)
		var front := base + look * 0.05
		g.paint(box, func(p: Vector3): return VoxelSdf.cylinder(p, base, front, 0.046, 0.05), Mat.BRASS, t)
		g.paint(box, func(p: Vector3): return VoxelSdf.cylinder(p, front - look * 0.012, front + look * 0.004, 0.036, 0.036), 0, -1, CARVE)
		g.paint(box, func(p: Vector3): return VoxelSdf.cylinder(p, front - look * 0.016, front - look * 0.004, 0.037, 0.037), Mat.LENS, t)
		# Bright rim ring.
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			var q := p - front
			var along := q.dot(look)
			var radial := (q - look * along).length()
			return along > -0.008 and radial > 0.039 and radial < 0.053, Mat.RIVET, [Mat.BRASS])
		# Rivets on the cup sides.
		for a: float in [0.5, 2.6]:
			var at := base + look * 0.026 + Vector3(0.05 * cos(a) * s, 0.048 * sin(a), 0)
			g.paint(box, func(p: Vector3): return VoxelSdf.sphere(p, at, FINE_CELL * 0.8), Mat.RIVET, t, ADD)
		# A glint on each lens.
		g.paint(box, func(p: Vector3):
			var q := p - (front - look * 0.01)
			var along := q.dot(look)
			if absf(along) > 0.008:
				return 1.0
			var off := q - look * along
			return VoxelSdf.sphere(off, Vector3(-0.014 * s, 0.012, 0.0), FINE_CELL * 1.0), Mat.GLINT, t, PAINT)
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, Vector3(0, 1.654, 0.142), Vector3(0.016, 0.009, 0.012)), Mat.BRASS, t)


# ------------------------------------------------------------ gauntlet grids

func build_gauntlet(side: float) -> VoxelGrid:
	var x0 := 0.56 * side
	var x1 := 1.06 * side
	var bounds := AABB(Vector3(minf(x0, x1), 1.13, -0.16), Vector3(0.5, 0.28, 0.32))
	var g := VoxelGrid.new(bounds, FINE_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	var prefix := "Left" if side > 0 else "Right"
	var tag := Tag.GAUNT_L if side > 0 else Tag.GAUNT_R
	var thumb_tag := Tag.THUMB_L if side > 0 else Tag.THUMB_R
	var y := 1.268
	# Big flared cuff (a bell) from mid-forearm to the wrist, lip and band.
	g.paint(box, func(p: Vector3): return VoxelSdf.cylinder(p, Vector3(0.6 * side, y, 0), Vector3(0.785 * side, y, 0), 0.094, 0.094),
		Mat.BRASS, tag)
	g.paint(box, func(p: Vector3): return VoxelSdf.cylinder(p, Vector3(0.585 * side, y, 0), Vector3(0.612 * side, y, 0), 0.108, 0.108),
		Mat.RIVET, tag)
	g.paint(box, func(p: Vector3): return VoxelSdf.cylinder(p, Vector3(0.68 * side, y, 0), Vector3(0.696 * side, y, 0), 0.1, 0.1),
		Mat.BRASS, tag)
	# Rivets round the cuff in two rings.
	for ring_x: float in [0.645, 0.74]:
		for k in 6:
			var a := TAU * (k + (0.5 if ring_x > 0.7 else 0.0)) / 6.0
			var r := 0.098
			var at := Vector3(ring_x * side, y + cos(a) * r, sin(a) * r)
			g.paint(box, func(p: Vector3): return VoxelSdf.sphere(p, at, FINE_CELL * 0.85), Mat.RIVET, tag)
	# Engraved lightning bolt on top of the cuff (storm-knight mark).
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		if p.y < y + 0.05:
			return false
		var u := (absf(p.x) - 0.62) / 0.15
		var bolt_z := 0.03 - u * 0.06 + (0.03 if u > 0.45 else 0.0)
		return u > 0.1 and u < 0.9 and absf(p.z - bolt_z) < FINE_CELL * 0.9, Mat.ENGRAVE, [Mat.BRASS])
	# Hand: a leather glove, palm block about 1.4x.
	var palm := Vector3(0.842 * side, y + 0.002, 0.0)
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, palm, Vector3(0.056, 0.034, 0.072), 0.018), Mat.GLOVE, tag)
	# Back-of-hand plate and a knuckle guard with four bumps.
	g.paint(box, func(p: Vector3): return VoxelSdf.box(p, palm + Vector3(0.0, 0.03, 0.0), Vector3(0.05, 0.012, 0.066), 0.01),
		Mat.BRASS, tag)
	# Fingers: chunky gloved fingers; the back of each segment is plated in
	# brass (recoloured, not an extra shell, so curled fingers stay solid) with
	# a dark seam at every joint.
	for f in 4:
		var chain := PackedVector3Array()
		for part: String in ["Proximal", "Intermediate", "Distal"]:
			chain.append(rest[StringName(prefix + FINGERS[f] + part)])
		chain.append(chain[2] + (chain[2] - chain[1]) * 1.1)
		_plated_digit(g, box, chain, 0.0185, 0.0172, FINGER_BASE + (0 if side > 0 else 4) + f)
		# Knuckle guard: a raised brass block and rivet over each knuckle, on
		# that finger (so it stays on the knuckle when the hand closes).
		var knuckle := chain[0] + Vector3(0.006 * side, 0.016, 0.0)
		var ftag := FINGER_BASE + (0 if side > 0 else 4) + f
		g.paint(box, func(p: Vector3): return VoxelSdf.box(p, knuckle, Vector3(0.016, 0.009, 0.0155), 0.004),
			Mat.BRASS, ftag, ADD)
		g.paint(box, func(p: Vector3): return VoxelSdf.sphere(p, knuckle + Vector3(0, 0.011, 0), FINE_CELL * 0.8),
			Mat.RIVET, ftag, ADD)
	# Thumb: modelled already tucked, lying along the underside of the index
	# finger's first segment, and rigid with the hand (the clips' thumb bones
	# splay it). When the fingers curl it sits across the front of the fist.
	# Gold, with a seam at the joint and a glove underside.
	var root: Vector3 = rest[StringName(prefix + "ThumbMetacarpal")] + Vector3(0.0, -0.008, 0.012)
	var mid := Vector3(0.872 * side, y - 0.03, 0.074)
	var tip := Vector3(0.93 * side, y - 0.032, 0.066)
	g.paint(box, func(p: Vector3): return minf(VoxelSdf.capsule(p, root, mid, 0.024, 0.021),
		VoxelSdf.capsule(p, mid, tip, 0.021, 0.019)), Mat.BRASS, thumb_tag)
	g.paint(box, func(p: Vector3):
		return VoxelSdf.sphere(p, mid, 0.024) if absf(absf(p.x) - absf(mid.x)) < FINE_CELL * 0.6 else 1.0,
		Mat.ENGRAVE, thumb_tag, PAINT)
	g.paint(box, func(p: Vector3):
		if p.y > root.y - 0.012:
			return 1.0
		return minf(VoxelSdf.capsule(p, root, mid, 0.025, 0.022), VoxelSdf.capsule(p, mid, tip, 0.022, 0.02)),
		Mat.GLOVE, thumb_tag, PAINT)
	return g


func _plated_digit(g: VoxelGrid, box: AABB, chain: PackedVector3Array, r0: float, r1: float, tag: int) -> void:
	for i in chain.size() - 1:
		var a := chain[i]
		var b := chain[i + 1]
		g.paint(box, func(p: Vector3): return VoxelSdf.capsule(p, a, b, r0, r1), Mat.GLOVE, tag)
	for i in chain.size() - 1:
		var a := chain[i]
		var b := chain[i + 1]
		var axis := (b - a).normalized()
		g.paint(box, func(p: Vector3):
			var along := (p - a).dot(axis) / a.distance_to(b)
			if along < 0.0 or along > 1.0 or p.y < a.lerp(b, along).y + 0.002:
				return 1.0
			return VoxelSdf.capsule(p, a, b, r0 + 0.002, r1 + 0.002), Mat.BRASS, tag, PAINT)
		if i > 0:
			g.paint(box, func(p: Vector3):
				var along := (p - a).dot(axis)
				if absf(along) > FINE_CELL * 0.55 or p.y < a.y + 0.002:
					return 1.0
				return VoxelSdf.sphere(p, a, r0 + 0.004), Mat.ENGRAVE, tag, PAINT)


# ----------------------------------------------------------------- weights

## Skin weights for a vertex at p of a part tagged tag: [bones, weights].
func weights(tag: int, p: Vector3) -> Array:
	var w := {}
	if tag >= FINGER_BASE:
		var k := tag - FINGER_BASE
		_finger_w(p, w, "Left" if k < 4 else "Right", FINGERS[k % 4])
		return _pack(w)
	match tag:
		Tag.TORSO, Tag.COLLAR, Tag.SCARF_WRAP, Tag.SCARF_FRONT:
			_torso_w(p, w, tag)
		Tag.ARM_L, Tag.ARM_R:
			_arm_w(p, w, "Left" if tag == Tag.ARM_L else "Right")
		Tag.LEG_L, Tag.LEG_R:
			_leg_w(p, w, "Left" if tag == Tag.LEG_L else "Right")
		Tag.SKIRT:
			var k := 0.45 * smoothstep(0.78, 0.56, p.y) * smoothstep(0.0, 0.12, absf(p.x))
			_add(w, &"Hips", 1.0 - k)
			_add(w, &"LeftUpperLeg" if p.x > 0.0 else &"RightUpperLeg", k)
		Tag.SCARF_TAIL:
			var pts := _scarf_points()
			pts.insert(0, Vector3(0.1, 1.32, -0.15))
			_chain_w(p, w, pts, [&"UpperChest", &"Scarf1", &"Scarf2", &"Scarf3", &"Scarf4", &"Scarf5"])
		Tag.HEAD:
			_add(w, &"Head", 1.0)
		Tag.GAUNT_L, Tag.GAUNT_R:
			var prefix := "Left" if tag == Tag.GAUNT_L else "Right"
			var t := smoothstep(0.75, 0.80, absf(p.x))
			_add(w, StringName(prefix + "LowerArm"), 1.0 - t)
			_add(w, StringName(prefix + "Hand"), t)
		Tag.THUMB_L, Tag.THUMB_R:
			# Rigid with the hand: the current clips splay the thumb sideways
			# (authored for the old, smaller thumb), which cuts through the
			# plated fist. Laid along the side of the fist it reads cleanly.
			_add(w, &"LeftHand" if tag == Tag.THUMB_L else &"RightHand", 1.0)
	return _pack(w)


func _torso_w(p: Vector3, w: Dictionary, tag: int) -> void:
	var spine := {}
	_piecewise(p.y, [[0.80, "Hips"], [0.90, "Spine"], [1.01, "Chest"], [1.12, "UpperChest"]], spine, false)
	# The neck column alone follows the neck bone; the collar and the scarf wrap a little.
	var neck := 0.0
	if tag == Tag.TORSO:
		neck = smoothstep(1.27, 1.34, p.y) * (1.0 - smoothstep(0.06, 0.09, Vector2(p.x, p.z).length()))
	elif tag == Tag.COLLAR or tag == Tag.SCARF_WRAP:
		neck = 0.3
	var shoulder := smoothstep(0.10, 0.22, absf(p.x)) * smoothstep(1.02, 1.16, p.y)
	for b: StringName in spine:
		_add(w, b, spine[b] * (1.0 - shoulder) * (1.0 - neck))
	_add(w, &"LeftShoulder" if p.x > 0.0 else &"RightShoulder", shoulder * (1.0 - neck))
	_add(w, &"Neck", neck)


func _arm_w(p: Vector3, w: Dictionary, prefix: String) -> void:
	if absf(p.x) < 0.22:
		_torso_w(p, w, Tag.TORSO)
		return
	_piecewise(absf(p.x), [[0.22, prefix + "Shoulder"], [0.32, prefix + "UpperArm"], [0.48, prefix + "UpperArm"],
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
		pts.append(rest[StringName(prefix + best + part)])
		names.append(StringName(prefix + best + part))
	pts.append(pts[3] + (pts[3] - pts[2]) * 1.2)
	_chain_w(p, w, pts, names)


## Blends between keyed bones along x (keys ascending: [x, bone name]).
static func _piecewise(x: float, keys: Array, w: Dictionary, smooth: bool) -> void:
	var add := func(bone: String, amount: float) -> void:
		var b := StringName(bone)
		w[b] = w.get(b, 0.0) + amount
	if x <= keys[0][0]:
		add.call(keys[0][1], 1.0)
		return
	for i in keys.size() - 1:
		if x <= keys[i + 1][0]:
			var t: float = (x - keys[i][0]) / (keys[i + 1][0] - keys[i][0])
			if smooth:
				t = smoothstep(0.0, 1.0, t)
			add.call(keys[i][1], 1.0 - t)
			add.call(keys[i + 1][1], t)
			return
	add.call(keys[-1][1], 1.0)


## Points p0..pn with bone i owning segment i; blends half-way at each joint.
static func _chain_w(p: Vector3, w: Dictionary, pts: PackedVector3Array, names: Array) -> void:
	var best := 0
	var best_f := 0.0
	var best_d := INF
	for i in pts.size() - 1:
		var ab := pts[i + 1] - pts[i]
		var f := clampf((p - pts[i]).dot(ab) / ab.dot(ab), 0.0, 1.0)
		var d := p.distance_squared_to(pts[i] + ab * f)
		if d < best_d:
			best_d = d
			best = i
			best_f = f
	best = mini(best, names.size() - 1)
	var next := 0.0
	var prev := 0.0
	if best_f > 0.7 and best + 1 < names.size():
		next = 0.5 * (best_f - 0.7) / 0.3
		w[names[best + 1]] = w.get(names[best + 1], 0.0) + next
	if best_f < 0.3 and best > 0:
		prev = 0.5 * (0.3 - best_f) / 0.3
		w[names[best - 1]] = w.get(names[best - 1], 0.0) + prev
	w[names[best]] = w.get(names[best], 0.0) + 1.0 - next - prev


static func _add(w: Dictionary, bone: StringName, amount: float) -> void:
	if amount > 0.0001:
		w[bone] = w.get(bone, 0.0) + amount


func _pack(w: Dictionary) -> Array:
	var pairs := []
	for b: StringName in w:
		pairs.append([w[b], bones[b]])
	pairs.sort_custom(func(a, b): return a[0] > b[0])
	var ids := PackedInt32Array([0, 0, 0, 0])
	var ws := PackedFloat32Array([0, 0, 0, 0])
	var total := 0.0
	for i in mini(4, pairs.size()):
		total += pairs[i][0]
	for i in mini(4, pairs.size()):
		ids[i] = pairs[i][1]
		ws[i] = pairs[i][0] / total
	return [ids, ws]
