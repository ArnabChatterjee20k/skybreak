class_name VerdantFallsVoxel
extends VoxelZone
## Verdant Falls in the voxel style (docs/lookdev/verdant_falls.md), look v1,
## built on the voxel zone kit (game/world/voxel_zone_kit/README.md). The sim
## stays the truth: the floor is the baked terrain heightmap (TerrainShape's
## _verdant, the same samples ZoneGround bakes), every tree and the falls come
## from VerdantFallsProps run as-is with the match's PropKit seed (4242), and the
## lake is the plane at y 0. This only builds the voxel look over them.
##
## Tiers: T1 smooth floor and shore around the spawns, the shore and the story
## props; T2 smooth floor further out, the basalt cliff face and canopies; T3 the
## plateau, the far floor and mist; 2xT3 the backdrop hills.

const VERSION := 1
## Outer floor tiers sit this far under the finer tier they overlap (no seam).
const TIER_DROP := 0.03
const TERRAIN_SHADER := preload("res://game/world/voxel_zone_kit/voxel_terrain.gdshader")
const WATER_SHADER := preload("res://game/world/zones_voxel/verdant_falls/vf_water.gdshader")
const FALLS_SHADER := preload("res://game/world/zones_voxel/verdant_falls/vf_falls.gdshader")
const MIST_SHADER := preload("res://game/world/zones_voxel/verdant_falls/vf_mist.gdshader")
const SHAFT_SHADER := preload("res://game/world/zones_voxel/verdant_falls/vf_shaft.gdshader")
const HEIGHTMAP := "res://game/world/terrain/terrain_heightmap.res"
## Spawn ring kept clear of new props (m), and the props' shared LOD ranges.
const SPAWN_RING := 25.0
const CANOPY_RANGES := [55.0, 0.0]
const TRUNK_RANGES := [35.0, 120.0, 0.0]

enum Mat {
	EMPTY, LEAF_TOP, LEAF, LEAF_DARK, MOSS, MOSS_LIGHT, FERN, FERN_DARK, BARK, BARK_DARK, BARK_RIDGE,
	BASALT, STONE, STONE_DARK, SAND, WOOD, WOOD_NEW, ROPE, IRON, ORCHID, ORCHID_DARK, MUSHROOM, MUSHROOM_CAP,
	FUNGUS, SOIL, ROOT, WATER, FOAM, REED, LILY, FROG, HEARTWOOD, CARVE, PETAL_WHITE,
}
## Palette (sRGB), from the sheet: three greens, dark wet basalt, white water,
## orchid magenta as the one accent.
const COLORS := {
	Mat.LEAF_TOP: Color("#7AA850"), Mat.LEAF: Color("#56803E"), Mat.LEAF_DARK: Color("#2E4A2C"),
	Mat.MOSS: Color("#6E9048"), Mat.MOSS_LIGHT: Color("#86A452"), Mat.FERN: Color("#4E7A54"),
	Mat.FERN_DARK: Color("#30503A"), Mat.BARK: Color("#5A4C40"), Mat.BARK_DARK: Color("#382E26"),
	Mat.BARK_RIDGE: Color("#7A6C5E"), Mat.BASALT: Color("#3A4040"), Mat.STONE: Color("#8A8A7E"),
	Mat.STONE_DARK: Color("#5A5A50"), Mat.SAND: Color("#B8AC88"), Mat.WOOD: Color("#6E5A44"),
	Mat.WOOD_NEW: Color("#A08A66"), Mat.ROPE: Color("#9C8C68"), Mat.IRON: Color("#3E3C3A"),
	Mat.ORCHID: Color("#E05AC8"), Mat.ORCHID_DARK: Color("#9A3A88"), Mat.MUSHROOM: Color("#E8DCC4"),
	Mat.MUSHROOM_CAP: Color("#B0784A"), Mat.FUNGUS: Color("#C8A878"), Mat.SOIL: Color("#4A3A2C"),
	Mat.ROOT: Color("#4E4034"), Mat.WATER: Color("#6C8C8C"), Mat.FOAM: Color("#F0F4F2"),
	Mat.REED: Color("#7E8A4E"), Mat.LILY: Color("#557A3E"), Mat.FROG: Color("#6A8A3A"),
	Mat.HEARTWOOD: Color("#B89870"), Mat.CARVE: Color("#2A221C"), Mat.PETAL_WHITE: Color("#F2EEE2"),
}
## Floor tones: moss light to deep, leaf litter, blue-green ground fern.
const FLOOR_MOSS: Array[Color] = [Color("#7A9A4A"), Color("#66863F"), Color("#567439"), Color("#43602F")]
const LITTER: Array[Color] = [Color("#7C6A4A"), Color("#8E7A52"), Color("#6A5A40")]

var map: TerrainHeightmap
var zone: ZoneData
var layout: ZoneLayout
var centre := Vector2.ZERO
## Sim placements (VerdantFallsProps): trunk and canopy transforms.
var trunks: Array[Transform3D] = []
var canopies: Array[Transform3D] = []
## The curtain's four corners (top left, top right, bottom left, bottom right).
var falls_quad := PackedVector3Array()
var spray_spots: Array[Transform3D] = []
var spawns: Array[Vector2] = []
## Story spots chosen in build (world x, z) and the two walkway giants.
var shrine_at := Vector2.ZERO
var grove_pair: Array[int] = []
var marks_tree := -1
var fallen_at := Vector2.ZERO
var islet_at := Vector2.ZERO
var sluice_at := Vector2.ZERO
## Canopy shade on a 2 m grid over the zone box.
var _shade := PackedFloat32Array()
var _shade_origin := Vector2.ZERO
var _shade_size := Vector2i.ZERO
var _cell_scale := 1.0
var _water_mat: ShaderMaterial
var _falls_mats: Array[ShaderMaterial] = []
var _mist_mats: Array[ShaderMaterial] = []
var _shaft_mats: Array[ShaderMaterial] = []
var _swaying: Array = []
var _env_done := false
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "VerdantFalls"


func build() -> void:
	var t := Time.get_ticks_msec()
	map = load(HEIGHTMAP)
	layout = ZoneLayout.load_default()
	zone = load("res://game/world/zones/verdant_falls.tres")
	centre = zone.centre
	for p in zone.spawn_points:
		spawns.append(Vector2(p.x, p.z))
	_placements()
	_canopy_shade()
	_pick_story_spots()
	var steps: Array[Callable] = [_floor, _cliff, _backdrop, _water, _falls, _trees, _canopies, _scatter,
		_shore, _story_props, _mist, _shafts, _particles]
	for step in steps:
		var s := Time.get_ticks_msec()
		step.call()
		stats["ms_" + step.get_method().trim_prefix("_")] = Time.get_ticks_msec() - s
		print("  %s: %d ms" % [step.get_method(), Time.get_ticks_msec() - s])
	stats["ms_total"] = Time.get_ticks_msec() - t


## The sim's floor: the baked heightmap, bilinear (ZoneGround bakes the same samples).
func ground_at(x: float, z: float) -> float:
	return map.ground_height_at(x, z)


func local(lx: float, lz: float) -> Vector2:
	return centre + Vector2(lx, lz)


## Runs the sim's own prop builder (as WorldMap does for a zone match: one
## PropKit with seed 4242 and every ground zone's spawns kept clear) to get its
## placements; its grey-box meshes are thrown away.
func _placements() -> void:
	var kit := PropKit.new(map, WorldMap.PROP_SEED)
	for zd in layout.ground_zones():
		for p in zd.spawn_points:
			kit.keep_clear.append(Vector3(p.x, p.z, WorldMap.SPAWN_CLEAR_RADIUS))
	var scratch := Node3D.new()
	VerdantFallsProps.build(scratch, kit, zone, layout)
	for child in scratch.get_children():
		match String(child.name):
			"Trunks":
				trunks.assign(child.get_meta(PropKit.INSTANCE_TRANSFORMS_META))
			"Canopies":
				canopies.assign(child.get_meta(PropKit.INSTANCE_TRANSFORMS_META))
			"Spray":
				spray_spots.assign(child.get_meta(PropKit.INSTANCE_TRANSFORMS_META))
			"Waterfall":
				var arrays := (child as MeshInstance3D).mesh.surface_get_arrays(0)
				falls_quad = arrays[Mesh.ARRAY_VERTEX]
	scratch.free()
	stats["trees"] = trunks.size()
	stats["canopies"] = canopies.size()


## Trunk base (ground), radius and height of sim tree k.
func tree_base(k: int) -> Vector3:
	var t := trunks[k]
	var h := t.basis.get_scale().y
	return Vector3(t.origin.x, t.origin.y - h * 0.5 + 2.0, t.origin.z)


func tree_radius(k: int) -> float:
	return trunks[k].basis.get_scale().x * 0.5


func tree_height(k: int) -> float:
	return trunks[k].basis.get_scale().y


func _canopy_shade() -> void:
	_shade_origin = centre - Vector2(340, 470)
	_shade_size = Vector2i(340, 470)
	_shade.resize(_shade_size.x * _shade_size.y)
	for t in canopies:
		var c := t.origin
		var r := t.basis.get_scale().x * 0.5
		var lo := Vector2i(((Vector2(c.x, c.z) - Vector2(r, r) - _shade_origin) / 2.0).floor())
		var hi := Vector2i(((Vector2(c.x, c.z) + Vector2(r, r) - _shade_origin) / 2.0).ceil())
		for gz in range(maxi(lo.y, 0), mini(hi.y, _shade_size.y - 1) + 1):
			for gx in range(maxi(lo.x, 0), mini(hi.x, _shade_size.x - 1) + 1):
				var w := _shade_origin + Vector2(gx, gz) * 2.0 + Vector2.ONE
				var d := w.distance_to(Vector2(c.x, c.z)) / r
				if d < 1.0:
					var i := gx + gz * _shade_size.x
					_shade[i] = minf(1.0, _shade[i] + (1.0 - d * d) * 0.7)


func shade_at(w: Vector2) -> float:
	var g := Vector2i(((w - _shade_origin) / 2.0).floor())
	if g.x < 0 or g.y < 0 or g.x >= _shade_size.x or g.y >= _shade_size.y:
		return 0.0
	return _shade[g.x + g.y * _shade_size.x]


func near_spawn(w: Vector2, r := SPAWN_RING) -> bool:
	for s in spawns:
		if w.distance_to(s) < r:
			return true
	return false


func near_trunk(w: Vector2, pad: float) -> bool:
	for k in trunks.size():
		var b := tree_base(k)
		if w.distance_to(Vector2(b.x, b.z)) < tree_radius(k) + pad:
			return true
	return false


## Story spots at authored places outside the spawn ring, nudged off trunks.
func _pick_story_spots() -> void:
	shrine_at = _clear_spot(local(62, 128), 9.0)
	fallen_at = _clear_spot(local(118, 176), 12.0)
	sluice_at = _clear_spot(local(52, 104), 5.0)
	# Stepping stones to an islet on the south shelf, west of the spawns.
	islet_at = local(-58, 96)
	for k in 40:
		var w := local(-58 - k * 1.5, 92 - k * 0.6)
		var g := ground_at(w.x, w.y)
		if g > -1.4 and g < -0.5:
			islet_at = w
			break
	# Walkway: the two giants nearest the Giant Grove landmark that stand 26-60 m apart.
	var grove := Vector2(zone.landmark_positions[2].x, zone.landmark_positions[2].z)
	var best := INF
	for a in mini(trunks.size(), 40):
		for b in range(a + 1, mini(trunks.size(), 40)):
			var pa := tree_base(a)
			var pb := tree_base(b)
			var d := Vector2(pa.x, pa.z).distance_to(Vector2(pb.x, pb.z))
			if d < 26.0 or d > 60.0:
				continue
			var score := Vector2(pa.x, pa.z).lerp(Vector2(pb.x, pb.z), 0.5).distance_to(grove) + absf(pa.y - pb.y) * 3.0
			if score < best:
				best = score
				grove_pair = [a, b]
	# Height marks: the giant nearest the shrine.
	best = INF
	for k in mini(trunks.size(), 40):
		var b := tree_base(k)
		var d := Vector2(b.x, b.z).distance_to(shrine_at)
		if d < best:
			best = d
			marks_tree = k
	stats["story"] = {"shrine": shrine_at, "fallen": fallen_at, "sluice": sluice_at, "islet": islet_at,
		"walkway": grove_pair, "marks_tree": marks_tree}


func _clear_spot(w: Vector2, r: float) -> Vector2:
	for k in 60:
		var a := k * 2.4
		var p := w + Vector2(cos(a), sin(a)) * k * 1.2
		if not near_trunk(p, r) and not near_spawn(p, SPAWN_RING + r) and ground_at(p.x, p.y) > 1.2:
			return p
	return w


# ---------------------------------------------------------------- terrain

## Floor rectangles by tier (world min, max): T1 around the spawns and the
## south shore, T2 the valley around the lake, T3 the rest of the zone box.
func _t1_rect() -> Rect2:
	return Rect2(local(-95, 70), Vector2(195, 150))


func _t2_rect() -> Rect2:
	return Rect2(local(-250, -128), Vector2(500, 430))


func _box_rect() -> Rect2:
	return Rect2(local(-340, -128), Vector2(680, 600))


func _floor() -> void:
	var quads := 0
	var t1 := _t1_rect()
	var t2 := _t2_rect()
	var box := _box_rect()
	quads += _smooth_field(T1, t1, Rect2(), "FloorT1", 0.0, 0.0)
	quads += _smooth_field(T2, t2, t1.grow(-1.0), "FloorT2", 0.0, TIER_DROP)
	quads += _smooth_field(T3, box, t2.grow(-3.0), "FloorT3", 0.0, TIER_DROP * 2.0)
	stats["floor_quads"] = quads


## A smooth top on the sim's floor over `rect`, skipping `hole`, coloured per cell.
func _smooth_field(cell: float, rect: Rect2, hole: Rect2, node_name: String, vis_end: float, drop: float) -> int:
	var hf := VoxelHeightfield.new(cell, rect.position, rect.end)
	var cliff_z := centre.y - 128.0
	for z in hf.size.y:
		for x in hf.size.x:
			var w := hf.centre(x, z)
			if hole.has_point(w) or w.y < cliff_z:
				continue
			var h := ground_at(w.x, w.y)
			hf.set_column(x, z, roundi(h / cell), roundi((h - 1.2) / cell), _floor_colour(w, h, x, z, cell))
	hf.smooth_height = func(x: float, z: float) -> float: return ground_at(x, z) - drop
	var mat := _terrain_material(hf)
	var node := hf.build(self, mat, node_name, vis_end, false)
	return VoxelHeightfield.count_quads(node)


func _floor_colour(w: Vector2, h: float, x: int, z: int, cell: float) -> Color:
	var id := Vector3i(x, roundi(cell * 1000.0), z)
	var hv := VoxelSdf.hash3(id, 11)
	var shade := shade_at(w)
	var slope := absf(ground_at(w.x + 1.0, w.y) - ground_at(w.x - 1.0, w.y)) \
		+ absf(ground_at(w.x, w.y + 1.0) - ground_at(w.x, w.y - 1.0))
	# Under water: the sandy shelf, darker with depth.
	if h < 0.0:
		var sand := COLORS[Mat.SAND] * (0.95 + 0.1 * hv)
		return _ao(sand.lerp(Color("#4c5a48"), smoothstep(0.0, 6.0, -h)), 0.0)
	# Shore: wet dark sand at the waterline, pale khaki above, pebbles.
	if h < 1.6:
		var sand := COLORS[Mat.SAND] * (0.94 + 0.12 * hv)
		if h < 0.35:
			sand = sand * 0.68
		if VoxelSdf.hash3(id, 41) < 0.05:
			sand = COLORS[Mat.STONE] * (0.85 + 0.2 * hv)
		var into := smoothstep(1.0, 1.6, h)
		return _ao(sand.lerp(FLOOR_MOSS[1], into * 0.7), shade * 0.5)
	# Steep: exposed rock and roots.
	if slope > 3.2:
		return _ao(COLORS[Mat.STONE_DARK].lerp(Color("#4a5040"), hv), shade)
	# Moss in patches (four tones, lighter and yellower in the open), leaf
	# litter and blue-green ground fern under the canopies.
	var n1 := sin(w.x * 0.071 + w.y * 0.043) + sin(w.x * 0.033 - w.y * 0.089 + 1.3)
	var n2 := sin(w.x * 0.37 + 2.1) * sin(w.y * 0.31 - 0.7)
	var tone := clampf(0.4 + n1 * 0.3 + n2 * 0.25 + (hv - 0.5) * 0.3 + shade * 0.4, 0.0, 0.999)
	var k := tone * 3.0
	var c := FLOOR_MOSS[int(k)].lerp(FLOOR_MOSS[mini(int(k) + 1, 3)], fposmod(k, 1.0))
	var litter := shade * (0.5 + 0.5 * sin(w.x * 0.9 + w.y * 0.4))
	if VoxelSdf.hash3(id, 23) < litter * 0.55:
		c = LITTER[int(VoxelSdf.hash3(id, 29) * 3.0) % 3]
	elif n2 < -0.55 and shade > 0.3:
		c = COLORS[Mat.FERN] * (0.92 + 0.12 * hv)
	elif VoxelSdf.hash3(id, 37) < 0.004 and shade < 0.3:
		c = COLORS[Mat.PETAL_WHITE]
	# Sun pools: the floor is lighter where the canopy opens.
	c = c.lerp(c.lightened(0.15), clampf(1.0 - shade * 2.0, 0.0, 1.0) * 0.4)
	return _ao(c * (0.97 + 0.06 * VoxelSdf.hash3(id, 31)), shade)


## Baked canopy shade (up to 45% darker, slightly cooler).
static func _ao(c: Color, shade: float) -> Color:
	var k := 1.0 - 0.45 * shade
	return Color(c.r * k * (1.0 - 0.05 * shade), c.g * k, c.b * k * (1.0 + 0.04 * shade), 0.0)


func _terrain_material(hf: VoxelHeightfield) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	hf.bind(mat)
	mat.set_shader_parameter("rock_color", Color("#4a5250"))
	mat.set_shader_parameter("rock_shadow", Color("#262c2c"))
	mat.set_shader_parameter("soil_color", Color("#3e3226"))
	mat.set_shader_parameter("under_color", Color("#3A4040"))
	mat.set_shader_parameter("under_alt", Color("#2e3434"))
	mat.set_shader_parameter("under_deep", Color("#1E2424"))
	mat.set_shader_parameter("strata_cells", 4.0)
	mat.set_shader_parameter("noise_amount", 0.04)
	return mat


## The north cliff and plateau: stepped basalt columns (prisms of 4 x 4 T2
## cells with their own heights) on the face, T3 columns on the plateau; moss on
## every top, the river groove painted as running water.
func _cliff() -> void:
	var quads := 0
	var face_rect := Rect2(local(-340, -178), Vector2(680, 50.5))
	var top_rect := Rect2(local(-340, -470), Vector2(680, 292.5))
	quads += _cliff_field(T2, face_rect, 4, "CliffFace")
	quads += _cliff_field(T3, top_rect, 1, "Plateau")
	stats["cliff_quads"] = quads


func _cliff_field(cell: float, rect: Rect2, prism: int, node_name: String) -> int:
	var hf := VoxelHeightfield.new(cell, rect.position, rect.end)
	var floor_edge := centre.y - 128.0
	for z in hf.size.y:
		for x in hf.size.x:
			var w := hf.centre(x, z)
			if w.y >= floor_edge:
				continue
			var px := floori(float(x) / prism)
			var pz := floori(float(z) / prism)
			# Hex-ish columns: odd prism rows shifted by half a prism.
			if pz % 2 == 1:
				px = floori((float(x) + prism * 0.5) / prism)
			var pid := Vector3i(px, prism, pz)
			var pc := hf.centre(px * prism + prism / 2, pz * prism + prism / 2)
			var h := ground_at(pc.x, pc.y)
			var steep := absf(ground_at(pc.x, pc.y - 4.0) - ground_at(pc.x, pc.y + 4.0))
			# Columns stand proud on the face by up to 1.2 m.
			var jitter := (VoxelSdf.hash3(pid, 3) - 0.35) * minf(steep * 0.4, 7.0)
			var top := h + jitter
			var lv := roundi(top / cell)
			hf.set_column(x, z, lv, roundi((top - 14.0) / cell), _cliff_colour(w, top, steep, pid, hf, x, z))
	var mat := _terrain_material(hf)
	mat.set_shader_parameter("strata_cells", 8.0 if cell < 1.0 else 2.0)
	mat.set_shader_parameter("crack_amount", 1.0)
	mat.set_shader_parameter("rock_color", Color("#3A4040"))
	mat.set_shader_parameter("rock_shadow", Color("#181e1e"))
	mat.set_shader_parameter("soil_color", Color("#2e3a2a"))
	var node := hf.build(self, mat, node_name)
	return VoxelHeightfield.count_quads(node)


func _cliff_colour(w: Vector2, top: float, steep: float, pid: Vector3i, hf: VoxelHeightfield, x: int, z: int) -> Color:
	var hv := VoxelSdf.hash3(pid, 13)
	var lx := w.x - centre.x
	var lz := w.y - centre.y
	# The river groove on the plateau: running water, white where it nears the lip.
	var groove := absf(lx - 20.0 * sin(lz * 0.01))
	if top > 100.0 and groove < 9.0:
		var near_lip := smoothstep(-200.0, -160.0, lz)
		var foam := VoxelSdf.hash3(Vector3i(x, 0, z), 51) < 0.15 + near_lip * 0.5
		return Color("#5e7a78") if not foam else COLORS[Mat.FOAM] * 0.95
	if top > 100.0 and groove < 12.0:
		return COLORS[Mat.STONE_DARK] * (0.9 + 0.2 * hv)
	# Moss on every ledge; on the face some tops are bare wet basalt.
	if steep > 20.0 and hv < 0.55:
		return COLORS[Mat.BASALT] * (0.9 + 0.2 * hv)
	var moss := FLOOR_MOSS[int(hv * 4.0) % 4]
	if top > 100.0:
		# Plateau jungle: canopy greens seen from below and above.
		var n := sin(w.x * 0.05) * sin(w.y * 0.07) + VoxelSdf.hash3(Vector3i(x, 1, z), 7) * 0.6
		moss = COLORS[Mat.LEAF].lerp(COLORS[Mat.LEAF_DARK], clampf(0.5 - n * 0.5, 0.0, 1.0))
		if VoxelSdf.hash3(Vector3i(x, 2, z), 9) < 0.05:
			moss = COLORS[Mat.LEAF_TOP]
	return _ao(moss, 0.0)


## Hills beyond the zone box (2xT3 stepped), coloured as far canopy, so no
## shot ever sees the box edge.
func _backdrop() -> void:
	var cell := T3 * 4.0
	var outer := Rect2(local(-760, -860), Vector2(1520, 1720))
	var inner := _box_rect().merge(Rect2(local(-340, -470), Vector2(680, 342)))
	var hf := VoxelHeightfield.new(cell, outer.position, outer.end)
	for z in hf.size.y:
		for x in hf.size.x:
			var w := hf.centre(x, z)
			if inner.grow(-cell).has_point(w):
				continue
			# Rise toward the horizon so the backdrop frames the valley.
			var d := maxf(absf(w.x - centre.x) - 340.0, absf(w.y - centre.y) - 470.0)
			var crown := VoxelSdf.hash3(Vector3i(floori(w.x / 11.0), 5, floori(w.y / 11.0)), 3) * 9.0
			var h := maxf(ground_at(w.x, w.y), 0.0) * 0.5 + 20.0 + clampf(d, 0.0, 400.0) * 0.1 \
				+ 12.0 * sin(w.x * 0.013) * sin(w.y * 0.011) + crown
			if w.y < centre.y - 128.0:
				h = maxf(h, 118.0 + 10.0 * sin(w.x * 0.02))
			var n := VoxelSdf.hash3(Vector3i(x, 3, z), 7)
			var c := COLORS[Mat.LEAF].lerp(COLORS[Mat.LEAF_DARK], 0.35 + 0.4 * n)
			hf.set_column(x, z, roundi(h / cell), roundi(-20.0 / cell), c)
	var mat := _terrain_material(hf)
	mat.set_shader_parameter("rock_color", Color("#3c5034"))
	mat.set_shader_parameter("rock_shadow", Color("#22321e"))
	var node := hf.build(self, mat, "Backdrop")
	stats["backdrop_quads"] = VoxelHeightfield.count_quads(node)


# ---------------------------------------------------------------- water

func _water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(520, 440)
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = WATER_SHADER
	var lake := local(-20, -20)
	_water_mat.set_shader_parameter("clip_centre", lake + Vector2(0, -10))
	_water_mat.set_shader_parameter("clip_radius", 236.0)
	var top := falls_quad[0].lerp(falls_quad[1], 0.5)
	var bottom := falls_quad[2].lerp(falls_quad[3], 0.5)
	_water_mat.set_shader_parameter("falls", Vector4(top.x, 30.0, lerpf(top.z, bottom.z, 0.5), top.y))
	_water_mat.set_shader_parameter("cliff_z", centre.y - 152.0)
	plane.material = _water_mat
	var mi := MeshInstance3D.new()
	mi.name = "MirrorLake"
	mi.mesh = plane
	mi.position = Vector3(lake.x, 0.0, lake.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## The Great Falls on the sim's curtain: two stepped layers (the sim's quad
## and a thinner veil in front), a boulder lip at the top, foam blocks and
## plunge-pool rocks at the foot.
func _falls() -> void:
	var tl := falls_quad[0]
	var tr := falls_quad[1]
	var bl := falls_quad[2]
	var br := falls_quad[3]
	for layer in 2:
		var push := Vector3(0, 0, 1.6 * layer)
		var shrink := 0.82 if layer == 1 else 1.0
		var mid_t := tl.lerp(tr, 0.5)
		var mid_b := bl.lerp(br, 0.5)
		var verts := PackedVector3Array([mid_t.lerp(tl, shrink) + push, mid_t.lerp(tr, shrink) + push,
			mid_b.lerp(bl, shrink) + push, mid_b.lerp(br, shrink) + push])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2])
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat := ShaderMaterial.new()
		mat.shader = FALLS_SHADER
		mat.set_shader_parameter("size_m", Vector2(tl.distance_to(tr) * shrink, tl.distance_to(bl)))
		mat.set_shader_parameter("layer", float(layer))
		mat.set_shader_parameter("speed", 0.45 + 0.15 * layer)
		if layer == 1:
			mat.set_shader_parameter("water_color", Color(0.86, 0.9, 0.9))
		_falls_mats.append(mat)
		var mi := MeshInstance3D.new()
		mi.name = "GreatFalls%d" % layer
		mi.mesh = m
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	# Boulder lip where the river pours over, and rocks in the plunge pool.
	var lip: Array[Transform3D] = []
	var pool: Array[Transform3D] = []
	_rng.seed = 77
	for k in 26:
		var u := float(k) / 25.0
		var p := tl.lerp(tr, u) + Vector3(_rng.randf_range(-1.5, 1.5), -0.8, _rng.randf_range(-3.0, 1.0))
		if absf(u - 0.5) < 0.42 and _rng.randf() < 0.6:
			continue
		lip.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(2.5, 4.5)), p))
	for k in 18:
		var a := _rng.randf() * PI
		var r := _rng.randf_range(26.0, 44.0)
		var bc := bl.lerp(br, 0.5)
		var p := Vector3(bc.x + cos(a) * r, -0.6, bc.z - 4.0 + sin(a) * r * 0.6)
		pool.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(1.6, 3.2)), p))
	VoxelProp.place(self, "FallsLip", _lod(_boulder_mesh.bind(0, true), 4.0), [140.0, 0.0], lip, 1)
	VoxelProp.place(self, "PlungeRocks", _lod(_boulder_mesh.bind(1, true), 4.0), [140.0, 0.0], pool, 1)


# ---------------------------------------------------------------- trees

## Giant trunks (buttress roots at 2xT1, trunk and limbs at T2) and small
## trunks on the sim's trunk spots; the trunk's height follows the sim's.
func _trees() -> void:
	var base_tiers: Array = []
	var upper_tiers: Array = []
	for v in 3:
		base_tiers.append([_giant_base(v, T1 * 2.0), _giant_base(v, T2), _giant_base(v, T3)])
		upper_tiers.append([_giant_upper(v, T2), _giant_upper(v, T3)])
	var small_tiers := [_small_trunk(T1 * 2.0), _small_trunk(T2)]
	var bases: Array = [[], [], []]
	var uppers: Array = [[], [], []]
	var smalls: Array[Transform3D] = []
	for k in trunks.size():
		var b := tree_base(k)
		var r := tree_radius(k)
		var h := tree_height(k)
		if r >= 4.4:
			var v := k % 3
			var s := r / 6.0
			# Limb 0 leans toward the sim's lower canopy (offset +x, -z).
			var basis := Basis(Vector3.UP, -PI * 0.25).scaled(Vector3(s, (h - 2.0) / 76.0, s))
			var flat := Basis(Vector3.UP, -PI * 0.25 + VoxelSdf.hash3(Vector3i(k, 0, 0), 3) * 0.3).scaled(Vector3.ONE * s)
			(bases[v] as Array).append(Transform3D(flat, b + Vector3.DOWN * 0.4))
			(uppers[v] as Array).append(Transform3D(basis, b + Vector3.DOWN * 0.4))
		else:
			var s := r / 2.0
			smalls.append(Transform3D(Basis(Vector3.UP, k * 1.3).scaled(Vector3(s, (h - 2.0) / 26.0, s)), b + Vector3.DOWN * 0.2))
	var tris := 0
	for v in 3:
		var lb: Array[Transform3D] = []
		lb.assign(bases[v])
		var lu: Array[Transform3D] = []
		lu.assign(uppers[v])
		var bt: Array[ArrayMesh] = []
		bt.assign(base_tiers[v])
		var ut: Array[ArrayMesh] = []
		ut.assign(upper_tiers[v])
		VoxelProp.place(self, "GiantBase%d" % v, bt, TRUNK_RANGES, lb, 2)
		VoxelProp.place(self, "GiantTrunk%d" % v, ut, [70.0, 0.0], lu, 1)
		tris += VoxelProp.quads(bt[0]) * 2 + VoxelProp.quads(ut[0]) * 2
	var st: Array[ArrayMesh] = []
	st.assign(small_tiers)
	VoxelProp.place(self, "SmallTrunks", st, [45.0, 0.0], smalls, 1)
	stats["giant_tris_per_variant_near"] = tris / 3
	stats["small_trunk_tris"] = VoxelProp.quads(st[0]) * 2


## Buttress roots and the lower 12 m of a giant (design radius 6 m): an
## 8-sided faceted trunk, 3-5 planar fins with ridges, root tips into the moss,
## moss on the north side and the fin tops, orchids above head height.
func _giant_base(v: int, cell: float) -> ArrayMesh:
	var bounds := AABB(Vector3(-15, -1.2, -15), Vector3(30, 14.4, 30))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 3100 + v
		g.paint(AABB(Vector3(-7.5, -1.2, -7.5), Vector3(15, 14.4, 15)), func(p: Vector3) -> float:
			return _octagon(p, 6.0 + maxf(0.0, 2.0 - p.y) * 0.4) , Mat.BARK)
		var fins := 4 + v % 2
		for f in fins:
			var a := TAU * f / fins + rng.randf_range(-0.35, 0.35)
			var dir := Vector3(cos(a), 0, sin(a))
			var reach := rng.randf_range(11.0, 14.0)
			var tall := rng.randf_range(7.0, 10.0)
			var thick := rng.randf_range(0.5, 0.75)
			# A planar fin: a triangle in the (dir, up) plane, thick in the side axis.
			var side := Vector3(-dir.z, 0, dir.x)
			var fb := AABB(Vector3(-reach, -1.2, -reach) , Vector3(reach * 2, tall + 1.2, reach * 2))
			g.paint(fb, func(p: Vector3) -> float:
				var u := p.dot(dir)
				var s := absf(p.dot(side)) - thick * (1.0 + maxf(0.0, 1.0 - p.y) * 0.6)
				var lean := p.y - tall * (1.0 - clampf((u - 5.0) / (reach - 5.0), 0.0, 1.0)) * (1.0 - 0.15 * sin(u * 0.9))
				return maxf(maxf(s, lean), maxf(4.5 - u, u - reach)), Mat.BARK, -1, VoxelGrid.Mode.ADD)
			# Root tip running on into the moss.
			var tip := dir * (reach + 2.5) + Vector3.DOWN * 0.5
			g.paint(AABB(dir * reach - Vector3(4, 2, 4), Vector3(8, 3, 8)), func(p: Vector3) -> float:
				return VoxelSdf.capsule(p, dir * (reach - 1.0) + Vector3.UP * 0.2, tip, 0.6, 0.25), Mat.ROOT, -1, VoxelGrid.Mode.ADD)
		# Bark: vertical furrows; ridges lighter.
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return fposmod(atan2(p.z, p.x) * 7.0 + sin(p.y * 0.4) * 0.6, 1.0) < 0.22 and Vector2(p.x, p.z).length() < 7.5,
			Mat.BARK_DARK, [Mat.BARK])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y > 0.3 and VoxelSdf.hash3(c, 17) < 0.25 and Vector2(p.x, p.z).length() > 7.5, Mat.BARK_RIDGE, [Mat.BARK])
		# Moss: the north side (-z) low down, every fin top, the root tips.
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			var north := p.z < -2.0 and p.y < 6.0 + 3.0 * VoxelSdf.hash3(c, 5)
			var top := g.get_mat(c.x, c.y + 1, c.z) == 0 and VoxelSdf.hash3(c, 9) < 0.7
			return (north and VoxelSdf.hash3(c, 21) < 0.65) or top or p.y < 0.2,
			Mat.MOSS, [Mat.BARK, Mat.BARK_DARK, Mat.BARK_RIDGE, Mat.ROOT])
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool: return VoxelSdf.hash3(c, 23) < 0.25,
			Mat.MOSS_LIGHT, [Mat.MOSS])
		# Orchid clusters on the trunk, above head height.
		for o in 3:
			var a := rng.randf() * TAU
			var oc := Vector3(cos(a) * 6.1, rng.randf_range(4.0, 10.0), sin(a) * 6.1)
			g.paint(AABB(oc - Vector3.ONE * 0.8, Vector3.ONE * 1.6), func(p: Vector3) -> float:
				return VoxelSdf.sphere(p, oc, 0.55), Mat.ORCHID, -1, VoxelGrid.Mode.ADD)
			g.paint_surface(AABB(oc - Vector3.ONE * 0.8, Vector3.ONE * 1.6), func(_p: Vector3, c: Vector3i) -> bool:
				return VoxelSdf.hash3(c, 31) < 0.4, Mat.LEAF, [Mat.ORCHID])
	return _mesh("vf_giant_base%d" % v, bounds, cell, paint)


## The giant above 12 m (design height 76 m): faceted trunk tapering, bark
## furrows, three limbs into the canopy layers, lianas hanging from them.
func _giant_upper(v: int, cell: float) -> ArrayMesh:
	var bounds := AABB(Vector3(-16, 11.5, -16), Vector3(32, 66, 32))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 3200 + v
		g.paint(AABB(Vector3(-6.5, 11.5, -6.5), Vector3(13, 66, 13)), func(p: Vector3) -> float:
			return maxf(_octagon(p, lerpf(5.7, 3.0, clampf((p.y - 12.0) / 64.0, 0.0, 1.0))), p.y - 76.0), Mat.BARK)
		var limbs: Array[Vector3] = [Vector3(11, 47, 0), Vector3(-10, 58, 7), Vector3(-3, 66, -11)]
		for l in limbs.size():
			var from := Vector3(0, limbs[l].y - 10.0, 0)
			var to := limbs[l].rotated(Vector3.UP, rng.randf_range(-0.2, 0.2) if l > 0 else 0.0)
			var lo := Vector3(minf(from.x, to.x), from.y, minf(from.z, to.z)) - Vector3.ONE * 2.5
			g.paint(AABB(lo, (to - from).abs() + Vector3.ONE * 5.0), func(p: Vector3) -> float:
				return VoxelSdf.capsule(p, from, to, 2.2, 0.9), Mat.BARK, -1, VoxelGrid.Mode.ADD)
			# Lianas: rigid strands hanging from the limb.
			for j in 3:
				var at := from.lerp(to, rng.randf_range(0.4, 0.95))
				var len := rng.randf_range(10.0, 24.0)
				var bottom := at + Vector3(rng.randf_range(-1, 1), -len, rng.randf_range(-1, 1))
				g.paint(AABB(Vector3(minf(at.x, bottom.x) - 1, bottom.y - 1, minf(at.z, bottom.z) - 1),
					Vector3(absf(at.x - bottom.x) + 2, len + 2, absf(at.z - bottom.z) + 2)), func(p: Vector3) -> float:
					return VoxelSdf.capsule(p, at, bottom, 0.22, 0.18), Mat.LEAF, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return fposmod(atan2(p.z, p.x) * 6.0 + p.y * 0.05, 1.0) < 0.2, Mat.BARK_DARK, [Mat.BARK])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return (g.get_mat(c.x, c.y + 1, c.z) == 0 and VoxelSdf.hash3(c, 9) < 0.8) or (p.z < -2.5 and VoxelSdf.hash3(c, 13) < 0.3),
			Mat.MOSS, [Mat.BARK, Mat.BARK_DARK])
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool: return VoxelSdf.hash3(c, 41) < 0.3,
			Mat.LEAF_DARK, [Mat.LEAF])
	return _mesh("vf_giant_upper%d" % v, bounds, cell, paint)


## A small tree's trunk (design radius 2 m, 26 m tall): faceted, root flares,
## two limbs, moss on the north side.
func _small_trunk(cell: float) -> ArrayMesh:
	var bounds := AABB(Vector3(-5, -0.8, -5), Vector3(10, 27.8, 10))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(AABB(Vector3(-2.5, -0.8, -2.5), Vector3(5, 27.8, 5)), func(p: Vector3) -> float:
			return maxf(_octagon(p, lerpf(2.0, 1.0, clampf(p.y / 26.0, 0.0, 1.0))), p.y - 26.0), Mat.BARK)
		for f in 4:
			var a := TAU * f / 4.0 + 0.4
			var dir := Vector3(cos(a), 0, sin(a))
			g.paint(AABB(Vector3(-5, -0.8, -5), Vector3(10, 3, 10)), func(p: Vector3) -> float:
				return VoxelSdf.capsule(p, Vector3(0, 1.4, 0), dir * 3.8 + Vector3.DOWN * 0.3, 1.0, 0.25), Mat.ROOT, -1, VoxelGrid.Mode.ADD)
		for l: Vector3 in [Vector3(3.5, 22, 0), Vector3(-2.5, 24, 2.5)]:
			g.paint(AABB(Vector3(-4, 15, -4), Vector3(8, 12, 8)), func(p: Vector3) -> float:
				return VoxelSdf.capsule(p, Vector3(0, l.y - 5.0, 0), l, 0.7, 0.35), Mat.BARK, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return fposmod(atan2(p.z, p.x) * 3.0, 1.0) < 0.2, Mat.BARK_DARK, [Mat.BARK])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return (p.z < -0.8 and p.y < 5.0 and VoxelSdf.hash3(c, 3) < 0.7) or p.y < 0.3, Mat.MOSS, [Mat.BARK, Mat.BARK_DARK, Mat.ROOT])
	return _mesh("vf_small_trunk", bounds, cell, paint)


## Distance to an 8-sided prism of apothem r round the y axis (2D, unbounded in y).
static func _octagon(p: Vector3, r: float) -> float:
	var q := Vector2(absf(p.x), absf(p.z))
	var d := maxf(q.x, q.y)
	d = maxf(d, (q.x + q.y) * 0.70710678)
	return d - r


## Canopy leaf masses on the sim's canopy transforms: clusters of stepped,
## flat-topped slabs (terraced shelves, not spheres) in three greens.
func _canopies() -> void:
	var tiers: Array = []
	for v in 3:
		tiers.append([_canopy_mesh(v, T2), _canopy_mesh(v, T3)])
	var lists: Array = [[], [], []]
	for k in canopies.size():
		var t := canopies[k]
		var w := t.basis.get_scale().x
		var s := w / 40.0
		var yaw := VoxelSdf.hash3(Vector3i(k, 7, 0), 3) * TAU
		var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), t.origin + Vector3.DOWN * w * 0.08)
		(lists[k % 3] as Array).append(xf)
		_swaying.append([k % 3, (lists[k % 3] as Array).size() - 1, xf, VoxelSdf.hash3(Vector3i(k, 1, 1), 5) * TAU])
	var tris := 0
	for v in 3:
		var list: Array[Transform3D] = []
		list.assign(lists[v])
		var tt: Array[ArrayMesh] = []
		tt.assign(tiers[v])
		VoxelProp.place(self, "Canopy%d" % v, tt, CANOPY_RANGES, list, 1)
		tris += VoxelProp.quads(tt[0]) * 2
	stats["canopy_tris_per_variant_near"] = tris / 3


func _canopy_mesh(v: int, cell: float) -> ArrayMesh:
	var bounds := AABB(Vector3(-22, -7, -22), Vector3(44, 15, 44))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4100 + v
		var slabs: Array[Vector4] = [Vector4(0, -3.5, 0, 17.0)]
		for k in 6:
			var a := TAU * k / 6.0 + rng.randf_range(-0.4, 0.4)
			var d := rng.randf_range(6.0, 12.0)
			slabs.append(Vector4(cos(a) * d, rng.randf_range(-2.5, 0.5), sin(a) * d, rng.randf_range(7.0, 10.0)))
		for k in 4:
			var a := TAU * k / 4.0 + rng.randf_range(-0.6, 0.6)
			var d := rng.randf_range(2.0, 8.0)
			slabs.append(Vector4(cos(a) * d, rng.randf_range(1.0, 3.5), sin(a) * d, rng.randf_range(4.5, 7.0)))
		for s in slabs:
			var c := Vector3(s.x, s.y, s.z)
			var r := s.w
			var seed_a := rng.randf() * TAU
			var thick := rng.randf_range(1.4, 2.0)
			g.paint(AABB(c - Vector3(r + 1.5, thick + 0.1, r + 1.5), Vector3(r * 2 + 3, thick * 2 + 0.2, r * 2 + 3)),
				func(p: Vector3) -> float:
					var dx := p.x - c.x
					var dz := p.z - c.z
					var a := atan2(dz, dx)
					var rr := r * (1.0 + 0.12 * sin(a * 3.0 + seed_a) + 0.08 * sin(a * 7.0 - seed_a))
					# Flat top, the underside stepping in (a shelf).
					var under := c.y - thick + (sqrt(dx * dx + dz * dz) / rr) * thick * 0.8
					return maxf(maxf(sqrt(dx * dx + dz * dz) - rr, p.y - (c.y + thick * 0.5)), under - p.y),
				Mat.LEAF, -1, VoxelGrid.Mode.ADD)
		# Gaps: a few pockets so limbs and sky show through.
		for k in 5:
			var a := rng.randf() * TAU
			var hc := Vector3(cos(a) * rng.randf_range(8, 16), rng.randf_range(-3, 1), sin(a) * rng.randf_range(8, 16))
			var hr := rng.randf_range(1.8, 3.0)
			g.paint(AABB(hc - Vector3.ONE * hr, Vector3.ONE * hr * 2), func(p: Vector3) -> float:
				return VoxelSdf.sphere(p, hc, hr), Mat.LEAF, -1, VoxelGrid.Mode.CARVE)
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool:
			return g.get_mat(c.x, c.y + 1, c.z) == 0, Mat.LEAF_TOP, [Mat.LEAF])
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool:
			return g.get_mat(c.x, c.y - 1, c.z) == 0, Mat.LEAF_DARK, [Mat.LEAF])
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool:
			return VoxelSdf.hash3(c, 61) < 0.12, Mat.LEAF_DARK, [Mat.LEAF, Mat.LEAF_TOP])
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool:
			return VoxelSdf.hash3(c, 67) < 0.004, Mat.ORCHID, [Mat.LEAF])
	return _mesh("vf_canopy%d" % v, bounds, cell, paint)


# ---------------------------------------------------------------- scatter

## Ferns, elephant-ear plants, mossy boulders, mushrooms and fallen logs over
## the valley floor near the play space; thinned in the spawn ring, never on
## the lake.
func _scatter() -> void:
	var ferns: Array = [[], [], [], []]
	var ears: Array = [[], []]
	var boulders: Array = [[], []]
	var shrooms: Array[Transform3D] = []
	var logs: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var area := Rect2(local(-250, -120), Vector2(500, 400))
	for k in 26000:
		var w := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		var g := ground_at(w.x, w.y)
		if g < 1.7 or w.y < centre.y - 125.0:
			continue
		var shade := shade_at(w)
		var spawn := near_spawn(w)
		if spawn and rng.randf() < 0.85:
			continue
		if near_trunk(w, 0.6) or w.distance_to(shrine_at) < 11.0 or w.distance_to(sluice_at) < 6.0 or w.distance_to(fallen_at) < 9.0:
			continue
		# Denser under the canopies and near the play space.
		var dense := 0.25 + shade * 0.75
		if rng.randf() > dense:
			continue
		var slope := absf(ground_at(w.x + 1.0, w.y) - ground_at(w.x - 1.0, w.y))
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)),
			Vector3(w.x, g - 0.04 - slope * 0.3, w.y))
		var roll := rng.randf()
		if roll < 0.62:
			(ferns[k % 4] as Array).append(xf)
		elif roll < 0.76:
			(ears[k % 2] as Array).append(xf)
		elif roll < 0.86:
			(boulders[k % 2] as Array).append(Transform3D(xf.basis.scaled(Vector3.ONE * rng.randf_range(0.6, 1.6)), xf.origin))
		elif roll < 0.985:
			shrooms.append(xf)
		elif not spawn:
			logs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)), xf.origin))
	for v in 4:
		_place([_fern_mesh(v, T1), _fern_mesh(v, T1 * 2.0)], ferns[v], "Ferns%d" % v, [30.0, 70.0], 0)
	for v in 2:
		_place([_ear_mesh(v, T1), _ear_mesh(v, T1 * 2.0)], ears[v], "Ears%d" % v, [30.0, 80.0], 0)
		_place(_lod(_boulder_mesh.bind(v + 2, false), 4.0), boulders[v], "Boulders%d" % v, [60.0, 180.0], 1)
	_place([_mushroom_mesh()], shrooms, "Mushrooms", [30.0], 0)
	_place(_lod(_log_mesh, 2.0), logs, "Logs", [60.0, 180.0], 1)


## Tiled LOD placement (shadow_tiers of the finest tiers cast).
func _place(meshes: Array, list: Array, node_name: String, ranges: Array, shadow_tiers: int) -> Node3D:
	var typed: Array[Transform3D] = []
	typed.assign(list)
	var tiers: Array[ArrayMesh] = []
	tiers.assign(meshes)
	stats["n_" + node_name] = typed.size()
	stats["tris_" + node_name] = tiers.map(func(m: ArrayMesh) -> int: return VoxelProp.quads(m) * 2)
	return VoxelProp.place(self, node_name, tiers, ranges, typed, shadow_tiers)


## A fern: 6-9 fronds as stepped blades arching out of a crown (T1/2).
func _fern_mesh(v: int, cell := T1 * 0.5) -> ArrayMesh:
	var bounds := AABB(Vector3(-1.4, -0.1, -1.4), Vector3(2.8, 1.5, 2.8))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5100 + v
		var count := 6 + v
		for f in count:
			var a := TAU * f / count + rng.randf_range(-0.3, 0.3)
			var dir := Vector3(cos(a), 0, sin(a))
			var len := rng.randf_range(0.9, 1.3)
			var lift := rng.randf_range(0.7, 1.2)
			var mat := Mat.FERN if f % 3 else Mat.FERN_DARK
			# A frond: an arc of leaflet blocks, widest a third of the way out.
			for s in 9:
				var u := float(s) / 8.0
				var pc := dir * len * u + Vector3.UP * (lift * sin(u * PI * 0.8) + 0.05)
				var wide := 0.2 * sin(u * PI) + 0.04
				var side := Vector3(-dir.z, 0, dir.x)
				g.paint(AABB(pc - Vector3.ONE * 0.3, Vector3.ONE * 0.6), func(p: Vector3) -> float:
					var q := p - pc
					return maxf(maxf(absf(q.dot(side)) - wide, absf(q.dot(dir)) - 0.06), absf(q.y) - 0.035),
					mat, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y > 0.7 and VoxelSdf.hash3(c, 5) < 0.35, Mat.LEAF_TOP, [Mat.FERN])
	return _mesh("vf_fern%d" % v, bounds, cell, paint)


## Elephant-ear plant: 3-4 big flat heart-ish leaves on stalks (T1/2).
func _ear_mesh(v: int, cell := T1 * 0.5) -> ArrayMesh:
	var bounds := AABB(Vector3(-1.8, -0.1, -1.8), Vector3(3.6, 2.4, 3.6))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5200 + v
		for f in 3 + v:
			var a := TAU * f / (3 + v) + rng.randf_range(-0.3, 0.3)
			var dir := Vector3(cos(a), 0, sin(a))
			var top := dir * rng.randf_range(0.6, 1.0) + Vector3.UP * rng.randf_range(0.55, 1.05)
			g.paint(AABB(Vector3(-1.2, 0, -1.2), Vector3(2.4, 2.0, 2.4)), func(p: Vector3) -> float:
				return VoxelSdf.capsule(p, Vector3.ZERO, top, 0.05, 0.035), Mat.FERN_DARK, -1, VoxelGrid.Mode.ADD)
			var lc := top + dir * 0.55
			var tilt := -0.35
			g.paint(AABB(lc - Vector3.ONE * 0.9, Vector3.ONE * 1.8), func(p: Vector3) -> float:
				var q := p - lc
				var along := q.dot(dir)
				var side := q.dot(Vector3(-dir.z, 0, dir.x))
				var plane := absf(q.y - along * tilt) - 0.04
				return maxf(plane, VoxelSdf.slice(along, side, 0.85, 0.55 - along * 0.15)), Mat.LEAF, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return g.get_mat(c.x, c.y + 1, c.z) == 0 and p.y > 0.5, Mat.LEAF_TOP, [Mat.LEAF])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return VoxelSdf.hash3(c, 9) < 0.15, Mat.FERN, [Mat.LEAF, Mat.LEAF_TOP])
	return _mesh("vf_ear_b%d" % v, bounds, cell, paint)


## A mossy boulder (design about 2 m): faceted, a moss cap, wet-dark foot;
## `wet` makes the plunge-pool and lip version (dark basalt, little moss).
func _boulder_mesh(v: int, wet: bool) -> ArrayMesh:
	var bounds := AABB(Vector3(-1.3, -0.5, -1.3), Vector3(2.6, 2.0, 2.6))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5300 + v
		var hx := rng.randf_range(0.8, 1.1)
		var hy := rng.randf_range(0.5, 0.75)
		var hz := rng.randf_range(0.7, 1.0)
		var base := Mat.BASALT if wet else Mat.STONE_DARK
		g.paint(bounds, func(p: Vector3) -> float:
			var q := p - Vector3(0, hy * 0.6, 0)
			var facet := maxf(absf(q.x) / hx, maxf(absf(q.y) / hy, absf(q.z) / hz))
			facet = maxf(facet, (absf(q.x) / hx + absf(q.y) / hy + absf(q.z) / hz) * 0.62)
			return facet - 1.0, base)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return g.get_mat(c.x, c.y + 1, c.z) == 0 and VoxelSdf.hash3(c, 3) < (0.35 if wet else 0.85), Mat.MOSS, [base])
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool:
			return VoxelSdf.hash3(c, 7) < 0.3, Mat.MOSS_LIGHT, [Mat.MOSS])
		if not wet:
			g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
				return p.y > hy * 0.8 and VoxelSdf.hash3(c, 11) < 0.5, Mat.STONE, [base])
	return _mesh("vf_boulder%d%s" % [v, "w" if wet else ""], bounds, _cell_or(T1), paint)


func _cell_or(cell: float) -> float:
	return cell


## A cluster of 5-7 mushrooms (T0): pale stems, brown caps with flecks.
func _mushroom_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.35, -0.02, -0.35), Vector3(0.7, 0.35, 0.7))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5400
		for k in 6:
			var b := Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
			var h := rng.randf_range(0.08, 0.22)
			var r := rng.randf_range(0.04, 0.08)
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, b, b + Vector3.UP * h, 0.018, 0.014), Mat.MUSHROOM)
			var cc := b + Vector3.UP * h
			g.paint(bounds, func(p: Vector3) -> float:
				return maxf(VoxelSdf.ellipsoid(p, cc, Vector3(r, r * 0.6, r)), cc.y - 0.01 - p.y), Mat.MUSHROOM_CAP, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool: return VoxelSdf.hash3(c, 5) < 0.15, Mat.MUSHROOM, [Mat.MUSHROOM_CAP])
	return _mesh("vf_mushrooms", bounds, T0, paint)


## A fallen log (6 m) with shelf fungus and a moss back (T1).
func _log_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-3.4, -0.3, -0.9), Vector3(6.8, 1.6, 1.8))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.cylinder(p, Vector3(-3, 0.4, 0), Vector3(3, 0.35, 0), 0.55, 0.45), Mat.BARK)
		g.paint(bounds, func(p: Vector3) -> float:
			return VoxelSdf.cylinder(p, Vector3(-3.4, 0.4, 0), Vector3(-2.6, 0.4, 0), 0.35, 0.35), Mat.HEARTWOOD, -1, VoxelGrid.Mode.FILL)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y > 0.7 and VoxelSdf.hash3(c, 3) < 0.8, Mat.MOSS, [Mat.BARK])
		for k in 4:
			var fc := Vector3(-2.0 + k * 1.3, 0.35 + 0.1 * (k % 2), 0.55 * (1 if k % 2 else -1))
			g.paint(AABB(fc - Vector3(0.4, 0.1, 0.4), Vector3(0.8, 0.2, 0.8)), func(p: Vector3) -> float:
				return maxf(VoxelSdf.ellipsoid(p, fc, Vector3(0.3, 0.06, 0.25)), 0.0), Mat.FUNGUS, -1, VoxelGrid.Mode.ADD)
	return _mesh("vf_log", bounds, T1 * _cell_scale_k(), paint)


func _cell_scale_k() -> float:
	return 1.0


# ---------------------------------------------------------------- shore

## Reeds along the waterline, lily pads on the shallows, a frog on one pad.
func _shore() -> void:
	var reeds: Array = [[], []]
	var pads: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var area := Rect2(local(-230, -110), Vector2(460, 260))
	for k in 30000:
		var w := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		var g := ground_at(w.x, w.y)
		if near_spawn(w) or w.distance_to(islet_at) < 3.0:
			continue
		if g > -0.3 and g < 0.6 and rng.randf() < 0.7:
			(reeds[k % 2] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)),
				Vector3(w.x, maxf(g, -0.3) - 0.05, w.y)))
		elif g > -1.6 and g < -0.4 and rng.randf() < 0.22:
			pads.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4)), Vector3(w.x, 0.02, w.y)))
	for v in 2:
		_place([_reed_mesh(v)], reeds[v], "Reeds%d" % v, [45.0], 0)
	_place([_lily_mesh()], pads, "LilyPads", [60.0], 0)
	if not pads.is_empty():
		var frog := _frog_mesh()
		_single([frog], [40.0], Transform3D(Basis(Vector3.UP, 0.7), pads[pads.size() / 2].origin + Vector3.UP * 0.02), "Frog")


func _reed_mesh(v: int) -> ArrayMesh:
	var bounds := AABB(Vector3(-0.5, -0.1, -0.5), Vector3(1.0, 1.9, 1.0))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5500 + v
		for k in 9:
			var b := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
			var tip := b + Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(1.0, 1.7), rng.randf_range(-0.2, 0.2))
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, b, tip, 0.03, 0.015), Mat.REED, -1, VoxelGrid.Mode.ADD)
			if k % 3 == 0:
				var head := tip.lerp(b, 0.12)
				g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, head, tip.lerp(b, 0.25), 0.05, 0.05), Mat.MUSHROOM_CAP, -1, VoxelGrid.Mode.FILL)
	return _mesh("vf_reed%d" % v, bounds, T0 * 2.0, paint)


func _lily_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.5, -0.05, -0.5), Vector3(1.0, 0.2, 1.0))
	var paint := func(g: VoxelGrid) -> void:
		for k in 3:
			var c := Vector3([-0.15, 0.2, 0.0][k], 0, [0.1, 0.05, -0.22][k])
			var r := [0.26, 0.2, 0.16][k] as float
			g.paint(bounds, func(p: Vector3) -> float:
				var q := p - c
				var notch := 1.0 if (absf(atan2(q.z, q.x) - 0.3) < 0.25 and q.length() > 0.03) else 0.0
				return maxf(maxf(Vector2(q.x, q.z).length() - r, absf(q.y) - 0.012), notch - 0.5), Mat.LILY, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.sphere(p, Vector3(0.2, 0.05, 0.05), 0.05), Mat.PETAL_WHITE, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool: return VoxelSdf.hash3(c, 3) < 0.25, Mat.LEAF_TOP, [Mat.LILY])
	return _mesh("vf_lily", bounds, T0, paint)


## A small frog-green frog with big eyes, sitting (T0).
func _frog_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.12, -0.01, -0.12), Vector3(0.24, 0.16, 0.24))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.ellipsoid(p, Vector3(0, 0.045, 0), Vector3(0.06, 0.04, 0.075)), Mat.FROG)
		for sx: float in [-1.0, 1.0]:
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.sphere(p, Vector3(sx * 0.035, 0.085, 0.045), 0.018), Mat.MUSHROOM, -1, VoxelGrid.Mode.FILL)
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.sphere(p, Vector3(sx * 0.037, 0.088, 0.058), 0.009), Mat.CARVE, -1, VoxelGrid.Mode.FILL)
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.ellipsoid(p, Vector3(sx * 0.06, 0.015, -0.03), Vector3(0.025, 0.02, 0.05)), Mat.FROG, -1, VoxelGrid.Mode.ADD)
	return _mesh("vf_frog", bounds, T0 * 0.5, paint)


# ---------------------------------------------------------------- story props

func _story_props() -> void:
	_shrine()
	_walkway()
	_sluice()
	_fallen_giant()
	_islet()
	_height_marks()


func _single(meshes: Array, ranges: Array, xf: Transform3D, node_name: String) -> Node3D:
	var typed: Array[ArrayMesh] = []
	typed.assign(meshes)
	return VoxelProp.single(self, node_name, typed, ranges, xf)


## Story 1, the overgrown shrine: a stone platform with a stair, the altar
## with the Falling Leaf emblem and fresh orchids, a frog guardian, roots
## through the stones; its heron guardian lies toppled in the lake shallows.
func _shrine() -> void:
	var g := _max_ground(shrine_at, 4.0) - 0.1
	var yaw := atan2(spawns[1].x - shrine_at.x, spawns[1].y - shrine_at.y)
	_single(_lod(_shrine_mesh, 4.0), [80.0, 0.0], Transform3D(Basis(Vector3.UP, yaw), Vector3(shrine_at.x, g, shrine_at.y)), "Shrine")
	# The toppled heron: the nearest shallows toward the lake (north).
	var w := shrine_at
	for k in 80:
		w = shrine_at + Vector2(-0.3, -1.0).normalized() * k
		if ground_at(w.x, w.y) < -0.3:
			break
	var hy := ground_at(w.x, w.y)
	_single(_lod(_heron_mesh, 4.0), [80.0, 0.0], Transform3D(Basis(Vector3.UP, 1.1) * Basis(Vector3.FORWARD, PI * 0.5 - 0.15),
		Vector3(w.x, hy + 0.35, w.y)), "HeronToppled")
	stats["heron_at"] = w


## Highest floor under a footprint of radius r.
func _max_ground(w: Vector2, r: float) -> float:
	var hi := -INF
	for k in 9:
		var a := TAU * k / 8.0
		var p := w + (Vector2(cos(a), sin(a)) * r if k > 0 else Vector2.ZERO)
		hi = maxf(hi, ground_at(p.x, p.y))
	return hi


## Lowest floor under a footprint of radius r (props sink, never float).
func _min_ground(w: Vector2, r: float) -> float:
	var lo := INF
	for k in 9:
		var a := TAU * k / 8.0
		var p := w + (Vector2(cos(a), sin(a)) * r if k > 0 else Vector2.ZERO)
		lo = minf(lo, ground_at(p.x, p.y))
	return lo


func _shrine_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-5.5, -2.2, -5.5), Vector3(11, 7.2, 11))
	var paint := func(g: VoxelGrid) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 6100
		# Platform: laid blocks with joints (each block its own slight height).
		for bx in 6:
			for bz in 6:
				var c := Vector3(-3.75 + bx * 1.5, -0.5, -3.75 + bz * 1.5)
				var lift := rng.randf_range(-0.06, 0.08)
				g.paint(AABB(c - Vector3(0.8, 1.1, 0.8), Vector3(1.6, 2.2, 1.6)), func(p: Vector3) -> float:
					return VoxelSdf.box(p, c + Vector3(0, lift, 0), Vector3(0.7, 1.0, 0.7), 0.04), Mat.STONE)
				# Foundation course under it, into the slope.
				g.paint(AABB(c - Vector3(0.8, 2.1, 0.8), Vector3(1.6, 1.2, 1.6)), func(p: Vector3) -> float:
					return VoxelSdf.box(p, c + Vector3(0, -1.5, 0), Vector3(0.74, 0.55, 0.74), 0.03), Mat.STONE_DARK, -1, VoxelGrid.Mode.ADD)
		# Stair down the front (+z), three steps.
		for s in 3:
			var c := Vector3(0, -0.85 - s * 0.3, 4.9 + s * 0.45)
			g.paint(AABB(c - Vector3(2.0, 0.5, 0.4), Vector3(4.0, 1.0, 0.8)), func(p: Vector3) -> float:
				return VoxelSdf.box(p, c, Vector3(1.8, 0.35 + s * 0.15, 0.24), 0.03), Mat.STONE)
		# Altar: a block with a recessed top and the Falling Leaf on its front.
		g.paint(AABB(Vector3(-1.4, 0.4, -3.2), Vector3(2.8, 1.6, 1.8)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 1.05, -2.3), Vector3(1.2, 0.6, 0.7), 0.04), Mat.STONE)
		g.paint(AABB(Vector3(-1.6, 1.6, -3.3), Vector3(3.2, 0.4, 2.0)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, 1.72, -2.3), Vector3(1.35, 0.1, 0.82), 0.02), Mat.STONE_DARK)
		g.paint_surface(AABB(Vector3(-1.3, 0.5, -1.7), Vector3(2.6, 1.2, 0.3)), func(p: Vector3, _c: Vector3i) -> bool:
			return _emblem(Vector2(p.x, p.y - 1.05) / 0.55), Mat.CARVE, [Mat.STONE])
		# Fresh orchids laid on the altar (the accent).
		for k in 5:
			var oc := Vector3(rng.randf_range(-0.8, 0.8), 1.85, -2.3 + rng.randf_range(-0.4, 0.4))
			g.paint(AABB(oc - Vector3.ONE * 0.2, Vector3.ONE * 0.4), func(p: Vector3) -> float:
				return VoxelSdf.ellipsoid(p, oc, Vector3(0.14, 0.06, 0.1)), Mat.ORCHID if k % 2 == 0 else Mat.ORCHID_DARK, -1, VoxelGrid.Mode.ADD)
			g.paint(AABB(oc - Vector3(0.3, 0.1, 0.3), Vector3(0.6, 0.2, 0.6)), func(p: Vector3) -> float:
				return VoxelSdf.capsule(p, oc, oc + Vector3(0.25, -0.03, 0.1), 0.02, 0.02), Mat.LEAF, -1, VoxelGrid.Mode.ADD)
		# The frog guardian (original): squat body, wide mouth, big round eyes, on a plinth.
		var fp := Vector3(-3.2, 0.5, 2.6)
		g.paint(AABB(fp - Vector3(0.7, 0, 0.7), Vector3(1.4, 0.5, 1.4)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, fp + Vector3(0, 0.2, 0), Vector3(0.6, 0.2, 0.6), 0.03), Mat.STONE_DARK)
		var fb := fp + Vector3(0, 0.95, 0)
		g.paint(AABB(fb - Vector3(0.8, 0.6, 0.8), Vector3(1.6, 1.4, 1.6)), func(p: Vector3) -> float:
			return VoxelSdf.ellipsoid(p, fb, Vector3(0.6, 0.5, 0.65)), Mat.STONE)
		for sx: float in [-1.0, 1.0]:
			var eye := fb + Vector3(sx * 0.3, 0.45, 0.3)
			g.paint(AABB(eye - Vector3.ONE * 0.25, Vector3.ONE * 0.5), func(p: Vector3) -> float:
				return VoxelSdf.sphere(p, eye, 0.2), Mat.STONE, -1, VoxelGrid.Mode.ADD)
			g.paint(AABB(eye - Vector3.ONE * 0.25, Vector3.ONE * 0.5), func(p: Vector3) -> float:
				return VoxelSdf.sphere(p, eye + Vector3(0, 0, 0.17), 0.07), Mat.CARVE, -1, VoxelGrid.Mode.FILL)
			var foot := fp + Vector3(sx * 0.45, 0.5, 0.5)
			g.paint(AABB(foot - Vector3.ONE * 0.3, Vector3.ONE * 0.6), func(p: Vector3) -> float:
				return VoxelSdf.ellipsoid(p, foot, Vector3(0.2, 0.08, 0.25)), Mat.STONE, -1, VoxelGrid.Mode.ADD)
		g.paint(AABB(fb - Vector3(0.6, 0.2, -0.4), Vector3(1.2, 0.3, 0.4)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, fb + Vector3(0, -0.05, 0.6), Vector3(0.4, 0.025, 0.1)), Mat.CARVE, -1, VoxelGrid.Mode.FILL)
		# The heron's empty plinth (it fell into the lake).
		var hp := Vector3(3.2, 0.5, 2.6)
		g.paint(AABB(hp - Vector3(0.7, 0, 0.7), Vector3(1.4, 0.5, 1.4)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, hp + Vector3(0, 0.2, 0), Vector3(0.6, 0.2, 0.6), 0.03), Mat.STONE_DARK)
		g.paint(AABB(hp + Vector3(-0.3, 0.4, -0.2), Vector3(0.6, 0.3, 0.4)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, hp + Vector3(0.05, 0.5, 0), Vector3(0.12, 0.1, 0.14)), Mat.STONE, -1, VoxelGrid.Mode.ADD)
		# Roots growing through: from the back corner over the blocks and down the sides.
		for k in 5:
			var a := rng.randf_range(-2.4, -0.7)
			var from := Vector3(-5.4 + k * 0.6, 0.6, -5.4)
			var to := Vector3(cos(a) * 5.5 + rng.randf_range(-1, 3), -0.4, rng.randf_range(-2.0, 4.5))
			var mid := from.lerp(to, 0.5) + Vector3.UP * 0.45
			for seg: Array in [[from, mid], [mid, to]]:
				var p0: Vector3 = seg[0]
				var p1: Vector3 = seg[1]
				var lo := Vector3(minf(p0.x, p1.x), minf(p0.y, p1.y), minf(p0.z, p1.z)) - Vector3.ONE * 0.4
				g.paint(AABB(lo, (p1 - p0).abs() + Vector3.ONE * 0.8), func(p: Vector3) -> float:
					return VoxelSdf.capsule(p, p0, p1, 0.24, 0.14), Mat.ROOT, -1, VoxelGrid.Mode.FILL)
		# Moss caps and joints, orchids in a root crook.
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			var open_up := g.get_mat(c.x, c.y + 1, c.z) == 0
			return open_up and VoxelSdf.hash3(c, 3) < 0.35 + (0.4 if p.z < -2.0 or absf(p.x) > 3.5 else 0.0), Mat.MOSS,
			[Mat.STONE, Mat.STONE_DARK, Mat.ROOT])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return (fposmod(p.x + 0.75, 1.5) < 0.09 or fposmod(p.z + 0.75, 1.5) < 0.09) and p.y > -0.1 and p.y < 0.6 and VoxelSdf.hash3(c, 5) < 0.7,
			Mat.MOSS, [Mat.STONE])
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool: return VoxelSdf.hash3(c, 9) < 0.3, Mat.MOSS_LIGHT, [Mat.MOSS])
	return _mesh("vf_shrine_b", bounds, T1, paint, [Mat.MOSS])


## The Falling Leaf (original emblem): a leaf whose vein becomes a falling
## line, inside a broken circle. q in emblem units (radius 1).
static func _emblem(q: Vector2) -> bool:
	var r := q.length()
	var ring := absf(r - 0.92) < 0.08 and not (q.y < -0.6 and absf(q.x) < 0.25)
	var leaf := VoxelSdf.slice(q.x, q.y - 0.15, 0.32 * (1.0 - absf(q.y - 0.15) * 0.4), 0.6) < 0.0 \
		and not (absf(q.x) < 0.05)
	var vein := absf(q.x) < 0.05 and q.y < 0.55 and q.y > -0.85
	return ring or (leaf and r < 0.85) or vein


## The heron guardian (original), toppled: a tall stone bird on its side,
## long beak, folded wings, moss on the upper side (it lies in the shallows).
func _heron_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.8, -0.3, -0.9), Vector3(1.6, 3.6, 1.8))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 0.0, 0), Vector3(0.5, 0.15, 0.5), 0.03), Mat.STONE_DARK)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, Vector3(0, 0.15, 0), Vector3(0, 0.9, 0.05), 0.06, 0.06), Mat.STONE)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.ellipsoid(p, Vector3(0, 1.4, 0), Vector3(0.36, 0.55, 0.45)), Mat.STONE, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, Vector3(0, 1.8, 0.1), Vector3(0, 2.6, 0.25), 0.12, 0.09), Mat.STONE, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.ellipsoid(p, Vector3(0, 2.75, 0.25), Vector3(0.14, 0.14, 0.18)), Mat.STONE, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, Vector3(0, 2.75, 0.35), Vector3(0, 2.7, 0.85), 0.05, 0.015), Mat.STONE, -1, VoxelGrid.Mode.ADD)
		for sx: float in [-1.0, 1.0]:
			g.paint(bounds, func(p: Vector3) -> float:
				return VoxelSdf.box(p, Vector3(sx * 0.33, 1.35, -0.05), Vector3(0.06, 0.4, 0.38), 0.02), Mat.STONE_DARK, -1, VoxelGrid.Mode.ADD)
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.sphere(p, Vector3(sx * 0.11, 2.8, 0.32), 0.03), Mat.CARVE, -1, VoxelGrid.Mode.FILL)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.x > 0.1 and VoxelSdf.hash3(c, 3) < 0.6, Mat.MOSS, [Mat.STONE, Mat.STONE_DARK])
	return _mesh("vf_heron", bounds, T1 * 0.5, paint)


## Story 2, the canopy walkway between two giants of the grove: planks on a
## rope catenary at about 22 m, two missing, rope rails, ring platforms on
## both trunks and a lantern hook with no lantern.
func _walkway() -> void:
	if grove_pair.size() < 2:
		return
	var a := tree_base(grove_pair[0])
	var b := tree_base(grove_pair[1])
	var ra := tree_radius(grove_pair[0])
	var rb := tree_radius(grove_pair[1])
	var dir := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var deck_y := maxf(a.y, b.y) + 22.0
	var p0 := Vector3(a.x, deck_y, a.z) + dir * (ra + 1.2)
	var p1 := Vector3(b.x, deck_y, b.z) - dir * (rb + 1.2)
	var span := p0.distance_to(p1)
	var yaw := atan2(dir.x, dir.z)
	var planks: Array[Transform3D] = []
	var count := int(span / 0.55)
	for k in count:
		if k == count / 3 or k == count / 3 + 4:
			continue
		var u := (k + 0.5) / count
		var p := p0.lerp(p1, u) + Vector3.DOWN * span * 0.08 * 4.0 * u * (1.0 - u)
		planks.append(Transform3D(Basis(Vector3.UP, yaw + VoxelSdf.hash3(Vector3i(k, 0, 0), 3) * 0.08 - 0.04), p))
	_place(_lod(_plank_mesh, 4.0), planks, "WalkwayPlanks", [90.0, 260.0], 1)
	# Rope rails: rigid segments along both sides, 1.1 m up, sagging with the deck.
	var ropes: Array[Transform3D] = []
	var side := Vector3(-dir.z, 0, dir.x)
	for s: float in [-1.0, 1.0]:
		var prev := Vector3.ZERO
		for k in 25:
			var u := float(k) / 24.0
			var p := p0.lerp(p1, u) + Vector3.DOWN * span * 0.08 * 4.0 * u * (1.0 - u) + side * s * 0.75 + Vector3.UP * 1.1
			if k > 0:
				ropes.append(_along(prev, p))
				# Hangers down to the deck every other segment.
				if k % 2 == 0:
					ropes.append(_along(p, p + Vector3.DOWN * 1.1))
			prev = p
	_place([_rope_mesh()], ropes, "WalkwayRopes", [120.0], 0)
	for k in 2:
		var c := a if k == 0 else b
		var r := ra if k == 0 else rb
		_single(_lod(_ring_platform_mesh.bind(k), 4.0), [100.0, 0.0],
			Transform3D(Basis(Vector3.UP, yaw + PI * k).scaled(Vector3.ONE * (r / 6.0)), Vector3(c.x, deck_y - 0.25, c.z)), "TreePlatform%d" % k)
	stats["walkway"] = {"span": span, "deck_y": deck_y, "mid": p0.lerp(p1, 0.5)}


static func _along(a: Vector3, b: Vector3) -> Transform3D:
	var d := b - a
	var len := d.length()
	var y := d / len
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x, y * len, z), a)


func _plank_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.9, -0.12, -0.3), Vector3(1.8, 0.2, 0.6))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, -0.03, 0), Vector3(0.8, 0.05, 0.22), 0.01), Mat.WOOD)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool: return absf(p.x) > 0.7 or VoxelSdf.hash3(c, 3) < 0.2, Mat.WOOD_NEW, [Mat.WOOD])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool: return p.x < -0.4 and VoxelSdf.hash3(c, 5) < 0.3, Mat.MOSS, [Mat.WOOD])
	return _mesh("vf_plank", bounds, T0 * 2.0, paint)


## A unit rope segment along +y (scaled to length by the transform).
func _rope_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.05, 0, -0.05), Vector3(0.1, 1.0, 0.1))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 0.5, 0), Vector3(0.025, 0.5, 0.025)), Mat.ROPE)
	return _mesh("vf_rope", bounds, T0, paint)


## A ring platform round a giant (design trunk radius 6): planks on brackets,
## a rail, and on the first one the lantern hook with no lantern.
func _ring_platform_mesh(v: int) -> ArrayMesh:
	var bounds := AABB(Vector3(-8.6, -2.6, -8.6), Vector3(17.2, 5.0, 17.2))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float:
			var r := Vector2(p.x, p.z).length()
			var arc := atan2(p.z, p.x)
			if absf(wrapf(arc - PI * 0.5, -PI, PI)) > 2.0:
				return 1.0
			return maxf(maxf(6.1 - r, r - 8.2), absf(p.y) - 0.09), Mat.WOOD)
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return fposmod(atan2(p.z, p.x) * 18.0, 1.0) < 0.12, Mat.BARK_DARK, [Mat.WOOD])
		for k in 5:
			var a := PI * 0.5 + (k - 2) * 0.9
			var d := Vector3(cos(a), 0, sin(a))
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, d * 6.0 + Vector3.DOWN * 2.2, d * 7.8 + Vector3.DOWN * 0.1, 0.12, 0.1), Mat.WOOD, -1, VoxelGrid.Mode.ADD)
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.capsule(p, d * 8.1, d * 8.1 + Vector3.UP * 1.1, 0.07, 0.07), Mat.WOOD, -1, VoxelGrid.Mode.ADD)
		g.paint(bounds, func(p: Vector3) -> float:
			var r := Vector2(p.x, p.z).length()
			if absf(wrapf(atan2(p.z, p.x) - PI * 0.5, -PI, PI)) > 1.85:
				return 1.0
			return maxf(absf(r - 8.1) - 0.05, absf(p.y - 1.1) - 0.04), Mat.ROPE, -1, VoxelGrid.Mode.ADD)
		if v == 0:
			# The lantern hook: an iron bracket with an empty hook.
			var hb := Vector3(0, 1.8, 6.0)
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, hb + Vector3(0, 0, 0.5), Vector3(0.04, 0.04, 0.5)), Mat.IRON, -1, VoxelGrid.Mode.ADD)
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.torus(p, hb + Vector3(0, -0.12, 0.95), Vector3.RIGHT, 0.08, 0.02), Mat.IRON, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool: return p.y > 0.05 and VoxelSdf.hash3(c, 9) < 0.12, Mat.MOSS, [Mat.WOOD])
	return _mesh("vf_ring_platform%d" % v, bounds, T0 * 2.0, paint)


## Story 3, the broken sluice: a stone channel from the shrine's basin toward
## the lake, a timber gate on an iron frame with its lower board broken out,
## water running through and spilling off the channel's end in a small fall.
func _sluice() -> void:
	var to_lake := (Vector2(centre.x, centre.y - 20) - sluice_at).normalized()
	var yaw := atan2(to_lake.x, to_lake.y)
	var g := _min_ground(sluice_at, 3.0)
	_single(_lod(_sluice_mesh, 4.0), [80.0, 0.0], Transform3D(Basis(Vector3.UP, yaw), Vector3(sluice_at.x, g, sluice_at.y)), "Sluice")
	stats["sluice_yaw"] = yaw


func _sluice_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-1.8, -2.2, -6.5), Vector3(3.6, 4.2, 14.5))
	var paint := func(g: VoxelGrid) -> void:
		# Channel walls and bed: laid blocks along +z (toward the lake).
		for k in 9:
			var z := -6.0 + k * 1.4
			for s: float in [-1.0, 1.0]:
				g.paint(AABB(Vector3(s * 1.1 - 0.5, -1.5, z - 0.8), Vector3(1.0, 2.6, 1.6)), func(p: Vector3) -> float:
					return VoxelSdf.box(p, Vector3(s * 1.1, -0.35 + 0.04 * (k % 2), z), Vector3(0.32, 0.9, 0.66), 0.03), Mat.STONE)
			g.paint(AABB(Vector3(-1.5, -1.6, z - 0.8), Vector3(3.0, 0.8, 1.6)), func(p: Vector3) -> float:
				return VoxelSdf.box(p, Vector3(0, -1.2, z), Vector3(1.2, 0.3, 0.68), 0.03), Mat.STONE_DARK)
		# The last wall blocks have fallen: a gap at the far end.
		g.paint(AABB(Vector3(0.6, -1.6, 5.2), Vector3(1.2, 2.4, 2.0)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(1.1, 0.0, 6.2), Vector3(0.5, 1.2, 0.9)), Mat.STONE, -1, VoxelGrid.Mode.CARVE)
		# Water: a stepped ribbon in the channel, then a spill over the end.
		g.paint(AABB(Vector3(-0.9, -1.0, -6.4), Vector3(1.8, 0.5, 12.6)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, -0.82, -0.2), Vector3(0.78, 0.07, 6.2)), Mat.WATER, -1, VoxelGrid.Mode.ADD)
		g.paint(AABB(Vector3(-0.9, -2.2, 5.8), Vector3(1.8, 1.6, 1.0)), func(p: Vector3) -> float:
			return VoxelSdf.box(p, Vector3(0, -1.5, 6.25), Vector3(0.7, 0.7, 0.07)), Mat.WATER, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(AABB(Vector3(-0.9, -2.2, 5.6), Vector3(1.8, 1.8, 1.0)), func(_p: Vector3, c: Vector3i) -> bool:
			return VoxelSdf.hash3(c, 3) < 0.5, Mat.FOAM, [Mat.WATER])
		# Gate: iron frame posts and lintel, boards with the lowest one broken out.
		for s: float in [-1.0, 1.0]:
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(s * 0.95, 0.3, -1.0), Vector3(0.09, 1.3, 0.09)), Mat.IRON, -1, VoxelGrid.Mode.FILL)
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 1.6, -1.0), Vector3(1.05, 0.08, 0.1)), Mat.IRON, -1, VoxelGrid.Mode.FILL)
		for b in 3:
			var y := 1.25 - b * 0.32
			g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, y, -1.0), Vector3(0.84, 0.14, 0.05)), Mat.WOOD, -1, VoxelGrid.Mode.ADD)
		# The broken board, hanging askew from one end.
		g.paint(bounds, func(p: Vector3) -> float:
			var q := (p - Vector3(-0.3, 0.05, -0.9)).rotated(Vector3.FORWARD, 0.5)
			return VoxelSdf.box(q, Vector3.ZERO, Vector3(0.55, 0.12, 0.05)), Mat.WOOD, -1, VoxelGrid.Mode.ADD)
		# The Falling Leaf on the lintel's stone above, moss and fern tufts on the walls.
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 1.85, -1.0), Vector3(0.35, 0.18, 0.12), 0.02), Mat.STONE, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(AABB(Vector3(-0.4, 1.65, -0.95), Vector3(0.8, 0.4, 0.1)), func(p: Vector3, _c: Vector3i) -> bool:
			return _emblem(Vector2(p.x, p.y - 1.85) / 0.17), Mat.CARVE, [Mat.STONE])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return g.get_mat(c.x, c.y + 1, c.z) == 0 and VoxelSdf.hash3(c, 5) < 0.55, Mat.MOSS, [Mat.STONE, Mat.STONE_DARK])
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool: return VoxelSdf.hash3(c, 9) < 0.15, Mat.STONE_DARK, [Mat.STONE])
	return _mesh("vf_sluice", bounds, T1 * 0.5, paint)


## Story 4, the fallen giant: its trunk across the floor, hollowed at the
## broken end and carpeted in moss, the root plate standing up like a wall.
func _fallen_giant() -> void:
	var g := _min_ground(fallen_at, 8.0)
	var yaw := 0.9
	_single(_lod(_fallen_mesh, 2.0), [140.0, 0.0], Transform3D(Basis(Vector3.UP, yaw), Vector3(fallen_at.x, g, fallen_at.y)), "FallenGiant")


func _fallen_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-4, -1.0, -21), Vector3(8, 12, 40))
	var paint := func(g: VoxelGrid) -> void:
		# The trunk, lying along z, sunk a little into the floor.
		g.paint(AABB(Vector3(-3.6, -1, -15), Vector3(7.2, 7.4, 33)), func(p: Vector3) -> float:
			return maxf(_octagon(Vector3(p.x, 0, p.y - 2.4), lerpf(3.2, 2.4, (p.z + 14.0) / 32.0)) , maxf(-14.0 - p.z, p.z - 18.0)), Mat.BARK)
		# Hollow at the broken end (+z), pale heartwood rim.
		g.paint(AABB(Vector3(-2.4, 0, 12), Vector3(4.8, 4.8, 7)), func(p: Vector3) -> float:
			return maxf(_octagon(Vector3(p.x, 0, p.y - 2.4), 1.7), 12.5 - p.z), Mat.BARK, -1, VoxelGrid.Mode.CARVE)
		g.paint_surface(AABB(Vector3(-3.5, -1, 16.8), Vector3(7, 7, 1.5)), func(_p: Vector3, _c: Vector3i) -> bool: return true, Mat.HEARTWOOD, [Mat.BARK])
		# Root plate: a disc of soil and roots standing up at -z.
		g.paint(AABB(Vector3(-4, -1, -21), Vector3(8, 12, 7.5)), func(p: Vector3) -> float:
			var q := p - Vector3(0, 4.5, -15.5)
			var r := Vector2(q.x, q.y).length()
			var a := atan2(q.y, q.x)
			return maxf(r - (5.2 + 0.6 * sin(a * 5.0) + 0.4 * sin(a * 11.0)), absf(q.z) - 0.9 - 0.4 * (1.0 - r / 5.5)), Mat.SOIL, -1, VoxelGrid.Mode.ADD)
		var rng := RandomNumberGenerator.new()
		rng.seed = 6400
		for k in 14:
			var a := rng.randf() * TAU
			var from := Vector3(cos(a) * 3.0, 4.5 + sin(a) * 3.0, -16.2)
			var to := Vector3(cos(a) * rng.randf_range(4.8, 6.3), 4.5 + sin(a) * rng.randf_range(4.8, 6.3), -16.6 - rng.randf_range(0, 2.5))
			var lo := Vector3(minf(from.x, to.x), minf(from.y, to.y), minf(from.z, to.z)) - Vector3.ONE * 0.5
			g.paint(AABB(lo, (to - from).abs() + Vector3.ONE), func(p: Vector3) -> float:
				return VoxelSdf.capsule(p, from, to, 0.35, 0.1), Mat.ROOT, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
			return fposmod(atan2(p.y - 2.4, p.x) * 6.0 + p.z * 0.03, 1.0) < 0.2, Mat.BARK_DARK, [Mat.BARK])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return g.get_mat(c.x, c.y + 1, c.z) == 0 and VoxelSdf.hash3(c, 3) < 0.92, Mat.MOSS, [Mat.BARK, Mat.BARK_DARK, Mat.SOIL, Mat.ROOT])
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.z > 12.0 and p.y < 2.0 and VoxelSdf.hash3(c, 7) < 0.7, Mat.MOSS, [Mat.HEARTWOOD, Mat.BARK])
		g.paint_surface(bounds, func(_p: Vector3, c: Vector3i) -> bool: return VoxelSdf.hash3(c, 11) < 0.3, Mat.MOSS_LIGHT, [Mat.MOSS])
		# Shelf fungus along the flank, ferns on the root plate's top.
		for k in 7:
			var fc := Vector3(3.0, 1.6 + 0.4 * (k % 3), -10.0 + k * 3.6)
			g.paint(AABB(fc - Vector3(0.6, 0.2, 0.6), Vector3(1.2, 0.4, 1.2)), func(p: Vector3) -> float:
				return VoxelSdf.ellipsoid(p, fc, Vector3(0.5, 0.09, 0.4)), Mat.FUNGUS, -1, VoxelGrid.Mode.ADD)
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y > 8.5 and VoxelSdf.hash3(c, 13) < 0.5, Mat.FERN, [Mat.MOSS, Mat.MOSS_LIGHT, Mat.SOIL])
	return _mesh("vf_fallen", bounds, T1 * 2.0 * _cell_scale_k(), paint)


## Story 5, stepping stones from the south shore to an islet with a flat
## stone and a cairn.
func _islet() -> void:
	var stones: Array[Transform3D] = []
	var shore := islet_at
	for k in 40:
		var w := islet_at + (Vector2(centre.x, centre.y + 150) - islet_at).normalized() * k * 1.4
		if ground_at(w.x, w.y) > 0.3:
			shore = w
			break
	var n := int(shore.distance_to(islet_at) / 1.4)
	for k in range(1, n):
		var w := islet_at.lerp(shore, float(k) / n) + Vector2(sin(k * 1.9) * 0.4, cos(k * 1.3) * 0.3)
		var g := ground_at(w.x, w.y)
		stones.append(Transform3D(Basis(Vector3.UP, k * 0.9).scaled(Vector3(0.55, maxf(0.3, (0.25 - g) / 1.2), 0.55)), Vector3(w.x, g - 0.2, w.y)))
	_place([_boulder_mesh(4, true)], stones, "SteppingStones", [120.0], 1)
	var g := ground_at(islet_at.x, islet_at.y)
	_single(_lod(_islet_mesh, 4.0), [120.0, 0.0], Transform3D(Basis(Vector3.UP, 0.4), Vector3(islet_at.x, g, islet_at.y)), "Islet")
	stats["islet_stones"] = stones.size()


func _islet_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-2.2, -0.2, -2.2), Vector3(4.4, 3.6, 4.4))
	var paint := func(g: VoxelGrid) -> void:
		var top := -ground_at(islet_at.x, islet_at.y) + 0.25
		g.paint(bounds, func(p: Vector3) -> float:
			return maxf(VoxelSdf.slice(p.x, p.z, 1.9, 1.6, 3.0), maxf(p.y - top, -p.y)), Mat.STONE_DARK)
		g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool: return p.y > top - 0.12, Mat.STONE, [Mat.STONE_DARK])
		var y := top
		var rng := RandomNumberGenerator.new()
		rng.seed = 6500
		for k in 5:
			var r := 0.36 - k * 0.055
			var c := Vector3(rng.randf_range(-0.04, 0.04), y + r * 0.45, rng.randf_range(-0.04, 0.04))
			g.paint(AABB(c - Vector3.ONE * 0.5, Vector3.ONE), func(p: Vector3) -> float:
				return VoxelSdf.ellipsoid(p, c, Vector3(r, r * 0.45, r * 0.85)), Mat.STONE if k % 2 else Mat.STONE_DARK, -1, VoxelGrid.Mode.ADD)
			y += r * 0.9
		g.paint_surface(bounds, func(p: Vector3, c: Vector3i) -> bool:
			return p.y < top + 0.05 and p.y > top - 0.3 and VoxelSdf.hash3(c, 3) < 0.4, Mat.MOSS, [Mat.STONE, Mat.STONE_DARK])
	return _mesh("vf_islet", bounds, T1 * 0.5, paint)


## Story 6, carved height marks on a giant near the shrine: a smoothed bark
## panel with notches from knee height to above a fighter's head, the
## highest one fresh (pale wood).
func _height_marks() -> void:
	if marks_tree < 0:
		return
	var b := tree_base(marks_tree)
	var r := tree_radius(marks_tree)
	var to := (shrine_at - Vector2(b.x, b.z)).normalized()
	var pos := Vector3(b.x, b.y, b.z) + Vector3(to.x, 0, to.y) * (r * 0.96 + 0.05)
	var yaw := atan2(to.x, to.y)
	_single([_marks_mesh()], [45.0], Transform3D(Basis(Vector3.UP, yaw), pos), "HeightMarks")
	stats["marks_at"] = pos


func _marks_mesh() -> ArrayMesh:
	var bounds := AABB(Vector3(-0.5, 0.0, -0.15), Vector3(1.0, 2.8, 0.3))
	var paint := func(g: VoxelGrid) -> void:
		g.paint(bounds, func(p: Vector3) -> float: return VoxelSdf.box(p, Vector3(0, 1.4, -0.05), Vector3(0.36, 1.3, 0.08), 0.02), Mat.BARK_RIDGE)
		var heights := [0.55, 0.9, 1.22, 1.5, 1.74, 1.95, 2.18]
		for k in heights.size():
			var hgt: float = heights[k]
			var fresh := k == heights.size() - 1
			g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
				return absf(p.y - hgt) < 0.025 and absf(p.x + 0.05) < 0.2, Mat.HEARTWOOD if fresh else Mat.CARVE, [Mat.BARK_RIDGE])
			# A tally scratch beside each mark.
			g.paint_surface(bounds, func(p: Vector3, _c: Vector3i) -> bool:
				return absf(p.y - hgt - 0.04) < 0.04 and absf(p.x - 0.24) < 0.012, Mat.HEARTWOOD if fresh else Mat.CARVE, [Mat.BARK_RIDGE])
	return _mesh("vf_marks", bounds, T0, paint)


# ---------------------------------------------------------------- atmosphere

## Mist: see-through T3 puffs low over the lake and a spray cloud at the
## falls' foot.
func _mist() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = MIST_SHADER
	mat.set_shader_parameter("opacity", 0.09)
	_mist_mats.append(mat)
	var spray := ShaderMaterial.new()
	spray.shader = MIST_SHADER
	spray.set_shader_parameter("opacity", 0.5)
	spray.set_shader_parameter("mist_color", Color("#F0F4F2"))
	_mist_mats.append(spray)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var lake: Array[Transform3D] = []
	for k in 22:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 120.0
		var p := Vector3(centre.x + cos(a) * r, rng.randf_range(2.0, 6.0), centre.y - 30.0 + sin(a) * r * 0.7)
		lake.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rng.randf_range(1.4, 2.4), 0.2, rng.randf_range(1.4, 2.4))), p))
	var foot := falls_quad[2].lerp(falls_quad[3], 0.5)
	var plume: Array[Transform3D] = []
	for k in 9:
		var p := foot + Vector3(rng.randf_range(-30, 30), rng.randf_range(2, 16), rng.randf_range(0, 14))
		plume.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.35, 0.6)), p))
	var puff: Array[ArrayMesh] = [VoxelStage.puff_mesh(1)]
	for spec: Array in [[lake, mat, "LakeMist"], [plume, spray, "FallsSpray"]]:
		var root := VoxelProp.place(self, spec[2], puff, [0.0], spec[0], 0)
		for child in root.get_children():
			(child as GeometryInstance3D).material_override = spec[1]


## God-ray cards in canopy gaps and over the floor, along the hero sun.
func _shafts() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHAFT_SHADER
	_shaft_mats.append(mat)
	var sun := (presets().day.sun_dir as Vector3).normalized()
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.center_offset = Vector3(0, 0.5, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var spots: Array[Vector2] = [shrine_at + Vector2(-6, 4), local(-30, 120), local(10, 160), local(60, 175), local(-80, 140),
		local(90, 210), local(30, 230), local(-50, 205), local(120, 150), local(150, 220)]
	var shafts := Node3D.new()
	shafts.name = "GodRays"
	add_child(shafts)
	for w in spots:
		for j in 2:
			var foot := Vector3(w.x + rng.randf_range(-6, 6), ground_at(w.x, w.y), w.y + rng.randf_range(-6, 6))
			var len := rng.randf_range(45.0, 70.0)
			var up := -sun
			var width := rng.randf_range(3.0, 7.0)
			var mi := MeshInstance3D.new()
			mi.mesh = quad
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var y := up
			var x := y.cross(Vector3.UP).normalized().rotated(y, rng.randf() * PI)
			var z := x.cross(y)
			mi.transform = Transform3D(Basis(x * width, y * len, z), foot)
			shafts.add_child(mi)


## Spray and drifting pollen motes (GPUParticles3D, fixed fps so captures
## are repeatable).
func _particles() -> void:
	var foot := falls_quad[2].lerp(falls_quad[3], 0.5)
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.35, 0.35)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.97, 0.97, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = mat
	var spray := _emitter(box, 1800, 5.0, Vector3(32, 2, 6), Vector3(0, 1, 0.4), 4.0, 9.0, Vector3(0, -1.2, 0))
	spray.position = foot + Vector3(0, 1, 4)
	var mote := BoxMesh.new()
	mote.size = Vector3(0.022, 0.022, 0.022)
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(1.0, 0.97, 0.85)
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote.material = mm
	var motes := _emitter(mote, 2500, 30.0, Vector3(60, 8, 60), Vector3(0.3, 0.1, 0.2), 0.1, 0.4, Vector3(0, 0.01, 0))
	motes.position = Vector3(centre.x + 10, 9, centre.y + 140)


func _emitter(mesh: Mesh, amount: int, life: float, extents: Vector3, dir: Vector3, vmin: float, vmax: float, grav: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.draw_pass_1 = mesh
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.fixed_fps = 30
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(-extents * 2.0 - Vector3(0, 10, 0), extents * 4.0 + Vector3(0, 60, 0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = dir
	pm.spread = 25.0
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = grav
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.8
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	p.process_material = pm
	add_child(p)
	return p


# ---------------------------------------------------------------- shared helpers

func _mesh(key: String, bounds: AABB, cell: float, paint: Callable, soft := []) -> ArrayMesh:
	return VoxelProp.mesh(key, VERSION, bounds, cell * _cell_scale, paint, color, surface_of, soft)


func _coarse(make: Callable, k := 4.0) -> ArrayMesh:
	_cell_scale = k
	var m: ArrayMesh = make.call()
	_cell_scale = 1.0
	return m


func _lod(make: Callable, k := 4.0) -> Array[ArrayMesh]:
	return [make.call(), _coarse(make, k)]


func color(mat: int, p: Vector3, c: Vector3i, n: Vector3, occlusion: float, exposure: float) -> Color:
	var base: Color = COLORS.get(mat, Color.MAGENTA)
	var quiet := mat in [Mat.STONE, Mat.STONE_DARK, Mat.BASALT, Mat.WATER, Mat.FOAM]
	var col := VoxelDesign.default_color(base, mat, c, occlusion, exposure, quiet,
		mat in [Mat.STONE, Mat.WOOD, Mat.BARK_RIDGE, Mat.WOOD_NEW])
	if mat in [Mat.LEAF, Mat.LEAF_TOP, Mat.LEAF_DARK]:
		# Three greens by facing: sunlit tops, mid sides, deep undersides.
		col = col.lerp(COLORS[Mat.LEAF_TOP], clampf(maxf(n.y, 0.0) * 0.5 + exposure * 0.3, 0.0, 0.7))
		col = col.lerp(COLORS[Mat.LEAF_DARK] * 0.85, clampf(occlusion * 1.4 + maxf(-n.y, 0.0) * 0.6, 0.0, 0.9))
		col *= 0.94 + 0.12 * VoxelSdf.hash3(c, 71)
		col.a = 1.0
	elif mat in [Mat.MOSS, Mat.MOSS_LIGHT, Mat.FERN, Mat.FERN_DARK, Mat.BARK, Mat.ORCHID]:
		col *= 0.95 + 0.1 * VoxelSdf.hash3(c, 73)
		col.a = 1.0
	return col


func surface_of(mat: int) -> int:
	match mat:
		Mat.IRON:
			return VoxelProp.Surf.METAL
		Mat.WATER, Mat.FOAM:
			return VoxelProp.Surf.WATER
		Mat.LEAF, Mat.LEAF_TOP, Mat.LEAF_DARK, Mat.FERN, Mat.FERN_DARK, Mat.ORCHID, Mat.ORCHID_DARK, Mat.LILY, Mat.REED:
			return VoxelProp.Surf.PETAL
		Mat.BARK, Mat.BARK_DARK, Mat.BARK_RIDGE, Mat.ROOT:
			return VoxelProp.Surf.BARK
	return VoxelProp.Surf.MATTE


# ---------------------------------------------------------------- presets

## Sunrise mist (the hero): warm pale sky near the sun, soft blue above, a
## low warm sun from the east-south-east, warm pale fog (not mint).
func presets() -> Dictionary:
	var p := VoxelStage.PRESETS.duplicate(true)
	p.day.merge({
		"sky_top": Color("#8AB0D8"), "sky_horizon": Color("#E8E0C8"), "sky_below": Color("#cfd2c4"),
		"cloud": Color("#fffaf0"), "cloud_shadow": Color("#c8cabe"), "cloud_cover": 0.32,
		"sun_dir": Vector3(-0.74, -0.44, -0.5), "sun_color": Color("#fff0d8"), "sun_energy": 2.25, "sun_size": 0.03,
		"rim_color": Color("#fff2dc"), "rim_energy": 0.45,
		"ambient_color": Color("#a2b0a0"), "ambient_energy": 0.5,
		"fog_color": Color("#E4E4D8"), "fog_density": 0.0005, "exposure": 1.0,
	}, true)
	p.dusk.merge({
		"sky_top": Color("#5e6a9e"), "sky_horizon": Color("#f0b080"), "sun_dir": Vector3(-0.9, -0.2, -0.38),
		"sun_color": Color("#ffc890"), "sun_energy": 2.3, "rim_color": Color("#ffc090"), "rim_energy": 0.45,
		"ambient_color": Color("#9a8a8a"), "fog_color": Color("#e0c8b4"), "fog_density": 0.0006,
	}, true)
	p.night.merge({
		"sky_top": Color("#0c1628"), "sky_horizon": Color("#26384a"), "rim_color": Color("#b0c4ff"), "rim_energy": 0.55,
		"ambient_color": Color("#2a3e4a"), "fog_color": Color("#1e2c34"),
	}, true)
	return p


# ---------------------------------------------------------------- motion

## Falls and ripples run on the capture clock; the lake mirrors the current
## sky; height mist goes on the stage's environment once; canopies sway.
func animate(t: float) -> void:
	if not _env_done:
		_env_done = true
		for n in get_parent().get_children():
			if n is VoxelStage:
				var env := (n as VoxelStage).env
				env.fog_height = 9.0
				env.fog_height_density = 0.004
	var stage: VoxelStage = null
	for n in get_parent().get_children():
		if n is VoxelStage:
			stage = n
	if stage != null and not stage.current.is_empty():
		var cur := stage.current
		var lvl := clampf(float(cur.sun_energy) / 2.5, 0.25, 1.0)
		_water_mat.set_shader_parameter("sky_top", cur.sky_top)
		_water_mat.set_shader_parameter("sky_horizon", cur.sky_horizon)
		_water_mat.set_shader_parameter("light_level", lvl)
		for m in _falls_mats:
			m.set_shader_parameter("light_level", lerpf(0.55, 1.0, lvl))
		for m in _mist_mats:
			m.set_shader_parameter("mist_color", (cur.fog_color as Color).lightened(0.15))
			m.set_shader_parameter("light_level", lerpf(0.4, 1.0, lvl))
		for m in _shaft_mats:
			m.set_shader_parameter("strength", 0.07 * lvl * lvl)
			m.set_shader_parameter("light_color", cur.sun_color)
	_water_mat.set_shader_parameter("t", t)
	for m in _falls_mats:
		m.set_shader_parameter("t", t)


# ---------------------------------------------------------------- shots

func shots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var top := falls_quad[0].lerp(falls_quad[1], 0.5)
	# 1. The key image: the Great Falls across the mirror lake at sunrise, Kael on the south shore.
	var shore := _shore_point(centre.x - 4.0)
	out.append({"name": "falls_key", "from": Vector3(shore.x + 3.0, ground_at(shore.x, shore.y) + 3.0, shore.y + 9.0),
		"at": Vector3(top.x, 44.0, top.z), "fov": 55.0, "kael": [shore, PI], "times": ["day", "dusk"]})
	# 2. The overgrown shrine, Kael on its stair.
	var yaw := atan2(spawns[1].x - shrine_at.x, spawns[1].y - shrine_at.y)
	var front := shrine_at + Vector2(sin(yaw), cos(yaw)) * 2.4
	var cam := shrine_at + Vector2(sin(yaw + 0.3), cos(yaw + 0.3)) * 11.5
	out.append({"name": "shrine", "from": Vector3(cam.x, ground_at(cam.x, cam.y) + 3.4, cam.y),
		"at": Vector3(shrine_at.x, ground_at(shrine_at.x, shrine_at.y) + 1.6, shrine_at.y), "fov": 52.0,
		"kael": [front, yaw], "kael_y": _max_ground(shrine_at, 4.0) - 0.1 + 0.52, "times": ["day"]})
	# 3. The Giant Grove: buttress roots and the walkway overhead, Kael at the roots.
	if grove_pair.size() == 2:
		var a := tree_base(grove_pair[0])
		var b := tree_base(grove_pair[1])
		var mid := Vector2(a.x + b.x, a.z + b.z) * 0.5
		var across := Vector2(-(b.z - a.z), b.x - a.x).normalized()
		var to_a := (Vector2(a.x, a.z) - mid).normalized()
		var kp := Vector2(a.x, a.z) - to_a * (tree_radius(grove_pair[0]) + 1.5) + across * 3.0
		var cp := mid + across * 30.0 - to_a * 4.0
		out.append({"name": "grove", "from": Vector3(cp.x, ground_at(cp.x, cp.y) + 2.0, cp.y),
			"at": Vector3(mid.x + to_a.x * 6.0, ground_at(mid.x, mid.y) + 14.0, mid.y + to_a.y * 6.0), "fov": 62.0,
			"kael": [kp, atan2(across.x, across.y)], "times": ["day"]})
	# 4. Gameplay camera on Kael on the moss floor near a spawn.
	var k := spawns[0] + Vector2(6.0, -10.0)
	var ky := ground_at(k.x, k.y) + 1.0
	out.append({"name": "kael_scale", "from": Vector3(k.x + 3.0, ky + 1.5, k.y + 5.0), "at": Vector3(k.x - 1.0, ky + 0.6, k.y - 4.0),
		"fov": 55.0, "kael": [k, PI * 0.9], "times": ["day"]})
	# 5. The fallen giant and god-rays on the valley floor.
	out.append({"name": "fallen_giant", "from": Vector3(fallen_at.x - 22.0, ground_at(fallen_at.x - 22.0, fallen_at.y + 18.0) + 4.0, fallen_at.y + 18.0),
		"at": Vector3(fallen_at.x, ground_at(fallen_at.x, fallen_at.y) + 3.5, fallen_at.y), "fov": 55.0, "times": ["day"]})
	# 6. A wide overview from above the south canopy.
	out.append({"name": "overview", "from": Vector3(centre.x + 150.0, 150.0, centre.y + 280.0), "at": Vector3(top.x, 50.0, top.z + 60.0),
		"fov": 55.0, "times": ["day"]})
	return out


## The south shore point at world x (the first floor above the waterline
## walking south from the lake centre).
func _shore_point(x: float) -> Vector2:
	for k in 300:
		var z := centre.y + 60.0 + k * 0.5
		var dry := true
		for j in 25:
			if ground_at(x, z + j) < 0.5:
				dry = false
				break
		if dry:
			return Vector2(x, z + 1.5)
	return Vector2(x, centre.y + 100.0)


## 20 s: low over the mirror lake toward the falls, up the curtain to the lip,
## a turn over the plateau river, a dive back down through the spray, then a
## jungle run under the canopy past the walkway, the shrine and the spawns.
func flight() -> Array[Dictionary]:
	var top := falls_quad[0].lerp(falls_quad[1], 0.5)
	var foot := falls_quad[2].lerp(falls_quad[3], 0.5)
	var shore := _shore_point(centre.x)
	var walk: Vector3 = stats.get("walkway", {}).get("mid", Vector3(centre.x + 100, 30, centre.y + 180))
	var sh := Vector3(shrine_at.x, ground_at(shrine_at.x, shrine_at.y), shrine_at.y)
	return [
		{"from": Vector3(shore.x + 10, 6.0, shore.y + 20), "at": Vector3(top.x, 40.0, top.z), "fov": 58.0},
		{"from": Vector3(centre.x - 5, 5.0, centre.y + 20), "at": Vector3(top.x, 50.0, top.z), "fov": 58.0},
		{"from": Vector3(foot.x + 15, 14.0, foot.z + 90), "at": Vector3(top.x, 70.0, top.z), "fov": 60.0},
		{"from": Vector3(foot.x + 30, 60.0, foot.z + 60), "at": Vector3(top.x, 105.0, top.z), "fov": 60.0},
		{"from": Vector3(top.x + 25, 132.0, top.z + 30), "at": Vector3(top.x, 118.0, top.z - 60), "fov": 60.0},
		{"from": Vector3(top.x - 20, 140.0, top.z - 40), "at": Vector3(top.x + 20, 80.0, top.z + 80), "fov": 60.0},
		{"from": Vector3(foot.x - 10, 40.0, foot.z + 40), "at": Vector3(centre.x + 40, 15.0, centre.y + 140), "fov": 60.0},
		{"from": Vector3(centre.x + 30, 12.0, centre.y + 95), "at": walk, "fov": 62.0},
		{"from": walk + Vector3(-20, -8, -25), "at": walk + Vector3(10, -4, 20), "fov": 62.0},
		{"from": walk + Vector3(15, -12, 20), "at": sh + Vector3(0, 2, 0), "fov": 60.0},
		{"from": sh + Vector3(14, 6, 14), "at": Vector3(spawns[1].x, 4.0, spawns[1].y), "fov": 58.0},
		{"from": Vector3(spawns[1].x + 25, 18.0, spawns[1].y + 30), "at": Vector3(top.x, 60.0, top.z), "fov": 58.0},
	]


func flight_kael() -> Array:
	return [_shore_point(centre.x - 4.0), PI]
