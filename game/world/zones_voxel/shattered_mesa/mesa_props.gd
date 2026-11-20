class_name MesaProps
extends RefCounted
## Shattered Mesa's voxel props. The hoodoos, boulders and the Red Arch take
## the transforms ShatteredMesaProps builds (PropKit seed 4242, as WorldMap);
## scrub, talus, dead trees and the story props are visual-only and stay off
## the open floor lines (low, or beside landmarks).

const VERSION := 2
enum Mat { NONE, LIGHT, DARK, PALE, CAP, LICHEN, SAND, SAGE, SAGE_DARK, WOOD, CANVAS, ROPE, IRON, BRASS,
	GLOW, LEDGER, VARNISH, GLYPH, WATER, BUCKET }
const COLORS := {
	Mat.LIGHT: Color("#C88C70"), Mat.DARK: Color("#9A5440"), Mat.PALE: Color("#D4A88C"),
	Mat.CAP: Color("#6E5E54"), Mat.LICHEN: Color("#B4D23C"), Mat.SAND: Color("#E2D2B4"),
	Mat.SAGE: Color("#8A9470"), Mat.SAGE_DARK: Color("#5A6248"), Mat.WOOD: Color("#B8B0A4"),
	Mat.CANVAS: Color("#B4A488"), Mat.ROPE: Color("#9A8466"), Mat.IRON: Color("#4A4642"),
	Mat.BRASS: Color("#9C8450"), Mat.GLOW: Color("#ffd89a"), Mat.LEDGER: Color("#5A3E30"),
	Mat.VARNISH: Color("#4A3428"), Mat.GLYPH: Color("#E0C0A4"), Mat.WATER: Color("#3a4a50"),
	Mat.BUCKET: Color("#7a7a74"),
}
## Hoodoo variants: (height, base radius) in metres.
const HOODOOS := [Vector2(30, 4.5), Vector2(38, 5.0), Vector2(46, 5.5), Vector2(54, 6.0), Vector2(62, 6.5),
	Vector2(70, 7.0)]

var zone: ShatteredMesaVoxel
var root: Node3D
var stats := {}
var arch_centre := Vector3.ZERO
var arch_base_y := 0.0
var arch_forward := Vector3.FORWARD
var camp_at := Vector3.ZERO
var hoodoo_hero := Transform3D.IDENTITY
var hoodoo_hero_r := 5.0
var _pillars: Array[Transform3D] = []
var _boulders: Array[Transform3D] = []
var _arch: Transform3D
var _cell_scale := 1.0


func _init(z: ShatteredMesaVoxel) -> void:
	zone = z


func build() -> void:
	root = Node3D.new()
	root.name = "MesaProps"
	zone.add_child(root)
	var t := Time.get_ticks_msec()
	_placements()
	_red_arch()
	_hoodoos()
	_boulder_field()
	_scrub()
	_story()
	stats.props_ms = Time.get_ticks_msec() - t


func ground(x: float, z: float) -> float:
	return zone.ground_at(x, z)


# ---------------------------------------------------------------- the sim's truth

func _placements() -> void:
	var kit := PropKit.new(zone.map, WorldMap.PROP_SEED)
	var layout := ZoneLayout.load_default()
	for zd in layout.ground_zones():
		for p in zd.spawn_points:
			kit.keep_clear.append(Vector3(p.x, p.z, WorldMap.SPAWN_CLEAR_RADIUS))
	var scratch := Node3D.new()
	ShatteredMesaProps.build(scratch, kit, zone.zone, layout)
	for child in scratch.get_children():
		var list: Array[Transform3D] = []
		list.assign(child.get_meta(PropKit.INSTANCE_TRANSFORMS_META, []))
		match String(child.name):
			"MesaPillars":
				_pillars = list
			"MesaBoulders":
				_boulders = list
			"MesaArches":
				_arch = list[0]
	scratch.free()
	stats.hoodoos = _pillars.size()
	stats.boulders = _boulders.size()


# ---------------------------------------------------------------- colour

func color(mat: int, p: Vector3, c: Vector3i, n: Vector3, occlusion: float, exposure: float) -> Color:
	var base: Color = COLORS.get(mat, Color.MAGENTA)
	var rock := mat in [Mat.LIGHT, Mat.DARK, Mat.PALE, Mat.CAP, Mat.VARNISH]
	var col := VoxelDesign.default_color(base, mat, c, occlusion, exposure, mat == Mat.SAND,
		rock or mat in [Mat.WOOD, Mat.CANVAS, Mat.BUCKET])
	if rock:
		# +-6% on rock, darker toward the foot of each piece.
		col *= 0.94 + 0.12 * VoxelSdf.hash3(c, 211)
		if n.y < -0.5:
			col *= 0.7
	if mat == Mat.LICHEN:
		col *= 0.88 + 0.24 * VoxelSdf.hash3(c, 223)
	col.a = 1.0
	return col


func surface_of(mat: int) -> int:
	match mat:
		Mat.IRON, Mat.BRASS, Mat.BUCKET:
			return VoxelProp.Surf.METAL
		Mat.GLOW:
			return VoxelProp.Surf.GLOW
		Mat.WATER:
			return VoxelProp.Surf.WATER
		Mat.WOOD:
			return VoxelProp.Surf.BARK
		Mat.SAGE, Mat.SAGE_DARK, Mat.CANVAS:
			return VoxelProp.Surf.PETAL
	return VoxelProp.Surf.MATTE


func _mesh(key: String, bounds: AABB, cell: float, paint: Callable) -> ArrayMesh:
	return VoxelProp.mesh("mesa_" + key, VERSION, bounds, cell * _cell_scale, paint, color, surface_of)


func _tiers(make: Callable, ks: Array) -> Array[ArrayMesh]:
	var out: Array[ArrayMesh] = []
	for k: float in ks:
		_cell_scale = k
		out.append(make.call())
	_cell_scale = 1.0
	return out


static func octagon(p: Vector3, c: Vector3, r: float) -> float:
	var d := Vector2(absf(p.x - c.x), absf(p.z - c.z))
	return maxf(maxf(d.x, d.y), (d.x + d.y) * 0.7071) - r


## Lichen on north (-Z) and top faces of rock, in clumps.
func _lichen(g: VoxelGrid, bounds: AABB, amount := 0.1) -> void:
	g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
		var clump := VoxelSdf.hash3(Vector3i((p / 0.6).floor()), 301)
		if clump > amount:
			return false
		var north := g.get_mat(c.x, c.y, c.z - 1) == 0
		var top := g.get_mat(c.x, c.y + 1, c.z) == 0
		return (north or top) and VoxelSdf.hash3(c, 303) < 0.6, Mat.LICHEN, [Mat.LIGHT, Mat.DARK, Mat.PALE, Mat.CAP])


# ---------------------------------------------------------------- Red Arch

## Laid strata slabs over the sim's arch footprint (two legs and a span from
## ShatteredMesaProps' boxes, 90 x 70 x 40 scaled, yaw 0.6): each 2.8 m band a
## planar slab, its edges set back or forward a cell per band, rust and
## salmon alternating, a dark caprock on the span, a stepped soffit, talus at
## the feet, lichen on the north face.
func _red_arch() -> void:
	var b := _arch.basis
	var sx := b.x.length()
	var sy := b.y.length()
	var sz := b.z.length()
	var yaw := atan2(b.x.z, b.x.x) * -1.0
	var base := _arch.origin - b.y * 0.5
	arch_base_y = base.y
	arch_centre = Vector3(base.x, base.y, base.z)
	arch_forward = b.z.normalized()
	var legs := [[-0.5 * sx, -0.34 * sx], [0.34 * sx, 0.5 * sx]]
	var leg_top := 0.8 * sy
	var span_lo := 0.72 * sy
	var span_hi := sy
	var leg_d := 0.08 * sz
	var span_d := 0.1 * sz
	var band := 2.8
	var paint_leg := func(g: VoxelGrid, x0: float, x1: float) -> void:
		var nb := ceili(leg_top / band) + 1
		for i in nb:
			var y0 := i * band
			var y1 := minf(y0 + band, leg_top + band * 0.6)
			# Flared foot, a waist, then wider again under the span.
			var t := y0 / leg_top
			var flare := 2.6 * pow(1.0 - t, 3.0) + 0.9 * pow(t, 4.0) - 0.4 * sin(t * PI)
			var j1 := (VoxelSdf.hash3(Vector3i(i, 1, int(x0)), 5) - 0.5) * 0.9
			var j2 := (VoxelSdf.hash3(Vector3i(i, 2, int(x0)), 5) - 0.5) * 0.9
			var j3 := (VoxelSdf.hash3(Vector3i(i, 3, int(x0)), 5) - 0.5) * 0.7
			var lo := Vector3(x0 - flare + j1, y0, -leg_d - flare * 0.6 + j3)
			var hi := Vector3(x1 + flare + j2, y1, leg_d + flare * 0.6 - j3)
			var mat := Mat.LIGHT if i % 2 == 0 else Mat.DARK
			if VoxelSdf.hash3(Vector3i(i, 7, 0), 9) > 0.8:
				mat = Mat.PALE
			var c := (lo + hi) * 0.5
			var h := (hi - lo) * 0.5
			g.paint(AABB(lo, hi - lo), func(p: Vector3) -> float: return VoxelSdf.box(p, c, h), mat)
			# Chipped corners: a few cells knocked out per band edge.
			g.paint(AABB(lo, hi - lo), func(p: Vector3) -> float:
				var e := minf(minf(p.x - lo.x, hi.x - p.x), minf(p.z - lo.z, hi.z - p.z))
				return -1.0 if e < 0.4 and VoxelSdf.hash3(Vector3i((p / 0.7).floor()), 13) < 0.3 else 1.0,
				0, -1, VoxelGrid.Mode.CARVE)
		_lichen(g, AABB(Vector3(x0 - 4, 0, -leg_d - 3), Vector3(x1 - x0 + 8, leg_top + 4, 2 * leg_d + 6)), 0.12)
	var paint_span := func(g: VoxelGrid) -> void:
		var nb := ceili((span_hi - span_lo) / band) + 1
		for i in nb:
			var y0 := span_lo + i * band - band
			var y1 := minf(y0 + band, span_hi)
			if y1 <= y0:
				continue
			var top := y1 >= span_hi - 0.01
			var reach := 0.55 * sx - (0.0 if i > 1 else 3.0) - (2.0 if top else 0.0)
			var jx := (VoxelSdf.hash3(Vector3i(i, 4, 0), 5) - 0.5) * 1.4
			var jz := (VoxelSdf.hash3(Vector3i(i, 5, 0), 5) - 0.5) * 0.8
			var d := span_d + jz + (0.35 if top else 0.0)
			var lo := Vector3(-reach + jx, y0, -d)
			var hi := Vector3(reach + jx * 0.5, y1, d)
			var mat := Mat.CAP if top else (Mat.DARK if i % 2 == 0 else Mat.LIGHT)
			var c := (lo + hi) * 0.5
			var h := (hi - lo) * 0.5
			# Soffit: the lowest bands step down only beside the legs (corbels).
			g.paint(AABB(lo, hi - lo), func(p: Vector3) -> float:
				if y0 < span_lo and absf(p.x) < 0.34 * sx - 2.0 * float(1 - i + 1):
					return 1.0
				return VoxelSdf.box(p, c, h), mat)
			g.paint(AABB(lo, hi - lo), func(p: Vector3) -> float:
				var e := minf(minf(p.x - lo.x, hi.x - p.x), minf(p.z - lo.z, hi.z - p.z))
				return -1.0 if e < 0.4 and VoxelSdf.hash3(Vector3i((p / 0.7).floor()), 17) < 0.3 else 1.0,
				0, -1, VoxelGrid.Mode.CARVE)
		_lichen(g, AABB(Vector3(-0.56 * sx, span_lo - 4, -span_d - 2), Vector3(1.12 * sx, span_hi - span_lo + 6,
			2 * span_d + 4)), 0.1)
	var xf := Transform3D(Basis(Vector3.UP, yaw), base)
	var leg_bounds := func(l: Array) -> AABB:
		return AABB(Vector3(l[0] - 5.0, 0, -leg_d - 4.0), Vector3(l[1] - l[0] + 10.0, leg_top + 3.0, 2.0 * leg_d + 8.0))
	for li in 2:
		var l: Array = legs[li]
		var bb: AABB = leg_bounds.call(l)
		var make := func() -> ArrayMesh: return _mesh("arch_leg%d" % li, bb, VoxelZone.T2,
			func(g: VoxelGrid) -> void: paint_leg.call(g, l[0], l[1]))
		VoxelProp.single(root, "ArchLeg%d" % li, _tiers(make, [1.0, 4.0]), [260.0, 0.0], xf)
	var sb := AABB(Vector3(-0.56 * sx, span_lo - band - 0.5, -span_d - 1.5), Vector3(1.12 * sx, span_hi - span_lo + band + 1.0,
		2.0 * span_d + 3.0))
	var make_span := func() -> ArrayMesh: return _mesh("arch_span", sb, VoxelZone.T2, paint_span)
	VoxelProp.single(root, "ArchSpan", _tiers(make_span, [1.0, 4.0]), [260.0, 0.0], xf)
	# Talus apron at both feet.
	var talus: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for l: Array in legs:
		for i in 26:
			var lx := lerpf(l[0] - 9.0, l[1] + 9.0, rng.randf())
			var lz := rng.randf_range(-12.0, 12.0)
			if absf(lz) < leg_d + 3.0 and lx > l[0] - 3.0 and lx < l[1] + 3.0:
				continue
			var w := xf * Vector3(lx, 0, lz)
			var s := rng.randf_range(0.35, 1.1)
			talus.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s),
				Vector3(w.x, ground(w.x, w.z) - 0.25 * s, w.z)))
	_place_boulders(talus, "ArchTalus")
	stats.arch_quads = 0


# ---------------------------------------------------------------- hoodoos

## Stacked octagonal drums: a wide base, bulges and necks, light and dark
## bands alternating per drum, a thin neck and a flat dark caprock hat.
func _hoodoo_paint(v: int) -> Callable:
	var hv: Vector2 = HOODOOS[v]
	return func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 900 + v
		var height := hv.x
		var r0 := hv.y
		var cap_h := rng.randf_range(2.2, 3.2)
		var neck_h := rng.randf_range(1.8, 3.0)
		var body := height - cap_h - neck_h
		var y := 0.0
		var i := 0
		while y < body:
			var dh := rng.randf_range(2.4, 5.2)
			var t := y / body
			var r := r0 * (1.0 - 0.32 * t) * (0.86 + 0.22 * rng.randf())
			if i % 3 == 2:
				r *= 0.82
			var ox := rng.randf_range(-0.3, 0.3)
			var oz := rng.randf_range(-0.3, 0.3)
			var y0 := y
			var y1 := minf(y + dh, body)
			var mat := Mat.LIGHT if i % 2 == 0 else Mat.DARK
			if rng.randf() < 0.15:
				mat = Mat.PALE
			var c := Vector3(ox, 0, oz)
			g.paint(AABB(Vector3(-r - 1 + ox, y0, -r - 1 + oz), Vector3(2 * r + 2, y1 - y0, 2 * r + 2)),
				func(p: Vector3) -> float: return maxf(octagon(p, c, r - (0.35 if p.y > y1 - 0.36 else 0.0)), maxf(y0 - p.y, p.y - y1)), mat)
			y = y1
			i += 1
		var nr := r0 * 0.38
		g.paint(AABB(Vector3(-nr - 1, body, -nr - 1), Vector3(2 * nr + 2, neck_h, 2 * nr + 2)),
			func(p: Vector3) -> float: return maxf(octagon(p, Vector3.ZERO, nr), maxf(body - p.y, p.y - body - neck_h)), Mat.DARK)
		var cr := r0 * rng.randf_range(0.95, 1.2)
		var cy := body + neck_h
		g.paint(AABB(Vector3(-cr - 1, cy, -cr - 1), Vector3(2 * cr + 2, cap_h, 2 * cr + 2)),
			func(p: Vector3) -> float: return maxf(octagon(p, Vector3(0.4, 0, -0.2), cr - (0.4 if p.y > cy + cap_h - 0.5 else 0.0)),
				maxf(cy - p.y, p.y - cy - cap_h)), Mat.CAP)
		_lichen(g, AABB(Vector3(-r0 - 2, 0, -r0 - 2), Vector3(2 * r0 + 4, height + 1, 2 * r0 + 4)), 0.08)


func _hoodoo_tiers(v: int) -> Array[ArrayMesh]:
	var hv: Vector2 = HOODOOS[v]
	var r := hv.y * 1.3 + 1.0
	var bounds := AABB(Vector3(-r, -0.1, -r), Vector3(2 * r, hv.x + 0.5, 2 * r))
	var paint := _hoodoo_paint(v)
	return _tiers(func() -> ArrayMesh: return _mesh("hoodoo%d" % v, bounds, VoxelZone.T2, paint), [1.0, 2.0, 4.0])


func _hoodoos() -> void:
	var lists: Array = []
	for v in HOODOOS.size():
		lists.append([] as Array[Transform3D])
	var best := INF
	for xf in _pillars:
		var r := xf.basis.x.length() * 0.5
		var h := xf.basis.y.length()
		var pick := 0
		var err := INF
		for v in HOODOOS.size():
			var hv: Vector2 = HOODOOS[v]
			var e := absf(log(h / hv.x)) + 0.6 * absf(log(r / hv.y))
			if e < err:
				err = e
				pick = v
		var hv: Vector2 = HOODOOS[pick]
		var basis := xf.basis * Basis.from_scale(Vector3(1.0 / (2.0 * hv.y), 1.0 / hv.x, 1.0 / (2.0 * hv.y)))
		var base := xf.origin - xf.basis.y * 0.5
		(lists[pick] as Array[Transform3D]).append(Transform3D(basis, base))
		# Hero: a mid-size hoodoo near the field's centre.
		var d := Vector2(base.x, base.z).distance_to(Vector2(560, 640)) + absf(h - 45.0)
		if d < best:
			best = d
			hoodoo_hero = Transform3D(basis, base)
			hoodoo_hero_r = r
	var quads := 0
	for v in HOODOOS.size():
		var list: Array[Transform3D] = lists[v]
		if list.is_empty():
			continue
		var tiers := _hoodoo_tiers(v)
		VoxelProp.place(root, "Hoodoos%d" % v, tiers, [110.0, 260.0, 0.0], list, 2)
		quads += VoxelProp.quads(tiers[0]) * list.size()
	stats.hoodoo_quads_t2 = quads
	_fallen_hoodoo()


## The destructible's "after" state: a hoodoo broken into drums across a dry
## wash, its cap lying upside down a few metres away.
func _fallen_hoodoo() -> void:
	var at := _find_floor(Vector2(610, 690), 40.0, 14.0)
	var dir := Vector2(0.8, -0.6)
	var paint := func(g: VoxelGrid) -> void:
		var x := -9.0
		for i in 5:
			var r := 2.6 - i * 0.22 + VoxelSdf.hash3(Vector3i(i, 0, 0), 3) * 0.3
			var len := 2.6 + VoxelSdf.hash3(Vector3i(i, 1, 0), 3) * 1.2
			var c := Vector3(x + len * 0.5, r - 0.6, (VoxelSdf.hash3(Vector3i(i, 2, 0), 3) - 0.5) * 1.6)
			var mat := Mat.LIGHT if i % 2 == 0 else Mat.DARK
			var roll := VoxelSdf.hash3(Vector3i(i, 3, 0), 3) * 0.6
			g.paint(AABB(c - Vector3(len, r + 1, r + 1), Vector3(2 * len, 2 * r + 2, 2 * r + 2)), func(p: Vector3) -> float:
				var q := p - c
				var yz := Vector2(q.y, q.z).rotated(roll)
				var o := Vector3(yz.x, 0, yz.y)
				return maxf(octagon(o, Vector3.ZERO, r), absf(q.x) - len * 0.5), mat)
			x += len + 0.5 + VoxelSdf.hash3(Vector3i(i, 4, 0), 3) * 1.4
		# The cap, upside down.
		var cc := Vector3(x + 3.5, 0.9, 2.5)
		g.paint(AABB(cc - Vector3(4, 1.5, 4), Vector3(8, 3, 8)), func(p: Vector3) -> float:
			return maxf(octagon(p, cc, 3.2 - (0.4 if p.y < cc.y - 0.6 else 0.0)), absf(p.y - cc.y) - 1.2), Mat.CAP)
		g.paint(AABB(cc - Vector3(2, -1, 2), Vector3(4, 1.4, 4)), func(p: Vector3) -> float:
			return maxf(octagon(p, cc, 1.3), absf(p.y - cc.y - 1.6) - 0.5), Mat.DARK)
		_lichen(g, AABB(Vector3(-10, -1, -5), Vector3(30, 8, 10)), 0.1)
	var m := _mesh("fallen_hoodoo", AABB(Vector3(-10, -1, -5), Vector3(30, 7, 10)), VoxelZone.T1 * 2.0, paint)
	_single(m, at, atan2(-dir.y, dir.x), -0.3)
	zone.set_meta("fallen_hoodoo", Vector3(at.x, ground(at.x, at.y), at.y))


# ---------------------------------------------------------------- boulders, talus, scrub

func _boulder_paint(v: int) -> Callable:
	return func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 500 + v
		# A planar block: a box with big chamfer cuts (random planes), chipped.
		var half := Vector3(2.8, 2.0, 2.4) * rng.randf_range(0.9, 1.05)
		var planes: Array = []
		for i in 7:
			var nrm := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1.0), rng.randf_range(-1, 1)).normalized()
			planes.append([nrm, rng.randf_range(0.55, 0.8) * (absf(nrm.x) * half.x + absf(nrm.y) * half.y + absf(nrm.z) * half.z)])
		var top_band := rng.randf_range(-0.3, 0.6)
		g.paint(AABB(-half - Vector3.ONE * 0.2, half * 2.0 + Vector3.ONE * 0.4), func(p: Vector3) -> float:
			var d := VoxelSdf.box(p, Vector3.ZERO, half)
			for pl: Array in planes:
				d = maxf(d, p.dot(pl[0]) - pl[1])
			return d, Mat.LIGHT)
		g.paint(AABB(-half - Vector3.ONE * 0.2, half * 2.0 + Vector3.ONE * 0.4), func(p: Vector3) -> float:
			return -1.0 if p.y > top_band and p.y < top_band + 1.0 else 1.0, Mat.DARK, -1, VoxelGrid.Mode.PAINT)
		g.paint(AABB(-half - Vector3.ONE * 0.2, half * 2.0 + Vector3.ONE * 0.4), func(p: Vector3) -> float:
			return -1.0 if VoxelSdf.hash3(Vector3i((p / 0.45).floor()), 41 + v) < 0.07 and p.y > -0.5 else 1.0,
			0, -1, VoxelGrid.Mode.CARVE)
		if v % 2 == 1:
			g.paint(AABB(-half - Vector3.ONE * 0.2, half * 2.0 + Vector3.ONE * 0.4), func(p: Vector3) -> float:
				return -1.0 if p.y < -half.y * 0.35 else 1.0, Mat.VARNISH, -1, VoxelGrid.Mode.PAINT)
		_lichen(g, AABB(-half - Vector3.ONE, half * 2.0 + Vector3.ONE * 2.0), 0.22)


var _boulder_meshes: Array = []


func _boulder_tiers(v: int) -> Array[ArrayMesh]:
	if _boulder_meshes.is_empty():
		var bounds := AABB(Vector3(-3.2, -2.4, -2.8), Vector3(6.4, 4.8, 5.6))
		for i in 4:
			var paint := _boulder_paint(i)
			_boulder_meshes.append(_tiers(func() -> ArrayMesh: return _mesh("boulder%d" % i, bounds, VoxelZone.T1 * 2.0, paint),
				[1.0, 2.0, 8.0]))
	return _boulder_meshes[v]


func _place_boulders(list: Array[Transform3D], node_name: String) -> void:
	var by: Array = [[], [], [], []]
	for i in list.size():
		var v := int(VoxelSdf.hash3(Vector3i(roundi(list[i].origin.x), 0, roundi(list[i].origin.z)), 7) * 3.999)
		(by[v] as Array).append(list[i])
	for v in 4:
		var l: Array[Transform3D] = []
		l.assign(by[v])
		if not l.is_empty():
			VoxelProp.place(root, "%s%d" % [node_name, v], _boulder_tiers(v), [55.0, 160.0, 0.0], l, 2)


func _boulder_field() -> void:
	var list: Array[Transform3D] = []
	for xf in _boulders:
		# Sim sphere (unit radius 0.5) scaled (1.4 s, s, 1.2 s); the design is 5.6 x 4 x 4.8 m.
		var b := xf.basis * Basis.from_scale(Vector3(1.0 / 5.6, 1.0 / 4.0, 1.0 / 4.8))
		list.append(Transform3D(b, xf.origin))
	_place_boulders(list, "Boulders")
	# Talus aprons at every free mesa's foot.
	var talus: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4243
	var c := zone.zone.centre
	for mesa: Array in TerrainShape.MESAS:
		var mc: Vector2 = c + mesa[0]
		var r: float = mesa[1]
		var placed := 0
		var tries := 0
		while placed < 70 and tries < 600:
			tries += 1
			var a := rng.randf() * TAU
			var d := r + rng.randf_range(6.0, 24.0)
			var p := mc + Vector2(cos(a), sin(a)) * d
			var g := ground(p.x, p.y)
			var floor_h := ground(mc.x + cos(a) * (r + 40.0), mc.y + sin(a) * (r + 40.0))
			if g > floor_h + 2.5 or _near_spawn(p, 12.0):
				continue
			var s := rng.randf_range(0.2, 0.75) * (1.3 - (d - r) / 30.0)
			talus.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.6, 1.0), s)),
				Vector3(p.x, g - 0.3 * s, p.y)))
			placed += 1
	_place_boulders(talus, "Talus")
	stats.talus = talus.size()


func _near_spawn(p: Vector2, r: float) -> bool:
	for s in zone.zone.spawn_points:
		if p.distance_to(Vector2(s.x, s.z)) < r:
			return true
	return false


## Sage bushes: clustered T1 blobs in two tones; dead trees: bleached forks.
func _scrub() -> void:
	var sage: Array = []
	for v in 4:
		var paint := func(g: VoxelGrid) -> void:
			var rng := RandomNumberGenerator.new()
			rng.seed = 700 + v
			for i in 5 + v:
				var c := Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(0.25, 0.6), rng.randf_range(-0.45, 0.45))
				var r := rng.randf_range(0.25, 0.42)
				g.paint(AABB(c - Vector3.ONE * r, Vector3.ONE * r * 2.0), func(p: Vector3) -> float:
					return VoxelSdf.ellipsoid(p, c, Vector3(r, r * 0.8, r)), Mat.SAGE if i % 2 == 0 else Mat.SAGE_DARK, -1,
					VoxelGrid.Mode.ADD)
			g.paint(AABB(Vector3(-0.1, 0, -0.1), Vector3(0.2, 0.3, 0.2)), func(p: Vector3) -> float:
				return VoxelSdf.box(p, Vector3(0, 0.15, 0), Vector3(0.06, 0.15, 0.06)), Mat.WOOD)
			g.paint_surface(AABB(Vector3(-1, 0, -1), Vector3(2, 1.2, 2)), func(p: Vector3, c: Vector3i) -> bool:
				return p.y > 0.55 and VoxelSdf.hash3(c, 9) < 0.35, Mat.SAND, [Mat.SAGE_DARK])
		var bounds := AABB(Vector3(-0.95, 0, -0.95), Vector3(1.9, 1.1, 1.9))
		sage.append(_tiers(func() -> ArrayMesh: return _mesh("sage%d" % v, bounds, VoxelZone.T1, paint), [1.0, 3.0]))
	var lists: Array = [[], [], [], []]
	var trees: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4244
	var c := zone.zone.centre
	var tries := 0
	var count := 0
	while count < 2600 and tries < 20000:
		tries += 1
		var p := c + Vector2(rng.randf_range(-320, 320), rng.randf_range(-440, 440))
		var g := ground(p.x, p.y)
		if g > 28.0 or _near_spawn(p, 10.0) or absf(ground(p.x + 2, p.y) - g) > 0.6 or absf(ground(p.x, p.y + 2) - g) > 0.6:
			continue
		var s := rng.randf_range(0.6, 1.5)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, g - 0.05, p.y))
		(lists[count % 4] as Array).append(xf)
		count += 1
		if count % 45 == 0:
			trees.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)),
				Vector3(p.x + 3.0, ground(p.x + 3.0, p.y) - 0.1, p.y)))
	for v in 4:
		var l: Array[Transform3D] = []
		l.assign(lists[v])
		VoxelProp.place(root, "Sage%d" % v, sage[v], [70.0, 170.0], l, 1)
	stats.scrub = count
	var tree_paint := func(g: VoxelGrid) -> void:
		var limbs := [[Vector3(0, 0, 0), Vector3(0.2, 2.0, 0.1), 0.2, 0.16], [Vector3(0.2, 2.0, 0.1), Vector3(-0.9, 3.6, 0.3), 0.14, 0.07],
			[Vector3(0.2, 2.0, 0.1), Vector3(1.1, 3.9, -0.4), 0.13, 0.06], [Vector3(-0.4, 2.8, 0.2), Vector3(-1.5, 3.3, 0.9), 0.07, 0.04],
			[Vector3(0.7, 3.0, -0.2), Vector3(1.6, 3.2, 0.5), 0.07, 0.04], [Vector3(0.1, 1.2, 0.0), Vector3(0.9, 1.7, 0.6), 0.08, 0.05]]
		for l: Array in limbs:
			var a: Vector3 = l[0]
			var b: Vector3 = l[1]
			g.paint(AABB(a.min(b) - Vector3.ONE * 0.3, (b - a).abs() + Vector3.ONE * 0.6), func(p: Vector3) -> float:
				return VoxelSdf.capsule(p, a, b, l[2], l[3]), Mat.WOOD)
	var tb := AABB(Vector3(-1.8, 0, -1.0), Vector3(3.6, 4.3, 2.2))
	var tree := _tiers(func() -> ArrayMesh: return _mesh("dead_tree", tb, VoxelZone.T1, tree_paint), [1.0, 3.0])
	VoxelProp.place(root, "DeadTrees", tree, [90.0, 220.0], trees, 1)
	stats.dead_trees = trees.size()


# ---------------------------------------------------------------- story props

func _single(m: ArrayMesh, at: Vector2, yaw: float, sink := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = Vector3(at.x, ground(at.x, at.y) + sink, at.y)
	mi.rotation.y = yaw
	mi.visibility_range_end = 400.0
	root.add_child(mi)
	return mi


## The nearest flat floor spot to `want` (within `reach`), clear by `clear` m.
func _find_floor(want: Vector2, reach: float, clear: float) -> Vector2:
	var best := want
	var best_d := INF
	for i in 400:
		var a := float(i) * 2.399
		var d := sqrt(float(i) / 400.0) * reach
		var p := want + Vector2(cos(a), sin(a)) * d
		var g := ground(p.x, p.y)
		var flat := true
		for o: Vector2 in [Vector2(clear, 0), Vector2(-clear, 0), Vector2(0, clear), Vector2(0, -clear)]:
			if absf(ground(p.x + o.x, p.y + o.y) - g) > 0.8:
				flat = false
		if flat and not _near_spawn(p, 14.0) and d < best_d:
			best_d = d
			best = p
	return best


func _story() -> void:
	_camp()
	_well()
	_petroglyphs()
	_cairns()


## The surveyor's camp on the Anvil Mesa: a canvas lean-to, a theodolite on a
## tripod aimed at the Red Arch, a barrel stencilled with the Banded Sun, a
## ledger weighed down by a stone on a crate, a lantern on the pole.
func _camp() -> void:
	var anvil := zone.zone.centre + TerrainShape.MESAS[4][0]
	var to_arch := (Vector2(arch_centre.x, arch_centre.z) - anvil).normalized()
	# Highest flat spot toward the arch.
	var best := anvil
	var best_h := -INF
	for i in 300:
		var a := float(i) * 2.399
		var d := sqrt(float(i) / 300.0) * 34.0
		var p := anvil + Vector2(cos(a), sin(a)) * d
		var g := ground(p.x, p.y)
		var flat := true
		for o: Vector2 in [Vector2(5, 0), Vector2(-5, 0), Vector2(0, 5), Vector2(0, -5)]:
			if absf(ground(p.x + o.x, p.y + o.y) - g) > 0.15:
				flat = false
		var score := g + p.distance_to(anvil) * 0.01 + (p - anvil).dot(to_arch) * 0.02
		if flat and score > best_h:
			best_h = score
			best = p
	camp_at = Vector3(best.x, ground(best.x, best.y), best.y)
	var yaw := atan2(to_arch.x, to_arch.y)
	var cell := VoxelZone.T1 * 0.5
	# Lean-to: two poles, a ridge, the canvas sloping back to pegs.
	var lean := func(g: VoxelGrid) -> void:
		for x: float in [-1.4, 1.4]:
			g.paint(AABB(Vector3(x - 0.1, 0, 0.9), Vector3(0.2, 2.0, 0.2)), func(p: Vector3) -> float:
				return VoxelSdf.box(p, Vector3(x, 0.95, 1.0), Vector3(0.05, 0.95, 0.05)), Mat.WOOD)
		g.paint(AABB(Vector3(-1.7, 1.8, 0.85), Vector3(3.4, 0.3, 0.3)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 1.9, 1.0), Vector3(1.65, 0.05, 0.05)), Mat.WOOD)
		g.paint(AABB(Vector3(-1.6, 0, -1.2), Vector3(3.2, 2.0, 2.3)), func(p: Vector3) -> float:
			var t := (p.z + 1.1) / 2.1
			var y := t * 1.88 + 0.04 * sin(p.x * 3.0)
			return maxf(absf(p.y - y) - 0.05, maxf(absf(p.x) - 1.55, absf(t - 0.5) - 0.5)), Mat.CANVAS)
		g.paint_surface(AABB(Vector3(-1.6, 0, -1.2), Vector3(3.2, 2.0, 2.3)), func(p: Vector3, c: Vector3i) -> bool:
			return fposmod(p.x + 1.55, 0.75) < 0.05, Mat.ROPE, [Mat.CANVAS])
		# A bedroll under it.
		g.paint(AABB(Vector3(-1, 0, -0.6), Vector3(2, 0.3, 1)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(-0.2, 0.1, -0.1), Vector3(0.8, 0.1, 0.32), 0.05), Mat.ROPE)
	var lm := _mesh("camp_leanto", AABB(Vector3(-1.8, -0.05, -1.3), Vector3(3.6, 2.2, 2.6)), cell, lean)
	var site := best + to_arch.orthogonal() * 2.8 - to_arch * 1.2
	_single(lm, site, yaw + PI, -0.02)
	# Theodolite on a tripod at T0, looking at the arch.
	var theo := func(g: VoxelGrid) -> void:
		for k in 3:
			var a := float(k) * TAU / 3.0
			var foot := Vector3(cos(a) * 0.42, 0, sin(a) * 0.42)
			g.paint(AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 1.32, 1)), func(p: Vector3) -> float:
				return VoxelSdf.capsule(p, foot, Vector3(0, 1.3, 0), 0.022, 0.018), Mat.WOOD)
		g.paint(AABB(Vector3(-0.12, 1.28, -0.12), Vector3(0.24, 0.08, 0.24)), func(p: Vector3) -> float:
			return VoxelSdf.cylinder(p, Vector3(0, 1.28, 0), Vector3(0, 1.34, 0), 0.1, 0.1), Mat.BRASS)
		g.paint(AABB(Vector3(-0.08, 1.34, -0.08), Vector3(0.16, 0.2, 0.16)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 1.42, 0), Vector3(0.06, 0.08, 0.05)), Mat.BRASS)
		g.paint(AABB(Vector3(-0.06, 1.44, -0.25), Vector3(0.12, 0.12, 0.5)), func(p: Vector3) -> float:
			return VoxelSdf.cylinder(p, Vector3(0, 1.5, -0.22), Vector3(0, 1.5, 0.2), 0.04, 0.035), Mat.IRON)
		g.paint(AABB(Vector3(-0.06, 1.44, 0.15), Vector3(0.12, 0.12, 0.1)), func(p: Vector3) -> float:
			return VoxelSdf.cylinder(p, Vector3(0, 1.5, 0.17), Vector3(0, 1.5, 0.22), 0.045, 0.045), Mat.BRASS)
	var tm := _mesh("camp_theodolite", AABB(Vector3(-0.5, -0.02, -0.5), Vector3(1, 1.65, 1)), VoxelZone.T0, theo)
	var tpos := best + to_arch * 2.2 + to_arch.orthogonal() * -0.6
	_single(tm, tpos, yaw, -0.02)
	# Barrel with the Banded Sun, crate with the ledger and its stone, lantern.
	var gear := func(g: VoxelGrid) -> void:
		g.paint(AABB(Vector3(-0.34, 0, -0.34), Vector3(0.68, 0.9, 0.68)), func(p: Vector3) -> float:
			var bulge := 0.29 + 0.03 * sin(clampf(p.y / 0.88, 0.0, 1.0) * PI)
			return maxf(Vector2(p.x, p.z).length() - bulge, maxf(-p.y, p.y - 0.88)), Mat.WOOD)
		g.paint_surface(AABB(Vector3(-0.4, 0, -0.4), Vector3(0.8, 0.9, 0.8)), func(p: Vector3, c: Vector3i) -> bool:
			return absf(p.y - 0.12) < 0.025 or absf(p.y - 0.76) < 0.025, Mat.IRON, [Mat.WOOD])
		# Banded Sun stencil on the +Z side: a disc split by three bars, four rays above.
		g.paint_surface(AABB(Vector3(-0.4, 0.2, 0.0), Vector3(0.8, 0.6, 0.45)), func(p: Vector3, c: Vector3i) -> bool:
			var q := Vector2(p.x, p.y - 0.44)
			var disc := q.length() < 0.11 and fposmod(q.y + 0.11, 0.073) > 0.022
			var ray := false
			for k in 4:
				var a := lerpf(0.5, PI - 0.5, float(k) / 3.0)
				var dir := Vector2(cos(a), sin(a))
				var t := q.dot(dir)
				ray = ray or (t > 0.14 and t < 0.21 and absf(q.cross(dir)) < 0.014)
			return p.z > 0.15 and (disc or ray), Mat.DARK, [Mat.WOOD])
		# Crate, ledger, stone.
		g.paint(AABB(Vector3(0.45, 0, -0.3), Vector3(0.7, 0.5, 0.6)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0.8, 0.22, 0.0), Vector3(0.3, 0.22, 0.25)), Mat.WOOD)
		g.paint_surface(AABB(Vector3(0.45, 0, -0.3), Vector3(0.7, 0.5, 0.6)), func(p: Vector3, c: Vector3i) -> bool:
			return fposmod(p.y, 0.15) < 0.025, Mat.CANVAS, [Mat.WOOD])
		g.paint(AABB(Vector3(0.6, 0.44, -0.2), Vector3(0.4, 0.06, 0.32)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0.8, 0.465, -0.04), Vector3(0.15, 0.022, 0.11)), Mat.LEDGER)
		g.paint(AABB(Vector3(0.6, 0.48, -0.1), Vector3(0.4, 0.06, 0.2)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0.8, 0.49, 0.0), Vector3(0.13, 0.004, 0.09)), Mat.CANVAS)
		g.paint(AABB(Vector3(0.65, 0.48, -0.15), Vector3(0.25, 0.15, 0.2)), func(p: Vector3) -> float:
			return VoxelSdf.ellipsoid(p, Vector3(0.76, 0.53, -0.06), Vector3(0.08, 0.05, 0.065)), Mat.LIGHT)
	var gm := _mesh("camp_gear", AABB(Vector3(-0.42, -0.02, -0.42), Vector3(1.6, 1.0, 0.85)), VoxelZone.T0, gear)
	_single(gm, best - to_arch * 0.6 + to_arch.orthogonal() * 0.9, yaw, -0.02)
	var lantern := func(g: VoxelGrid) -> void:
		g.paint(AABB(Vector3(-0.1, 0, -0.1), Vector3(0.2, 0.26, 0.2)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 0.12, 0), Vector3(0.07, 0.09, 0.07)), Mat.GLOW)
		g.paint(AABB(Vector3(-0.1, 0, -0.1), Vector3(0.2, 0.3, 0.2)), func(p: Vector3) -> float:
			var frame := absf(absf(p.x) - 0.075) < 0.012 and absf(absf(p.z) - 0.075) < 0.012
			var caps := absf(p.y - 0.02) < 0.02 or absf(p.y - 0.23) < 0.02
			return -1.0 if (frame or caps) and absf(p.x) < 0.09 and absf(p.z) < 0.09 and p.y < 0.26 else 1.0, Mat.IRON)
		g.paint(AABB(Vector3(-0.03, 0.24, -0.03), Vector3(0.06, 0.08, 0.06)), func(p: Vector3) -> float:
			return VoxelSdf.torus(p, Vector3(0, 0.28, 0), Vector3(1, 0, 0), 0.03, 0.008), Mat.IRON)
	var lt := _mesh("camp_lantern", AABB(Vector3(-0.1, -0.01, -0.1), Vector3(0.2, 0.34, 0.2)), VoxelZone.T0, lantern)
	var lmi := MeshInstance3D.new()
	lmi.mesh = lt
	var lp := Vector3(site.x, camp_at.y, site.y) + Basis(Vector3.UP, yaw + PI) * Vector3(1.4, 1.52, 1.05)
	lmi.position = lp
	root.add_child(lmi)
	zone.lantern_materials.append(VoxelProp.materials()[VoxelProp.Surf.GLOW] as ShaderMaterial)


## A stone-lined well on the floor: a ring of planar stones, a frayed rope
## over a cross-beam, a dented bucket on the rim, sand drifted on one side.
func _well() -> void:
	var at := _find_floor(Vector2(600, 560), 60.0, 4.0)
	var paint := func(g: VoxelGrid) -> void:
		for k in 12:
			var a0 := float(k) / 12.0 * TAU
			var h := 0.75 + VoxelSdf.hash3(Vector3i(k, 0, 0), 3) * 0.18
			var mat: int = [Mat.LIGHT, Mat.DARK, Mat.PALE][k % 3]
			g.paint(AABB(Vector3(-1.4, -0.3, -1.4), Vector3(2.8, 1.3, 2.8)), func(p: Vector3) -> float:
				var r := Vector2(p.x, p.z).length()
				var a := fposmod(atan2(p.z, p.x) - a0, TAU)
				var inside := a < TAU / 12.0 - 0.05
				return maxf(maxf(absf(r - 1.05) - 0.24, p.y - h), -p.y - 0.3) if inside else 1.0, mat)
		g.paint(AABB(Vector3(-0.85, -0.3, -0.85), Vector3(1.7, 0.2, 1.7)), func(p: Vector3) -> float:
			return maxf(Vector2(p.x, p.z).length() - 0.8, absf(p.y + 0.25) - 0.04), Mat.WATER)
		# Posts and cross-beam, rope down.
		for x: float in [-1.2, 1.2]:
			g.paint(AABB(Vector3(x - 0.1, 0, -0.1), Vector3(0.2, 1.9, 0.2)), func(p: Vector3) -> float:
				return VoxelSdf.box(p, Vector3(x, 0.9, 0), Vector3(0.07, 0.9, 0.07)), Mat.WOOD)
		g.paint(AABB(Vector3(-1.35, 1.7, -0.1), Vector3(2.7, 0.2, 0.2)), func(p: Vector3) -> float:
			return VoxelSdf.cylinder(p, Vector3(-1.3, 1.78, 0), Vector3(1.3, 1.78, 0), 0.07, 0.07), Mat.WOOD)
		g.paint(AABB(Vector3(-0.05, 0.3, -0.05), Vector3(0.1, 1.5, 0.1)), func(p: Vector3) -> float:
			return VoxelSdf.capsule(p, Vector3(0.1, 1.75, 0), Vector3(0.05, 0.4, 0), 0.02, 0.02), Mat.ROPE)
		# The bucket on the rim, dented, rope frayed at its handle.
		g.paint(AABB(Vector3(0.7, 0.8, 0.5), Vector3(0.5, 0.45, 0.5)), func(p: Vector3) -> float:
			var q := p - Vector3(0.95, 0.85, 0.75)
			var r := 0.17 + q.y * 0.12 - (0.03 if q.x > 0.1 and q.y > 0.1 else 0.0)
			var shell := maxf(Vector2(q.x, q.z).length() - r, maxf(-q.y, q.y - 0.3))
			var hollow := maxf(Vector2(q.x, q.z).length() - r + 0.03, maxf(0.03 - q.y, q.y - 0.4))
			return maxf(shell, -hollow), Mat.BUCKET)
		g.paint(AABB(Vector3(0.7, 0.8, 0.5), Vector3(0.5, 0.55, 0.5)), func(p: Vector3) -> float:
			return VoxelSdf.torus(p, Vector3(0.95, 1.15, 0.75), Vector3(0, 0, 1), 0.19, 0.012) if p.y > 1.14 else 1.0, Mat.IRON)
		# Sand drift against the west side.
		g.paint(AABB(Vector3(-2.2, -0.3, -1.6), Vector3(1.5, 0.9, 3.2)), func(p: Vector3) -> float:
			return VoxelSdf.ellipsoid(p, Vector3(-1.25, -0.15, 0), Vector3(1.0, 0.65, 1.5)), Mat.SAND, -1, VoxelGrid.Mode.ADD)
		_lichen(g, AABB(Vector3(-1.4, 0, -1.4), Vector3(2.8, 1, 2.8)), 0.18)
	var m := _mesh("well", AABB(Vector3(-2.3, -0.32, -1.7), Vector3(4.0, 2.25, 3.4)), VoxelZone.T1 * 0.5, paint)
	_single(m, at, 0.4, 0.0)
	zone.set_meta("well", Vector3(at.x, ground(at.x, at.y), at.y))


## A boulder near the Red Arch's west foot, its face pecked with an arch, a
## sun, two small figures, a spiral and the Banded Sun.
func _petroglyphs() -> void:
	var spot := Vector3(arch_centre.x, 0, arch_centre.z) + arch_forward * 16.0 - _arch.basis.x.normalized() * 30.0
	var at := Vector2(spot.x, spot.z)
	var paint := func(g: VoxelGrid) -> void:
		g.paint(AABB(Vector3(-1.9, -0.5, -1.3), Vector3(3.8, 3.0, 2.6)), func(p: Vector3) -> float:
			var d := VoxelSdf.box(p, Vector3(0, 0.9, 0), Vector3(1.75, 1.3, 1.1), 0.1)
			d = maxf(d, p.dot(Vector3(0.5, 0.8, -0.3).normalized()) - 1.6)
			d = maxf(d, p.dot(Vector3(-0.6, 0.7, 0.2).normalized()) - 1.5)
			return d, Mat.LIGHT)
		g.paint(AABB(Vector3(-1.9, -0.5, -1.3), Vector3(3.8, 3.0, 2.6)), func(p: Vector3) -> float:
			return -1.0 if p.y < 0.3 else 1.0, Mat.VARNISH, -1, VoxelGrid.Mode.PAINT)
		# Varnished face (+Z) with lighter pecked glyphs.
		g.paint_surface(AABB(Vector3(-1.9, 0.2, 0.6), Vector3(3.8, 2.4, 0.7)), func(p: Vector3, c: Vector3i) -> bool:
			return true, Mat.VARNISH, [Mat.LIGHT])
		g.paint_surface(AABB(Vector3(-1.9, 0.2, 0.6), Vector3(3.8, 2.4, 0.7)), func(p: Vector3, c: Vector3i) -> bool:
			var q := Vector2(p.x, p.y - 1.0)
			var w := 0.045
			# Arch: an upside-down U on the left.
			var au := q - Vector2(-1.05, 0.0)
			var arch := (absf(au.length() - 0.38) < w and au.y > 0.0) or (absf(absf(au.x) - 0.38) < w and au.y < 0.0 and au.y > -0.35)
			# Sun with rays, top right.
			var su := q - Vector2(0.9, 0.55)
			var sun := absf(su.length() - 0.17) < w
			for k in 8:
				var a := float(k) * TAU / 8.0
				var dd := Vector2(cos(a), sin(a))
				var t := su.dot(dd)
				sun = sun or (t > 0.25 and t < 0.38 and absf(su.cross(dd)) < w * 0.8)
			# Two small figures under the arch's right.
			var fig := false
			for f: float in [-0.25, 0.08]:
				var fu := q - Vector2(f, -0.25)
				fig = fig or (fu - Vector2(0, 0.32)).length() < 0.07 or (absf(fu.x) < w * 0.7 and fu.y > -0.05 and fu.y < 0.28)
				fig = fig or (absf(fu.y - 0.16) < w * 0.6 and absf(fu.x) < 0.14)
				fig = fig or (absf(absf(fu.x) - (-fu.y) * 0.6) < w * 0.8 and fu.y < -0.02 and fu.y > -0.28)
			# A spiral, bottom right.
			var sp := q - Vector2(0.95, -0.35)
			var ang := atan2(sp.y, sp.x)
			var rr := sp.length()
			var spiral := rr < 0.3 and absf(fposmod(rr - (ang + PI) / TAU * 0.09, 0.09) - 0.045) < w * 0.5
			# The Banded Sun: a disc split by three bars, four rays above.
			var bs := q - Vector2(0.3, 0.62)
			var band := bs.length() < 0.15 and fposmod(bs.y + 0.15, 0.1) > 0.035
			for k in 4:
				var a2 := lerpf(0.5, PI - 0.5, float(k) / 3.0)
				var d2 := Vector2(cos(a2), sin(a2))
				var t2 := bs.dot(d2)
				band = band or (t2 > 0.19 and t2 < 0.28 and absf(bs.cross(d2)) < w * 0.6)
			var peck := VoxelSdf.hash3(c, 5) < 0.85
			return peck and (arch or sun or fig or spiral or band), Mat.GLYPH, [Mat.VARNISH])
		_lichen(g, AABB(Vector3(-1.9, 1.5, -1.3), Vector3(3.8, 1.2, 2.6)), 0.3)
	var m := _mesh("petroglyph_boulder", AABB(Vector3(-2, -0.55, -1.4), Vector3(4, 3.1, 2.8)), VoxelZone.T1 * 0.5, paint)
	var face := atan2(arch_forward.x, arch_forward.z)
	_single(m, at, face, -0.1)
	zone.set_meta("petroglyphs", Vector3(at.x, ground(at.x, at.y), at.y))
	zone.set_meta("petroglyph_face", arch_forward)


## A cairn on every free mesa's top: a line guiding from the Great Mesa to the arch.
func _cairns() -> void:
	var tiers: Array = []
	for v in 2:
		var paint := func(g: VoxelGrid) -> void:
			var y := 0.0
			for i in 6 - v:
				var r := 0.42 - i * 0.055 + VoxelSdf.hash3(Vector3i(i, v, 0), 3) * 0.06
				var h := 0.16 + VoxelSdf.hash3(Vector3i(i, v, 1), 3) * 0.1
				var o := Vector3((VoxelSdf.hash3(Vector3i(i, v, 2), 3) - 0.5) * 0.12, 0, (VoxelSdf.hash3(Vector3i(i, v, 3), 3) - 0.5) * 0.12)
				var cy := y + h * 0.5
				var mat: int = [Mat.CAP, Mat.LIGHT, Mat.DARK, Mat.PALE][i % 4]
				g.paint(AABB(Vector3(-0.6, y, -0.6), Vector3(1.2, h + 0.05, 1.2)), func(p: Vector3) -> float:
					return VoxelSdf.box(p, o + Vector3(0, cy, 0), Vector3(r, h * 0.5, r * 0.8), 0.04), mat)
				y += h
			_lichen(g, AABB(Vector3(-0.6, 0, -0.6), Vector3(1.2, 1.5, 1.2)), 0.25)
		tiers.append(_mesh("cairn%d" % v, AABB(Vector3(-0.62, -0.02, -0.62), Vector3(1.24, 1.4, 1.24)), VoxelZone.T1 * 0.5, paint))
	var c := zone.zone.centre
	var spots: Array[Vector3] = []
	for i in TerrainShape.MESAS.size():
		var mesa: Array = TerrainShape.MESAS[i]
		var mc: Vector2 = c + mesa[0]
		var toward := (Vector2(arch_centre.x, arch_centre.z) - mc).normalized()
		var p: Vector2 = mc + toward * (mesa[1] * 0.45)
		var at := _find_top(p, mc)
		var mi := _single(tiers[i % 2], at, float(i) * 1.3, -0.02)
		spots.append(mi.position)
	zone.set_meta("cairns", spots)


## A flat spot on a mesa top near `want` (stays at the top's level).
func _find_top(want: Vector2, mc: Vector2) -> Vector2:
	var top := ground(mc.x, mc.y)
	for i in 200:
		var a := float(i) * 2.399
		var p := want + Vector2(cos(a), sin(a)) * sqrt(float(i)) * 1.2
		var g := ground(p.x, p.y)
		if absf(g - top) < 0.6 and absf(ground(p.x + 1.5, p.y) - g) < 0.1 and absf(ground(p.x, p.y + 1.5) - g) < 0.1:
			return p
	return mc


func animate(_t: float) -> void:
	pass
