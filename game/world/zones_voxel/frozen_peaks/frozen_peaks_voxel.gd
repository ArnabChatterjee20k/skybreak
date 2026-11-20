class_name FrozenPeaksVoxel
extends VoxelZone
## Frozen Peaks in the voxel style (docs/lookdev/frozen_peaks.md), built on the
## voxel zone kit. The sim stays the truth: the ground is the baked terrain
## heightmap (TerrainShape._peaks), and every spire, shelf and boulder comes
## from FrozenPeaksProps run as ZoneMatch runs it (PropKit seed 4242, spawns
## kept clear). This pass only builds the look over them.
##
## Tiers: the valley floor is a smooth top that equals the sim floor (T1 around
## the spawns, T2 along the rest of the valley); the mountains are stepped T3
## columns with snow on every ledge; a coarse stand-in range frames the zone.

const TERRAIN_SHADER := preload("res://game/world/voxel_zone_kit/voxel_terrain.gdshader")
const SKY_SHADER := preload("res://game/world/zones_voxel/frozen_peaks/frozen_sky.gdshader")
## The valley floor: within this distance (m) of the valley line.
const FLOOR_HALF := 70.0
## T1 floor around the spawns and the camp (x, z, w, h).
const HERO_RECT := Rect2(-722, -606, 144, 150)
## The zone's own terrain (x, z): beyond it a coarse stand-in range.
const ZONE_RECT := Rect2(-1022, -1022, 840, 980)
const FAR_CELL := 16.0
## Mountain chunks switch to the 2 x T3 tier past this distance (m).
const MOUNTAIN_LOD := 330.0
## Glacier half-width (m) and the crevasse band beside it.
const GLACIER_HALF := 12.0

var map: TerrainHeightmap
var zone: ZoneData
var layout: ZoneLayout
var centre := Vector2.ZERO
## The sim's placements (FrozenPeaksProps): transforms as the grey-block builds them.
var sim_spires: Array[Transform3D] = []
var sim_shelves: Array[Transform3D] = []
var sim_boulders: Array[Transform3D] = []
## Where things are, for shots: camp centre, first cairn, crevasse, Ice Crown summit.
var camp := Vector2.ZERO
var first_cairn := Vector2.ZERO
var crown := Vector3.ZERO
var crevasses: Array = []  # [a: Vector2, b: Vector2, half width]
var prints: Array[Vector2] = []
var _shade := {}  # 0.5 m contact shade under props
var _pennant: Node3D
var _tent_flap: Node3D
var _sky_done := false
var _snow: Array[GPUParticles3D] = []


func _init() -> void:
	name = "FrozenPeaks"


func build() -> void:
	var t := Time.get_ticks_msec()
	map = load(WorldMap.HEIGHTMAP_PATH)
	layout = ZoneLayout.load_default()
	zone = load("res://game/world/zones/frozen_peaks.tres")
	centre = zone.centre
	_placements()
	_story_layout()
	_contact_shade()
	lantern_materials.append(VoxelProp.materials()[VoxelProp.Surf.GLOW] as ShaderMaterial)
	var steps: Array[Callable] = [_floor, _mountains, _far_range, _spires, _shelves, _boulders, _crown_teeth,
		_cairns, _camp, _crevasse_lips, _waterfall, _sastrugi, _snowfall]
	for step in steps:
		var s := Time.get_ticks_msec()
		step.call()
		stats["ms_" + step.get_method().trim_prefix("_")] = Time.get_ticks_msec() - s
	stats["ms_total"] = Time.get_ticks_msec() - t


func ground_at(x: float, z: float) -> float:
	return map.ground_height_at(x, z)


## Signed distance (m, along z) from the valley line.
func valley_d(x: float, z: float) -> float:
	var lx := x - centre.x
	return z - centre.y - (70.0 * sin(lx / 140.0) + 30.0)


## World (x, z) at lx along the valley, d metres off its line.
func valley_point(lx: float, d: float) -> Vector2:
	return Vector2(centre.x + lx, centre.y + 70.0 * sin(lx / 140.0) + 30.0 + d)


## Runs the sim's prop builder exactly as ZoneMatch does (a fresh PropKit with
## the world seed and every ground zone's spawns kept clear) and keeps its
## transforms; its grey-block meshes are thrown away.
func _placements() -> void:
	var kit := PropKit.new(map, WorldMap.PROP_SEED)
	for z in layout.ground_zones():
		for p in z.spawn_points:
			kit.keep_clear.append(Vector3(p.x, p.z, WorldMap.SPAWN_CLEAR_RADIUS))
	var scratch := Node3D.new()
	FrozenPeaksProps.build(scratch, kit, zone, layout)
	for node: Node in scratch.get_children():
		var list: Array[Transform3D] = []
		list.assign(node.get_meta(PropKit.INSTANCE_TRANSFORMS_META))
		match String(node.name):
			"IceSpires":
				sim_spires = list
			"IceShelves":
				sim_shelves = list
			"IceBoulders":
				sim_boulders = list
	scratch.free()
	stats["sim_props"] = [sim_spires.size(), sim_shelves.size(), sim_boulders.size()]


func _story_layout() -> void:
	camp = valley_point(56.0, -27.0)
	first_cairn = valley_point(40.0, -18.0)
	# The crevasse the boot prints stop at, crossing the glacier's south margin,
	# plus shorter ones along both margins (never in the 15 m lane).
	crevasses.append([valley_point(4.0, -34.0), valley_point(-3.0, -9.0), 1.2])
	var rng := RandomNumberGenerator.new()
	rng.seed = 4243
	var lx := -320.0
	while lx < 320.0:
		for sgn: float in [-1.0, 1.0]:
			if absf(lx) < 30.0 or rng.randf() < 0.35:
				continue
			var d0 := sgn * rng.randf_range(9.0, 11.0)
			var d1 := sgn * rng.randf_range(20.0, 32.0)
			var skew := rng.randf_range(-6.0, 6.0)
			crevasses.append([valley_point(lx, d0), valley_point(lx + skew, d1), rng.randf_range(0.5, 1.3)])
		lx += rng.randf_range(28.0, 46.0)
	# Boot prints from the first cairn west along the cairn line, ending at the crevasse.
	var x := 38.0
	var k := 0
	while x > 3.5:
		var side := 0.16 if k % 2 == 0 else -0.16
		prints.append(valley_point(x, -18.0 + side))
		x -= 0.42
		k += 1
	var best := -INF
	var guess := Vector2(-800, -750)
	for gx in range(-60, 61, 4):
		for gz in range(-60, 61, 4):
			var h := ground_at(guess.x + gx, guess.y + gz)
			if h > best:
				best = h
				crown = Vector3(guess.x + gx, h, guess.y + gz)


## Contact shade (0.5 m grid) at the feet of spires, boulders and the camp.
func _contact_shade() -> void:
	var add := func(c: Vector2, r: float, strength: float) -> void:
		for gx in range(floori((c.x - r) * 2.0), ceili((c.x + r) * 2.0) + 1):
			for gz in range(floori((c.y - r) * 2.0), ceili((c.y + r) * 2.0) + 1):
				var d := Vector2(gx * 0.5 + 0.25 - c.x, gz * 0.5 + 0.25 - c.y).length() / r
				if d < 1.0:
					var key := Vector2i(gx, gz)
					_shade[key] = maxf(_shade.get(key, 0.0), (1.0 - d) * strength)
	for xf in sim_spires:
		var sc := xf.basis.get_scale()
		add.call(Vector2(xf.origin.x, xf.origin.z), absf(sc.x) * 0.5 + 2.5, 0.9)
	for xf in sim_boulders:
		var sc := xf.basis.get_scale()
		add.call(Vector2(xf.origin.x, xf.origin.z), absf(sc.x) * 0.45 + 1.0, 0.8)
	add.call(camp, 3.0, 0.35)


# ---------------------------------------------------------------- terrain

func _is_floor(x: float, z: float) -> bool:
	# Decided per T3 cell, so the floor and the mountains share one boundary.
	var cx := (floorf((x - ZONE_RECT.position.x) / T3) + 0.5) * T3 + ZONE_RECT.position.x
	var cz := (floorf((z - ZONE_RECT.position.y) / T3) + 0.5) * T3 + ZONE_RECT.position.y
	return absf(valley_d(cx, cz)) < FLOOR_HALF and cx > -1010.0 and cx < -290.0


func _floor() -> void:
	var quads := 0
	for tier in 2:
		var cell := T1 if tier == 0 else T2
		var lo := HERO_RECT.position if tier == 0 else Vector2(ZONE_RECT.position.x, centre.y + 30.0 - 70.0 - FLOOR_HALF - 2.0)
		var hi := HERO_RECT.end if tier == 0 else Vector2(ZONE_RECT.end.x, centre.y + 30.0 + 70.0 + FLOOR_HALF + 2.0)
		var hf := FrozenHeightfield.new(cell, lo, hi)
		hf.max_block_metres = 1.41
		var rim := ceili(3.0 / cell)
		for z in hf.size.y:
			for x in hf.size.x:
				var w := hf.centre(x, z)
				if not _is_floor(w.x, w.y):
					continue
				var in_hero := HERO_RECT.has_point(w)
				if tier == 1 and in_hero:
					continue
				var h := ground_at(w.x, w.y)
				var lv := roundi(h / cell)
				var near_hero := tier == 1 and HERO_RECT.grow(1.0).has_point(w)
				hf.set_column(x, z, lv, lv if tier == 0 or near_hero else lv - rim, _floor_colour(w, cell))
		hf.smooth_height = ground_at
		var mat := _terrain_material(hf)
		var node := hf.build(self, mat, "FloorT%d" % (tier + 1), 0.0, false)
		quads += VoxelHeightfield.count_quads(node)
		stats["floor_t%d_columns" % (tier + 1)] = hf.size.x * hf.size.y
	stats["floor_quads"] = quads


## Snow, the glacier, crevasses, boot prints and contact shade, per column.
func _floor_colour(w: Vector2, cell: float) -> Color:
	var lx := w.x - centre.x
	var d := valley_d(w.x, w.y)
	var ci := Vector3i(floori(w.x / cell), 0, floori(w.y / cell))
	var n := VoxelSdf.hash3(ci, 3)
	# Sastrugi: wind ripples across the valley, crests packed brighter.
	var rip := sin((w.x * 0.8 + w.y * 0.6) * 1.9 + 1.3 * sin(w.y * 0.23 + w.x * 0.05))
	var col := Color("#E4E8EE")
	if rip > 0.82:
		col = Color("#F0F2F5")
	elif rip < -0.86:
		col = Color("#D2D9E3")
	col = col * (0.985 + 0.03 * n)
	var edge := GLACIER_HALF + 3.0 * sin(lx / 37.0) + 2.0 * sin(lx / 13.0 + 1.0) + 1.2 * sin(lx / 5.3)
	var ad := absf(d)
	if ad < edge:
		# Glacier: cyan-grey with flow streaks, lighter at its clear margin.
		var streak := sin(d * 1.7 + 0.6 * sin(lx * 0.09)) * 0.5 + 0.5
		var flow := VoxelSdf.hash3(Vector3i(floori(lx / 3.0), 0, floori(d / 0.7)), 7)
		col = Color("#9CB4C4").lerp(Color("#B4C8D4"), streak * 0.5 + flow * 0.25)
		if edge - ad < 1.2:
			col = Color("#C8DAE4")
		elif VoxelSdf.hash3(ci, 11) < 0.012:
			col = Color("#5A7488")  # trapped bubbles
		col = col * (0.97 + 0.06 * n)
	elif ad < edge + 2.5 and VoxelSdf.hash3(Vector3i(floori(w.x / 0.7), 0, floori(w.y / 0.7)), 13) < (edge + 2.5 - ad) / 2.5:
		col = Color("#D8E0E8")  # snow drifting onto the ice
	for cr: Array in crevasses:
		var a: Vector2 = cr[0]
		var b: Vector2 = cr[1]
		var hw: float = cr[2]
		var ab := b - a
		var t := clampf((w - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var taper := hw * (0.35 + 0.65 * sin(t * PI))
		var dist := (w - (a + ab * t)).length()
		if dist < taper:
			var depth := 1.0 - dist / taper
			col = Color("#5A7488").lerp(Color("#2A3C50"), pow(depth, 0.7))
		elif dist < taper + 0.35:
			col = Color("#C8DAE4")
	if lx > 0.0 and lx < 42.0 and absf(d + 18.0) < 0.6:
		for p in prints:
			var q := w - p
			if absf(q.x) < 0.15 and absf(q.y) < 0.07:
				col = Color("#AEB8CA")
	var shade: float = _shade.get(Vector2i(floori(w.x * 2.0), floori(w.y * 2.0)), 0.0)
	if shade > 0.0:
		col = col.lerp(Color("#8E9AB2"), shade * 0.45)
	if col.r > 0.86 and VoxelSdf.hash3(ci, 17) < 0.002:
		col = Color(1, 1, 1)  # frost sparkle
	col.a = 0.0
	return col


## The mountains: T3 columns, snow on ledges below ~35 degrees, slate above,
## lichen on slate here and there; the terrain shader adds strata and snow lips.
func _mountains() -> void:
	var hf := VoxelHeightfield.new(T3, ZONE_RECT.position, ZONE_RECT.end)
	for z in hf.size.y:
		for x in hf.size.x:
			var w := hf.centre(x, z)
			if _is_floor(w.x, w.y):
				continue
			var h := ground_at(w.x, w.y)
			var lv := roundi(h / T3)
			hf.set_column(x, z, lv, lv - 8, _rock_colour(w, h))
	var mat := _terrain_material(hf)
	var node := hf.build(self, mat, "Mountains")
	stats["mountain_quads"] = VoxelHeightfield.count_quads(node)
	# Far LOD: the same rule at 2 x T3 past MOUNTAIN_LOD metres (per chunk).
	var coarse := VoxelHeightfield.new(T3 * 2.0, ZONE_RECT.position, ZONE_RECT.end)
	for z in coarse.size.y:
		for x in coarse.size.x:
			var w := coarse.centre(x, z)
			if _is_floor(w.x, w.y):
				continue
			var h := ground_at(w.x, w.y)
			var lv := roundi(h / coarse.cell)
			coarse.set_column(x, z, lv, lv - 4, _rock_colour(w, h))
	var cmat := _terrain_material(coarse)
	var far := coarse.build(self, cmat, "MountainsFar")
	for c: MeshInstance3D in node.get_children():
		c.visibility_range_end = MOUNTAIN_LOD
	for c: MeshInstance3D in far.get_children():
		c.visibility_range_begin = MOUNTAIN_LOD
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stats["mountain_far_quads"] = VoxelHeightfield.count_quads(far)


func _rock_colour(w: Vector2, h: float) -> Color:
	var gx := (ground_at(w.x + 2.0, w.y) - ground_at(w.x - 2.0, w.y)) / 4.0
	var gz := (ground_at(w.x, w.y + 2.0) - ground_at(w.x, w.y - 2.0)) / 4.0
	var grade := Vector2(gx, gz).length()
	var ci := Vector3i(floori(w.x / T3), 0, floori(w.y / T3))
	var n := VoxelSdf.hash3(ci, 23)
	var snow_line := 1.05 + 0.4 * clampf((h - 120.0) / 140.0, 0.0, 1.0)
	if grade < snow_line + (n - 0.5) * 0.5:
		var c := Color("#E4E8EE") * (0.98 + 0.03 * n)
		c.a = 0.0
		return c
	var slate := Color("#4A505E") * (0.95 + 0.1 * n)
	if VoxelSdf.hash3(ci, 29) < 0.015:
		slate = Color("#6A6656")
	elif grade < 2.0 and VoxelSdf.hash3(ci, 31) < 0.3:
		slate = Color("#C9D0DA")  # old snow in a crack
	slate.a = 0.0
	return slate


## A stand-in range around the zone (8 m columns): the neighbours' real
## terrain is replaced by snowy ridges that rise with distance, so the zone's
## edge reads as more mountains in the fog. Look-dev framing only.
func _far_range() -> void:
	var lo := Vector2(-2800, -2800)
	var hi := Vector2(1200, 1200)
	var hf := VoxelHeightfield.new(FAR_CELL, lo, hi)
	var noise := FastNoiseLite.new()
	noise.seed = 991
	noise.frequency = 0.0022
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 4
	for z in hf.size.y:
		for x in hf.size.x:
			var w := hf.centre(x, z)
			if ZONE_RECT.grow(-FAR_CELL * 0.5).has_point(w):
				continue
			var dist := maxf(absf(w.x - centre.x) - ZONE_RECT.size.x * 0.5, absf(w.y - centre.y) - ZONE_RECT.size.y * 0.5)
			var ridge := noise.get_noise_2d(w.x, w.y) * 0.5 + 0.5
			var h := 90.0 + clampf(dist / 900.0, 0.0, 1.0) * 380.0 * pow(ridge, 1.5) + 120.0 * ridge
			if map != null and absf(w.x) < 1020.0 and absf(w.y) < 1020.0:
				h = maxf(h * clampf(dist / 300.0, 0.3, 1.0), ground_at(w.x, w.y))
			var lv := roundi(h / FAR_CELL)
			var snowy := ridge > 0.55 or VoxelSdf.hash3(Vector3i(x, 0, z), 5) < 0.4
			var c := Color("#DCE2EA") if snowy else Color("#4A505E")
			c.a = 0.0
			hf.set_column(x, z, lv, lv - 30, c)
	var mat := _terrain_material(hf)
	mat.set_shader_parameter("strata_cells", 2.0)
	var node := hf.build(self, mat, "FarRange")
	stats["far_quads"] = VoxelHeightfield.count_quads(node)


func _terrain_material(hf: VoxelHeightfield) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	hf.bind(mat)
	mat.set_shader_parameter("rock_color", Color("#4A505E"))
	mat.set_shader_parameter("rock_shadow", Color("#2C303A"))
	mat.set_shader_parameter("soil_color", Color("#3A3F4C"))
	mat.set_shader_parameter("crack_amount", 0.9)
	mat.set_shader_parameter("noise_amount", 0.03)
	mat.set_shader_parameter("edge_lift", 0.18)
	mat.set_shader_parameter("strata_cells", 3.0)
	return mat


# ---------------------------------------------------------------- sim props

func _spires() -> void:
	var lists: Array = []
	for v in FrozenPeaksDesigns.SPIRES.size():
		lists.append([])
	for xf in sim_spires:
		var fit := FrozenPeaksDesigns.fit_spire(xf)
		(lists[fit[0]] as Array).append(fit[1])
	var quads := 0
	for v in lists.size():
		if (lists[v] as Array).is_empty():
			continue
		var tiers: Array[ArrayMesh] = [FrozenPeaksDesigns.spire(v, T2), FrozenPeaksDesigns.spire(v, T3)]
		quads += VoxelProp.quads(tiers[0])
		_place(tiers, lists[v], "Spires%d" % v, [160.0, 0.0], 1)
	stats["spire_quads_t2"] = quads


func _shelves() -> void:
	var lists: Array = [[], [], [], []]
	for xf in sim_shelves:
		var fit := FrozenPeaksDesigns.fit_shelf(xf)
		(lists[fit[0]] as Array).append(fit[1])
	for v in 4:
		if (lists[v] as Array).is_empty():
			continue
		var tiers: Array[ArrayMesh] = [FrozenPeaksDesigns.shelf(v, T2), FrozenPeaksDesigns.shelf(v, T3)]
		_place(tiers, lists[v], "Shelves%d" % v, [200.0, 0.0], 1)


func _boulders() -> void:
	var lists: Array = [[], [], [], [], [], []]
	for k in sim_boulders.size():
		var xf := sim_boulders[k]
		var sc := xf.basis.get_scale()
		var s := absf(sc.y) / FrozenPeaksDesigns.BOULDER_S
		var v := (k * 7 + 3) % 6
		(lists[v] as Array).append(Transform3D(xf.basis.orthonormalized().scaled_local(Vector3.ONE * s), xf.origin))
	for v in 6:
		var tiers: Array[ArrayMesh] = [FrozenPeaksDesigns.boulder(v, T1), FrozenPeaksDesigns.boulder(v, T1 * 4.0)]
		_place(tiers, lists[v], "Boulders%d" % v, [70.0, 0.0], 1)


## The Ice Crown: a ring of ice teeth (spire designs) round the highest summit.
func _crown_teeth() -> void:
	var lists: Array = [[], [], []]
	for k in 11:
		var a := TAU * k / 11.0 + 0.2
		var r := 26.0 + 5.0 * sin(k * 2.3)
		var p := Vector2(crown.x + cos(a) * r, crown.z + sin(a) * r)
		var g := ground_at(p.x, p.y)
		var s := 0.55 + 0.25 * absf(sin(k * 1.7))
		var lean := Basis.from_euler(Vector3(sin(a) * 0.18, 0, -cos(a) * 0.18)) * Basis(Vector3.UP, k * 0.9)
		(lists[k % 3] as Array).append(Transform3D(lean.scaled_local(Vector3.ONE * s), Vector3(p.x, g - 4.0, p.y)))
	for i in 3:
		var v: int = [3, 2, 4][i]
		var tiers: Array[ArrayMesh] = [FrozenPeaksDesigns.spire(v, T2), FrozenPeaksDesigns.spire(v, T3)]
		_place(tiers, lists[i], "CrownTeeth%d" % i, [220.0, 0.0], 1)


func _place(meshes: Array[ArrayMesh], list: Array, node_name: String, ranges: Array, shadow_tiers: int) -> void:
	var typed: Array[Transform3D] = []
	typed.assign(list)
	VoxelProp.place(self, node_name, meshes, ranges, typed, shadow_tiers)
	stats["n_" + node_name] = typed.size()


# ---------------------------------------------------------------- story props

func _single(m: ArrayMesh, at: Vector2, yaw: float, lift := 0.0, end := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = m
	node.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, ground_at(at.x, at.y) + lift, at.y))
	node.visibility_range_end = end
	add_child(node)
	return node


## Waymarker cairns every 60 m along the south margin; the first is taller.
func _cairns() -> void:
	var lists: Array = [[], [], []]
	var k := 0
	var lx := 40.0 - 60.0
	while lx > -330.0:
		var p := valley_point(lx, -18.0 + 1.5 * sin(lx))
		lists[k % 3].append(Transform3D(Basis(Vector3.UP, lx * 0.7), Vector3(p.x, ground_at(p.x, p.y) - 0.04, p.y)))
		k += 1
		lx -= 60.0
	lx = 100.0
	while lx < 330.0:
		var p := valley_point(lx, -18.0 + 1.5 * sin(lx))
		lists[k % 3].append(Transform3D(Basis(Vector3.UP, lx * 0.7), Vector3(p.x, ground_at(p.x, p.y) - 0.04, p.y)))
		k += 1
		lx += 60.0
	for v in 3:
		_place([FrozenPeaksDesigns.cairn(v, false)], lists[v], "Cairns%d" % v, [0.0], 1)
	_single(FrozenPeaksDesigns.cairn(0, true), first_cairn, PI + 0.25, -0.04)


## The expedition camp by the spawns: the standing tent (flap tied open,
## lantern inside), the collapsed one, the crate stack with a mug, the flag
## tripod with its torn pennant, the half-buried sledge; and the ice axe in
## the nearest spire, the rope bridge over the crevasse.
func _camp() -> void:
	var dir := (valley_point(60.0, 0.0) - valley_point(50.0, 0.0)).normalized()
	var yaw := atan2(-dir.y, dir.x)
	var at := func(along: float, across: float) -> Vector2:
		return camp + dir * along + Vector2(-dir.y, dir.x) * across
	_tent_flap = _single(FrozenPeaksDesigns.tent_standing(), at.call(0.0, 0.0), yaw + PI * 0.5, -0.03)
	_single(FrozenPeaksDesigns.tent_collapsed(), at.call(4.2, -1.2), yaw + 0.3, -0.05)
	var crates := _single(FrozenPeaksDesigns.crate_stack(), at.call(-2.6, 2.4), yaw + 0.2, -0.03)
	var mug := MeshInstance3D.new()
	mug.mesh = FrozenPeaksDesigns.mug()
	mug.position = Vector3(-0.05, 0.34 * 4.0 * 0.9 + 0.04, 0.05)
	crates.add_child(mug)
	var tri_at: Vector2 = at.call(1.8, 3.4)
	_single(FrozenPeaksDesigns.tripod(), tri_at, 0.0, -0.03)
	_pennant = Node3D.new()
	_pennant.position = Vector3(tri_at.x, ground_at(tri_at.x, tri_at.y) + 3.2, tri_at.y)
	add_child(_pennant)
	var flag := MeshInstance3D.new()
	flag.mesh = FrozenPeaksDesigns.pennant()
	_pennant.add_child(flag)
	_pennant.rotation.y = 0.6
	_single(FrozenPeaksDesigns.sledge(), at.call(9.0, -4.0), yaw - 0.4, -0.05)
	# The ice axe at head height in the spire nearest the camp.
	var best := Transform3D()
	var best_d := INF
	for xf in sim_spires:
		var dd := Vector2(xf.origin.x, xf.origin.z).distance_to(camp)
		if dd < best_d:
			best_d = dd
			best = xf
	var fit := FrozenPeaksDesigns.fit_spire(best)
	var sxf: Transform3D = fit[1]
	var spec: Array = FrozenPeaksDesigns.SPIRES[fit[0]]
	var g := ground_at(sxf.origin.x, sxf.origin.z)
	var local_y := (g + 1.75 - sxf.origin.y) / sxf.basis.get_scale().y
	var toward := Vector2(camp.x - sxf.origin.x, camp.y - sxf.origin.z).normalized()
	var axe := MeshInstance3D.new()
	axe.mesh = FrozenPeaksDesigns.ice_axe()
	var radial := (sxf.basis.inverse() * Vector3(toward.x, 0, toward.y)).normalized()
	radial.y = 0.0
	radial = radial.normalized()
	# The main crystal's flat face (hex apothem) along that direction.
	var a := float(spec[1]) * 0.55
	var hit := sxf * (radial * a * 0.97 + Vector3(0, local_y, 0))
	var out := (sxf.basis * radial).normalized()
	axe.transform = Transform3D(Basis.looking_at(-out, Vector3.UP).rotated(out, 0.4), hit - out * 0.06)
	add_child(axe)
	stats["axe_spire_distance"] = best_d
	# The rope bridge, newer than the cairns, beside where the prints stop.
	var cr: Array = crevasses[0]
	var ca: Vector2 = cr[0]
	var cb: Vector2 = cr[1]
	var cdir := (cb - ca).normalized()
	var mid := ca.lerp(cb, 0.42)
	var across := Vector2(-cdir.y, cdir.x)
	var span := 4.4
	var bridge := MeshInstance3D.new()
	bridge.mesh = FrozenPeaksDesigns.rope_bridge(span)
	var y := maxf(ground_at(mid.x + across.x * span * 0.5, mid.y + across.y * span * 0.5),
		ground_at(mid.x - across.x * span * 0.5, mid.y - across.y * span * 0.5))
	bridge.transform = Transform3D(Basis(Vector3.UP, atan2(-across.y, across.x)), Vector3(mid.x, y, mid.y))
	add_child(bridge)


## Raised clear-ice lips along both sides of every crevasse (T1 blocks, a few
## cm proud of the snow), so the painted depth reads as a crack.
func _crevasse_lips() -> void:
	var lists: Array = [[], []]
	for cr: Array in crevasses:
		var a: Vector2 = cr[0]
		var b: Vector2 = cr[1]
		var hw: float = cr[2]
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var n := int(a.distance_to(b) / 0.9)
		for k in n:
			var t := (k + 0.5) / n
			var taper := hw * (0.35 + 0.65 * sin(t * PI))
			for sgn: float in [-1.0, 1.0]:
				var w := a.lerp(b, t) + side * sgn * (taper + 0.15)
				lists[k % 2].append(Transform3D(Basis(Vector3.UP, atan2(-dir.y, dir.x) + 0.15 * sin(k * 3.1)), Vector3(w.x, ground_at(w.x, w.y) - 0.02, w.y)))
	for v in 2:
		var bounds := AABB(Vector3(-0.55, -0.1, -0.25), Vector3(1.1, 0.3, 0.5))
		var m := VoxelProp.mesh("fp_lip%d" % v, FrozenPeaksDesigns.VERSION, bounds, T1 * 0.5, func(g: VoxelGrid) -> void:
			g.paint(bounds, func(p: Vector3) -> float:
				return VoxelSdf.box(p, Vector3(0, 0.0, 0), Vector3(0.45 - v * 0.1, 0.06 + 0.03 * v, 0.14)), FrozenPeaksDesigns.Mat.ICE_CLEAR),
			FrozenPeaksDesigns.color, FrozenPeaksDesigns.surface_of)
		_place([m], lists[v], "CrevasseLips%d" % v, [90.0], 0)


## A frozen waterfall on the north cliff above the camp: a veneer of stacked
## ice columns hugging the cliff (T2), clear ice with blue cores.
func _waterfall() -> void:
	# Walk north from the valley line until the cliff rises 40 m.
	var lx := 30.0
	var base := valley_point(lx, 0.0)
	var foot := Vector2.ZERO
	var top := Vector2.ZERO
	var g0 := ground_at(base.x, base.y)
	for k in 120:
		var p := base + Vector2(0, k * 1.0)
		var h := ground_at(p.x, p.y)
		if foot == Vector2.ZERO and h > g0 + 6.0:
			foot = p
		if h > g0 + 46.0:
			top = p
			break
	if foot == Vector2.ZERO or top == Vector2.ZERO:
		return
	var y0 := ground_at(foot.x, foot.y) - 2.0
	var y1 := ground_at(top.x, top.y) + 1.0
	var bounds := AABB(Vector3(foot.x - 7.0, y0, foot.y - 2.0), Vector3(14.0, y1 - y0, top.y - foot.y + 4.0))
	var zone_ground := ground_at
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			var lat := p.x - foot.x
			var width := 3.5 + 2.0 * clampf((y1 - p.y) / (y1 - y0), 0.0, 1.0) + 0.8 * sin(p.y * 0.4)
			if absf(lat) > width:
				return 1.0
			var surf: float = zone_ground.call(p.x, p.z)
			var col := 0.6 * sin(lat * 2.1) + 0.5
			# In the air, within ~2 m in front of the stepped cliff.
			var behind: float = zone_ground.call(p.x, p.z + 1.6 + col)
			return 1.0 if p.y < surf - 0.8 or p.y > behind + 0.4 else -1.0, FrozenPeaksDesigns.Mat.ICE_CLEAR)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return absf(sin((p.x - foot.x) * 2.1)) < 0.3 or VoxelSdf.hash3(c, 81) < 0.05, FrozenPeaksDesigns.Mat.ICE, [FrozenPeaksDesigns.Mat.ICE_CLEAR])
	var m := VoxelProp.mesh("fp_waterfall_%d" % roundi(foot.x), FrozenPeaksDesigns.VERSION, bounds, T2, paint,
		FrozenPeaksDesigns.color, FrozenPeaksDesigns.surface_of)
	var node := MeshInstance3D.new()
	node.name = "FrozenWaterfall"
	node.mesh = m
	add_child(node)
	stats["waterfall"] = [foot, top]


## Low sastrugi ridges on the snow near the spawns (no shadows, 40 m range).
func _sastrugi() -> void:
	var lists: Array = [[], [], []]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4244
	for k in 900:
		var p := Vector2(rng.randf_range(HERO_RECT.position.x, HERO_RECT.end.x), rng.randf_range(HERO_RECT.position.y, HERO_RECT.end.y))
		var ad := absf(valley_d(p.x, p.y))
		if ad < GLACIER_HALF + 5.0 or p.distance_to(camp) < 9.0:
			continue
		lists[k % 3].append(Transform3D(Basis(Vector3.UP, -0.64 + rng.randf_range(-0.2, 0.2)).scaled(Vector3.ONE * rng.randf_range(0.7, 1.5)),
			Vector3(p.x, ground_at(p.x, p.y) - 0.01, p.y)))
	for v in 3:
		_place([FrozenPeaksDesigns.sastrugi(v)], lists[v], "Sastrugi%d" % v, [45.0], 0)


## Sparse snowfall (2-3 cm flecks) over the valley; spindrift off the ridges.
func _snowfall() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.028, 0.028, 0.028)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#F4F6FA")
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = Color("#9AA6BC")
	mat.emission_energy_multiplier = 0.3
	box.material = mat
	var specs := [[Vector3(-650, 110, -530), Vector3(110, 30, 90), 26000], [Vector3(-800, 150, -600), Vector3(180, 50, 180), 14000]]
	for spec: Array in specs:
		var flakes := GPUParticles3D.new()
		flakes.name = "Snowfall"
		flakes.draw_pass_1 = box
		flakes.amount = spec[2]
		flakes.lifetime = 30.0
		flakes.preprocess = 30.0
		flakes.fixed_fps = 30
		flakes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flakes.visibility_aabb = AABB(-spec[1] * 1.5 - Vector3(0, 60, 0), spec[1] * 3.0 + Vector3(0, 60, 0))
		var p := ParticleProcessMaterial.new()
		p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		p.emission_box_extents = spec[1]
		p.direction = Vector3(0.5, -1.0, 0.25)
		p.spread = 15.0
		p.initial_velocity_min = 1.0
		p.initial_velocity_max = 1.8
		p.gravity = Vector3(0, -0.2, 0)
		p.turbulence_enabled = true
		p.turbulence_noise_strength = 0.8
		p.turbulence_noise_scale = 8.0
		p.scale_min = 0.7
		p.scale_max = 1.1
		flakes.process_material = p
		flakes.position = spec[0]
		add_child(flakes)
		_snow.append(flakes)


# ---------------------------------------------------------------- look

func presets() -> Dictionary:
	var p := VoxelStage.PRESETS.duplicate(true)
	p.night = {
		"sky_top": Color("#0E1428"), "sky_horizon": Color("#2A3450"), "sky_below": Color("#2A3450"),
		"cloud": Color("#3A4466"), "cloud_shadow": Color("#1A2038"), "cloud_cover": 0.12,
		"sun_dir": Vector3(-0.3, -0.62, -0.72), "sun_color": Color("#B4C4EC"), "sun_energy": 1.25,
		"sun_size": 0.0, "moon": true, "stars": 1.0,
		"rim_color": Color("#B0C4F0"), "rim_energy": 0.6,
		"ambient_color": Color("#34466E"), "ambient_energy": 0.7,
		"fog_color": Color("#26304C"), "fog_density": 0.0011, "exposure": 1.0, "lantern": 1.4, "aurora": 0.55,
	}
	p.day = {
		"sky_top": Color("#4A70B8"), "sky_horizon": Color("#9CB4D4"), "sky_below": Color("#B8C8DC"),
		"cloud": Color("#F4F6FA"), "cloud_shadow": Color("#B4BED0"), "cloud_cover": 0.3,
		"sun_dir": Vector3(0.298, -0.596, -0.745), "sun_color": Color("#F4F6FF"), "sun_energy": 2.3,
		"sun_size": 0.02, "moon": false, "stars": 0.0,
		"rim_color": Color("#FFD8B0"), "rim_energy": 0.25,
		"ambient_color": Color("#8696B4"), "ambient_energy": 0.55,
		"fog_color": Color("#B8C6DA"), "fog_density": 0.0010, "exposure": 0.9, "lantern": 0.25, "aurora": 0.0,
	}
	p.dusk = {
		"sky_top": Color("#3C4478"), "sky_horizon": Color("#C8A0A8"), "sky_below": Color("#A898A8"),
		"cloud": Color("#E8C8C0"), "cloud_shadow": Color("#7C7490"), "cloud_cover": 0.3,
		"sun_dir": Vector3(0.865, -0.204, -0.458), "sun_color": Color("#FFC0A0"), "sun_energy": 2.0,
		"sun_size": 0.035, "moon": false, "stars": 0.15,
		"rim_color": Color("#FFB890"), "rim_energy": 0.35,
		"ambient_color": Color("#7A7090"), "ambient_energy": 0.5,
		"fog_color": Color("#B8B0C0"), "fog_density": 0.0011, "exposure": 0.95, "lantern": 0.8, "aurora": 0.0,
	}
	return p


## Swaps the stage's sky to the Frozen Peaks sky (the kit's uniforms plus the
## aurora) once the stage exists, and drives the aurora, pennant and flap.
func animate(t: float) -> void:
	var stage: VoxelStage = null
	for n in get_parent().get_children():
		if n is VoxelStage:
			stage = n
	if stage != null and stage._sky_mat != null:
		if not _sky_done:
			stage._sky_mat.shader = SKY_SHADER
			stage._sky_mat.set_shader_parameter("aurora_azimuth", atan2(crown.z - (-530.0), crown.x - (-650.0)))
			_sky_done = true
		stage._sky_mat.set_shader_parameter("aurora_amount", float(stage.current.get("aurora", 0.0)))
		stage._sky_mat.set_shader_parameter("aurora_time", t + 40.0)
	if _pennant != null:
		_pennant.rotation.y = 0.6 + deg_to_rad(4.0) * sin(t * TAU * 0.5)


func shots() -> Array[Dictionary]:
	var all := ["night", "day", "dusk"]
	var out: Array[Dictionary] = []
	var sp := Vector2(-670, -530)
	var sy := ground_at(sp.x, sp.y)
	# Key image: low in the valley looking up the S-curve to the Ice Crown, Kael at the west spawn.
	var cam := valley_point(12.0, 4.0)
	var look := valley_point(-170.0, -25.0)
	out.append({"name": "valley_crown", "from": Vector3(cam.x, ground_at(cam.x, cam.y) + 3.4, cam.y),
		"at": Vector3(look.x, ground_at(look.x, look.y) + 32.0, look.y), "fov": 60.0, "kael": [sp + Vector2(4.0, 2.0), PI * 0.62], "times": all})
	out.append({"name": "overview", "from": Vector3(-420, 330, -330), "at": Vector3(-700, 120, -620), "fov": 60.0, "times": all})
	# Gameplay camera behind Kael at the spawn.
	out.append({"name": "gameplay", "from": Vector3(sp.x + 4.5, sy + 3.6, sp.y + 6.5), "at": Vector3(sp.x - 6.0, sy + 1.4, sp.y - 8.0),
		"fov": 62.0, "kael": [sp, PI * 0.8], "times": all})
	var c := camp
	var cy := ground_at(c.x, c.y)
	out.append({"name": "camp", "from": Vector3(c.x - 6.5, cy + 2.4, c.y + 7.5), "at": Vector3(c.x + 1.5, cy + 0.9, c.y - 0.5),
		"fov": 55.0, "kael": [c + Vector2(-2.6, 3.2), PI * 1.15], "times": ["night", "day"]})
	var fc := first_cairn
	out.append({"name": "cairn_crevasse", "from": Vector3(fc.x + 3.0, ground_at(fc.x, fc.y) + 1.9, fc.y + 3.5),
		"at": Vector3(fc.x - 30.0, ground_at(fc.x, fc.y) - 1.0, fc.y - 4.0), "fov": 55.0, "times": ["day"]})
	# The spire cluster nearest the camp, with the ice axe, Kael beside it.
	var best := Vector3.ZERO
	var best_d := INF
	for xf in sim_spires:
		var dd := Vector2(xf.origin.x, xf.origin.z).distance_to(camp)
		if dd < best_d:
			best_d = dd
			best = xf.origin
	var toward := (camp - Vector2(best.x, best.z)).normalized()
	var k := Vector2(best.x, best.z) + toward * 11.0
	var ky := ground_at(k.x, k.y)
	var side := Vector2(-toward.y, toward.x)
	out.append({"name": "spire_axe", "from": Vector3(k.x + toward.x * 10.0 + side.x * 5.0, ky + 3.0, k.y + toward.y * 10.0 + side.y * 5.0),
		"at": Vector3(best.x, ky + 6.0, best.z), "fov": 55.0, "kael": [k, atan2(-toward.x, -toward.y) + 0.4], "times": ["day", "night"]})
	# Shelf Cliffs: the shelf nearest the landmark, from below and in front.
	var sbest := sim_shelves[0]
	for xf in sim_shelves:
		if Vector2(xf.origin.x, xf.origin.z).distance_to(Vector2(-500, -700)) < Vector2(sbest.origin.x, sbest.origin.z).distance_to(Vector2(-500, -700)):
			sbest = xf
	var outx := sbest.basis.orthonormalized() * Vector3(1, 0, 0)
	var sc := sbest.origin + outx * 45.0 + Vector3(0, -10.0, 0)
	out.append({"name": "shelf_cliffs", "from": Vector3(sc.x + 12.0, maxf(sc.y, ground_at(sc.x, sc.z) + 4.0), sc.z + 12.0),
		"at": sbest.origin + Vector3(0, -3.0, 0), "fov": 55.0, "times": ["day", "night"]})
	return out


## About 20 s: low along the valley through a spire cluster, past the camp,
## up the cliffs over the shelves, a climb to circle the Ice Crown.
func flight() -> Array[Dictionary]:
	var pts: Array[Dictionary] = []
	var lift := func(p: Vector2, h: float) -> Vector3: return Vector3(p.x, ground_at(p.x, p.y) + h, p.y)
	pts.append({"from": lift.call(valley_point(190.0, 4.0), 9.0), "at": lift.call(valley_point(120.0, -6.0), 4.0), "fov": 58.0})
	pts.append({"from": lift.call(valley_point(140.0, -4.0), 6.0), "at": lift.call(valley_point(80.0, -14.0), 3.0), "fov": 58.0})
	pts.append({"from": lift.call(valley_point(95.0, -10.0), 4.5), "at": lift.call(camp, 1.0), "fov": 58.0})
	pts.append({"from": lift.call(valley_point(62.0, -14.0), 3.5), "at": lift.call(valley_point(10.0, -20.0), 1.5), "fov": 60.0})
	pts.append({"from": lift.call(valley_point(25.0, -6.0), 4.0), "at": lift.call(valley_point(-40.0, 2.0), 3.0), "fov": 60.0})
	pts.append({"from": lift.call(valley_point(-15.0, 4.0), 8.0), "at": Vector3(crown.x, crown.y - 70.0, crown.z), "fov": 58.0})
	pts.append({"from": lift.call(valley_point(-60.0, 10.0), 30.0), "at": Vector3(crown.x, crown.y - 40.0, crown.z), "fov": 56.0})
	pts.append({"from": Vector3(crown.x + 150.0, crown.y - 30.0, crown.z + 150.0), "at": Vector3(crown.x, crown.y, crown.z), "fov": 56.0})
	pts.append({"from": Vector3(crown.x + 140.0, crown.y + 10.0, crown.z - 40.0), "at": Vector3(crown.x, crown.y + 5.0, crown.z), "fov": 56.0})
	pts.append({"from": Vector3(crown.x + 70.0, crown.y + 30.0, crown.z - 120.0), "at": Vector3(crown.x, crown.y + 10.0, crown.z), "fov": 56.0})
	pts.append({"from": Vector3(crown.x - 40.0, crown.y + 50.0, crown.z - 130.0), "at": Vector3(crown.x, crown.y + 10.0, crown.z), "fov": 56.0})
	return pts


func flight_kael() -> Array:
	return [Vector2(-670, -530), PI * 0.8]
