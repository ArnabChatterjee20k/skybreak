class_name FrozenPeaksDesigns
extends RefCounted
## Frozen Peaks prop designs (docs/lookdev/frozen_peaks.md), painted in blocks
## with the character kit's VoxelGrid and cached by VoxelProp: faceted ice
## spires, stratified ice shelves with icicle fringes, faceted boulders, slate
## cairns and the expedition camp. Every design takes a cell so it can build
## its own LOD tiers. Snow caps are part of each prop: up-facing faces of rock
## and ice turn to snow in color(), so a cap never floats.

## Bump to rebuild the cached meshes after changing a design.
const VERSION := 3

enum Mat {
	EMPTY, SNOW, SNOW_PACKED, ICE, ICE_CLEAR, ICE_DEEP, SLATE, SLATE_DARK, LICHEN,
	CANVAS, CANVAS_DARK, WOOD, WOOD_NEW, ROPE, IRON, LANTERN, PENNANT, ENAMEL, PAINT, LEATHER,
}
## Palette (sRGB) from the sheet. Aurora green lives in the sky only.
const COLORS := {
	Mat.SNOW: Color("#E4E8EE"), Mat.SNOW_PACKED: Color("#F0F2F5"),
	Mat.ICE: Color("#9CB4C4"), Mat.ICE_CLEAR: Color("#C8DAE4"), Mat.ICE_DEEP: Color("#5A7488"),
	Mat.SLATE: Color("#4A505E"), Mat.SLATE_DARK: Color("#2C303A"), Mat.LICHEN: Color("#7A7458"),
	Mat.CANVAS: Color("#8A7E68"), Mat.CANVAS_DARK: Color("#5A5040"),
	Mat.WOOD: Color("#6A5440"), Mat.WOOD_NEW: Color("#9A8262"), Mat.ROPE: Color("#A08A68"),
	Mat.IRON: Color("#3E4048"), Mat.LANTERN: Color("#F0C890"), Mat.PENNANT: Color("#7A5652"),
	Mat.ENAMEL: Color("#C4CAD0"), Mat.PAINT: Color("#D2D6DA"), Mat.LEATHER: Color("#4E3E32"),
}
## Spire variants: [height, base radius, satellites]. Instances pick the
## closest in size and aspect, so voxels stay near cubic.
const SPIRES := [[26.0, 5.0, 2], [34.0, 5.5, 3], [44.0, 6.5, 2], [56.0, 7.5, 3], [40.0, 9.0, 4], [30.0, 8.0, 3]]
## Shelf variants: [length (out from the cliff), width]; all 4 m thick.
const SHELVES := [[30.0, 18.0], [40.0, 18.0], [30.0, 24.0], [40.0, 24.0]]
## Nominal boulder size factor (sim boulders are a sphere of (1.3, 1, 1.1) * s).
const BOULDER_S := 4.0


static func color(mat: int, p: Vector3, c: Vector3i, n: Vector3, occlusion: float, exposure: float) -> Color:
	var base: Color = COLORS.get(mat, Color.MAGENTA)
	var capped := mat in [Mat.ICE, Mat.ICE_CLEAR, Mat.ICE_DEEP, Mat.SLATE, Mat.SLATE_DARK, Mat.LICHEN, Mat.WOOD,
		Mat.CANVAS, Mat.CANVAS_DARK]
	# Cap pass: up-facing faces of rock, ice and gear hold snow.
	if capped and n.y > 0.5 and VoxelSdf.hash3(c, 41) < 0.9:
		base = COLORS[Mat.SNOW]
		mat = Mat.SNOW
	var quiet := mat in [Mat.SNOW, Mat.SNOW_PACKED]
	var col := VoxelDesign.default_color(base, mat, c, occlusion * (0.6 if quiet else 1.0), exposure, quiet,
		mat in [Mat.ICE, Mat.ICE_CLEAR, Mat.SLATE, Mat.WOOD, Mat.CANVAS], true)
	if quiet:
		# Snow stays clean: +-2% only, blue in its hollows, never dirty.
		col = base * (0.985 + 0.03 * VoxelSdf.hash3(c, 43))
		col = col.lerp(Color("#9AA6BC"), clampf(occlusion * 0.9, 0.0, 0.6))
		if VoxelSdf.hash3(c, 47) < 0.006 and n.y > 0.5:
			col = Color(1, 1, 1)  # frost sparkle
		col.a = 1.0
	elif mat in [Mat.ICE, Mat.ICE_CLEAR, Mat.ICE_DEEP]:
		# Ice: up to +-6% in layers, lighter clear edges, darker deep cores.
		var layer := VoxelSdf.hash3(Vector3i(0, floori(p.y / 0.9), 0), 53) * 2.0 - 1.0
		col *= 1.0 + 0.05 * layer
		col = col.lerp(COLORS[Mat.ICE_CLEAR], clampf(exposure * 0.6, 0.0, 0.5))
		col.a = 1.0
	return col


static func surface_of(mat: int) -> int:
	match mat:
		Mat.IRON:
			return VoxelProp.Surf.METAL
		Mat.LANTERN:
			return VoxelProp.Surf.GLOW
		Mat.ICE_CLEAR:
			return VoxelProp.Surf.WATER
		Mat.ICE, Mat.ICE_DEEP:
			return VoxelProp.Surf.PETAL
		Mat.WOOD, Mat.WOOD_NEW:
			return VoxelProp.Surf.BARK
	return VoxelProp.Surf.MATTE


static func _mesh(key: String, bounds: AABB, cell: float, paint: Callable) -> ArrayMesh:
	return VoxelProp.mesh(key, VERSION, bounds, cell, paint, color, surface_of)


# ---------------------------------------------------------------- shapes

## Hexagonal prism around the local y axis (flats facing +-z), apothem a.
static func hex(q: Vector3, a: float, y0: float, y1: float) -> float:
	var x := absf(q.x)
	var z := absf(q.z)
	return maxf(maxf(z, x * 0.8660254 + z * 0.5) - a, maxf(y0 - q.y, q.y - y1))


## A hex crystal: prism to y_body, then a stepped pyramid tip to y_tip.
static func crystal(q: Vector3, a: float, y_body: float, y_tip: float, steps := 5) -> float:
	if q.y <= y_body:
		return hex(q, a, -2.0, y_body)
	var t := clampf((q.y - y_body) / maxf(y_tip - y_body, 0.01), 0.0, 1.0)
	var ts := floorf(t * steps) / steps
	return hex(q, a * (1.0 - ts) + 0.05, -2.0, y_tip)


## Point p in the frame of a crystal standing at base, tilted by (tx, tz), yawed.
static func frame(p: Vector3, base: Vector3, yaw: float, tx: float, tz: float) -> Vector3:
	var b := Basis.from_euler(Vector3(tx, 0, tz)) * Basis(Vector3.UP, yaw)
	return b.inverse() * (p - base)


## The Crown Star: a six-point frost star whose top three points are longer.
## q in star radii (1 = the long points), y up.
static func crown_star(q: Vector2) -> bool:
	var r := q.length()
	var ang := rad_to_deg(atan2(q.y, q.x))
	var k := roundi((ang - 90.0) / 60.0)
	var delta := absf(ang - (90.0 + 60.0 * k))
	var top := posmod(k, 6) in [0, 1, 5]
	var tip := 1.0 if top else 0.62
	return r < lerpf(tip, 0.28, delta / 30.0)


# ---------------------------------------------------------------- ice spires

## A spire cluster: a main hex crystal with a stepped tip and 2-4 tilted
## satellites; layered ice, a darker band here and there, bubbles and a crack.
static func spire(v: int, cell: float) -> ArrayMesh:
	var spec: Array = SPIRES[v]
	var h: float = spec[0]
	var r: float = spec[1]
	var bounds := AABB(Vector3(-r * 1.6, -0.5, -r * 1.6), Vector3(r * 3.2, h + 1.0, r * 3.2))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 900 + v
		var a := r * 0.55
		var main_yaw := rng.randf() * PI
		g.paint(AABB(Vector3(-a * 1.3, -0.5, -a * 1.3), Vector3(a * 2.6, h + 0.5, a * 2.6)), func(p: Vector3) -> float:
			return crystal(frame(p, Vector3.ZERO, main_yaw, 0.0, 0.0), a, h * 0.74, h, 6), Mat.ICE)
		for k: int in spec[2]:
			var ang := TAU * (k + rng.randf_range(-0.15, 0.15)) / float(spec[2])
			var off := Vector3(cos(ang), 0, sin(ang)) * r * rng.randf_range(0.62, 0.85)
			var sa := r * rng.randf_range(0.2, 0.34)
			var sh := h * rng.randf_range(0.28, 0.6)
			var lean := rng.randf_range(0.12, 0.3)
			var tx := sin(ang) * lean
			var tz := -cos(ang) * lean
			var yaw := rng.randf() * PI
			var reach := sa * 1.4 + sh * lean
			g.paint(AABB(off - Vector3(reach, 0.5, reach), Vector3(reach * 2.0, sh + 1.0, reach * 2.0)), func(p: Vector3) -> float:
				return crystal(frame(p, off, yaw, tx, tz), sa, sh * 0.7, sh, 4), Mat.ICE, -1, VoxelGrid.Mode.ADD)
		var bands := []
		for k in 6:
			bands.append(rng.randf_range(2.0, h * 0.8))
		var crack_a := rng.randf() * TAU
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			for b: float in bands:
				if absf(p.y - b) < 0.45:
					return true
			if VoxelSdf.hash3(c, 61) < 0.025:
				return true  # bubbles
			# A long diagonal crack on one face.
			var ang := atan2(p.z, p.x)
			return absf(wrapf(ang - crack_a, -PI, PI)) < 0.5 and absf(fposmod(p.y * 0.8 + ang * 3.0, 6.0) - 3.0) < 0.18,
				Mat.ICE_DEEP, [Mat.ICE])
		# Clear ice on the vertical edges of every crystal.
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool:
			var open := 0
			for d: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				if g.get_mat(c.x + d.x, c.y, c.z + d.z) == 0:
					open += 1
			return open >= 2, Mat.ICE_CLEAR, [Mat.ICE])
	return _mesh("fp_spire%d" % v, bounds, cell, paint)


## The variant and transform that fit a sim spire (a cone of radius r, height
## h, standing at base): same footprint and height within ~15%.
static func fit_spire(sim: Transform3D) -> Array:
	var sc := sim.basis.get_scale()
	var r := absf(sc.x) * 0.5
	var h := absf(sc.y)
	var rot := sim.basis.orthonormalized()
	var base := sim.origin - sim.basis * Vector3(0, 0.5, 0)
	var best := 0
	var best_cost := INF
	for v in SPIRES.size():
		var s: float = h / float(SPIRES[v][0])
		var rr: float = float(SPIRES[v][1]) * s
		var cost := absf(log(s)) * 0.5 + absf(log(rr / r))
		if cost < best_cost:
			best_cost = cost
			best = v
	var s: float = h / float(SPIRES[best][0])
	var sxz := clampf(r / float(SPIRES[best][1]), s * 0.85, s * 1.15)
	return [best, Transform3D(rot * Basis.from_scale(Vector3(sxz, s, sxz)), base)]


# ---------------------------------------------------------------- ice shelves

## A stratified slab jutting out along +x: ice and old-snow layers, a drifted
## snow top with a cornice over the outer edge, a jagged outer edge and an
## icicle fringe under it. Centred on the sim box (4 m thick).
static func shelf(v: int, cell: float) -> ArrayMesh:
	var l: float = SHELVES[v][0]
	var w: float = SHELVES[v][1]
	var bounds := AABB(Vector3(-l * 0.5 - 0.5, -8.5, -w * 0.5 - 0.5), Vector3(l + 2.0, 11.5, w + 1.0))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1300 + v
		# Slab: thinner toward the tip, the outer edge broken into steps.
		g.paint(bounds, func(p: Vector3) -> float:
			var u := (p.x + l * 0.5) / l
			var jag := floorf(VoxelSdf.hash3(Vector3i(0, 0, floori(p.z / 1.6)), 3 + v) * 3.0) * 1.1
			var side := w * 0.5 - floorf(VoxelSdf.hash3(Vector3i(floori(p.x / 2.2), 0, 0), 7 + v) * 2.0) * 0.8 * u
			var bottom := -2.0 + 1.6 * u * u
			return maxf(maxf(p.x - (l * 0.5 - jag), -l * 0.5 - p.x), maxf(absf(p.z) - side, maxf(bottom - p.y, p.y - 1.4))),
			Mat.ICE)
		# Layers: blue ice, cloudy ice, old snow, hashed per 0.7 m band.
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return VoxelSdf.hash3(Vector3i(0, floori((p.y + 4.0) / 0.7), 0), 11 + v) < 0.35, Mat.ICE_DEEP, [Mat.ICE])
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return VoxelSdf.hash3(Vector3i(0, floori((p.y + 4.0) / 0.7), 0), 13 + v) < 0.2, Mat.SNOW_PACKED, [Mat.ICE])
		# Drifted snow top and a cornice curling over the outer edge.
		g.paint(bounds, func(p: Vector3) -> float:
			var drift := 1.4 + 0.5 + 0.35 * sin(p.z * 0.7 + v) + 0.25 * sin(p.x * 0.45)
			var u := (p.x + l * 0.5) / l
			var reach := l * 0.5 + 0.9 - floorf(VoxelSdf.hash3(Vector3i(0, 0, floori(p.z / 1.6)), 3 + v) * 3.0) * 1.1
			return maxf(maxf(p.y - drift, 1.3 - p.y), maxf(p.x - reach, maxf(-l * 0.5 - p.x, absf(p.z) - w * 0.5 + 0.6 * u))),
			Mat.SNOW, -1, VoxelGrid.Mode.ADD)
		# Icicle fringe: under the outer edge and the outer half of both sides.
		var spots: Array[Vector3] = []
		var z := -w * 0.5 + 0.6
		while z < w * 0.5 - 0.6:
			var jag := floorf(VoxelSdf.hash3(Vector3i(0, 0, floori(z / 1.6)), 3 + v) * 3.0) * 1.1
			spots.append(Vector3(l * 0.5 - jag - 0.5, 0, z))
			z += rng.randf_range(0.7, 1.5)
		var x := 0.0
		while x < l * 0.5 - 1.0:
			for sgn: float in [-1.0, 1.0]:
				spots.append(Vector3(x, 0, sgn * (w * 0.5 - 1.2)))
			x += rng.randf_range(1.2, 2.4)
		for s in spots:
			var u := (s.x + l * 0.5) / l
			var top := -2.0 + 1.6 * u * u + 0.2
			var length := rng.randf_range(0.8, 5.5) * (0.5 + 0.5 * u)
			var rad := rng.randf_range(0.22, 0.45)
			var a := Vector3(s.x, top, s.z)
			var b := Vector3(s.x + rng.randf_range(-0.2, 0.2), top - length, s.z)
			g.paint(AABB(b - Vector3(0.6, 0.2, 0.6), Vector3(1.2, length + 0.6, 1.2)), func(p: Vector3) -> float:
				return VoxelSdf.capsule(p, a, b, rad, 0.06), Mat.ICE_CLEAR, -1, VoxelGrid.Mode.ADD)
	return _mesh("fp_shelf%d" % v, bounds, cell, paint)


static func fit_shelf(sim: Transform3D) -> Array:
	var sc := sim.basis.get_scale()
	var rot := sim.basis.orthonormalized()
	var best := 0
	var best_cost := INF
	for v in SHELVES.size():
		var cost := absf(log(sc.x / float(SHELVES[v][0]))) + absf(log(sc.z / float(SHELVES[v][1])))
		if cost < best_cost:
			best_cost = cost
			best = v
	var k := Vector3(sc.x / float(SHELVES[best][0]), 1.0, sc.z / float(SHELVES[best][1]))
	k.y = (k.x + k.z) * 0.5
	return [best, Transform3D(rot * Basis.from_scale(k), sim.origin)]


# ---------------------------------------------------------------- boulders

## A faceted boulder: a convex block cut by planes (v < 3 ice, else slate with
## tilted strata and lichen), a chipped corner, snow on its top faces.
static func boulder(v: int, cell: float) -> ArrayMesh:
	var s := BOULDER_S
	var half := Vector3(0.65, 0.5, 0.55) * s
	var bounds := AABB(-half * 1.15, half * 2.3)
	var ice := v < 3
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1700 + v
		var planes: Array[Vector3] = []
		var dists: Array[float] = []
		for k in 11:
			var n := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1.0), rng.randf_range(-1, 1)).normalized()
			planes.append(n)
			dists.append(Vector3(n.x * half.x, n.y * half.y, n.z * half.z).length() * rng.randf_range(0.78, 0.95))
		var flat_bottom := -half.y * 0.75
		g.paint(bounds, func(p: Vector3) -> float:
			var d := VoxelSdf.ellipsoid(p, Vector3.ZERO, half)
			for k in planes.size():
				d = maxf(d, p.dot(planes[k]) - dists[k])
			return maxf(d, flat_bottom - p.y), Mat.ICE if ice else Mat.SLATE)
		var chip := Vector3(half.x * 0.8, half.y * 0.6, -half.z * 0.7)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.sphere(p, chip, s * 0.18), 0, -1, VoxelGrid.Mode.CARVE)
		if ice:
			g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
				return VoxelSdf.hash3(c, 63) < 0.04 or absf(fposmod(p.y * 1.3 + p.x * 0.4, 2.2) - 1.1) < 0.08, Mat.ICE_DEEP, [Mat.ICE])
		else:
			var tilt := Vector3(rng.randf_range(-0.3, 0.3), 1.0, rng.randf_range(-0.3, 0.3)).normalized()
			g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
				return fposmod(p.dot(tilt) / 0.45, 1.0) < 0.22, Mat.SLATE_DARK, [Mat.SLATE])
			g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
				return p.y < half.y * 0.2 and VoxelSdf.hash3(Vector3i(c.x / 2, c.y / 2, c.z / 2), 67) < 0.06, Mat.LICHEN, [Mat.SLATE])
	return _mesh("fp_boulder%d" % v, bounds, cell, paint)


# ---------------------------------------------------------------- cairns

## A waymarker cairn of stacked slate slabs. tall: the first cairn, with a flat
## capstone scratched with tally marks and the Crown Star on its biggest slab.
static func cairn(v: int, tall: bool) -> ArrayMesh:
	var bounds := AABB(Vector3(-0.8, -0.1, -0.8), Vector3(1.6, 2.6 if tall else 1.9, 1.6))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 2100 + v + (50 if tall else 0)
		var y := -0.05
		var count := 9 if tall else 5 + v
		var star_slab := 1
		for k in count:
			var t := float(k) / float(count)
			var hx := lerpf(0.62, 0.22, t) * rng.randf_range(0.85, 1.1)
			var hz := lerpf(0.5, 0.2, t) * rng.randf_range(0.85, 1.1)
			var hy := rng.randf_range(0.06, 0.11) if k != star_slab or not tall else 0.2
			var c := Vector3(rng.randf_range(-0.06, 0.06), y + hy, rng.randf_range(-0.06, 0.06))
			var yaw := rng.randf_range(-0.5, 0.5)
			g.paint(AABB(c - Vector3(0.8, hy + 0.05, 0.8), Vector3(1.6, hy * 2.0 + 0.1, 1.6)), func(p: Vector3) -> float:
				var q := Basis(Vector3.UP, yaw).inverse() * (p - c)
				return VoxelSdf.box(q, Vector3.ZERO, Vector3(hx, hy, hz), 0.03), Mat.SLATE if k % 3 else Mat.SLATE_DARK,
				-1, VoxelGrid.Mode.ADD)
			if tall and k == star_slab:
				var sc := c
				g.paint_surface(AABB(sc - Vector3(0.7, 0.3, 0.7), Vector3(1.4, 0.6, 1.4)), func(p: Vector3, _c: Vector3i) -> bool:
					return p.z > sc.z + 0.1 and crown_star(Vector2(p.x - sc.x, p.y - sc.y) / 0.19), Mat.PAINT, [Mat.SLATE, Mat.SLATE_DARK])
			y += hy * 2.0
		if tall:
			# Flat capstone with tally marks (days at the camp) on its front edge.
			var top := y + 0.06
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, top, 0), Vector3(0.3, 0.06, 0.26)), Mat.SLATE,
				-1, VoxelGrid.Mode.ADD)
			g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
				if p.z < 0.2 or absf(p.y - top) > 0.07:
					return false
				var slot := floori((p.x + 0.28) / 0.05)
				return slot >= 0 and slot < 11 and slot % 5 != 4 and fposmod(p.x + 0.28, 0.05) < 0.02, Mat.PAINT, [Mat.SLATE])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y < 0.5 and VoxelSdf.hash3(c, 71) < 0.08, Mat.LICHEN, [Mat.SLATE, Mat.SLATE_DARK])
		# Drifted snow against the windward foot.
		g.paint(bounds, func(p: Vector3) -> float:
			return maxf(VoxelSdf.ellipsoid(p, Vector3(-0.35, 0.0, 0.1), Vector3(0.55, 0.22, 0.6)), -p.y), Mat.SNOW, -1, VoxelGrid.Mode.ADD)
	return _mesh("fp_cairn%d%s" % [v, "_tall" if tall else ""], bounds, VoxelZone.T0 * 2.0, paint)


# ---------------------------------------------------------------- the expedition camp

## The standing tent: two planar canvas panels on an A-frame, the front flap
## tied open, a lantern glowing inside, guy-lines to pegs, snow on the ridge
## and drifted against the windward side.
static func tent_standing() -> ArrayMesh:
	var bounds := AABB(Vector3(-1.9, -0.1, -1.9), Vector3(3.8, 2.0, 3.8))
	var paint := func(g: VoxelGrid) -> void:
		var hw := 1.05
		var ht := 1.55
		var hl := 1.25
		# Canvas panels: |x| / hw + y / ht = 1, 4 cm thick.
		g.paint(bounds, func(p: Vector3) -> float:
			var plane := (absf(p.x) / hw + p.y / ht - 1.0) * 0.8
			return maxf(maxf(absf(plane) - 0.025, absf(p.z) - hl), maxf(-p.y, p.y - ht)), Mat.CANVAS)
		# Seams and a darker hem.
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return p.y < 0.12 or absf(fposmod(p.z + hl, 0.62) - 0.31) < 0.025, Mat.CANVAS_DARK, [Mat.CANVAS])
		# Front opening: the flap is cut out and folded back on the right.
		g.paint(bounds, func(p: Vector3) -> float:
			return maxf(p.z - hl - 0.2, maxf(hl - 0.15 - p.z, absf(p.x) / 0.55 + p.y / 1.15 - 1.0)), 0, -1, VoxelGrid.Mode.CARVE)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0.62, 0.55, hl + 0.06), Vector3(0.14, 0.45, 0.03)), Mat.CANVAS_DARK, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0.62, 0.75, hl + 0.1), Vector3(0.16, 0.025, 0.025)), Mat.ROPE, -1, VoxelGrid.Mode.ADD)
		# Poles, ridge and pegs.
		for z: float in [-hl - 0.05, hl + 0.05]:
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, ht * 0.5 + 0.05, z), Vector3(0.03, ht * 0.5 + 0.1, 0.03)), Mat.WOOD, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, ht + 0.02, 0), Vector3(0.03, 0.03, hl + 0.12)), Mat.WOOD, -1, VoxelGrid.Mode.ADD)
		for gx: float in [-1.0, 1.0]:
			for gz: float in [-1.0, 1.0]:
				var a := Vector3(gx * hw * 0.55, ht * 0.45, gz * hl * 0.8)
				var b := Vector3(gx * 1.75, 0.02, gz * 1.6)
				g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, a, b, 0.012, 0.012), Mat.ROPE, -1, VoxelGrid.Mode.ADD)
				g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, b + Vector3(0, 0.06, 0), Vector3(0.025, 0.08, 0.025)), Mat.WOOD, -1, VoxelGrid.Mode.ADD)
		# The lantern inside, hung from the ridge.
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 0.95, 0.4), Vector3(0.08, 0.11, 0.08), 0.02), Mat.LANTERN, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 1.1, 0.4), Vector3(0.06, 0.03, 0.06)), Mat.IRON, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, Vector3(0, 1.12, 0.4), Vector3(0, ht, 0.4), 0.01, 0.01), Mat.IRON, -1, VoxelGrid.Mode.ADD)
		# A bedroll inside, and drift on the windward (-x) side and the ridge.
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(-0.3, 0.08, -0.2), Vector3(0.3, 0.07, 0.8), 0.05), Mat.CANVAS_DARK, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float:
			return maxf(VoxelSdf.ellipsoid(p, Vector3(-1.2, 0.0, 0.0), Vector3(0.6, 0.55, 1.6)), -p.y), Mat.SNOW, -1, VoxelGrid.Mode.FILL)
		g.paint(bounds, func(p: Vector3) -> float:
			var plane := (absf(p.x) / hw + p.y / ht - 1.0) * 0.8
			return maxf(maxf(plane - 0.09, -plane - 0.02), maxf(absf(p.z) - hl + 0.1, ht - 0.35 - p.y)), Mat.SNOW, -1, VoxelGrid.Mode.ADD)
	return _mesh("fp_tent_up", bounds, VoxelZone.T0 * 2.0, paint)


## The collapsed tent: canvas sagging over a broken pole, mostly drifted over,
## one pole end sticking up out of the snow.
static func tent_collapsed() -> ArrayMesh:
	var bounds := AABB(Vector3(-1.8, -0.1, -1.8), Vector3(3.6, 1.5, 3.6))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			var top := 0.45 - 0.25 * absf(p.x) + 0.12 * sin(p.z * 2.4) - 0.1 * absf(p.z)
			return maxf(maxf(absf(p.y - top) - 0.03, -p.y), maxf(absf(p.x) - 1.2, absf(p.z) - 1.3)), Mat.CANVAS)
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return absf(fposmod(p.z + 1.3, 0.62) - 0.31) < 0.025, Mat.CANVAS_DARK, [Mat.CANVAS])
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.capsule(p, Vector3(0.1, 0.0, 1.25), Vector3(0.35, 1.25, 1.55), 0.03, 0.03), Mat.WOOD, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.capsule(p, Vector3(-0.2, 0.42, -1.3), Vector3(0.3, 0.5, 0.2), 0.03, 0.03), Mat.WOOD, -1, VoxelGrid.Mode.ADD)
		# Snow buries the windward two thirds in terraced drifts.
		g.paint(bounds, func(p: Vector3) -> float:
			var drift := 0.62 - 0.3 * maxf(p.x + 0.2, 0.0) - 0.12 * absf(p.z)
			drift = floorf(drift / 0.088) * 0.088
			return maxf(maxf(p.y - drift, -p.y), maxf(absf(p.x + 0.2) - 1.55, absf(p.z) - 1.6)), Mat.SNOW, -1, VoxelGrid.Mode.FILL)
	return _mesh("fp_tent_down", bounds, VoxelZone.T0 * 2.0, paint)


## Planks of a crate (0.8 m cube by default) centred at c; star: paint the
## Crown Star on its +z face; split: the lid is off and coiled rope shows.
static func _crate(g: VoxelGrid, bounds: AABB, c: Vector3, half: Vector3, yaw: float, star: bool, split := false) -> void:
	var b := Basis(Vector3.UP, yaw)
	var bi := b.inverse()
	g.paint(AABB(c - half * 1.6, half * 3.2), func(p: Vector3) -> float:
		var q := bi * (p - c)
		var box := VoxelSdf.box(q, Vector3.ZERO, half, 0.015)
		if split:
			box = maxf(box, -VoxelSdf.box(q, Vector3(0, half.y * 0.6, 0), half - Vector3(0.05, 0.0, 0.05)))
		return box, Mat.WOOD, -1, VoxelGrid.Mode.ADD)
	g.paint_surface(AABB(c - half * 1.6, half * 3.2), func(p: Vector3, _cc: Vector3i) -> bool:
		var q := bi * (p - c)
		return absf(fposmod(q.y + half.y, half.y * 2.0 / 3.0)) < 0.03, Mat.LEATHER, [Mat.WOOD])
	g.paint_surface(AABB(c - half * 1.6, half * 3.2), func(p: Vector3, _cc: Vector3i) -> bool:
		var q := bi * (p - c)
		return absf(absf(q.x) - half.x) < 0.07 and absf(absf(q.z) - half.z) < 0.07, Mat.IRON, [Mat.WOOD, Mat.LEATHER])
	if star:
		g.paint_surface(AABB(c - half * 1.6, half * 3.2), func(p: Vector3, _cc: Vector3i) -> bool:
			var q := bi * (p - c)
			return q.z > half.z - 0.05 and crown_star(Vector2(q.x, q.y) / (half.x * 0.7)), Mat.PAINT, [Mat.WOOD, Mat.LEATHER, Mat.IRON])
	if split:
		for k in 4:
			var r := 0.24 - k * 0.035
			var y := c.y - half.y * 0.2 + k * 0.05
			g.paint(AABB(c - half * 1.6, half * 3.2), func(p: Vector3) -> float:
				return VoxelSdf.torus(p, Vector3(c.x, y, c.z), Vector3.UP, r, 0.03), Mat.ROPE, -1, VoxelGrid.Mode.ADD)


## Crates: a stack of two with one on top (a mug stands on the top one; the
## mug is its own T0 mesh), the Crown Star painted on the front.
static func crate_stack() -> ArrayMesh:
	var bounds := AABB(Vector3(-1.2, -0.1, -0.9), Vector3(2.4, 1.9, 1.8))
	var paint := func(g: VoxelGrid) -> void:
		var h := Vector3(0.4, 0.34, 0.36)
		_crate(g, bounds, Vector3(-0.45, h.y, 0), h, 0.05, true)
		_crate(g, bounds, Vector3(0.43, h.y, 0.05), h, -0.08, false)
		_crate(g, bounds, Vector3(-0.05, h.y * 3.0 + 0.01, 0.0), h * 0.9, 0.3, true)
		g.paint(bounds, func(p: Vector3) -> float:
			return maxf(VoxelSdf.ellipsoid(p, Vector3(-0.9, 0.0, -0.3), Vector3(0.5, 0.35, 0.8)), -p.y), Mat.SNOW, -1, VoxelGrid.Mode.ADD)
	return _mesh("fp_crates", bounds, VoxelZone.T0 * 2.0, paint)


## An enamel mug (T0) with a dark rim and handle.
static func mug() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.12, -0.01, -0.12), Vector3(0.24, 0.16, 0.24))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			var r := Vector2(p.x, p.z).length()
			return maxf(maxf(r - 0.045, absf(p.y - 0.05) - 0.05), -maxf(r - 0.035, 0.012 - p.y)), Mat.ENAMEL)
		g.paint(bounds, func(p: Vector3) -> float:
			var r := Vector2(p.x, p.z).length()
			return maxf(absf(r - 0.042) - 0.012, absf(p.y - 0.096) - 0.008), Mat.IRON, -1, VoxelGrid.Mode.FILL)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.torus(p, Vector3(0.055, 0.05, 0), Vector3(0, 0, 1), 0.028, 0.008), Mat.ENAMEL, -1, VoxelGrid.Mode.ADD)
	return _mesh("fp_mug", bounds, VoxelZone.T0 * 0.5, paint)


## The flagpole tripod (three poles lashed at the top) without its pennant.
static func tripod() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.9, -0.1, -0.9), Vector3(1.8, 3.4, 1.8))
	var paint := func(g: VoxelGrid) -> void:
		var top := Vector3(0, 2.6, 0)
		for k in 3:
			var a := TAU * k / 3.0 + 0.4
			var foot := Vector3(cos(a) * 0.75, 0.0, sin(a) * 0.75)
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, foot, top + (top - foot) * 0.08, 0.035, 0.028), Mat.WOOD, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, top, top + Vector3(0, 0.7, 0), 0.025, 0.02), Mat.WOOD, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.torus(p, top, Vector3.UP, 0.06, 0.025), Mat.ROPE, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float:
			return maxf(VoxelSdf.ellipsoid(p, Vector3.ZERO, Vector3(0.9, 0.18, 0.9)), -p.y), Mat.SNOW, -1, VoxelGrid.Mode.ADD)
	return _mesh("fp_tripod", bounds, VoxelZone.T0 * 2.0, paint)


## The torn pennant, frozen stiff mid-flap; its origin is the hoist (it swings
## about the pole in animate()).
static func pennant() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.05, -0.4, -0.08), Vector3(0.95, 0.5, 0.16))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			var u := clampf(p.x / 0.85, 0.0, 1.0)
			var half := 0.17 * (1.0 - u * 0.7)
			var wave := 0.04 * sin(u * 7.0)
			var torn := p.x > 0.55 and VoxelSdf.hash3(Vector3i(floori(p.x / 0.04), floori(p.y / 0.04), 0), 5) < 0.45
			if torn:
				return 1.0
			return maxf(maxf(absf(p.y + 0.17) - half, absf(p.z - wave) - 0.012), maxf(-p.x, p.x - 0.85)), Mat.PENNANT)
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return p.x < 0.05 or absf(p.y + 0.17) < 0.02, Mat.CANVAS, [Mat.PENNANT])
	return _mesh("fp_pennant", bounds, VoxelZone.T0, paint)


## The sledge: curled runners, a slatted deck, three crates lashed on (one
## split open with coiled rope inside), half buried under a drift at the back.
static func sledge() -> ArrayMesh:
	var bounds := AABB(Vector3(-1.6, -0.1, -0.7), Vector3(3.2, 1.5, 1.4))
	var paint := func(g: VoxelGrid) -> void:
		for z: float in [-0.42, 0.42]:
			g.paint(bounds, func(p: Vector3) -> float:
				var curl := 0.0 if p.x < 1.0 else (p.x - 1.0) * (p.x - 1.0) * 1.6
				return maxf(maxf(absf(p.y - 0.04 - curl) - 0.035, absf(p.z - z) - 0.03), maxf(-1.3 - p.x, p.x - 1.42)), Mat.WOOD)
			for x: float in [-1.0, -0.3, 0.4]:
				g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(x, 0.14, z), Vector3(0.03, 0.08, 0.03)), Mat.WOOD, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float:
			return maxf(VoxelSdf.box(p, Vector3(-0.15, 0.24, 0), Vector3(1.15, 0.025, 0.48)), -absf(fposmod(p.x, 0.2) - 0.1) + 0.015), Mat.WOOD_NEW, -1, VoxelGrid.Mode.ADD)
		var h := Vector3(0.3, 0.24, 0.3)
		_crate(g, bounds, Vector3(-0.8, 0.27 + h.y, 0), h, 0.04, true)
		_crate(g, bounds, Vector3(-0.15, 0.27 + h.y, 0.02), h, -0.05, false, true)
		_crate(g, bounds, Vector3(0.5, 0.27 + h.y, -0.03), h, 0.1, false)
		# Lashing ropes over the crates.
		for x: float in [-0.8, 0.5]:
			g.paint(bounds, func(p: Vector3) -> float:
				var rect := maxf(absf(p.z) - 0.32, absf(p.y - 0.27 - h.y) - h.y - 0.02)
				return maxf(absf(rect) - 0.02, absf(p.x - x) - 0.02),
				Mat.ROPE, -1, VoxelGrid.Mode.ADD)
		# The drift buries the back half in stepped snow.
		g.paint(bounds, func(p: Vector3) -> float:
			var drift := 0.95 - 0.55 * clampf((p.x + 1.6) / 1.8, 0.0, 1.0)
			drift = floorf(drift / 0.088) * 0.088
			return maxf(maxf(p.y - drift, -p.y), maxf(p.x + 0.1, absf(p.z) - 0.7)), Mat.SNOW, -1, VoxelGrid.Mode.FILL)
	return _mesh("fp_sledge", bounds, VoxelZone.T0 * 2.0, paint)


## The ice axe (T0), pick end along +x from the shaft head; the shaft runs
## along -z from the origin (the point where it enters the ice).
static func ice_axe() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.2, -0.1, -0.08), Vector3(0.4, 0.2, 0.82))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.capsule(p, Vector3(0, 0, 0.0), Vector3(0, 0, 0.66), 0.016, 0.016), Mat.WOOD)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 0, 0.5), Vector3(0.022, 0.022, 0.12)), Mat.LEATHER, -1, VoxelGrid.Mode.FILL)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 0, 0.7), Vector3(0.02, 0.02, 0.04)), Mat.IRON, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.capsule(p, Vector3(0, 0, 0.72), Vector3(0.16, -0.03, 0.7), 0.014, 0.006), Mat.IRON, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(-0.09, 0, 0.72), Vector3(0.07, 0.012, 0.03)), Mat.IRON, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.torus(p, Vector3(0, -0.04, 0.42), Vector3(1, 0, 0), 0.05, 0.007), Mat.LEATHER, -1, VoxelGrid.Mode.ADD)
	return _mesh("fp_ice_axe", bounds, VoxelZone.T0 * 0.5, paint)


## A rope bridge of length `span` along x: stakes at both ends, two hand
## ropes, fresh planks on two foot ropes, a gentle sag.
static func rope_bridge(span: float) -> ArrayMesh:
	var hl := span * 0.5
	var bounds := AABB(Vector3(-hl - 0.6, -0.6, -0.7), Vector3(span + 1.2, 1.9, 1.4))
	var sag := func(x: float) -> float: return -0.35 * (1.0 - (x / hl) * (x / hl))
	var paint := func(g: VoxelGrid) -> void:
		for z: float in [-0.5, 0.5]:
			for x: float in [-hl - 0.2, hl + 0.2]:
				g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(x, 0.45, z), Vector3(0.05, 0.6, 0.05), 0.01), Mat.WOOD)
			g.paint(bounds, func(p: Vector3) -> float:
				return maxf(Vector2(p.y - 0.95 - sag.call(clampf(p.x, -hl, hl)) * 0.6, p.z - z).length() - 0.02, absf(p.x) - hl - 0.2), Mat.ROPE, -1, VoxelGrid.Mode.ADD)
			g.paint(bounds, func(p: Vector3) -> float:
				return maxf(Vector2(p.y - 0.05 - sag.call(clampf(p.x, -hl, hl)), p.z - z * 0.8).length() - 0.02, absf(p.x) - hl - 0.2), Mat.ROPE, -1, VoxelGrid.Mode.ADD)
		var x := -hl + 0.1
		while x < hl:
			var px := x
			g.paint(bounds, func(p: Vector3) -> float:
				return VoxelSdf.box(p, Vector3(px, 0.09 + sag.call(px), 0), Vector3(0.09, 0.022, 0.45)), Mat.WOOD_NEW, -1, VoxelGrid.Mode.ADD)
			x += 0.24
	return _mesh("fp_bridge_%d" % roundi(span * 10.0), bounds, VoxelZone.T0 * 2.0, paint)


## A low sastrugi ridge (wind-carved snow), 4-9 cm tall: relief on the snow.
static func sastrugi(v: int) -> ArrayMesh:
	var bounds := AABB(Vector3(-1.6, -0.05, -0.5), Vector3(3.2, 0.2, 1.0))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			var u := p.x / 1.5
			var crest := 0.09 * (1.0 - u * u) * (0.7 + 0.3 * sin(p.x * 3.0 + v))
			var lean := p.z - 0.1 * sin(p.x * 1.4 + v * 2.0)
			return maxf(maxf(p.y - crest * clampf(1.0 - absf(lean) / (0.15 + 0.2 * (1.0 - u * u)), 0.0, 1.0) - 0.005, -p.y), absf(u) - 1.0), Mat.SNOW_PACKED)
	return _mesh("fp_sastrugi%d" % v, bounds, VoxelZone.T0 * 2.0, paint)
