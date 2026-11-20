class_name EmberRiftDesigns
extends RefCounted
## Ember Rift's voxel prop designs (docs/lookdev/ember_rift.md): obsidian
## spires, geyser vents, pumice, shards, sulphur, survey stakes, crust rafts,
## lava tubes, the forge-shrine, the survey bridge, the fallen spire, the
## offering cairn, plume puffs and geyser blobs. Each returns a cached mesh
## (VoxelProp.mesh) at the given cell; paint closures reseed their own RNG so
## every LOD tier builds the same shape.

## Bump after changing any design (rebuilds the cached meshes).
const VERSION := 3

enum Mat {
	EMPTY, ASH, ASH_LIGHT, BASALT, OBSIDIAN, GLINT, CRUST, CRUST_DARK, SULPHUR, PUMICE, PUMICE_DARK,
	SANDSTONE, SANDSTONE_DARK, CHAR, WOOD, ROPE, CLOTH, IRON, LAVA, EMBER, SMOKE, SMOKE_LIT, GLASS,
}
## Palette from the sheet (sRGB). Lava is the one saturated colour.
const COLORS := {
	Mat.ASH: Color("#A8A09C"), Mat.ASH_LIGHT: Color("#BDB6B0"), Mat.BASALT: Color("#3E3A40"),
	Mat.OBSIDIAN: Color("#2A2128"), Mat.GLINT: Color("#7A6A78"), Mat.CRUST: Color("#4A3028"),
	Mat.CRUST_DARK: Color("#2A1A16"), Mat.SULPHUR: Color("#D8CC7A"), Mat.PUMICE: Color("#8C8078"),
	Mat.PUMICE_DARK: Color("#5A504C"), Mat.SANDSTONE: Color("#9A8878"), Mat.SANDSTONE_DARK: Color("#665848"),
	Mat.CHAR: Color("#3A302A"), Mat.WOOD: Color("#6E5A46"), Mat.ROPE: Color("#9A8A6A"),
	Mat.CLOTH: Color("#B8AC98"), Mat.IRON: Color("#4A4648"), Mat.LAVA: Color("#FFB040"),
	Mat.EMBER: Color("#E8701C"), Mat.SMOKE: Color("#5E5658"), Mat.SMOKE_LIT: Color("#8A5A44"),
	Mat.GLASS: Color("#4A3A48"),
}
const T0 := VoxelZone.T0
const T1 := VoxelZone.T1
const T2 := VoxelZone.T2
const T3 := VoxelZone.T3
## Spire variants: [radius, height] of the built mesh (base at y = 0).
const SPIRES := [[3.5, 30.0], [4.0, 50.0], [5.5, 38.0], [5.5, 62.0], [7.0, 46.0], [7.5, 70.0]]


static func color(mat: int, p: Vector3, c: Vector3i, n: Vector3, occlusion: float, exposure: float) -> Color:
	var base: Color = COLORS.get(mat, Color.MAGENTA)
	var quiet := mat in [Mat.ASH, Mat.OBSIDIAN, Mat.BASALT, Mat.SANDSTONE]
	var noisy := mat in [Mat.CRUST, Mat.CRUST_DARK, Mat.SULPHUR, Mat.PUMICE, Mat.PUMICE_DARK]
	var col := VoxelDesign.default_color(base, mat, c, occlusion, exposure, quiet,
		mat in [Mat.SANDSTONE, Mat.WOOD, Mat.OBSIDIAN, Mat.BASALT, Mat.IRON])
	if noisy:
		col *= 0.95 + 0.1 * VoxelSdf.hash3(c, 41)
	if mat == Mat.OBSIDIAN and p.y < 4.0:
		# Lava-lit lower faces.
		col = col.lerp(Color("#6A3A2A"), (1.0 - p.y / 4.0) * 0.3 * clampf(1.0 - n.y, 0.0, 1.0))
	if mat in [Mat.LAVA, Mat.EMBER]:
		col = base.lerp(Color("#FFD070") if mat == Mat.LAVA else Color("#FFB040"), VoxelSdf.hash3(c, 9) * 0.5)
	if mat in [Mat.SMOKE, Mat.SMOKE_LIT]:
		# Plume: grey on top, warm from below.
		col = Color("#6A6264").lerp(Color("#9A6448"), clampf(-n.y, 0.0, 1.0) * 0.8 + occlusion * 0.2)
		col = col.lerp(Color("#3E383C"), occlusion * 0.6)
		col *= 0.97 + 0.06 * VoxelSdf.hash3(c, 5)
	col.a = 1.0
	return col


static func surface_of(mat: int) -> int:
	match mat:
		Mat.LAVA, Mat.EMBER:
			return VoxelProp.Surf.GLOW
		Mat.IRON:
			return VoxelProp.Surf.METAL
		Mat.SMOKE, Mat.SMOKE_LIT:
			return VoxelProp.Surf.PETAL
		Mat.WOOD, Mat.CHAR, Mat.ROPE:
			return VoxelProp.Surf.BARK
	return VoxelProp.Surf.MATTE


static func _mesh(key: String, bounds: AABB, cell: float, paint: Callable, soft := []) -> ArrayMesh:
	return VoxelProp.mesh("er_" + key, VERSION, bounds, cell, paint, color, surface_of, soft)


## Facet planes of a prism (unit normals in xz and offsets), hashed per seed.
static func _facets(sides: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := []
	var a0 := rng.randf() * TAU
	for i in sides:
		var a := a0 + TAU * i / sides + rng.randf_range(-0.2, 0.2)
		out.append([Vector2(cos(a), sin(a)), 1.0 + rng.randf_range(-0.12, 0.1)])
	return out


## Largest and second-largest facet distance of q (xz) for radius rr.
static func _prism(q: Vector2, rr: float, facets: Array) -> Vector2:
	var d1 := -INF
	var d2 := -INF
	for f: Array in facets:
		var d := q.dot(f[0]) - rr * float(f[1])
		if d > d1:
			d2 = d1
			d1 = d
		elif d > d2:
			d2 = d
	return Vector2(d1, d2)


# ---------------------------------------------------------------- spires

## An obsidian spire: a leaning faceted prism tapering to a split tip, with
## conchoidal chip scars, a crust crack band, glinting facet edges and glass
## drips near the tip. Base at y = 0 (2 m of it below the sim ground).
static func spire(v: int, cell: float) -> ArrayMesh:
	var r: float = SPIRES[v][0]
	var h: float = SPIRES[v][1]
	var bounds := AABB(Vector3(-r - 1.0, -0.5, -r - 1.0), Vector3(2.0 * r + 2.0, h + 1.0, 2.0 * r + 2.0))
	var facets := _facets(5 + v % 3, 900 + v)
	var radius := func(y: float) -> float:
		return r * pow(clampf(1.0 - y / h, 0.0, 1.0), 0.75) * (1.0 + 0.08 * floorf(maxf(2.0 - y, 0.0)))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1900 + v
		g.paint(bounds, func(p: Vector3) -> float:
			# Terraced taper: the radius steps every 2.4 m (stacked fracture drums).
			var y := floorf(p.y / 2.4) * 2.4
			return maxf(_prism(Vector2(p.x, p.z), radius.call(y), facets).x, -p.y), Mat.OBSIDIAN)
		# Split tip: a V notch through the top fifth.
		var m := Vector2(cos(v * 1.3), sin(v * 1.3))
		g.paint(AABB(Vector3(-r, h * 0.78, -r), Vector3(2 * r, h * 0.25, 2 * r)), func(p: Vector3) -> float:
			return absf(Vector2(p.x, p.z).dot(m)) - (p.y - h * 0.8) * 0.12, 0, -1, VoxelGrid.Mode.CARVE)
		# Chip scars: shallow scoops out of the facets.
		for k in 10 + v * 2:
			var y := rng.randf_range(1.0, h * 0.75)
			var a := rng.randf() * TAU
			var rr: float = radius.call(y)
			var cpos := Vector3(cos(a) * rr * 1.05, y, sin(a) * rr * 1.05)
			var s := rr * rng.randf_range(0.25, 0.45) + 0.4
			g.paint(AABB(cpos - Vector3.ONE * s * 1.5, Vector3.ONE * s * 3.0), func(p: Vector3) -> float:
				return VoxelSdf.ellipsoid(p, cpos, Vector3(s, s * 1.5, s)), 0, -1, VoxelGrid.Mode.CARVE)
		# Crack band: a ring of umber crust a third of the way up.
		var band := h * rng.randf_range(0.25, 0.4)
		g.paint_surface(AABB(Vector3(-r - 1, band, -r - 1), Vector3(2 * r + 2, 1.2, 2 * r + 2)),
			func(p: Vector3, c: Vector3i) -> bool: return VoxelSdf.hash3(Vector3i(c.x / 3, 0, c.z / 3), 3) < 0.7, Mat.CRUST)
		# Facet edges catch light; drips of cooled glass near the tip.
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			var y := floorf(p.y / 2.4) * 2.4
			var d := _prism(Vector2(p.x, p.z), radius.call(y), facets)
			return d.x - d.y < cell * 0.45 and fposmod(p.y, 2.4) > 0.6, Mat.GLINT, [Mat.OBSIDIAN])
		g.paint_surface(AABB(Vector3(-r, h * 0.6, -r), Vector3(2 * r, h * 0.4, 2 * r)),
			func(_p: Vector3, c: Vector3i) -> bool: return VoxelSdf.hash3(Vector3i(c.x, c.y / 4, c.z), 8) < 0.05, Mat.GLASS, [Mat.OBSIDIAN])
	return _mesh("spire_b%d" % v, bounds, cell, paint)


# ---------------------------------------------------------------- vents

## A geyser vent on the sim's frustum (r 4.5 at the base, 3.15 at 3.5 m):
## terraced umber crust rings, a sulphur-crusted cracked rim, a throat with a
## lava pool glowing inside. Variant 1 is cracked open on its +x side (the
## sulphur fan on the floor points the same way).
static func vent(v: int, cell: float) -> ArrayMesh:
	var bounds := AABB(Vector3(-5.0, 0.0, -5.0), Vector3(10.0, 3.9, 10.0))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 2100 + v
		var jag := []
		for k in 16:
			jag.append(rng.randf_range(-0.25, 0.2))
		g.paint(bounds, func(p: Vector3) -> float:
			var y := floorf(p.y / 0.44) * 0.44
			var a := atan2(p.z, p.x)
			var sector := int(floorf((a + PI) / TAU * 16.0)) % 16
			var rr := 4.5 - y * 0.39 + float(jag[sector]) * (0.4 + y * 0.2)
			var top := 3.5 + float(jag[(sector + 5) % 16]) * 0.8
			return maxf(Vector2(p.x, p.z).length() - rr, p.y - top), Mat.CRUST)
		# Throat and its glowing pool.
		g.paint(AABB(Vector3(-2, 1.0, -2), Vector3(4, 3, 4)), func(p: Vector3) -> float:
			return Vector2(p.x, p.z).length() - (1.3 + (p.y - 1.0) * 0.25), 0, -1, VoxelGrid.Mode.CARVE)
		g.paint(AABB(Vector3(-2, 0.9, -2), Vector3(4, 0.5, 4)), func(p: Vector3) -> float:
			return maxf(Vector2(p.x, p.z).length() - 1.5, p.y - 1.25), Mat.LAVA)
		# Radial rim cracks.
		for k in 4:
			var a := rng.randf() * TAU
			var dir := Vector2(cos(a), sin(a))
			g.paint(AABB(Vector3(-5, 2.2, -5), Vector3(10, 2, 10)), func(p: Vector3) -> float:
				var q := Vector2(p.x, p.z)
				return maxf(absf(q.cross(dir)) - 0.12, -q.dot(dir)) + (3.4 - p.y) * 0.1, 0, -1, VoxelGrid.Mode.CARVE)
		if v == 1:
			# Cracked open on one side, a lava tongue in the breach.
			g.paint(AABB(Vector3(0, 0.6, -2.5), Vector3(5, 3.3, 5)), func(p: Vector3) -> float:
				return absf(p.z) - 0.25 - (p.y - 0.6) * 0.45 - maxf(p.x - 1.0, 0.0) * 0.1, 0, -1, VoxelGrid.Mode.CARVE)
			g.paint(AABB(Vector3(0, 0.5, -1), Vector3(5, 0.5, 2)), func(p: Vector3) -> float:
				return maxf(absf(p.z) - 0.35 + p.x * 0.04, p.y - 0.75), Mat.LAVA, -1, VoxelGrid.Mode.ADD)
		# Darker crust low, sulphur crust on the rim (pale, patchy).
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y < 1.2 and VoxelSdf.hash3(Vector3i(c.x / 2, c.y, c.z / 2), 4) < 0.5, Mat.CRUST_DARK, [Mat.CRUST])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			var rim := p.y > 2.7 and Vector2(p.x, p.z).length() < 3.6
			var stain := v == 1 and p.x > 0.5 and absf(p.z) < 1.4 and p.y > 0.5
			return (rim or stain) and VoxelSdf.hash3(Vector3i(c.x / 2, 0, c.z / 2), 6) < 0.55, Mat.SULPHUR, [Mat.CRUST, Mat.CRUST_DARK])
		# Glowing pinprick cracks on the cone.
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y > 0.6 and p.y < 2.6 and VoxelSdf.hash3(c, 12) < 0.006, Mat.EMBER, [Mat.CRUST, Mat.CRUST_DARK])
	return _mesh("vent%d" % v, bounds, cell, paint)


# ---------------------------------------------------------------- small props

## Pumice boulder: chamfered blocks (planar cuts), pitted with dark pores.
static func boulder(v: int, cell: float) -> ArrayMesh:
	var s := 0.8 + 0.4 * v
	var bounds := AABB(Vector3(-s * 1.6, -0.3, -s * 1.6), Vector3(s * 3.2, s * 2.0, s * 3.2))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 2300 + v
		for k in 3:
			var c := Vector3(rng.randf_range(-0.5, 0.5) * s, s * rng.randf_range(0.3, 0.6), rng.randf_range(-0.5, 0.5) * s)
			var half := Vector3(rng.randf_range(0.6, 1.0), rng.randf_range(0.4, 0.7), rng.randf_range(0.6, 1.0)) * s
			var cut := Vector3(rng.randf_range(-1, 1), 1.0, rng.randf_range(-1, 1)).normalized()
			g.paint(AABB(c - half * 1.2, half * 2.4), func(p: Vector3) -> float:
				return maxf(VoxelSdf.box(p, c, half, s * 0.15), (p - c).dot(cut) - half.y * 0.7), Mat.PUMICE, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool: return VoxelSdf.hash3(c, 21) < 0.14, Mat.PUMICE_DARK)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y < 0.25 and VoxelSdf.hash3(c, 22) < 0.6, Mat.ASH)
	return _mesh("boulder%d" % v, bounds, cell, paint)


## Obsidian shard lying or stuck in the ash: a long faceted wedge.
static func shard(v: int, cell: float) -> ArrayMesh:
	var l := 0.45 + 0.3 * v
	var bounds := AABB(Vector3(-l, -0.1, -l), Vector3(2 * l, l * 1.2, 2 * l))
	var paint := func(g: VoxelGrid) -> void:
		var facets := _facets(4, 2400 + v)
		var tilt := 0.6 + 0.25 * v
		g.paint(bounds, func(p: Vector3) -> float:
			# Along a tilted axis, a 4-sided prism tapering to a point.
			var ax := Vector3(cos(tilt) * 0.8, sin(tilt), 0.3).normalized()
			var t := p.dot(ax)
			var q3 := p - ax * t
			var q := Vector2(q3.x + q3.y * 0.5, q3.z)
			var rr := l * 0.22 * clampf(1.0 - t / l, 0.0, 1.0)
			return maxf(maxf(_prism(q, rr, facets).x, -t - 0.05), -p.y - 0.05), Mat.OBSIDIAN)
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool: return VoxelSdf.hash3(c, 23) < 0.18, Mat.GLINT)
	return _mesh("shard%d" % v, bounds, cell, paint)


## Sulphur crystal cluster: pale lemon prisms leaning out of a crust base.
static func sulphur(v: int, cell: float) -> ArrayMesh:
	var bounds := AABB(Vector3(-0.35, -0.05, -0.35), Vector3(0.7, 0.45, 0.7))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 2500 + v
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.ellipsoid(p, Vector3.ZERO, Vector3(0.3, 0.06, 0.26)), Mat.CRUST)
		for k in 7:
			var a := rng.randf() * TAU
			var dir := Vector3(cos(a) * 0.5, 1.0, sin(a) * 0.5).normalized()
			var base := Vector3(cos(a) * 0.08, 0.0, sin(a) * 0.08)
			var length_m := rng.randf_range(0.12, 0.3)
			var w := rng.randf_range(0.025, 0.045)
			g.paint(AABB(base - Vector3.ONE * 0.4, Vector3.ONE * 0.8), func(p: Vector3) -> float:
				var t := (p - base).dot(dir)
				var q := (p - base) - dir * t
				return maxf(maxf(absf(q.x) - w, absf(q.z) - w), maxf(-t, t - length_m)), Mat.SULPHUR, -1, VoxelGrid.Mode.ADD)
	return _mesh("sulphur%d" % v, bounds, cell, paint)


## Rising Ember emblem in [-1, 1]²: a teardrop flame on three strata bars.
static func emblem(u: float, v: float) -> bool:
	var flame := Vector2(u, v - 0.05).length() < 0.32 or (v > 0.05 and v < 0.8 and absf(u) < 0.32 * (0.8 - v) / 0.75)
	var bars := (absf(v + 0.5) < 0.07 and absf(u) < 0.62) or (absf(v + 0.68) < 0.06 and absf(u) < 0.5) \
		or (absf(v + 0.84) < 0.05 and absf(u) < 0.38)
	return flame or bars


## Survey stake with a weathered cloth tag (the emblem printed on it); the
## melted variant is a slumped, charred stub with a scorched tag remnant.
static func stake(melted: bool) -> ArrayMesh:
	var bounds := AABB(Vector3(-0.2, -0.2, -0.2), Vector3(0.4, 1.4, 0.4))
	var top := 0.62 if melted else 1.15
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			var lean := maxf(p.y - 0.3, 0.0) * (0.25 if melted else 0.0)
			return maxf(maxf(absf(p.x - lean) - 0.03, absf(p.z) - 0.03), maxf(-p.y - 0.15, p.y - top + absf(p.x) * 0.5)), Mat.WOOD)
		# Cloth tag hanging off the post's front.
		var tag_top := top - 0.08
		var tag_h := 0.12 if melted else 0.26
		g.paint(AABB(Vector3(-0.12, tag_top - 0.3, 0.02), Vector3(0.24, 0.32, 0.04)), func(p: Vector3) -> float:
			return maxf(maxf(absf(p.x) - 0.09, absf(p.z - 0.04) - 0.011), maxf(p.y - tag_top, tag_top - tag_h - p.y)), Mat.CLOTH, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return p.z > 0.04 and emblem(p.x / 0.08, (p.y - (tag_top - tag_h * 0.5)) / (tag_h * 0.45)), Mat.CRUST, [Mat.CLOTH])
		if melted:
			g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
				return p.y > top - 0.3 or VoxelSdf.hash3(c, 31) < 0.2, Mat.CHAR)
		# Rope tie under the tag.
		g.paint(AABB(Vector3(-0.06, tag_top, -0.06), Vector3(0.12, 0.05, 0.12)), func(p: Vector3) -> float:
			return maxf(maxf(absf(p.x) - 0.045, absf(p.z) - 0.045), absf(p.y - tag_top - 0.02) - 0.015), Mat.ROPE, -1, VoxelGrid.Mode.ADD)
	return _mesh("stake%d" % int(melted), bounds, T0, paint)


## A lava-crust raft floating on the pool: an irregular flat plate with
## lighter cracked edges.
static func raft(v: int, cell: float) -> ArrayMesh:
	var s := 1.4 + 0.6 * v
	var bounds := AABB(Vector3(-s * 1.3, -0.2, -s * 1.3), Vector3(s * 2.6, 0.6, s * 2.6))
	var paint := func(g: VoxelGrid) -> void:
		var facets := _facets(6, 2600 + v)
		g.paint(bounds, func(p: Vector3) -> float:
			return maxf(_prism(Vector2(p.x, p.z), s, facets).x, absf(p.y - 0.05) - 0.12 - 0.08 * VoxelSdf.hash3(Vector3i(int(p.x * 3), 0, int(p.z * 3)), 2)), Mat.CRUST)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return _prism(Vector2(p.x, p.z), s, facets).x > -0.3 and VoxelSdf.hash3(c, 24) < 0.5, Mat.CRUST_DARK)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return _prism(Vector2(p.x, p.z), s, facets).x > -0.2 and VoxelSdf.hash3(c, 25) < 0.12, Mat.EMBER)
	return _mesh("raft%d" % v, bounds, cell, paint)


## A collapsed lava tube: a half-pipe of crust on the floor with a broken
## middle section and basalt rubble.
static func lava_tube(cell: float) -> ArrayMesh:
	var bounds := AABB(Vector3(-4.5, -0.3, -2.0), Vector3(9.0, 2.2, 4.0))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			var r := Vector2(p.y, p.z).length()
			var y := floorf(p.y / 0.35) * 0.35
			return maxf(maxf(absf(r - 1.4) - 0.22 - 0.05 * y, absf(p.x) - 4.2), -p.y), Mat.CRUST)
		g.paint(AABB(Vector3(-1.3, 0.4, -2), Vector3(2.4, 2, 4)), func(p: Vector3) -> float:
			return absf(p.x + 0.1) - 0.9 - (p.y - 0.4) * 0.5, 0, -1, VoxelGrid.Mode.CARVE)
		for k in 5:
			var c := Vector3(-0.8 + k * 0.4, 0.2, -0.6 + 0.3 * (k % 3))
			g.paint(AABB(c - Vector3.ONE * 0.4, Vector3.ONE * 0.8), func(p: Vector3) -> float:
				return VoxelSdf.box(p, c, Vector3(0.28, 0.2, 0.22), 0.04), Mat.BASALT, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return VoxelSdf.hash3(Vector3i(c.x / 3, c.y, c.z / 3), 26) < 0.35, Mat.CRUST_DARK, [Mat.CRUST])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y > 1.4 and VoxelSdf.hash3(c, 27) < 0.4, Mat.ASH, [Mat.CRUST, Mat.CRUST_DARK])
	return _mesh("tube", bounds, cell, paint)


# ---------------------------------------------------------------- storytelling

## The forge-shrine: a sandstone platform with a three-step stair, a cracked
## anvil block carved with the Rising Ember, two braziers with live coals, a
## hammer-shaped notch worn into the top step and tool marks on the blocks.
## Faces +z (the stair side). Origin at the platform's foot centre.
static func shrine() -> ArrayMesh:
	var bounds := AABB(Vector3(-4.0, -0.4, -3.2), Vector3(8.0, 3.4, 7.4))
	var paint := func(g: VoxelGrid) -> void:
		# Platform blocks (0.9 m courses) and the stair.
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 0.25, -0.6), Vector3(3.6, 0.65, 2.4), 0.06), Mat.SANDSTONE)
		for s in 3:
			var z := 1.95 + s * 0.42
			var top := 0.75 - s * 0.3
			g.paint(bounds, func(p: Vector3) -> float:
				return VoxelSdf.box(p, Vector3(0, (top - 0.4) * 0.5, z), Vector3(1.6 - s * 0.1, (top + 0.4) * 0.5, 0.22), 0.04), Mat.SANDSTONE, -1, VoxelGrid.Mode.ADD)
		# A chunk broken off the platform's corner (shattered shrine).
		g.paint(AABB(Vector3(2.2, -0.2, -3.2), Vector3(2, 1.4, 1.6)), func(p: Vector3) -> float:
			return (p - Vector3(3.6, 1.0, -3.0)).dot(Vector3(-0.6, -0.5, -0.62).normalized()), 0, -1, VoxelGrid.Mode.CARVE)
		# Block joints and tool marks.
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			var jx := fposmod(p.x + floorf(p.y / 0.45) * 0.45, 1.2) < 0.09
			var jy := fposmod(p.y + 0.4, 0.45) < 0.09
			return jx or jy, Mat.SANDSTONE_DARK, [Mat.SANDSTONE])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return fposmod(p.x * 0.7 + p.y * 1.3, 0.35) < 0.09 and VoxelSdf.hash3(Vector3i(c.x / 6, c.y / 6, c.z / 6), 28) < 0.35,
				Mat.SANDSTONE_DARK, [Mat.SANDSTONE])
		# The anvil block: horn and heel, cracked through.
		var a := Vector3(0, 0.9, -0.7)
		g.paint(bounds, func(p: Vector3) -> float:
			var body := VoxelSdf.box(p, a + Vector3(0, 0.4, 0), Vector3(0.7, 0.4, 0.45), 0.04)
			var waist := VoxelSdf.box(p, a + Vector3(0, 0.12, 0), Vector3(0.45, 0.14, 0.32), 0.02)
			var horn := maxf(VoxelSdf.box(p, a + Vector3(0.95, 0.62, 0), Vector3(0.35, 0.16, 0.2)), (p.x - a.x - 0.6) * 0.5 + absf(p.y - a.y - 0.62) - 0.2)
			return minf(minf(body, waist), horn), Mat.BASALT)
		g.paint(AABB(a + Vector3(-1, 0, -1), Vector3(2, 1, 2)), func(p: Vector3) -> float:
			return absf((p - a).dot(Vector3(1, 0.35, 0.2).normalized()) - 0.12) - 0.05, 0, -1, VoxelGrid.Mode.CARVE)
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return p.z > a.z + 0.36 and emblem((p.x - a.x + 0.12) / 0.3, (p.y - a.y - 0.42) / 0.32), Mat.EMBER, [Mat.BASALT])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y > a.y + 0.75 and VoxelSdf.hash3(c, 29) < 0.45, Mat.IRON, [Mat.BASALT])
		# Braziers either side of the stair head, with coals.
		for sx: float in [-2.6, 2.6]:
			var b := Vector3(sx, 0.9, 1.1)
			g.paint(bounds, func(p: Vector3) -> float:
				var post := VoxelSdf.box(p, b + Vector3(0, 0.45, 0), Vector3(0.24, 0.45, 0.24), 0.03)
				var bowl := VoxelSdf.box(p, b + Vector3(0, 1.05, 0), Vector3(0.48, 0.18, 0.48), 0.05)
				return minf(post, bowl), Mat.SANDSTONE, -1, VoxelGrid.Mode.ADD)
			g.paint(bounds, func(p: Vector3) -> float:
				return VoxelSdf.box(p, b + Vector3(0, 1.2, 0), Vector3(0.36, 0.1, 0.36)), 0, -1, VoxelGrid.Mode.CARVE)
			g.paint(bounds, func(p: Vector3) -> float:
				return maxf(VoxelSdf.box(p, b + Vector3(0, 1.17, 0), Vector3(0.36, 0.08, 0.36)),
					p.y - b.y - 1.12 - 0.12 * VoxelSdf.hash3(Vector3i(int(p.x * 11), 0, int(p.z * 11)), 3)), Mat.EMBER)
		# Hammer notch worn into the top step (where someone knelt).
		var hn := Vector3(0.5, 0.75, 1.95)
		g.paint(bounds, func(p: Vector3) -> float:
			var head := VoxelSdf.box(p, hn, Vector3(0.12, 0.1, 0.2))
			var handle := VoxelSdf.box(p, hn + Vector3(-0.38, 0, 0), Vector3(0.3, 0.1, 0.05))
			return minf(head, handle), 0, -1, VoxelGrid.Mode.CARVE)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y > 0.3 and p.y < 0.8 and absf(p.x) < 1.5 and p.z > 1.7 and VoxelSdf.hash3(c, 30) < 0.5, Mat.ASH_LIGHT, [Mat.SANDSTONE])
		# Ash settled on the platform top.
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y > 0.8 and p.y < 0.95 and VoxelSdf.hash3(Vector3i(c.x / 2, 0, c.z / 2), 31) < 0.4, Mat.ASH, [Mat.SANDSTONE, Mat.SANDSTONE_DARK])
	return _mesh("shrine", bounds, T1, paint)


## The survey bridge across a lava channel (span along x, deck at y = 0 at
## the ends): sagging planks on two ropes, end posts, the middle third burnt
## away, charred planks at the gap and one hanging off the rope.
static func bridge(span: float) -> ArrayMesh:
	var half := span * 0.5
	var bounds := AABB(Vector3(-half - 0.4, -1.6, -1.0), Vector3(span + 0.8, 3.0, 2.0))
	var cell := T0 * 2.0
	var sag := func(x: float) -> float: return -0.45 * (1.0 - pow(x / half, 2.0))
	var paint := func(g: VoxelGrid) -> void:
		var burnt_from := -span / 6.0
		var burnt_to := span / 6.0
		var x := -half
		var k := 0
		while x < half:
			var w := 0.24
			var mid := x + w * 0.5
			if mid < burnt_from or mid > burnt_to:
				var charred := absf(mid) < span / 6.0 + 0.9
				var y: float = sag.call(mid)
				var tilt := 0.02 * (VoxelSdf.hash3(Vector3i(k, 0, 0), 1) - 0.5)
				var length_m := 0.62 + 0.1 * VoxelSdf.hash3(Vector3i(k, 0, 0), 2)
				g.paint(AABB(Vector3(x, y - 0.2, -0.8), Vector3(w, 0.4, 1.6)), func(p: Vector3) -> float:
					return maxf(maxf(absf(p.x - mid) - w * 0.42, absf(p.y - y - (p.z * tilt)) - 0.035), absf(p.z) - length_m),
						Mat.CHAR if charred else Mat.WOOD)
			x += w + 0.04
			k += 1
		# Ropes: two deck ropes and two handrails; one handrail burnt through.
		for side: float in [-0.68, 0.68]:
			for rail: float in [0.0, 0.95]:
				var broken := rail > 0.5 and side > 0.0
				g.paint(bounds, func(p: Vector3) -> float:
					if broken and absf(p.x) < span / 6.0 + 0.4:
						return 1.0
					if rail < 0.5 and absf(p.x) < span / 6.0 - 0.2:
						return 1.0
					var y: float = sag.call(p.x) + rail - (0.0 if rail < 0.5 else 0.3 * (1.0 - pow(p.x / half, 2.0)))
					return Vector2(p.y - y - 0.02, p.z - side).length() - 0.03, Mat.ROPE, -1, VoxelGrid.Mode.ADD)
		# End posts.
		for ex: float in [-half, half]:
			for side: float in [-0.68, 0.68]:
				g.paint(bounds, func(p: Vector3) -> float:
					return VoxelSdf.box(p, Vector3(ex, 0.3, side), Vector3(0.07, 0.75, 0.07), 0.01), Mat.WOOD, -1, VoxelGrid.Mode.ADD)
		# One charred plank still hangs from the rope at the gap.
		var hx := burnt_to + 0.05
		var hy: float = sag.call(hx)
		g.paint(bounds, func(p: Vector3) -> float:
			return maxf(maxf(absf(p.x - hx) - 0.035, absf(p.y - hy + 0.42) - 0.4), absf(p.z + 0.4) - 0.11), Mat.CHAR, -1, VoxelGrid.Mode.ADD)
		# Charred rope fibres and embers at the burnt ends.
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return absf(absf(p.x) - span / 6.0) < 0.5 and VoxelSdf.hash3(c, 32) < 0.5, Mat.CHAR, [Mat.ROPE, Mat.WOOD])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return absf(absf(p.x) - span / 6.0) < 0.25 and VoxelSdf.hash3(c, 33) < 0.15, Mat.EMBER, [Mat.CHAR])
	return _mesh("bridge%d" % roundi(span * 10.0), bounds, cell, paint)


## A fallen spire, fossilised in the floor: three faceted pieces in a line,
## half sunk, with cooled lava (crust) filling the breaks. Along x.
static func fallen_spire() -> ArrayMesh:
	var bounds := AABB(Vector3(-14.5, -1.0, -3.5), Vector3(29.0, 5.0, 7.0))
	var facets := _facets(6, 2700)
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			var t := (p.x + 14.0) / 28.0
			var rr := 3.0 * (1.0 - t * 0.8)
			var q := Vector2(p.y - 0.6, p.z)
			return maxf(maxf(_prism(q, rr, facets).x, absf(p.x) - 14.0), -p.y - 0.5), Mat.OBSIDIAN)
		for bx: float in [-4.0, 5.5]:
			g.paint(bounds, func(p: Vector3) -> float:
				return absf(p.x - bx + p.z * 0.25) - 0.45, Mat.CRUST, -1, VoxelGrid.Mode.PAINT)
			g.paint(AABB(Vector3(bx - 1.5, -0.5, -3.5), Vector3(3, 0.9, 7)), func(p: Vector3) -> float:
				return maxf(absf(p.x - bx + p.z * 0.25) - 1.1, p.y - 0.15 - 0.2 * VoxelSdf.hash3(Vector3i(int(p.x * 4), 0, int(p.z * 4)), 4)), Mat.CRUST, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			var t := (p.x + 14.0) / 28.0
			var d := _prism(Vector2(p.y - 0.6, p.z), 3.0 * (1.0 - t * 0.8), facets)
			return d.x - d.y < 0.2, Mat.GLINT, [Mat.OBSIDIAN])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y > 1.5 and VoxelSdf.hash3(Vector3i(c.x / 2, 0, c.z / 2), 34) < 0.3, Mat.ASH, [Mat.OBSIDIAN, Mat.GLINT])
	return _mesh("fallen_spire", bounds, T2 * 0.5, paint)


## Offering cairn on the rim: stacked pumice slabs ringed by obsidian shards.
static func cairn() -> ArrayMesh:
	var bounds := AABB(Vector3(-1.2, -0.1, -1.2), Vector3(2.4, 1.3, 2.4))
	var paint := func(g: VoxelGrid) -> void:
		var y := 0.0
		for k in 5:
			var s := 0.42 - k * 0.06
			var h := 0.16 - k * 0.012
			var c := Vector3(0.04 * sin(k * 2.1), y + h * 0.5, 0.04 * cos(k * 1.7))
			g.paint(bounds, func(p: Vector3) -> float:
				return VoxelSdf.box(p, c, Vector3(s, h * 0.5, s * 0.85), 0.03), Mat.PUMICE if k % 2 == 0 else Mat.PUMICE_DARK, -1, VoxelGrid.Mode.ADD)
			y += h
		for k in 10:
			var a := TAU * k / 10.0
			var c := Vector3(cos(a) * 0.95, 0.0, sin(a) * 0.95)
			var hh := 0.12 + 0.12 * VoxelSdf.hash3(Vector3i(k, 0, 0), 5)
			g.paint(bounds, func(p: Vector3) -> float:
				return maxf(VoxelSdf.box(p, c, Vector3(0.05, hh, 0.035)), p.y - hh - absf(p.x - c.x) * 2.0), Mat.OBSIDIAN, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool: return VoxelSdf.hash3(c, 35) < 0.2, Mat.GLINT, [Mat.OBSIDIAN])
	return _mesh("cairn", bounds, T0 * 2.0, paint)


# ---------------------------------------------------------------- motion

## A T3 smoke puff for the plume: flat-ish lumps, grey above, warm below.
static func puff(v: int) -> ArrayMesh:
	var bounds := AABB(Vector3(-15, -10, -15), Vector3(30, 21, 30))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 2800 + v
		for k in 8:
			var c := Vector3(rng.randf_range(-6, 6), rng.randf_range(-4, 4), rng.randf_range(-6, 6))
			var r := rng.randf_range(3.5, 6.5)
			g.paint(AABB(c - Vector3.ONE * r, Vector3.ONE * r * 2), func(p: Vector3) -> float:
				return VoxelSdf.ellipsoid(p, c, Vector3(r, r * 0.9, r)), Mat.SMOKE, -1, VoxelGrid.Mode.ADD)
	return _mesh("puff_b%d" % v, bounds, T3, paint)


## One molten blob of a geyser column (T1, glowing).
static func blob(v: int) -> ArrayMesh:
	var s := 0.35 + 0.2 * v
	var bounds := AABB(-Vector3.ONE * s * 1.2, Vector3.ONE * s * 2.4)
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3.ZERO, Vector3(s, s * 0.85, s), s * 0.35), Mat.EMBER)
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool: return VoxelSdf.hash3(c, 36) < 0.3, Mat.LAVA)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool: return p.y > s * 0.5 and VoxelSdf.hash3(c, 37) < 0.35, Mat.CRUST)
	return _mesh("blob_b%d" % v, bounds, T1, paint)
