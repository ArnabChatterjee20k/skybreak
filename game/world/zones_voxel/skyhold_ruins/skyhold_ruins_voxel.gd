class_name SkyholdRuinsVoxel
extends VoxelZone
## Skyhold Ruins in the voxel style (docs/lookdev/skyhold_ruins.md), look v1,
## on the voxel zone kit (game/world/voxel_zone_kit/README.md). The sim stays
## the truth: islands, columns and arches come from SkyholdRuinsProps (seed
## 4242) through SkyholdRuinsLayout, the Fang Rocks from the baked heightmap,
## the cloud sea sits at the world's 40 m plane. A visual pass only.
##
## Tiers: paved tops as flat T2 fields with the flagstones drawn per T1 cell
## (the top lies exactly on the island top + CAP), T1 props, T2 undersides,
## the Watch stump and the fangs, T3 clouds.

const PAVING_SHADER := preload("res://game/world/zones_voxel/skyhold_ruins/skyhold_paving.gdshader")
const TERRAIN_SHADER := preload("res://game/world/voxel_zone_kit/voxel_terrain.gdshader")
## The paving's height above the sim's island top: the grey-block cap's top.
const CAP := 0.6
## The paved shell's depth under the paving (m).
const SHELL := 1.4
const CLOUD_Y := 40.0
## LOD ranges (m) where each tier ends.
const COLUMN_RANGES := [35.0, 120.0, 0.0]
const PROP_RANGES := [50.0, 160.0, 0.0]
const SMALL_RANGES := [40.0]
## Where islands switch to their 2 x T2 far tier below HIGH (scaled per tier).
const ISLAND_FAR := 375.0

var layout: SkyholdRuinsLayout
var designs := SkyholdRuinsDesigns.new()
var crown: SkyholdRuinsLayout.Island
var watch: SkyholdRuinsLayout.Island
## Per island: [Vector2 normal, float distance] chords cutting the outline.
var _chords: Array = []
## Placements per design key: Array[Transform3D].
var _lists := {}
## Story spots, for the shots.
var spots := {}
var _birds: MultiMeshInstance3D
var _bird_paths: Array = []
var _flame_light: OmniLight3D
var _chain_ends: Array = []


## Each island's box (zone space) shared by its near and far tier chunks.
var _island_boxes := {}
## Crown and Watch Island as plain values: a bake can't keep the layout's inner
## Island objects, and flight() needs these two after a load (restored()).
var _kept_islands := {}


func _init() -> void:
	name = "SkyholdRuins"


func build() -> void:
	var t := Time.get_ticks_msec()
	layout = SkyholdRuinsLayout.read()
	crown = layout.named("Crown Island")
	watch = layout.named("Watch Island")
	_kept_islands = {"crown": _island_values(crown), "watch": _island_values(watch)}
	for isl in layout.islands:
		_chords.append(_outline(isl))
	lantern_materials.append(VoxelProp.materials()[VoxelProp.Surf.GLOW] as ShaderMaterial)
	var steps: Array[Callable] = [_islands, _fangs, _columns, _arches, _watch_stump, _story, _furnish, _chains,
		_rims, _scatter, _clouds, _birds_build, _place_all]
	for step in steps:
		var s := Time.get_ticks_msec()
		step.call()
		stats["ms_" + step.get_method().trim_prefix("_")] = Time.get_ticks_msec() - s
	stats["islands"] = layout.islands.size()
	stats["ms_total"] = Time.get_ticks_msec() - t


func restored() -> void:
	if crown == null and _kept_islands.has("crown"):
		crown = _island_from(_kept_islands.crown)
		watch = _island_from(_kept_islands.watch)


static func _island_values(isl: SkyholdRuinsLayout.Island) -> Dictionary:
	return {"centre": isl.centre, "top": isl.top, "radius": isl.radius, "depth": isl.depth, "yaw": isl.yaw,
		"name": isl.name, "arch": isl.arch}


static func _island_from(v: Dictionary) -> SkyholdRuinsLayout.Island:
	var isl := SkyholdRuinsLayout.Island.new()
	for k: String in v:
		isl.set(k, v[k])
	return isl


func presets() -> Dictionary:
	var p := VoxelStage.PRESETS.duplicate(true)
	var z := layout.zone if layout != null else load("res://game/world/zones/skyhold_ruins.tres") as ZoneData
	# Golden hour, sun still up: deep blue zenith, pale warm horizon, a lighter
	# cooler haze than the stone, rim 0.35 (sheet's preset notes).
	p.day = {
		"sky_top": Color("#2448a0"), "sky_horizon": Color("#d2dae6"), "sky_below": Color("#F4EEE4"),
		"cloud": Color("#fffaf0"), "cloud_shadow": Color("#b8b4c4"), "cloud_cover": 0.3,
		"sun_dir": z.sun_directions[0], "sun_color": Color("#ffd9a0"), "sun_energy": 2.7,
		"sun_size": 0.035, "moon": false, "stars": 0.0,
		"rim_color": Color("#fff0d0"), "rim_energy": 0.35,
		"ambient_color": Color("#a8a4a8"), "ambient_energy": 0.5,
		"fog_color": Color("#d8dde4"), "fog_density": 0.0005, "exposure": 0.92, "lantern": 0.3,
	}
	p.dusk = {
		"sky_top": Color("#4a5a96"), "sky_horizon": Color("#f2a868"), "sky_below": Color("#f2d2b4"),
		"cloud": Color("#ffe2c4"), "cloud_shadow": Color("#b49aa0"), "cloud_cover": 0.35,
		"sun_dir": z.sun_directions[1], "sun_color": Color("#ffb070"), "sun_energy": 2.3,
		"sun_size": 0.045, "moon": false, "stars": 0.0,
		"rim_color": Color("#ffc090"), "rim_energy": 0.4,
		"ambient_color": Color("#a6888a"), "ambient_energy": 0.5,
		"fog_color": Color("#e8d0bc"), "fog_density": 0.0006, "exposure": 1.0, "lantern": 0.7,
	}
	p.night = {
		"sky_top": Color("#0a1030"), "sky_horizon": Color("#2a3458"), "sky_below": Color("#3a4468"),
		"cloud": Color("#6a76a0"), "cloud_shadow": Color("#2a3050"), "cloud_cover": 0.25,
		"sun_dir": z.sun_directions[2], "sun_color": Color("#b8c8ff"), "sun_energy": 0.55,
		"sun_size": 0.0, "moon": true, "stars": 0.9,
		"rim_color": Color("#a6c0ff"), "rim_energy": 0.6,
		"ambient_color": Color("#30395e"), "ambient_energy": 0.6,
		"fog_color": Color("#283050"), "fog_density": 0.0006, "exposure": 1.0, "lantern": 1.2,
	}
	return p


func cloud_sea() -> Dictionary:
	return {"rect": Rect2(-330, -1080, 740, 960), "height": CLOUD_Y, "puffs": 150, "seed": 4242}


## The paving height of the highest island whose outline holds (x, z).
func ground_at(x: float, z: float) -> float:
	var best := -INF
	for i in layout.islands.size():
		var isl := layout.islands[i]
		if _gauge(i, Vector2(x, z)) <= 1.0:
			best = maxf(best, isl.top + CAP)
	return best


# ---------------------------------------------------------------- outline

## 5-8 chords cut each island's circle into a fractured polygon; columns at
## 0.72 r stay inside.
func _outline(isl: SkyholdRuinsLayout.Island) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(isl.centre.x), roundi(isl.centre.y)))
	var n := 5 + rng.randi() % 4
	var out := []
	var lo := maxf(0.8, (isl.radius * 0.72 + 2.4) / isl.radius)
	for k in n:
		var a := isl.yaw + TAU * (k + rng.randf_range(-0.3, 0.3)) / n
		out.append([Vector2(cos(a), sin(a)), isl.radius * rng.randf_range(lo, 0.97)])
	return out


## 1 on island i's outline, < 1 inside.
func _gauge(i: int, p: Vector2) -> float:
	var isl := layout.islands[i]
	var q := p - isl.centre
	var g := q.length() / isl.radius
	for ch: Array in _chords[i]:
		g = maxf(g, q.dot(ch[0]) / float(ch[1]))
	return g


func _local(isl: SkyholdRuinsLayout.Island, lx: float, lz: float) -> Vector2:
	var xa := Vector2(cos(isl.yaw), -sin(isl.yaw))
	var za := Vector2(sin(isl.yaw), cos(isl.yaw))
	return isl.centre + xa * lx + za * lz


func _floor(isl: SkyholdRuinsLayout.Island) -> float:
	return isl.top + CAP


# ---------------------------------------------------------------- islands

func _islands() -> void:
	var quads := 0
	var far_quads := 0
	for i in layout.islands.size():
		var top := _island_top(i)
		quads += VoxelHeightfield.count_quads(top)
		var under := _island_underside(i)
		quads += VoxelHeightfield.count_quads(under)
		if VoxelQuality.tier == GraphicsSettings.Quality.HIGH:
			continue
		# Below HIGH, a far tier at 2 x T2 past ISLAND_FAR; the whole island
		# switches at once (one box for every chunk of both tiers: no seams).
		var box := AABB()
		var nodes: Array = top.get_children() + under.get_children()
		for k in nodes.size():
			var mi := nodes[k] as MeshInstance3D
			var b := (mi.get_parent() as Node3D).transform * mi.mesh.get_aabb()
			box = b if k == 0 else box.merge(b)
		_island_boxes[i] = box
		var far_top := _island_top(i, T2 * 2.0)
		var far_under := _island_underside(i, T2 * 2.0)
		far_quads += VoxelHeightfield.count_quads(far_top) + VoxelHeightfield.count_quads(far_under)
		_link_far(i, [top, under], [far_top, far_under])
	stats["terrain_quads"] = quads
	stats["terrain_far_quads"] = far_quads


## Ties an island's near and far tier nodes to one box and one switch distance.
func _link_far(i: int, near: Array, far: Array) -> void:
	var box: AABB = _island_boxes[i]
	var switch := VoxelQuality.far(ISLAND_FAR)
	for tier in 2:
		for root: Node3D in (near if tier == 0 else far):
			for mi: MeshInstance3D in root.get_children():
				mi.custom_aabb = root.transform.affine_inverse() * box
				if tier == 0:
					mi.visibility_range_end = switch
				else:
					mi.visibility_range_begin = switch


func _bounds(i: int) -> Rect2:
	var isl := layout.islands[i]
	var r := isl.radius * 1.04
	return Rect2(isl.centre - Vector2(r, r), Vector2(r, r) * 2.0)


## The paved shell: a flat T2 field, offset so its top lies exactly on the
## paving height; the rim breaks along 1 m blocks (lost flags).
func _island_top(i: int, cell := T2) -> Node3D:
	var isl := layout.islands[i]
	var b := _bounds(i)
	var hf := VoxelHeightfield.new(cell, b.position, b.end)
	var y := _floor(isl)
	var level := roundi(y / cell)
	var lime := Color("#cdbfa2")
	var deco := _deco_for(i)
	for z in hf.size.y:
		for x in hf.size.x:
			var w := hf.centre(x, z)
			var g := _gauge(i, w)
			if g > 1.0:
				continue
			var blk := Vector3i(floori(w.x / 0.9), 0, floori(w.y / 0.9))
			if g > 0.965 and VoxelSdf.hash3(blk, 3) < 0.55:
				continue
			# Moss creeps in from the rim and in patches; a warm-cool drift of tone.
			var patch := sin(w.x * 0.21 + w.y * 0.13) * sin(w.x * 0.07 - w.y * 0.19 + 1.7)
			var moss := clampf((g - 0.78) * 2.5, 0.0, 1.0) * 0.8 + clampf(patch - 0.4, 0.0, 1.0)
			var c := lime * (0.96 + 0.08 * VoxelSdf.hash3(Vector3i(x, 0, z), 7))
			c = c.lerp(Color("#d2bc98"), clampf(0.5 + 0.5 * sin(w.x * 0.05 + w.y * 0.03), 0.0, 1.0) * 0.35)
			if moss > 0.85 and VoxelSdf.hash3(Vector3i(x, 1, z), 9) < (moss - 0.85) * 2.5:
				c = Color("#8a9462")
			c = _decorate(deco, w, c)
			c.a = clampf(moss, 0.0, 1.0)
			hf.set_column(x, z, level, level - roundi(SHELL / cell), c)
	hf.bake_step_ao(0.25, 2)
	var mat := ShaderMaterial.new()
	mat.shader = PAVING_SHADER
	hf.bind(mat)
	mat.set_shader_parameter("paving", true)
	mat.set_shader_parameter("isle_centre", isl.centre)
	mat.set_shader_parameter("isle_yaw", isl.yaw)
	mat.set_shader_parameter("isle_radius", isl.radius)
	mat.set_shader_parameter("rock_color", Color("#b8a27e"))
	mat.set_shader_parameter("rock_shadow", Color("#8a7458"))
	mat.set_shader_parameter("soil_color", Color("#7a6650"))
	mat.set_shader_parameter("joint_color", Color("#a08c70"))
	mat.set_shader_parameter("joint_moss", Color("#8a9264"))
	mat.set_shader_parameter("marble_color", Color("#E6DCC8"))
	mat.set_shader_parameter("strata_cells", 2.0)
	mat.set_shader_parameter("crack_amount", 0.3)
	var node := hf.build(self, mat, "Isle%dTop%s" % [i, "Far" if cell > T2 else ""], 0.0, true)
	node.position.y = y - level * cell
	return node


## Story decals painted into the paving colour (T2): the sundial ring, the
## patina streak fans under bronze, shade under the arch.
func _deco_for(i: int) -> Array:
	var out := []
	var isl := layout.islands[i]
	if spots.has("sundial_island") and spots.sundial_island == i:
		out.append(["dial", spots.sundial_at])
	if isl.arch:
		out.append(["shade", isl.centre, isl.yaw])
	return out


func _decorate(deco: Array, w: Vector2, c: Color) -> Color:
	for d: Array in deco:
		match d[0]:
			"dial":
				var r := w.distance_to(d[1])
				if r < 6.2:
					var a := fposmod(atan2(w.y - d[1].y, w.x - d[1].x) / TAU * 12.0, 1.0)
					if r > 5.4:
						return Color("#e6dcc8")
					if r > 4.6 and a < 0.18:
						return Color("#5a4a34")
					if r < 4.6 and r > 1.4:
						return c.lerp(Color("#e6dcc8"), 0.5)
			"shade":
				var q: Vector2 = w - d[1]
				var lx := q.dot(Vector2(cos(d[2]), -sin(d[2])))
				var lz := q.dot(Vector2(sin(d[2]), cos(d[2])))
				if absf(lx) < 9.5 and absf(lz) < 3.4:
					return c.darkened(0.12)
	return c


## The underside: stacked strata slabs stepping inward to the sim's depth,
## an inverted fractured cone (T2), each slab's outline wobbling on its own.
func _island_underside(i: int, cell := T2) -> Node3D:
	var isl := layout.islands[i]
	var b := _bounds(i)
	var hf := VoxelHeightfield.new(cell, b.position, b.end, true)
	var slab := maxi(1, roundi(7.0 * T2 / cell))  # 2.45 m slabs
	var top_level := roundi((_floor(isl) - SHELL) / cell) + 1
	for z in hf.size.y:
		for x in hf.size.x:
			var w := hf.centre(x, z)
			var g := _gauge(i, w)
			if g > 0.985:
				continue
			var a := atan2(w.y - isl.centre.y, w.x - isl.centre.x)
			# The grey-block body: radius r at the top to 0.14 r at the depth.
			var reach := clampf((1.0 - g) / 0.86, 0.0, 1.0)
			var raw := -isl.depth * pow(reach, 0.8) / cell
			var band := floori(raw / slab)
			var wob := sin(a * (3.0 + absi(band) % 3) + band * 1.7) * 0.5 + sin(a * 7.0 - band * 2.3) * 0.3
			wob += (VoxelSdf.hash3(Vector3i(floori(a * 9.0), band, i), 5) - 0.5) * 0.8
			var bottom := floori((raw + wob * slab * 1.4) / slab) * slab + top_level
			# Hanging rocks: a few deeper drips under the slabs.
			if VoxelSdf.hash3(Vector3i(x / 6, 0, z / 6), i) < 0.05 and reach > 0.15:
				bottom -= slab * 2
			if bottom >= top_level:
				continue
			hf.set_column(x, z, bottom, top_level, Color.WHITE)
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	hf.bind(mat)
	mat.set_shader_parameter("under_top", _floor(isl))
	mat.set_shader_parameter("under_depth", isl.depth + 8.0)
	mat.set_shader_parameter("under_color", Color("#5e5249"))
	mat.set_shader_parameter("under_alt", Color("#4c423b"))
	mat.set_shader_parameter("under_deep", Color("#2c2622"))
	mat.set_shader_parameter("strata_cells", float(slab))
	mat.set_shader_parameter("crack_amount", 0.12)
	mat.set_shader_parameter("noise_amount", 0.03)
	return hf.build(self, mat, "Isle%dUnder%s" % [i, "Far" if cell > T2 else ""], 0.0, true)


# ---------------------------------------------------------------- fangs

## The Fang Rocks above the cloud sea from the baked heightmap: T2 columns in
## stepped 1.4 m strata with a jagged crown, cool dark grey.
func _fangs() -> void:
	var quads := 0
	var c := layout.zone.centre
	for f in TerrainShape.SKY_FANGS.size():
		var spec: Array = TerrainShape.SKY_FANGS[f]
		var at: Vector2 = c + (spec[0] as Vector2)
		var r: float = spec[1] * 2.2
		var hf := VoxelHeightfield.new(T2, at - Vector2(r, r), at + Vector2(r, r))
		var slab := 4
		for z in hf.size.y:
			for x in hf.size.x:
				var w := hf.centre(x, z)
				var h := layout.heightmap.ground_height_at(w.x, w.y)
				if h < CLOUD_Y - 6.0:
					continue
				var a := atan2(w.y - at.y, w.x - at.x)
				# Crags: lobes and notches round the spire, a split crown.
				var lobe := 0.5 + 0.5 * sin(a * 3.0 + f * 1.9) * cos(a * 2.0 - f)
				var notch := VoxelSdf.hash3(Vector3i(floori(a * 7.0 + 7.0), f, 0), 91)
				var lift := clampf((h - CLOUD_Y) / 80.0, 0.0, 1.0)
				# Notches cut at most one slab (1.4 m) into the sim's rock.
				h -= 1.4 * notch * lift * lobe
				var raw := h / T2
				var band := floori(raw / slab)
				var wob := sin(a * 5.0 + band * 1.3 + f) * 0.6 + (VoxelSdf.hash3(Vector3i(x / 3, band, z / 3), 77 + f) - 0.5) * 1.4
				var lv := floori((raw + wob * slab) / slab) * slab
				var tone := 0.9 + 0.2 * VoxelSdf.hash3(Vector3i(x / 4, band, z / 4), 81)
				var col := Color("#4E5058") * tone
				if VoxelSdf.hash3(Vector3i(x, 0, z), 83) < 0.08:
					col = Color("#5e6a52")  # lichen on the ledges
				hf.set_column(x, z, lv, roundi((CLOUD_Y - 10.0) / T2), col)
		hf.bake_step_ao(0.35, 2)
		var mat := ShaderMaterial.new()
		mat.shader = TERRAIN_SHADER
		hf.bind(mat)
		mat.set_shader_parameter("rock_color", Color("#565860"))
		mat.set_shader_parameter("rock_shadow", Color("#33353c"))
		mat.set_shader_parameter("soil_color", Color("#3a3c44"))
		mat.set_shader_parameter("strata_cells", 4.0)
		mat.set_shader_parameter("crack_amount", 0.5)
		var node := hf.build(self, mat, "Fang%d" % f)
		quads += VoxelHeightfield.count_quads(node)
		spots["fang%d" % f] = Vector3(at.x, layout.heightmap.ground_height_at(at.x, at.y), at.y)
	stats["fang_quads"] = quads


# ---------------------------------------------------------------- columns and arches

func _add(key: String, xf: Transform3D) -> void:
	if not _lists.has(key):
		_lists[key] = [] as Array[Transform3D]
	(_lists[key] as Array[Transform3D]).append(xf)


func _xf(at: Vector3, yaw: float, s := 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)


## The sim's columns: whole ones stand 16 m on the base; broken ones snap to
## the nearest broken design. Nests on three broken capitals.
func _columns() -> void:
	var nests := 0
	for isl in layout.islands:
		for col: Dictionary in isl.columns:
			var at: Vector3 = col.at
			var base := Vector3(at.x, _floor(isl), at.z)
			var h: float = col.height
			var v := 0
			if h < 15.0:
				var best := 99.0
				for k in SkyholdRuinsDesigns.COLUMN_BROKEN.size():
					var d := absf(SkyholdRuinsDesigns.COLUMN_BROKEN[k] - 0.4 - h)
					if d < best:
						best = d
						v = k + 1
			_add("column%d" % v, _xf(base, col.angle))
			if v > 0 and nests < 4 and VoxelSdf.hash3(Vector3i(roundi(at.x), 0, roundi(at.z)), 5) < 0.3:
				nests += 1
				var top := SkyholdRuinsDesigns.COLUMN_BROKEN[v - 1] - 0.62
				_add("nest", _xf(base + Vector3(0, top, 0), col.angle))
				spots["nest%d" % nests] = base + Vector3(0, top, 0)
				var rng := RandomNumberGenerator.new()
				rng.seed = nests
				for k in 6:
					var o := Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-3.0, 3.0))
					if o.length() < 1.7:
						o = o.normalized() * 2.0
					_add("feather", _xf(base + o + Vector3(0, 0.005, 0), rng.randf() * TAU))
	stats["columns"] = 0
	for v in 5:
		stats["columns"] += (_lists.get("column%d" % v, []) as Array).size()


## The sim's arches (every island over r 26): voussoir arches standing on the
## paving at the island centre and yaw; two variants (whole, ruined); the
## Crown Island arch is the Crown Gate.
func _arches() -> void:
	for isl in layout.islands:
		if not isl.arch:
			continue
		var base := Vector3(isl.centre.x, _floor(isl), isl.centre.y)
		if isl == crown:
			_add("pier_grand", _xf(base, isl.yaw))
			_add("pier_grand", _xf(base, isl.yaw + PI))
			_add("gate_top", _xf(base, isl.yaw))
			continue
		_add("pier", _xf(base, isl.yaw))
		_add("pier", _xf(base, isl.yaw + PI))
		var ruined := VoxelSdf.hash3(Vector3i(roundi(base.x), 0, roundi(base.z)), 7) < 0.5
		_add("arch_top_ruined" if ruined else "arch_top", _xf(base, isl.yaw + (PI if ruined and base.x > 0.0 else 0.0)))
		if ruined:
			var side := -1.0 if base.x > 0.0 else 1.0
			var spot := _local(isl, side * 10.5, 4.5)
			_add("rubble2", _xf(Vector3(spot.x, base.y, spot.y), isl.yaw))


func _watch_stump() -> void:
	var at := _local(watch, 0.0, 21.0)
	_add("watch_stump", _xf(Vector3(at.x, _floor(watch), at.y), watch.yaw))
	spots["stump"] = Vector3(at.x, _floor(watch), at.y)


# ---------------------------------------------------------------- story

func _story() -> void:
	var cy := _floor(crown)
	# The Crown Gate's keepers: two robed statues flanking the gate, braziers
	# (cold), an altar in front.
	for s: float in [-1.0, 1.0]:
		var at := _local(crown, s * 13.5, 4.0)
		_add("robed", _xf(Vector3(at.x, cy, at.y), crown.yaw))
		var bz := _local(crown, s * 6.5, 7.5)
		_add("brazier_cold", _xf(Vector3(bz.x, cy, bz.y), crown.yaw))
	var alt := _local(crown, 0.0, 11.0)
	_add("altar", _xf(Vector3(alt.x, cy, alt.y), crown.yaw))
	spots["gate"] = Vector3(crown.centre.x, cy, crown.centre.y)
	# Stairs to nowhere: a grand flight running out over the rim on Crown
	# Island, between two columns, top steps hanging over the cloud sea.
	var ci := layout.islands.find(crown)
	var best_a := 0.0
	var best_g := 0.0
	for k in 72:
		var a := TAU * k / 72.0
		var dir := Vector2(cos(a), sin(a))
		var ok := true
		for col: Dictionary in crown.columns:
			var cp := Vector2(col.at.x, col.at.z) - crown.centre
			if absf(wrapf(atan2(cp.y, cp.x) - a, -PI, PI)) < 0.11:
				ok = false
		# Prefer a chord edge (straight rim) toward the camera side (+x, +z).
		var edge := 0.0
		for d in range(30, 70):
			if _gauge(ci, crown.centre + dir * d) > 1.0:
				edge = d
				break
		var score := (1.0 if ok else 0.0) + (0.4 if edge < 50.0 else 0.0) + 0.2 * dir.dot(Vector2(-0.7, 0.7))
		if score > best_g:
			best_g = score
			best_a = a
	var dir := Vector2(cos(best_a), sin(best_a))
	var rim_d := 30.0
	while _gauge(ci, crown.centre + dir * rim_d) <= 1.0 and rim_d < 70.0:
		rim_d += 0.25
	# The flight rises along +z (local): its foot 4.2 m inside the rim.
	var foot := crown.centre + dir * (rim_d - 4.6)
	var yaw := atan2(dir.x, dir.y)
	_add("stairs", _xf(Vector3(foot.x, cy, foot.y), yaw))
	spots["stairs"] = Vector3(foot.x, cy, foot.y)
	spots["stairs_dir"] = dir
	# The fallen statue on Watch Island: face-down across the plaza, its
	# raised arm snapped off and lying at the rim.
	var wy := _floor(watch)
	var wi := layout.islands.find(watch)
	var fall := _local(watch, -14.0, -12.0)
	var fall_yaw := watch.yaw + 0.6
	var lying := Basis(Vector3.UP, fall_yaw) * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, PI * 0.5)
	# Lying on its face: the figure's front (+z) down, its back 0.5 m up.
	_add("robed_fallen", Transform3D(lying, Vector3(fall.x, wy + 0.6, fall.y)))
	var reach := Vector2(sin(fall_yaw), cos(fall_yaw))
	var arm_d := 4.0
	while _gauge(wi, fall + reach * arm_d) < 0.95 and arm_d < 60.0:
		arm_d += 0.5
	var arm := fall + reach * arm_d
	_add("statue_arm", _xf(Vector3(arm.x, wy, arm.y), fall_yaw + 0.4))
	_add("rubble0", _xf(Vector3(fall.x - reach.y * 2.5, wy, fall.y + reach.x * 2.5), 0.3))
	spots["fallen"] = Vector3(fall.x, wy, fall.y)
	spots["fallen_yaw"] = fall_yaw
	spots["arm"] = Vector3(arm.x, wy, arm.y)
	var plinth := _local(watch, -18.5, -16.5)
	_add("altar", _xf(Vector3(plinth.x, wy, plinth.y), watch.yaw + 0.6))
	_add("winged_lion", _xf(Vector3(_local(watch, 13.0, 6.0).x, wy, _local(watch, 13.0, 6.0).y), watch.yaw + PI * 0.5))
	# The one lit brazier, on the small island nearest the spawns.
	var spawn := Vector2(40, -560)
	var lit: SkyholdRuinsLayout.Island = null
	for isl in layout.islands:
		if isl.radius < 20.0 and (lit == null or isl.centre.distance_to(spawn) < lit.centre.distance_to(spawn)):
			lit = isl
	var lp := _local(lit, 2.5, 3.0)
	var ly := _floor(lit)
	_add("brazier_lit", _xf(Vector3(lp.x, ly, lp.y), 0.0))
	_add("altar", _xf(Vector3(_local(lit, -1.5, 3.0).x, ly, _local(lit, -1.5, 3.0).y), lit.yaw))
	spots["brazier"] = Vector3(lp.x, ly, lp.y)
	_flame_light = OmniLight3D.new()
	_flame_light.name = "BrazierLight"
	_flame_light.light_color = Color("#ffb060")
	_flame_light.omni_range = 9.0
	_flame_light.light_energy = 1.2
	_flame_light.shadow_enabled = false
	_flame_light.position = Vector3(lp.x, ly + 2.2, lp.y)
	add_child(_flame_light)
	# The sundial plaza: on the arched island nearest the Crown, its gnomon
	# pointing at the Crown Gate.
	var dial: SkyholdRuinsLayout.Island = null
	for isl in layout.islands:
		if isl != crown and isl != watch and isl.arch and (dial == null
				or isl.centre.distance_to(crown.centre) < dial.centre.distance_to(crown.centre)):
			dial = isl
	var dp := _local(dial, 0.0, -dial.radius * 0.42)
	spots["sundial_island"] = layout.islands.find(dial)
	spots["sundial_at"] = dp
	var to_gate := crown.centre - dp
	_add("gnomon", _xf(Vector3(dp.x, _floor(dial), dp.y), atan2(-to_gate.y, to_gate.x)))
	spots["sundial"] = Vector3(dp.x, _floor(dial), dp.y)
	# The dial island's paving is rebuilt with the dial (it was built first).
	var di := layout.islands.find(dial)
	var old := get_node_or_null("Isle%dTop" % di)
	if old != null:
		old.free()
		var top := _island_top(di)
		var old_far := get_node_or_null("Isle%dTopFar" % di)
		if old_far != null:
			old_far.free()
			_link_far(di, [top], [_island_top(di, T2 * 2.0)])


## Furniture on the other islands: altars before arches, a winged lion on a
## few, collapsed walls, fallen columns, rubble at column feet.
func _furnish() -> void:
	var n := 0
	for isl in layout.islands:
		n += 1
		if isl == crown or isl == watch:
			continue
		var y := _floor(isl)
		var h := VoxelSdf.hash3(Vector3i(roundi(isl.centre.x), 1, roundi(isl.centre.y)), 3)
		if isl.arch:
			var a := _local(isl, 0.0, 7.5 if h < 0.5 else -7.5)
			_add("altar", _xf(Vector3(a.x, y, a.y), isl.yaw + (0.0 if h < 0.5 else PI)))
			if h > 0.6:
				var l := _local(isl, 0.0, -isl.radius * 0.45)
				_add("winged_lion", _xf(Vector3(l.x, y, l.y), isl.yaw + PI * 0.5))
		if isl.radius > 18.0:
			var wa := h * TAU
			var wp := isl.centre + Vector2(cos(wa), sin(wa)) * isl.radius * 0.52
			_add("wall%d" % (n % 2), _xf(Vector3(wp.x, y, wp.y), -wa + PI * 0.5))
			_add("rubble%d" % (n % 4), _xf(Vector3(wp.x + cos(wa) * 2.5, y, wp.y + sin(wa) * 2.5), wa))
		if isl.radius > 30.0 and h < 0.45:
			var fa := h * TAU + 2.0
			var fp := isl.centre + Vector2(cos(fa), sin(fa)) * isl.radius * 0.35
			_add("fallen_column", _xf(Vector3(fp.x, y, fp.y), -fa))
		for col: Dictionary in isl.columns:
			var at: Vector3 = col.at
			if VoxelSdf.hash3(Vector3i(roundi(at.x), 2, roundi(at.z)), 11) < 0.3:
				var o := Vector2(at.x, at.z) - isl.centre
				var p := Vector2(at.x, at.z) - o.normalized() * 2.6
				_add("rubble%d" % ((roundi(at.x) % 4 + 4) % 4), _xf(Vector3(p.x, y, p.y), at.z))
	# Crown and Watch: a fallen column on each plaza.
	var fc := _local(crown, -14.0, -16.0)
	_add("fallen_column", _xf(Vector3(fc.x, _floor(crown), fc.y), crown.yaw + 0.5))
	var wc := _local(watch, 16.0, -14.0)
	_add("fallen_column", _xf(Vector3(wc.x, _floor(watch), wc.y), watch.yaw - 0.8))


# ---------------------------------------------------------------- chains

## Hanging chains between two columns on adjacent islands, snapped in the
## middle: each half sags from its column top and dangles over the gap.
func _chains() -> void:
	var best := []
	var best_gap := 1.0e9
	for a in layout.islands:
		for b in layout.islands:
			if a == b or a.centre.x > b.centre.x:
				continue
			for ca: Dictionary in a.columns:
				if ca.height < 15.0:
					continue
				for cb: Dictionary in b.columns:
					if cb.height < 15.0:
						continue
					var pa := Vector3(ca.at.x, _floor(a) + SkyholdRuinsDesigns.COLUMN_WHOLE - 0.7, ca.at.z)
					var pb := Vector3(cb.at.x, _floor(b) + SkyholdRuinsDesigns.COLUMN_WHOLE - 0.7, cb.at.z)
					var d := pa.distance_to(pb)
					if d > 14.0 and d < best_gap and absf(pa.y - pb.y) < 12.0:
						best_gap = d
						best = [pa, pb]
	if best.is_empty():
		return
	var pa: Vector3 = best[0]
	var pb: Vector3 = best[1]
	spots["chain_a"] = pa
	spots["chain_b"] = pb
	for half in 2:
		var from := pa if half == 0 else pb
		var to := pb if half == 0 else pa
		var flat := Vector3(to.x - from.x, 0, to.z - from.z)
		var reach := flat.length() * 0.42
		var dir := flat.normalized()
		var pts: Array[Vector3] = []
		# Sag along a parabola to the break, then hang straight down.
		var steps := 60
		for k in steps + 1:
			var t := float(k) / steps
			pts.append(from + dir * reach * t + Vector3(0, -reach * 0.55 * t * t + (to.y - from.y) * 0.2 * t, 0))
		var end := pts[pts.size() - 1]
		var drop := 3.0 + half * 1.5
		for k in 12:
			pts.append(end + Vector3(0, -drop * (k + 1) / 12.0, 0) + dir * 0.08 * sin(k * 0.7))
		_chain_ends.append(end)
		var walked := 0.0
		var link := 0
		for k in range(1, pts.size()):
			var seg := pts[k] - pts[k - 1]
			walked += seg.length()
			while walked >= 0.21:
				walked -= 0.21
				var p := pts[k] - seg.normalized() * walked
				var up := seg.normalized()
				var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
				var fwd := side.cross(up)
				var basis := Basis(side, up, fwd)
				if link % 2 == 1:
					basis = basis * Basis(Vector3.UP, PI * 0.5)
				_add("chain_link", Transform3D(basis, p))
				link += 1


# ---------------------------------------------------------------- rims and scatter

## Hanging roots and broken foundation blocks under every rim.
func _rims() -> void:
	for i in layout.islands.size():
		var isl := layout.islands[i]
		var y := _floor(isl) - SHELL
		var rng := RandomNumberGenerator.new()
		rng.seed = 5000 + i
		var count := int(isl.radius * 0.6)
		for k in count:
			var a := rng.randf() * TAU
			var dir := Vector2(cos(a), sin(a))
			var d := isl.radius * 0.6
			while _gauge(i, isl.centre + dir * d) < 0.93 and d < isl.radius * 1.2:
				d += 0.3
			var p := isl.centre + dir * (d - 1.5)
			if k % 3 == 0:
				_add("rubble%d" % (k % 4), Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * 2.0) * Basis(Vector3.RIGHT, PI),
					Vector3(p.x, y + 0.2, p.y)))
			else:
				_add("roots%d" % (k % 2), _xf(Vector3(p.x, y + 0.3 - rng.randf_range(0.0, 2.0), p.y), a))


## Wildflower clumps in the joints near rims and column feet (T0, 40 m).
func _scatter() -> void:
	for i in layout.islands.size():
		var isl := layout.islands[i]
		var y := _floor(isl)
		var rng := RandomNumberGenerator.new()
		rng.seed = 6000 + i
		for k in int(isl.radius * 3.0):
			var a := rng.randf() * TAU
			var s := sqrt(rng.randf_range(0.36, 1.0))
			var p := isl.centre + Vector2(cos(a), sin(a)) * isl.radius * s
			if _gauge(i, p) > 0.95:
				continue
			_add("flowers%d" % (k % 3), _xf(Vector3(p.x, y, p.y), rng.randf() * TAU, rng.randf_range(0.8, 1.3)))


func _clouds() -> void:
	# Puff towers rising round the Fang Rocks, and a few near the islands.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for f in TerrainShape.SKY_FANGS.size():
		var fp: Vector3 = spots["fang%d" % f]
		for k in 7:
			var a := rng.randf() * TAU
			var d: float = TerrainShape.SKY_FANGS[f][1] * rng.randf_range(1.6, 2.6)
			var s := rng.randf_range(0.7, 1.4)
			var y := CLOUD_Y + 4.0 + k * rng.randf_range(2.0, 5.0)
			_add("puff%d" % (k % 3), Transform3D(Basis(Vector3.UP, a).scaled(Vector3(s, s * 0.9, s)),
				Vector3(fp.x + cos(a) * d, y, fp.z + sin(a) * d)))


## Small flocks wheeling around the Crown Gate (view only).
func _birds_build() -> void:
	var m := designs.bird()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	mm.instance_count = 18
	_birds = MultiMeshInstance3D.new()
	_birds.name = "Birds"
	_birds.multimesh = mm
	_birds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_birds)
	for k in 18:
		var flock := k / 6
		_bird_paths.append([flock, k % 6, 14.0 + flock * 8.0, 26.0 + flock * 6.0 + (k % 3) * 0.8])
	animate(0.0)


func animate(t: float) -> void:
	if _birds == null:
		return
	var g: Vector3 = spots.get("gate", Vector3.ZERO)
	for k in _bird_paths.size():
		var bp: Array = _bird_paths[k]
		var r: float = bp[2]
		var speed := 0.16 + 0.03 * float(bp[0])
		var a := t * speed * (1.0 if int(bp[0]) % 2 == 0 else -1.0) + float(bp[0]) * 2.1 + float(bp[1]) * 0.09
		var off := Vector3(sin(float(bp[1]) * 2.3) * 1.2, sin(float(bp[1]) * 1.7) * 0.8, cos(float(bp[1]) * 2.9) * 1.2)
		var p := g + Vector3(cos(a) * r, float(bp[3]) + sin(t * 0.5 + k) * 1.0, sin(a) * r) + off
		var tangent := Vector3(-sin(a), 0, cos(a)) * (1.0 if int(bp[0]) % 2 == 0 else -1.0)
		var flap := sin(t * 9.0 + k * 1.3) * 0.35
		var basis := Basis.looking_at(tangent, Vector3.UP).rotated(tangent.normalized(), flap * 0.2)
		_birds.multimesh.set_instance_transform(k, Transform3D(basis.scaled(Vector3(1.0, 1.0 + flap, 1.0)), p))
	if _flame_light != null:
		_flame_light.light_energy = 1.1 + 0.15 * sin(t * 11.0) + 0.08 * sin(t * 23.0)


# ---------------------------------------------------------------- placement

## Builds each design's tiers and places the collected transforms.
func _place_all() -> void:
	var col := func(v: int) -> Callable: return func() -> ArrayMesh: return designs.column(v)
	var specs := {
		"pier": [func() -> ArrayMesh: return designs.arch_pier(false), [1.0, 2.0, 4.0], PROP_RANGES, 2],
		"pier_grand": [func() -> ArrayMesh: return designs.arch_pier(true), [1.0, 2.0, 4.0], PROP_RANGES, 2],
		"arch_top": [func() -> ArrayMesh: return designs.arch_top(false, false), [2.0, 4.0], [120.0, 0.0], 1],
		"arch_top_ruined": [func() -> ArrayMesh: return designs.arch_top(true, false), [2.0, 4.0], [120.0, 0.0], 1],
		"gate_top": [func() -> ArrayMesh: return designs.arch_top(false, true), [1.0, 2.0, 4.0], [60.0, 200.0, 0.0], 2],
		"watch_stump": [func() -> ArrayMesh: return designs.watch_stump(), [1.0, 4.0], [150.0, 0.0], 1],
		"robed": [func() -> ArrayMesh: return designs.robed_statue(true, true), [1.0, 3.0], [60.0, 0.0], 1],
		"robed_fallen": [func() -> ArrayMesh: return designs.robed_statue(false, false), [1.0, 3.0], [60.0, 0.0], 1],
		"statue_arm": [func() -> ArrayMesh: return designs.statue_arm(), [1.0], [60.0], 1],
		"winged_lion": [func() -> ArrayMesh: return designs.winged_lion(), [1.0, 3.0], [60.0, 0.0], 1],
		"brazier_cold": [func() -> ArrayMesh: return designs.brazier(false), [1.0, 4.0], [40.0, 160.0], 1],
		"brazier_lit": [func() -> ArrayMesh: return designs.brazier(true), [1.0, 4.0], [40.0, 0.0], 1],
		"altar": [func() -> ArrayMesh: return designs.altar(), [1.0, 4.0], [40.0, 160.0], 1],
		"gnomon": [func() -> ArrayMesh: return designs.gnomon(), [1.0, 4.0], [40.0, 160.0], 1],
		"stairs": [func() -> ArrayMesh: return designs.stairs(), [1.0, 3.0], [70.0, 0.0], 1],
		"fallen_column": [func() -> ArrayMesh: return designs.fallen_column(), [1.0, 3.0], [50.0, 200.0], 1],
		"nest": [func() -> ArrayMesh: return designs.nest(), [1.0], [40.0], 0],
		"feather": [func() -> ArrayMesh: return designs.feather(), [1.0], [25.0], 0],
		"chain_link": [func() -> ArrayMesh: return designs.chain_link(), [1.0, 3.0], [40.0, 220.0], 1],
	}
	for v in 5:
		specs["column%d" % v] = [col.call(v), [1.0, 2.0, 4.0], COLUMN_RANGES, 2]
	for v in 2:
		var w := v
		specs["wall%d" % v] = [func() -> ArrayMesh: return designs.wall(w), [1.0, 3.0], [50.0, 200.0], 1]
		specs["roots%d" % v] = [func() -> ArrayMesh: return designs.roots(w), [1.0, 3.0], [50.0, 200.0], 0]
	for v in 4:
		var w := v
		specs["rubble%d" % v] = [func() -> ArrayMesh: return designs.rubble(w), [1.0, 3.0], [40.0, 150.0], 1]
	for v in 3:
		var w := v
		specs["flowers%d" % v] = [func() -> ArrayMesh: return designs.flowers(w), [1.0], [30.0], 0]
		specs["puff%d" % v] = [func() -> ArrayMesh: return VoxelStage.puff_mesh(w), [1.0], [0.0], 0]
	var quads := {}
	for key: String in _lists:
		if not specs.has(key):
			push_warning("no design for %s" % key)
			continue
		var spec: Array = specs[key]
		var s := Time.get_ticks_msec()
		var meshes: Array[ArrayMesh] = []
		if key.begins_with("puff"):
			meshes.append(spec[0].call())
		else:
			meshes = designs.tiers(spec[0], spec[1])
		var list: Array[Transform3D] = _lists[key]
		var tile := 0.0 if key.begins_with("flowers") or key == "feather" else 128.0
		VoxelProp.place(self, key.to_pascal_case(), meshes, spec[2], list, spec[3], 6.0, tile)
		var q := []
		for m in meshes:
			q.append(VoxelProp.quads(m))
		quads[key] = [list.size(), q, Time.get_ticks_msec() - s]
	stats["props"] = quads


# ---------------------------------------------------------------- shots

func shots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var g: Vector3 = spots.gate
	var xa := Vector3(cos(crown.yaw), 0, -sin(crown.yaw))
	var za := Vector3(sin(crown.yaw), 0, cos(crown.yaw))
	# The key image: the Crown Gate at golden hour, columns' shadows striping
	# the plaza, Kael under the gate for scale.
	var cam := g + za * 36.0 - xa * 14.0 + Vector3(0, 3.2, 0)
	var k := g + za * 6.0 + xa * 1.5
	out.append({"name": "crown_gate", "from": cam, "at": g + Vector3(0, 10.0, 0) + za * 2.0, "fov": 55.0,
		"kael": [Vector2(k.x, k.z), atan2(cam.x - k.x, cam.z - k.z)], "times": ["day", "dusk", "night"]})
	# The stairs to nowhere over the cloud sea, Kael on the top step.
	var st: Vector3 = spots.stairs
	var sd: Vector2 = spots.stairs_dir
	var sdir := Vector3(sd.x, 0, sd.y)
	var side := Vector3(-sd.y, 0, sd.x)
	var top := st + sdir * 5.3
	out.append({"name": "stairs", "from": st - sdir * 9.0 + side * 9.0 + Vector3(0, 4.5, 0), "at": top + sdir * 6.0 + Vector3(0, -2.0, 0),
		"fov": 55.0, "kael": [Vector2(top.x, top.z), atan2(-sdir.x, -sdir.z) + 0.4], "kael_y": st.y + 2.7,
		"times": ["day"]})
	# The fallen statue on Watch Island, the stump behind, Kael beside it.
	var f: Vector3 = spots.fallen
	var fy: float = spots.fallen_yaw
	var fdir := Vector3(sin(fy), 0, cos(fy))
	var fside := Vector3(cos(fy), 0, -sin(fy))
	var fk := f + fdir * 2.6 - fside * 2.2
	var fcam := f + fdir * 7.5 + fside * 3.2 + Vector3(0, 2.3, 0)
	out.append({"name": "fallen_statue", "from": fcam, "at": f + fdir * 1.5 + Vector3(0, 0.6, 0), "fov": 55.0,
		"kael": [Vector2(fk.x, fk.z), atan2(fcam.x - fk.x, fcam.z - fk.z)], "times": ["day"]})
	# A wide overview: island cluster, fangs, cloud sea, blue sky.
	out.append({"name": "overview", "from": Vector3(260, 290, -300), "at": Vector3(10, 150, -640), "fov": 55.0,
		"times": ["day", "dusk", "night"]})
	# Gameplay-ish camera on Kael at the spawn-side brazier island.
	var b: Vector3 = spots.brazier
	var kb := b + Vector3(-2.5, 0, 2.0)
	out.append({"name": "kael_scale", "from": kb + Vector3(3.0, 2.6, 5.2), "at": kb + Vector3(0, 1.2, 0), "fov": 55.0,
		"kael": [Vector2(kb.x, kb.z), PI * 0.15], "times": ["day", "night"]})
	# The Fang Rocks piercing the clouds, islands above.
	var f0: Vector3 = spots.fang0
	out.append({"name": "fangs", "from": f0 + Vector3(70, -40, 90), "at": f0 + Vector3(0, -40, 0), "fov": 55.0,
		"times": ["day"]})
	# Under an island: strata and roots over the cloud sea.
	out.append({"name": "underside", "from": Vector3(watch.centre.x + 60, watch.top - 70, watch.centre.y + 55),
		"at": Vector3(watch.centre.x, watch.top - 30, watch.centre.y), "fov": 55.0, "times": ["day"]})
	# The snapped chains over the gap.
	if spots.has("chain_a"):
		var ca: Vector3 = spots.chain_a
		var cb: Vector3 = spots.chain_b
		var mid := (ca + cb) * 0.5
		var perp := (cb - ca).cross(Vector3.UP).normalized()
		out.append({"name": "chains", "from": mid + perp * 22.0 + Vector3(0, -3.0, 0), "at": mid + Vector3(0, -4.0, 0),
			"fov": 55.0, "times": ["day"]})
	# The sundial.
	var sdl: Vector3 = spots.sundial
	out.append({"name": "sundial", "from": sdl + Vector3(9, 6, 9), "at": sdl, "fov": 55.0, "times": ["day"]})
	return out


## A 20 s flight: down into the island cluster past the lit brazier, under
## Watch Island, past the fallen statue, round a Fang Rock low over the cloud
## sea, up past the snapped chains, through the Crown Gate and out to a wide.
func flight() -> Array[Dictionary]:
	var g: Vector3 = spots.gate
	var za := Vector3(sin(crown.yaw), 0, cos(crown.yaw))
	var b: Vector3 = spots.brazier
	var f: Vector3 = spots.fallen
	var f0: Vector3 = spots.fang0
	var w := Vector3(watch.centre.x, watch.top, watch.centre.y)
	var mid: Vector3 = (spots.get("chain_a", w) + spots.get("chain_b", w)) * 0.5
	return [
		{"from": Vector3(120, 240, -430), "at": b},
		{"from": b + Vector3(30, 14, 26), "at": b + Vector3(0, 2, 0)},
		{"from": w + Vector3(85, -25, 20), "at": w + Vector3(0, -35, 0)},
		{"from": w + Vector3(40, -75, 70), "at": w + Vector3(0, -50, 0)},
		{"from": w + Vector3(-30, 15, 85), "at": f},
		{"from": f + Vector3(-10, 13, 22), "at": f + Vector3(0, 1, 0)},  # over the columns, not through
		{"from": mid + Vector3(14, 4, 36), "at": mid + Vector3(0, -4, 0)},
		{"from": f0 + Vector3(20, -50, 70), "at": f0 + Vector3(0, -30, 0)},
		{"from": f0 + Vector3(50, -32, -5), "at": f0 + Vector3(0, -10, 0)},  # above the cloud puffs
		{"from": Vector3(-30, 185, -760), "at": g + Vector3(0, 10, 0)},
		{"from": g + za * 45.0 + Vector3(0, 12, 0), "at": g + Vector3(0, 9, 0)},
		{"from": g + za * 6.0 + Vector3(0, 8, 0), "at": g - za * 30.0 + Vector3(0, 7, 0)},
		{"from": g - za * 55.0 + Vector3(0, 27, 0), "at": g - za * 160.0 + Vector3(0, -22, 0)},
	]


func flight_kael() -> Array:
	var g: Vector3 = spots.gate
	var za := Vector3(sin(crown.yaw), 0, cos(crown.yaw))
	var xa := Vector3(cos(crown.yaw), 0, -sin(crown.yaw))
	var k := g + za * 6.0 + xa * 1.5
	return [Vector2(k.x, k.z), crown.yaw]


## True if p is inside (or within margin of) an island's paved shell or
## underside, an arch, or a Fang Rock: the fly-through must never be.
func inside_solid(p: Vector3, margin := 2.5) -> bool:
	for i in layout.islands.size():
		var isl := layout.islands[i]
		var q := Vector2(p.x, p.z)
		var g := _gauge(i, q)
		if g > 1.0 + margin / isl.radius:
			continue
		var reach := clampf((1.0 - g) / 0.86, 0.0, 1.0)
		var bottom := isl.top - isl.depth * pow(reach, 0.8) - 4.0
		var top := _floor(isl) + margin
		if p.y > bottom - margin and p.y < top:
			return true
		if isl.arch:
			var d := q - isl.centre
			var lx := absf(d.dot(Vector2(cos(isl.yaw), -sin(isl.yaw))))
			var lz := absf(d.dot(Vector2(sin(isl.yaw), cos(isl.yaw))))
			var h := p.y - _floor(isl)
			var grand := 5.0 if isl == crown else 0.0
			if lz < 2.6 + margin and lx < 10.4 + margin and h < 20.6 + grand + margin \
					and (lx > SkyholdRuinsDesigns.INTRADOS - margin or h > 15.5 - margin):
				return true
	return p.y < layout.heightmap.ground_height_at(p.x, p.z) + margin * 2.0
