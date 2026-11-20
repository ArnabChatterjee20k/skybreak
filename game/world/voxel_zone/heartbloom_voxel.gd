class_name HeartbloomVoxel
extends Node3D
## Heartbloom Gardens in the voxel style (docs/lookdev/heartbloom.md), look-dev
## v1. The sim stays the truth: island shapes come from IslandField.HEARTBLOOM
## and every prop position from HeartbloomProps (seed 5151), run as-is so the
## layout is identical; this only builds the voxel look over them.
##
## Cell tiers (the characters' ladder): T1 8.8 cm lawns and props, T2 35 cm
## arch core and undersides near the lip, T3 1.4 m deep undersides and the
## far islands' cones. v1 builds Heart Isle and Wishing Isle tops at T1, the
## other islands' tops at T2.

const T0 := 0.022
const T1 := 0.088
const T2 := 0.35
const T3 := 1.4
const LIP := 1.6
const TERRAIN_SHADER := preload("res://game/world/voxel_zone/voxel_terrain.gdshader")
## Bump to rebuild cached prop meshes after changing a design below.
const VERSION := 3
const FINE_ISLANDS := ["Heart Isle", "Wishing Isle"]

enum Mat {
	EMPTY, ROSE, ROSE_DARK, MORTAR, MOSS, GOLD, STONE, STONE_DARK, BARK, BARK_DARK,
	BLOSSOM, BLOSSOM_LIGHT, BLOSSOM_DEEP, WOOD, WOOD_NEW, POST, ROPE, PAPER, PAPER_BLUE, CAP,
	RIBBON, GRASS_A, GRASS_B, FLOWER_WHITE, FLOWER_YELLOW, SOIL, WATER,
}
## Palette (sRGB), from the design sheet.
const COLORS := {
	Mat.ROSE: Color("#d8bba8"), Mat.ROSE_DARK: Color("#c4a08f"), Mat.MORTAR: Color("#7d685d"),
	Mat.MOSS: Color("#6F8A58"), Mat.GOLD: Color("#d9b46a"),
	Mat.STONE: Color("#e2d3c3"), Mat.STONE_DARK: Color("#8f8178"),
	Mat.BARK: Color("#5C4A44"), Mat.BARK_DARK: Color("#3A2E2A"),
	Mat.BLOSSOM: Color("#efb3c4"), Mat.BLOSSOM_LIGHT: Color("#fbe1e8"), Mat.BLOSSOM_DEEP: Color("#c97d95"),
	Mat.WOOD: Color("#9C8468"), Mat.WOOD_NEW: Color("#c4ab86"), Mat.POST: Color("#8A4A40"),
	Mat.ROPE: Color("#cdb994"), Mat.PAPER: Color("#F0D2B0"), Mat.PAPER_BLUE: Color("#b9cfe0"),
	Mat.CAP: Color("#4a3a36"),
	Mat.RIBBON: Color("#d9849c"), Mat.GRASS_A: Color("#86a95a"), Mat.GRASS_B: Color("#6a9148"),
	Mat.FLOWER_WHITE: Color("#f5f1e6"), Mat.FLOWER_YELLOW: Color("#f0cf6a"), Mat.SOIL: Color("#5a4232"),
	Mat.WATER: Color("#9CCBCB"),
}
const LAWN := Color("#7FA85A")
const PETAL := Color("#F7CCD8")

var field: IslandField
var zone: ZoneData
var props: HeartbloomProps
## World (x, z) of the Heart Arch's foot and its ground height.
var arch_base := Vector2.ZERO
var arch_ground := 0.0
## Coarse (1 m) shade and petal maps under the canopies, for painting lawns.
var _shade := {}
var stats := {}
## Where the trees stand (instance transforms), and lanterns hung in the arch.
var tree_spots: Array[Transform3D] = []
var arch_lanterns: Array[Vector3] = []


func build() -> void:
	var t := Time.get_ticks_msec()
	field = IslandField.heartbloom()
	zone = load("res://game/world/zones/heartbloom_gardens.tres")
	props = _placements()
	var heart := field.index_of("Heart Isle")
	arch_base = field.centres[heart] + HeartbloomProps.ARCH_OFFSET
	arch_ground = field.surface_at(arch_base.x, arch_base.y)
	_canopy_maps()
	print("placements in %d ms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	_islands()
	print("islands in %d ms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	_arch()
	print("arch in %d ms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	_trees()
	print("trees in %d ms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	_bridges()
	_lanterns()
	_fountain()
	_clouds()
	_scatter()
	_rims_and_roots()
	_story_props()
	print("bridges, lanterns, fountain, clouds in %d ms" % (Time.get_ticks_msec() - t))


## Runs the sim's own prop builder to get its placements (it builds its
## grey-box meshes too; they're thrown away).
func _placements() -> HeartbloomProps:
	var p := HeartbloomProps.new()
	p.kit = PropKit.new(null, 0)
	p.zone = zone
	p.field = field
	p.rng.seed = HeartbloomProps.SEED
	var scratch := Node3D.new()
	p._build(scratch)
	scratch.free()
	return p


# ---------------------------------------------------------------- islands

## Shade (AO) and petal density on a 1 m grid under every canopy.
func _canopy_maps() -> void:
	for t in props.canopies:
		var c := t.origin
		var r := t.basis.get_scale().x * 0.55
		for gx in range(floori(c.x - r), ceili(c.x + r) + 1):
			for gz in range(floori(c.z - r), ceili(c.z + r) + 1):
				var d := Vector2(gx + 0.5 - c.x, gz + 0.5 - c.z).length() / r
				if d >= 1.0:
					continue
				var k := Vector2i(gx, gz)
				_shade[k] = maxf(_shade.get(k, 0.0), 1.0 - d)


func _islands() -> void:
	var quads := 0
	for i in field.size():
		var fine: bool = field.names[i] in FINE_ISLANDS
		var top := _island_top(i, T1 if fine else T2)
		quads += VoxelHeightfield.count_quads(top)
		var under := _island_underside(i, T2 if fine else T3)
		quads += VoxelHeightfield.count_quads(under)
	stats["terrain_quads"] = quads


func _island_bounds(i: int) -> Rect2:
	var r := field.radii[i] * 1.12
	var c := field.centres[i]
	return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)


func _island_top(i: int, cell: float) -> Node3D:
	var b := _island_bounds(i)
	var hf := VoxelHeightfield.new(cell, b.position, b.end)
	var paths := _paths(i)
	for z in hf.size.y:
		for x in hf.size.x:
			var w := hf.centre(x, z)
			var s := field.rim_fraction(i, w.x, w.y)
			if s > 1.0:
				continue
			var h := field.top_profile(i, s)
			var level := roundi(h / cell)
			hf.set_column(x, z, level, roundi((h - LIP) / cell), _lawn_colour(w, x, z, s, paths))
	hf.smooth_height = func(x: float, z: float) -> float:
		return field.top_profile(i, minf(field.rim_fraction(i, x, z), 1.0))
	var mat := _terrain_material(hf, i)
	return hf.build(self, mat, "%sTop" % field.names[i].replace(" ", ""))


func _island_underside(i: int, cell: float) -> Node3D:
	var b := _island_bounds(i)
	var hf := VoxelHeightfield.new(cell, b.position, b.end, true)
	for z in hf.size.y:
		for x in hf.size.x:
			var w := hf.centre(x, z)
			var s := field.rim_fraction(i, w.x, w.y)
			if s > 0.985:
				continue
			var bottom := roundi(field.underside_profile(i, s) / cell)
			var cap := roundi((field.top_profile(i, s) - LIP) / cell) + 1
			if bottom >= cap:
				continue
			hf.set_column(x, z, bottom, cap, Color.WHITE)
	var mat := _terrain_material(hf, i)
	return hf.build(self, mat, "%sUnder" % field.names[i].replace(" ", ""))


func _terrain_material(hf: VoxelHeightfield, i: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	hf.bind(mat)
	mat.set_shader_parameter("under_top", field.tops[i])
	mat.set_shader_parameter("under_depth", field.depths[i])
	# Cool grey-brown stone (pink is the accent, kept for blossoms and hearts).
	mat.set_shader_parameter("rock_color", Color("#a39588"))
	mat.set_shader_parameter("rock_shadow", Color("#6d6159"))
	mat.set_shader_parameter("soil_color", Color("#5a4232"))
	mat.set_shader_parameter("under_color", Color("#857a72"))
	mat.set_shader_parameter("under_deep", Color("#3a3432"))
	mat.set_shader_parameter("strata_cells", 3.0 if hf.cell > 0.2 else 8.0)
	return mat


## Flagstone walks on an island: (a, b, half width) segments.
func _paths(i: int) -> Array:
	var out := []
	if field.names[i] != "Heart Isle":
		return out
	var front := arch_base + Vector2(0, 10)
	# From the arch's front out to each bridge landing on Heart Isle.
	for pair: Array in HeartbloomProps.BRIDGES:
		if pair[0] != "Heart Isle":
			continue
		var b := field.index_of(pair[1])
		var dir := (field.centres[b] - field.centres[i]).normalized()
		var land := field.top_point(i, atan2(dir.y, dir.x), 0.92)
		out.append([front, Vector2(land.x, land.z), 1.5])
	# A short plaza in front of the arch.
	out.append([arch_base + Vector2(-6, 7), arch_base + Vector2(6, 7), 3.5])
	return out


## Lawn tones, light to deep: patches of each, by a two-scale value noise.
const GRASS: Array[Color] = [Color("#9cbb64"), Color("#86a95a"), Color("#749a4f"), Color("#5f8545")]


func _lawn_colour(w: Vector2, x: int, z: int, s: float, paths: Array) -> Color:
	var cell_id := Vector3i(x, 0, z)
	var h := VoxelSdf.hash3(cell_id, 11)
	var shade: float = _shade.get(Vector2i(floori(w.x), floori(w.y)), 0.0)
	# Flagstone walk: stones on a staggered grid, 1-cell dark joints, worn centre.
	for seg: Array in paths:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var hw: float = seg[2]
		var ab := b - a
		var t := clampf((w - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var off := w - (a + ab * t)
		var d := off.length()
		if d < hw + 0.2 * sin(t * 40.0):
			var u := t * ab.length() / 0.9
			var v := (off.dot(Vector2(-ab.y, ab.x).normalized()) + hw) / 0.75
			var row := floori(v)
			var uu := u + (0.5 if row % 2 == 1 else 0.0)
			var joint := fposmod(uu, 1.0) < 0.1 or fposmod(v, 1.0) < 0.12
			var flag := VoxelSdf.hash3(Vector3i(floori(uu), row, 3), 5)
			var stone := COLORS[Mat.STONE] * (0.9 + 0.16 * flag)
			stone = stone.lerp(stone.lightened(0.12), 1.0 - d / hw)
			if joint:
				stone = COLORS[Mat.MOSS] if h > 0.35 else COLORS[Mat.STONE_DARK]
			return _ao(stone, shade)
	# Grass: four tones in soft patches (big and small scale), slightly yellower
	# toward the sunny rim, a touch of per-cell variation.
	var n1 := sin(w.x * 0.11 + w.y * 0.07) + sin(w.x * 0.05 - w.y * 0.13 + 1.3)
	var n2 := sin(w.x * 0.47 + 2.1) * sin(w.y * 0.39 - 0.7)
	var tone := clampf(0.5 + n1 * 0.25 + n2 * 0.22 + (h - 0.5) * 0.25, 0.0, 0.999)
	var k := tone * 3.0
	var c := GRASS[int(k)].lerp(GRASS[mini(int(k) + 1, 3)], fposmod(k, 1.0))
	c = c.lerp(Color("#a9b865"), smoothstep(0.75, 1.0, s) * 0.3)
	# Petal drifts: under the canopies, thinning out downwind in streaks.
	var drift := shade * shade
	var streak := 0.5 + 0.5 * sin(w.x * 1.7 + w.y * 0.9)
	if VoxelSdf.hash3(cell_id, 23) < drift * (0.35 + 0.4 * streak) + 0.002:
		return _ao(PETAL.lerp(Color("#fde6ec"), VoxelSdf.hash3(cell_id, 31) * 0.5), shade * 0.4)
	# Clover and tiny flowers in clumps.
	var clump := sin(w.x * 0.9) * sin(w.y * 1.1)
	if clump > 0.75 and h < 0.12:
		return _ao(Color("#f3efe2") if h < 0.08 else Color("#eed58a"), shade)
	if clump < -0.8 and h < 0.25:
		return _ao(Color("#6f9a4c"), shade)  # clover leaves, a deeper green
	return _ao(c * (0.97 + 0.06 * VoxelSdf.hash3(cell_id, 29)), shade)


## Baked shade under canopies (up to 35% darker, a little cooler).
static func _ao(c: Color, shade: float) -> Color:
	var k := 1.0 - 0.35 * shade
	return Color(c.r * k * (1.0 - 0.04 * shade), c.g * k, c.b * k * (1.0 + 0.05 * shade), 0.0)


# ---------------------------------------------------------------- shared colouring

func color(mat: int, p: Vector3, c: Vector3i, n: Vector3, occlusion: float, exposure: float) -> Color:
	var base: Color = COLORS.get(mat, Color.MAGENTA)
	var quiet := mat in [Mat.ROSE, Mat.STONE, Mat.MORTAR]
	var col := VoxelDesign.default_color(base, mat, c, occlusion, exposure, quiet,
		mat in [Mat.ROSE, Mat.STONE, Mat.WOOD, Mat.POST, Mat.GOLD, Mat.CAP])
	if mat in [Mat.BLOSSOM, Mat.BLOSSOM_LIGHT, Mat.BLOSSOM_DEEP]:
		# Sunlit tops lighter, undersides a little deeper: from height in the cluster.
		col = col.lerp(COLORS[Mat.BLOSSOM_LIGHT], exposure * 0.6)
		col = col.lerp(COLORS[Mat.BLOSSOM_DEEP] * 0.85, clampf(occlusion * 1.4, 0.0, 0.8))
		if n.y < -0.5:
			col = col.lerp(COLORS[Mat.BLOSSOM_DEEP] * 0.8, 0.5)
	return col


func surface_of(mat: int) -> int:
	match mat:
		Mat.GOLD:
			return 1
		Mat.BLOSSOM, Mat.BLOSSOM_LIGHT, Mat.BLOSSOM_DEEP:
			return 3
		Mat.PAPER, Mat.PAPER_BLUE:
			return 4
		Mat.WATER:
			return 2
		Mat.BARK, Mat.BARK_DARK:
			return 5
	return 0


# ---------------------------------------------------------------- Heart Arch

## Laid voussoirs along the heart curve (T2): two courses (inner and outer
## ring) of slightly irregular blocks, joints staggered between the courses,
## weathered cream-rose sandstone in three tints, mortar joints with moss, a
## blossom vine climbing the right lobe, ribbons near the feet, the keystone
## with a gold heart on both faces, and a two-step pedestal.
func _arch() -> void:
	var scale := HeartbloomProps.ARCH_HEIGHT / 29.5
	var lift := 17.0 * scale + 2.2
	var half_in := 2.7
	var half_depth := 3.2
	var bounds := AABB(Vector3(-29, -1, -4.6), Vector3(58, 50, 9.2))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 2626
		for half: float in [1.0, -1.0]:
			var pts := PackedVector2Array()
			var steps := 72
			for k in steps + 1:
				var t := lerpf(0.03, PI - 0.03, float(k) / steps)
				var hp := HeartbloomProps.heart_point(t) * scale
				pts.append(Vector2(hp.x * half, hp.y + lift))
			# Block boundaries along the curve, 1.5-2.1 m apart.
			var total := 0.0
			for k in steps:
				total += pts[k].distance_to(pts[k + 1])
			var cuts := PackedFloat32Array([0.0])
			while cuts[-1] < total:
				cuts.append(cuts[-1] + rng.randf_range(1.5, 2.1))
			var arc := 0.0
			for k in steps:
				var a := pts[k]
				var b := pts[k + 1]
				var seg_len := a.distance_to(b)
				var arc0 := arc
				var lo := Vector3(minf(a.x, b.x) - half_in - 0.5, minf(a.y, b.y) - half_in - 0.5, -half_depth - 0.5)
				var hi := Vector3(maxf(a.x, b.x) + half_in + 0.5, maxf(a.y, b.y) + half_in + 0.5, half_depth + 0.5)
				var box := AABB(lo, hi - lo)
				var ab := b - a
				var nrm := Vector2(-ab.y, ab.x).normalized()
				# (arc length, signed offset across the tube) of a point.
				var frame := func(p: Vector3) -> Vector2:
					var q := Vector2(p.x, p.y)
					var h := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
					return Vector2(arc0 + h * seg_len, (q - (a + ab * h)).dot(nrm))
				g.paint(box, func(p: Vector3) -> float:
					var q := Vector2(p.x, p.y)
					var h := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
					return maxf((q - (a + ab * h)).length() - half_in, absf(p.z) - half_depth), Mat.ROSE)
				# Which block (course, index) a point is in, and how far from its joint.
				var block := func(p: Vector3) -> Vector3:
					var f: Vector2 = frame.call(p)
					var course := 0 if f.y < 0.0 else 1
					var along := f.x + (0.9 if course == 1 else 0.0)
					var idx := cuts.bsearch(along) - 1
					var from_joint := minf(along - cuts[maxi(idx, 0)], cuts[mini(idx + 1, cuts.size() - 1)] - along)
					return Vector3(course, idx, from_joint)
				for tint: int in [Mat.ROSE_DARK, Mat.STONE]:
					g.paint_surface(box, func(p: Vector3, _c: Vector3i) -> bool:
						var bl: Vector3 = block.call(p)
						var hsh := VoxelSdf.hash3(Vector3i(int(bl.x), int(bl.y), roundi(half)), 13)
						return (hsh < 0.3) if tint == Mat.ROSE_DARK else (hsh > 0.8), tint, [Mat.ROSE])
				# Joints (mortar, about a third grown over with moss).
				var joint := func(p: Vector3) -> bool:
					var bl: Vector3 = block.call(p)
					var f: Vector2 = frame.call(p)
					return bl.z < T2 * 0.75 or (absf(f.y) < T2 * 0.6 and absf(p.z) > half_depth - T2)
				g.paint_surface(box, func(p: Vector3, c: Vector3i) -> bool:
					return joint.call(p) and VoxelSdf.hash3(c, 41) >= 0.35, Mat.MORTAR, [Mat.ROSE, Mat.ROSE_DARK, Mat.STONE])
				g.paint_surface(box, func(p: Vector3, c: Vector3i) -> bool:
					return joint.call(p) and VoxelSdf.hash3(c, 41) < 0.35, Mat.MOSS, [Mat.ROSE, Mat.ROSE_DARK, Mat.STONE])
				arc += seg_len
		# Blossom vine climbing the right lobe's outside.
		var vine := PackedVector3Array()
		for k in 15:
			var t := lerpf(1.95, 1.0, float(k) / 14.0)
			var hp := HeartbloomProps.heart_point(t) * scale
			var out := Vector2(hp.x, hp.y - 2.0).normalized()
			vine.append(Vector3(hp.x + out.x * (half_in + 0.3), hp.y + lift + out.y * (half_in + 0.3), half_depth * 0.6 + sin(k) * 0.5))
		for k in vine.size() - 1:
			var va := vine[k]
			var vb := vine[k + 1]
			g.paint(AABB(Vector3(minf(va.x, vb.x), minf(va.y, vb.y), minf(va.z, vb.z)) - Vector3.ONE * 0.6,
				(vb - va).abs() + Vector3.ONE * 1.2), func(p: Vector3) -> float:
				return VoxelSdf.capsule(p, va, vb, 0.2, 0.2), Mat.MOSS, -1, VoxelGrid.Mode.ADD)
			if k % 2 == 0:
				var r := rng.randf_range(0.6, 1.0)
				g.paint(AABB(va - Vector3.ONE * (r + 0.2), Vector3.ONE * (r * 2 + 0.4)), func(p: Vector3) -> float:
					return VoxelSdf.ellipsoid(p, va, Vector3(r, r * 0.8, r)), Mat.BLOSSOM, -1, VoxelGrid.Mode.ADD)
		# Ribbons tied round both feet of the arch.
		for half: float in [1.0, -1.0]:
			var foot := HeartbloomProps.heart_point(PI - 0.35) * scale
			var c := Vector3(foot.x * half, foot.y + lift, 0)
			g.paint_surface(AABB(c - Vector3(4, 1.2, 4), Vector3(8, 2.4, 8)), func(p: Vector3, _c: Vector3i) -> bool:
				return absf(p.y - c.y + (p.x - c.x) * 0.25) < T2 * 0.8, Mat.RIBBON, [Mat.ROSE, Mat.ROSE_DARK, Mat.STONE, Mat.MORTAR, Mat.MOSS])
		# Keystone, its gold heart on both faces, the pedestal.
		var cusp := HeartbloomProps.heart_point(0.0) * scale
		var key_c := Vector3(0, cusp.y + lift + 0.6, 0)
		var diamond := func(p: Vector3, hb: Vector3) -> float:
			var q := p - key_c
			var r := Vector3((q.x + q.y) * 0.7071, (q.y - q.x) * 0.7071, q.z)
			return VoxelSdf.box(r, Vector3.ZERO, hb)
		g.paint(AABB(key_c - Vector3(4, 4, 4), Vector3(8, 8, 8)), func(p: Vector3) -> float:
			return diamond.call(p, Vector3(2.6, 2.6, 3.4)), Mat.STONE, -1, VoxelGrid.Mode.FILL)
		g.paint(AABB(key_c - Vector3(2.5, 2.5, 4), Vector3(5, 5, 8)), func(p: Vector3) -> float:
			var q := Vector2(p.x - key_c.x, p.y - key_c.y + 0.3) / 1.9
			# Heart: two circles over a point.
			var heart := minf(Vector2(q.x - 0.5, q.y - 0.25).length(), Vector2(q.x + 0.5, q.y - 0.25).length()) - 0.55
			heart = minf(heart, maxf(absf(q.x) + q.y * 0.9 - 0.75, -q.y - 1.1))
			return maxf(heart, absf(p.z) - 3.55), Mat.GOLD, -1, VoxelGrid.Mode.FILL)
		g.paint(AABB(Vector3(-7.2, -0.6, -5.2), Vector3(14.4, 1.6, 10.4)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 0.2, 0), Vector3(7.0, 0.7, 5.0)), Mat.STONE, -1, VoxelGrid.Mode.FILL)
		g.paint(AABB(Vector3(-4.7, 0.5, -3.7), Vector3(9.4, 1.6, 7.4)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 1.4, 0), Vector3(4.5, 0.7, 3.5)), Mat.STONE, -1, VoxelGrid.Mode.FILL)
		g.paint_surface(AABB(Vector3(-7.2, -0.6, -5.2), Vector3(14.4, 2.8, 10.4)), func(p: Vector3, c: Vector3i) -> bool:
			return p.y < 0.5 and VoxelSdf.hash3(c, 43) < 0.3, Mat.MOSS, [Mat.STONE])
	var m := VoxelProp.mesh("hb_arch", VERSION, bounds, T2, paint, color, surface_of)
	var node := MeshInstance3D.new()
	node.name = "HeartArch"
	node.mesh = m
	node.position = Vector3(arch_base.x, arch_ground, arch_base.y)
	add_child(node)
	stats["arch_quads"] = _quads(m)
	# A lantern hanging inside each lobe.
	for half: float in [1.0, -1.0]:
		var top := HeartbloomProps.heart_point(1.0) * scale
		arch_lanterns.append(node.position + Vector3(top.x * half * 0.85, top.y + lift - half_in - 2.2, 0))


# ---------------------------------------------------------------- trees

## Four blossom-tree variants at T1: a gnarled, tapering trunk (a bent capsule
## chain) on root flares, limbs that fork on the way to each cluster, and a
## canopy of lumpy blossom masses with carved gaps the limbs show through.
## Colour: deep rose in the canopy's core, pale tips where it's exposed.
func _trees() -> void:
	var variants: Array[ArrayMesh] = []
	var far: Array[ArrayMesh] = []
	for v in 4:
		variants.append(_tree_mesh(v, T1))
		far.append(_tree_mesh(v, T2))
	var per_variant: Array = [[], [], [], []]
	for k in props.trunks.size():
		var t := props.trunks[k]
		var sc := t.basis.get_scale()
		var ground := t.origin + Vector3.UP * 0.5
		ground.y = field.surface_at(ground.x, ground.z, ground.y + 3.0) if is_finite(field.surface_at(ground.x, ground.z, ground.y + 3.0)) else ground.y
		var size := (sc.y - 0.5) / 7.0
		var yaw := VoxelSdf.hash3(Vector3i(roundi(ground.x), 0, roundi(ground.z)), 5) * TAU
		var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size), ground)
		(per_variant[k % 4] as Array).append(xf)
		tree_spots.append(xf)
	var quads := 0
	for v in 4:
		var list: Array[Transform3D] = []
		list.assign(per_variant[v])
		VoxelProp.instances(self, "Trees%d" % v, variants[v], list, 90.0)
		var far_node := VoxelProp.instances(self, "TreesFar%d" % v, far[v], list)
		far_node.visibility_range_begin = 90.0
		quads += _quads(variants[v]) * list.size()
	stats["tree_quads_t1_all"] = quads
	stats["tree_variant_quads"] = _quads(variants[0])


func _tree_mesh(v: int, cell: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + v
	var h := 7.0
	# Trunk: 4 joints with bends, ending at the crown.
	var trunk := PackedVector3Array([Vector3(0, -0.4, 0)])
	var lean := Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
	for k in range(1, 5):
		var f := float(k) / 4.0
		trunk.append(Vector3(lean.x * f + rng.randf_range(-0.25, 0.25), h * 0.6 * f, lean.y * f + rng.randf_range(-0.25, 0.25)))
	var top := trunk[-1]
	var clusters: Array[Vector4] = []
	var count := 5 + v % 3
	for k in count:
		var a := TAU * k / count + rng.randf_range(-0.4, 0.4)
		var out := rng.randf_range(1.6, 2.8)
		clusters.append(Vector4(cos(a) * out, h * rng.randf_range(0.72, 0.92), sin(a) * out, rng.randf_range(1.4, 2.0)))
	clusters.append(Vector4(top.x, h * 0.98, top.z, 1.8))
	var bounds := AABB(Vector3(-5.8, -0.6, -5.8), Vector3(11.6, 10.6, 11.6))
	var paint := func(g: VoxelGrid) -> void:
		var cap := func(a: Vector3, b: Vector3, ra: float, rb: float, mat: int) -> void:
			var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z)) - Vector3.ONE * (ra + 0.1)
			g.paint(AABB(lo, (b - a).abs() + Vector3.ONE * (ra + 0.1) * 2), func(p: Vector3) -> float:
				return VoxelSdf.capsule(p, a, b, ra, rb), mat, -1, VoxelGrid.Mode.ADD)
		for k in trunk.size() - 1:
			var f := float(k) / (trunk.size() - 1)
			cap.call(trunk[k], trunk[k + 1], lerpf(0.5, 0.26, f), lerpf(0.44, 0.22, f), Mat.BARK)
		# Root flares, half sunk into the lawn.
		for k in 5:
			var a := TAU * k / 5.0 + rng.randf_range(-0.3, 0.3)
			var len := rng.randf_range(0.9, 1.5)
			cap.call(Vector3(0, 0.35, 0), Vector3(cos(a) * len, -0.15, sin(a) * len), 0.3, 0.08, Mat.BARK)
		# Limbs: to a fork point, then a branch to each cluster near it.
		for c4 in clusters:
			var c := Vector3(c4.x, c4.y, c4.z)
			var fork := top.lerp(c, 0.5) + Vector3(rng.randf_range(-0.3, 0.3), 0.3, rng.randf_range(-0.3, 0.3))
			cap.call(top, fork, 0.22, 0.15, Mat.BARK)
			cap.call(fork, c * 0.9, 0.14, 0.07, Mat.BARK)
			var side := fork + (c - fork).rotated(Vector3.UP, 0.7) * 0.7
			cap.call(fork, side, 0.11, 0.05, Mat.BARK)
		# Bark: dark grooves twisting round the trunk.
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return fposmod(atan2(p.z, p.x) * 2.5 + p.y * 0.6, 1.0) < 0.2, Mat.BARK_DARK, [Mat.BARK])
		# Blossom masses: 10 lumps per cluster.
		for c4 in clusters:
			var c := Vector3(c4.x, c4.y, c4.z)
			var r := c4.w
			var lumps: Array[Vector4] = [Vector4(c.x, c.y, c.z, r * 0.8)]
			for j in 9:
				var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.5), rng.randf_range(-1, 1)).normalized()
				var lc := c + d * r * rng.randf_range(0.6, 0.95)
				lumps.append(Vector4(lc.x, lc.y, lc.z, r * rng.randf_range(0.32, 0.55)))
			for l in lumps:
				var lc := Vector3(l.x, l.y, l.z)
				g.paint(AABB(lc - Vector3.ONE * (l.w + 0.2), Vector3.ONE * (l.w * 2 + 0.4)), func(p: Vector3) -> float:
					return VoxelSdf.ellipsoid(p, lc, Vector3(l.w, l.w * 0.8, l.w)), Mat.BLOSSOM, -1, VoxelGrid.Mode.ADD)
		# Gaps: pockets carved into the masses so the limbs show through.
		for c4 in clusters:
			for j in 6:
				var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.9, 0.3), rng.randf_range(-1, 1)).normalized()
				var hc := Vector3(c4.x, c4.y, c4.z) + d * c4.w * 0.95
				var hr := c4.w * rng.randf_range(0.28, 0.42)
				g.paint(AABB(hc - Vector3.ONE * hr, Vector3.ONE * hr * 2), func(p: Vector3) -> float:
					return VoxelSdf.sphere(p, hc, hr), Mat.BLOSSOM, -1, VoxelGrid.Mode.CARVE)
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool:
			return VoxelSdf.hash3(c, 61) < 0.2, Mat.BLOSSOM_LIGHT, [Mat.BLOSSOM])
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool:
			return VoxelSdf.hash3(c, 67) < 0.12, Mat.BLOSSOM_DEEP, [Mat.BLOSSOM])
	return VoxelProp.mesh("hb_tree%d_%s" % [v, "t1" if cell < 0.1 else "t2"], VERSION, bounds, cell, paint, color,
		surface_of, [Mat.BLOSSOM])


# ---------------------------------------------------------------- lawn scatter

## Small things that give the lawn its scales: grass tufts, flower clumps,
## scattered stones, edging stones along the walks; on the T1 islands only,
## clear of paths, plazas and trunks.
func _scatter() -> void:
	var tufts: Array = [[], [], []]
	var flowers: Array = [[], []]
	var stones: Array = [[], [], []]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var fc: Vector3 = zone.get_meta("wishing_fountain").centre
	for name: String in FINE_ISLANDS:
		var i := field.index_of(name)
		var paths := _paths(i)
		var area := PI * field.radii[i] * field.radii[i]
		for k in int(area / 3.0):
			var p := _random_on(i, rng, 0.97)
			if _on_path(p, paths, 0.6) or Vector2(p.x, p.z).distance_to(Vector2(fc.x, fc.z)) < 8.0:
				continue
			if Vector2(p.x, p.z).distance_to(arch_base) < 8.0:
				continue
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), p)
			var roll := rng.randf()
			if roll < 0.8:
				(tufts[k % 3] as Array).append(xf)
			elif roll < 0.97:
				(flowers[k % 2] as Array).append(xf)
			else:
				(stones[k % 3] as Array).append(Transform3D(xf.basis.scaled(Vector3.ONE * rng.randf_range(0.8, 1.6)), p + Vector3.DOWN * 0.06))
		# Edging stones along both sides of every walk.
		for seg: Array in paths:
			var a: Vector2 = seg[0]
			var b: Vector2 = seg[1]
			var hw: float = seg[2]
			var dir := (b - a).normalized()
			var side := Vector2(-dir.y, dir.x)
			var n := int(a.distance_to(b) / 1.1)
			for k in n:
				for sgn: float in [-1.0, 1.0]:
					var w := a.lerp(b, (k + 0.5) / n) + side * sgn * (hw + 0.25)
					var y := field.surface_at(w.x, w.y)
					if is_finite(y):
						(stones[k % 3] as Array).append(Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y) + rng.randf_range(-0.3, 0.3))
							.scaled(Vector3(0.7, 0.55, 0.9)), Vector3(w.x, y - 0.05, w.y)))
	for v in 3:
		_place(_tuft_mesh(v), tufts[v], "Tufts%d" % v, 55.0)
		_place(_stone_mesh(v), stones[v], "Stones%d" % v, 120.0)
	for v in 2:
		_place(_flower_mesh(v), flowers[v], "Flowers%d" % v, 45.0)
	stats["scatter"] = tufts.reduce(func(acc, l): return acc + l.size(), 0) + flowers.reduce(func(acc, l): return acc + l.size(), 0) \
		+ stones.reduce(func(acc, l): return acc + l.size(), 0)


func _place(m: ArrayMesh, list: Array, node_name: String, end: float) -> void:
	var typed: Array[Transform3D] = []
	typed.assign(list)
	var node := VoxelProp.instances(self, node_name, m, typed, end)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if end < 60.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _random_on(i: int, rng: RandomNumberGenerator, s_max: float) -> Vector3:
	var p := field.top_point(i, rng.randf() * TAU, sqrt(rng.randf()) * s_max)
	p.y = field.surface_at(p.x, p.z)
	return p


func _on_path(p: Vector3, paths: Array, margin: float) -> bool:
	for seg: Array in paths:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var w := Vector2(p.x, p.z)
		var ab := b - a
		var t := clampf((w - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if (w - (a + ab * t)).length() < float(seg[2]) + margin:
			return true
	return false


func _tuft_mesh(v: int) -> ArrayMesh:
	var bounds := AABB(Vector3(-0.35, -0.05, -0.35), Vector3(0.7, 0.55, 0.7))
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + v
	var paint := func(g: VoxelGrid) -> void:
		for k in 7:
			var base := Vector3(rng.randf_range(-0.18, 0.18), 0, rng.randf_range(-0.18, 0.18))
			var tip := base + Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.22, 0.42), rng.randf_range(-0.15, 0.15))
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, base, tip, 0.03, 0.012),
				Mat.GRASS_A if k % 3 else Mat.GRASS_B, -1, VoxelGrid.Mode.ADD)
	return VoxelProp.mesh("hb_tuft%d" % v, VERSION, bounds, T0 * 1.5, paint, color, surface_of)


func _flower_mesh(v: int) -> ArrayMesh:
	var bounds := AABB(Vector3(-0.3, -0.05, -0.3), Vector3(0.6, 0.35, 0.6))
	var rng := RandomNumberGenerator.new()
	rng.seed = 600 + v
	var petal := Mat.FLOWER_WHITE if v == 0 else Mat.FLOWER_YELLOW
	var paint := func(g: VoxelGrid) -> void:
		for k in 5:
			var base := Vector3(rng.randf_range(-0.18, 0.18), 0, rng.randf_range(-0.18, 0.18))
			var head := base + Vector3(0, rng.randf_range(0.12, 0.24), 0)
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, base, head, 0.012, 0.012), Mat.GRASS_B)
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.ellipsoid(p, head, Vector3(0.05, 0.025, 0.05)), petal, -1, VoxelGrid.Mode.ADD)
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.sphere(p, head + Vector3(0, 0.02, 0), 0.018), Mat.FLOWER_YELLOW if v == 0 else Mat.CAP, -1, VoxelGrid.Mode.ADD)
	return VoxelProp.mesh("hb_flower%d" % v, VERSION, bounds, T0, paint, color, surface_of)


func _stone_mesh(v: int) -> ArrayMesh:
	var bounds := AABB(Vector3(-0.6, -0.3, -0.6), Vector3(1.2, 0.9, 1.2))
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + v
	var paint := func(g: VoxelGrid) -> void:
		var hx := rng.randf_range(0.3, 0.5)
		var hy := rng.randf_range(0.18, 0.32)
		var hz := rng.randf_range(0.25, 0.45)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, hy * 0.6, 0), Vector3(hx, hy, hz), 0.08), Mat.STONE)
		# A chipped corner, moss on the north side.
		var chip := Vector3(hx, hy * 1.4, hz)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.sphere(p, chip, 0.18), Mat.STONE, -1, VoxelGrid.Mode.CARVE)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.z < -hz * 0.3 and VoxelSdf.hash3(c, 71) < 0.6, Mat.MOSS, [Mat.STONE])
	return VoxelProp.mesh("hb_stone%d" % v, VERSION, bounds, T1 * 0.5, paint, color, surface_of)


# ---------------------------------------------------------------- rims and roots

## Grass overhanging every T1 island's rim, with roots dangling from the soil;
## longer roots and vines hanging from the undersides.
func _rims_and_roots() -> void:
	var lips: Array = [[], [], []]
	var roots: Array = [[], [], []]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for name: String in FINE_ISLANDS:
		var i := field.index_of(name)
		var c := field.centres[i]
		var n := int(TAU * field.radii[i] / 1.0)
		for k in n:
			var a := TAU * k / n
			var p := field.top_point(i, a, 1.0)
			var out := Vector3(p.x - c.x, 0, p.z - c.y).normalized()
			var basis := Basis(Vector3.UP, atan2(out.x, out.z))
			p.y = roundf(p.y / T1) * T1
			(lips[k % 3] as Array).append(Transform3D(basis, p))
		for k in int(field.radii[i] * 2.2):
			var a := rng.randf() * TAU
			var s := rng.randf_range(0.45, 0.95)
			var r := field.rim_radius(i, a) * s
			var w := Vector2(c.x + cos(a) * r, c.y + sin(a) * r)
			var y := field.underside_profile(i, s)
			(roots[k % 3] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.6)),
				Vector3(w.x, y + 0.4, w.y)))
	for v in 3:
		_place(_lip_mesh(v), lips[v], "RimLips%d" % v, 160.0)
		_place(_root_mesh(v), roots[v], "HangingRoots%d" % v, 220.0)


func _lip_mesh(v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 800 + v
	var bounds := AABB(Vector3(-0.7, -2.2, -0.4), Vector3(1.4, 2.5, 1.2))
	var paint := func(g: VoxelGrid) -> void:
		# A slab of turf sticking out past the rim, its soil under it.
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, -0.06, 0.1), Vector3(0.62, 0.07, 0.38)), Mat.GRASS_A)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, -0.3, 0.0), Vector3(0.6, 0.18, 0.3)), Mat.SOIL)
		# Grass blades drooping over the edge.
		for k in 6:
			var x := rng.randf_range(-0.55, 0.55)
			var a := Vector3(x, 0.0, 0.42)
			var b := a + Vector3(rng.randf_range(-0.05, 0.05), -rng.randf_range(0.1, 0.35), rng.randf_range(0.05, 0.12))
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, a, b, 0.035, 0.02), Mat.GRASS_B, -1, VoxelGrid.Mode.ADD)
		# Roots dangling from the soil.
		for k in 3:
			var x := rng.randf_range(-0.5, 0.5)
			var a := Vector3(x, -0.4, rng.randf_range(0.05, 0.25))
			var mid := a + Vector3(rng.randf_range(-0.15, 0.15), -rng.randf_range(0.4, 0.8), 0.05)
			var b := mid + Vector3(rng.randf_range(-0.2, 0.2), -rng.randf_range(0.3, 0.9), 0.0)
			g.paint(bounds, func(p: Vector3) -> float:
				return minf(VoxelSdf.capsule(p, a, mid, 0.04, 0.03), VoxelSdf.capsule(p, mid, b, 0.03, 0.015)), Mat.BARK, -1, VoxelGrid.Mode.ADD)
	return VoxelProp.mesh("hb_lip%d" % v, VERSION, bounds, T0 * 2.0, paint, color, surface_of)


func _root_mesh(v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 850 + v
	var bounds := AABB(Vector3(-1.2, -6.0, -1.2), Vector3(2.4, 6.6, 2.4))
	var paint := func(g: VoxelGrid) -> void:
		for k in 4:
			var a := Vector3(rng.randf_range(-0.6, 0.6), 0.4, rng.randf_range(-0.6, 0.6))
			var pts := [a]
			for j in 4:
				pts.append(pts[-1] + Vector3(rng.randf_range(-0.35, 0.35), -rng.randf_range(0.5, 1.4), rng.randf_range(-0.35, 0.35)))
			for j in pts.size() - 1:
				var pa: Vector3 = pts[j]
				var pb: Vector3 = pts[j + 1]
				var r0 := lerpf(0.12, 0.03, float(j) / 4.0)
				g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, pa, pb, r0, r0 * 0.7),
					Mat.BARK if k % 2 == 0 else Mat.MOSS, -1, VoxelGrid.Mode.ADD)
	return VoxelProp.mesh("hb_root%d" % v, VERSION, bounds, T1 * 0.5, paint, color, surface_of)


# ---------------------------------------------------------------- story props

## Storytelling props in the fight area: a bench facing the arch, a swing on a
## Heart Isle tree, a wishing well, a standing stone carved with initials in a
## heart, and a picnic blanket with a basket on Picnic Meadow.
func _story_props() -> void:
	var bench_at := arch_base + Vector2(-9.0, 17.0)
	_single(_bench_mesh(), bench_at, PI)
	_single(_well_mesh(), arch_base + Vector2(16.0, 20.0), 0.4)
	_single(_carved_stone_mesh(), arch_base + Vector2(7.5, 6.5), -0.3)
	var meadow := field.index_of("Picnic Meadow")
	var mc := field.centres[meadow]
	_single(_blanket_mesh(), mc + Vector2(0.0, 16.0), 0.35)
	# The swing hangs from the Heart Isle tree nearest the arch's front.
	var best := Transform3D()
	var best_d := INF
	for t in tree_spots:
		var d := Vector2(t.origin.x, t.origin.z).distance_to(arch_base + Vector2(0, 30))
		if d < best_d:
			best_d = d
			best = t
	var swing := MeshInstance3D.new()
	swing.name = "Swing"
	swing.mesh = _swing_mesh()
	swing.transform = best
	add_child(swing)


func _single(m: ArrayMesh, at: Vector2, yaw: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = m
	var y := field.surface_at(at.x, at.y)
	node.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, y, at.y))
	add_child(node)
	return node


func _bench_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-1.2, -0.1, -0.5), Vector3(2.4, 1.2, 1.0))
	var paint := func(g: VoxelGrid) -> void:
		for z: float in [-0.14, 0.0, 0.14]:
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 0.46, z), Vector3(1.0, 0.03, 0.06)), Mat.WOOD)
		for z: float in [0.3, 0.42]:
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 0.62 + (z - 0.3) * 2.0, 0.27), Vector3(1.0, 0.05, 0.03)), Mat.WOOD)
		for x: float in [-0.85, 0.85]:
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(x, 0.22, 0), Vector3(0.06, 0.24, 0.2)), Mat.STONE)
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(x, 0.7, 0.27), Vector3(0.04, 0.24, 0.03)), Mat.POST)
		# A heart carved in the backrest.
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			var q := Vector2(p.x, p.y - 0.75) / 0.09
			var heart := minf(Vector2(q.x - 0.5, q.y - 0.25).length(), Vector2(q.x + 0.5, q.y - 0.25).length()) - 0.55
			heart = minf(heart, maxf(absf(q.x) + q.y * 0.9 - 0.75, -q.y - 1.1))
			return p.z < 0.26 and heart < 0.0, Mat.CAP, [Mat.WOOD])
	return VoxelProp.mesh("hb_bench", VERSION, bounds, T0, paint, color, surface_of)


func _well_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-1.6, -0.1, -1.6), Vector3(3.2, 3.4, 3.2))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			var r := Vector2(p.x, p.z).length()
			return maxf(absf(r - 0.95) - 0.22, absf(p.y - 0.45) - 0.45), Mat.STONE)
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return fposmod(atan2(p.z, p.x) / TAU * 12.0 + (0.5 if p.y > 0.45 else 0.0), 1.0) < 0.08 or absf(p.y - 0.45) < 0.03,
				Mat.MORTAR, [Mat.STONE])
		g.paint(bounds, func(p: Vector3) -> float: return maxf(Vector2(p.x, p.z).length() - 0.75, absf(p.y - 0.62) - 0.02), Mat.WATER)
		for x: float in [-1.0, 1.0]:
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(x, 1.4, 0), Vector3(0.07, 1.0, 0.07)), Mat.POST)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 2.4, 0), Vector3(1.3, 0.05, 0.7)), Mat.CAP)
		g.paint(bounds, func(p: Vector3) -> float:
			return maxf(VoxelSdf.box(p, Vector3(0, 2.62, 0), Vector3(1.4, 0.3, 0.8)), absf(p.z) * 0.8 + p.y - 3.05), Mat.WOOD)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, Vector3(-0.95, 1.9, 0), Vector3(0.95, 1.9, 0), 0.05, 0.05), Mat.WOOD)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, Vector3(0, 1.9, 0), Vector3(0, 1.1, 0), 0.015, 0.015), Mat.ROPE)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 1.0, 0), Vector3(0.12, 0.12, 0.12)), Mat.WOOD)
	return VoxelProp.mesh("hb_well", VERSION, bounds, T0 * 2.0, paint, color, surface_of)


func _carved_stone_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.7, -0.3, -0.4), Vector3(1.4, 2.2, 0.8))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 0.75, 0), Vector3(0.5 - p.y * 0.08, 0.95, 0.22), 0.1), Mat.STONE)
		# A heart outline with two initials-like marks inside, on the front.
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			if p.z < 0.15:
				return false
			var q := Vector2(p.x, p.y - 1.05) / 0.33
			var heart := minf(Vector2(q.x - 0.5, q.y - 0.25).length(), Vector2(q.x + 0.5, q.y - 0.25).length()) - 0.55
			heart = minf(heart, maxf(absf(q.x) + q.y * 0.9 - 0.75, -q.y - 1.1))
			var outline := absf(heart) < 0.09
			var mark_a := absf(q.x + 0.38) < 0.06 and absf(q.y) < 0.3
			var mark_b := absf(q.x - 0.38) < 0.06 and absf(q.y) < 0.3 or absf(q.y - 0.0) < 0.05 and absf(q.x - 0.38) < 0.15
			return outline or mark_a or mark_b, Mat.STONE_DARK, [Mat.STONE])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return (p.y < 0.4 or p.z < -0.1) and VoxelSdf.hash3(c, 73) < 0.5, Mat.MOSS, [Mat.STONE])
	return VoxelProp.mesh("hb_carved_stone", VERSION, bounds, T0 * 2.0, paint, color, surface_of)


func _blanket_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-1.3, -0.05, -1.1), Vector3(2.6, 0.7, 2.2))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 0.02, 0), Vector3(1.0, 0.025, 0.8)), Mat.RIBBON)
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return (floori((p.x + 1.0) / 0.2) + floori((p.z + 0.8) / 0.2)) % 2 == 0, Mat.PAPER, [Mat.RIBBON])
		# A folded corner and the basket.
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(-0.8, 0.07, 0.6), Vector3(0.2, 0.025, 0.2)), Mat.RIBBON, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0.6, 0.18, -0.4), Vector3(0.24, 0.15, 0.17), 0.03), Mat.WOOD, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return fposmod(p.x * 25.0 + p.y * 25.0, 1.0) < 0.35, Mat.CAP, [Mat.WOOD])
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.torus(p, Vector3(0.6, 0.33, -0.4), Vector3(1, 0, 0), 0.16, 0.02), Mat.WOOD, -1, VoxelGrid.Mode.ADD)
	return VoxelProp.mesh("hb_blanket", VERSION, bounds, T0, paint, color, surface_of)


func _swing_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(1.2, 0.2, -0.6), Vector3(1.4, 4.4, 1.2))
	var paint := func(g: VoxelGrid) -> void:
		for z: float in [-0.35, 0.35]:
			g.paint(bounds, func(p: Vector3) -> float:
				return VoxelSdf.capsule(p, Vector3(1.9, 4.3, z), Vector3(1.9, 0.62, z), 0.025, 0.025), Mat.ROPE)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(1.9, 0.58, 0), Vector3(0.2, 0.035, 0.45)), Mat.WOOD)
		# The bough it hangs from.
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, Vector3(1.3, 4.35, 0), Vector3(2.5, 4.45, 0), 0.12, 0.09), Mat.BARK)
	return VoxelProp.mesh("hb_swing", VERSION, bounds, T0 * 1.5, paint, color, surface_of)


static func _quads(m: Mesh) -> int:
	var total := 0
	for s in m.get_surface_count():
		total += m.surface_get_array_index_len(s) / 6
	return total


# ---------------------------------------------------------------- bridges

## Every rope-plank bridge from the sim's list: voxel planks (T1) on the sagging
## deck, rope links (T0) for hand ropes and suspenders, end posts (T1). One
## plank on the Heart Isle - Wishing Isle bridge is new, lighter wood.
func _bridges() -> void:
	var plank := _plank_mesh(false)
	var new_plank := _plank_mesh(true)
	var link := _rope_mesh()
	var post := _post_mesh()
	var planks: Array[Transform3D] = []
	var fresh: Array[Transform3D] = []
	var links: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	for pair: Array in HeartbloomProps.BRIDGES:
		var a := field.index_of(pair[0])
		var b := field.index_of(pair[1])
		var dir := (field.centres[b] - field.centres[a]).normalized()
		var angle := atan2(dir.y, dir.x)
		var start := field.top_point(a, angle, 0.92)
		var end := field.top_point(b, angle + PI, 0.92)
		var length := start.distance_to(end)
		var sag := length * 0.07
		var flat := Vector3(end.x - start.x, 0.0, end.z - start.z).normalized()
		var side := Vector3.UP.cross(flat).normalized()
		var deck := func(u: float) -> Vector3:
			return start.lerp(end, u) + Vector3.DOWN * sag * 4.0 * u * (1.0 - u)
		var count := int(length / 0.95)
		var odd := count / 3 if pair == ["Heart Isle", "Wishing Isle"] else -1
		for k in count:
			var u := (float(k) + 0.5) / count
			var p: Vector3 = deck.call(u)
			var ahead: Vector3 = (deck.call(minf(u + 0.01, 1.0)) as Vector3) - (deck.call(maxf(u - 0.01, 0.0)) as Vector3)
			var forward := ahead.normalized()
			var basis := Basis(side, forward.cross(side).normalized(), forward)
			# A little wobble per plank, so the deck looks laid by hand.
			var wob := (VoxelSdf.hash3(Vector3i(k, roundi(p.x), roundi(p.z)), 9) - 0.5) * 0.08
			(fresh if k == odd else planks).append(Transform3D(basis.rotated(forward, wob), p))
		for s: float in [-1.0, 1.0]:
			var rope_at := func(u: float) -> Vector3:
				return (deck.call(u) as Vector3) + side * 1.6 * s + Vector3.UP * 1.15
			var n := int(length / 0.5)
			for k in n:
				var p0: Vector3 = rope_at.call(float(k) / n)
				var p1: Vector3 = rope_at.call(float(k + 1) / n)
				links.append(_along(p0, p1))
			for k in range(1, maxi(8, int(length / 2.0))):
				var u := float(k) / maxi(8, int(length / 2.0))
				var top: Vector3 = rope_at.call(u)
				var bottom: Vector3 = (deck.call(u) as Vector3) + side * 1.6 * s
				var m := int(top.distance_to(bottom) / 0.5)
				for j in m:
					links.append(_along(bottom.lerp(top, float(j) / m), bottom.lerp(top, float(j + 1) / m)))
			for u: float in [0.0, 1.0]:
				var base: Vector3 = (deck.call(u) as Vector3) + side * 1.7 * s
				posts.append(Transform3D(Basis(Vector3.UP, atan2(flat.x, flat.z)), base + Vector3.DOWN * 0.4))
	VoxelProp.instances(self, "BridgePlanks", plank, planks, 160.0)
	VoxelProp.instances(self, "BridgePlankNew", new_plank, fresh, 160.0)
	VoxelProp.instances(self, "BridgeRopes", link, links, 120.0)
	VoxelProp.instances(self, "BridgePosts", post, posts, 200.0)
	stats["bridge_instances"] = planks.size() + links.size() + posts.size()


## A transform that lays a 0.5 m link (along +Z) from a to b.
static func _along(a: Vector3, b: Vector3) -> Transform3D:
	var z := (b - a).normalized()
	var x := Vector3.UP.cross(z)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	return Transform3D(Basis(x, z.cross(x), z), (a + b) * 0.5)


func _plank_mesh(fresh: bool) -> ArrayMesh:
	var bounds := AABB(Vector3(-1.7, -0.15, -0.4), Vector3(3.4, 0.3, 0.8))
	var mat := Mat.WOOD_NEW if fresh else Mat.WOOD
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3.ZERO, Vector3(1.6, 0.09, 0.34)), mat)
		# Grain: darker lines along the plank, and two nail heads at each end.
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return fposmod(p.z * 11.0 + VoxelSdf.hash3(Vector3i(c.x / 6, 0, 0), 3), 1.0) < 0.18, Mat.CAP if not fresh else Mat.WOOD,
			[mat])
		for x: float in [-1.4, 1.4]:
			for z: float in [-0.18, 0.18]:
				var at := Vector3(x, 0.09, z)
				g.paint(AABB(at - Vector3.ONE * 0.06, Vector3.ONE * 0.12), func(p: Vector3) -> float:
					return VoxelSdf.sphere(p, at, 0.04), Mat.GOLD, -1, VoxelGrid.Mode.ADD)
	return VoxelProp.mesh("hb_plank%s" % ("_new" if fresh else ""), VERSION, bounds, T1 * 0.5, paint, color, surface_of)


func _rope_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.1, -0.1, -0.27), Vector3(0.2, 0.2, 0.54))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.capsule(p, Vector3(0, 0, -0.25), Vector3(0, 0, 0.25), 0.055, 0.055), Mat.ROPE)
		# Twist: a dark spiral groove.
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return fposmod(atan2(p.y, p.x) / TAU + p.z * 6.0, 1.0) < 0.3, Mat.WOOD, [Mat.ROPE])
	return VoxelProp.mesh("hb_rope", VERSION, bounds, T0, paint, color, surface_of)


func _post_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.4, -0.2, -0.4), Vector3(0.8, 3.8, 0.8))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 1.5, 0), Vector3(0.21, 1.6, 0.21), 0.03), Mat.POST)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 3.15, 0), Vector3(0.3, 0.09, 0.3), 0.02), Mat.CAP)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 0.0, 0), Vector3(0.28, 0.2, 0.28)), Mat.STONE)
		# Rope lashing near the top.
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 1.15, 0), Vector3(0.24, 0.12, 0.24)), Mat.ROPE, -1, VoxelGrid.Mode.ADD)
	return VoxelProp.mesh("hb_post", VERSION, bounds, T1 * 0.5, paint, color, surface_of)


# ---------------------------------------------------------------- lanterns

## Paper lanterns (T0) on every spot the sim hangs one, with dark caps and
## paper ribs; one on Lantern Rise is the pale blue replacement. Posts with a
## crossbar where the sim stands them.
func _lanterns() -> void:
	var paper := _lantern_mesh(false)
	var blue := _lantern_mesh(true)
	var warm: Array[Transform3D] = []
	var odd: Array[Transform3D] = []
	var rise := field.centres[field.index_of("Lantern Rise")]
	var picked := false
	for t in props.lanterns:
		var s := t.basis.get_scale().y / 1.2
		var xf := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), t.origin)
		if not picked and Vector2(t.origin.x, t.origin.z).distance_to(rise) < 30.0:
			picked = true
			odd.append(xf)
		else:
			warm.append(xf)
	for at in arch_lanterns:
		warm.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.6), at))
	VoxelProp.instances(self, "PaperLanterns", paper, warm, 140.0)
	VoxelProp.instances(self, "PaperLanternBlue", blue, odd, 140.0)
	var post := _lantern_post_mesh()
	var posts: Array[Transform3D] = []
	var fc: Vector3 = zone.get_meta("wishing_fountain").centre
	var spots: Array[Vector2] = []
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.5
		spots.append(Vector2(fc.x + cos(a) * 11.0, fc.z + sin(a) * 11.0))
	for dx: float in [-14.0, 14.0]:
		for dz: float in [-7.0, 7.0]:
			spots.append(arch_base + Vector2(dx, dz))
	var ri := field.index_of("Lantern Rise")
	for k in 6:
		var p := field.top_point(ri, TAU * float(k) / 6.0 + 0.3, 0.62)
		spots.append(Vector2(p.x, p.z))
	for s in spots:
		var y := field.surface_at(s.x, s.y)
		if is_finite(y):
			posts.append(Transform3D(Basis.IDENTITY, Vector3(s.x, y, s.y)))
	VoxelProp.instances(self, "LanternPosts", post, posts, 200.0)
	stats["lanterns"] = props.lanterns.size()


func _lantern_mesh(blue: bool) -> ArrayMesh:
	var bounds := AABB(Vector3(-0.55, -0.75, -0.55), Vector3(1.1, 1.6, 1.1))
	var paper := Mat.PAPER_BLUE if blue else Mat.PAPER
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.ellipsoid(p, Vector3.ZERO, Vector3(0.46, 0.56, 0.46)), paper)
		# Ribs every ~9 cm around the body.
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return fposmod(p.y, 0.1) < T0 * 0.9, Mat.CAP if blue else Mat.POST, [paper])
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.cylinder(p, Vector3(0, 0.5, 0), Vector3(0, 0.66, 0), 0.24, 0.2), Mat.CAP)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.cylinder(p, Vector3(0, -0.62, 0), Vector3(0, -0.5, 0), 0.2, 0.22), Mat.CAP)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, Vector3(0, 0.66, 0), Vector3(0, 0.8, 0), 0.02, 0.02), Mat.ROPE)
		# Tassel.
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, Vector3(0, -0.62, 0), Vector3(0, -0.74, 0), 0.03, 0.05), Mat.POST)
	return VoxelProp.mesh("hb_lantern%s" % ("_blue" if blue else ""), VERSION, bounds, T0, paint, color, surface_of)


func _lantern_post_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.9, -0.4, -0.3), Vector3(1.8, 3.9, 0.6))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 1.5, 0), Vector3(0.18, 1.8, 0.18), 0.02), Mat.POST)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 3.2, 0), Vector3(0.75, 0.09, 0.14), 0.02), Mat.POST)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, -0.15, 0), Vector3(0.3, 0.2, 0.3)), Mat.STONE)
		# Tally marks carved on the post (someone counting the evenings).
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return p.z > 0.1 and p.y > 1.2 and p.y < 1.45 and absf(p.x) < 0.12 and fposmod(p.x + 0.12, 0.06) < T1 * 0.5,
			Mat.CAP, [Mat.POST])
		# The two lanterns hang from the crossbar (they're instanced separately).
		g.paint(bounds, func(p: Vector3) -> float:
			return minf(VoxelSdf.capsule(p, Vector3(0.6, 3.1, 0), Vector3(0.6, 2.95, 0), 0.015, 0.015),
				VoxelSdf.capsule(p, Vector3(-0.6, 3.1, 0), Vector3(-0.6, 2.95, 0), 0.015, 0.015)), Mat.ROPE)
	return VoxelProp.mesh("hb_lantern_post", VERSION, bounds, T1 * 0.5, paint, color, surface_of)


# ---------------------------------------------------------------- fountain

## The Wishing Fountain at T1: a ring basin of rim blocks, a pedestal, two
## bowls and a gold finial; water planes in the pools; wishing coins on the
## basin floor, thickest near the rim, one balanced on the spout.
func _fountain() -> void:
	var fc: Vector3 = zone.get_meta("wishing_fountain").centre
	var ground := field.surface_at(fc.x, fc.z)
	var bounds := AABB(Vector3(-7.2, -0.3, -7.2), Vector3(14.4, 9.2, 14.4))
	var paint := func(g: VoxelGrid) -> void:
		# Basin: a low wall ring of 18 blocks with a floor.
		g.paint(bounds, func(p: Vector3) -> float:
			var r := Vector2(p.x, p.z).length()
			return maxf(maxf(absf(r - 6.4) - 0.45, absf(p.y - 0.75) - 0.75), 0.0) if true else 1.0, Mat.STONE)
		g.paint(bounds, func(p: Vector3) -> float:
			return maxf(Vector2(p.x, p.z).length() - 6.0, absf(p.y - 0.1) - 0.12), Mat.STONE_DARK)
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			var a := fposmod(atan2(p.z, p.x) / TAU * 18.0, 1.0)
			return absf(Vector2(p.x, p.z).length() - 6.4) < 0.5 and (a < 0.05 or absf(p.y - 1.0) < T1 * 0.5), Mat.MORTAR, [Mat.STONE])
		# A worn sun-dial ring on the rim's top.
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			var a := fposmod(atan2(p.z, p.x) / TAU * 24.0, 1.0)
			return p.y > 1.4 and absf(Vector2(p.x, p.z).length() - 6.4) < 0.1 and a < 0.25, Mat.STONE_DARK, [Mat.STONE])
		# Pedestal, lower bowl, stem, upper bowl, finial.
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.cylinder(p, Vector3(0, 0, 0), Vector3(0, 4.0, 0), 0.95, 0.75), Mat.STONE)
		g.paint(bounds, func(p: Vector3) -> float:
			var bowl := VoxelSdf.cylinder(p, Vector3(0, 3.9, 0), Vector3(0, 5.0, 0), 1.2, 3.3)
			var hollow := VoxelSdf.cylinder(p, Vector3(0, 4.3, 0), Vector3(0, 5.2, 0), 1.0, 3.05)
			return maxf(bowl, -hollow), Mat.STONE)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.cylinder(p, Vector3(0, 4.9, 0), Vector3(0, 7.1, 0), 0.5, 0.4), Mat.STONE)
		g.paint(bounds, func(p: Vector3) -> float:
			var bowl := VoxelSdf.cylinder(p, Vector3(0, 7.0, 0), Vector3(0, 7.7, 0), 0.6, 1.6)
			var hollow := VoxelSdf.cylinder(p, Vector3(0, 7.3, 0), Vector3(0, 7.9, 0), 0.4, 1.4)
			return maxf(bowl, -hollow), Mat.STONE)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.ellipsoid(p, Vector3(0, 8.1, 0), Vector3(0.45, 0.55, 0.45)), Mat.GOLD)
		# Moss on the north side of the basin wall and bowls.
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.z < -2.0 and p.y < 1.0 and VoxelSdf.hash3(c, 47) < 0.4, Mat.MOSS, [Mat.STONE])
		# Wishing coins on the floor, thickest near the rim; one on the finial.
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			var r := Vector2(p.x, p.z).length()
			return p.y < 0.3 and r < 5.9 and VoxelSdf.hash3(c, 53) < 0.02 + 0.12 * smoothstep(3.0, 5.8, r), Mat.GOLD, [Mat.STONE_DARK])
	var m := VoxelProp.mesh("hb_fountain", VERSION, bounds, T1, paint, color, surface_of)
	var node := MeshInstance3D.new()
	node.name = "WishingFountain"
	node.mesh = m
	node.position = Vector3(fc.x, ground, fc.z)
	add_child(node)
	# Water in the basin and the two bowls.
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("#9CCBCB")
	water.roughness = 0.08
	water.metallic_specular = 0.8
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.albedo_color.a = 0.78
	for pool: Array in [[5.95, 0.42], [3.0, 4.95], [1.4, 7.65]]:
		var disc := CylinderMesh.new()
		disc.top_radius = pool[0]
		disc.bottom_radius = pool[0]
		disc.height = 0.02
		disc.radial_segments = 48
		var w := MeshInstance3D.new()
		w.mesh = disc
		w.material_override = water
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.position = node.position + Vector3(0, pool[1], 0)
		add_child(w)
	stats["fountain_quads"] = _quads(m)


# ---------------------------------------------------------------- cloud sea

## Voxel puff clouds (T3) on the sim's cloud-tuft spots, plus a lower layer
## drifting under the islands; the fog does the rest.
func _clouds() -> void:
	var variants: Array[ArrayMesh] = []
	for v in 3:
		variants.append(_cloud_mesh(v))
	var lists: Array = [[], [], []]
	for k in props.clouds.size():
		var t := props.clouds[k]
		var s := t.basis.get_scale().x / 24.0
		(lists[k % 3] as Array).append(Transform3D(Basis(Vector3.UP, k * 1.7).scaled(Vector3.ONE * clampf(s, 0.4, 2.0)), t.origin))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 70:
		var p := Vector3(rng.randf_range(-330, 330), rng.randf_range(196, 228), rng.randf_range(-240, 260))
		(lists[k % 3] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.8)), p))
	for v in 3:
		var list: Array[Transform3D] = []
		list.assign(lists[v])
		var node := VoxelProp.instances(self, "Clouds%d" % v, variants[v], list)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _cloud_mesh(v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 300 + v
	var bounds := AABB(Vector3(-26, -6, -26), Vector3(52, 18, 52))
	var paint := func(g: VoxelGrid) -> void:
		for k in 9:
			var c := Vector3(rng.randf_range(-14, 14), rng.randf_range(0, 4), rng.randf_range(-14, 14))
			var r := rng.randf_range(5.0, 9.0)
			g.paint(AABB(c - Vector3(r, r * 0.6, r), Vector3(r, r * 0.6, r) * 2), func(p: Vector3) -> float:
				return maxf(VoxelSdf.ellipsoid(p, c, Vector3(r, r * 0.55, r)), -1.0 - p.y), Mat.PAPER, -1, VoxelGrid.Mode.ADD)
	return VoxelProp.mesh("hb_cloud%d" % v, VERSION, bounds, T3, paint, _cloud_colour, func(_m: int) -> int: return 3)


func _cloud_colour(_mat: int, p: Vector3, c: Vector3i, n: Vector3, occlusion: float, _exposure: float) -> Color:
	var col := Color("#fbe9ec").lerp(Color("#e7c3cf"), clampf(-n.y, 0.0, 1.0) * 0.6 + occlusion * 0.4)
	col *= 0.97 + 0.06 * VoxelSdf.hash3(c, 5)
	col.a = 1.0
	return col
