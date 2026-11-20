class_name VoxelWeaponDesign
extends VoxelDesign
## A rigid, code-built voxel weapon (docs/lookdev/weapons.md): the voxel kit's
## pipeline without a skeleton. Parts are painted in the weapon model space
## WeaponModels uses (grip at the origin, long axis +Y, barrels along -Z), so a
## voxel weapon drops in for the old mesh with the same grip, scale and
## off-hand point. Every material is a shared role; each weapon fills the
## roles with its owner's palette and energy colour (palette()).

## Shared material roles (0 must be EMPTY).
enum Mat {
	EMPTY, BODY, BODY_DARK, EDGE, TRIM, TRIM_DARK, GRIP, GRIP_DARK, LEATHER, WOOD, RIVET,
	ENGRAVE, EMBLEM, GLOW, GLOW_CORE, GLASS, CLOTH, CLOTH_DARK, STITCH, STONE, ACCENT,
}

## World-space size of the fine weapon cell (docs/lookdev/kael.md voxel spec).
const WORLD_CELL := 0.011
## Emission of the GLOW surface: bright enough to read as energy, clamped so bloom stays a thin glow.
const GLOW_EMISSION := 1.1

## Roles that are metal unless a design says otherwise (surface_of).
const METALS := [Mat.BODY, Mat.BODY_DARK, Mat.EDGE, Mat.TRIM, Mat.TRIM_DARK, Mat.RIVET, Mat.ENGRAVE, Mat.EMBLEM]
## Roles that lighten on exposed edges (wear).
const WEARING := [Mat.EDGE, Mat.TRIM, Mat.RIVET, Mat.GRIP, Mat.LEATHER, Mat.WOOD, Mat.STONE, Mat.BODY]
## Roles that keep the calm +-2% noise.
const QUIET := [Mat.BODY, Mat.CLOTH]

var _palette := {}


func _init() -> void:
	super(null)
	_palette = palette()


# ---------------------------------------------------------------- to override

## The weapon kind this design replaces.
func kind() -> Weapon.Kind:
	return Weapon.Kind.NONE


## Role -> sRGB colour: the owner's palette, with the energy colour on GLOW/GLOW_CORE.
func palette() -> Dictionary:
	return {}


## Roles rendered as stone/cloth rather than metal (e.g. Brann's granite core).
func matte_roles() -> Array:
	return []


# ---------------------------------------------------------------- kit overrides

## The authored cell: WORLD_CELL in the world once the grip scale (WeaponGrip.SCALE at the
## reference hand) and the ranged x1.3 are applied.
func cell() -> float:
	return WORLD_CELL / model_scale()


## Scale from authored model space to the world at the reference hand.
func model_scale() -> float:
	var k := kind()
	var s := float(WeaponGrip.SCALE.get(k, 1.0))
	if Weapon.is_ranged(k) and not Weapon.is_bow(k):
		s *= 1.3
	return s


func surface_of(mat: int) -> int:
	match mat:
		Mat.GLOW, Mat.GLOW_CORE:
			return Surf.GLOW
		Mat.GLASS:
			return Surf.GLASS
		Mat.WOOD:
			return Surf.HAIR
	if mat in matte_roles():
		return Surf.CLOTH
	if mat in METALS:
		return Surf.METAL
	return Surf.CLOTH


func color(mat: int, p: Vector3, c: Vector3i, _n: Vector3, occlusion: float, exposure: float) -> Color:
	var base: Color = _palette.get(mat, Color.MAGENTA)
	if mat == Mat.GLOW or mat == Mat.GLOW_CORE:
		# Energy stays bright: a little flicker noise, almost no cavity darkening.
		var e := base * (1.0 + (VoxelSdf.hash3(c, mat) - 0.5) * 0.08)
		e = e.darkened(occlusion * 0.15)
		e.a = 1.0
		return e
	var col := default_color(base, mat, c, occlusion, exposure, mat in QUIET, mat in WEARING)
	if mat in [Mat.GRIP, Mat.LEATHER, Mat.WOOD, Mat.STONE, Mat.CLOTH]:
		# Small parts get the stronger (up to +-6%) variation of the sheets.
		col = col * (1.0 + (VoxelSdf.hash3(c, mat + 7) - 0.5) * 0.06)
		col.a = 1.0
	return col


func weights(_tag: int, _p: Vector3) -> Array:
	return [PackedInt32Array([0, 0, 0, 0]), PackedFloat32Array([1, 0, 0, 0])]


func blur_cells(_grid: VoxelGrid) -> int:
	return 2


func surface_params() -> Array:
	var params := super.surface_params()
	params[Surf.GLOW] = {"roughness_value": 0.4, "emission_value": GLOW_EMISSION, "edge_lift": 0.0,
		"corner_ao": 0.3}
	params[Surf.METAL] = {"roughness_value": 0.38, "metallic_value": 0.7, "specular_value": 0.6,
		"edge_lift": 0.3, "bevel_tilt": 0.6}
	params[Surf.HAIR] = {"roughness_value": 0.62, "specular_value": 0.4, "edge_lift": 0.12}
	return params


# ---------------------------------------------------------------- building

## A grid over bounds at the weapon cell divided by fine (2 = half cell, for emblems).
## Every grid's origin sits on the weapon-cell lattice, so a fine grid meets a coarse one at
## a shared face when the split is snapped (snap()).
func grid(bounds: AABB, fine := 1.0) -> VoxelGrid:
	var c := cell()
	var lo := ((bounds.position - Vector3.ONE * c * 2.0) / c).floor() * c
	var hi := ((bounds.end + Vector3.ONE * c * 2.0) / c).ceil() * c
	return VoxelGrid.new(AABB(lo, hi - lo), c / fine)


## v on the weapon-cell lattice (where a coarse and a fine grid may meet).
func snap(v: float) -> float:
	return snappedf(v, cell())


## A grip wrap: a cylinder a->b of radius r in GRIP_DARK with raised GRIP bands
## spiralling both ways (a diagonal lattice of 1-cell ridges), pitch in metres.
func grip_wrap(g: VoxelGrid, a: Vector3, b: Vector3, r: float, pitch: float, mat := Mat.GRIP,
		recess := Mat.GRIP_DARK) -> void:
	var box := _segment_box(a, b, r + g.cell * 1.5)
	g.paint(box, func(p: Vector3) -> float: return VoxelSdf.cylinder(p, a, b, r, r), recess)
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var up := axis.cross(side)
	var length := a.distance_to(b)
	g.paint(box, func(p: Vector3) -> float:
		var d := p - a
		var t := d.dot(axis)
		if t < g.cell or t > length - g.cell:
			return 1.0
		var ang := atan2(d.dot(up), d.dot(side)) / TAU
		var band := fposmod(t / pitch + ang * 2.0, 1.0)
		if band > 0.42:
			return 1.0
		return VoxelSdf.cylinder(p, a, b, r + g.cell * 0.95, r + g.cell * 0.95), mat, -1, ADD)
	# The lattice: the second spiral recolours the recess where it crosses (ridges stay 1 cell).
	g.paint(box, func(p: Vector3) -> float:
		var cc := g.cell_of(p)
		if g.get_mat(cc.x, cc.y, cc.z) != recess:
			return 1.0
		var d := p - a
		var ang := atan2(d.dot(up), d.dot(side)) / TAU
		var band := fposmod(d.dot(axis) / pitch - ang * 2.0, 1.0)
		return -1.0 if band < 0.12 else 1.0, mat, -1, PAINT)


## A domed rivet head at p on a face with normal n (r in metres, at least ~1 cell).
func rivet(g: VoxelGrid, p: Vector3, n: Vector3, r := -1.0, mat := Mat.RIVET) -> void:
	var rr := maxf(r, g.cell * 1.1)
	var c := p + n * rr * 0.2
	g.paint(AABB(c - Vector3.ONE * rr * 1.5, Vector3.ONE * rr * 3.0),
		func(q: Vector3) -> float: return VoxelSdf.ellipsoid(q, c, Vector3.ONE * rr), mat, -1, FILL)


## Paints (or engraves) a 2D mark on the surface facing n around centre: mask(q) is tested
## with q in [-1, 1]^2 along (u, v) at half-size size. Engraving carves the mark one cell
## deep and darkens its walls with floor_mat.
func mark(g: VoxelGrid, centre: Vector3, u: Vector3, v: Vector3, size: float, mask: Callable,
		mat: int, engrave := false, floor_mat := Mat.ENGRAVE) -> void:
	var n := u.cross(v).normalized()
	var reach := Vector3.ONE * (size * 1.5 + g.cell * 3.0)
	var box := AABB(centre - reach, reach * 2.0)
	var hits: Array[Vector3i] = []
	g.paint_surface(box, func(p: Vector3, c: Vector3i) -> bool:
		var d := p - centre
		var depth := d.dot(n)
		if depth < -g.cell * 2.5 or depth > g.cell * 2.5:
			return false
		# Only cells whose open side faces n (not the far face of a thin part).
		var o := Vector3i((Vector3(c) + n * 1.01).round())
		if g.get_mat(o.x, o.y, o.z) != 0:
			return false
		var q := Vector2(d.dot(u), d.dot(v)) / size
		if absf(q.x) > 1.0 or absf(q.y) > 1.0 or not mask.call(q):
			return false
		hits.append(c)
		return true, mat)
	if not engrave:
		return
	for c in hits:
		g.mats[g.index(c.x, c.y, c.z)] = 0
	var down := Vector3i((-n).round())
	for c in hits:
		var o := c + down
		if g.get_mat(o.x, o.y, o.z) != 0:
			g.mats[g.index(o.x, o.y, o.z)] = mat if floor_mat < 0 else floor_mat


## Darker 1-cell crack seams (glowing for Brann) along surface cells near a polyline.
func seam(g: VoxelGrid, pts: PackedVector3Array, width: float, mat: int, only: Array = []) -> void:
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var box := AABB(lo, hi - lo).grow(width + g.cell * 2.0)
	g.paint_surface(box, func(p: Vector3, _c: Vector3i) -> bool:
		for i in pts.size() - 1:
			if Geometry3D.get_closest_point_to_segment(p, pts[i], pts[i + 1]).distance_to(p) <= width:
				return true
		return false, mat, only)


## Whether the cell at p holds mat (for PAINT passes that must not spill onto other parts).
static func holds(g: VoxelGrid, p: Vector3, mat: int) -> bool:
	var cc := g.cell_of(p)
	return g.get_mat(cc.x, cc.y, cc.z) == mat


static func _segment_box(a: Vector3, b: Vector3, r: float) -> AABB:
	var lo := a.min(b) - Vector3.ONE * r
	return AABB(lo, a.max(b) + Vector3.ONE * r - lo)


# ---------------------------------------------------------------- emblems (q in [-1, 1]^2, +y up)

## Kael's winged-sky sigil: a ring (the sky), a centre dot and two stepped feathers per side.
static func winged_sky(q: Vector2) -> bool:
	var r := q.length()
	if (r > 0.32 and r < 0.56) or r < 0.16:
		return true
	var ax := absf(q.x)
	for f in 2:
		var x0 := 0.7 + f * 0.2
		var top := 0.34 - f * 0.18
		if absf(ax - x0) < 0.08 and q.y < top and q.y > top - 0.6 + f * 0.12:
			return true
	return false


## Vexa's Crescent Eye: a crescent cupped around a diamond pupil, three rays from its open side.
static func crescent_eye(q: Vector2) -> bool:
	var crescent := q.length() < 0.72 and (q - Vector2(0.34, 0)).length() > 0.56
	var pupil := absf(q.x - 0.12) + absf(q.y) * 0.8 < 0.26
	var rays := false
	for a: float in [-0.55, 0.0, 0.55]:
		var dir := Vector2(cos(a), sin(a))
		var t := (q - Vector2(0.42, 0)).dot(dir)
		var off := absf((q - Vector2(0.42, 0)).cross(dir))
		if t > 0.3 and t < 0.58 and off < 0.07:
			rays = true
	return crescent or pupil or rays


## Lyra's Wayfinder Star: an eight-point star with a long plumb-line lower point inside a
## circle broken at the upper right.
static func wayfinder_star(q: Vector2) -> bool:
	var r := q.length()
	var a := atan2(q.y, q.x)
	var star := r < 0.13 + 0.3 * pow(absf(cos(a * 2.0)), 6.0) + 0.12 * pow(absf(cos(a * 2.0 + PI * 0.5)), 6.0)
	var plumb := absf(q.x) < 0.06 + maxf(0.0, (q.y + 0.25) * 0.15) and q.y < -0.1 and q.y > -0.98
	var deg := rad_to_deg(a)
	var ring := r > 0.62 and r < 0.76 and not (deg > 15.0 and deg < 75.0) and not (absf(q.x) < 0.09 and q.y < 0.0)
	return star or plumb or ring


## Brann's Hearth-Mark: an anvil side-on with three stacked flame chevrons, in a square frame
## with notched corners.
static func hearth_mark(q: Vector2) -> bool:
	var m := maxf(absf(q.x), absf(q.y))
	var frame := m > 0.8 and m < 0.97 and not (absf(q.x) > 0.8 and absf(q.y) > 0.8)
	var anvil_top := q.y > -0.22 and q.y < -0.04 and q.x > -0.6 + (q.y + 0.22) * -0.8 and q.x < 0.48
	var waist := absf(q.x) < 0.16 and q.y <= -0.22 and q.y > -0.46
	var foot := absf(q.x) < 0.42 and q.y <= -0.46 and q.y > -0.62
	var flame := false
	for k in 3:
		var y0 := 0.22 + k * 0.17
		if absf(q.x) < 0.3 - k * 0.06 and absf(q.y - (y0 - absf(q.x) * 0.9)) < 0.055:
			flame = true
	return frame or anvil_top or waist or foot or flame


## The item family's drop mark (shared pickups): a four-point spark in a ring.
static func item_spark(q: Vector2) -> bool:
	var r := q.length()
	var spark := absf(q.x) * absf(q.y) < 0.012 and r < 0.62
	return spark or (r > 0.7 and r < 0.86) or r < 0.14


## A heart (the Heartbloom item family).
static func heart(q: Vector2) -> bool:
	var x := q.x * 1.25
	var y := q.y * 1.25 + 0.15
	var a := x * x + y * y - 1.0
	return a * a * a - x * x * y * y * y <= 0.0
