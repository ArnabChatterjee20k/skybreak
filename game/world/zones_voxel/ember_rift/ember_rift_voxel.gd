class_name EmberRiftVoxel
extends VoxelZone
## Ember Rift in the voxel style (docs/lookdev/ember_rift.md), look v1, built
## on the voxel zone kit (game/world/voxel_zone_kit/README.md). The sim stays
## the truth: the ground is the baked TerrainHeightmap (TerrainShape._ember),
## the lava plane sits at the sim's 31 m, and every spire, vent and fissure
## comes from EmberRiftProps run as-is with WorldMap's seed and keep-clear
## circles (exactly what ZoneMatch builds with focus_zone = ember_rift).
##
## Tiers: T1 smooth ash around the duel floor, T2 smooth ash for the rest of
## the floor plus stepped crust banks and the columnar basalt inner wall, T3
## rim crowns and outer slopes (4.2 m blocks), T3 plume puffs.

const TERRAIN_SHADER := preload("res://game/world/zones_voxel/ember_rift/ember_terrain.gdshader")
const LAVA_SHADER := preload("res://game/world/zones_voxel/ember_rift/ember_lava.gdshader")
const D := EmberRiftDesigns
const LAVA_Y := 31.0
## Lava plane clip radius around the centre (WorldMap uses 215 m).
const LAVA_CLIP := 215.0
## T1 ash around the spawns and towards the vent (x, z, w, h).
const FINE_RECT := Rect2(600.0, -485.0, 120.0, 105.0)
## Columnar basalt: the plan width of one column (m).
const BASALT := 2.45
## Smooth (walkable) where the ground's slope is under this.
const SMOOTH_SLOPE := 0.5
const SPIRE_RANGES := [90.0, 280.0, 0.0]
const PROP_RANGES := [80.0, 0.0]
const GRID := 2.0

var hm: TerrainHeightmap
var layout: ZoneLayout
var zone: ZoneData
var shape: TerrainShape
var centre := Vector2.ZERO
var spawn_mid := Vector2.ZERO
var spires: Array[Transform3D] = []
var vents: Array[Transform3D] = []
var fissures: Array[Transform3D] = []
## Authored storytelling spots: name -> [Vector3 at, float yaw, extra].
var spots := {}
var geyser_vent := 0
var cracked_vent := 1
var terrain_materials: Array[ShaderMaterial] = []
var lava_material: ShaderMaterial
var fall_material: ShaderMaterial
var _grid_origin := Vector2.ZERO
var _grid_n := 0
var _lava_d := PackedFloat32Array()
var _slope := PackedFloat32Array()
var _blobs: Array[MultiMeshInstance3D] = []
var _puffs: Array[MultiMeshInstance3D] = []
var _lights: Array[OmniLight3D] = []
var _stage: VoxelStage
var _preset := ""
var _fields: Array[VoxelHeightfield] = []


func _init() -> void:
	name = "EmberRift"


func build() -> void:
	var t := Time.get_ticks_msec()
	hm = load(WorldMap.HEIGHTMAP_PATH)
	layout = ZoneLayout.load_default()
	zone = load("res://game/world/zones/ember_rift.tres")
	shape = TerrainShape.new(layout)
	centre = zone.centre
	for p in zone.spawn_points:
		spawn_mid += Vector2(p.x, p.z) / zone.spawn_points.size()
	lantern_materials.append(VoxelProp.materials()[VoxelProp.Surf.GLOW] as ShaderMaterial)
	var steps: Array[Callable] = [_placements, _grids, _story_spots, _terrain, _lava, _spires, _vents, _scatter,
		_story_props, _plume, _geyser, _breach_fall, _particles, _lava_lights]
	for step in steps:
		var s := Time.get_ticks_msec()
		step.call()
		stats["ms_" + step.get_method().trim_prefix("_")] = Time.get_ticks_msec() - s
	stats["ms_total"] = Time.get_ticks_msec() - t


func ground_at(x: float, z: float) -> float:
	return hm.ground_height_at(x, z)


## Runs the sim's prop builder with the game's seed and keep-clear circles.
func _placements() -> void:
	var kit := PropKit.new(hm, WorldMap.PROP_SEED)
	for z in layout.ground_zones():
		for p in z.spawn_points:
			kit.keep_clear.append(Vector3(p.x, p.z, WorldMap.SPAWN_CLEAR_RADIUS))
	var scratch := Node3D.new()
	EmberRiftProps.build(scratch, kit, zone, layout)
	spires.assign(scratch.get_node("ObsidianSpires").get_meta(PropKit.INSTANCE_TRANSFORMS_META))
	vents.assign(scratch.get_node("GeyserVents").get_meta(PropKit.INSTANCE_TRANSFORMS_META))
	fissures.assign(scratch.get_meta(EmberRiftProps.FISSURES_META))
	scratch.free()
	# The geyser beside the spawns erupts in the shots; the next one is cracked open.
	var order := range(vents.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return _vent_base(a).distance_to(Vector3(spawn_mid.x, 36, spawn_mid.y)) < _vent_base(b).distance_to(Vector3(spawn_mid.x, 36, spawn_mid.y)))
	geyser_vent = order[0]
	cracked_vent = order[1]
	stats["spires"] = spires.size()
	stats["vents"] = vents.size()
	stats["fissures"] = fissures.size()


func _vent_base(i: int) -> Vector3:
	return vents[i].origin - Vector3(0, 1.75, 0)


# ---------------------------------------------------------------- 2 m grids

## Distance to the nearest lava sample (m, chamfer) and the slope, on the
## heightmap's own 2 m samples around the zone.
func _grids() -> void:
	var half := 480.0
	_grid_origin = ((centre - Vector2(half, half)) / GRID).floor() * GRID
	_grid_n = int(2.0 * half / GRID) + 1
	var n := _grid_n
	var h := PackedFloat32Array()
	h.resize(n * n)
	_lava_d.resize(n * n)
	_slope.resize(n * n)
	for j in n:
		for i in n:
			var w := _grid_origin + Vector2(i, j) * GRID
			var y := hm.ground_height_at(w.x, w.y)
			h[i + j * n] = y
			_lava_d[i + j * n] = 0.0 if (y < LAVA_Y and w.distance_to(centre) < LAVA_CLIP) else 1.0e5
	for j in range(1, n - 1):
		for i in range(1, n - 1):
			var k := i + j * n
			_slope[k] = Vector2(h[k + 1] - h[k - 1], h[k + n] - h[k - n]).length() / (2.0 * GRID)
	var diag := GRID * 1.4142
	for j in range(1, n):
		for i in range(1, n - 1):
			var k := i + j * n
			_lava_d[k] = minf(_lava_d[k], minf(minf(_lava_d[k - 1] + GRID, _lava_d[k - n] + GRID),
				minf(_lava_d[k - n - 1] + diag, _lava_d[k - n + 1] + diag)))
	for j in range(n - 2, -1, -1):
		for i in range(n - 2, 0, -1):
			var k := i + j * n
			_lava_d[k] = minf(_lava_d[k], minf(minf(_lava_d[k + 1] + GRID, _lava_d[k + n] + GRID),
				minf(_lava_d[k + n + 1] + diag, _lava_d[k + n - 1] + diag)))


func _grid_at(arr: PackedFloat32Array, x: float, z: float) -> float:
	var f := (Vector2(x, z) - _grid_origin) / GRID
	var i := clampi(int(f.x), 0, _grid_n - 2)
	var j := clampi(int(f.y), 0, _grid_n - 2)
	var tx := clampf(f.x - i, 0.0, 1.0)
	var tz := clampf(f.y - j, 0.0, 1.0)
	var k := i + j * _grid_n
	return lerpf(lerpf(arr[k], arr[k + 1], tx), lerpf(arr[k + _grid_n], arr[k + _grid_n + 1], tx), tz)


func lava_distance(x: float, z: float) -> float:
	return _grid_at(_lava_d, x, z)


func slope_at(x: float, z: float) -> float:
	return _grid_at(_slope, x, z)


func rim_radius(x: float, z: float) -> float:
	var a := atan2(z - centre.y, x - centre.x)
	return 270.0 + 20.0 * sin(a * 3.0) + 10.0 * shape._low.get_noise_2d(x, z)


## Plan cell of the columnar basalt at (x, z): staggered rows (hex-ish).
func _basalt_site(x: float, z: float) -> Vector2:
	var row := floorf(z / BASALT)
	var off := BASALT * 0.5 if int(row) % 2 != 0 else 0.0
	var colm := floorf((x + off) / BASALT)
	return Vector2((colm + 0.5) * BASALT - off, (row + 0.5) * BASALT)


## The visible top at (x, z) (floor, basalt column or rim block), in metres.
func shown_top(x: float, z: float) -> float:
	var w := Vector2(x, z)
	var r := w.distance_to(centre)
	var rim := rim_radius(x, z)
	if r >= rim - 25.0:
		var b := (w / (T3 * 3.0)).floor() * T3 * 3.0 + Vector2.ONE * T3 * 1.5
		return roundi(hm.ground_height_at(b.x, b.y) / T3) * T3
	if r > rim - 105.0 and slope_at(x, z) >= SMOOTH_SLOPE:
		var s := _basalt_site(x, z)
		var jitter := (VoxelSdf.hash3(Vector3i(int(s.x * 10), 0, int(s.y * 10)), 17) - 0.5) * 0.7
		return roundi((hm.ground_height_at(s.x, s.y) + jitter) / T2) * T2
	return hm.ground_height_at(x, z)


# ---------------------------------------------------------------- spots

## Authored storytelling spots, found on the sim's ground near the sheet's
## intent and clear of spawns, vents (20 m), spires and fissures.
func _story_spots() -> void:
	# Survey bridge: the channel crossing nearest the duel floor, ~8-11 m.
	var best := INF
	for gz in range(-60, 61):
		for gx in range(-60, 61):
			var p := spawn_mid + Vector2(gx, gz) * 2.0 + Vector2(0, -20)
			if hm.ground_height_at(p.x, p.y) > 29.5:
				continue
			for k in 4:
				var d := Vector2.from_angle(k * PI / 4.0)
				var a := _bank(p, -d)
				var b := _bank(p, d)
				if a == Vector2.INF or b == Vector2.INF:
					continue
				var span := a.distance_to(b)
				if span < 7.0 or span > 12.0:
					continue
				var score := p.distance_to(spawn_mid) + absf(span - 9.0) * 4.0
				if score < best and p.distance_to(spawn_mid) > 25.0:
					best = score
					var mid := (a + b) * 0.5
					var deck := minf(hm.ground_height_at(a.x, a.y), hm.ground_height_at(b.x, b.y)) + 0.05
					spots["bridge"] = [Vector3(mid.x, deck, mid.y), -(b - a).angle(), span + 1.2]
	# Forge-shrine: on the floor towards the Rim Breach (angle 2.3).
	var dir := Vector2.from_angle(2.3)
	spots["shrine"] = _flat_spot(centre + dir * 150.0, 40.0, 6.0, dir)
	# Fallen spire fossil: a long flat strip on the floor east of the duel.
	spots["fallen"] = _flat_spot(centre + Vector2(95, 30), 60.0, 15.0, Vector2(1, 0.3).normalized())
	# Lava tubes: two short ones near the fissure field.
	spots["tube_a"] = _flat_spot(spawn_mid + Vector2(-48, 10), 25.0, 5.0, Vector2(1, 0.4).normalized())
	spots["tube_b"] = _flat_spot(spawn_mid + Vector2(52, -22), 25.0, 5.0, Vector2(0.3, 1).normalized())
	# Offering cairn: the highest flat block near the Crater Rim landmark.
	var top := -INF
	for gz in range(-12, 13):
		for gx in range(-12, 13):
			var p := Vector2(660, -790) + Vector2(gx, gz) * 2.5
			var y := shown_top(p.x, p.y)
			if y > top:
				top = y
				spots["cairn"] = [Vector3(p.x, y, p.y), 0.4, 0.0]


## Where the ground rises back above the lava along d from p (within 9 m).
func _bank(p: Vector2, d: Vector2) -> Vector2:
	for k in range(2, 10):
		var q := p + d * k
		if hm.ground_height_at(q.x, q.y) > 34.0 and slope_at(q.x, q.y) < 0.6:
			var q2 := q + d * 1.5
			return q2 if hm.ground_height_at(q2.x, q2.y) > 34.0 else Vector2.INF
	return Vector2.INF


## The flattest clear spot within `search` m of `near` for a footprint of
## half-length `half` along `dir`: [Vector3 at, yaw, 0].
func _flat_spot(near: Vector2, search: float, half: float, dir: Vector2) -> Array:
	var best := INF
	var out := [Vector3(near.x, hm.ground_height_at(near.x, near.y), near.y), -dir.angle(), 0.0]
	for gz in range(-int(search / 3.0), int(search / 3.0) + 1):
		for gx in range(-int(search / 3.0), int(search / 3.0) + 1):
			var p := near + Vector2(gx, gz) * 3.0
			if not _clear(p, half + 4.0):
				continue
			var lo := INF
			var hi := -INF
			for k in range(-2, 3):
				for side in [-1.0, 1.0]:
					var q: Vector2 = p + dir * (half * k / 2.0) + dir.orthogonal() * half * 0.4 * side
					var y := hm.ground_height_at(q.x, q.y)
					lo = minf(lo, y)
					hi = maxf(hi, y)
			if lo < 33.5:
				continue
			var score := (hi - lo) * 10.0 + p.distance_to(near) * 0.05
			if score < best:
				best = score
				out = [Vector3(p.x, lo, p.y), -dir.angle(), hi - lo]
	return out


func _clear(p: Vector2, radius: float) -> bool:
	for z in zone.spawn_points:
		if p.distance_to(Vector2(z.x, z.z)) < radius + 12.0:
			return false
	for i in vents.size():
		var b := _vent_base(i)
		if p.distance_to(Vector2(b.x, b.z)) < radius + 20.0:
			return false
	for s in spires:
		if p.distance_to(Vector2(s.origin.x, s.origin.z)) < radius + s.basis.x.length() * 0.5 + 4.0:
			return false
	for f in fissures:
		if p.distance_to(Vector2(f.origin.x, f.origin.z)) < radius + 4.0:
			return false
	return true


# ---------------------------------------------------------------- terrain

func _terrain() -> void:
	var quads := {}
	var fine := FINE_RECT
	# T1: smooth ash and stepped banks around the duel floor.
	var t1s := VoxelHeightfield.new(T1, fine.position, fine.end)
	var t1b := VoxelHeightfield.new(T1, fine.position, fine.end)
	t1s.smooth_height = ground_at
	var lava_floor := roundi((LAVA_Y - 1.5) / T1)
	for z in t1s.size.y:
		for x in t1s.size.x:
			var w := t1s.centre(x, z)
			var h := hm.ground_height_at(w.x, w.y)
			if h < LAVA_Y - 0.2:
				continue
			var col := _floor_colour(w, h)
			if slope_at(w.x, w.y) < SMOOTH_SLOPE:
				t1s.set_column(x, z, roundi(h / T1), lava_floor, col)
			else:
				t1b.set_column(x, z, roundi(h / T1), lava_floor, col)
	# T2: the rest of the floor (smooth), banks (stepped) and the basalt wall.
	var lo := centre - Vector2(300, 300)
	var hi := centre + Vector2(300, 300)
	var t2s := VoxelHeightfield.new(T2, lo, hi)
	var t2b := VoxelHeightfield.new(T2, lo, hi)
	t2s.smooth_height = ground_at
	var lava_floor2 := roundi((LAVA_Y - 1.5) / T2)
	var basalt := D.COLORS[D.Mat.BASALT] as Color
	var ash := D.COLORS[D.Mat.ASH] as Color
	for z in t2s.size.y:
		for x in t2s.size.x:
			var w := t2s.centre(x, z)
			if fine.has_point(w):
				continue
			var r := w.distance_to(centre)
			if r > 300.0:
				continue
			var rim := rim_radius(w.x, w.y)
			if r >= rim - 25.0:
				continue
			var h := hm.ground_height_at(w.x, w.y)
			if h < LAVA_Y - 0.2 and r < LAVA_CLIP:
				continue
			var s := slope_at(w.x, w.y)
			if s < SMOOTH_SLOPE:
				t2s.set_column(x, z, roundi(h / T2), lava_floor2, _floor_colour(w, h))
			elif r > rim - 105.0:
				var top := shown_top(w.x, w.y)
				var site := _basalt_site(w.x, w.y)
				var k := VoxelSdf.hash3(Vector3i(int(site.x * 10), 1, int(site.y * 10)), 19)
				var c := basalt.lerp(ash, 0.25 + 0.35 * k * clampf(1.6 - s, 0.0, 1.0))
				c *= 0.92 + 0.12 * k
				c.a = clampf(1.0 - lava_distance(w.x, w.y) / 14.0, 0.0, 1.0)
				t2b.set_column(x, z, roundi(top / T2), roundi((top - 10.0) / T2), c)
			else:
				t2b.set_column(x, z, roundi(h / T2), lava_floor2, _floor_colour(w, h))
	# T3: rim crowns and outer slopes in 4.2 m blocks.
	var t3 := VoxelHeightfield.new(T3, centre - Vector2(470, 470), centre + Vector2(470, 470))
	var obsidian := D.COLORS[D.Mat.OBSIDIAN] as Color
	for z in t3.size.y:
		for x in t3.size.x:
			var w := t3.centre(x, z)
			var r := w.distance_to(centre)
			var rim := rim_radius(w.x, w.y)
			if r < rim - 25.0 or r > rim + 190.0:
				continue
			var top := shown_top(w.x, w.y)
			var b := (w / (T3 * 3.0)).floor()
			var k := VoxelSdf.hash3(Vector3i(int(b.x), 2, int(b.y)), 23)
			# Crown: obsidian, ash-dusted on flatter tops; outer slopes ash-grey.
			var crown := clampf(1.0 - absf(r - rim) / 40.0, 0.0, 1.0)
			var c := ash.darkened(0.45).lerp(obsidian.lightened(0.15), crown)
			c = c.lerp(ash.darkened(0.15), 0.3 * k * (1.0 - crown))
			c *= 0.9 + 0.15 * k
			c.a = 0.0
			t3.set_column(x, z, roundi(top / T3), roundi(top / T3) - 30, c)
	_spot_paint(t1s)
	_spot_paint(t1b)
	_spot_paint(t2s)
	_spot_paint(t2b)
	_fields = [t1s, t1b, t2s, t2b, t3]
	var specs := [[t1s, "AshFine", 0.0, false], [t1b, "BanksFine", 0.0, true], [t2s, "Ash", 0.0, false],
		[t2b, "WallBasalt", 0.0, true], [t3, "RimCrown", 0.0, true]]
	for spec: Array in specs:
		var hf: VoxelHeightfield = spec[0]
		var mat := _terrain_material(hf, spec[1] == "RimCrown")
		var node := hf.build(self, mat, spec[1], spec[2], spec[3])
		quads[spec[1]] = VoxelHeightfield.count_quads(node)
	stats["terrain_quads"] = quads


func _terrain_material(hf: VoxelHeightfield, rim: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	hf.bind(mat)
	mat.set_shader_parameter("cap_from", 112.0 if rim else 125.0)
	mat.set_shader_parameter("joint_metres", 4.0 if rim else 1.3)
	mat.set_shader_parameter("noise_amount", 0.03 if hf.smooth_height.is_valid() else 0.05)
	terrain_materials.append(mat)
	return mat


## The ash floor's colour at w: pale ash, wind ripples running across the
## north-east drift, drifts, pumice pebbles, crusted banks near lava, darker
## low ground; alpha carries the baked lava bounce.
func _floor_colour(w: Vector2, h: float) -> Color:
	var ash := Color("#A8A09C")
	var ridge := Color("#BDB6B0")
	var crust := Color("#4A3028")
	var q := w.dot(Vector2(0.6, 0.8))
	var wob := shape._low.get_noise_2d(w.x * 3.0, w.y * 3.0) * 4.0
	var v := fposmod(q * 0.42 + wob, 1.0)
	var c := ash
	if v < 0.14:
		c = ridge
	elif v > 0.55 and v < 0.68:
		c = ash * 0.95
	var drift := shape._detail.get_noise_2d(w.x * 0.6, w.y * 0.6)
	c = c.lerp(ridge, smoothstep(0.25, 0.7, drift) * 0.5)
	c = c.lerp(Color("#857C7C"), smoothstep(-0.3, -0.7, drift) * 0.35)
	var cell := Vector3i(floori(w.x / T1), 0, floori(w.y / T1))
	if VoxelSdf.hash3(cell, 13) < 0.025:
		c = Color("#5A504C")
	var d := lava_distance(w.x, w.y)
	c = c.lerp(crust, clampf(1.0 - (d - 1.0) / 3.5, 0.0, 1.0) * 0.85)
	c = c.lerp(Color("#6E6668"), clampf((34.5 - h) / 3.0, 0.0, 1.0) * 0.5)
	c.a = clampf(1.0 - d / 12.0, 0.0, 1.0)
	return c


## Local paint over a field: spire-foot AO, scorch rings and the sulphur fan
## around vents, crust aprons around the fissure strips.
func _spot_paint(hf: VoxelHeightfield) -> void:
	for s in spires:
		var base := s.origin - s.basis.y * 2.5
		var r := s.basis.x.length() * 0.5
		_paint_disc(hf, Vector2(base.x, base.z), r + 5.0, func(c: Color, d: float, _w: Vector2) -> Color:
			var k := clampf(1.0 - (d - r) / 5.0, 0.0, 1.0)
			return Color(c.r * (1.0 - 0.4 * k), c.g * (1.0 - 0.42 * k), c.b * (1.0 - 0.38 * k), c.a))
	for i in vents.size():
		var b := _vent_base(i)
		var vc := Vector2(b.x, b.z)
		var cracked := i == cracked_vent
		_paint_disc(hf, vc, 20.0, func(c: Color, d: float, w: Vector2) -> Color:
			var out := c
			var ring := clampf(1.0 - absf(d - 6.0) / 3.5, 0.0, 1.0)
			out = out.lerp(Color("#3A302E"), ring * 0.65)
			if d < 4.8:
				out = out.lerp(Color("#2A1A16"), 0.7)
			if cracked:
				var rel := w - vc
				if rel.x > 3.0 and absf(rel.y) < rel.x * 0.45:
					var fan := clampf(1.0 - d / 19.0, 0.0, 1.0) * (1.0 - absf(rel.y) / (rel.x * 0.45))
					if VoxelSdf.hash3(Vector3i(floori(w.x / 0.35), 0, floori(w.y / 0.35)), 14) < fan * 1.3:
						out = out.lerp(Color("#C8BC70"), 0.75)
			out.a = maxf(c.a, clampf(1.0 - d / 10.0, 0.0, 1.0) * 0.6)
			return out)
	for f in fissures:
		var along := f.basis.x.normalized()
		var across := f.basis.z.normalized()
		var o := Vector2(f.origin.x, f.origin.z)
		var ax := Vector2(along.x, along.z)
		var az := Vector2(across.x, across.z)
		var half := Vector2(EmberRiftProps.FISSURE_LENGTH * 0.5 + 0.5, EmberRiftProps.FISSURE_WIDTH * 0.5 + 0.6)
		_paint_disc(hf, o, half.length(), func(c: Color, _d: float, w: Vector2) -> Color:
			var rel := w - o
			var u := absf(rel.dot(ax))
			var v := absf(rel.dot(az))
			if u > half.x or v > half.y:
				return c
			var out := c.lerp(Color("#4A3028"), 0.8 if v < half.y - 0.4 else 0.45)
			out.a = maxf(c.a, 0.7)
			return out)


func _paint_disc(hf: VoxelHeightfield, at: Vector2, radius: float, fn: Callable) -> void:
	var x0 := maxi(0, floori((at.x - radius - hf.origin.x) / hf.cell))
	var x1 := mini(hf.size.x - 1, ceili((at.x + radius - hf.origin.x) / hf.cell))
	var z0 := maxi(0, floori((at.y - radius - hf.origin.y) / hf.cell))
	var z1 := mini(hf.size.y - 1, ceili((at.y + radius - hf.origin.y) / hf.cell))
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var i := hf.index(x, z)
			if hf.shown[i] == VoxelHeightfield.NONE:
				continue
			var w := hf.centre(x, z)
			var d := w.distance_to(at)
			if d > radius:
				continue
			var k := i * 4
			var c := Color(hf.colours[k] / 255.0, hf.colours[k + 1] / 255.0, hf.colours[k + 2] / 255.0, hf.colours[k + 3] / 255.0)
			hf.set_colour(x, z, fn.call(c, d, w))


# ---------------------------------------------------------------- lava

## The lava plane at the sim's height, voxel crust cells, plus the sim's
## fissure strips as extra instances (custom r = 1), one draw call.
func _lava() -> void:
	lava_material = ShaderMaterial.new()
	lava_material.shader = LAVA_SHADER
	lava_material.set_shader_parameter("clip_centre", Vector3(centre.x, LAVA_Y, centre.y))
	lava_material.set_shader_parameter("clip_radius", LAVA_CLIP + 10.0)
	lava_material.set_shader_parameter("vent", centre)
	var xfs: Array[Transform3D] = [Transform3D(Basis.from_scale(Vector3(480, 1, 480)), Vector3(centre.x, LAVA_Y, centre.y))]
	xfs.append_array(fissures)
	var unit := PlaneMesh.new()
	unit.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = unit
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_custom_data(i, Color(0.0 if i == 0 else 1.0, 0, 0, 0))
	var node := MultiMeshInstance3D.new()
	node.name = "Lava"
	node.multimesh = mm
	node.material_override = lava_material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


# ---------------------------------------------------------------- props

func _spires() -> void:
	var lists := []
	for v in D.SPIRES.size():
		lists.append(_xfs())
	for s in spires:
		var base := s.origin - s.basis.y * 2.5
		var r := s.basis.x.length() * 0.5
		var h := s.basis.y.length() * EmberRiftProps.SPIRE_MESH_HEIGHT
		var best := 0
		var score := INF
		for v in D.SPIRES.size():
			var vr: float = D.SPIRES[v][0]
			var vh: float = D.SPIRES[v][1]
			var e := absf(log((h / r) / (vh / vr))) + 0.4 * absf(log(r / vr))
			if e < score:
				score = e
				best = v
		var rot := s.basis.orthonormalized()
		var vr2: float = D.SPIRES[best][0]
		var vh2: float = D.SPIRES[best][1]
		(lists[best] as Array[Transform3D]).append(Transform3D(rot * Basis.from_scale(Vector3(r / vr2, h / vh2, r / vr2)), base))
	var quads := 0
	for v in D.SPIRES.size():
		var tiers: Array[ArrayMesh] = [D.spire(v, T2), D.spire(v, T2 * 2.0), D.spire(v, T3)]
		VoxelProp.place(self, "Spires%d" % v, tiers, SPIRE_RANGES, lists[v], 2)
		quads += VoxelProp.quads(tiers[0]) * (lists[v] as Array).size()
	stats["spire_quads_near"] = quads


func _vents() -> void:
	var lists: Array = [_xfs(), _xfs()]
	var crystals: Array = [_xfs(), _xfs()]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4243
	for i in vents.size():
		var b := _vent_base(i)
		var v := 1 if i == cracked_vent else 0
		(lists[v] as Array[Transform3D]).append(Transform3D(Basis(), b))
		for k in 10:
			var a := rng.randf() * TAU
			var on_rim := k < 6
			var rr := rng.randf_range(2.0, 2.9) if on_rim else rng.randf_range(4.7, 5.6)
			var y := b.y + 3.35 if on_rim else hm.ground_height_at(b.x + cos(a) * rr, b.z + sin(a) * rr)
			(crystals[k % 2] as Array[Transform3D]).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(b.x + cos(a) * rr, y, b.z + sin(a) * rr)))
	var quads := 0
	for v in 2:
		var tiers: Array[ArrayMesh] = [D.vent(v, T1), D.vent(v, T1 * 4.0)]
		VoxelProp.place(self, "Vents%d" % v, tiers, [90.0, 0.0], lists[v], 1)
		quads += VoxelProp.quads(tiers[0]) * (lists[v] as Array).size()
		var one: Array[ArrayMesh] = [D.sulphur(v, T0)]
		VoxelProp.place(self, "Sulphur%d" % v, one, [40.0], crystals[v], 0)
	stats["vent_quads_near"] = quads


## Pumice boulders and ash-floor clutter, obsidian shards at spire feet,
## crust rafts on the pool and channels, survey stakes towards the vent.
func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4244
	var boulders: Array = [_xfs(), _xfs(), _xfs()]
	var tries := 0
	var placed := 0
	while placed < 150 and tries < 6000:
		tries += 1
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 175.0
		var p := centre + Vector2.from_angle(a) * d
		var h := hm.ground_height_at(p.x, p.y)
		if h < 33.5 or slope_at(p.x, p.y) > 0.35 or not _clear(p, 1.5):
			continue
		var s := rng.randf_range(0.7, 1.4)
		(boulders[placed % 3] as Array[Transform3D]).append(Transform3D(
			Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, h - 0.15, p.y)))
		placed += 1
	for v in 3:
		VoxelProp.place(self, "Pumice%d" % v, _meshes([D.boulder(v, T1), D.boulder(v, T1 * 4.0)]), PROP_RANGES, boulders[v], 1)
	var shards: Array = [_xfs(), _xfs(), _xfs()]
	var n := 0
	for sp in spires:
		var base := sp.origin - sp.basis.y * 2.5
		var r := sp.basis.x.length() * 0.5
		for k in 7:
			var a := rng.randf() * TAU
			var p := Vector2(base.x, base.z) + Vector2.from_angle(a) * (r + rng.randf_range(0.5, 4.0))
			var h := hm.ground_height_at(p.x, p.y)
			if h < LAVA_Y + 0.3:
				continue
			(shards[n % 3] as Array[Transform3D]).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, h - 0.03, p.y)))
			n += 1
	for v in 3:
		VoxelProp.place(self, "Shards%d" % v, _meshes([D.shard(v, T0)]), [45.0], shards[v], 0)
	# Rafts on the central pool and in channels near the duel.
	var rafts: Array = [_xfs(), _xfs(), _xfs()]
	n = 0
	tries = 0
	while n < 26 and tries < 3000:
		tries += 1
		var p := centre + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * (22.0 if n < 12 else 150.0)
		if hm.ground_height_at(p.x, p.y) > LAVA_Y - 2.5 or lava_distance(p.x, p.y) > 0.5:
			continue
		var s := rng.randf_range(0.7, 1.2)
		(rafts[n % 3] as Array[Transform3D]).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, 1, s)), Vector3(p.x, LAVA_Y + 0.02, p.y)))
		n += 1
	for v in 3:
		VoxelProp.place(self, "Rafts%d" % v, _meshes([D.raft(v, T1), D.raft(v, T1 * 4.0)]), [120.0, 0.0], rafts[v], 0)
	# Survey stakes in a line from the duel floor towards the vent; the last melted.
	var stakes: Array = [_xfs(), _xfs()]
	var from := spawn_mid + Vector2(7.0, -14.0)
	var to := centre + Vector2(7.0, 24.0)
	var count := int(from.distance_to(to) / 5.0)
	for k in count:
		var p := from.lerp(to, float(k) / float(count - 1)) + Vector2(rng.randf_range(-0.3, 0.3), 0)
		var h := hm.ground_height_at(p.x, p.y)
		if h < LAVA_Y + 0.5:
			continue
		var melted := lava_distance(p.x, p.y) < 6.0 or k >= count - 3
		(stakes[1 if melted else 0] as Array[Transform3D]).append(Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3) + PI), Vector3(p.x, h, p.y)))
	for v in 2:
		VoxelProp.place(self, "Stakes%d" % v, _meshes([D.stake(v == 1)]), [55.0], stakes[v], 1)
	stats["boulders"] = placed
	stats["shards"] = n


func _story_props() -> void:
	for key: String in ["shrine", "fallen", "tube_a", "tube_b", "bridge", "cairn"]:
		if not spots.has(key):
			continue
		var s: Array = spots[key]
		var at: Vector3 = s[0]
		var m: ArrayMesh
		var shadow := true
		match key:
			"shrine":
				m = D.shrine()
			"fallen":
				m = D.fallen_spire()
				at.y -= 0.6
			"tube_a", "tube_b":
				m = D.lava_tube(T1)
				at.y -= 0.1
			"bridge":
				m = D.bridge(float(s[2]))
			"cairn":
				m = D.cairn()
		var mi := MeshInstance3D.new()
		mi.name = key.capitalize().replace(" ", "")
		mi.mesh = m
		mi.position = at
		mi.rotation.y = float(s[1]) + (PI * 0.5 if key == "shrine" else 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 400.0
		add_child(mi)
		stats["quads_" + key] = VoxelProp.quads(m)


# ---------------------------------------------------------------- motion

## The smoke plume: T3 puffs rising from the vent, drifting north-east and
## growing; animate() lifts them along the column.
func _plume() -> void:
	for v in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = D.puff(v)
		mm.instance_count = 14
		var node := MultiMeshInstance3D.new()
		node.name = "Plume%d" % v
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_puffs.append(node)
	_place_puffs(0.0)


func _place_puffs(t: float) -> void:
	for v in _puffs.size():
		var mm := _puffs[v].multimesh
		for k in mm.instance_count:
			var i := k * 3 + v
			var u := fposmod(float(i) / 42.0 + t * 0.006, 1.0)
			var y := 40.0 + u * 330.0
			var drift := Vector2(110.0, -85.0) * pow(u, 1.4)
			var wob := Vector2(sin(i * 2.3) * 9.0, cos(i * 1.7) * 9.0) * (0.3 + u)
			var s := 0.55 + u * 2.4
			mm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, i * 1.9).scaled(Vector3(s, s * 0.85, s)),
				Vector3(centre.x + drift.x + wob.x, y, centre.y + drift.y + wob.y)))


## The erupting geyser beside the spawns: a 25 m column of molten blobs and
## falling droplets (always erupting in the look-dev).
func _geyser() -> void:
	for v in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = D.blob(v)
		mm.instance_count = 36
		var node := MultiMeshInstance3D.new()
		node.name = "Geyser%d" % v
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_blobs.append(node)
	_place_blobs(0.0)


func _place_blobs(t: float) -> void:
	var b := _vent_base(geyser_vent) + Vector3(0, 2.6, 0)
	for v in _blobs.size():
		var mm := _blobs[v].multimesh
		for k in mm.instance_count:
			var i := k * 2 + v
			var u := fposmod(float(i) / 72.0 + t * 0.55, 1.0)
			var a := i * 2.399
			var spread := 0.6 + 4.5 * smoothstep(0.55, 1.0, u)
			# Up the column, then out and down as droplets.
			var y := 25.0 * sin(minf(u / 0.62, 1.0) * PI * 0.5) - 30.0 * pow(maxf(u - 0.62, 0.0), 2.0)
			var s := (1.25 - u * 0.7) * (0.8 + 0.4 * fposmod(i * 0.618, 1.0))
			var p := b + Vector3(cos(a) * spread, maxf(y, -1.5), sin(a) * spread)
			mm.set_instance_transform(k, Transform3D(Basis(Vector3(0.3, 1, 0.2).normalized(), i + t * 3.0).scaled(Vector3.ONE * s), p))


## The Rim Breach lava fall: a stepped cascade of glowing cells down the
## inner wall from the notch, riding the basalt steps (T2).
func _breach_fall() -> void:
	var notch := Vector2(zone.landmark_positions[2].x, zone.landmark_positions[2].z)
	var dir := (centre - notch).normalized()
	var length := 0.0
	var foot := notch
	for k in 200:
		var p := notch + dir * k
		if hm.ground_height_at(p.x, p.y) < 37.0:
			foot = p
			length = k
			break
	if length <= 0.0:
		return
	var lo := Vector2(minf(notch.x, foot.x), minf(notch.y, foot.y)) - Vector2(12, 12)
	var hi := Vector2(maxf(notch.x, foot.x), maxf(notch.y, foot.y)) + Vector2(12, 12)
	var hf := VoxelHeightfield.new(T2, lo, hi)
	var side := dir.orthogonal()
	for z in hf.size.y:
		for x in hf.size.x:
			var w := hf.centre(x, z)
			var rel := w - notch
			var t := rel.dot(dir)
			if t < 0.0 or t > length:
				continue
			var wobble := 2.0 * sin(t * 0.09) + 1.2 * sin(t * 0.31)
			var width := 3.2 + 3.5 * smoothstep(length - 25.0, length, t)
			if absf(rel.dot(side) - wobble) > width:
				continue
			var top := shown_top(w.x, w.y) + T2
			hf.set_column(x, z, roundi(top / T2), roundi(top / T2) - 4, Color(1, 0.6, 0.2, 0))
	fall_material = ShaderMaterial.new()
	fall_material.shader = TERRAIN_SHADER
	hf.bind(fall_material)
	fall_material.set_shader_parameter("lava_mode", true)
	var node := hf.build(self, fall_material, "BreachFall", 0.0, false)
	stats["quads_breach_fall"] = VoxelHeightfield.count_quads(node)
	spots["breach_foot"] = [Vector3(foot.x, hm.ground_height_at(foot.x, foot.y), foot.y), 0.0, 0.0]


## Ash fall (grey flakes, most) and sparks (few) over the duel floor, and
## sparks rising off the vent pool. Voxel cubes, sparse near the camera.
func _particles() -> void:
	var specs := [
		["AshFall", Vector3(spawn_mid.x, 70, spawn_mid.y - 40), Vector3(110, 35, 110), 2400, 14.0, Color("#9a9290"), 0.0, Vector3(0.6, -1.0, -0.4), 0.05],
		["Sparks", Vector3(centre.x, 36, centre.y), Vector3(22, 3, 22), 500, 5.0, Color("#FFB040"), 4.0, Vector3(0.2, 1.0, -0.15), 0.035],
		["GeyserSparks", _vent_base(geyser_vent) + Vector3(0, 4, 0), Vector3(2, 2, 2), 220, 2.5, Color("#FFC060"), 4.0, Vector3(0, 1, 0), 0.03],
	]
	for s: Array in specs:
		var p := GPUParticles3D.new()
		p.name = s[0]
		p.amount = s[3]
		p.lifetime = s[4]
		p.preprocess = s[4]
		p.position = s[1]
		p.visibility_aabb = AABB(-s[2] * 2.0 - Vector3(0, 40, 0), s[2] * 4.0 + Vector3(0, 80, 0))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = s[2]
		pm.direction = s[7]
		pm.spread = 25.0
		pm.initial_velocity_min = 0.6 if s[6] == 0.0 else 3.0
		pm.initial_velocity_max = 1.4 if s[6] == 0.0 else 7.0
		pm.gravity = Vector3(0, -0.4, 0) if s[6] == 0.0 else Vector3(0, 0.6, 0)
		pm.angle_max = 180.0
		p.process_material = pm
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * float(s[8])
		var m := StandardMaterial3D.new()
		m.albedo_color = s[5]
		if s[6] > 0.0:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(s[5]) * float(s[6])
		cube.material = m
		p.draw_pass_1 = cube
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)


## At most 4 lava lights, amber, no shadows: the vent pool, the geyser, the
## Breach fall's foot. Energy per preset in animate().
func _lava_lights() -> void:
	var places: Array[Vector3] = [Vector3(centre.x, 38, centre.y), _vent_base(geyser_vent) + Vector3(0, 6, 0)]
	if spots.has("breach_foot"):
		places.append((spots["breach_foot"][0] as Vector3) + Vector3(0, 5, 0))
	var ranges := [75.0, 32.0, 45.0]
	for i in places.size():
		var l := OmniLight3D.new()
		l.position = places[i]
		l.omni_range = ranges[i]
		l.omni_attenuation = 1.4
		l.light_color = Color("#FF9A40")
		l.shadow_enabled = false
		add_child(l)
		_lights.append(l)


func presets() -> Dictionary:
	var p := VoxelStage.PRESETS.duplicate(true)
	p.day.merge({
		"sky_top": Color("#6C7688"), "sky_horizon": Color("#BCB2AA"), "sky_below": Color("#8A8280"),
		"cloud": Color("#CCC4BE"), "cloud_shadow": Color("#8C8488"), "cloud_cover": 0.5,
		"sun_dir": Vector3(-0.41, -0.76, 0.51), "sun_color": Color("#FFE6CC"), "sun_energy": 2.3, "sun_size": 0.02,
		"rim_color": Color("#FFE0C8"), "rim_energy": 0.4,
		"ambient_color": Color("#A89A98"), "ambient_energy": 0.55,
		"fog_color": Color("#8A8282"), "fog_density": 0.0011, "exposure": 0.95, "lantern": 0.5, "name": "day",
	}, true)
	p.dusk.merge({
		"sky_top": Color("#3C3450"), "sky_horizon": Color("#B87458"), "sky_below": Color("#5E4844"),
		"cloud": Color("#C88C74"), "cloud_shadow": Color("#54404C"), "cloud_cover": 0.5,
		"sun_dir": Vector3(-0.86, -0.25, 0.45), "sun_color": Color("#FFB084"), "sun_energy": 2.0, "sun_size": 0.035,
		"rim_color": Color("#FFC4A0"), "rim_energy": 0.5,
		"ambient_color": Color("#7C6670"), "ambient_energy": 0.5,
		"fog_color": Color("#8A6A5A"), "fog_density": 0.0013, "exposure": 1.0, "lantern": 0.9, "name": "dusk",
	}, true)
	p.night.merge({
		"sky_top": Color("#2A2230"), "sky_horizon": Color("#5A3A3A"), "sky_below": Color("#2A1E20"),
		"cloud": Color("#6A4438"), "cloud_shadow": Color("#2A2028"), "cloud_cover": 0.55,
		"sun_dir": Vector3(0.31, -0.72, 0.62), "sun_color": Color("#E89078"), "sun_energy": 0.45, "sun_size": 0.0,
		"moon": false, "stars": 0.12,
		"rim_color": Color("#FFB890"), "rim_energy": 0.45,
		"ambient_color": Color("#2A2430"), "ambient_energy": 0.75,
		"fog_color": Color("#3A2A2C"), "fog_density": 0.0014, "exposure": 1.25, "lantern": 1.3, "name": "night",
	}, true)
	return p


## Per-preset lava strength: [lava glow, day light on crust, bounce, lights].
const LAVA_BY_PRESET := {
	"day": [0.85, 1.0, 0.15, 0.5], "dusk": [1.0, 0.55, 0.45, 1.4], "night": [1.25, 0.15, 1.1, 2.6],
}


func animate(t: float) -> void:
	if _stage == null and get_parent() != null:
		for n in get_parent().get_children():
			if n is VoxelStage:
				_stage = n
				_stage.env.glow_intensity = 0.5
				_stage.env.fog_height = 48.0
				_stage.env.fog_height_density = 0.012
	if _stage != null and _stage.current.get("name", "") != _preset:
		_preset = _stage.current.get("name", "dusk")
		var k: Array = LAVA_BY_PRESET.get(_preset, LAVA_BY_PRESET.dusk)
		lava_material.set_shader_parameter("glow", k[0])
		lava_material.set_shader_parameter("day_light", k[1])
		for m in terrain_materials:
			m.set_shader_parameter("bounce_energy", k[2])
			m.set_shader_parameter("lava_glow", k[0])
		if fall_material != null:
			fall_material.set_shader_parameter("lava_glow", k[0] * 1.3)
		for l in _lights:
			l.light_energy = k[3]
	lava_material.set_shader_parameter("time_s", t)
	if fall_material != null:
		fall_material.set_shader_parameter("time_s", t)
	_place_puffs(t)
	_place_blobs(t)


# ---------------------------------------------------------------- shots

func shots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var vb := _vent_base(geyser_vent)
	var to_vent := (Vector2(vb.x, vb.z) - spawn_mid).normalized()
	var perp := to_vent.orthogonal()
	var gcam := Vector2(vb.x, vb.z) - to_vent * 26.0 + perp * 9.0
	var gk := Vector2(vb.x, vb.z) - to_vent * 11.0 + perp * 3.0
	out.append({"name": "vent_plume", "from": Vector3(708, 46, -452), "at": Vector3(660, 70, -522), "fov": 58.0,
		"kael": [Vector2(690, -466), PI * 0.8], "times": ["night", "dusk", "day"]})
	out.append({"name": "geyser", "from": Vector3(gcam.x, ground_at(gcam.x, gcam.y) + 4.0, gcam.y),
		"at": vb + Vector3(0, 9, 0), "fov": 55.0, "kael": [gk, -to_vent.angle() - PI * 0.5], "times": ["night", "dusk"]})
	var notch: Vector3 = zone.landmark_positions[2]
	var bdir := (centre - Vector2(notch.x, notch.z)).normalized()
	var bcam := Vector2(notch.x, notch.z) + bdir * 175.0 + bdir.orthogonal() * 30.0
	out.append({"name": "breach", "from": Vector3(bcam.x, 52, bcam.y), "at": Vector3(notch.x, 52, notch.z), "fov": 50.0,
		"times": ["dusk", "night"]})
	if spots.has("shrine"):
		var sh: Vector3 = spots["shrine"][0]
		var yaw: float = spots["shrine"][1] + PI * 0.5
		var front := Vector3(sin(yaw), 0, cos(yaw))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var cam := sh + front * 9.0 + right * 4.5 + Vector3(0, 2.6, 0)
		var k := sh + front * 3.6 + right * 1.6
		out.append({"name": "shrine", "from": cam, "at": sh + Vector3(0, 1.2, 0) + front * 0.5, "fov": 48.0,
			"kael": [Vector2(k.x, k.z), atan2(-front.x, -front.z) + PI + 0.5], "times": ["dusk", "night"]})
	if spots.has("bridge"):
		var br: Vector3 = spots["bridge"][0]
		var byaw: float = spots["bridge"][1]
		var along := Vector3(cos(-byaw), 0, sin(-byaw))
		var across := Vector3(-along.z, 0, along.x)
		var kp := br - along * float(spots["bridge"][2]) * 0.32
		out.append({"name": "bridge", "from": br + across * 9.0 - along * 3.0 + Vector3(0, 1.5, 0), "at": br + Vector3(0, -0.4, 0),
			"fov": 52.0, "kael": [Vector2(kp.x, kp.z), byaw - PI * 0.5], "kael_y": br.y - 0.2, "times": ["dusk"]})
	var sp := _spire_cluster()
	out.append({"name": "spire_forest", "from": Vector3(sp.x, ground_at(sp.x, sp.z) + 1.7, sp.z),
		"at": Vector3(sp.x, 0, sp.z) + _spire_look(sp), "fov": 62.0, "times": ["day", "dusk"]})
	out.append({"name": "overview", "from": Vector3(660, 205, -815), "at": Vector3(655, 40, -470), "fov": 60.0,
		"times": ["day", "dusk", "night"]})
	var sp0: Vector3 = zone.spawn_points[0]
	out.append({"name": "kael_floor", "from": Vector3(sp0.x - 2.5, ground_at(sp0.x, sp0.z) + 3.4, sp0.z + 7.0),
		"at": Vector3(sp0.x + 4.0, ground_at(sp0.x, sp0.z) + 2.0, sp0.z - 12.0), "fov": 62.0,
		"kael": [Vector2(sp0.x, sp0.z), 0.15], "times": ["day", "dusk", "night"]})
	return out


## A floor spot with several spires around it (for the looking-up shot).
func _spire_cluster() -> Vector3:
	var best := Vector3(centre.x, 0, centre.y + 60)
	var most := -1.0
	for s in spires:
		var p := Vector2(s.origin.x, s.origin.z)
		var score := 0.0
		for o in spires:
			var d := p.distance_to(Vector2(o.origin.x, o.origin.z))
			if d < 45.0:
				score += o.basis.y.length() / (d + 8.0)
		if score > most and p.distance_to(centre) < 175.0:
			most = score
			best = s.origin
	# Stand a few metres off the spire's foot.
	var off := (Vector2(best.x, best.z) - centre).normalized() * -9.0
	return Vector3(best.x + off.x, 0, best.z + off.y)


func _spire_look(at: Vector3) -> Vector3:
	var sum := Vector3.ZERO
	for s in spires:
		var d := Vector2(s.origin.x - at.x, s.origin.z - at.z)
		if d.length() < 45.0:
			sum += Vector3(d.x, 0, d.y).normalized()
	var dir := sum.normalized() if sum.length() > 0.1 else Vector3(0, 0, -1)
	return dir * 20.0 + Vector3(0, ground_at(at.x, at.z) + 22.0, 0)


func flight() -> Array[Dictionary]:
	var vb := _vent_base(geyser_vent)
	var notch: Vector3 = zone.landmark_positions[2]
	return [
		{"from": Vector3(660, 240, -930), "at": Vector3(660, 130, -760), "fov": 60.0},
		{"from": Vector3(660, 200, -820), "at": Vector3(660, 70, -640), "fov": 60.0},
		{"from": Vector3(655, 140, -735), "at": Vector3(650, 45, -600), "fov": 60.0},
		{"from": Vector3(645, 80, -665), "at": Vector3(650, 42, -560), "fov": 58.0},
		{"from": Vector3(640, 50, -610), "at": Vector3(660, 40, -525), "fov": 56.0},
		{"from": Vector3(650, 40, -570), "at": Vector3(665, 45, -510), "fov": 56.0},
		{"from": Vector3(690, 48, -545), "at": Vector3(660, 70, -515), "fov": 56.0},
		{"from": Vector3(705, 62, -500), "at": Vector3(660, 85, -520), "fov": 56.0},
		{"from": vb + Vector3(24, 10, 18), "at": vb + Vector3(0, 10, 0), "fov": 56.0},
		{"from": Vector3(620, 46, -430), "at": Vector3(560, 46, -395), "fov": 56.0},
		{"from": Vector3(560, 58, -392), "at": Vector3(notch.x, 62, notch.z), "fov": 56.0},
		{"from": Vector3(505, 85, -340), "at": Vector3(notch.x - 80, 60, notch.z + 80), "fov": 58.0},
	]


func flight_kael() -> Array:
	return [spawn_mid + Vector2(-8, -3), 0.3]


static func _xfs() -> Array[Transform3D]:
	return []


static func _meshes(list: Array) -> Array[ArrayMesh]:
	var out: Array[ArrayMesh] = []
	out.assign(list)
	return out
