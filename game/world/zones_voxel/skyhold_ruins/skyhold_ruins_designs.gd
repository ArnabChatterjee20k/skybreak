class_name SkyholdRuinsDesigns
extends RefCounted
## The voxel designs of Skyhold Ruins (docs/lookdev/skyhold_ruins.md): drum
## columns, voussoir arches, the Crown Gate, the Watch stump, verdigris bronze
## statues and braziers, the stairs to nowhere, chains, nests, altars, walls,
## rubble and flowers. Each builder returns cached VoxelProp meshes; `k` scales
## the cell for coarser LOD tiers.

## Bump after changing any design (the meshes are cached on disk).
const VERSION := 5
const T0 := VoxelZone.T0
const T1 := VoxelZone.T1
const T2 := VoxelZone.T2

enum Mat {
	EMPTY, LIME, LIME_DARK, MARBLE, MARBLE_DARK, MORTAR, MOSS, IVY, FLOWER_W, FLOWER_Y,
	BRONZE, VERDIGRIS, PATINA, CHAIN, ROCK, ROOT, FLAME, ASH, NEST, FEATHER, SOIL, GLYPH, STEM, EGG,
}
## Palette (sRGB) from the sheet. Verdigris is the one accent: bronze only.
const COLORS := {
	Mat.LIME: Color("#D4BE96"), Mat.LIME_DARK: Color("#b29c78"), Mat.MARBLE: Color("#E6DCC8"),
	Mat.MARBLE_DARK: Color("#c4b8a2"), Mat.MORTAR: Color("#8a7660"), Mat.MOSS: Color("#7A8A58"),
	Mat.IVY: Color("#4E6A3E"), Mat.FLOWER_W: Color("#ECE8DC"), Mat.FLOWER_Y: Color("#E4D89A"),
	Mat.BRONZE: Color("#5A4A34"), Mat.VERDIGRIS: Color("#4AB49A"), Mat.PATINA: Color("#8fb8a4"),
	Mat.CHAIN: Color("#4a3e30"), Mat.ROCK: Color("#6A5A4E"), Mat.ROOT: Color("#5a4636"),
	Mat.FLAME: Color("#f6b870"), Mat.ASH: Color("#5c5650"), Mat.NEST: Color("#8a6e4c"),
	Mat.FEATHER: Color("#f0ece4"), Mat.SOIL: Color("#5a4838"), Mat.GLYPH: Color("#9a8466"),
	Mat.STEM: Color("#6a7f48"), Mat.EGG: Color("#e8e0cc"),
}

var _k := 1.0


# ---------------------------------------------------------------- colour

func color(mat: int, p: Vector3, c: Vector3i, n: Vector3, occlusion: float, exposure: float) -> Color:
	var base: Color = COLORS.get(mat, Color.MAGENTA)
	var quiet := mat in [Mat.LIME, Mat.MARBLE, Mat.MARBLE_DARK, Mat.LIME_DARK]
	if mat == Mat.VERDIGRIS or mat == Mat.BRONZE:
		# Bronze gone green: verdigris on exposed faces and in streaks, dark
		# bronze in the recesses, a little lighter on the upward faces.
		var streak := VoxelSdf.hash3(Vector3i(c.x, 0, c.z), 41)
		var green := clampf(0.55 + 0.25 * maxf(n.y, 0.0) - occlusion * 1.6 + (streak - 0.5) * 0.45, 0.0, 1.0)
		if mat == Mat.BRONZE:
			green *= 0.35
		var col := COLORS[Mat.BRONZE].lerp(COLORS[Mat.VERDIGRIS], green)
		col = col.lerp(col.lightened(0.25), exposure * 0.5)
		col *= 0.94 + 0.12 * VoxelSdf.hash3(c, 43)
		col.a = 1.0
		return col
	if mat == Mat.FLAME:
		var f := Color("#e07a38").lerp(Color("#ffe4a8"), clampf((p.y - 1.45) / 0.7, 0.0, 1.0))
		f.a = 1.0
		return f
	var col := VoxelDesign.default_color(base, mat, c, occlusion, exposure, quiet,
		mat in [Mat.LIME, Mat.MARBLE, Mat.LIME_DARK, Mat.MARBLE_DARK])
	if mat in [Mat.MOSS, Mat.IVY, Mat.ROCK, Mat.NEST, Mat.ROOT]:
		col *= 0.94 + 0.12 * VoxelSdf.hash3(c, 47)
	if mat in [Mat.LIME, Mat.MARBLE] and n.y < -0.5:
		col = col.darkened(0.12)
	col.a = 1.0
	return col


func surface_of(mat: int) -> int:
	match mat:
		Mat.BRONZE, Mat.VERDIGRIS, Mat.CHAIN:
			return VoxelProp.Surf.METAL
		Mat.FLAME:
			return VoxelProp.Surf.GLOW
		Mat.MOSS, Mat.IVY, Mat.FLOWER_W, Mat.FLOWER_Y, Mat.STEM, Mat.FEATHER:
			return VoxelProp.Surf.PETAL
		Mat.ROOT, Mat.NEST:
			return VoxelProp.Surf.BARK
	return VoxelProp.Surf.MATTE


func _mesh(key: String, bounds: AABB, cell: float, paint: Callable) -> ArrayMesh:
	return VoxelProp.mesh("sky_" + key, VERSION, bounds, cell * _k, paint, color, surface_of)


## The design make() builds, at each cell multiplier in ks (finest first).
func tiers(make: Callable, ks: Array) -> Array[ArrayMesh]:
	var out: Array[ArrayMesh] = []
	for k: float in ks:
		_k = k
		out.append(make.call())
	_k = 1.0
	return out


static func _h(c: Vector3i, salt: int) -> float:
	return VoxelSdf.hash3(c, salt)


## Grooves one cell deep where `joint(p)` is true and the cell is on the skin
## of the solid (within `skin` of the surface sdf `solid`).
static func _groove(g: VoxelGrid, bounds: AABB, solid: Callable, joint: Callable, skin: float) -> void:
	g.paint(bounds, func(p: Vector3) -> float:
		var d: float = solid.call(p)
		return -1.0 if d > -skin and joint.call(p) else 1.0, 0, -1, VoxelGrid.Mode.CARVE)


# ---------------------------------------------------------------- columns

## Column heights above the paving (m) for the whole column and the broken
## variants the sim's broken heights (4-10 m above its base) snap to.
const COLUMN_WHOLE := 16.4
const COLUMN_BROKEN: Array[float] = [4.9, 6.4, 7.9, 9.4]


## A fluted marble column: a square stylobate block (0.4 m, bridging the
## paving to the sim's column base), a moulded base, shaft drums with 20 flutes
## and joints, a capital (whole only) or a jagged break showing a drum joint;
## chips, moss at the foot, ivy on some.
func column(variant: int) -> ArrayMesh:
	var whole := variant == 0
	var height := COLUMN_WHOLE if whole else COLUMN_BROKEN[variant - 1]
	var bounds := AABB(Vector3(-1.6, 0, -1.6), Vector3(3.2, height + 0.1, 3.2))
	var paint := func(g: VoxelGrid) -> void:
		var cell := g.cell
		var shaft_lo := 0.78
		var shaft_hi := COLUMN_WHOLE - 0.95
		var radius := func(y: float) -> float: return 1.12 - 0.14 * clampf((y - shaft_lo) / (shaft_hi - shaft_lo), 0.0, 1.0)
		var drum := 1.62
		g.paint(AABB(Vector3(-1.5, 0, -1.5), Vector3(3.0, 0.4, 3.0)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 0.2, 0), Vector3(1.48, 0.2, 1.48)), Mat.LIME_DARK)
		g.paint(AABB(Vector3(-1.45, 0.4, -1.45), Vector3(2.9, 0.4, 2.9)), func(p: Vector3) -> float:
			var r := Vector2(p.x, p.z).length()
			return r - (1.42 if p.y < 0.55 else 1.28), Mat.MARBLE)
		var top := shaft_hi if whole else height
		var shaft_solid := func(p: Vector3) -> float: return Vector2(p.x, p.z).length() - radius.call(p.y)
		g.paint(AABB(Vector3(-1.2, shaft_lo, -1.2), Vector3(2.4, top - shaft_lo, 2.4)), shaft_solid, Mat.MARBLE)
		if whole:
			g.paint(AABB(Vector3(-1.5, shaft_hi, -1.5), Vector3(3.0, 0.5, 3.0)), func(p: Vector3) -> float:
				var t := (p.y - shaft_hi) / 0.5
				return Vector2(p.x, p.z).length() - lerpf(0.98, 1.42, t * t), Mat.MARBLE)
			g.paint(AABB(Vector3(-1.55, shaft_hi + 0.5, -1.55), Vector3(3.1, 0.45, 3.1)), func(p: Vector3) -> float:
				return VoxelSdf.box(p, Vector3(0, shaft_hi + 0.72, 0), Vector3(1.5, 0.22, 1.5)), Mat.MARBLE)
		# Flutes and drum joints.
		var shaft_box := AABB(Vector3(-1.2, shaft_lo, -1.2), Vector3(2.4, top - shaft_lo, 2.4))
		_groove(g, shaft_box, shaft_solid, func(p: Vector3) -> bool:
			var f := fposmod(atan2(p.z, p.x) / TAU * 20.0, 1.0)
			return absf(f - 0.5) < 0.2, cell * 1.05)
		_groove(g, shaft_box, shaft_solid, func(p: Vector3) -> bool:
			return fposmod(p.y - shaft_lo, drum) < cell, cell * 1.05)
		if not whole:
			# A jagged break: the top drum shears off along a wavy line, one
			# side lower, with a chunk missing.
			var seed := float(variant) * 1.7
			g.paint(AABB(Vector3(-1.6, height - 1.4, -1.6), Vector3(3.2, 1.6, 3.2)), func(p: Vector3) -> float:
				var a := atan2(p.z, p.x)
				var cut := height - 0.55 + 0.45 * sin(a + seed) + 0.18 * sin(a * 3.0 + seed * 2.0) \
					+ 0.08 * (VoxelSdf.hash3(g.cell_of(p) * Vector3i(1, 0, 1), 5) - 0.5)
				return cut - p.y, 0, -1, VoxelGrid.Mode.CARVE)
			var chunk := Vector3(cos(seed) * 1.1, height - 1.0, sin(seed) * 1.1)
			g.paint(AABB(chunk - Vector3.ONE * 0.8, Vector3.ONE * 1.6), func(p: Vector3) -> float:
				return VoxelSdf.box(p, chunk, Vector3(0.55, 0.5, 0.5)), 0, -1, VoxelGrid.Mode.CARVE)
		# Chips on the skin, moss at the foot, ivy climbing on some.
		g.paint(shaft_box, func(p: Vector3) -> float:
			var c := g.cell_of(p)
			return -1.0 if shaft_solid.call(p) > -cell * 1.05 and VoxelSdf.hash3(c, 9 + variant) < 0.02 else 1.0,
			0, -1, VoxelGrid.Mode.CARVE)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y < 1.6 and VoxelSdf.hash3(c, 13) < (1.6 - p.y) * 0.45, Mat.MOSS, [Mat.MARBLE, Mat.LIME_DARK])
		if variant in [0, 2, 4]:
			var side := float(variant) * 2.1
			g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
				var a := wrapf(atan2(p.z, p.x) - side, -PI, PI)
				var reach := 3.5 + 2.5 * sin(a * 5.0 + side) - absf(a) * 3.0
				return p.y < reach and absf(a) < 1.1 and VoxelSdf.hash3(c, 17) < 0.5, Mat.IVY, [Mat.MARBLE, Mat.MOSS])
		# Darker stone in the flutes' depths reads from the cavity AO; lighter
		# worn edges come from exposure.
	return _mesh("column%d" % variant, bounds, T1, paint)


## A fallen column: four fluted drums lying in a row, rolled apart, and the
## capital on its side.
func fallen_column() -> ArrayMesh:
	var bounds := AABB(Vector3(-7.5, 0, -2.0), Vector3(15.0, 3.2, 4.0))
	var paint := func(g: VoxelGrid) -> void:
		var cell := g.cell
		var drums := [[-5.8, 0.0, 0.0], [-3.9, 0.25, 0.1], [-1.7, -0.3, 0.25], [0.7, 0.5, -0.2]]
		for d: Array in drums:
			var x0: float = d[0]
			var dz: float = d[1]
			var c := Vector3(x0 + 0.8, 1.05, dz)
			var solid := func(p: Vector3) -> float: return Vector2(p.y - c.y, p.z - c.z).length() - 1.05
			var box := AABB(Vector3(x0, 0, dz - 1.2), Vector3(1.6, 2.2, 2.4))
			g.paint(box, func(p: Vector3) -> float:
				return maxf(solid.call(p), absf(p.x - c.x) - 0.78), Mat.MARBLE)
			var turn: float = d[2]
			_groove(g, box, func(p: Vector3) -> float: return maxf(solid.call(p), absf(p.x - c.x) - 0.78),
				func(p: Vector3) -> bool:
					var f := fposmod(atan2(p.z - c.z, p.y - c.y) / TAU * 20.0 + turn, 1.0)
					return absf(f - 0.5) < 0.2, cell * 1.05)
		# The capital, tipped over.
		g.paint(AABB(Vector3(3.2, 0, -1.6), Vector3(3.2, 3.1, 3.2)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(4.8, 1.5, 0.0), Vector3(0.24, 1.48, 1.48)), Mat.MARBLE)
		g.paint(AABB(Vector3(3.2, 0, -1.6), Vector3(3.2, 3.1, 3.2)), func(p: Vector3) -> float:
			var t := clampf((5.04 - p.x) / 0.5, 0.0, 1.0)
			return maxf(Vector2(p.y - 1.5, p.z).length() - lerpf(1.42, 0.98, t * t), maxf(p.x - 5.5, 4.55 - p.x)), Mat.MARBLE)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y < 0.5 and VoxelSdf.hash3(c, 19) < 0.5, Mat.MOSS, [Mat.MARBLE])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y > 1.9 and VoxelSdf.hash3(c, 23) < 0.06, Mat.MOSS, [Mat.MARBLE])
	return _mesh("fallen_column", bounds, T1, paint)


# ---------------------------------------------------------------- arches

## Arch geometry (the sim's 18 x 20 x 4 m arch, standing on the paving):
## piers at |x| 5.76-9, springing at SPRING, voussoirs 5.76-8.0 m from the
## centre, spandrels, architrave, a glyph frieze and a cornice up to 20.4 m.
const SPRING := 11.4
const INTRADOS := 5.76
const EXTRADOS := 8.0


## One pier (the right one; the left is the same mesh turned half a turn):
## laid ashlar courses with staggered joints, a plinth and an impost.
func arch_pier(grand: bool) -> ArrayMesh:
	var bounds := AABB(Vector3(5.2, 0, -2.6), Vector3(4.4, SPRING + 0.2, 5.2))
	var paint := func(g: VoxelGrid) -> void:
		var cell := g.cell
		var solid := func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(7.38, SPRING * 0.5, 0), Vector3(1.62, SPRING * 0.5, 2.0))
		g.paint(bounds, solid, Mat.LIME)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(7.38, 0.35, 0), Vector3(1.95, 0.35, 2.35)), Mat.LIME_DARK)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(7.38, SPRING - 0.25, 0), Vector3(1.85, 0.25, 2.25)), Mat.MARBLE)
		if grand:
			# Engaged pilasters on both faces, fluted.
			for zs: float in [-1.0, 1.0]:
				g.paint(bounds, func(p: Vector3) -> float:
					return VoxelSdf.box(p, Vector3(7.38, SPRING * 0.5, zs * 2.15), Vector3(0.75, SPRING * 0.5 - 0.7, 0.2)), Mat.MARBLE)
		var course := 0.88
		_groove(g, bounds, solid, func(p: Vector3) -> bool:
			var row := floori(p.y / course)
			var off := 0.8 if row % 2 == 1 else 0.0
			var along := p.z if absf(absf(p.x - 7.38) - 1.62) < cell * 1.5 else p.x
			return fposmod(p.y, course) < cell or fposmod(along + off, 1.6) < cell, cell * 1.05)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y < 1.4 and VoxelSdf.hash3(c, 29) < (1.4 - p.y) * 0.5, Mat.MOSS, [Mat.LIME, Mat.LIME_DARK])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return VoxelSdf.hash3(Vector3i(c.x, floori(p.y / course), c.z), 31) < 0.05, Mat.LIME_DARK, [Mat.LIME])
	return _mesh("arch_pier%d" % int(grand), bounds, T1, paint)


## The arch's upper part: 13 voussoirs with a keystone carrying the Winged
## Keystone, ashlar spandrels, architrave, a frieze with an original glyph
## band, and a cornice. ruined: a jagged bite out of one top corner. grand
## (the Crown Gate): an attic storey with a cast bronze Winged Keystone.
func arch_top(ruined: bool, grand: bool) -> ArrayMesh:
	var top := 25.4 if grand else 20.6
	var bounds := AABB(Vector3(-10.4, SPRING - 0.3, -2.8), Vector3(20.8, top - SPRING + 0.4, 5.6))
	var paint := func(g: VoxelGrid) -> void:
		var cell := g.cell
		var c := Vector2(0, SPRING)
		var ring := func(p: Vector3) -> float:
			var r := Vector2(p.x, p.y - SPRING).length()
			return maxf(maxf(INTRADOS - r, r - EXTRADOS), maxf(SPRING - p.y, absf(p.z) - 2.0))
		g.paint(bounds, ring, Mat.MARBLE)
		# Keystone: proud of the ring.
		var key := func(p: Vector3) -> float:
			return maxf(VoxelSdf.box(p, Vector3(0, SPRING + 7.0, 0), Vector3(0.75, 1.5, 2.15)), INTRADOS - 0.1 - Vector2(p.x, p.y - SPRING).length())
		g.paint(bounds, key, Mat.MARBLE)
		# Spandrels up to the architrave.
		var span := func(p: Vector3) -> float:
			var r := Vector2(p.x, p.y - SPRING).length()
			return maxf(VoxelSdf.box(p, Vector3(0, (SPRING + 17.4) * 0.5, 0), Vector3(9.0, (17.4 - SPRING) * 0.5, 1.9)), EXTRADOS - r)
		g.paint(bounds, span, Mat.LIME, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 17.9, 0), Vector3(9.4, 0.5, 2.2)), Mat.MARBLE)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 18.9, 0), Vector3(9.3, 0.5, 2.1)), Mat.LIME)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 19.75, 0), Vector3(10.1, 0.35, 2.55)), Mat.MARBLE)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 20.3, 0), Vector3(9.8, 0.2, 2.35)), Mat.MARBLE_DARK)
		# Voussoir joints (radial) and spandrel courses.
		_groove(g, bounds, ring, func(p: Vector3) -> bool:
			var a := atan2(p.y - SPRING, p.x)
			var r := Vector2(p.x, p.y - SPRING).length()
			return fposmod(a / PI * 13.0, 1.0) * r * PI / 13.0 < cell * 1.0, cell * 1.05)
		_groove(g, bounds, span, func(p: Vector3) -> bool:
			var row := floori(p.y / 0.88)
			return fposmod(p.y, 0.88) < cell or fposmod(p.x + (0.8 if row % 2 == 1 else 0.0), 1.6) < cell, cell * 1.05)
		# The glyph band: original angular glyphs, 0.5 m cells, recessed on both faces.
		g.paint(AABB(Vector3(-9.3, 18.45, -2.2), Vector3(18.6, 0.9, 4.4)), func(p: Vector3) -> float:
			if absf(absf(p.z) - 2.1) > cell * 1.05:
				return 1.0
			var gx := floori((p.x + 9.3) / 0.5)
			var lx := fposmod(p.x + 9.3, 0.5) / 0.5
			var ly := (p.y - 18.5) / 0.8
			if lx < 0.12 or lx > 0.88 or ly < 0.12 or ly > 0.88:
				return 1.0
			var h := VoxelSdf.hash3(Vector3i(gx, 0, 0), 33)
			var bar_v := absf(lx - (0.3 + 0.4 * h)) < 0.1
			var bar_h := absf(ly - (0.25 + 0.5 * VoxelSdf.hash3(Vector3i(gx, 1, 0), 35))) < 0.1 and lx > 0.25
			return -1.0 if bar_v or bar_h else 1.0, 0, -1, VoxelGrid.Mode.CARVE)
		# The Winged Keystone on the keystone faces: a trapezoid with two swept wings.
		var emblem := func(lp: Vector2, s: float) -> bool:
			var x := absf(lp.x) / s
			var y := lp.y / s
			var stone := y > -0.5 and y < 0.5 and x < 0.32 + 0.12 * y
			var wing := y > -0.1 and y < 0.45 and x > 0.42 and x < 1.2 and y > (x - 0.42) * 0.55 - 0.1 \
				and fposmod(x * 5.0, 1.0) > 0.25
			return stone or wing
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return absf(p.z) > 2.0 and emblem.call(Vector2(p.x, p.y - SPRING - 7.0), 1.1), Mat.MARBLE_DARK, [Mat.MARBLE])
		if grand:
			# Attic: a raised block with a cast bronze Winged Keystone on both faces,
			# a moulded cap, and stepped plinths at its ends.
			g.paint(bounds, func(p: Vector3) -> float:
				return VoxelSdf.box(p, Vector3(0, 22.6, 0), Vector3(7.2, 2.2, 1.8)), Mat.LIME)
			g.paint(bounds, func(p: Vector3) -> float:
				return VoxelSdf.box(p, Vector3(0, 25.0, 0), Vector3(7.6, 0.3, 2.1)), Mat.MARBLE)
			for xs: float in [-1.0, 1.0]:
				g.paint(bounds, func(p: Vector3) -> float:
					return VoxelSdf.box(p, Vector3(xs * 8.6, 21.0, 0), Vector3(1.0, 0.6, 1.6)), Mat.MARBLE)
			_groove(g, AABB(Vector3(-7.3, 20.4, -1.9), Vector3(14.6, 4.4, 3.8)), func(p: Vector3) -> float:
				return VoxelSdf.box(p, Vector3(0, 22.6, 0), Vector3(7.2, 2.2, 1.8)), func(p: Vector3) -> bool:
					var row := floori(p.y / 0.88)
					return fposmod(p.y, 0.88) < cell or fposmod(p.x + (0.8 if row % 2 == 1 else 0.0), 1.6) < cell, cell * 1.05)
			g.paint(bounds, func(p: Vector3) -> float:
				if absf(p.z) < 1.8 or absf(p.z) > 2.05:
					return 1.0
				return -1.0 if emblem.call(Vector2(p.x, p.y - 22.6), 1.9) else 1.0, Mat.VERDIGRIS)
			# Patina streaks down the attic below the bronze.
			g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
				return absf(p.z) > 1.7 and p.y < 21.8 and p.y > 19.0 and absf(p.x) < 2.2 \
					and VoxelSdf.hash3(Vector3i(c.x, 0, c.z), 37) < 0.3 - (21.8 - p.y) * 0.08, Mat.PATINA,
					[Mat.LIME, Mat.MARBLE])
		if ruined:
			g.paint(bounds, func(p: Vector3) -> float:
				var d := Vector2(p.x - 8.6, p.y - 21.5).length() - 4.0
				d += 0.6 * sin(p.x * 2.1 + p.y * 1.3) + 0.3 * VoxelSdf.hash3(g.cell_of(p) / 3, 39)
				return d, 0, -1, VoxelGrid.Mode.CARVE)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y > 19.9 and VoxelSdf.hash3(c, 41) < 0.12, Mat.MOSS, [Mat.MARBLE, Mat.MARBLE_DARK, Mat.LIME])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return VoxelSdf.hash3(Vector3i(c.x / 4, c.y / 4, c.z), 43) < 0.06, Mat.MARBLE_DARK, [Mat.MARBLE])
	return _mesh("arch_top%d%d" % [int(ruined), int(grand)], bounds, T1, paint)


# ---------------------------------------------------------------- watch stump

## The Watch tower's broken stump (T2): a square ashlar tower 9 m across with
## a battered plinth, a doorway, window slits, a jagged top 13-19 m up and a
## rubble apron.
func watch_stump() -> ArrayMesh:
	var bounds := AABB(Vector3(-7, 0, -7), Vector3(14, 20, 14))
	var paint := func(g: VoxelGrid) -> void:
		var cell := g.cell
		var solid := func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 10, 0), Vector3(4.5, 10, 4.5))
		g.paint(bounds, solid, Mat.LIME)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 0.7, 0), Vector3(5.3 - p.y * 0.4, 0.7, 5.3 - p.y * 0.4)), Mat.LIME_DARK)
		# Hollow inside, door and slits.
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 11, 0), Vector3(3.4, 10.5, 3.4)), 0, -1, VoxelGrid.Mode.CARVE)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 1.8, 4.5), Vector3(1.1, 1.8, 1.2)), 0, -1, VoxelGrid.Mode.CARVE)
		g.paint(bounds, func(p: Vector3) -> float:
			return Vector2(p.x, p.y - 3.6).length() - 1.1 if absf(p.z - 4.5) < 1.2 else 1.0, 0, -1, VoxelGrid.Mode.CARVE)
		for s: Array in [[Vector3(0, 8.5, -4.5), Vector3(0.25, 1.0, 1.2)], [Vector3(4.5, 7.0, 0), Vector3(1.2, 1.0, 0.25)],
				[Vector3(-4.5, 10.5, 1.5), Vector3(1.2, 1.0, 0.25)], [Vector3(1.8, 11.5, 4.5), Vector3(0.25, 1.0, 1.2)]]:
			var at: Vector3 = s[0]
			var half: Vector3 = s[1]
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, at, half), 0, -1, VoxelGrid.Mode.CARVE)
		# The break: high on one corner, low on the other, stepped by courses.
		g.paint(bounds, func(p: Vector3) -> float:
			var course := floorf(p.y / 1.05)
			var cut := 13.0 + (p.x + p.z) * 0.55 + 1.2 * sin(p.x * 0.9) + 0.8 * cos(p.z * 1.3)
			return floorf(cut / 1.05) * 1.05 - course * 1.05 - 0.5, 0, -1, VoxelGrid.Mode.CARVE)
		_groove(g, bounds, solid, func(p: Vector3) -> bool:
			var row := floori(p.y / 1.05)
			var along := p.z if absf(absf(p.x) - 4.5) < cell * 1.5 else p.x
			return fposmod(p.y, 1.05) < cell * 0.9 or fposmod(along + (1.0 if row % 2 == 1 else 0.0), 2.0) < cell * 0.9, cell * 1.05)
		# Rubble apron on the low side.
		var rng := RandomNumberGenerator.new()
		rng.seed = 911
		for k in 22:
			var at := Vector3(rng.randf_range(-6.5, 6.5), 0.0, rng.randf_range(-6.5, 6.5))
			if absf(at.x) < 4.8 and absf(at.z) < 4.8:
				continue
			var half := Vector3(rng.randf_range(0.4, 0.9), rng.randf_range(0.3, 0.5), rng.randf_range(0.4, 0.8))
			at.y = half.y
			g.paint(AABB(at - half - Vector3.ONE * 0.4, half * 2 + Vector3.ONE * 0.8), func(p: Vector3) -> float:
				return VoxelSdf.box(p, at, half), Mat.LIME, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return VoxelSdf.hash3(c, 47) < (0.5 if p.y < 1.5 else 0.06), Mat.MOSS, [Mat.LIME, Mat.LIME_DARK])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return VoxelSdf.hash3(Vector3i(c.x / 3, c.y / 3, c.z / 3), 49) < 0.12, Mat.LIME_DARK, [Mat.LIME])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.x < -4.4 and p.y < 9.0 - absf(p.z) * 1.2 and VoxelSdf.hash3(c, 51) < 0.6, Mat.IVY, [Mat.LIME, Mat.MOSS])
	return _mesh("watch_stump", bounds, T2, paint)


# ---------------------------------------------------------------- statues

## A plinth (marble, moulded, with a cast bronze Winged Keystone on its front
## and patina streaks running down below the bronze figure).
func _plinth(g: VoxelGrid, half: Vector3, bounds: AABB) -> void:
	var h := half.y * 2.0
	g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, half.y, 0), half), Mat.MARBLE)
	g.paint(bounds, func(p: Vector3) -> float:
		return VoxelSdf.box(p, Vector3(0, 0.15, 0), half + Vector3(0.15, -half.y + 0.15, 0.15)), Mat.MARBLE_DARK)
	g.paint(bounds, func(p: Vector3) -> float:
		return VoxelSdf.box(p, Vector3(0, h - 0.1, 0), half + Vector3(0.12, -half.y + 0.1, 0.12)), Mat.MARBLE_DARK)
	g.paint(bounds, func(p: Vector3) -> float:
		if absf(p.z - half.z) > g.cell * 1.1:
			return 1.0
		var x := absf(p.x) / 0.36
		var y := (p.y - h * 0.5) / 0.36
		var stone := y > -0.5 and y < 0.5 and x < 0.32 + 0.12 * y
		var wing := y > -0.1 and y < 0.45 and x > 0.42 and x < 1.2 and y > (x - 0.42) * 0.55 - 0.1
		return -1.0 if stone or wing else 1.0, Mat.VERDIGRIS)
	g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
		return p.y > 0.3 and p.y < h - 0.05 and VoxelSdf.hash3(Vector3i(c.x, 0, c.z), 53) < 0.22 * (p.y / h), Mat.PATINA, [Mat.MARBLE])


## The robed figure (original): a cloaked keeper with a raised right arm, a
## closed book under the left, planar robe folds, a hood. arm false: the arm
## snapped off at the shoulder (the fallen statue). With a plinth when
## plinth is true.
func robed_statue(arm: bool, plinth: bool) -> ArrayMesh:
	var bounds := AABB(Vector3(-1.5, 0, -1.2), Vector3(3.0, 5.6, 2.4))
	var paint := func(g: VoxelGrid) -> void:
		var base := 1.4 if plinth else 0.0
		if plinth:
			_plinth(g, Vector3(1.05, 0.7, 0.85), bounds)
		var b := Vector3(0, base, 0)
		# Robe: a tapered block with planar fold ridges at the front.
		g.paint(bounds, func(p: Vector3) -> float:
			var t := clampf((p.y - base) / 2.2, 0.0, 1.0)
			var hx := lerpf(0.62, 0.42, t)
			var hz := lerpf(0.46, 0.32, t)
			var fold := 0.05 * absf(sin((p.x) * 9.0)) if p.z > 0.0 else 0.0
			return VoxelSdf.box(p, b + Vector3(0, 1.1, 0), Vector3(hx + fold, 1.1, hz + fold * 0.6)), Mat.VERDIGRIS)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, b + Vector3(0, 2.55, 0), Vector3(0.5, 0.38, 0.34)), Mat.VERDIGRIS)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, b + Vector3(0, 2.9, -0.02), Vector3(0.6, 0.12, 0.36)), Mat.VERDIGRIS)
		# Head and hood.
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.ellipsoid(p, b + Vector3(0, 3.32, 0.04), Vector3(0.24, 0.29, 0.26)), Mat.VERDIGRIS)
		g.paint(bounds, func(p: Vector3) -> float:
			return maxf(VoxelSdf.ellipsoid(p, b + Vector3(0, 3.38, -0.04), Vector3(0.3, 0.34, 0.31)), -(p.z - 0.12 - b.z)), Mat.BRONZE)
		# Left arm down, holding a book against the hip.
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.capsule(p, b + Vector3(-0.56, 2.8, 0), b + Vector3(-0.6, 1.9, 0.12), 0.15, 0.13), Mat.VERDIGRIS)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, b + Vector3(-0.5, 1.8, 0.3), Vector3(0.1, 0.32, 0.25)), Mat.BRONZE)
		if arm:
			g.paint(bounds, func(p: Vector3) -> float:
				return VoxelSdf.capsule(p, b + Vector3(0.56, 2.85, 0), b + Vector3(0.8, 3.75, 0.25), 0.15, 0.12), Mat.VERDIGRIS)
			g.paint(bounds, func(p: Vector3) -> float:
				return VoxelSdf.capsule(p, b + Vector3(0.8, 3.75, 0.25), b + Vector3(0.88, 4.3, 0.4), 0.12, 0.11), Mat.VERDIGRIS)
			g.paint(bounds, func(p: Vector3) -> float:
				return VoxelSdf.box(p, b + Vector3(0.9, 4.48, 0.42), Vector3(0.09, 0.16, 0.06)), Mat.VERDIGRIS)
		else:
			g.paint(bounds, func(p: Vector3) -> float:
				return VoxelSdf.box(p, b + Vector3(0.6, 2.82, 0), Vector3(0.14, 0.12, 0.16)), Mat.BRONZE)
		# Feet under the hem.
		for xs: float in [-0.22, 0.22]:
			g.paint(bounds, func(p: Vector3) -> float:
				return VoxelSdf.box(p, b + Vector3(xs, 0.08, 0.42), Vector3(0.12, 0.08, 0.14)), Mat.VERDIGRIS)
	return _mesh("robed%d%d" % [int(arm), int(plinth)], bounds, T1, paint)


## The snapped-off arm of the fallen statue (lying on the paving).
func statue_arm() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.3, 0, -1.2), Vector3(0.6, 0.5, 2.4))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.capsule(p, Vector3(0, 0.16, -0.9), Vector3(0.05, 0.15, 0.4), 0.15, 0.12), Mat.VERDIGRIS)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0.05, 0.12, 0.7), Vector3(0.09, 0.07, 0.17)), Mat.VERDIGRIS)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 0.16, -0.95), Vector3(0.15, 0.15, 0.06)), Mat.BRONZE)
	return _mesh("statue_arm", bounds, T1, paint)


## A winged lion (original): a blocky crouching lion with a squared mane and
## swept stepped wings, on a long plinth.
func winged_lion() -> ArrayMesh:
	var bounds := AABB(Vector3(-1.9, 0, -1.6), Vector3(3.8, 4.4, 3.2))
	var paint := func(g: VoxelGrid) -> void:
		_plinth(g, Vector3(1.6, 0.55, 0.8), bounds)
		var y0 := 1.1
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(-0.1, y0 + 0.75, 0), Vector3(1.05, 0.42, 0.42), 0.08), Mat.VERDIGRIS)
		for leg: Vector3 in [Vector3(0.8, 0, 0.28), Vector3(0.8, 0, -0.28), Vector3(-0.95, 0, 0.3), Vector3(-0.95, 0, -0.3)]:
			g.paint(bounds, func(p: Vector3) -> float:
				return VoxelSdf.box(p, Vector3(leg.x, y0 + 0.35, leg.z), Vector3(0.16, 0.36, 0.13)), Mat.VERDIGRIS)
			g.paint(bounds, func(p: Vector3) -> float:
				return VoxelSdf.box(p, Vector3(leg.x + 0.08, y0 + 0.06, leg.z), Vector3(0.22, 0.07, 0.15)), Mat.VERDIGRIS)
		# Mane and head.
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(1.0, y0 + 1.35, 0), Vector3(0.36, 0.5, 0.5), 0.06), Mat.BRONZE)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(1.35, y0 + 1.3, 0), Vector3(0.3, 0.3, 0.3), 0.05), Mat.VERDIGRIS)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(1.62, y0 + 1.18, 0), Vector3(0.12, 0.14, 0.18)), Mat.VERDIGRIS)
		# Tail.
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.capsule(p, Vector3(-1.1, y0 + 0.9, 0), Vector3(-1.6, y0 + 1.5, 0.1), 0.07, 0.06), Mat.VERDIGRIS)
		# Wings: three stepped feather slabs per side, swept back and up.
		for zs: float in [-1.0, 1.0]:
			for k in 4:
				var ky := y0 + 1.25 + k * 0.32
				var kx := 0.35 - k * 0.42
				var kz := zs * (0.5 + k * 0.18)
				g.paint(bounds, func(p: Vector3) -> float:
					return VoxelSdf.box(p, Vector3(kx, ky, kz), Vector3(0.55 - k * 0.04, 0.1, 0.06 + k * 0.01)), Mat.VERDIGRIS)
	return _mesh("winged_lion", bounds, T1, paint)


# ---------------------------------------------------------------- braziers, altars, sundial

## A bronze brazier on a tripod; lit: a low amber flame and embers, else ash.
func brazier(lit: bool) -> ArrayMesh:
	var bounds := AABB(Vector3(-0.8, 0, -0.8), Vector3(1.6, 2.4, 1.6))
	var paint := func(g: VoxelGrid) -> void:
		for k in 3:
			var a := TAU * k / 3.0
			var foot := Vector3(cos(a) * 0.62, 0.05, sin(a) * 0.62)
			g.paint(bounds, func(p: Vector3) -> float:
				return VoxelSdf.capsule(p, foot, Vector3(cos(a) * 0.3, 1.25, sin(a) * 0.3), 0.06, 0.05), Mat.BRONZE)
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.sphere(p, foot + Vector3(0, 0.03, 0), 0.1), Mat.VERDIGRIS)
		g.paint(bounds, func(p: Vector3) -> float:
			var r := Vector2(p.x, p.z).length()
			var t := clampf((p.y - 1.15) / 0.45, 0.0, 1.0)
			var outer := lerpf(0.32, 0.62, sqrt(t))
			return maxf(maxf(r - outer, (outer - 0.07) - r if p.y > 1.25 else -1.0), absf(p.y - 1.375) - 0.225), Mat.VERDIGRIS)
		g.paint(bounds, func(p: Vector3) -> float:
			return maxf(absf(Vector2(p.x, p.z).length() - 0.62) - 0.05, absf(p.y - 1.6) - 0.04), Mat.BRONZE)
		if lit:
			g.paint(bounds, func(p: Vector3) -> float:
				return maxf(Vector2(p.x, p.z).length() - 0.48, absf(p.y - 1.4) - 0.1), Mat.ASH)
			g.paint(bounds, func(p: Vector3) -> float:
				var r := Vector2(p.x, p.z).length()
				var a := atan2(p.z, p.x)
				var y := clampf((p.y - 1.42) / 0.85, 0.0, 1.0)
				var tongue := 0.55 + 0.45 * sin(a * 3.0 + y * 4.0)
				var allowed := 0.36 * pow(1.0 - y, 0.9) * tongue + 0.03 * VoxelSdf.hash3(g.cell_of(p), 55)
				return maxf(r - allowed, maxf(p.y - 2.27, 1.42 - p.y)), Mat.FLAME)
		else:
			g.paint(bounds, func(p: Vector3) -> float:
				return maxf(Vector2(p.x, p.z).length() - 0.52, absf(p.y - 1.45) - 0.06), Mat.ASH)
	return _mesh("brazier%d" % int(lit), bounds, T1 * 0.5, paint)


## An altar block with the Winged Keystone in bronze on its front, a top slab,
## and two small offering bowls.
func altar() -> ArrayMesh:
	var bounds := AABB(Vector3(-1.2, 0, -0.8), Vector3(2.4, 1.5, 1.6))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 0.55, 0), Vector3(0.9, 0.55, 0.5)), Mat.MARBLE)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 0.1, 0), Vector3(1.0, 0.1, 0.6)), Mat.MARBLE_DARK)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 1.17, 0), Vector3(1.05, 0.08, 0.62)), Mat.MARBLE)
		g.paint(bounds, func(p: Vector3) -> float:
			if absf(p.z - 0.5) > g.cell * 1.1:
				return 1.0
			var x := absf(p.x) / 0.3
			var y := (p.y - 0.62) / 0.3
			var stone := y > -0.5 and y < 0.5 and x < 0.32 + 0.12 * y
			var wing := y > -0.1 and y < 0.45 and x > 0.42 and x < 1.2 and y > (x - 0.42) * 0.55 - 0.1
			return -1.0 if stone or wing else 1.0, Mat.VERDIGRIS)
		for bx: float in [-0.55, 0.5]:
			g.paint(bounds, func(p: Vector3) -> float:
				var r := Vector2(p.x - bx, p.z).length()
				return maxf(maxf(r - 0.17, absf(p.y - 1.31) - 0.06), -maxf(0.12 - r, 1.3 - p.y)), Mat.BRONZE)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y < 0.4 and VoxelSdf.hash3(c, 57) < 0.35, Mat.MOSS, [Mat.MARBLE, Mat.MARBLE_DARK])
	return _mesh("altar", bounds, T1 * 0.5, paint)


## The sundial's gnomon: a marble drum with an inlaid hour ring and a bronze
## blade along +x (the zone turns it to point at the Crown Gate).
func gnomon() -> ArrayMesh:
	var bounds := AABB(Vector3(-1.4, 0, -1.4), Vector3(2.8, 2.2, 2.8))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			return maxf(Vector2(p.x, p.z).length() - 1.25, absf(p.y - 0.4) - 0.4), Mat.MARBLE)
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			var a := fposmod(atan2(p.z, p.x) / TAU * 12.0, 1.0)
			var r := Vector2(p.x, p.z).length()
			return p.y > 0.75 and r > 0.95 and r < 1.18 and a < 0.12, Mat.BRONZE, [Mat.MARBLE])
		g.paint(bounds, func(p: Vector3) -> float:
			var t := (p.x + 0.9) / 1.8
			return maxf(maxf(absf(p.z) - 0.05, absf(p.x) - 0.9), maxf(0.8 - p.y, p.y - (0.8 + 1.2 * (1.0 - t)))), Mat.VERDIGRIS)
	return _mesh("gnomon", bounds, T1 * 0.5, paint)


# ---------------------------------------------------------------- stairs, walls, rubble

## The stairs to nowhere: a grand flight of 11 worn steps between cheek walls,
## rising along +z and snapping off at its top, the last steps' ends jagged.
func stairs() -> ArrayMesh:
	var bounds := AABB(Vector3(-3.6, -1.2, -0.2), Vector3(7.2, 5.2, 7.6))
	var paint := func(g: VoxelGrid) -> void:
		var cell := g.cell
		var rise := 0.3
		var run := 0.6
		var solid := func(p: Vector3) -> float:
			if absf(p.x) > 3.0 or p.z < 0.0 or p.z > 6.9:
				return 1.0
			var k := floorf(p.z / run)
			var top := (k + 1.0) * rise
			return p.y - top if p.y > -1.0 else 1.0
		g.paint(bounds, solid, Mat.MARBLE)
		# Cheek walls with ashlar courses.
		for xs: float in [-1.0, 1.0]:
			g.paint(bounds, func(p: Vector3) -> float:
				var top := (floorf(p.z / run) + 1.0) * rise + 0.6
				return maxf(VoxelSdf.box(p, Vector3(xs * 3.25, 1.4, 3.4), Vector3(0.3, 2.6, 3.5)), p.y - top), Mat.LIME)
		# Worn, dished tread centres; darker risers' feet.
		g.paint(bounds, func(p: Vector3) -> float:
			var k := floorf(p.z / run)
			var top := (k + 1.0) * rise
			var wear := 1.0 - absf(p.x) / 1.6
			return -1.0 if wear > 0.0 and p.y > top - cell * (1.0 if wear > 0.45 else 0.0) - 0.001 and p.y < top else 1.0,
			0, -1, VoxelGrid.Mode.CARVE)
		# The break at the top: a jagged fracture plane.
		g.paint(bounds, func(p: Vector3) -> float:
			var cut := 6.2 + 0.5 * sin(p.x * 1.7) + 0.35 * sin(p.x * 4.1 + 1.0) - (p.y + 1.0) * 0.12
			return cut - p.z, 0, -1, VoxelGrid.Mode.CARVE)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.z > 5.4 and VoxelSdf.hash3(c, 59) < 0.35, Mat.LIME_DARK, [Mat.MARBLE, Mat.LIME])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			var k := floorf(p.z / 0.6)
			return absf(p.z - k * 0.6) < cell * 1.2 and absf(p.x) > 1.6 and VoxelSdf.hash3(c, 61) < 0.5, Mat.MOSS, [Mat.MARBLE])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return absf(p.x) > 2.9 and VoxelSdf.hash3(c, 63) < 0.08, Mat.FLOWER_W, [Mat.LIME, Mat.MOSS])
	return _mesh("stairs", bounds, T1, paint)


## A collapsed wall: an ashlar wall 8 m long with an arched window, its top
## broken off in a falling diagonal of courses.
func wall(variant: int) -> ArrayMesh:
	var bounds := AABB(Vector3(-4.3, 0, -0.7), Vector3(8.6, 5.4, 1.4))
	var paint := func(g: VoxelGrid) -> void:
		var cell := g.cell
		var solid := func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 2.6, 0), Vector3(4.0, 2.6, 0.5))
		g.paint(bounds, solid, Mat.LIME)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 0.25, 0), Vector3(4.2, 0.25, 0.65)), Mat.LIME_DARK)
		var wx := 1.2 if variant == 0 else -1.0
		g.paint(bounds, func(p: Vector3) -> float:
			return minf(VoxelSdf.box(p, Vector3(wx, 2.3, 0), Vector3(0.6, 0.8, 1.0)), Vector2(p.x - wx, p.y - 3.1).length() - 0.6 if absf(p.z) < 1.0 else 1.0),
			0, -1, VoxelGrid.Mode.CARVE)
		var s := 1.0 if variant == 0 else -1.0
		g.paint(bounds, func(p: Vector3) -> float:
			var course := floorf(p.y / 0.66)
			var cut := 3.2 + s * p.x * 0.45 + 0.8 * sin(p.x * 1.3 + variant)
			return floorf(cut / 0.66) * 0.66 - course * 0.66 - 0.3, 0, -1, VoxelGrid.Mode.CARVE)
		_groove(g, bounds, solid, func(p: Vector3) -> bool:
			var row := floori(p.y / 0.66)
			return fposmod(p.y, 0.66) < cell or fposmod(p.x + (0.6 if row % 2 == 1 else 0.0), 1.2) < cell, cell * 1.05)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return VoxelSdf.hash3(c, 65) < (0.55 if p.y < 1.0 else 0.08), Mat.MOSS, [Mat.LIME, Mat.LIME_DARK])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return VoxelSdf.hash3(Vector3i(floori((p.x + 9.0) / 1.2), floori(p.y / 0.66), 0), 67 + variant) < 0.18, Mat.LIME_DARK, [Mat.LIME])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return s * p.x > 1.5 and p.y < 4.0 - s * p.x * 0.3 and VoxelSdf.hash3(c, 69) < 0.55, Mat.IVY, [Mat.LIME, Mat.MOSS])
	return _mesh("wall%d" % variant, bounds, T1, paint)


## Rubble: a few fallen ashlar blocks and chips.
func rubble(variant: int) -> ArrayMesh:
	var bounds := AABB(Vector3(-1.6, 0, -1.6), Vector3(3.2, 1.3, 3.2))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 700 + variant
		for k in 3 + variant:
			var half := Vector3(rng.randf_range(0.25, 0.6), rng.randf_range(0.18, 0.4), rng.randf_range(0.2, 0.45))
			var at := Vector3(rng.randf_range(-0.9, 0.9), half.y, rng.randf_range(-0.9, 0.9))
			var tilt := rng.randf_range(-0.4, 0.4)
			g.paint(AABB(at - Vector3.ONE, Vector3.ONE * 2), func(p: Vector3) -> float:
				var q := p - at
				var r := Vector3(q.x * cos(tilt) - q.z * sin(tilt), q.y, q.x * sin(tilt) + q.z * cos(tilt))
				return VoxelSdf.box(r, Vector3.ZERO, half), Mat.LIME if k % 3 else Mat.MARBLE, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return VoxelSdf.hash3(c, 71) < (0.4 if p.y < 0.25 else 0.08), Mat.MOSS, [Mat.LIME, Mat.MARBLE])
	return _mesh("rubble%d" % variant, bounds, T1, paint)


# ---------------------------------------------------------------- small things (T0)

## A chain link (T0): a blocky oval ring, about 26 cm long.
func chain_link() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.1, -0.16, -0.04), Vector3(0.2, 0.32, 0.08))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			return maxf(VoxelSdf.box(p, Vector3.ZERO, Vector3(0.08, 0.13, 0.025)), -VoxelSdf.box(p, Vector3.ZERO, Vector3(0.035, 0.085, 0.1))), Mat.CHAIN)
	return _mesh("chain_link", bounds, T0, paint)


## A bird nest of twigs with two eggs, for a broken capital (T0).
func nest() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.45, 0, -0.45), Vector3(0.9, 0.36, 0.9))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			var r := Vector2(p.x, p.z).length()
			var bowl := Vector3(p.x, (p.y - 0.34) * 1.6, p.z).length() - 0.26
			var twig := VoxelSdf.hash3(g.cell_of(p), 73) * 0.06
			return maxf(maxf(r - 0.42 - twig, -bowl), p.y - 0.3 - twig), Mat.NEST)
		for e: Vector3 in [Vector3(0.06, 0.2, 0.02), Vector3(-0.08, 0.2, -0.05)]:
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.ellipsoid(p, e, Vector3(0.055, 0.07, 0.055)), Mat.EGG)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0.3, 0.3, 0.1), Vector3(0.12, 0.012, 0.025)), Mat.FEATHER)
	return _mesh("nest", bounds, T0, paint)


## A feather lying flat (T0), 12 cm.
func feather() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.08, 0, -0.03), Vector3(0.16, 0.03, 0.06))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 0.01, 0), Vector3(0.065 - absf(p.z) * 0.6, 0.008, 0.022)), Mat.FEATHER)
	return _mesh("feather", bounds, T0, paint)


## A clump of wildflowers in a paving joint (T0): stems, white or butter heads.
func flowers(variant: int) -> ArrayMesh:
	var bounds := AABB(Vector3(-0.2, 0, -0.2), Vector3(0.4, 0.3, 0.4))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 800 + variant
		g.paint(bounds, func(p: Vector3) -> float:
			return maxf(Vector2(p.x, p.z).length() - 0.14, p.y - 0.04), Mat.MOSS)
		for k in 7:
			var at := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
			var h := rng.randf_range(0.1, 0.24)
			g.paint(bounds, func(p: Vector3) -> float:
				return maxf(Vector2(p.x - at.x, p.z - at.z).length() - 0.012, p.y - h), Mat.STEM)
			var head := Mat.FLOWER_W if (k + variant) % 3 else Mat.FLOWER_Y
			g.paint(bounds, func(p: Vector3) -> float:
				return VoxelSdf.box(p, Vector3(at.x, h, at.z), Vector3(0.025, 0.012, 0.025)), head)
	return _mesh("flowers%d" % variant, bounds, T0, paint)


## Hanging roots under an island rim: a few wiggling strands, 2-6 m (T1).
func roots(variant: int) -> ArrayMesh:
	var bounds := AABB(Vector3(-1.5, -6.5, -1.5), Vector3(3.0, 6.7, 3.0))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 900 + variant
		for k in 4:
			var at := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
			var length := rng.randf_range(2.0, 6.2)
			var phase := rng.randf() * TAU
			var segs := 6
			for s in segs:
				var y0 := -length * s / segs
				var y1 := -length * (s + 1) / segs
				var a := at + Vector3(sin(phase + s) * 0.25, y0, cos(phase + s * 1.3) * 0.25)
				var b := at + Vector3(sin(phase + s + 1) * 0.25, y1, cos(phase + (s + 1) * 1.3) * 0.25)
				var r0 := 0.11 * (1.0 - float(s) / segs) + 0.03
				g.paint(AABB(Vector3(-1.5, y1 - 0.3, -1.5), Vector3(3.0, y0 - y1 + 0.6, 3.0)), func(p: Vector3) -> float:
					return VoxelSdf.capsule(p, a, b, r0, r0 * 0.8), Mat.ROOT)
	return _mesh("roots%d" % variant, bounds, T1, paint)


## A small bird (T0) with spread wings, for the flocks around the Crown Gate.
func bird() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.3, -0.06, -0.12), Vector3(0.6, 0.18, 0.24))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 0, 0), Vector3(0.04, 0.03, 0.1)), Mat.ROCK)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 0.02 + absf(p.x) * 0.25, -0.01), Vector3(0.28, 0.012, 0.05 - absf(p.x) * 0.1)), Mat.ROCK)
	return _mesh("bird", bounds, T0, paint)
