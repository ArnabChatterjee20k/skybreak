class_name StormfallCityVoxel
extends VoxelZone
## Stormfall City in the voxel style (docs/lookdev/stormfall_city.md), look v1,
## on the voxel zone kit. The sim stays the truth: the ground is the baked
## heightmap (TerrainShape._city) sampled on its own 2 m grid, and every
## building, rubble heap, water tower, sign and car comes from
## StormfallCityProps run as ZoneMatch runs it (PropKit seed 4242, spawns kept
## clear), so the layout is identical; this only builds the look over them.
##
## Tiers: T1 (8.8 cm) street paint, shop floors, cars, street props; T2 (35 cm)
## upper facades, roofs, rubble, towers; T3 (1.4 m) the skyline ring's far
## tier. Everything is boxes (CityBlocks), merged per 48 m tile with a near
## and a far LOD; the cell look comes from the shaders.

const BLOCK_SHADER := preload("res://game/world/zones_voxel/stormfall_city/city_block.gdshader")
const STREET_SHADER := preload("res://game/world/zones_voxel/stormfall_city/city_street.gdshader")
const STREAK_SHADER := preload("res://game/world/zones_voxel/stormfall_city/city_streak.gdshader")
const RAIN_SHADER := preload("res://game/world/zones_voxel/stormfall_city/city_rain.gdshader")
const TILE := 48.0
## Near tier ends here (m); the far tier takes over to the fog.
const NEAR_RANGE := 170.0
const GROUND_NEAR := 140.0
## The coarse far ground reaches this far (m) past the ground tiles.
const FAR_GROUND := 1800.0
const STOREY := 3.5

## Palette (sRGB), from the sheet.
const ASPHALT := Color("#2A2C34")
const CONCRETE := Color("#5A5C66")
const CONCRETE_DARK := Color("#34363E")
const BRICK := Color("#6A4A40")
const STONE := Color("#7A7266")
const STEEL := Color("#4A4442")
const RUST := Color("#6A5040")
const MAGENTA := Color("#FF3CA8")
const WARM_WHITE := Color("#F4E6CE")
const WINDOW := Color("#E8C890")
const SODIUM := Color("#E0A860")
const CAR_COLOURS: Array[Color] = [Color("#5d6470"), Color("#6e5650"), Color("#4f5e58"), Color("#7a7468"),
	Color("#3e4250"), Color("#6c6a70")]

var zone: ZoneData
var layout: ZoneLayout
var heightmap: TerrainHeightmap
var buildings: Array[Transform3D] = []
var rubble: Array[Transform3D] = []
var tanks: Array[Transform3D] = []
var signs: Array[Transform3D] = []
var cars: Array[Transform3D] = []
## Landmark towers: name -> building transform.
var towers := {}
## Magenta emitters (world positions) for the nearest-sign lights.
var magenta_spots: PackedVector3Array = []
var block_mat: ShaderMaterial
var street_mat: ShaderMaterial
var _near: Dictionary = {}
var _far: Dictionary = {}
var _streaks := CityBlocks.new()
var _lights: Array[OmniLight3D] = []
var _bolt: Node3D
var _flash: DirectionalLight3D
var _rain: GPUParticles3D
var _flash_at: Array[float] = [3.2, 11.6, 18.4]
var _tris := {}


func _init() -> void:
	name = "StormfallCity"


func build() -> void:
	var t := Time.get_ticks_msec()
	zone = load("res://game/world/zones/stormfall_city.tres")
	layout = ZoneLayout.load_default()
	heightmap = load(WorldMap.HEIGHTMAP_PATH)
	_placements()
	block_mat = ShaderMaterial.new()
	block_mat.shader = BLOCK_SHADER
	street_mat = ShaderMaterial.new()
	street_mat.shader = STREET_SHADER
	street_mat.set_shader_parameter("zone_centre", zone.centre)
	var steps: Array[Callable] = [_ground, _buildings, _occluders, _towers, _rubble, _signs, _cars, _street_props,
		_story_props, _commit_tiles, _weather]
	for step in steps:
		var s := Time.get_ticks_msec()
		step.call()
		stats["ms_" + step.get_method().trim_prefix("_")] = Time.get_ticks_msec() - s
	stats["tris"] = _tris
	stats["ms_total"] = Time.get_ticks_msec() - t


func ground_at(x: float, z: float) -> float:
	return heightmap.ground_height_at(x, z)


## Runs the sim's own prop builder as ZoneMatch does (focus zone: a fresh
## PropKit with seed 4242 and every ground zone's spawns kept clear) and reads
## its instance transforms; the grey-box meshes are thrown away.
func _placements() -> void:
	var kit := PropKit.new(heightmap, WorldMap.PROP_SEED)
	for z in layout.ground_zones():
		for p in z.spawn_points:
			kit.keep_clear.append(Vector3(p.x, p.z, WorldMap.SPAWN_CLEAR_RADIUS))
	var scratch := Node3D.new()
	StormfallCityProps.build(scratch, kit, zone, layout)
	for child in scratch.get_children():
		var list: Array[Transform3D] = []
		list.assign(child.get_meta(PropKit.INSTANCE_TRANSFORMS_META, []))
		match String(child.name):
			"Buildings": buildings = list
			"Rubble": rubble = list
			"WaterTowers": tanks = list
			"NeonSigns": signs = list
			"Cars": cars = list
	scratch.free()
	for i in zone.landmark_names.size():
		var nm := zone.landmark_names[i]
		if not nm.contains("Tower"):
			continue
		var lp := Vector2(zone.landmark_positions[i].x, zone.landmark_positions[i].z)
		for b in buildings:
			if Vector2(b.origin.x, b.origin.z).distance_to(lp) < TILE * 0.5 and b.basis.get_scale().y >= 120.0:
				towers[nm] = b
		if not towers.has(nm) and nm == "Spire Tower":
			# The sim places no building here (the block sits on the raised
			# district's slope, so StormfallCityProps skips it): the Spire is a
			# visual landmark only until the sim gets one (filed in TODO.md).
			var low := INF
			for dx in [-13.0, 13.0]:
				for dz in [-13.0, 13.0]:
					low = minf(low, heightmap.ground_height_at(lp.x + dx, lp.y + dz))
			towers[nm] = PropKit.placed(Vector3(lp.x, low - 1.0, lp.y), Vector3(26, 150, 26), 0.0)
			stats["spire_visual_only"] = true
	stats["buildings"] = buildings.size()
	stats["cars"] = cars.size()
	stats["signs"] = signs.size()


# ---------------------------------------------------------------- tiles

func _tile_key(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.z / TILE))


func _near_blocks(p: Vector3) -> CityBlocks:
	var k := _tile_key(p)
	if not _near.has(k):
		_near[k] = CityBlocks.new()
	return _near[k]


func _far_blocks(p: Vector3) -> CityBlocks:
	var k := _tile_key(p)
	if not _far.has(k):
		_far[k] = CityBlocks.new()
	return _far[k]


## Every tile becomes a near mesh (shadowed, to NEAR_RANGE) and a far mesh
## (unshadowed, from NEAR_RANGE on); tiles with only far geometry show it always.
func _commit_tiles() -> void:
	var root := Node3D.new()
	root.name = "Blocks"
	add_child(root)
	var near_tris := 0
	var far_tris := 0
	for k: Vector2i in _far:
		var far: CityBlocks = _far[k]
		var near: CityBlocks = _near.get(k, null)
		var fm := far.commit()
		far_tris += far.triangles()
		var fi := MeshInstance3D.new()
		fi.name = "Far_%d_%d" % [k.x, k.y]
		fi.mesh = fm
		fi.material_override = block_mat
		root.add_child(fi)
		if near == null or near.is_empty():
			continue
		var nm := near.commit()
		near_tris += near.triangles()
		var ni := MeshInstance3D.new()
		ni.name = "Near_%d_%d" % [k.x, k.y]
		ni.mesh = nm
		ni.material_override = block_mat
		root.add_child(ni)
		# One AABB for both tiers, so the hard switch measures the same distance
		# (different centres left a band where both drew and z-fought).
		var box := fm.get_aabb().merge(nm.get_aabb())
		fi.custom_aabb = box
		ni.custom_aabb = box
		fi.visibility_range_begin = VoxelQuality.far(NEAR_RANGE)
		fi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ni.visibility_range_end = VoxelQuality.far(NEAR_RANGE)
	for k: Vector2i in _near:
		var near: CityBlocks = _near[k]
		if _far.has(k) or near.is_empty():
			continue
		near_tris += near.triangles()
		var ni := MeshInstance3D.new()
		ni.name = "Near_%d_%d" % [k.x, k.y]
		ni.mesh = near.commit()
		ni.material_override = block_mat
		ni.visibility_range_end = VoxelQuality.far(NEAR_RANGE * 1.5)
		root.add_child(ni)
	_tris["blocks_near_all_tiles"] = near_tris
	_tris["blocks_far_all_tiles"] = far_tris
	if not _streaks.is_empty():
		var sm := MeshInstance3D.new()
		sm.name = "NeonStreaks"
		sm.mesh = _streaks.commit()
		var mat := ShaderMaterial.new()
		mat.shader = STREAK_SHADER
		sm.material_override = mat
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sm)
		_tris["streaks"] = _streaks.triangles()


# ---------------------------------------------------------------- ground

## The ground on the heightmap's own 2 m grid (so the visible street is the
## sim floor), in 48 m chunks: a 2 m near tier and an 8 m far tier.
func _ground() -> void:
	var root := Node3D.new()
	root.name = "Ground"
	add_child(root)
	var c := zone.centre
	var lo := Vector2(c.x - 500.0, c.y - 600.0)
	var hi := Vector2(c.x + 500.0, c.y + 600.0)
	var tris := 0
	# The outer ring only ever shows its 8 m tier: merged 4 x 4 tiles to a draw.
	var ring := {}
	for tz in range(floori(lo.y / TILE), ceili(hi.y / TILE)):
		for tx in range(floori(lo.x / TILE), ceili(hi.x / TILE)):
			var o := Vector2(tx * TILE, tz * TILE)
			var d := o + Vector2(TILE, TILE) * 0.5 - c
			var close := absf(d.x) < 360.0 and absf(d.y) < 480.0
			if not close:
				var key := Vector2i(floori(tx / 4.0), floori(tz / 4.0))
				var arrays := _ground_mesh(o, 8.0).surface_get_arrays(0)
				# Packed arrays are values: append to a local copy and store it back.
				var pair: Array = ring.get(key, [PackedVector3Array(), PackedVector3Array()])
				var verts: PackedVector3Array = pair[0]
				var normals: PackedVector3Array = pair[1]
				verts.append_array(arrays[Mesh.ARRAY_VERTEX])
				normals.append_array(arrays[Mesh.ARRAY_NORMAL])
				ring[key] = [verts, normals]
				continue
			for lod in [2.0, 8.0]:
				var mesh := _ground_mesh(o, lod)
				var mi := MeshInstance3D.new()
				mi.mesh = mesh
				mi.material_override = street_mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if close:
					if lod == 2.0:
						mi.visibility_range_end = VoxelQuality.far(GROUND_NEAR)
					else:
						mi.visibility_range_begin = VoxelQuality.far(GROUND_NEAR)
				root.add_child(mi)
				tris += mesh.surface_get_array_len(0) / 3 if lod == 2.0 else 0
	for key: Vector2i in ring:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = ring[key][0]
		arrays[Mesh.ARRAY_NORMAL] = ring[key][1]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = street_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		tris += mesh.surface_get_array_len(0) / 3
	_tris["ground_all_tiles"] = tris
	_tris["ground_far"] = _ground_far(root, Rect2(lo, hi - lo))


## Coarse matte ground from the tiles' edge on past the fog (FAR_GROUND m each
## way), so from the high fly-through no straight terrain edge cuts the sky. It
## starts one step inside the tiles and a metre lower, so no seam shows.
func _ground_far(root: Node3D, tiles: Rect2) -> int:
	var step := 64.0
	var outer := tiles.grow(FAR_GROUND)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var inner := tiles.grow(-step)
	var nx := ceili(outer.size.x / step)
	var nz := ceili(outer.size.y / step)
	# Past the heightmap's square the ground eases down to the city's level (no
	# clamped plateau at the map edge).
	var base := heightmap.ground_height_at(zone.centre.x, zone.centre.y)
	var map := Rect2(heightmap.origin, Vector2.ONE * heightmap.cell_size * (heightmap.size - 1))
	var h := func(x: float, z: float) -> float:
		var out := maxf(maxf(map.position.x - x, x - map.end.x), maxf(map.position.y - z, z - map.end.y))
		return lerpf(heightmap.ground_height_at(x, z), base, clampf(out / 400.0, 0.0, 1.0)) - 1.0
	for j in nz:
		for i in nx:
			var o := outer.position + Vector2(i, j) * step
			if inner.encloses(Rect2(o, Vector2(step, step))):
				continue
			var p00 := Vector3(o.x, h.call(o.x, o.y), o.y)
			var p10 := Vector3(o.x + step, h.call(o.x + step, o.y), o.y)
			var p01 := Vector3(o.x, h.call(o.x, o.y + step), o.y + step)
			var p11 := Vector3(o.x + step, h.call(o.x + step, o.y + step), o.y + step)
			for tri: Array in [[p00, p10, p11], [p00, p11, p01]]:
				var nn := ((tri[2] as Vector3) - (tri[0] as Vector3)).cross((tri[1] as Vector3) - (tri[0] as Vector3)).normalized()
				for v: Vector3 in tri:
					verts.append(v)
					normals.append(nn)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "GroundFar"
	mi.mesh = mesh
	# Matte: the street shader's wet glints read as bright patches in the fog.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#3a3944")
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return verts.size() / 3


func _ground_mesh(o: Vector2, step: float) -> ArrayMesh:
	var n := int(TILE / step)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var hts := PackedFloat32Array()
	hts.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			hts[j * (n + 1) + i] = heightmap.ground_height_at(o.x + i * step, o.y + j * step)
	for j in n:
		for i in n:
			var p00 := Vector3(o.x + i * step, hts[j * (n + 1) + i], o.y + j * step)
			var p10 := Vector3(o.x + (i + 1) * step, hts[j * (n + 1) + i + 1], o.y + j * step)
			var p01 := Vector3(o.x + i * step, hts[(j + 1) * (n + 1) + i], o.y + (j + 1) * step)
			var p11 := Vector3(o.x + (i + 1) * step, hts[(j + 1) * (n + 1) + i + 1], o.y + (j + 1) * step)
			# A fan around the cell's bilinear centre: four times closer to the
			# sim's bilinear floor than a single diagonal on the canal slopes.
			var pc := (p00 + p10 + p01 + p11) * 0.25
			for tri: Array in [[p00, p10, pc], [p10, p11, pc], [p11, p01, pc], [p01, p00, pc]]:
				var nn := ((tri[2] as Vector3) - (tri[0] as Vector3)).cross((tri[1] as Vector3) - (tri[0] as Vector3)).normalized()
				for v: Vector3 in tri:
					verts.append(v)
					normals.append(nn)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


# ---------------------------------------------------------------- buildings

static func _h(v: Vector3, salt: int) -> float:
	return VoxelSdf.hash3(Vector3i(floori(v.x * 3.0), floori(v.y * 3.0), floori(v.z * 3.0)), salt)


static func _jit(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k)


## A box in a building's frame (base centre at the origin, local metres).
static func _bx(b: CityBlocks, frame: Transform3D, centre: Vector3, size: Vector3, col: Color, code: int, cell: float,
		faces := CityBlocks.ALL, seed_value := 0.0) -> void:
	b.add(frame * Transform3D(Basis.from_scale(size), centre), col, code, cell, faces, seed_value)


func _buildings() -> void:
	for xf in buildings:
		var is_tower := false
		for nm: String in towers:
			if towers[nm] == xf:
				is_tower = true
		if is_tower:
			continue
		var size := xf.basis.get_scale()
		var rot := xf.basis.orthonormalized()
		var base := xf.origin - xf.basis * Vector3(0, 0.5, 0)
		var frame := Transform3D(rot, base)
		var skyline := size.y >= 68.0 and size.x <= 30.5 and size.z <= 30.5 and absf(size.x - size.z) > 0.01 \
			or size.y >= 68.0
		_building(_far_blocks(base), frame, size, base, false)
		if not skyline:
			_building(_near_blocks(base), frame, size, base, true)
	_tris["water_towers"] = tanks.size()
	for xf in tanks:
		var base := xf.origin - xf.basis * Vector3(0, 0.5, 0)
		_water_tower(_near_blocks(base), Transform3D(Basis(), base), true)
		_water_tower(_far_blocks(base), Transform3D(Basis(), base), false)


## An occluder inside each building's full-footprint body (the shop floor up
## to the roof under any setback or broken top, as _building lays it out), so
## streets and blocks behind buildings skip the main pass.
func _occluders() -> void:
	var root := Node3D.new()
	root.name = "Occluders"
	add_child(root)
	for xf in buildings:
		var size := xf.basis.get_scale()
		var base := xf.origin - xf.basis * Vector3(0, 0.5, 0)
		var top := size.y
		var shop_h := 1.0 + 4.5
		var setback := top > 30.0 and _h(base, 4) < 0.55
		var broken := _h(base, 5) < 0.3 and top > 20.0
		var body_top := shop_h + roundf((top - shop_h) * 0.62 / STOREY) * STOREY if setback else top
		var lower_top := body_top - (2.0 * STOREY if broken and not setback else 0.0)
		if lower_top < 6.0 or minf(size.x, size.z) < 4.0:
			continue
		var box := BoxOccluder3D.new()
		box.size = Vector3(size.x - 0.6, lower_top - 1.0, size.z - 0.6)
		var oi := OccluderInstance3D.new()
		oi.occluder = box
		var rot := xf.basis.orthonormalized()
		oi.transform = Transform3D(rot, base + rot * Vector3(0, lower_top * 0.5, 0))
		root.add_child(oi)
	stats["occluders"] = root.get_child_count()
	if is_inside_tree():
		get_viewport().use_occlusion_culling = true


## One building: storey slabs, setback, cornice, parapet, windows (shader),
## broken top, a crack line if it leans; near tier adds shop fronts, fire
## escapes, balconies and roof clutter.
func _building(b: CityBlocks, frame: Transform3D, size: Vector3, base: Vector3, near: bool) -> void:
	b.base_y = base.y
	var w := size.x
	var d := size.z
	var top := size.y
	var seed_v := _h(base, 1)
	var brick := seed_v < 0.3 and top < 45.0
	var code := CityBlocks.Code.BRICK if brick else CityBlocks.Code.FACADE
	var tone := 0.88 + 0.24 * _h(base, 2)
	var warm := _h(base, 3)
	var wall: Color = _jit(BRICK if brick else CONCRETE.lerp(Color("#625c58") if warm > 0.5 else Color("#545a66"), 0.5), tone)
	var trim := _jit(CONCRETE_DARK.lerp(CONCRETE, 0.6), tone * 1.05)
	var cell := T2
	# Ground floor at T1 (what fighters fight against), the rest at T2.
	var shop_h := 1.0 + 4.5
	_bx(b, frame, Vector3(0, shop_h * 0.5, 0), Vector3(w, shop_h, d), _jit(wall, 0.9), CityBlocks.Code.CONCRETE, T1,
		CityBlocks.NO_BOTTOM, seed_v)
	var setback := top > 30.0 and _h(base, 4) < 0.55
	var body_top := top
	var broken := _h(base, 5) < 0.3 and top > 20.0
	if setback:
		body_top = shop_h + roundf((top - shop_h) * 0.62 / STOREY) * STOREY
	var lower_top := body_top - (2.0 * STOREY if broken and not setback else 0.0)
	_bx(b, frame, Vector3(0, (shop_h + lower_top) * 0.5, 0), Vector3(w, lower_top - shop_h, d), wall, code, cell,
		CityBlocks.ALL, seed_v)
	# Shop-floor slab band and the cornice.
	_bx(b, frame, Vector3(0, shop_h + 0.18, 0), Vector3(w + 0.7, 0.35, d + 0.7), trim, CityBlocks.Code.CONCRETE, T2)
	if broken and not setback:
		# Broken top: two storeys stand on three quarters of the roof; the missing
		# corner shows its floor slabs and rebar.
		var sx := 1.0 if _h(base, 6) < 0.5 else -1.0
		var sz := 1.0 if _h(base, 7) < 0.5 else -1.0
		_bx(b, frame, Vector3(-sx * w * 0.25, (lower_top + body_top) * 0.5, 0), Vector3(w * 0.5, body_top - lower_top, d),
			wall, code, cell, CityBlocks.ALL, seed_v)
		_bx(b, frame, Vector3(sx * w * 0.25, (lower_top + body_top - STOREY) * 0.5, -sz * d * 0.25),
			Vector3(w * 0.5, body_top - STOREY - lower_top, d * 0.5), wall, code, cell, CityBlocks.ALL, seed_v)
		for k in 3:
			var y := lower_top + k * STOREY
			var reach := 0.4 + 0.6 * _h(base + Vector3(k, 0, 0), 8)
			_bx(b, frame, Vector3(sx * w * 0.25, y + 0.15, sz * d * 0.25 * reach), Vector3(w * 0.5 * reach, 0.3, d * 0.5 * reach),
				trim, CityBlocks.Code.CONCRETE, T2)
			if near:
				for r in 5:
					var rx := sx * (w * 0.05 + w * 0.4 * _h(base + Vector3(r, k, 0), 9))
					_bx(b, frame, Vector3(rx, y + 0.6, sz * d * 0.48 * reach), Vector3(0.05, 1.0 + _h(base + Vector3(r, 0, k), 10), 0.05),
						RUST, CityBlocks.Code.RUST, T0)
	else:
		_cornice(b, frame, w, d, body_top, trim, near)
	if setback:
		var iw := w - 2.0 * (2.0 + roundf(_h(base, 11) * 2.0))
		var id := d - 2.0 * (2.0 + roundf(_h(base, 12) * 2.0))
		_bx(b, frame, Vector3(0, (body_top + top) * 0.5, 0), Vector3(iw, top - body_top, id), wall, code, cell,
			CityBlocks.ALL, seed_v + 0.5)
		_cornice(b, frame, iw, id, top, trim, near)
	var leaning := absf(frame.basis.get_euler().x) + absf(frame.basis.get_euler().z) > 0.001
	if leaning:
		# A leaning building: a dark crack line just above its foot.
		_bx(b, frame, Vector3(0, 2.2, 0), Vector3(w + 0.12, 0.3, d + 0.12), Color("#1c1d22"), CityBlocks.Code.CONCRETE, T1)
	if not near:
		return
	_shop_fronts(b, frame, w, d, base)
	if not leaning:
		_sills(b, frame, w, d, lower_top, code == CityBlocks.Code.BRICK)
	if _h(base, 13) < 0.45 and lower_top > 14.0:
		_fire_escape(b, frame, w, d, lower_top, base)
	if _h(base, 14) < 0.5 and lower_top > 10.0:
		_balconies(b, frame, w, d, lower_top, base)
	_roof_clutter(b, frame, (w - 4.0 * float(setback) * 2.0) if setback else w, d if not setback else d - 8.0,
		top if setback or not broken else lower_top, base)


## Real sills and hoods under and over the shader's windows on the three
## storeys above the shop floor (relief where fighters fight); the bays match
## city_block.gdshader exactly (3 m bays, 4 x 5 T2-cell windows, sill at 0.7 m).
func _sills(b: CityBlocks, frame: Transform3D, w: float, d: float, top: float, brick: bool) -> void:
	var col := Color("#6a6a70") if not brick else Color("#7a6a60")
	for side in 4:
		var along := w if side < 2 else d
		var out := (d if side < 2 else w) * 0.5
		var nb := floorf((along - 1.0) / 3.0)
		if nb < 1.0:
			continue
		var margin := (along - nb * 3.0) * 0.5
		for si in range(2, 5):
			var y := si * STOREY + 0.7
			if y + 2.0 > top - 1.2:
				break
			for k in int(nb):
				# _side's u and the face's own u (CityBlocks) agree on every side.
				var u := margin + 3.0 * k + 1.4 - along * 0.5
				_bx(b, frame, _side(side, u, out + 0.12) + Vector3(0, y - 0.09, 0), _side_size(side, 1.75, 0.3) + Vector3(0, 0.18, 0),
					col, CityBlocks.Code.CONCRETE, T1)
				_bx(b, frame, _side(side, u, out + 0.08) + Vector3(0, y + 1.75 + 0.09, 0), _side_size(side, 1.75, 0.2) + Vector3(0, 0.18, 0),
					col * 0.85, CityBlocks.Code.CONCRETE, T1)


func _cornice(b: CityBlocks, frame: Transform3D, w: float, d: float, y: float, trim: Color, near: bool) -> void:
	_bx(b, frame, Vector3(0, y - 0.35, 0), Vector3(w + 0.7, 0.7, d + 0.7), trim, CityBlocks.Code.CONCRETE, T2)
	# Parapet: four walls a cell thick, 1 m tall.
	var t := T2
	_bx(b, frame, Vector3(0, y + 0.5, d * 0.5 - t * 0.5), Vector3(w, 1.0, t), trim, CityBlocks.Code.CONCRETE, T2)
	_bx(b, frame, Vector3(0, y + 0.5, -d * 0.5 + t * 0.5), Vector3(w, 1.0, t), trim, CityBlocks.Code.CONCRETE, T2)
	_bx(b, frame, Vector3(w * 0.5 - t * 0.5, y + 0.5, 0), Vector3(t, 1.0, d - 2.0 * t), trim, CityBlocks.Code.CONCRETE, T2)
	_bx(b, frame, Vector3(-w * 0.5 + t * 0.5, y + 0.5, 0), Vector3(t, 1.0, d - 2.0 * t), trim, CityBlocks.Code.CONCRETE, T2)
	if near:
		# Roof membrane: darker, a cell below the parapet top.
		_bx(b, frame, Vector3(0, y + 0.05, 0), Vector3(w - 2.0 * t, 0.1, d - 2.0 * t), Color("#2c2d33"), CityBlocks.Code.CONCRETE, T2)


## Shop fronts on all four faces: roller shutters (some up, showing a lit or
## dark window), awnings, a slab sign board.
func _shop_fronts(b: CityBlocks, frame: Transform3D, w: float, d: float, base: Vector3) -> void:
	for side in 4:
		var along := w if side < 2 else d
		var out := (d if side < 2 else w) * 0.5
		var nshops := maxi(1, floori(along / 6.0))
		var span := along / nshops
		for k in nshops:
			var u := -along * 0.5 + span * (k + 0.5)
			var hk := _h(base + Vector3(side * 7, 0, k), 20)
			var sw := span - 1.0
			var pos := _side(side, u, out + 0.06)
			var sz := _side_size(side, sw, 0.12)
			var col := Color("#4a4c52").lerp(Color("#5a5048"), _h(base + Vector3(k, side, 0), 21))
			if hk < 0.55:
				# Shutter down (graffiti tag on some: a muted cell patch).
				_bx(b, frame, pos + Vector3(0, 1.0 + 1.6, 0), sz + Vector3(0, 3.2, 0), col, CityBlocks.Code.SHUTTER, T1)
				if hk < 0.18:
					_bx(b, frame, _side(side, u + 0.4, out + 0.13) + Vector3(0, 2.0, 0), _side_size(side, 1.6, 0.02) + Vector3(0, 0.9, 0),
						Color("#6a5a6a") if hk < 0.09 else Color("#5a6a66"), CityBlocks.Code.PAINT, T1)
			else:
				# Shutter up: glass shop window, lit warm or dark.
				_bx(b, frame, pos + Vector3(0, 1.0 + 1.4, 0), sz + Vector3(0, 2.8, 0),
					WINDOW if hk > 0.8 else Color("#141820"), CityBlocks.Code.SHOP if hk > 0.8 else CityBlocks.Code.GLASS, T1)
				_bx(b, frame, pos + Vector3(0, 1.0 + 3.05, 0), sz + Vector3(0, 0.5, 0.06), col, CityBlocks.Code.SHUTTER, T1)
			if _h(base + Vector3(k, 0, side), 22) < 0.35:
				# Awning: a sloped slab of muted canvas with a valance.
				var acol := [Color("#5a4c48"), Color("#4c5450"), Color("#5c5a54"), Color("#4a4c58")][int(hk * 40.0) % 4] as Color
				var ap := _side(side, u, out + 0.9)
				var asz := _side_size(side, sw, 1.8)
				var tilt := Basis(_side_axis(side), -0.25 * (1.0 if side % 2 == 0 else -1.0))
				b.add(frame * Transform3D(tilt * Basis.from_scale(asz + Vector3(0, 0.12, 0)), ap + Vector3(0, 4.55, 0)), acol,
					CityBlocks.Code.CLOTH, T1)
				_bx(b, frame, _side(side, u, out + 1.75) + Vector3(0, 4.15, 0), _side_size(side, sw, 0.06) + Vector3(0, 0.35, 0), acol * 0.85,
					CityBlocks.Code.CLOTH, T1)


## Position on a face: side 0 +z, 1 -z, 2 +x, 3 -x; u along it, out from the centre.
static func _side(side: int, u: float, out: float) -> Vector3:
	match side:
		0: return Vector3(u, 0, out)
		1: return Vector3(-u, 0, -out)
		2: return Vector3(out, 0, -u)
	return Vector3(-out, 0, u)


static func _side_size(side: int, along: float, depth: float) -> Vector3:
	return Vector3(along, 0, depth) if side < 2 else Vector3(depth, 0, along)


static func _side_axis(side: int) -> Vector3:
	return Vector3.RIGHT if side < 2 else Vector3.BACK


static func _side_normal(side: int) -> Vector3:
	return [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT][side]


## Zig-zag fire escape on one face: a landing per storey, rails, a stair between.
func _fire_escape(b: CityBlocks, frame: Transform3D, w: float, d: float, top: float, base: Vector3) -> void:
	var side := int(_h(base, 30) * 4.0) % 4
	var along := w if side < 2 else d
	var out := (d if side < 2 else w) * 0.5
	var u := (-0.25 + 0.5 * _h(base, 31)) * along * 0.5
	var nrm := _side_normal(side)
	var ax := _side_axis(side) * (1.0 if side % 2 == 0 else -1.0)
	var steel := STEEL
	var y := 1.0 + 4.5 + STOREY
	var k := 0
	while y < top - 1.0:
		var c := _side(side, u, out + 0.65)
		_bx(b, frame, c + Vector3(0, y, 0), _side_size(side, 3.4, 1.2) + Vector3(0, 0.08, 0), steel, CityBlocks.Code.STEEL, T1)
		# Rails: top bar and posts.
		_bx(b, frame, c + nrm * 0.58 + Vector3(0, y + 0.95, 0), _side_size(side, 3.4, 0.05) + Vector3(0, 0.05, 0), steel,
			CityBlocks.Code.STEEL, T0)
		for p in 4:
			_bx(b, frame, c + nrm * 0.58 + ax * (-1.6 + p * 1.066) + Vector3(0, y + 0.48, 0), Vector3(0.05, 0.95, 0.05), steel,
				CityBlocks.Code.STEEL, T0)
		# Stair to the next landing, alternating direction.
		var dir := 1.0 if k % 2 == 0 else -1.0
		var mid := c + ax * dir * 0.3 + Vector3(0, y + STOREY * 0.5, 0) + nrm * 0.15
		var run := Vector2(2.6, STOREY)
		var ang := atan2(run.y, run.x) * dir
		var basis := Basis(nrm, ang if side % 2 == 0 else -ang)
		b.add(frame * Transform3D(basis * Basis.from_scale(_side_size(side, run.length(), 0.7) + Vector3(0, 0.1, 0)), mid), _jit(steel, 0.9),
			CityBlocks.Code.RUST if k % 3 == 2 else CityBlocks.Code.STEEL, T1)
		y += STOREY
		k += 1


func _balconies(b: CityBlocks, frame: Transform3D, w: float, d: float, top: float, base: Vector3) -> void:
	var side := (int(_h(base, 30) * 4.0) + 1) % 4
	var along := w if side < 2 else d
	var out := (d if side < 2 else w) * 0.5
	var nb := floori((along - 1.0) / 3.0)
	var margin := (along - nb * 3.0) * 0.5
	var nrm := _side_normal(side)
	var y := 1.0 + 4.5 + STOREY
	var row := 0
	while y < top - 2.0:
		for k in nb:
			if _h(base + Vector3(k, row, side), 32) > 0.22:
				continue
			var u := -along * 0.5 + margin + 3.0 * (k + 0.5)
			var c := _side(side, u, out + 0.55)
			_bx(b, frame, c + Vector3(0, y, 0), _side_size(side, 2.2, 1.1) + Vector3(0, 0.2, 0), CONCRETE_DARK.lerp(CONCRETE, 0.5),
				CityBlocks.Code.CONCRETE, T1)
			_bx(b, frame, c + nrm * 0.5 + Vector3(0, y + 0.55, 0), _side_size(side, 2.2, 0.08) + Vector3(0, 0.9, 0), STEEL,
				CityBlocks.Code.STEEL, T1)
		y += STOREY
		row += 1


## AC units, vents, an antenna or two on the roof.
func _roof_clutter(b: CityBlocks, frame: Transform3D, w: float, d: float, y: float, base: Vector3) -> void:
	var n := 2 + int(_h(base, 40) * 4.0)
	for k in n:
		var p := Vector3((_h(base + Vector3(k, 0, 0), 41) - 0.5) * (w - 4.0), y, (_h(base + Vector3(0, 0, k), 42) - 0.5) * (d - 4.0))
		var kind := _h(base + Vector3(k, 1, 0), 43)
		if kind < 0.6:
			_bx(b, frame, p + Vector3(0, 0.6, 0), Vector3(1.8, 1.2, 1.2), Color("#6a6c70"), CityBlocks.Code.STEEL, T1)
			_bx(b, frame, p + Vector3(0, 1.22, 0), Vector3(0.9, 0.06, 0.9), Color("#1a1b1e"), CityBlocks.Code.STEEL, T1)
		elif kind < 0.85:
			_bx(b, frame, p + Vector3(0, 0.9, 0), Vector3(0.7, 1.8, 0.7), Color("#55575c"), CityBlocks.Code.STEEL, T1)
			_bx(b, frame, p + Vector3(0, 1.9, 0), Vector3(1.0, 0.2, 1.0), Color("#45474c"), CityBlocks.Code.STEEL, T1)
		else:
			var h := 4.0 + 6.0 * _h(base + Vector3(k, 2, 0), 44)
			_bx(b, frame, p + Vector3(0, h * 0.5, 0), Vector3(0.09, h, 0.09), STEEL, CityBlocks.Code.STEEL, T0)
			_bx(b, frame, p + Vector3(0, h * 0.8, 0), Vector3(1.4, 0.05, 0.05), STEEL, CityBlocks.Code.STEEL, T0)


## A water tower on stilts (the sim's 7 x 9 x 7 m slot): wooden staves, a
## stepped cone roof, steel legs and the Split Bolt stencil as a pale band.
func _water_tower(b: CityBlocks, frame: Transform3D, near: bool) -> void:
	var wood := Color("#5a4a3c")
	if not near:
		_bx(b, frame, Vector3(0, 6.0, 0), Vector3(5.0, 5.0, 5.0), wood, CityBlocks.Code.WOOD, T2)
		_bx(b, frame, Vector3(0, 1.75, 0), Vector3(4.0, 3.5, 4.0), STEEL, CityBlocks.Code.STEEL, T2, 0b111100)
		return
	for s in 8:
		var a := s * TAU / 8.0
		var bs := Basis(Vector3.UP, a)
		b.add(frame * Transform3D(bs * Basis.from_scale(Vector3(2.0, 4.6, 0.3)), bs * Vector3(0, 0, 2.3) + Vector3(0, 6.0, 0)),
			_jit(wood, 0.9 + 0.15 * float(s % 3) / 2.0), CityBlocks.Code.WOOD, T1)
	_bx(b, frame, Vector3(0, 6.0, 0), Vector3(4.5, 4.4, 4.5), _jit(wood, 0.7), CityBlocks.Code.WOOD, T1)
	for r in 3:
		_bx(b, frame, Vector3(0, 4.4 + r * 1.6, 0), Vector3(5.1, 0.1, 5.1), RUST, CityBlocks.Code.RUST, T1)
	for k in 3:
		var s := 4.4 - k * 1.4
		_bx(b, frame, Vector3(0, 8.45 + k * 0.4, 0), Vector3(s, 0.4, s), _jit(STEEL, 0.9), CityBlocks.Code.STEEL, T1)
	for lx in [-1.6, 1.6]:
		for lz in [-1.6, 1.6]:
			_bx(b, frame, Vector3(lx, 1.9, lz), Vector3(0.22, 3.8, 0.22), STEEL, CityBlocks.Code.STEEL, T1)
	_bx(b, frame, Vector3(0, 1.9, 1.6), Vector3(3.2, 0.12, 0.12), STEEL, CityBlocks.Code.STEEL, T1)
	_bx(b, frame, Vector3(0, 1.9, -1.6), Vector3(3.2, 0.12, 0.12), STEEL, CityBlocks.Code.STEEL, T1)
	# Split Bolt stencil: a pale hex patch with the bolt as darker cells.
	_bx(b, frame, Vector3(0, 6.1, 2.46), Vector3(1.4, 1.4, 0.04), Color("#8a8478"), CityBlocks.Code.PAINT, T0)
	_bx(b, frame, Vector3(0.1, 6.3, 2.49), Vector3(0.18, 0.8, 0.03), Color("#3a3430"), CityBlocks.Code.PAINT, T0)
	_bx(b, frame, Vector3(-0.2, 5.8, 2.49), Vector3(0.5, 0.15, 0.03), Color("#3a3430"), CityBlocks.Code.PAINT, T0)
	_bx(b, frame, Vector3(0.3, 5.8, 2.49), Vector3(0.4, 0.15, 0.03), Color("#3a3430"), CityBlocks.Code.PAINT, T0)


# ---------------------------------------------------------------- towers

func _towers() -> void:
	for nm: String in towers:
		var xf: Transform3D = towers[nm]
		var size := xf.basis.get_scale()
		var base := xf.origin - xf.basis * Vector3(0, 0.5, 0)
		var frame := Transform3D(Basis(), base)
		for near in [true, false]:
			var b := _near_blocks(base) if near else _far_blocks(base)
			b.base_y = base.y
			match nm:
				"Spire Tower": _spire(b, frame, size, base, near)
				"Signal Tower": _signal(b, frame, size, base, near)
				_: _old_tower(b, frame, size, base, near)


## The Spire: stacked setbacks to a stepped needle with a magenta beacon.
func _spire(b: CityBlocks, frame: Transform3D, size: Vector3, base: Vector3, near: bool) -> void:
	var w := size.x
	var top := size.y
	var col := Color("#4e525e")
	var tiers := [[0.0, 0.55, w], [0.55, 0.8, w - 5.6], [0.8, 1.0, w - 11.2]]
	for t: Array in tiers:
		var y0: float = top * float(t[0])
		var y1: float = top * float(t[1])
		var tw: float = t[2]
		_bx(b, frame, Vector3(0, (y0 + y1) * 0.5, 0), Vector3(tw, y1 - y0, tw), col, CityBlocks.Code.FACADE, T2, CityBlocks.ALL, 0.31)
		_bx(b, frame, Vector3(0, y1 - 0.5, 0), Vector3(tw + 1.4, 1.0, tw + 1.4), CONCRETE_DARK, CityBlocks.Code.CONCRETE, T2)
		# Corner piers: vertical fins at each corner.
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				_bx(b, frame, Vector3(sx * tw * 0.5, (y0 + y1) * 0.5, sz * tw * 0.5), Vector3(1.4, y1 - y0, 1.4), CONCRETE_DARK.lerp(col, 0.5),
					CityBlocks.Code.CONCRETE, T2)
	# Needle: stacked shrinking blocks, then a thin mast.
	var y := top
	var s := w - 13.0
	while s > 1.0:
		_bx(b, frame, Vector3(0, y + 2.0, 0), Vector3(s, 4.0, s), col.darkened(0.1), CityBlocks.Code.STEEL, T2)
		y += 4.0
		s *= 0.7
	_bx(b, frame, Vector3(0, y + 9.0, 0), Vector3(0.7, 18.0, 0.7), STEEL, CityBlocks.Code.STEEL, T2)
	_bx(b, frame, Vector3(0, y + 18.6, 0), Vector3(1.4, 1.4, 1.4), MAGENTA, CityBlocks.Code.BEACON, T2)
	for k in 3:
		_bx(b, frame, Vector3(0, y + 4.0 + k * 4.5, 0), Vector3(1.1, 0.35, 1.1), MAGENTA, CityBlocks.Code.BEACON, T2)
	magenta_spots.append(base + Vector3(0, y + 18.6, 0))
	stats["spire_top"] = base.y + y + 19.3
	if near:
		_shop_fronts(b, frame, w, w, base)


## Signal Tower: a plain slab tower crowned by a lattice radio mast with a white strobe.
func _signal(b: CityBlocks, frame: Transform3D, size: Vector3, base: Vector3, near: bool) -> void:
	var w := size.x
	var top := size.y
	var col := Color("#575a62")
	_bx(b, frame, Vector3(0, top * 0.5, 0), Vector3(w, top, w), col, CityBlocks.Code.FACADE, T2, CityBlocks.ALL, 0.47)
	for k in range(1, int(top / 21.0)):
		_bx(b, frame, Vector3(0, k * 21.0, 0), Vector3(w + 0.7, 0.7, w + 0.7), CONCRETE_DARK, CityBlocks.Code.CONCRETE, T2)
	_cornice(b, frame, w, w, top, CONCRETE_DARK, near)
	# Lattice mast: four legs tapering, braced every 3 m (horizontal and X).
	var mh := 46.0
	var legs := 12
	for i in legs:
		var y0 := top + i * mh / legs
		var y1 := y0 + mh / legs
		var r0 := lerpf(5.0, 0.8, float(i) / legs)
		var r1 := lerpf(5.0, 0.8, float(i + 1) / legs)
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				_bx(b, frame, Vector3(sx * (r0 + r1) * 0.5, (y0 + y1) * 0.5, sz * (r0 + r1) * 0.5), Vector3(0.3, y1 - y0, 0.3), STEEL,
					CityBlocks.Code.STEEL, T1 if near else T2)
		if near or i % 2 == 0:
			for f in 4:
				var bs := Basis(Vector3.UP, f * PI * 0.5)
				_bx(b, frame * Transform3D(bs, Vector3.ZERO), Vector3(0, y1, r1), Vector3(2.0 * r1, 0.18, 0.18), STEEL, CityBlocks.Code.STEEL, T1)
				if near:
					var diag := Vector2(2.0 * r0, y1 - y0)
					var xb := Basis(Vector3.BACK, atan2(diag.y, diag.x) * (1.0 if i % 2 == 0 else -1.0))
					b.add(frame * Transform3D(bs, Vector3.ZERO) * Transform3D(xb * Basis.from_scale(Vector3(diag.length(), 0.12, 0.12)),
						Vector3(0, (y0 + y1) * 0.5, (r0 + r1) * 0.5)), STEEL, CityBlocks.Code.STEEL, T1)
	_bx(b, frame, Vector3(0, top + mh + 1.0, 0), Vector3(1.0, 1.0, 1.0), Color.WHITE, CityBlocks.Code.STROBE, T1)
	# Dish antennas on the roof.
	_bx(b, frame, Vector3(6, top + 2.0, 6), Vector3(2.4, 2.4, 0.4), Color("#7a7c80"), CityBlocks.Code.STEEL, T1)
	stats["mast_top"] = base.y + top + mh + 1.5
	if near:
		_shop_fronts(b, frame, w, w, base)


## Old Tower: laid stone blocks, a stepped crown, a warm clock face on all
## four sides, stopped at ten to four with its minute hand missing on the
## street face.
func _old_tower(b: CityBlocks, frame: Transform3D, size: Vector3, base: Vector3, near: bool) -> void:
	var w := size.x
	var top := size.y
	var shaft := top - 26.0
	_bx(b, frame, Vector3(0, shaft * 0.5, 0), Vector3(w - 4.0, shaft, w - 4.0), STONE, CityBlocks.Code.STONE, T2, CityBlocks.ALL, 0.71)
	# Plinth and string courses.
	_bx(b, frame, Vector3(0, 4.0, 0), Vector3(w, 8.0, w), _jit(STONE, 0.85), CityBlocks.Code.STONE, T2)
	var y := 20.0
	while y < shaft:
		_bx(b, frame, Vector3(0, y, 0), Vector3(w - 3.3, 0.7, w - 3.3), _jit(STONE, 1.1), CityBlocks.Code.STONE, T2)
		y += 14.0
	# Buttresses at the corners.
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_bx(b, frame, Vector3(sx * (w * 0.5 - 2.5), shaft * 0.5, sz * (w * 0.5 - 2.5)), Vector3(3.0, shaft, 3.0), _jit(STONE, 0.92),
				CityBlocks.Code.STONE, T2)
	# Clock stage.
	var cw := w - 2.0
	_bx(b, frame, Vector3(0, shaft + 6.0, 0), Vector3(cw, 12.0, cw), _jit(STONE, 1.05), CityBlocks.Code.STONE, T2)
	for side in 4:
		var nrm := _side_normal(side)
		var ax := _side_axis(side) * (1.0 if side % 2 == 0 else -1.0)
		var c := nrm * (cw * 0.5 + 0.05) + Vector3(0, shaft + 6.0, 0)
		# Stepped disc of 35 cm rows, radius 4.2 m.
		var r := 4.2
		var rows := int(r * 2.0 / T2)
		for row in rows:
			var yy := -r + (row + 0.5) * T2
			var half := sqrt(maxf(r * r - yy * yy, 0.0))
			half = floorf(half / T2) * T2
			if half <= 0.0:
				continue
			_bx(b, frame, c + Vector3(0, yy, 0), _side_size(side, half * 2.0, 0.12) + Vector3(0, T2, 0), WINDOW, CityBlocks.Code.WARM_GLOW, T2)
		# Rim and hour marks.
		for m in 12:
			var a := m * TAU / 12.0
			var mp := c + nrm * 0.1 + ax * sin(a) * 3.6 + Vector3(0, cos(a) * 3.6, 0)
			_bx(b, frame, mp, _side_size(side, 0.35, 0.08) + Vector3(0, 0.6 if m % 3 == 0 else 0.35, 0), Color("#2a2420"), CityBlocks.Code.STEEL, T0)
		# Hands: hour at ~3:50, minute at 50 (missing on side 0).
		var ha := deg_to_rad(115.0)
		var hc := c + nrm * 0.16 + (ax * sin(ha) + Vector3(0, cos(ha), 0)) * 1.1
		var hb := Basis(nrm, -ha if side % 2 == 0 else ha)
		b.add(frame * Transform3D(hb * Basis.from_scale(_side_size(side, 0.3, 0.08) + Vector3(0, 2.2, 0)), hc), Color("#1e1a18"),
			CityBlocks.Code.STEEL, T0)
		if side != 0:
			var ma := deg_to_rad(300.0)
			var mc := c + nrm * 0.18 + (ax * sin(ma) + Vector3(0, cos(ma), 0)) * 1.6
			var mb := Basis(nrm, -ma if side % 2 == 0 else ma)
			b.add(frame * Transform3D(mb * Basis.from_scale(_side_size(side, 0.22, 0.08) + Vector3(0, 3.2, 0)), mc), Color("#1e1a18"),
				CityBlocks.Code.STEEL, T0)
		_bx(b, frame, c + nrm * 0.12, _side_size(side, 9.4, 0.06) + Vector3(0, 0.5, 0), _jit(STONE, 0.7), CityBlocks.Code.STONE, T2)
	# Stepped crown: three shrinking stages and a pyramid of blocks.
	var cy := shaft + 12.0
	var s := cw + 1.0
	_bx(b, frame, Vector3(0, cy + 0.4, 0), Vector3(s, 0.8, s), _jit(STONE, 0.8), CityBlocks.Code.STONE, T2)
	cy += 0.8
	for k in 7:
		s -= 2.6
		if s < 1.0:
			break
		_bx(b, frame, Vector3(0, cy + 0.9, 0), Vector3(s, 1.8, s), Color("#4a4440") if k % 2 == 0 else _jit(STONE, 0.75), CityBlocks.Code.STONE, T2)
		cy += 1.8
	_bx(b, frame, Vector3(0, cy + 3.0, 0), Vector3(0.3, 6.0, 0.3), RUST, CityBlocks.Code.RUST, T1)
	stats["clock_centre"] = base + Vector3(0, shaft + 6.0, cw * 0.5)
	if near:
		_shop_fronts(b, frame, w, w, base)


# ---------------------------------------------------------------- rubble

## Collapsed blocks: heaps of concrete slabs at angles with rebar, in the
## sim's rubble slots (each a box; the heap fills its footprint).
func _rubble() -> void:
	for xf in rubble:
		var size := xf.basis.get_scale()
		var base := xf.origin - xf.basis * Vector3(0, 0.5, 0)
		var rot := xf.basis.orthonormalized()
		var frame := Transform3D(rot, base)
		for near in [true, false]:
			var b := _near_blocks(base) if near else _far_blocks(base)
			var n := 9 if near else 3
			for k in n:
				var hk := _h(base + Vector3(k, 0, 0), 50)
				var sz := Vector3(size.x * (0.3 + 0.5 * hk), maxf(0.35, size.y * (0.15 + 0.3 * _h(base + Vector3(0, k, 0), 51))),
					size.z * (0.3 + 0.5 * _h(base + Vector3(0, 0, k), 52)))
				var p := Vector3((_h(base + Vector3(k, 1, 0), 53) - 0.5) * size.x * 0.6, sz.y * 0.5 + k * size.y * 0.06,
					(_h(base + Vector3(k, 2, 0), 54) - 0.5) * size.z * 0.6)
				var tilt := Basis.from_euler(Vector3((hk - 0.5) * 0.6, hk * TAU, (_h(base + Vector3(k, 3, 0), 55) - 0.5) * 0.6))
				b.add(frame * Transform3D(tilt * Basis.from_scale(sz), p), _jit(CONCRETE, 0.8 + 0.3 * hk), CityBlocks.Code.CONCRETE, T2)
				if near and hk < 0.5:
					for r in 3:
						var rp := p + tilt * Vector3((r - 1) * sz.x * 0.25, sz.y * 0.5, sz.z * 0.5)
						b.add(frame * Transform3D(tilt * Basis(Vector3.RIGHT, 0.5) * Basis.from_scale(Vector3(0.05, 1.4, 0.05)), rp), RUST,
							CityBlocks.Code.RUST, T0)


# ---------------------------------------------------------------- neon

## The sim's signs, restyled: vertical blades project from the facade, bands
## sit over shop fronts; tube outlines and made-up glyphs on a dark backing.
## One accent: about a third magenta, the rest warm white, a few dead.
func _signs() -> void:
	var lit := 0
	var all := signs.duplicate()
	var authored := _authored_signs()
	all.append_array(authored)
	for xf: Transform3D in all:
		var size := xf.basis.get_scale()
		var rot := xf.basis.orthonormalized()
		var c := xf.origin
		var hk := _h(c, 60)
		var magenta := hk < 0.36 or xf in authored
		var dead := hk > 0.93 and not xf in authored
		var col := MAGENTA if magenta else WARM_WHITE
		var code := CityBlocks.Code.PAINT if dead else (CityBlocks.Code.NEON if magenta else CityBlocks.Code.NEON_WHITE)
		if dead:
			col = Color("#5a5458")
		var b := _near_blocks(c)
		var blade := size.y > size.x * 2.0
		if blade:
			# Blade: projects out of the facade along the sim box's x.
			var h := minf(size.y, 12.0)
			var out_dir := rot * Vector3.RIGHT
			var frame := Transform3D(rot, c + out_dir * 0.9)
			_bx(b, frame, Vector3.ZERO, Vector3(1.6, h, 0.3), Color("#16161a"), CityBlocks.Code.BACKING, T1)
			_bx(b, frame, Vector3(-0.9, h * 0.3, 0), Vector3(0.3, 0.15, 0.15), STEEL, CityBlocks.Code.STEEL, T1)
			_bx(b, frame, Vector3(-0.9, -h * 0.3, 0), Vector3(0.3, 0.15, 0.15), STEEL, CityBlocks.Code.STEEL, T1)
			for f in [-1.0, 1.0]:
				_tubes(b, frame, Vector3(0, 0, f * 0.18), Vector2(1.6, h), col, code, c, Vector3.RIGHT, Vector3.UP)
			_bx(_far_blocks(c), frame, Vector3.ZERO, Vector3(1.6, h, 0.36), col if not dead else Color("#16161a"),
				code if not dead else CityBlocks.Code.BACKING, T2)
			if not dead:
				_streak(c + out_dir * 0.9, out_dir, h, col, magenta)
		else:
			# Band over a shop front, flat on the facade.
			var frame := Transform3D(rot, c)
			var l := size.x
			_bx(b, frame, Vector3.ZERO, Vector3(l, 1.0, 0.3), Color("#16161a"), CityBlocks.Code.BACKING, T1)
			_tubes(b, frame, Vector3(0, 0, 0.18), Vector2(l, 1.0), col, code, c, Vector3.RIGHT, Vector3.UP)
			_bx(_far_blocks(c), frame, Vector3(0, 0, 0.1), Vector3(l, 0.6, 0.2), col if not dead else Color("#16161a"),
				code if not dead else CityBlocks.Code.BACKING, T2)
			if not dead:
				_streak(c, rot * Vector3.BACK, 2.0, col, magenta)
		if magenta and not dead:
			magenta_spots.append(c)
		if not dead:
			lit += 1
	stats["signs_lit"] = lit


## Look-dev additions on top of the sim's signs: a magenta blade on the corner
## building of the key street (x = -78), so the key image has its neon and
## reflection. Placed on the real facade, 5-14 m up, off the street.
func _authored_signs() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for spot: Vector2 in [Vector2(-96.0, 436.0)]:
		for xf in buildings:
			var sz := xf.basis.get_scale()
			if absf(xf.origin.x - spot.x) < sz.x * 0.5 and absf(xf.origin.z - spot.y) < sz.z * 0.5 \
					and xf.basis.get_euler().length() < 0.001:
				# On the east face, projecting into the street.
				var east := xf.origin.x + sz.x * 0.5 + 0.3
				var g := ground_at(east, spot.y)
				out.append(PropKit.placed(Vector3(east, g + 5.5, spot.y), Vector3(0.6, 9.0, 2.0), 0.0))
				break
	return out


## Tube outline plus glyph strokes on a sign face (plane spanned by ax, ay).
func _tubes(b: CityBlocks, frame: Transform3D, centre: Vector3, extent: Vector2, col: Color, code: int, key: Vector3,
		ax: Vector3, ay: Vector3) -> void:
	var t := 0.06
	var hx := extent.x * 0.5 - 0.12
	var hy := extent.y * 0.5 - 0.12
	var depth := Vector3(0, 0, t)
	_bx(b, frame, centre + ay * hy, ax * hx * 2.0 + ay * t + depth, col, code, T0)
	_bx(b, frame, centre - ay * hy, ax * hx * 2.0 + ay * t + depth, col, code, T0)
	_bx(b, frame, centre + ax * hx, ay * hy * 2.0 + ax * t + depth, col, code, T0)
	_bx(b, frame, centre - ax * hx, ay * hy * 2.0 + ax * t + depth, col, code, T0)
	# Glyphs in squares along the long axis: 2-3 strokes each from a hashed set.
	var vertical := extent.y > extent.x
	var g := minf(extent.x, extent.y) - 0.5
	var count := int((maxf(extent.x, extent.y) - 0.6) / (g + 0.2))
	for i in count:
		var off := (-(count - 1) * 0.5 + i) * (g + 0.2)
		var gc := centre + (ay * off if vertical else ax * off)
		var bits := int(_h(key + Vector3(i, 0, 0), 61) * 255.0)
		var s := g * 0.5
		var strokes := [
			[Vector3(0, s, 0), Vector3(g, t, 0)], [Vector3(0, 0, 0), Vector3(g * 0.8, t, 0)], [Vector3(0, -s, 0), Vector3(g, t, 0)],
			[Vector3(-s, 0, 0), Vector3(t, g, 0)], [Vector3(s, 0, 0), Vector3(t, g, 0)], [Vector3(0, s * 0.5, 0), Vector3(t, g * 0.5, 0)],
			[Vector3(-s * 0.5, -s * 0.5, 0), Vector3(t, g * 0.5, 0)], [Vector3(s * 0.4, s * 0.1, 0), Vector3(g * 0.5, t, 0)],
		]
		var drawn := 0
		for k in strokes.size():
			if bits & (1 << k) == 0 or drawn >= 3:
				continue
			var st: Array = strokes[k]
			var p: Vector3 = st[0]
			var e: Vector3 = st[1]
			_bx(b, frame, gc + ax * p.x + ay * p.y, ax * e.x + ay * e.y + depth, col, code, T0)
			drawn += 1


## A reflection streak on the wet street under a sign: a long thin quad
## running out from the facade (city_streak.gdshader breaks it up).
func _streak(at: Vector3, out_dir: Vector3, h: float, col: Color, magenta: bool) -> void:
	var flat := Vector3(out_dir.x, 0, out_dir.z).normalized()
	var g := ground_at(at.x, at.z)
	var length := 5.0 + h * 0.6
	var start := at + flat * 0.4
	var mid := Vector3(start.x, g + 0.03, start.z) + flat * length * 0.5
	var basis := Basis(flat.cross(Vector3.UP).normalized(), Vector3.UP, -flat)
	var width := (0.9 if magenta else 0.6) * (2.2 if h > 4.0 else 1.0)
	_streaks.add(Transform3D(basis.orthonormalized() * Basis.from_scale(Vector3(width, 0.001, length)), mid),
		Color(col.r, col.g, col.b) * (1.0 if magenta else 0.35), CityBlocks.Code.NEON, 1.0, 0b000100, _h(at, 62))


# ---------------------------------------------------------------- cars

## Six wrecked-car variants (muted bodies, smashed screens, flat tyres), boxes
## at T1, placed with the sim's transforms; two LOD tiers.
func _cars() -> void:
	var lists: Array = [[], [], [], [], [], []]
	for xf in cars:
		var v := int(_h(xf.origin, 70) * 6.0) % 6
		var base := xf.origin - xf.basis * Vector3(0, 0.5, 0)
		var rot := xf.basis.orthonormalized()
		(lists[v] as Array).append(Transform3D(rot, base))
	var tris := 0
	for v in 6:
		var near := CityBlocks.new()
		var far := CityBlocks.new()
		_car(near, v, true)
		_car(far, v, false)
		var nm := near.commit()
		var fm := far.commit()
		nm.surface_set_material(0, block_mat)
		fm.surface_set_material(0, block_mat)
		var list: Array[Transform3D] = []
		list.assign(lists[v])
		VoxelProp.place(self, "Cars%d" % v, [nm, fm] as Array[ArrayMesh], [70.0, 0.0], list, 1)
		tris += near.triangles() * list.size()
	_tris["cars_near_all"] = tris


func _car(b: CityBlocks, v: int, near: bool) -> void:
	var body := CAR_COLOURS[v]
	var f := Transform3D()
	var sedan := v < 4
	var len := 4.6
	var hb := 0.75
	_bx(b, f, Vector3(0, 0.25 + hb * 0.5, 0), Vector3(len, hb, 1.9), body, CityBlocks.Code.STEEL, T1, CityBlocks.NO_BOTTOM, v)
	var cab_l := 2.3 if sedan else 3.4
	var cab_x := -0.2 if sedan else -0.5
	var roof_y := 0.25 + hb + 0.62
	if v == 5:
		# Flipped on its side was too much clutter: this one is crushed flat.
		roof_y = 0.25 + hb + 0.3
	_bx(b, f, Vector3(cab_x, (0.25 + hb + roof_y) * 0.5, 0), Vector3(cab_l, roof_y - 0.25 - hb, 1.62),
		Color("#141820"), CityBlocks.Code.GLASS, T1)
	_bx(b, f, Vector3(cab_x, roof_y + 0.05, 0), Vector3(cab_l - 0.3, 0.1, 1.66), body * 0.92, CityBlocks.Code.STEEL, T1)
	if not near:
		# Same extents as the near tier (wheels to the ground, bumpers), so both
		# tiers switch at the same distance.
		_bx(b, f, Vector3(0, 0.15, 0), Vector3(len + 0.2, 0.3, 1.9), Color("#141416"), CityBlocks.Code.RUBBER, T1, CityBlocks.NO_BOTTOM)
		return
	# Pillars.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_bx(b, f, Vector3(cab_x + sx * (cab_l * 0.5 - 0.1), (0.25 + hb + roof_y) * 0.5, sz * 0.8), Vector3(0.12, roof_y - 0.25 - hb, 0.08),
				body * 0.85, CityBlocks.Code.STEEL, T1)
	# Smashed windscreen: a pale crazed patch.
	if v % 2 == 0:
		_bx(b, f, Vector3(cab_x + cab_l * 0.5 + 0.01, (0.25 + hb + roof_y) * 0.5, 0.2), Vector3(0.04, 0.4, 0.7), Color("#7a8490"),
			CityBlocks.Code.GLASS, T0)
	# Wheels (one flat), bumpers, lamps (dead amber), a rust patch.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var flat := (v + int(sx) + int(sz) * 2) % 5 == 0
			_bx(b, f, Vector3(sx * 1.45, 0.33 if not flat else 0.22, sz * 0.86), Vector3(0.7, 0.66 if not flat else 0.44, 0.26),
				Color("#141416"), CityBlocks.Code.RUBBER, T1)
	_bx(b, f, Vector3(len * 0.5 + 0.04, 0.45, 0), Vector3(0.12, 0.22, 1.9), Color("#2a2a2e"), CityBlocks.Code.STEEL, T1)
	_bx(b, f, Vector3(-len * 0.5 - 0.04, 0.45, 0), Vector3(0.12, 0.22, 1.9), Color("#2a2a2e"), CityBlocks.Code.STEEL, T1)
	for sz in [-0.7, 0.7]:
		_bx(b, f, Vector3(len * 0.5 + 0.01, 0.75, sz), Vector3(0.04, 0.16, 0.3), Color("#c8c4b4"), CityBlocks.Code.GLASS, T0)
		_bx(b, f, Vector3(-len * 0.5 - 0.01, 0.75, sz), Vector3(0.04, 0.14, 0.3), Color("#5a2a28"), CityBlocks.Code.GLASS, T0)
	_bx(b, f, Vector3(0.9, 0.6, 0.955), Vector3(0.8, 0.3, 0.02), RUST, CityBlocks.Code.RUST, T1)


# ---------------------------------------------------------------- street props

## Sodium lamps (most dead) at the corners, bins, cables strung across streets.
func _street_props() -> void:
	var c := zone.centre
	var lamps := 0
	for bz in range(floori((c.y - 300.0) / TILE), ceili((c.y + 300.0) / TILE)):
		for bx in range(floori((c.x - 260.0) / TILE), ceili((c.x + 260.0) / TILE)):
			var corner := Vector3(bx * TILE + 11.0, 0, bz * TILE + 11.0)
			var cw := Vector2(corner.x, corner.z)
			if absf(cw.y - _canal_z(cw.x)) < 24.0:
				continue
			if layout.weights_at(cw.x, cw.y)[layout.index_of(zone.id)] < 0.85:
				continue
			var g := ground_at(cw.x, cw.y)
			var hk := _h(corner, 80)
			var b := _near_blocks(corner)
			var frame := Transform3D(Basis(), Vector3(cw.x, g, cw.y))
			if hk < 0.7:
				var on := hk < 0.18
				_bx(b, frame, Vector3(0, 3.5, 0), Vector3(0.16, 7.0, 0.16), STEEL, CityBlocks.Code.STEEL, T1)
				_bx(b, frame, Vector3(0.8, 6.95, 0.8), Vector3(1.9, 0.12, 0.12), STEEL, CityBlocks.Code.STEEL, T1)
				b.add(frame * Transform3D(Basis(Vector3.UP, PI * 0.25) * Basis.from_scale(Vector3(0.12, 0.12, 2.2)), Vector3(0.75, 6.95, 0.75)),
					STEEL, CityBlocks.Code.STEEL, T1)
				_bx(b, frame, Vector3(1.5, 6.8, 1.5), Vector3(0.6, 0.16, 0.36), SODIUM if on else Color("#3a3630"),
					CityBlocks.Code.SODIUM if on else CityBlocks.Code.GLASS, T0)
				lamps += 1
			if hk > 0.55:
				# A bin, tipped over on some.
				var tip := hk > 0.8
				var bb := Basis(Vector3.BACK, PI * 0.5) if tip else Basis()
				b.add(frame * Transform3D(bb * Basis.from_scale(Vector3(0.6, 0.9, 0.6)), Vector3(-1.2, 0.3 if tip else 0.45, 1.6)),
					Color("#3c4440"), CityBlocks.Code.STEEL, T1)
			if hk < 0.35:
				# Cables strung across the street to the next block.
				var a := Vector3(cw.x, g + 9.0, cw.y + 2.0)
				var e := a + Vector3(14.0, 0.4, 0)
				_cable(b, a, e, 0.9)
	stats["lamps"] = lamps


## A sagging cable from a to e as short T0 boxes.
func _cable(b: CityBlocks, a: Vector3, e: Vector3, sag: float) -> void:
	var n := 10
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := a.lerp(e, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		var mid := (prev + p) * 0.5
		var dir := p - prev
		var basis := Basis.looking_at(dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.RIGHT)
		b.add(Transform3D(basis * Basis.from_scale(Vector3(0.04, 0.04, dir.length())), mid), Color("#141416"), CityBlocks.Code.RUBBER, T0)
		prev = p


func _canal_z(x: float) -> float:
	return zone.centre.y + 20.0 + 25.0 * sin((x - zone.centre.x) * 0.012)


# ---------------------------------------------------------------- story props

## The sheet's storytelling props, at authored spots off the street centres:
## the noodle bar, the half-sunk bus, laundry lines, the stopped clock (in
## _old_tower), the rooftop garden and the gutter pouring into a puddle.
var story := {}


func _story_props() -> void:
	_noodle_bar(Vector3(-62.4, 0, 413.0))
	_bus(Vector2(-74.0, _canal_z(-74.0)))
	_laundry()
	_rooftop_garden()
	_gutter()
	_boats()


func _noodle_bar(at: Vector3) -> void:
	# On the plaza's west edge, facing the spawn street.
	var g := ground_at(at.x, at.z)
	var f := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(at.x, g, at.z))
	var b := _near_blocks(at)
	b.base_y = g
	# Stall: a counter, back wall, awning, sign.
	_bx(b, f, Vector3(0, 0.5, 0), Vector3(3.6, 1.0, 0.7), Color("#4a3c32"), CityBlocks.Code.WOOD, T1)
	_bx(b, f, Vector3(0, 1.03, 0), Vector3(3.8, 0.06, 0.9), Color("#5c4a3a"), CityBlocks.Code.WOOD, T1)
	_bx(b, f, Vector3(0, 1.6, -1.4), Vector3(3.8, 3.2, 0.2), Color("#3a3634"), CityBlocks.Code.CONCRETE, T1)
	_bx(b, f, Vector3(0, 1.6, -1.28), Vector3(3.2, 1.0, 0.04), WINDOW, CityBlocks.Code.SHOP, T1)
	b.add(f * Transform3D(Basis(Vector3.RIGHT, 0.3) * Basis.from_scale(Vector3(4.2, 0.08, 2.2)), Vector3(0, 3.05, -0.4)), Color("#5a2c40"),
		CityBlocks.Code.CLOTH, T1)
	for k in 7:
		_bx(b, f, Vector3(-1.9 + k * 0.63, 2.6, 0.62), Vector3(0.5, 0.35, 0.04), Color("#e9dccb"), CityBlocks.Code.CLOTH, T1)
	# Sign board: magenta tubes, made-up script.
	var sf := f * Transform3D(Basis(), Vector3(0, 3.7, -0.9))
	_bx(b, sf, Vector3.ZERO, Vector3(3.4, 0.9, 0.2), Color("#16161a"), CityBlocks.Code.BACKING, T1)
	_tubes(b, sf, Vector3(0, 0, 0.12), Vector2(3.4, 0.9), MAGENTA, CityBlocks.Code.NEON, at, Vector3.RIGHT, Vector3.UP)
	magenta_spots.append(sf.origin)
	_streak(sf.origin, f.basis * Vector3.BACK, 3.0, MAGENTA, true)
	# Stools (one tipped over), a bowl and chopsticks on the counter.
	for k in 3:
		var sp := Vector3(-1.1 + k * 1.1, 0, 0.9)
		if k == 2:
			b.add(f * Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3(0.32, 0.7, 0.32)), sp + Vector3(0.3, 0.17, 0.4)),
				Color("#6a4a3a"), CityBlocks.Code.WOOD, T0)
		else:
			_bx(b, f, sp + Vector3(0, 0.35, 0), Vector3(0.08, 0.7, 0.08), STEEL, CityBlocks.Code.STEEL, T0)
			_bx(b, f, sp + Vector3(0, 0.72, 0), Vector3(0.36, 0.06, 0.36), Color("#6a4a3a"), CityBlocks.Code.WOOD, T0)
	_bx(b, f, Vector3(0.4, 1.12, 0.1), Vector3(0.2, 0.1, 0.2), Color("#d8d0c4"), CityBlocks.Code.CONCRETE, T0)
	_bx(b, f, Vector3(0.4, 1.155, 0.1), Vector3(0.14, 0.02, 0.14), Color("#8a6040"), CityBlocks.Code.PAINT, T0)
	_bx(b, f, Vector3(0.55, 1.18, 0.1), Vector3(0.02, 0.02, 0.24), Color("#b09060"), CityBlocks.Code.WOOD, T0)
	story["noodle_bar"] = Vector3(at.x, g, at.z)


## A city bus nosed down into a collapsed stretch of the canal embankment, its
## rear still on the street; the destination board still lit.
func _bus(at: Vector2) -> void:
	var top := ground_at(at.x, at.y + 18.5)
	var low := ground_at(at.x, at.y + 11.0)
	var rear := Vector3(at.x, top, at.y + 21.5)
	var nose := Vector3(at.x, low - 0.6, at.y + 10.5)
	var dir := (nose - rear).normalized()
	var mid := (rear + nose) * 0.5 + Vector3.UP * 1.5
	var basis := Basis.looking_at(dir, Vector3.UP)
	var f := Transform3D(basis.rotated(dir, 0.08), mid)
	var b := _near_blocks(mid)
	b.base_y = low
	var len := 11.0
	var body := Color("#6a6050")
	_bx(b, f, Vector3(0, 0, 0), Vector3(2.5, 2.9, len), body, CityBlocks.Code.STEEL, T1)
	_bx(b, f, Vector3(0, -1.0, 0), Vector3(2.52, 0.5, len + 0.02), Color("#4a4438"), CityBlocks.Code.STEEL, T1)
	for side in [-1.0, 1.0]:
		for k in 8:
			_bx(b, f, Vector3(side * 1.26, 0.55, -4.5 + k * 1.25), Vector3(0.04, 1.0, 1.05), Color("#141820") if (k + int(side)) % 4 != 0 else Color("#0a0a0c"),
				CityBlocks.Code.GLASS, T1)
	_bx(b, f, Vector3(0, 0.6, -len * 0.5 - 0.01), Vector3(2.2, 1.3, 0.04), Color("#141820"), CityBlocks.Code.GLASS, T1)
	_bx(b, f, Vector3(0, 1.3, -len * 0.5 - 0.03), Vector3(1.8, 0.32, 0.04), Color("#E8B070"), CityBlocks.Code.WARM_GLOW, T0)
	_bx(b, f, Vector3(0, 1.48, 0), Vector3(2.4, 0.08, len - 0.4), body * 0.9, CityBlocks.Code.STEEL, T1)
	# Broken road slabs around it.
	for k in 4:
		var p := Vector3(at.x - 3.0 + k * 2.2, low + 0.3, at.y + 12.0 + (k % 2) * 2.0)
		b.add(Transform3D(Basis.from_euler(Vector3(0.4 + 0.1 * k, 0.3 * k, 0.2)) * Basis.from_scale(Vector3(2.6, 0.35, 2.0)), p),
			Color("#2e3036"), CityBlocks.Code.CONCRETE, T1)
	story["bus"] = mid


## Laundry lines between balconies on two facing buildings near the spawn street.
func _laundry() -> void:
	var a := Vector3(-90.5, ground_at(-90.5, 384.0) + 9.5, 384.0)
	var e := Vector3(-77.5, a.y + 0.6, 384.0)
	var b := _near_blocks(a)
	for line in 2:
		var o := Vector3(0, line * 2.4, line * 3.0)
		_cable(b, a + o, e + o, 0.5)
		for k in 7:
			var t := (k + 0.8) / 8.6
			var p := (a + o).lerp(e + o, t) + Vector3.DOWN * 0.5 * 4.0 * t * (1.0 - t)
			var cl := [Color("#8a8070"), Color("#5a6470"), Color("#7a5a5a"), Color("#c0b8a8"), Color("#4a5a50")][(k + line) % 5] as Color
			var h := 0.6 + 0.4 * _h(p, 90)
			_bx(b, Transform3D(), p + Vector3(0, -h * 0.5, 0), Vector3(0.7, h, 0.04), cl, CityBlocks.Code.CLOTH, T0)
	story["laundry"] = (a + e) * 0.5


## Someone lived up here: planters, a bench, a tarp on poles, a water drum.
func _rooftop_garden() -> void:
	# The lowest standing building near the spawns.
	var best := Transform3D()
	var best_score := INF
	for xf in buildings:
		var s := xf.basis.get_scale()
		if s.y > 30.0 or s.y < 14.0 or xf.basis.get_euler().length() > 0.001:
			continue
		var d := Vector2(xf.origin.x, xf.origin.z).distance_to(Vector2(-22, 402))
		if d < best_score and d > 40.0:
			best_score = d
			best = xf
	var s := best.basis.get_scale()
	var top := best.origin + Vector3(0, s.y * 0.5, 0)
	var b := _near_blocks(top)
	var f := Transform3D(Basis(), top)
	b.base_y = top.y
	for k in 5:
		var p := Vector3(-s.x * 0.3 + k * s.x * 0.14, 0, s.z * 0.3)
		_bx(b, f, p + Vector3(0, 0.3, 0), Vector3(1.8, 0.6, 0.8), Color("#5a4a3c"), CityBlocks.Code.WOOD, T1)
		_bx(b, f, p + Vector3(0, 0.62, 0), Vector3(1.6, 0.06, 0.6), Color("#3a2c22"), CityBlocks.Code.WOOD, T1)
		for q in 4:
			var hp := _h(p + Vector3(q, 0, 0), 91)
			_bx(b, f, p + Vector3(-0.6 + q * 0.4, 0.62 + (0.15 + hp * 0.25) * 0.5, (hp - 0.5) * 0.2), Vector3(0.22 + hp * 0.12, 0.15 + hp * 0.25, 0.22),
				Color("#3f4a3a") if hp < 0.5 else (Color("#4c5a40") if hp < 0.85 else Color("#6a5a48")), CityBlocks.Code.PLANT, T0)
	# Bench, tarp shelter, drum, a string of dead bulbs.
	_bx(b, f, Vector3(0, 0.45, -2.0), Vector3(2.0, 0.1, 0.5), Color("#5c4a3a"), CityBlocks.Code.WOOD, T1)
	_bx(b, f, Vector3(-0.8, 0.22, -2.0), Vector3(0.1, 0.44, 0.4), STEEL, CityBlocks.Code.STEEL, T1)
	_bx(b, f, Vector3(0.8, 0.22, -2.0), Vector3(0.1, 0.44, 0.4), STEEL, CityBlocks.Code.STEEL, T1)
	for px in [-2.5, 2.5]:
		for pz in [-4.0, -1.0]:
			_bx(b, f, Vector3(px, 1.2, pz), Vector3(0.1, 2.4, 0.1), Color("#5c4a3a"), CityBlocks.Code.WOOD, T1)
	b.add(f * Transform3D(Basis(Vector3.RIGHT, 0.15) * Basis.from_scale(Vector3(5.6, 0.06, 3.6)), Vector3(0, 2.45, -2.5)), Color("#3e5060"),
		CityBlocks.Code.CLOTH, T1)
	_bx(b, f, Vector3(3.4, 0.5, -3.0), Vector3(0.8, 1.0, 0.8), Color("#3a4a5a"), CityBlocks.Code.STEEL, T1)
	_cable(b, top + Vector3(-2.5, 2.3, -1.0), top + Vector3(2.5, 2.3, -1.0), 0.3)
	story["garden"] = top


## A broken roof gutter pouring a column of water into a long street puddle.
func _gutter() -> void:
	var at := Vector3(-55.8, 0, 380.0)
	var g := ground_at(at.x, at.z)
	var b := _near_blocks(at)
	var h := 12.0
	_bx(b, Transform3D(), Vector3(at.x, g + h, at.z), Vector3(0.3, 0.25, 2.0), RUST, CityBlocks.Code.RUST, T0)
	for k in 26:
		var y := g + h - 0.3 - k * 0.45
		var wob := 0.06 * sin(k * 1.7)
		_bx(b, Transform3D(), Vector3(at.x + 0.25 + wob, y, at.z + 0.7), Vector3(0.12, 0.3, 0.12), Color("#9aa6b4"), CityBlocks.Code.WATER, T0)
	# The puddle it feeds: a mirror strip a few mm up.
	_bx(b, Transform3D(), Vector3(at.x + 2.0, g + 0.01, at.z + 0.7), Vector3(4.5, 0.02, 1.6), Color("#20242c"), CityBlocks.Code.WATER, T1,
		0b000100)
	story["gutter"] = Vector3(at.x, g, at.z)


## Canal boats sunk at the moorings: hulls tilted into the water.
func _boats() -> void:
	for k in 3:
		var x := -160.0 + k * 95.0
		var z := _canal_z(x) + (9.0 if k % 2 == 0 else -9.0)
		var g := ground_at(x, z)
		var p := Vector3(x, g + 0.25, z)
		var b := _near_blocks(p)
		var f := Transform3D(Basis.from_euler(Vector3(0.12, 0.1 + k * 0.4, 0.18)), p)
		_bx(b, f, Vector3.ZERO, Vector3(2.2, 1.0, 7.0), Color("#3a4448"), CityBlocks.Code.STEEL, T1)
		_bx(b, f, Vector3(0, 0.55, -1.0), Vector3(1.6, 1.1, 2.4), Color("#4a4440"), CityBlocks.Code.WOOD, T1)
		_bx(b, f, Vector3(0, 0.15, 0), Vector3(2.0, 0.1, 6.6), Color("#1a1e22"), CityBlocks.Code.WATER, T1)


# ---------------------------------------------------------------- weather

## Rain around the camera, the lightning bolt and flash, and four magenta
## lights that follow the nearest magenta signs.
func _weather() -> void:
	for i in 4:
		var l := OmniLight3D.new()
		l.light_color = MAGENTA
		l.light_energy = 2.0
		l.omni_range = 11.0
		l.omni_attenuation = 1.4
		l.shadow_enabled = false
		add_child(l)
		_lights.append(l)
	_flash = DirectionalLight3D.new()
	_flash.name = "Lightning"
	_flash.light_color = Color("#dfe6ff")
	_flash.light_energy = 0.0
	_flash.rotation = Vector3(-1.0, 0.6, 0.0)
	add_child(_flash)
	_bolt = _lightning_bolt()
	_bolt.visible = false
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 9000
	_rain.lifetime = 0.9
	_rain.preprocess = 1.0
	_rain.fixed_fps = 30
	_rain.local_coords = false
	_rain.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 2, 28)
	pm.direction = Vector3(0.18, -1, 0.1)
	pm.spread = 2.0
	pm.initial_velocity_min = 26.0
	pm.initial_velocity_max = 30.0
	pm.gravity = Vector3.ZERO
	_rain.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.018, 0.9)
	var rm := ShaderMaterial.new()
	rm.shader = RAIN_SHADER
	quad.material = rm
	_rain.draw_pass_1 = quad
	add_child(_rain)


## A branching bolt of small glowing blocks high over the skyline.
func _lightning_bolt() -> Node3D:
	var b := CityBlocks.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var start := Vector3(60, 330, 760)
	var branches := [[start, Vector3(0, -1, 0), 26]]
	var made := 0
	while not branches.is_empty() and made < 90:
		var br: Array = branches.pop_back()
		var p: Vector3 = br[0]
		var dir: Vector3 = br[1]
		for i in int(br[2]):
			var step := Vector3(rng.randf_range(-6, 6), -rng.randf_range(5, 9), rng.randf_range(-3, 3)) + dir * 2.0
			var q := p + step
			var mid := (p + q) * 0.5
			var basis := Basis.looking_at(step.normalized(), Vector3.RIGHT)
			b.add(Transform3D(basis * Basis.from_scale(Vector3(0.9, 0.9, step.length())), mid), Color("#e8ecff"), CityBlocks.Code.STROBE, 1.4)
			made += 1
			if rng.randf() < 0.12 and branches.size() < 4:
				branches.append([q, Vector3(rng.randf_range(-1, 1), -0.6, 0), int(br[2]) / 3])
			p = q
	var mi := MeshInstance3D.new()
	mi.name = "Bolt"
	mi.mesh = b.commit()
	var mat := block_mat.duplicate() as ShaderMaterial
	mat.set_shader_parameter("strobe", 1.6)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func animate(t: float) -> void:
	street_mat.set_shader_parameter("clock", t)
	block_mat.set_shader_parameter("beacon", 0.75 + 0.25 * sin(t * 1.6))
	block_mat.set_shader_parameter("strobe", 1.0 if fposmod(t, 1.5) < 0.12 else 0.0)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var cp := cam.global_position
		_rain.global_position = cp + Vector3(0, 14, 0) - cam.global_basis.z * 12.0
		# The four magenta signs nearest the camera light their surroundings.
		var best: Array = []
		for s in magenta_spots:
			var d := s.distance_squared_to(cp)
			if d < 160.0 * 160.0:
				best.append([d, s])
		best.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for i in _lights.size():
			_lights[i].visible = i < best.size()
			if i < best.size():
				# Low over the pavement, so the wet street catches the magenta.
				var sp: Vector3 = best[i][1]
				_lights[i].global_position = Vector3(sp.x, minf(sp.y, ground_at(sp.x, sp.z) + 4.5), sp.z)
	# Lightning: 2-3 frame flashes at fixed times (>= 6 s apart), or forced by the preset.
	var stage := _stage()
	var forced := stage != null and float(stage.current.get("flash", 0.0)) > 0.0
	var k := 1.0 if forced else 0.0
	for ft in _flash_at:
		var dt := t - ft
		if dt >= 0.0 and dt < 0.12:
			k = maxf(k, 1.0 - dt / 0.12 * 0.5)
		elif dt >= 0.2 and dt < 0.27:
			k = maxf(k, 0.6)
	_flash.light_energy = 3.0 * k
	_bolt.visible = k > 0.0
	if stage != null:
		# Moonlight through cloud: a small source. The kit's wide soft-shadow
		# penumbra speckles (PCSS noise) on the city's many small near faces.
		stage.sun.light_angular_distance = 0.25
		var sky: ShaderMaterial = stage.get("_sky_mat")
		var p := stage.current
		if sky != null and not p.is_empty():
			sky.set_shader_parameter("top_color", (p.sky_top as Color).lerp(Color("#8890b0"), k * 0.6))
			sky.set_shader_parameter("horizon_color", (p.sky_horizon as Color).lerp(Color("#c8d0f0"), k * 0.7))
			sky.set_shader_parameter("cloud_color", (p.cloud as Color).lerp(Color("#e0e6ff"), k * 0.8))


func _stage() -> VoxelStage:
	if get_parent() == null:
		return null
	for c in get_parent().get_children():
		if c is VoxelStage:
			return c
	return null


# ---------------------------------------------------------------- presets

## Storm day, after the storm, thunderstorm midnight (hero). The sky stays
## lighter than the buildings; fog and sky are slate, never violet; the rim is
## cool white.
func presets() -> Dictionary:
	var p := VoxelStage.PRESETS.duplicate(true)
	p.night = {
		"sky_top": Color("#14161E"), "sky_horizon": Color("#535872"), "sky_below": Color("#3A3E50"),
		"cloud": Color("#5e6278"), "cloud_shadow": Color("#262833"), "cloud_cover": 0.78,
		"sun_dir": Vector3(0.36, -0.78, -0.52), "sun_color": Color("#9ca8d8"), "sun_energy": 0.35,
		"sun_size": 0.0, "moon": false, "stars": 0.0,
		"rim_color": Color("#D8E4FF"), "rim_energy": 0.9,
		"ambient_color": Color("#2c3246"), "ambient_energy": 0.7,
		"fog_color": Color("#4A4E5E"), "fog_density": 0.003, "exposure": 1.25, "lantern": 1.0,
	}
	p.day = {
		"sky_top": Color("#4a5260"), "sky_horizon": Color("#8a9290"), "sky_below": Color("#6a7070"),
		"cloud": Color("#9aa0a4"), "cloud_shadow": Color("#4a5056"), "cloud_cover": 0.85,
		"sun_dir": Vector3(-0.3, -0.81, -0.5), "sun_color": Color("#b8c4e0"), "sun_energy": 0.9,
		"sun_size": 0.0, "moon": false, "stars": 0.0,
		"rim_color": Color("#D8E4FF"), "rim_energy": 1.6,
		"ambient_color": Color("#6a7080"), "ambient_energy": 0.75,
		"fog_color": Color("#7a8084"), "fog_density": 0.0026, "exposure": 1.0, "lantern": 0.7,
	}
	p.dusk = {
		"sky_top": Color("#3c3a50"), "sky_horizon": Color("#c8a49a"), "sky_below": Color("#6a5a60"),
		"cloud": Color("#9a8a96"), "cloud_shadow": Color("#3e3846"), "cloud_cover": 0.6,
		"sun_dir": Vector3(-0.85, -0.32, -0.42), "sun_color": Color("#e6b0a0"), "sun_energy": 1.1,
		"sun_size": 0.03, "moon": false, "stars": 0.0,
		"rim_color": Color("#ffd8c0"), "rim_energy": 1.2,
		"ambient_color": Color("#5a5062"), "ambient_energy": 0.6,
		"fog_color": Color("#7a6c72"), "fog_density": 0.0024, "exposure": 1.05, "lantern": 0.9,
	}
	var flash: Dictionary = p.night.duplicate()
	flash["flash"] = 1.0
	p["lightning"] = flash
	return p


# ---------------------------------------------------------------- shots

func shots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var spire: Vector3 = towers["Spire Tower"].origin if towers.has("Spire Tower") else Vector3(-102, 80, 618)
	var all := ["night", "dusk", "day"]
	# Key image: low on the street at x = -78, north across the canal to the Spire.
	var kx := -78.0
	var kz := 440.0
	var g := ground_at(kx, kz)
	out.append({"name": "street_key", "from": Vector3(kx + 2.5, g + 2.4, kz - 18.0), "at": Vector3(spire.x, g + 34.0, spire.z),
		"fov": 58.0, "kael": [Vector2(kx + 1.2, kz - 9.0), PI * 0.95], "times": all})
	# The canal and the half-sunk bus, from the embankment.
	var bus: Vector3 = story.get("bus", Vector3(-74, 6, 480))
	var cz := _canal_z(bus.x + 20.0)
	out.append({"name": "canal_bus", "from": Vector3(bus.x + 20.0, ground_at(bus.x + 20.0, cz) + 1.7, cz - 3.0),
		"at": Vector3(bus.x - 2.0, bus.y + 1.5, bus.z - 2.0), "fov": 55.0,
		"times": ["night"]})
	# The Old Tower's stopped clock.
	var clock: Vector3 = stats.get("clock_centre", Vector3(-198, 120, 282))
	out.append({"name": "old_tower_clock", "from": clock + Vector3(14.0, -38.0, 62.0), "at": clock + Vector3(0, -6.0, 0), "fov": 45.0,
		"times": ["night"]})
	# Lightning over the skyline from a rooftop.
	out.append({"name": "lightning_skyline", "from": Vector3(40, 70, 300), "at": Vector3(-20, 90, 620), "fov": 60.0,
		"times": ["lightning"]})
	# The rooftop garden.
	var gd: Vector3 = story.get("garden", Vector3(-60, 30, 380))
	out.append({"name": "rooftop_garden", "from": gd + Vector3(7.0, 4.0, 9.0), "at": gd + Vector3(0, 0.8, -1.0), "fov": 55.0,
		"kael": [Vector2(gd.x + 1.5, gd.z + 1.5), PI * 0.2], "kael_y": gd.y + 0.15, "times": ["night"]})
	# Wide overview.
	out.append({"name": "overview", "from": Vector3(220, 190, 160), "at": Vector3(-40, 20, 500), "fov": 55.0, "times": all})
	# Kael for scale: beside a car, under the noodle-bar sign, on the street at gameplay camera.
	var nb: Vector3 = story.get("noodle_bar", Vector3(-62, 12, 413))
	out.append({"name": "kael_noodle_bar", "from": nb + Vector3(6.5, 2.0, 3.5), "at": nb + Vector3(0, 1.8, 0), "fov": 55.0,
		"kael": [Vector2(nb.x + 2.0, nb.z + 1.0), PI * 0.4], "times": ["night"]})
	var car := _nearest_car(Vector3(-22, 12, 402))
	var cg := ground_at(car.origin.x, car.origin.z)
	var side := car.basis.orthonormalized() * Vector3(0, 0, 1)
	var kp := car.origin + side * 1.8
	out.append({"name": "kael_car", "from": kp + side * 4.5 + Vector3(2.0, 1.6, 0), "at": kp + Vector3(0, 0.6, 0), "fov": 55.0,
		"kael": [Vector2(kp.x, kp.z), atan2(side.x, side.z)], "times": ["night"]})
	var sp := Vector2(-22, 402)
	var sg := ground_at(sp.x, sp.y)
	out.append({"name": "kael_gameplay", "from": Vector3(sp.x - 3.0, sg + 3.2, sp.y + 6.5), "at": Vector3(sp.x + 8.0, sg + 1.6, sp.y - 12.0),
		"fov": 62.0, "kael": [sp, PI * 0.85], "times": all})
	return out


func _nearest_car(p: Vector3) -> Transform3D:
	var best := cars[0] if not cars.is_empty() else Transform3D()
	for c in cars:
		if c.origin.distance_to(p) < best.origin.distance_to(p):
			best = c
	return Transform3D(best.basis.orthonormalized(), best.origin - best.basis * Vector3(0, 0.5, 0))


## 20 s: low down the spawn street past the noodle bar, a turn over the canal
## past the bus, up the facades to the rooftop garden, between blocks and a
## climb around the Spire's needle (a lightning flash at 18.4 s).
func flight() -> Array[Dictionary]:
	var g := ground_at(-22, 402)
	var bus: Vector3 = story.get("bus", Vector3(-74, 6, 480))
	var gd: Vector3 = story.get("garden", Vector3(-60, 30, 380))
	var spire: Vector3 = towers["Spire Tower"].origin if towers.has("Spire Tower") else Vector3(-102, 80, 618)
	var top: float = stats.get("spire_top", 200.0)
	return [
		{"from": Vector3(30, g + 6.6, 404), "at": Vector3(-40, g + 4.0, 402), "fov": 60.0},  # the street rises here
		{"from": Vector3(-6, g + 2.6, 403), "at": Vector3(-62, g + 3.0, 412), "fov": 60.0},
		{"from": Vector3(-46, g + 4.7, 400), "at": Vector3(-78, g + 3.0, 440), "fov": 60.0},
		{"from": Vector3(-74, g + 4.0, 427), "at": bus + Vector3(0, 0, 0), "fov": 58.0},  # clear of the corner block
		{"from": Vector3(-56, g + 2.0, bus.z - 2.0), "at": bus + Vector3(-30, 0, 4), "fov": 58.0},
		{"from": Vector3(-30, g + 10.0, bus.z - 14.0), "at": gd + Vector3(0, 0, 0), "fov": 58.0},
		{"from": gd + Vector3(14, 6, 16), "at": gd, "fov": 56.0},
		{"from": gd + Vector3(-8, 20, 30), "at": spire + Vector3(0, 10, 0), "fov": 56.0},
		{"from": spire + Vector3(50, -20, -70), "at": spire + Vector3(0, 30, 0), "fov": 56.0},
		{"from": spire + Vector3(55, top - spire.y - 25.0, 20), "at": Vector3(spire.x, top - 30.0, spire.z), "fov": 56.0},
		{"from": spire + Vector3(0, top - spire.y + 4.0, 60), "at": Vector3(spire.x, top - 45.0, spire.z), "fov": 58.0},
		{"from": spire + Vector3(-40, top - spire.y + 20.0, 30), "at": Vector3(spire.x + 40.0, g + 30.0, spire.z - 200.0), "fov": 60.0},
	]


func flight_kael() -> Array:
	return [Vector2(-22, 402), PI * 0.6]
