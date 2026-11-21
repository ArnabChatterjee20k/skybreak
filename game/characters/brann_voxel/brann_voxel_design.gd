class_name BrannVoxelDesign
extends VoxelDesign
## Voxel Brann (docs/lookdev/brann.md), a client of the voxel kit
## (game/characters/voxel_kit/README.md), built in code on BrannFigure's rest
## pose (T-pose, +Z front, his left = +X). A stone-forged smith: faceted
## stone torso, boulder pauldrons with moss, anvil fists, a braided ember-red
## beard and a leather apron. Ember cracks are grooves with GLOW at the bottom.
## Grids: the body at 2.2 cm; boulders, forearms + fists and the lower beard
## + braid at 1.1 cm; the head and the belt front (buckle, pocket tools) at 8.5 mm.

const BODY_CELL := 0.022
const FINE_CELL := 0.011
const HEAD_CELL := 0.0085
## GLOW's base emission; BrannVoxelView finds the surface by it and pulses it.
const GLOW_EMISSION := 2.0

enum Mat {
	EMPTY, STONE, STONE_DARK, BOULDER, BOULDER_DARK, MOSS, MOSS_DARK, LICHEN, FLOWER, FLOWER_CORE,
	LEATHER, LEATHER_DARK, PATCH, BRAND, STITCH, BURN, SCORCH, BELT, TROUSER, TROUSER_DARK,
	IRON, IRON_NEW, RIVET, SOLE, BEARD, BEARD_DARK, EMBER_CORE, EMBER, EMBER_DIM, PUPIL, GLINT,
	MOUTH, WOOD, BUCKLE_DARK, BOOT,
}
enum Tag {
	TORSO, NECK, ARM_L, ARM_R, LEG_L, LEG_R, APRON, BOULDER_L, BOULDER_R, HEAD, BEARD, BRAID,
	GAUNT_L, GAUNT_R, THUMB_L, THUMB_R, FOOT_L, FOOT_R,
}
## The braid's chain: one bone per segment, the first parented to the head.
## BrannBraidBones adds them to the rig; BrannVoxelView swings them.
const BRAID_BONES: Array[StringName] = [&"Braid1", &"Braid2", &"Braid3"]
## Per-finger rig tags: FINGER_BASE + side (0 left, 1 right) * 4 + finger.
const FINGER_BASE := 32
const FINGERS: Array[String] = ["Index", "Middle", "Ring", "Little"]

const COLORS := {
	Mat.STONE: Color("6e6a6c"), Mat.STONE_DARK: Color("524e55"),
	Mat.BOULDER: Color("57545a"), Mat.BOULDER_DARK: Color("403d45"),
	Mat.MOSS: Color("5e7a42"), Mat.MOSS_DARK: Color("46602f"), Mat.LICHEN: Color("8f9470"),
	Mat.FLOWER: Color("ecebe2"), Mat.FLOWER_CORE: Color("d9b84a"),
	Mat.LEATHER: Color("4a2c1e"), Mat.LEATHER_DARK: Color("361f15"), Mat.PATCH: Color("6a4630"),
	Mat.BRAND: Color("2a170f"), Mat.STITCH: Color("8a6a4c"), Mat.BURN: Color("1c110c"),
	Mat.SCORCH: Color("33201a"), Mat.BELT: Color("3a2317"),
	Mat.TROUSER: Color("343a4c"), Mat.TROUSER_DARK: Color("272c3b"),
	Mat.IRON: Color("35353b"), Mat.IRON_NEW: Color("7a7a82"), Mat.RIVET: Color("5a5a62"),
	Mat.SOLE: Color("1e1e22"), Mat.BOOT: Color("3e271b"),
	Mat.BEARD: Color("c2361c"), Mat.BEARD_DARK: Color("9a2a14"),
	Mat.EMBER_CORE: Color("ffd9a0"), Mat.EMBER: Color("ff4a12"), Mat.EMBER_DIM: Color("9a2008"),
	Mat.PUPIL: Color("1a0d08"), Mat.GLINT: Color("fff6e8"), Mat.MOUTH: Color("2a1612"),
	Mat.WOOD: Color("6b4a30"), Mat.BUCKLE_DARK: Color("1e1e22"),
}
## Each material's shadow tone (the sheet's palette); cavities lean toward it.
const SHADOWS := {
	Mat.STONE: Color("45414a"), Mat.STONE_DARK: Color("38343e"),
	Mat.BOULDER: Color("343239"), Mat.BOULDER_DARK: Color("29272e"),
	Mat.MOSS: Color("3a4e2a"), Mat.MOSS_DARK: Color("2c3b20"), Mat.LICHEN: Color("5c604a"),
	Mat.LEATHER: Color("2c1a12"), Mat.LEATHER_DARK: Color("22140d"), Mat.PATCH: Color("442c1e"),
	Mat.BELT: Color("22140d"), Mat.TROUSER: Color("1f2330"), Mat.TROUSER_DARK: Color("181b26"),
	Mat.IRON: Color("1e1e22"), Mat.IRON_NEW: Color("4a4a52"), Mat.RIVET: Color("2a2a30"),
	Mat.BEARD: Color("7e2010"), Mat.BEARD_DARK: Color("5e180c"), Mat.BOOT: Color("24160f"),
	Mat.WOOD: Color("44301f"),
}
## Value noise per material (sheet: 3% on stone and apron panels, up to 6% on moss, iron, straps;
## the big stone torso and denim legs stay at about 2% so they never read as speckle).
const NOISE := {
	Mat.STONE: 0.022, Mat.BOULDER: 0.03, Mat.LEATHER: 0.03, Mat.TROUSER: 0.02, Mat.BEARD: 0.04,
	Mat.MOSS: 0.06, Mat.MOSS_DARK: 0.06, Mat.IRON: 0.06, Mat.IRON_NEW: 0.04, Mat.BELT: 0.06,
	Mat.LICHEN: 0.06, Mat.BOOT: 0.05,
}
const WEARS := [Mat.IRON, Mat.RIVET, Mat.BELT, Mat.BOOT, Mat.PATCH, Mat.WOOD]
const IRON_WEAR := Color("6a6a72")

## Torso facets (convex hulls: [normal, distance]); see _hull.
const CHEST_C := Vector3(0, 1.40, 0.0)
const BELLY_C := Vector3(0, 1.04, 0.02)
const PELVIS_C := Vector3(0, 0.84, 0.0)
const SHOULDER_Y := 1.48
## The chest and belly fronts (z): the bib sits a cell proud of them.
const FRONT_Z := 0.31
const HEAD_C := Vector3(0, 1.865, 0.035)
const HEAD_HALF := Vector3(0.135, 0.165, 0.14)
## Where the apron skirt hangs: front face z at the belt and its lean.
const SKIRT_TOP := 0.90
const SKIRT_HEM := 0.46

var _chest := PackedFloat32Array()
var _belly := PackedFloat32Array()
var _pelvis := PackedFloat32Array()
var _boulder := PackedFloat32Array()
var _wedge := PackedFloat32Array()


func _init(skel: Skeleton3D) -> void:
	super(skel)
	add_braid_bones(skel)
	for i in skel.get_bone_count():
		bones[StringName(skel.get_bone_name(i))] = i
		rest[StringName(skel.get_bone_name(i))] = skel.get_bone_global_rest(i).origin
	# Only axis-aligned faces and 45-degree chamfers: any other slope voxelises
	# into long uneven terraces, which read as lumpy rather than carved.
	_chest = planes([
		[Vector3(0, 0, 1), 0.28], [Vector3(0, 0, -1), 0.24], [Vector3(1, 0, 0), 0.40], [Vector3(-1, 0, 0), 0.40],
		[Vector3(1, 0, 1), 0.431], [Vector3(-1, 0, 1), 0.431], [Vector3(1, 0, -1), 0.403], [Vector3(-1, 0, -1), 0.403],
		[Vector3(1, 1, 0), 0.40], [Vector3(-1, 1, 0), 0.40], [Vector3(0, 1, 0), 0.25], [Vector3(0, -1, 0), 0.24],
		[Vector3(0, 1, 1), 0.33], [Vector3(0, 1, -1), 0.31], [Vector3(0, -1, 1), 0.34],
	])
	_belly = planes([
		[Vector3(0, 0, 1), 0.29], [Vector3(0, 0, -1), 0.22], [Vector3(1, 0, 0), 0.37], [Vector3(-1, 0, 0), 0.37],
		[Vector3(1, 0, 1), 0.417], [Vector3(-1, 0, 1), 0.417], [Vector3(1, 0, -1), 0.375], [Vector3(-1, 0, -1), 0.375],
		[Vector3(0, 1, 0), 0.20], [Vector3(0, -1, 0), 0.16], [Vector3(0, -1, 1), 0.29],
	])
	_pelvis = planes([
		[Vector3(0, 0, 1), 0.235], [Vector3(0, 0, -1), 0.215], [Vector3(1, 0, 0), 0.33], [Vector3(-1, 0, 0), 0.33],
		[Vector3(1, 0, 1), 0.357], [Vector3(-1, 0, 1), 0.357], [Vector3(1, 0, -1), 0.343], [Vector3(-1, 0, -1), 0.343],
		[Vector3(0, 1, 0), 0.10], [Vector3(0, -1, 0), 0.16],
	])
	# A left boulder (mirror nx for the right): a flat-topped block of big
	# axis faces and 45-degree facets, its inner top cut away into a deep
	# notch so the head and a tucked chin clear it.
	_boulder = planes([
		[Vector3(0, 1, 0), 0.14], [Vector3(0, -1, 0), 0.16], [Vector3(1, 0, 0), 0.20], [Vector3(-1, 0, 0), 0.16],
		[Vector3(0, 0, 1), 0.19], [Vector3(0, 0, -1), 0.22],
		[Vector3(0, 1, 1), 0.198], [Vector3(0, 1, -1), 0.212], [Vector3(1, 1, 0), 0.198], [Vector3(-1, 1, 0), 0.12],
		[Vector3(-1, 0, 1), 0.16], [Vector3(1, 0, 1), 0.233], [Vector3(1, 0, -1), 0.255], [Vector3(-1, 0, -1), 0.212],
		[Vector3(0, -1, 1), 0.191], [Vector3(1, -1, 0), 0.198], [Vector3(-1, -1, 0), 0.184], [Vector3(1, 1, 1), 0.27],
	])
	# A smaller rock wedged on the back-outer corner, cut the same way.
	_wedge = planes([
		[Vector3(0, 1, 0), 0.05], [Vector3(0, -1, 0), 0.05], [Vector3(1, 0, 0), 0.08], [Vector3(-1, 0, 0), 0.08],
		[Vector3(0, 0, 1), 0.07], [Vector3(0, 0, -1), 0.07], [Vector3(-1, 1, 0), 0.07], [Vector3(0, 1, 1), 0.07],
		[Vector3(1, 0, 1), 0.09],
	])


func build_grids() -> Array[VoxelGrid]:
	return [build_body(), build_boulder(1.0), build_boulder(-1.0), build_arm(1.0), build_arm(-1.0),
		build_wrist(1.0), build_wrist(-1.0), build_head(), build_beard(), build_front()]


## No smoothing pass: the parts are planar or fine-cell, and it costs build time.
func soft_materials() -> Array:
	return []


func blur_cells(_grid: VoxelGrid) -> int:
	return 2


func surface_of(mat: int) -> int:
	match mat:
		Mat.IRON, Mat.IRON_NEW, Mat.RIVET, Mat.BUCKLE_DARK:
			return Surf.METAL
		Mat.EMBER_CORE, Mat.EMBER, Mat.EMBER_DIM:
			return Surf.GLOW
		Mat.GLINT:
			return Surf.GLASS
		Mat.STONE, Mat.STONE_DARK, Mat.BOULDER, Mat.BOULDER_DARK, Mat.PUPIL, Mat.MOUTH:
			return Surf.SKIN
		Mat.BEARD, Mat.BEARD_DARK:
			return Surf.HAIR
	return Surf.CLOTH


func surface_params() -> Array:
	return [
		{"roughness_value": 0.88, "specular_value": 0.28, "bevel_tilt": 0.35, "edge_lift": 0.04},  # CLOTH
		{"roughness_value": 0.5, "metallic_value": 0.7, "specular_value": 0.55, "edge_lift": 0.22},  # METAL
		{"roughness_value": 0.1, "metallic_value": 0.1, "specular_value": 0.9, "emission_value": 0.6},  # GLASS
		{"roughness_value": 0.9, "specular_value": 0.25, "bevel_tilt": 0.3, "edge_lift": 0.05},  # SKIN (stone)
		{"roughness_value": 0.6, "emission_value": GLOW_EMISSION, "edge_lift": 0.0},  # GLOW (ember)
		{"roughness_value": 0.72, "specular_value": 0.4, "edge_lift": 0.14},  # HAIR (beard)
	]


## Per-voxel colour: base with value noise and a little hue drift, cavities
## leaning toward the material's own shadow tone, worn edges on leather and
## iron, sparse lighter chips on stone edges, a lighter lap on the apron.
func color(mat: int, p: Vector3, c: Vector3i, _n: Vector3, occlusion: float, exposure: float) -> Color:
	var base: Color = COLORS.get(mat, Color.MAGENTA)
	var amp: float = NOISE.get(mat, 0.035)
	var noise := VoxelSdf.hash3(c, mat) * 2.0 - 1.0
	var drift := VoxelSdf.hash3(c, mat + 31) * 2.0 - 1.0
	var col := base * (1.0 + noise * amp)
	# Hue and saturation drift scale with the value noise (calm on big panels).
	var hue := amp / 0.035
	col = Color.from_hsv(fposmod(col.h + drift * 0.008 * hue, 1.0), clampf(col.s * (1.0 + drift * 0.04 * hue), 0.0, 1.0), col.v)
	if mat == Mat.EMBER_CORE or mat == Mat.EMBER or mat == Mat.EMBER_DIM:
		col.a = 1.0
		return col
	if mat == Mat.LEATHER and p.z > 0.2 and p.y > 0.55 and p.y < 0.82:
		# The lap, rubbed lighter where work rests on it.
		col = col.lerp(COLORS[Mat.PATCH], 0.18 * smoothstep(0.82, 0.68, p.y) * smoothstep(0.55, 0.62, p.y))
	if mat == Mat.BEARD and p.y < 1.45:
		# A touch darker and deeper toward the braid.
		col = col.lerp(SHADOWS[Mat.BEARD], 0.15)
	var shadow: Color = SHADOWS.get(mat, col.darkened(0.45))
	col = col.lerp(shadow * (1.0 + noise * amp), clampf(occlusion * 1.1, 0.0, 1.0))
	col *= 1.0 - occlusion * 0.28
	if mat in WEARS:
		var worn: Color = IRON_WEAR if mat == Mat.IRON or mat == Mat.RIVET else col.lightened(0.3)
		col = col.lerp(worn, exposure * 0.7)
	elif mat == Mat.BOULDER and VoxelSdf.hash3(c / 3, 77) < 0.08 and exposure > 0.5:
		# Sparse clumped chips on the boulders only: on the torso's stepped
		# chamfers every step is an edge, so chips there read as salt noise.
		col = col.lerp(col.lightened(0.18), exposure * 0.7)
	col.a = 1.0
	return col


# ---------------------------------------------------------------- shared shapes

## [normal, distance] pairs as a flat array of unit normals and distances.
static func planes(list: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for e: Array in list:
		var n := (e[0] as Vector3).normalized()
		out.append_array([n.x, n.y, n.z, e[1]])
	return out


## A convex polytope (intersection of half spaces) around c; side -1 mirrors it in x.
static func hull(p: Vector3, c: Vector3, pl: PackedFloat32Array, side := 1.0) -> float:
	var qx := (p.x - c.x) * side
	var qy := p.y - c.y
	var qz := p.z - c.z
	var best := -1e9
	var i := 0
	while i < pl.size():
		best = maxf(best, pl[i] * qx + pl[i + 1] * qy + pl[i + 2] * qz - pl[i + 3])
		i += 4
	return best


## The facet of a hull nearest p: its unit normal (mirrored for side -1).
static func hull_normal(p: Vector3, c: Vector3, pl: PackedFloat32Array, side := 1.0) -> Vector3:
	var q := Vector3((p.x - c.x) * side, p.y - c.y, p.z - c.z)
	var best := -1e9
	var n := Vector3.UP
	var i := 0
	while i < pl.size():
		var d := pl[i] * q.x + pl[i + 1] * q.y + pl[i + 2] * q.z - pl[i + 3]
		if d > best:
			best = d
			n = Vector3(pl[i] * side, pl[i + 1], pl[i + 2])
		i += 4
	return n


func torso_sdf(p: Vector3) -> float:
	return minf(hull(p, CHEST_C, _chest), hull(p, BELLY_C, _belly))


func body_sdf(p: Vector3) -> float:
	return minf(torso_sdf(p), hull(p, PELVIS_C, _pelvis))


## Chamfered-box slice (an octagon): flat faces with 45-degree corners.
static func octagon(dx: float, dz: float, rx: float, rz: float, chamfer := 1.42) -> float:
	var ax := absf(dx) / rx
	var az := absf(dz) / rz
	return (maxf(maxf(ax, az), (ax + az) / chamfer) - 1.0) * minf(rx, rz)


## The front face of the apron skirt at height y.
static func skirt_z(y: float) -> float:
	return 0.335 - (SKIRT_TOP - y) * 0.10


static func skirt_half_width(y: float) -> float:
	return 0.25 + (SKIRT_TOP - y) * 0.10


static func box_of(c: Vector3, half: Vector3) -> AABB:
	return AABB(c - half, half * 2.0)


## Nearest point on a 2D polyline: (distance, t along it 0..1).
static func polyline_hit(q: Vector2, pts: PackedVector2Array) -> Vector2:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var best := 1e9
	var best_t := 0.0
	var run := 0.0
	for i in pts.size() - 1:
		var ab := pts[i + 1] - pts[i]
		var h := clampf((q - pts[i]).dot(ab) / ab.dot(ab), 0.0, 1.0)
		var d := q.distance_to(pts[i] + ab * h)
		if d < best:
			best = d
			best_t = (run + ab.length() * h) / total
		run += ab.length()
	return Vector2(best, best_t)


## The Hearth-Mark (original emblem) in a unit square (u, v in -1..1): an
## anvil side-on, a flame of three stacked chevrons rising from its face, in a
## square frame with notched corners.
static func hearth_mark(u: float, v: float) -> bool:
	var au := absf(u)
	var av := absf(v)
	if maxf(au, av) > 1.0:
		return false
	if au > 0.8 and av > 0.8:
		return false
	if au > 0.8 or av > 0.8:
		return true
	# Anvil: face with a horn to the left, waist, foot.
	if v > -0.45 and v < -0.2 and u > -0.66 and u < 0.52:
		return u > -0.4 or v > -0.36
	if v >= -0.6 and v <= -0.45 and au < 0.2:
		return true
	if v > -0.8 and v < -0.6 and au < 0.42:
		return true
	# Flame: three stacked chevrons.
	for k in 3:
		var base := -0.12 + k * 0.24
		if au < 0.34 and absf(v - (base + 0.2 - au * 0.75)) < 0.075:
			return true
	return false


## A glowing seam on a part: cells within width of the polyline (projected on
## the plane across `axis`, on the side `facing` picks) are carved one cell
## deep, and the cell beneath each becomes ember (core in the middle, dim at
## the tip). sdf is the part's own distance function; only cells of `tag`.
func crack(g: VoxelGrid, bounds: AABB, sdf: Callable, pts: PackedVector2Array, axis: int,
		facing: Callable, tag: int, width := 0.7) -> void:
	var w := g.cell * width
	var cell := g.cell
	# Only cells near the polyline's footprint are visited.
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for q in pts:
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	lo -= Vector2.ONE * cell * 2.0
	hi += Vector2.ONE * cell * 2.0
	var near := bounds
	match axis:
		0:
			near = AABB(Vector3(bounds.position.x, lo.y, lo.x), Vector3(bounds.size.x, hi.y - lo.y, hi.x - lo.x))
		1:
			near = AABB(Vector3(lo.x, bounds.position.y, lo.y), Vector3(hi.x - lo.x, bounds.size.y, hi.y - lo.y))
		_:
			near = AABB(Vector3(lo.x, lo.y, bounds.position.z), Vector3(hi.x - lo.x, hi.y - lo.y, bounds.size.z))
	bounds = bounds.intersection(near)
	if not bounds.has_volume():
		return
	var proj := func(p: Vector3) -> Vector2:
		match axis:
			0:
				return Vector2(p.z, p.y)
			1:
				return Vector2(p.x, p.z)
		return Vector2(p.x, p.y)
	var hit := func(p: Vector3) -> Vector2:
		if not facing.call(p):
			return Vector2(1e9, 0.0)
		return polyline_hit(proj.call(p), pts)
	for m: int in [Mat.EMBER_DIM, Mat.EMBER, Mat.EMBER_CORE]:
		g.paint(bounds, func(p: Vector3):
			var h: Vector2 = hit.call(p)
			if h.x > w:
				return 1.0
			var kind := Mat.EMBER_DIM if h.y > 0.8 else (Mat.EMBER_CORE if h.y > 0.34 and h.y < 0.42 else Mat.EMBER)
			if kind != m:
				return 1.0
			var d: float = sdf.call(p)
			return -1.0 if d < -cell * 0.9 and d > -cell * 2.3 else 1.0, m, tag, PAINT)
	g.paint(bounds, func(p: Vector3):
		var h: Vector2 = hit.call(p)
		if h.x > w:
			return 1.0
		return -1.0 if sdf.call(p) > -cell * 0.9 else 1.0, 0, -1, CARVE)


# ---------------------------------------------------------------- body grid

func build_body() -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(-0.72, -0.01, -0.33), Vector3(1.44, 1.74, 0.74)), BODY_CELL)
	_pelvis_and_legs(g)
	_boots(g)
	_torso(g)
	_upper_arms(g)
	_torso_cracks(g)
	_belt_and_straps(g)
	_apron(g)
	return g


func _pelvis_and_legs(g: VoxelGrid) -> void:
	g.paint(box_of(PELVIS_C, Vector3(0.38, 0.2, 0.28)), func(p: Vector3): return hull(p, PELVIS_C, _pelvis),
		Mat.TROUSER, Tag.TORSO)
	for side: float in [1.0, -1.0]:
		var tag := Tag.LEG_L if side > 0 else Tag.LEG_R
		var lx := 0.18 * side
		var box := AABB(Vector3(minf(lx - 0.2 * side, lx + 0.2 * side), 0.26, -0.22), Vector3(0.4, 0.58, 0.42))
		# Trouser leg: octagon slices tapering from the seat to the cuff, a
		# little flare out for the planted stance.
		g.paint(box, func(p: Vector3):
			if p.y < 0.27 or p.y > 0.82:
				return 1.0
			var t := clampf((0.82 - p.y) / 0.52, 0.0, 1.0)
			var r := lerpf(0.165, 0.128, t) + (0.01 if p.y < 0.5 and p.y > 0.4 else 0.0)
			var cx := lx + 0.012 * side * t
			return octagon(p.x - cx, p.z - 0.005, r, r * 0.92), Mat.TROUSER, tag)
		# Rolled cuff: a thicker band with a fold line.
		g.paint(box, func(p: Vector3):
			if p.y < 0.27 or p.y > 0.35:
				return 1.0
			return octagon(p.x - lx - 0.012 * side, p.z - 0.005, 0.15, 0.14), Mat.TROUSER, tag)
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			return absf(p.y - 0.313) < BODY_CELL * 0.5, Mat.TROUSER_DARK, [Mat.TROUSER])
		# Knee crease and a side seam.
		g.paint_surface(box, func(p: Vector3, _c: Vector3i):
			var seam := absf(p.z - 0.005) < BODY_CELL * 0.5 and p.x * side > 0.18 + 0.1 and p.y > 0.36
			var crease := absf(p.y - 0.47) < BODY_CELL * 0.5 and p.z > 0.06
			return seam or crease, Mat.TROUSER_DARK, [Mat.TROUSER])


func _boots(g: VoxelGrid) -> void:
	for side: float in [1.0, -1.0]:
		var tag := Tag.LEG_L if side > 0 else Tag.LEG_R
		# The foot, toe cap and sole ride the foot rigidly; the shaft the shin.
		var foot_tag := Tag.FOOT_L if side > 0 else Tag.FOOT_R
		var bx := 0.19 * side
		var box := AABB(Vector3(bx - 0.17, -0.01, -0.2), Vector3(0.34, 0.33, 0.5))
		# Shaft (planar octagon), foot block, iron toe cap, a thick sole.
		g.paint(box, func(p: Vector3):
			if p.y < 0.13 or p.y > 0.29:
				return 1.0
			return octagon(p.x - bx, p.z + 0.005, 0.138, 0.13), Mat.BOOT, tag)
		g.paint(box, func(p: Vector3):
			if p.y < 0.04:
				return 1.0
			var top := 0.17 - maxf(p.z - 0.05, 0.0) * 0.32
			return maxf(maxf(octagon(p.x - bx, 0.0, 0.13, 0.13), absf(p.z - 0.055) - 0.2), maxf(p.y - top, 0.04 - p.y)),
			Mat.BOOT, foot_tag)
		g.paint(box, func(p: Vector3):
			if p.z < 0.14 or p.y < 0.04:
				return 1.0
			var top := 0.17 - maxf(p.z - 0.05, 0.0) * 0.32 + 0.012
			return maxf(maxf(octagon(p.x - bx, 0.0, 0.142, 0.142), absf(p.z - 0.2) - 0.07), p.y - top), Mat.IRON, foot_tag)
		g.paint(box, func(p: Vector3):
			return maxf(octagon(p.x - bx, 0.0, 0.15, 0.15), maxf(absf(p.z - 0.06) - 0.225, absf(p.y - 0.026) - 0.026)),
			Mat.SOLE, foot_tag)
		# Hobnails: six iron studs along each sole edge.
		for k in 6:
			var z := lerpf(-0.13, 0.25, k / 5.0)
			for e: float in [1.0, -1.0]:
				var at := Vector3(bx + 0.162 * e, 0.024, z)
				g.paint(box_of(at, Vector3(0.02, 0.02, 0.02)), func(p: Vector3): return VoxelSdf.box(p, at, Vector3(0.008, 0.008, 0.008)),
					Mat.RIVET, foot_tag, ADD)
		# A strap and buckle round the shaft top.
		g.paint(box, func(p: Vector3):
			if absf(p.y - 0.25) > 0.022:
				return 1.0
			return octagon(p.x - bx, p.z + 0.005, 0.152, 0.144), Mat.BELT, tag)
		var bk := Vector3(bx + 0.155 * side, 0.25, 0.0)
		g.paint(box_of(bk, Vector3(0.03, 0.04, 0.04)), func(p: Vector3): return VoxelSdf.box(p, bk, Vector3(0.012, 0.024, 0.024)),
			Mat.IRON, tag)


func _torso(g: VoxelGrid) -> void:
	var box := AABB(Vector3(-0.44, 0.86, -0.29), Vector3(0.88, 0.82, 0.66))
	g.paint(box, func(p: Vector3): return torso_sdf(p), Mat.STONE, Tag.TORSO)
	# A short, thick neck column, almost hidden between the boulders.
	g.paint(AABB(Vector3(-0.14, 1.5, -0.14), Vector3(0.28, 0.24, 0.3)), func(p: Vector3):
		return maxf(octagon(p.x, p.z - 0.01, 0.115, 0.11), absf(p.y - 1.61) - 0.1), Mat.STONE, Tag.NECK, ADD)
	# Chisel marks: short dark dashes on the flat facets only (on a stepped
	# chamfer a dash breaks into scattered dots), in a few 4-cell blocks.
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		var blk := Vector3i(c.x >> 2, c.y >> 2, c.z >> 2)
		if VoxelSdf.hash3(blk, 11) > 0.12 or not _on_flat_facet(p):
			return false
		var lx := c.x & 3
		var ly := c.y & 3
		var lz := c.z & 3
		return (lx == ly and lz < 3) if VoxelSdf.hash3(blk, 12) < 0.5 else (lx + ly == 3 and lz < 3), Mat.STONE_DARK, [Mat.STONE])


## Whether p is on one of the torso's axis-aligned faces, not a 45-degree chamfer.
func _on_flat_facet(p: Vector3) -> bool:
	var n := hull_normal(p, CHEST_C, _chest) if p.y > 1.22 else hull_normal(p, BELLY_C, _belly)
	return maxf(absf(n.x), maxf(absf(n.y), absf(n.z))) > 0.99


func _upper_arms(g: VoxelGrid) -> void:
	for side: float in [1.0, -1.0]:
		var tag := Tag.ARM_L if side > 0 else Tag.ARM_R
		var box := AABB(Vector3(0.24 if side > 0 else -0.71, 1.3, -0.17), Vector3(0.47, 0.36, 0.34))
		g.paint(box, func(p: Vector3):
			var ax := p.x * side
			if ax < 0.26 or ax > 0.70:
				return 1.0
			var r := lerpf(0.135, 0.122, clampf((ax - 0.3) / 0.38, 0.0, 1.0))
			var arm := octagon(p.y - SHOULDER_Y, p.z, r, r * 0.96)
			# Deltoid: a faceted block on top of the arm root.
			var delt := maxf(octagon(p.y - 1.52, p.z, 0.115, 0.135), absf(ax - 0.40) - 0.11)
			return minf(arm, delt), Mat.STONE, tag, ADD)
		# One crack across the deltoid's top.
		crack(g, box, func(p: Vector3):
			var ax := p.x * side
			var r := lerpf(0.135, 0.122, clampf((ax - 0.3) / 0.38, 0.0, 1.0))
			return minf(octagon(p.y - SHOULDER_Y, p.z, r, r * 0.96),
				maxf(octagon(p.y - 1.52, p.z, 0.115, 0.135), absf(ax - 0.40) - 0.11)),
			PackedVector2Array([Vector2(0.33 * side, 0.06), Vector2(0.4 * side, 0.02), Vector2(0.45 * side, 0.07),
				Vector2(0.53 * side, 0.03)]), 1, func(p: Vector3): return p.y > 1.56, tag)


func _torso_cracks(g: VoxelGrid) -> void:
	var front := func(p: Vector3) -> bool: return p.z > 0.05
	var back := func(p: Vector3) -> bool: return p.z < -0.05
	var tsdf := func(p: Vector3) -> float: return torso_sdf(p)
	var cracks := [
		# Chest sides and pecs (outside the bib), belly sides, back.
		[[Vector2(0.24, 1.56), Vector2(0.29, 1.48), Vector2(0.26, 1.40), Vector2(0.33, 1.30), Vector2(0.31, 1.20)], front],
		[[Vector2(0.29, 1.48), Vector2(0.36, 1.45)], front],
		[[Vector2(-0.22, 1.54), Vector2(-0.27, 1.44), Vector2(-0.24, 1.36), Vector2(-0.33, 1.27)], front],
		[[Vector2(0.33, 1.08), Vector2(0.29, 1.0), Vector2(0.33, 0.93)], front],
		[[Vector2(-0.31, 1.12), Vector2(-0.34, 1.03)], front],
		[[Vector2(0.05, 1.58), Vector2(-0.06, 1.46), Vector2(0.04, 1.33), Vector2(-0.05, 1.18), Vector2(0.02, 1.06)], back],
		[[Vector2(-0.06, 1.46), Vector2(-0.2, 1.41), Vector2(-0.28, 1.47)], back],
		[[Vector2(0.04, 1.33), Vector2(0.18, 1.27), Vector2(0.24, 1.31)], back],
	]
	for entry: Array in cracks:
		var pts := PackedVector2Array(entry[0])
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		for q in pts:
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
		var is_front: bool = entry[1] == front
		var bounds := AABB(Vector3(lo.x - 0.04, lo.y - 0.04, 0.0 if is_front else -0.3), Vector3(hi.x - lo.x + 0.08,
			hi.y - lo.y + 0.08, 0.36 if is_front else 0.3))
		crack(g, bounds, tsdf, pts, 2, entry[1], Tag.TORSO, 0.55)


func _belt_and_straps(g: VoxelGrid) -> void:
	var box := AABB(Vector3(-0.42, 0.84, -0.3), Vector3(0.84, 0.16, 0.68))
	# Wide belt one cell proud of the body, stitched along both edges.
	g.paint(box, func(p: Vector3):
		if p.y < 0.86 or p.y > 0.975:
			return 1.0
		var d := body_sdf(p)
		return -1.0 if d > 0.0 and d < BODY_CELL * 1.2 else 1.0, Mat.BELT, Tag.TORSO, ADD)
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		return g.mats[g.index(c.x, c.y, c.z)] == Mat.BELT and (p.y < 0.875 or p.y > 0.96) and (c.x + c.z) % 2 == 0, Mat.STITCH, [Mat.BELT])
	# Straps: from the bib's top corners over the trapezius, crossing in an X on the back.
	for side: float in [1.0, -1.0]:
		var top := AABB(Vector3(0.1 if side > 0 else -0.26, 1.42, -0.3), Vector3(0.16, 0.28, 0.62))
		var on_top := func(p: Vector3) -> bool: return absf(p.x * side - 0.175) < 0.036 and p.y > 1.46
		g.paint(top, func(p: Vector3):
			if not on_top.call(p):
				return 1.0
			var d := torso_sdf(p)
			return -1.0 if d > 0.0 and d < BODY_CELL * 1.2 else 1.0, Mat.LEATHER, Tag.TORSO, ADD)
		var a := Vector2(0.175 * side, 1.56)
		var b := Vector2(-0.27 * side, 0.98)
		var back_box := AABB(Vector3(-0.36, 0.94, -0.32), Vector3(0.72, 0.68, 0.2))
		var on_back := func(p: Vector3) -> bool:
			var q := Vector2(p.x, p.y)
			var ab := b - a
			var h := clampf((q - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
			return q.distance_to(a + ab * h) < 0.036 and p.z < -0.08
		g.paint(back_box, func(p: Vector3):
			if not on_back.call(p):
				return 1.0
			var d := torso_sdf(p)
			return -1.0 if d > 0.0 and d < BODY_CELL * 1.2 else 1.0, Mat.LEATHER, Tag.TORSO, ADD)
		# Stitch lines down the straps' middles.
		g.paint_surface(back_box, func(p: Vector3, c: Vector3i):
			if g.mats[g.index(c.x, c.y, c.z)] != Mat.LEATHER or not on_back.call(p):
				return false
			var q := Vector2(p.x, p.y)
			var ab := (b - a).normalized()
			var off := absf((q - a).cross(ab))
			return off < BODY_CELL * 0.5 and c.y % 2 == 0, Mat.STITCH, [Mat.LEATHER])
	# The cross: a riveted iron ring where the straps meet.
	var x_at := Vector3(0.0, 1.33, -0.27)
	g.paint(box_of(x_at, Vector3(0.06, 0.06, 0.05)), func(p: Vector3):
		var dz := torso_sdf(p)
		return maxf(absf(Vector2(p.x, p.y - x_at.y).length() - 0.03) - 0.012, absf(dz - BODY_CELL * 1.5) - BODY_CELL * 0.6),
		Mat.IRON, Tag.TORSO)


func _apron(g: VoxelGrid) -> void:
	# Bib: one cell proud of the chest and belly facets, a trapezoid.
	var bib_hw := func(y: float) -> float: return 0.16 + (1.52 - y) * 0.18
	var bib_box := AABB(Vector3(-0.3, 0.95, 0.08), Vector3(0.6, 0.6, 0.3))
	g.paint(bib_box, func(p: Vector3):
		if p.y > 1.52 or p.y < 0.96 or absf(p.x) > bib_hw.call(p.y):
			return 1.0
		var d := torso_sdf(p)
		return -1.0 if d > 0.0 and d < BODY_CELL * 1.2 else 1.0, Mat.LEATHER, Tag.TORSO, ADD)
	# Stitched hem round the bib, and the Hearth-Mark branded on its left.
	g.paint_surface(bib_box, func(p: Vector3, c: Vector3i):
		if g.mats[g.index(c.x, c.y, c.z)] != Mat.LEATHER:
			return false
		var edge := absf(absf(p.x) - (bib_hw.call(p.y) - BODY_CELL)) < BODY_CELL * 0.5 or absf(p.y - 1.5) < BODY_CELL * 0.5
		return edge and (c.x + c.y) % 2 == 0, Mat.STITCH, [Mat.LEATHER])
	g.paint_surface(bib_box, func(p: Vector3, _c: Vector3i):
		return hearth_mark((p.x - 0.14) / 0.1, (p.y - 1.1) / 0.1), Mat.BRAND, [Mat.LEATHER])
	# Skirt: a flat, stiff slab from the belt to the knee, square hem with
	# chamfered corners, two pockets, a patch, scorch marks and burn holes.
	var skirt_box := AABB(Vector3(-0.32, SKIRT_HEM - 0.01, 0.2), Vector3(0.64, SKIRT_TOP - SKIRT_HEM + 0.04, 0.2))
	var in_skirt := func(p: Vector3) -> float:
		if p.y < SKIRT_HEM or p.y > SKIRT_TOP + 0.02:
			return 1.0
		var hw := skirt_half_width(p.y)
		var corner := (absf(p.x) - (hw - 0.04)) - (p.y - SKIRT_HEM)
		var z0 := skirt_z(p.y)
		return maxf(maxf(absf(p.x) - hw, corner), maxf(p.z - z0, z0 - 0.042 - p.z))
	g.paint(skirt_box, in_skirt, Mat.LEATHER, Tag.APRON, ADD)
	g.paint_surface(skirt_box, func(p: Vector3, c: Vector3i):
		if g.tags[g.index(c.x, c.y, c.z)] != Tag.APRON:
			return false
		var hem := absf(p.y - (SKIRT_HEM + BODY_CELL * 1.5)) < BODY_CELL * 0.5 and absf(p.x) < skirt_half_width(p.y) - 0.06
		var sides := absf(absf(p.x) - (skirt_half_width(p.y) - BODY_CELL * 1.5)) < BODY_CELL * 0.5 and p.y > SKIRT_HEM + 0.06
		return (hem or sides) and (c.x + c.y) % 2 == 0, Mat.STITCH, [Mat.LEATHER])
	for side: float in [1.0, -1.0]:
		var pocket := func(p: Vector3) -> bool:
			var ax := p.x * side
			return ax > 0.09 and ax < 0.25 and p.y > 0.64 and p.y < 0.82
		g.paint(skirt_box, func(p: Vector3):
			if not pocket.call(p):
				return 1.0
			var z0 := skirt_z(p.y)
			return -1.0 if p.z > z0 and p.z < z0 + BODY_CELL else 1.0, Mat.LEATHER, Tag.APRON, ADD)
		g.paint_surface(skirt_box, func(p: Vector3, c: Vector3i):
			if not pocket.call(p) or p.z < skirt_z(p.y) + BODY_CELL * 0.5:
				return false
			var ax := p.x * side
			var rim := ax < 0.09 + BODY_CELL or ax > 0.25 - BODY_CELL or p.y < 0.64 + BODY_CELL
			if p.y > 0.82 - BODY_CELL:
				return true
			return rim and (c.x + c.y) % 2 == 0, Mat.STITCH, [Mat.LEATHER])
		g.paint_surface(skirt_box, func(p: Vector3, _c: Vector3i):
			return pocket.call(p) and p.y > 0.82 - BODY_CELL, Mat.LEATHER_DARK, [Mat.STITCH])
	# A patch in lighter, mismatched leather with big stitches.
	g.paint_surface(skirt_box, func(p: Vector3, c: Vector3i):
		if p.x > -0.05 or p.x < -0.21 or p.y < 0.52 or p.y > 0.63:
			return false
		var rim := p.x > -0.05 - BODY_CELL or p.x < -0.21 + BODY_CELL or p.y < 0.52 + BODY_CELL or p.y > 0.63 - BODY_CELL
		return not rim or (c.x + c.y) % 2 == 1, Mat.PATCH, [Mat.LEATHER, Mat.STITCH])
	g.paint_surface(skirt_box, func(p: Vector3, c: Vector3i):
		if p.x > -0.05 or p.x < -0.21 or p.y < 0.52 or p.y > 0.63:
			return false
		var rim := p.x > -0.05 - BODY_CELL or p.x < -0.21 + BODY_CELL or p.y < 0.52 + BODY_CELL or p.y > 0.63 - BODY_CELL
		return rim and (c.x + c.y) % 2 == 0, Mat.STITCH, [Mat.LEATHER, Mat.PATCH])
	# Scorch marks: low-frequency blotches on the lower skirt and the bib.
	g.paint_surface(AABB(Vector3(-0.32, 0.45, 0.08), Vector3(0.64, 0.95, 0.32)), func(p: Vector3, c: Vector3i):
		var blk := Vector3i(c.x / 3, c.y / 3, 0)
		return VoxelSdf.hash3(blk, 21) < 0.07 and VoxelSdf.hash3(c, 22) < 0.8, Mat.SCORCH, [Mat.LEATHER])
	# Burn holes: right through the skirt, with a charred rim.
	for hole: Vector2 in [Vector2(0.2, 0.54), Vector2(0.0, 0.7), Vector2(-0.24, 0.79)]:
		var at := Vector3(hole.x, hole.y, skirt_z(hole.y) - 0.02)
		g.paint_surface(box_of(at, Vector3(0.06, 0.06, 0.05)), func(p: Vector3, _c: Vector3i):
			return Vector2(p.x - at.x, p.y - at.y).length() < BODY_CELL * 1.9, Mat.BURN, [Mat.LEATHER, Mat.SCORCH, Mat.STITCH])
		g.paint(box_of(at, Vector3(0.04, 0.04, 0.05)), func(p: Vector3):
			return Vector2(p.x - at.x, p.y - at.y).length() - BODY_CELL * 0.75, 0, -1, CARVE)


# ---------------------------------------------------------------- boulders

static func boulder_center(side: float) -> Vector3:
	return Vector3(0.44 * side, 1.725, -0.03)


## Points on a fist (rest space) that must stay out of the boulders: the
## palm, the knuckle corners and the thumb.
static func fist_points(side: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for x: float in [0.93, 1.05, 1.13]:
		for y: float in [-0.08, 0.0, 0.08]:
			for z: float in [-0.12, 0.0, 0.14]:
				out.append(Vector3(x * side, SHOULDER_Y + y, z))
	return out


## Points round the forearm (rest space), elbow to wrist cuff.
static func forearm_points(side: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for x: float in [0.70, 0.80, 0.90]:
		for a in 8:
			var t := TAU * a / 8.0
			out.append(Vector3(x * side, SHOULDER_Y + cos(t) * 0.14, sin(t) * 0.14))
	return out


## The boulder's rock (without moss) as a distance in rest space.
func boulder_sdf(p: Vector3, side: float) -> float:
	var c := boulder_center(side)
	var wedge_c := c + Vector3(0.08 * side, 0.13, -0.12)
	return minf(hull(p, c, _boulder, side), hull(p, wedge_c, _wedge, side))


## The outward normal of the boulder facet nearest p (rest space).
func boulder_normal(p: Vector3, side: float) -> Vector3:
	return hull_normal(p, boulder_center(side), _boulder, side)


func build_boulder(side: float) -> VoxelGrid:
	var c := boulder_center(side)
	var g := VoxelGrid.new(box_of(c, Vector3(0.235, 0.21, 0.245)), FINE_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	var tag := Tag.BOULDER_L if side > 0 else Tag.BOULDER_R
	var rock := func(p: Vector3) -> float: return hull(p, c, _boulder, side)
	g.paint(box, rock, Mat.BOULDER, tag)
	# A smaller wedged rock on the back-outer corner.
	var wedge_c := c + Vector3(0.08 * side, 0.13, -0.12)
	g.paint(box_of(wedge_c, Vector3(0.11, 0.08, 0.1)), func(p: Vector3): return hull(p, wedge_c, _wedge, side),
		Mat.BOULDER, tag, ADD)
	# Chisel marks on the facets: short parallel strokes.
	g.paint_surface(box, func(p: Vector3, cc: Vector3i):
		var blk := Vector3i(cc.x / 5, cc.y / 5, cc.z / 5)
		if VoxelSdf.hash3(blk, 41) > 0.14:
			return false
		var l := Vector3i(posmod(cc.x, 5), posmod(cc.y, 5), posmod(cc.z, 5))
		return (l.x + l.y + l.z) % 5 == 0 and l.y > 0 and l.y < 4, Mat.BOULDER_DARK, [Mat.BOULDER])
	# Moss cap: 1-2 cells thick on the up-facing facets, a ragged edge, tufts.
	g.paint(box, func(p: Vector3):
		var d: float = rock.call(p)
		if d <= 0.0 or d > FINE_CELL * 2.6:
			return 1.0
		var n := hull_normal(p, c, _boulder, side)
		var cc := g.cell_of(p)
		var lo := VoxelSdf.hash3(Vector3i(cc.x / 3, cc.y / 3, cc.z / 3), 51)
		var up := n.y + (lo - 0.5) * 0.5
		if up < 0.55:
			return 1.0
		var thick := FINE_CELL * (0.8 + 1.3 * lo)
		# Sparse tufts stand a cell or two proud.
		var tuft := VoxelSdf.hash3(Vector3i(cc.x, 0, cc.z), 52) < 0.02
		if d > thick and not tuft:
			return 1.0
		return -1.0, Mat.MOSS, tag, ADD)
	g.paint_surface(box, func(_p: Vector3, cc: Vector3i):
		return VoxelSdf.hash3(Vector3i(cc.x / 3, cc.y / 3, cc.z / 3), 53) < 0.3, Mat.MOSS_DARK, [Mat.MOSS])
	# Lichen dots on the bare rock.
	g.paint_surface(box, func(_p: Vector3, cc: Vector3i):
		return VoxelSdf.hash3(Vector3i(cc.x / 2, cc.y / 2, cc.z / 2), 54) < 0.025, Mat.LICHEN, [Mat.BOULDER])
	# A thin glowing crack down the outer face.
	crack(g, box, rock, PackedVector2Array([Vector2(-0.06, 1.82), Vector2(0.0, 1.74), Vector2(-0.04, 1.66),
		Vector2(0.03, 1.58)]), 0, func(p: Vector3): return p.x * side > c.x * side + 0.12, tag, 0.8)
	if side > 0:
		_flower(g, c + Vector3(-0.05, 0.0, 0.08), tag, rock)
	return g


## The tiny white flower in the moss on his left boulder.
func _flower(g: VoxelGrid, near: Vector3, tag: int, rock: Callable) -> void:
	# Find the moss top above `near`.
	var top := near.y
	for k in 40:
		var y := near.y + k * FINE_CELL * 0.5
		if rock.call(Vector3(near.x, y, near.z)) > FINE_CELL * 1.6:
			top = y
			break
	var base := Vector3(near.x, top, near.z)
	g.paint(box_of(base + Vector3(0, 0.02, 0), Vector3(0.01, 0.03, 0.01)), func(p: Vector3):
		return VoxelSdf.box(p, base + Vector3(0, 0.012, 0), Vector3(FINE_CELL * 0.4, 0.014, FINE_CELL * 0.4)), Mat.MOSS_DARK, tag, ADD)
	var head := base + Vector3(0, 0.03, 0)
	g.paint(box_of(head, Vector3(0.03, 0.01, 0.03)), func(p: Vector3):
		var q := p - head
		if absf(q.y) > FINE_CELL * 0.5:
			return 1.0
		var cross := (absf(q.x) < FINE_CELL * 0.6 and absf(q.z) < FINE_CELL * 1.6) or (absf(q.z) < FINE_CELL * 0.6 and absf(q.x) < FINE_CELL * 1.6)
		return -1.0 if cross else 1.0, Mat.FLOWER, tag)
	g.paint(box_of(head, Vector3(0.01, 0.01, 0.01)), func(p: Vector3):
		return VoxelSdf.box(p, head + Vector3(0, FINE_CELL * 0.5, 0), Vector3(FINE_CELL * 0.45, FINE_CELL * 0.45, FINE_CELL * 0.45)),
		Mat.FLOWER_CORE, tag)


# ---------------------------------------------------------------- forearms and fists

## The wrist cuff's centre and half length along the arm, and the hand bone's
## rest x (the wrist pivot).
const CUFF_X := 0.926
const CUFF_HALF := 0.027
const WRIST_X := 0.92


## The palm block and the wrist plug (rest space, rigid on the hand): the plug
## is a stone stub round the wrist pivot, hidden inside the forearm and the
## palm at rest, that fills the cuff's mouth when the hand bends.
static func palm_sdf(p: Vector3, side: float) -> float:
	var palm := Vector3(0.975 * side, SHOULDER_Y, -0.003)
	return VoxelSdf.box(p, palm, Vector3(0.064, 0.086, 0.14), 0.018)


static func wrist_plug_sdf(p: Vector3, side: float) -> float:
	var ax := p.x * side
	return maxf(octagon(p.y - SHOULDER_Y, p.z, 0.118, 0.118), maxf(0.862 - ax, ax - 0.95))


## The wrist plug on its own grid, so its faces exist inside the forearm and
## show only when the hand bends out of the cuff.
func build_wrist(side: float) -> VoxelGrid:
	var c := Vector3(0.906 * side, SHOULDER_Y, 0.0)
	var g := VoxelGrid.new(box_of(c, Vector3(0.07, 0.15, 0.15)), FINE_CELL)
	var gtag := Tag.GAUNT_L if side > 0 else Tag.GAUNT_R
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	g.paint(box, func(p: Vector3): return wrist_plug_sdf(p, side), Mat.STONE_DARK, gtag)
	return g


## Points round the middle of the cuff's mouth (rest space, on the forearm)
## that the hand's palm or plug must cover in every pose, or a slit opens
## between the cuff and the fist. The radius is the palm's inscribed one, so
## twisting the fist (free) never uncovers them; the rest of the mouth is the
## cuff's solid iron face.
static func cuff_mouth_points(side: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for a in 12:
		var t := TAU * a / 12.0
		out.append(Vector3((CUFF_X + CUFF_HALF + 0.004) * side, SHOULDER_Y + cos(t) * 0.075, sin(t) * 0.075))
	return out


## Seams the move scan checks for gaps: points on one bone that another
## bone's solid must cover ({name: [points bone, points, cover bone, sdf]}).
func gap_checks() -> Dictionary:
	var out := {}
	for side: float in [1.0, -1.0]:
		var prefix := "Left" if side > 0 else "Right"
		out[prefix + " wrist"] = [StringName(prefix + "LowerArm"), cuff_mouth_points(side), StringName(prefix + "Hand"),
			func(p: Vector3) -> float: return minf(palm_sdf(p, side), wrist_plug_sdf(p, side))]
	return out


func _forearm_r(ax: float) -> float:
	return lerpf(0.122, 0.152, clampf((ax - 0.64) / 0.28, 0.0, 1.0))


func build_arm(side: float) -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(0.62 if side > 0 else -1.28, 1.29, -0.2), Vector3(0.66, 0.38, 0.42)), FINE_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	var prefix := "Left" if side > 0 else "Right"
	var tag := Tag.ARM_L if side > 0 else Tag.ARM_R
	var gtag := Tag.GAUNT_L if side > 0 else Tag.GAUNT_R
	var y := SHOULDER_Y
	# Forearm: an octagonal stone prism swelling toward the wrist.
	var fore := func(p: Vector3) -> float:
		var ax := p.x * side
		var r := _forearm_r(ax)
		return maxf(octagon(p.y - y, p.z, r, r * 0.95), maxf(0.64 - ax, ax - 0.93))
	g.paint(box, fore, Mat.STONE, tag)
	crack(g, box, fore, PackedVector2Array([Vector2(0.66 * side, 0.02), Vector2(0.70 * side, -0.03),
		Vector2(0.745 * side, 0.01), Vector2(0.80 * side, -0.02), Vector2(0.86 * side, 0.03), Vector2(0.91 * side, -0.01)]),
		1, func(p: Vector3): return p.y > y + 0.08, tag)
	crack(g, box, fore, PackedVector2Array([Vector2(0.67 * side, y - 0.03), Vector2(0.72 * side, y + 0.02),
		Vector2(0.78 * side, y - 0.02), Vector2(0.84 * side, y + 0.03)]), 2, func(p: Vector3): return p.z > 0.08, tag)
	# Three iron bands with bevelled edges and five rivets each; the left
	# arm's middle band is newer, bright unpatinated iron.
	for k in 3:
		var xc := [0.705, 0.79, 0.875][k] as float
		var band_mat := Mat.IRON_NEW if side > 0 and k == 1 else Mat.IRON
		var rb := _forearm_r(xc) + 0.014
		var band_box := AABB(Vector3(xc * side - 0.03, y - rb - 0.02, -rb - 0.02), Vector3(0.06, rb * 2.0 + 0.04, rb * 2.0 + 0.04))
		g.paint(band_box, func(p: Vector3):
			var off := absf(p.x * side - xc)
			if off > 0.022:
				return 1.0
			var r := rb - (0.008 if off > 0.013 else 0.0)
			return octagon(p.y - y, p.z, r, r * 0.95), band_mat, tag)
		for a_deg: float in [-80.0, -40.0, 0.0, 40.0, 80.0]:
			var a := deg_to_rad(a_deg)
			var at := Vector3(xc * side, y + cos(a) * (rb + 0.004), sin(a) * (rb + 0.004))
			g.paint(box_of(at, Vector3(0.012, 0.012, 0.012)), func(p: Vector3): return VoxelSdf.sphere(p, at, FINE_CELL * 0.75),
				Mat.RIVET, tag, ADD)
	# Fist: a stone palm block with an iron back plate.
	var palm := Vector3(0.975 * side, y, -0.003)
	g.paint(box_of(palm, Vector3(0.08, 0.1, 0.16)), func(p: Vector3):
		return VoxelSdf.box(p, palm, Vector3(0.064, 0.086, 0.14), 0.018), Mat.STONE, gtag)
	var plate := palm + Vector3(-0.005 * side, 0.088, 0.0)
	g.paint(box_of(plate, Vector3(0.07, 0.02, 0.13)), func(p: Vector3):
		var q := p - plate
		var bevel := 0.006 if absf(q.y) > 0.002 else 0.0
		return maxf(maxf(absf(q.x) - 0.052 + bevel, absf(q.z) - 0.124 + bevel), absf(q.y) - 0.0075), Mat.IRON, gtag)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		var at := plate + Vector3(corner.x * 0.038, 0.01, corner.y * 0.105)
		g.paint(box_of(at, Vector3(0.012, 0.012, 0.012)), func(p: Vector3): return VoxelSdf.sphere(p, at, FINE_CELL * 0.75),
			Mat.RIVET, gtag, ADD)
	# Wrist cuff: a deep iron ring where the stone meets the hand, overlapping
	# the palm so the wrist plug fills its mouth when the hand bends.
	g.paint(AABB(Vector3(0.925 * side - 0.04, y - 0.2, -0.2), Vector3(0.08, 0.4, 0.4)), func(p: Vector3):
		var off := absf(p.x * side - CUFF_X)
		if off > CUFF_HALF:
			return 1.0
		var r := 0.165 - (0.006 if off > CUFF_HALF - 0.008 else 0.0)
		return octagon(p.y - y, p.z, r, r * 0.957), Mat.IRON, tag)
	# Fingers: thick planar stone blocks, one per segment with a dark seam at
	# each joint, a forged iron knuckle plate on each first segment (flat face,
	# bevelled edges, hammer-peened dents).
	var zs := [0.1, 0.034, -0.032, -0.097]
	for f in 4:
		var chain := PackedVector3Array()
		for part: String in ["Proximal", "Intermediate", "Distal"]:
			chain.append(rest[StringName(prefix + FINGERS[f] + part)])
		chain.append(chain[2] + (chain[2] - chain[1]).normalized() * 0.045)
		var dz: float = zs[f] - chain[0].z
		for i in chain.size():
			chain[i] += Vector3(0, 0, dz)
		chain[0] -= Vector3(0.02 * side, 0, 0)
		var ftag := FINGER_BASE + (0 if side > 0 else 4) + f
		var hy := 0.054 if f < 3 else 0.046
		var hz := 0.031 if f < 3 else 0.027
		for i in 3:
			var a := chain[i]
			var b := chain[i + 1]
			var mid := (a + b) * 0.5
			var hl := absf(b.x - a.x) * 0.5
			var shrink := 0.004 * i
			g.paint(box_of(mid, Vector3(hl + 0.02, hy + 0.01, hz + 0.01)), func(p: Vector3):
				return VoxelSdf.box(p, mid, Vector3(hl, hy - shrink, hz - shrink * 0.5), 0.009), Mat.STONE, ftag)
			if i > 0:
				g.paint(box_of(a, Vector3(0.01, hy + 0.01, hz + 0.01)), func(p: Vector3):
					return -1.0 if absf(p.x - a.x) < FINE_CELL * 0.5 else 1.0, Mat.STONE_DARK, ftag, PAINT)
		var k0 := chain[0]
		var k1 := chain[1]
		var kc := (k0 + k1) * 0.5 + Vector3(0, hy + 0.004, 0)
		var khl := absf(k1.x - k0.x) * 0.5 + 0.004
		g.paint(box_of(kc, Vector3(khl + 0.01, 0.02, hz + 0.012)), func(p: Vector3):
			var q := p - kc
			var bevel := 0.0055 if q.y > 0.0 else 0.0
			return maxf(maxf(absf(q.x) - khl + bevel, absf(q.z) - hz - 0.005 + bevel), absf(q.y) - 0.009), Mat.IRON, ftag)
		# Hammer-peened dents: single cells pressed into the plate's top.
		g.paint(box_of(kc, Vector3(khl + 0.01, 0.02, hz + 0.012)), func(p: Vector3):
			var cc := g.cell_of(p)
			if p.y < kc.y + 0.004 or g.get_mat(cc.x, cc.y + 1, cc.z) != 0:
				return 1.0
			return -1.0 if VoxelSdf.hash3(cc, 61 + f) < 0.16 else 1.0, 0, -1, CARVE)
	# Thumb: modelled tucked along the palm's front edge, rigid with the hand.
	var thumb_tag := Tag.THUMB_L if side > 0 else Tag.THUMB_R
	var t0 := Vector3(0.935 * side, y - 0.024, 0.15)
	var t1 := Vector3(1.045 * side, y - 0.034, 0.158)
	var tc := (t0 + t1) * 0.5
	g.paint(box_of(tc, Vector3(0.075, 0.05, 0.05)), func(p: Vector3):
		return VoxelSdf.box(p, tc, Vector3(0.058, 0.036, 0.033), 0.012), Mat.STONE, thumb_tag)
	g.paint(box_of(tc, Vector3(0.075, 0.05, 0.05)), func(p: Vector3):
		return -1.0 if absf(p.x - (tc.x + 0.012 * side)) < FINE_CELL * 0.5 else 1.0, Mat.STONE_DARK, thumb_tag, PAINT)
	return g


# ---------------------------------------------------------------- head grid

func head_sdf(p: Vector3) -> float:
	var skull := VoxelSdf.box(p, HEAD_C, HEAD_HALF, 0.075)
	var jaw := VoxelSdf.box(p, Vector3(0, 1.735, 0.06), Vector3(0.145, 0.06, 0.125), 0.05)
	# Flat cheek planes chisel the skull's front corners.
	var cheeks := (absf(p.x) * 0.7 + (p.z - 0.035) * 0.7) - 0.168
	return maxf(minf(skull, jaw), cheeks)


func build_head() -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(-0.2, 1.53, -0.14), Vector3(0.4, 0.53, 0.42)), HEAD_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	var t := Tag.HEAD
	g.paint(box, func(p: Vector3): return head_sdf(p), Mat.STONE, t)
	# Small ears.
	for s: float in [1.0, -1.0]:
		var ear := Vector3(0.142 * s, 1.835, 0.03)
		g.paint(box_of(ear, Vector3(0.03, 0.045, 0.04)), func(p: Vector3): return VoxelSdf.box(p, ear, Vector3(0.016, 0.032, 0.025), 0.008),
			Mat.STONE, t, ADD)
		g.paint(box_of(ear, Vector3(0.03, 0.045, 0.04)), func(p: Vector3):
			return VoxelSdf.box(p, ear + Vector3(0.012 * s, 0, 0.004), Vector3(0.006, 0.018, 0.012)), 0, -1, CARVE)
	# Heavy brow: a planar ledge per side, low and furrowed at the centre.
	for s: float in [1.0, -1.0]:
		var brow_box := AABB(Vector3(minf(0.0, 0.17 * s) - 0.005, 1.84, 0.08), Vector3(0.18, 0.09, 0.16))
		var yb := func(u: float) -> float: return 1.876 + 0.018 * clampf(u / 0.15, 0.0, 1.0)
		var zf := func(u: float) -> float: return 0.214 - u * 0.14
		var ledge := func(p: Vector3) -> float:
			var u := p.x * s
			return maxf(maxf(absf(p.y - yb.call(u)) - 0.021, p.z - zf.call(u) - (p.y - yb.call(u)) * 0.35),
				maxf(0.1 - p.z, maxf(u - 0.148, -u - 0.004)))
		g.paint(brow_box, ledge, Mat.STONE, t)
		# Bushy dark-ember brows on the ledge's top front edge only.
		g.paint_surface(brow_box, func(p: Vector3, _c: Vector3i):
			var u := p.x * s
			return u > 0.015 and u < 0.14 and ledge.call(p) <= 0.0 and head_sdf(p) > 0.0 and p.y > yb.call(u) + 0.008 \
				and p.z > zf.call(u) - 0.03, Mat.BEARD_DARK, [Mat.STONE])
	# Deep-set glowing eyes under the ledge, a dark pupil block in front, a glint.
	for s: float in [1.0, -1.0]:
		var e := Vector3(0.058 * s, 1.84, 0.17)
		var eb := box_of(e, Vector3(0.05, 0.035, 0.05))
		g.paint(eb, func(p: Vector3): return VoxelSdf.ellipsoid(p, e + Vector3(0, 0, 0.03), Vector3(0.042, 0.022, 0.05)), 0, -1, CARVE)
		g.paint(eb, func(p: Vector3): return VoxelSdf.ellipsoid(p, e + Vector3(0, -0.002, -0.022), Vector3(0.034, 0.017, 0.035)),
			Mat.EMBER, t, ADD)
		g.paint(eb, func(p: Vector3): return VoxelSdf.ellipsoid(p, e + Vector3(0, -0.002, -0.022), Vector3(0.024, 0.011, 0.04)),
			Mat.EMBER_CORE, t, PAINT)
		var pupil := e + Vector3(-0.004 * s, -0.002, 0.016)
		g.paint(box_of(pupil, Vector3(0.02, 0.02, 0.02)), func(p: Vector3): return VoxelSdf.box(p, pupil, Vector3(0.0045, 0.0095, 0.006)),
			Mat.PUPIL, t, ADD)
		var glint := pupil + Vector3(0.0085 * s, 0.006, 0.0)
		g.paint(box_of(glint, Vector3(0.01, 0.01, 0.01)), func(p: Vector3): return VoxelSdf.box(p, glint, Vector3(0.004, 0.004, 0.004)),
			Mat.GLINT, t, FILL)
		# Cheekbones.
		var cheek := Vector3(0.088 * s, 1.795, 0.148)
		g.paint(box_of(cheek, Vector3(0.05, 0.03, 0.04)), func(p: Vector3): return VoxelSdf.box(p, cheek, Vector3(0.038, 0.017, 0.026), 0.008),
			Mat.STONE, t, ADD)
	# A broad stone nose with dark nostrils.
	var nose := Vector3(0, 1.788, 0.19)
	g.paint(box_of(nose, Vector3(0.05, 0.06, 0.05)), func(p: Vector3):
		var q := p - nose
		var bridge := q.y * 0.35
		return maxf(VoxelSdf.box(p, nose, Vector3(0.03 - maxf(q.y, 0.0) * 0.25, 0.042, 0.03), 0.01), q.z - 0.018 + bridge), Mat.STONE, t)
	for s: float in [1.0, -1.0]:
		var nostril := nose + Vector3(0.014 * s, -0.04, 0.006)
		g.paint(box_of(nostril, Vector3(0.01, 0.01, 0.01)), func(p: Vector3): return VoxelSdf.box(p, nostril, Vector3(0.006, 0.005, 0.008)),
			Mat.MOUTH, t, PAINT)
	# Chisel marks on the crown and the cheek crack (his left cheek).
	g.paint_surface(box, func(p: Vector3, c: Vector3i):
		if p.y < 1.9:
			return false
		var blk := Vector3i(c.x / 5, c.y / 5, c.z / 5)
		return VoxelSdf.hash3(blk, 71) < 0.25 and (posmod(c.x, 5) + posmod(c.z, 5)) == 4, Mat.STONE_DARK, [Mat.STONE])
	crack(g, box, func(p: Vector3): return head_sdf(p), PackedVector2Array([Vector2(0.078, 1.822), Vector2(0.1, 1.80),
		Vector2(0.09, 1.782), Vector2(0.112, 1.765)]), 2, func(p: Vector3): return p.z > 0.1 and p.x > 0.05, t, 0.75)
	# Crown crack, a thin seam over the top toward the back.
	crack(g, box, func(p: Vector3): return head_sdf(p), PackedVector2Array([Vector2(-0.04, 0.12), Vector2(-0.01, 0.06),
		Vector2(-0.05, 0.0), Vector2(-0.02, -0.07)]), 1, func(p: Vector3): return p.y > 1.97, t, 0.75)
	_upper_beard(g, box)
	return g


func _upper_beard(g: VoxelGrid, box: AABB) -> void:
	var t := Tag.BEARD
	# Sideburns and the jaw's beard: a shell round the jaw, clear of the face
	# above the mouth.
	g.paint(box, func(p: Vector3):
		if p.y > 1.835:
			return 1.0
		var face := absf(p.x) < 0.112 - maxf(1.79 - p.y, 0.0) * 0.4 and p.y > 1.752 and p.z > 0.06
		if face:
			return 1.0
		var shell := VoxelSdf.box(p, Vector3(0, 1.73, 0.065), Vector3(0.152, 0.075, 0.135), 0.06)
		if p.z < -0.02 and p.y > 1.7:
			return 1.0
		return maxf(shell, -head_sdf(p) - HEAD_CELL * 2.0), Mat.BEARD, t, ADD)
	# Heavy moustache: two drooping locks from under the nose into the beard.
	for s: float in [1.0, -1.0]:
		_lock(g, box, Vector3(0.008 * s, 1.752, 0.2), Vector3(0.07 * s, 1.752, 0.2), Vector3(0.105 * s, 1.69, 0.18), 0.022, 0.016,
			Mat.BEARD, t)
		_lock(g, box, Vector3(0.04 * s, 1.745, 0.205), Vector3(0.09 * s, 1.74, 0.195), Vector3(0.118 * s, 1.705, 0.16), 0.016, 0.01,
			Mat.BEARD, t)
	# A dark mouth line under the moustache.
	g.paint(box_of(Vector3(0, 1.722, 0.19), Vector3(0.05, 0.01, 0.04)), func(p: Vector3):
		return -1.0 if absf(p.x) < 0.036 and absf(p.y - 1.722) < 0.005 else 1.0, Mat.MOUTH, t, PAINT)
	_beard_strands(g, box, 1.53)


## Strand grooves (wavy dark lines down the beard) and a few outline strands.
func _beard_strands(g: VoxelGrid, box: AABB, low: float) -> void:
	g.paint_surface(box, func(p: Vector3, _c: Vector3i):
		if p.y < low or p.z < 0.0:
			return false
		var u := (p.x + 0.012 * sin(p.y * 38.0)) / 0.03
		return absf(fposmod(u, 1.0) - 0.5) > 0.36, Mat.BEARD_DARK, [Mat.BEARD])


## A tapered tube along a quadratic curve (beard locks, moustache).
func _lock(g: VoxelGrid, box: AABB, a: Vector3, bend: Vector3, tip: Vector3, r0: float, r1: float, mat: int, tag: int) -> void:
	var pts := PackedVector3Array()
	var lo := a
	var hi := a
	for k in 7:
		var u := k / 6.0
		var q := a.lerp(bend, u).lerp(bend.lerp(tip, u), u)
		pts.append(q)
		lo = Vector3(minf(lo.x, q.x), minf(lo.y, q.y), minf(lo.z, q.z))
		hi = Vector3(maxf(hi.x, q.x), maxf(hi.y, q.y), maxf(hi.z, q.z))
	var bounds := AABB(lo - Vector3.ONE * r0, hi - lo + Vector3.ONE * r0 * 2.0).intersection(box)
	g.paint(bounds, func(p: Vector3):
		var best := 1e9
		for i in 6:
			best = minf(best, VoxelSdf.capsule(p, pts[i], pts[i + 1], lerpf(r0, r1, i / 6.0), lerpf(r0, r1, (i + 1) / 6.0)))
		return best, mat, tag)


# ---------------------------------------------------------------- beard + braid grid

## The braid's joints in rest space, root (in the beard's bottom lobe) to tip:
## it hangs straight down the bib, a bead's width plus air in front of it.
static func braid_points() -> PackedVector3Array:
	return PackedVector3Array([Vector3(0, 1.40, 0.375), Vector3(0, 1.24, 0.385), Vector3(0, 1.15, 0.388),
		Vector3(0, 1.02, 0.388)])


## Adds the braid chain bones to a rig that lacks them (idempotent): rest at
## braid_points, model-aligned bases, the first under Head.
static func add_braid_bones(skel: Skeleton3D) -> void:
	if skel.find_bone(BRAID_BONES[0]) >= 0:
		return
	var pts := braid_points()
	var parent := skel.find_bone(&"Head")
	var parent_global := skel.get_bone_global_rest(parent)
	for k in BRAID_BONES.size():
		var index := skel.add_bone(BRAID_BONES[k])
		skel.set_bone_parent(index, parent)
		skel.set_bone_rest(index, parent_global.affine_inverse() * Transform3D(Basis(), pts[k]))
		skel.reset_bone_pose(index)
		parent = index
		parent_global = Transform3D(Basis(), pts[k])


func build_beard() -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(-0.2, 0.88, 0.1), Vector3(0.4, 0.8, 0.42)), FINE_CELL)
	var box := AABB(g.origin, Vector3(g.size) * g.cell)
	var t := Tag.BEARD
	# The full beard: a wedge of soft lobes from the jaw down onto the chest.
	var beard_box := AABB(Vector3(-0.2, 1.24, 0.1), Vector3(0.4, 0.46, 0.36))
	g.paint(beard_box, func(p: Vector3):
		var e1 := VoxelSdf.ellipsoid(p, Vector3(0, 1.635, 0.2), Vector3(0.165, 0.1, 0.13))
		var e2 := VoxelSdf.ellipsoid(p, Vector3(0, 1.5, 0.272), Vector3(0.142, 0.13, 0.09))
		var e3 := VoxelSdf.ellipsoid(p, Vector3(0, 1.36, 0.31), Vector3(0.09, 0.105, 0.068))
		return VoxelSdf.smooth_union(VoxelSdf.smooth_union(e1, e2, 0.05), e3, 0.05), Mat.BEARD, t)
	# Strands breaking the outline at the sides and the bottom.
	for s: float in [1.0, -1.0]:
		_lock(g, box, Vector3(0.15 * s, 1.66, 0.17), Vector3(0.175 * s, 1.55, 0.22), Vector3(0.14 * s, 1.44, 0.27), 0.02, 0.008,
			Mat.BEARD, t)
		_lock(g, box, Vector3(0.12 * s, 1.52, 0.3), Vector3(0.13 * s, 1.42, 0.32), Vector3(0.085 * s, 1.33, 0.33), 0.018, 0.008,
			Mat.BEARD, t)
		_lock(g, box, Vector3(0.06 * s, 1.36, 0.35), Vector3(0.07 * s, 1.30, 0.36), Vector3(0.045 * s, 1.255, 0.36), 0.014, 0.006,
			Mat.BEARD, t)
	_beard_strands(g, beard_box, 1.24)
	_braid(g, box)
	return g


func _braid(g: VoxelGrid, box: AABB) -> void:
	var t := Tag.BRAID
	var pts := braid_points()
	# Beads: alternating tilted lobes along the chain, a plait.
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var n := 9
	for k in n:
		var at := _along(pts, total * (k + 0.5) / n)
		var tilt := 0.45 if k % 2 == 0 else -0.45
		var r := lerpf(0.04, 0.03, float(k) / n)
		var basis := Basis(Vector3.BACK, tilt)
		g.paint(box_of(at, Vector3(0.06, 0.06, 0.05)), func(p: Vector3):
			var q := basis.inverse() * (p - at)
			return VoxelSdf.ellipsoid(q, Vector3.ZERO, Vector3(r, r * 0.95, r * 0.8)), Mat.BEARD, t)
	g.paint_surface(AABB(Vector3(-0.07, 0.95, 0.3), Vector3(0.14, 0.45, 0.2)), func(p: Vector3, c: Vector3i):
		return g.tags[g.index(c.x, c.y, c.z)] == t and VoxelSdf.hash3(c, 81) < 0.25, Mat.BEARD_DARK, [Mat.BEARD])
	# Three iron rings break it into segments.
	for y: float in [1.29, 1.19, 1.11]:
		var at := _at_y(pts, y)
		var r := 0.038 if y > 1.2 else 0.034
		g.paint(box_of(at, Vector3(0.06, 0.03, 0.06)), func(p: Vector3):
			return VoxelSdf.torus(p, at, Vector3.UP, r, 0.011), Mat.IRON, t)
	# The heart ring he forged, threaded above the end ring: a flat heart with a hole.
	var heart := _at_y(pts, 1.045) + Vector3(0, 0, 0.032)
	g.paint(box_of(heart, Vector3(0.05, 0.05, 0.02)), func(p: Vector3):
		var q := Vector2(p.x - heart.x, p.y - heart.y) / 0.03
		var lobes := minf(Vector2(q.x - 0.5, q.y - 0.35).length(), Vector2(q.x + 0.5, q.y - 0.35).length()) - 0.55
		var point := (absf(q.x) * 0.95 - q.y * 0.7) - 0.62
		var shape := minf(lobes, maxf(point, q.y - 0.4))
		var hole := minf(Vector2(q.x - 0.32, q.y - 0.3).length(), Vector2(q.x + 0.32, q.y - 0.3).length()) - 0.18
		return maxf(maxf(shape, -hole), absf(p.z - heart.z) - FINE_CELL * 0.6), Mat.IRON_NEW, t, FILL)
	# A tufted tip and the heavy end ring hanging from it.
	var tip := pts[-1]
	g.paint(box_of(tip, Vector3(0.04, 0.04, 0.04)), func(p: Vector3):
		var q := p - tip
		if q.y > 0.0:
			return 1.0
		var col := posmod(int(floor(q.x / FINE_CELL)), 2)
		return VoxelSdf.box(p, tip + Vector3(0, -0.01 - col * 0.008, 0), Vector3(0.024, 0.014 + col * 0.008, 0.018)), Mat.BEARD, t)
	var ring := tip + Vector3(0, -0.06, 0.004)
	g.paint(box_of(ring, Vector3(0.07, 0.07, 0.03)), func(p: Vector3):
		return VoxelSdf.torus(p, ring, Vector3.BACK, 0.036, 0.0125), Mat.IRON, t)


static func _along(pts: PackedVector3Array, dist: float) -> Vector3:
	for i in pts.size() - 1:
		var l := pts[i].distance_to(pts[i + 1])
		if dist <= l:
			return pts[i].lerp(pts[i + 1], dist / l)
		dist -= l
	return pts[-1]


static func _at_y(pts: PackedVector3Array, y: float) -> Vector3:
	for i in pts.size() - 1:
		if y <= pts[i].y and y >= pts[i + 1].y:
			return pts[i].lerp(pts[i + 1], (pts[i].y - y) / (pts[i].y - pts[i + 1].y))
	return pts[-1]


# ---------------------------------------------------------------- belt front grid

func build_front() -> VoxelGrid:
	var g := VoxelGrid.new(AABB(Vector3(-0.27, 0.6, 0.27), Vector3(0.54, 0.42, 0.18)), HEAD_CELL)
	_buckle(g)
	_pocket_tools(g)
	return g


func _buckle(g: VoxelGrid) -> void:
	# An anvil-shaped iron buckle (horn to his right), the Hearth-Mark stamped
	# into its face.
	var c := Vector3(0.0, 0.918, 0.0)
	c.z = skirt_z(0.918) + 0.026
	var t := Tag.TORSO
	var bounds := box_of(c, Vector3(0.16, 0.09, 0.04))
	var depth := 0.012
	var anvil := func(p: Vector3) -> float:
		var u := p.x - c.x
		var v := p.y - c.y
		var face := maxf(maxf(u - 0.11, -0.09 - u), maxf(v - 0.065, -0.01 - v))
		var horn := maxf(maxf(-u - 0.145, u + 0.09), maxf(v - 0.065, 0.025 + (-0.09 - u) * 0.7 - v))
		var waist := maxf(absf(u - 0.005) - 0.045, maxf(v + 0.01, -0.045 - v))
		var foot := maxf(absf(u - 0.005) - 0.085, maxf(v + 0.045, -0.072 - v))
		return maxf(minf(minf(face, horn), minf(waist, foot)), absf(p.z - c.z) - depth)
	g.paint(bounds, anvil, Mat.IRON, t)
	var mark_c := Vector2(c.x + 0.01, c.y + 0.028)
	g.paint(bounds, func(p: Vector3):
		if p.z < c.z + depth - HEAD_CELL:
			return 1.0
		return -1.0 if hearth_mark((p.x - mark_c.x) / 0.036, (p.y - mark_c.y) / 0.036) else 1.0, 0, -1, CARVE)
	g.paint(bounds, func(p: Vector3):
		if p.z < c.z + depth - HEAD_CELL * 2.0 or p.z > c.z + depth - HEAD_CELL:
			return 1.0
		return -1.0 if hearth_mark((p.x - mark_c.x) / 0.036, (p.y - mark_c.y) / 0.036) else 1.0, Mat.BUCKLE_DARK, t, PAINT)
	# Rivets at the horn root and the foot.
	for at: Vector3 in [c + Vector3(-0.075, 0.045, depth), c + Vector3(0.095, 0.045, depth), c + Vector3(-0.06, -0.06, depth),
			c + Vector3(0.07, -0.06, depth)]:
		g.paint(box_of(at, Vector3(0.01, 0.01, 0.01)), func(p: Vector3): return VoxelSdf.box(p, at, Vector3(0.004, 0.004, 0.004)),
			Mat.RIVET, t, ADD)


func _pocket_tools(g: VoxelGrid) -> void:
	var t := Tag.APRON
	# Tongs in the left pocket: two iron arms, jaws up, a rivet at the pivot.
	var z0 := skirt_z(0.8) + BODY_CELL + 0.008
	for k: float in [-1.0, 1.0]:
		var a := Vector3(0.155 + 0.012 * k, 0.76, z0)
		var b := Vector3(0.16 + 0.006 * k, 0.9, z0 + 0.004)
		var jaw := Vector3(0.17 + 0.022 * k, 0.955, z0 + 0.004)
		g.paint(AABB(Vector3(0.1, 0.74, z0 - 0.03), Vector3(0.12, 0.24, 0.06)), func(p: Vector3):
			return minf(VoxelSdf.capsule(p, a, b, 0.0075, 0.0075), VoxelSdf.capsule(p, b, jaw, 0.0085, 0.0095)), Mat.IRON, t)
	var pivot := Vector3(0.16, 0.9, z0 + 0.012)
	g.paint(box_of(pivot, Vector3(0.012, 0.012, 0.012)), func(p: Vector3): return VoxelSdf.sphere(p, pivot, 0.007), Mat.RIVET, t, ADD)
	# A rasp in the right pocket: a wooden handle with an iron ferrule.
	var r0 := Vector3(-0.17, 0.78, z0)
	var r1 := Vector3(-0.185, 0.875, z0 + 0.004)
	var r2 := Vector3(-0.19, 0.935, z0 + 0.006)
	g.paint(AABB(Vector3(-0.24, 0.76, z0 - 0.03), Vector3(0.1, 0.2, 0.06)), func(p: Vector3):
		return VoxelSdf.capsule(p, r1, r2, 0.016, 0.018), Mat.WOOD, t)
	g.paint(AABB(Vector3(-0.24, 0.76, z0 - 0.03), Vector3(0.1, 0.2, 0.06)), func(p: Vector3):
		return VoxelSdf.capsule(p, r0, r1, 0.011, 0.012), Mat.IRON, t)
	var ferrule := r1.lerp(r2, 0.08)
	g.paint(box_of(ferrule, Vector3(0.03, 0.02, 0.03)), func(p: Vector3):
		return maxf(Vector2(p.x - ferrule.x, p.z - ferrule.z).length() - 0.02, absf(p.y - ferrule.y) - 0.006), Mat.IRON_NEW, t)


## Rigid parts the move scan (game/lookdev/move_scan.gd) checks for clipping:
## bone -> sdf in rest space. The boulders, the head and the belly (for the braid).
func clearance_parts() -> Dictionary:
	return {
		&"LeftShoulder": func(p: Vector3) -> float: return boulder_sdf(p, 1.0),
		&"RightShoulder": func(p: Vector3) -> float: return boulder_sdf(p, -1.0),
		&"Head": func(p: Vector3) -> float: return head_sdf(p),
		&"Spine": [func(p: Vector3) -> float: return hull(p, BELLY_C, _belly), BRAID_BONES],
		&"UpperChest": [func(p: Vector3) -> float: return hull(p, CHEST_C, _chest), BRAID_BONES],
	}


# ----------------------------------------------------------------- weights

func weights(tag: int, p: Vector3) -> Array:
	var w := {}
	if tag >= FINGER_BASE:
		var k := tag - FINGER_BASE
		_finger_w(p, w, "Left" if k < 4 else "Right", FINGERS[k % 4])
		return _pack(w)
	match tag:
		Tag.TORSO:
			_torso_w(p, w)
		Tag.NECK:
			var k := smoothstep(1.56, 1.66, p.y)
			_add(w, &"UpperChest", 1.0 - k)
			_add(w, &"Neck", k)
		Tag.ARM_L, Tag.ARM_R:
			_arm_w(p, w, "Left" if tag == Tag.ARM_L else "Right")
		Tag.LEG_L, Tag.LEG_R:
			_leg_w(p, w, "Left" if tag == Tag.LEG_L else "Right")
		Tag.FOOT_L, Tag.FOOT_R:
			var prefix := "Left" if tag == Tag.FOOT_L else "Right"
			var toes := smoothstep(0.08, 0.2, p.z)
			_add(w, StringName(prefix + "Foot"), 1.0 - toes)
			_add(w, StringName(prefix + "Toes"), toes)
		Tag.APRON:
			# Stiff leather: mostly the hips, the flap's spring lower down, and
			# at most 0.25 of the legs at the hem's sides.
			var down := smoothstep(SKIRT_TOP, SKIRT_HEM, p.y)
			var leg := 0.25 * down * smoothstep(0.03, 0.16, absf(p.x))
			var flap := 0.55 * down
			_add(w, &"Hips", 1.0 - leg - flap)
			_add(w, &"ApronFlap", flap)
			_add(w, &"LeftUpperLeg" if p.x > 0.0 else &"RightUpperLeg", leg)
		Tag.BOULDER_L:
			_add(w, &"LeftShoulder", 1.0)
		Tag.BOULDER_R:
			_add(w, &"RightShoulder", 1.0)
		Tag.HEAD:
			_add(w, &"Head", 1.0)
		Tag.BEARD:
			var k := 0.65 * smoothstep(1.62, 1.38, p.y)
			_add(w, &"Head", 1.0 - k)
			_add(w, &"Neck", k)
		Tag.BRAID:
			# Along the chain, blended at the joints so it bends like a plait;
			# the joints sit between the iron rings, which stay rigid.
			var pts := braid_points()
			pts.append(pts[-1] + Vector3(0, -0.1, 0))
			var names: Array = BRAID_BONES.duplicate()
			names.append(BRAID_BONES[-1])
			_chain_w(p, w, pts, names)
		Tag.GAUNT_L, Tag.GAUNT_R:
			# Rigid with the hand; the seam hides under the forearm's wrist cuff.
			_add(w, &"LeftHand" if tag == Tag.GAUNT_L else &"RightHand", 1.0)
		Tag.THUMB_L, Tag.THUMB_R:
			_add(w, &"LeftHand" if tag == Tag.THUMB_L else &"RightHand", 1.0)
	return _pack(w)


func _torso_w(p: Vector3, w: Dictionary) -> void:
	var spine := {}
	_piecewise(p.y, [[0.86, "Hips"], [0.99, "Spine"], [1.14, "Chest"], [1.30, "UpperChest"]], spine, false)
	var shoulder := smoothstep(0.17, 0.29, absf(p.x)) * smoothstep(1.3, 1.45, p.y)
	for b: StringName in spine:
		_add(w, b, spine[b] * (1.0 - shoulder))
	_add(w, &"LeftShoulder" if p.x > 0.0 else &"RightShoulder", shoulder)


func _arm_w(p: Vector3, w: Dictionary, prefix: String) -> void:
	var ax := absf(p.x)
	if ax < 0.27:
		_torso_w(p, w)
		return
	# The forearm (and its wrist cuff) stays on the lower arm: the fist is its own rigid tag.
	_piecewise(ax, [[0.27, prefix + "Shoulder"], [0.48, prefix + "UpperArm"], [0.60, prefix + "UpperArm"],
		[0.72, prefix + "LowerArm"]], w, true)


func _leg_w(p: Vector3, w: Dictionary, prefix: String) -> void:
	if p.y >= 0.84:
		_torso_w(p, w)
		return
	var tmp := {}
	# Boot shaft and shin on the lower leg (the foot is its own rigid tag).
	_piecewise(p.y, [[0.39, prefix + "LowerLeg"], [0.50, prefix + "UpperLeg"], [0.70, prefix + "UpperLeg"],
		[0.84, "Hips"]], tmp, true)
	for b: StringName in tmp:
		_add(w, b, tmp[b])


func _finger_w(p: Vector3, w: Dictionary, prefix: String, finger: String) -> void:
	var pts := PackedVector3Array([rest[StringName(prefix + "Hand")]])
	var names: Array = [StringName(prefix + "Hand")]
	for part: String in ["Proximal", "Intermediate", "Distal"]:
		pts.append(rest[StringName(prefix + finger + part)])
		names.append(StringName(prefix + finger + part))
	pts.append(pts[3] + (pts[3] - pts[2]).normalized() * 0.05)
	# Fingers are spread in z off their bones; measure along x only.
	var q := Vector3(p.x, pts[1].y, pts[1].z)
	_chain_w(q, w, pts, names)
