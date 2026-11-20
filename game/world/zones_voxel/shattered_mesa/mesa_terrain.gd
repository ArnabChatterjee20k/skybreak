class_name MesaTerrain
extends RefCounted
## Shattered Mesa's ground as voxels, over the sim's baked heightmap (the truth):
## - the floor and every flat tread: triangles on the heightmap's own 2 m grid
##   (the visible ground stays within a few cm of ZoneGround), per-voxel look in
##   the floor shader (T1 cells), macro colour from a 1 m texture;
## - cliffs (cells too steep to stand on): a VoxelHeightfield of rock columns at
##   T2 whose tops snap down to 2.8 m strata bands, so every mesa, canyon wall
##   and terrace riser is a stack of planar slabs with a setback per band;
## - LOD: 8 m floor and T3 rock past NEAR_END, and a T3 ring outside the zone.
## Meshes and textures are cached on disk by VERSION.

const FLOOR_SHADER := preload("res://game/world/zones_voxel/shattered_mesa/mesa_floor.gdshader")
const ROCK_SHADER := preload("res://game/world/zones_voxel/shattered_mesa/mesa_rock.gdshader")
const VERSION := 3
const CACHE := "user://voxel_zone_cache/shattered_mesa_v%d/" % VERSION
## Floor cells whose corners differ by more than this (m) are cliff, not floor.
const STEEP := 1.1
## Strata band in rock cells (T2): 8 x 0.35 = 2.8 m.
const BAND_CELLS := 8
## Skirt under every floor edge that meets a cliff: covers the band snap.
const SKIRT := 3.4
## Near tiers end here (m); far tiers start.
const NEAR_END := 330.0
## Floor chunk side in 2 m samples.
const FLOOR_CHUNK := 32

var map: TerrainHeightmap
## Zone box (world x, z) built at near detail; the ring around it is far only.
var near_min := Vector2.ZERO
var near_max := Vector2.ZERO
var ring_min := Vector2.ZERO
var ring_max := Vector2.ZERO
var stats := {}
var floor_material: ShaderMaterial
var rock_materials: Array[ShaderMaterial] = []
## Steep per 2 m cell over the heightmap (1 = cliff), cell (i, j) = samples (i..i+1, j..j+1).
var _steep := PackedByteArray()


func _init(heightmap: TerrainHeightmap, zone_min: Vector2, zone_max: Vector2, ring_lo: Vector2, ring_hi: Vector2) -> void:
	map = heightmap
	# Align to 2.8 m so T2 and T3 rock chunks share edges.
	near_min = (zone_min / 2.8).floor() * 2.8
	near_max = (zone_max / 2.8).ceil() * 2.8
	ring_min = (ring_lo / 2.8).floor() * 2.8
	ring_max = (ring_hi / 2.8).ceil() * 2.8


## Height of the sim's ground (bilinear, as ZoneGround).
func height(x: float, z: float) -> float:
	return map.ground_height_at(x, z)


func build(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "MesaTerrain"
	parent.add_child(root)
	var t := Time.get_ticks_msec()
	_classify()
	floor_material = ShaderMaterial.new()
	floor_material.shader = FLOOR_SHADER
	floor_material.set_shader_parameter("macro_tex", _macro_texture())
	floor_material.set_shader_parameter("macro_origin", ring_min)
	floor_material.set_shader_parameter("macro_size", ring_max - ring_min)
	stats.floor_tris = _floor(root)
	stats.rock_tris = _rock(root)
	stats.terrain_ms = Time.get_ticks_msec() - t
	return root


# ---------------------------------------------------------------- classification

func _classify() -> void:
	var n := map.size
	_steep.resize(n * n)
	for j in n - 1:
		for i in n - 1:
			var a := map.heights[j * n + i]
			var b := map.heights[j * n + i + 1]
			var c := map.heights[(j + 1) * n + i]
			var d := map.heights[(j + 1) * n + i + 1]
			var lo := minf(minf(a, b), minf(c, d))
			var hi := maxf(maxf(a, b), maxf(c, d))
			_steep[j * n + i] = 1 if hi - lo > STEEP else 0


func _sample_of(w: Vector2) -> Vector2i:
	return Vector2i(floori((w.x - map.origin.x) / map.cell_size), floori((w.y - map.origin.y) / map.cell_size))


## Whether the floor at `step` samples per cell covers the cell with first sample (i, j).
func _floor_cell(i: int, j: int, step: int) -> bool:
	var n := map.size
	for dj in step:
		for di in step:
			var ii := i + di
			var jj := j + dj
			if ii < 0 or jj < 0 or ii >= n - 1 or jj >= n - 1 or _steep[jj * n + ii] == 1:
				return false
	return true


func _in_near(w: Vector2) -> bool:
	return w.x >= near_min.x and w.y >= near_min.y and w.x < near_max.x and w.y < near_max.y


# ---------------------------------------------------------------- floor

func _floor(root: Node3D) -> int:
	var node := Node3D.new()
	node.name = "Floor"
	root.add_child(node)
	var tris := 0
	var s0 := _sample_of(ring_min)
	var s1 := _sample_of(ring_max)
	var span := FLOOR_CHUNK
	for cj in range(s0.y, s1.y, span):
		for ci in range(s0.x, s1.x, span):
			var centre := map.sample_position(ci + span / 2, cj + span / 2)
			var near := _in_near(centre)
			for tier in ([1, 4] if near else [4]):
				var key := "floor_%d_%d_%d" % [ci, cj, tier]
				var mesh := _cached(key, func() -> ArrayMesh: return _floor_chunk(ci, cj, mini(ci + span, s1.x),
					mini(cj + span, s1.y), tier))
				if mesh == null:
					continue
				var mi := MeshInstance3D.new()
				mi.name = key
				mi.mesh = mesh
				mi.material_override = floor_material
				# Flat treads under a high sun: let the rock and props cast.
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if near:
					mi.visibility_range_begin = 0.0 if tier == 1 else NEAR_END
					mi.visibility_range_end = NEAR_END if tier == 1 else 0.0
				node.add_child(mi)
				if tier == 1 or not near:
					tris += mesh.surface_get_array_len(0) / 3
	return tris


## Floor triangles of samples [i0, i1) x [j0, j1) at `step` samples per cell,
## with skirts down every edge that meets a cliff cell.
func _floor_chunk(i0: int, j0: int, i1: int, j1: int, step: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var n := map.size
	for j in range(j0, j1, step):
		for i in range(i0, i1, step):
			if not _floor_cell(i, j, step):
				continue
			var p := [_vertex(i, j), _vertex(i + step, j), _vertex(i + step, j + step), _vertex(i, j + step)]
			var nn := [_normal(i, j), _normal(i + step, j), _normal(i + step, j + step), _normal(i, j + step)]
			# Split along the flatter diagonal (closer to the bilinear surface).
			var tri: Array
			if absf(p[0].y - p[2].y) < absf(p[1].y - p[3].y):
				tri = [0, 2, 1, 0, 3, 2]
			else:
				tri = [0, 3, 1, 1, 3, 2]
			for k: int in tri:
				verts.append(p[k])
				normals.append(nn[k])
				uvs.append(Vector2(-1000.0, 0.0))
			# Skirts on edges facing a non-floor cell (or the field's end).
			var sides := [[Vector2i(0, -step), 0, 1], [Vector2i(step, 0), 1, 2], [Vector2i(0, step), 2, 3],
				[Vector2i(-step, 0), 3, 0]]
			for s: Array in sides:
				var o: Vector2i = s[0]
				if _floor_cell(i + o.x, j + o.y, step):
					continue
				var a: Vector3 = p[s[1]]
				var b: Vector3 = p[s[2]]
				var out := Vector3(o.x, 0, o.y).normalized()
				var top := maxf(a.y, b.y)
				var quad := [a, b, b - Vector3(0, SKIRT * step, 0), a - Vector3(0, SKIRT * step, 0)]
				var order := [0, 1, 2, 0, 2, 3]
				if (quad[1] - quad[0]).cross(quad[2] - quad[0]).dot(out) > 0.0:
					order = [0, 2, 1, 0, 3, 2]
				for k: int in order:
					verts.append(quad[k])
					normals.append(out)
					uvs.append(Vector2(top, 1.0))
	if verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _vertex(i: int, j: int) -> Vector3:
	var w := map.sample_position(i, j)
	return Vector3(w.x, map.height_at_sample(i, j), w.y)


func _normal(i: int, j: int) -> Vector3:
	var dx := map.height_at_sample(i + 1, j) - map.height_at_sample(i - 1, j)
	var dz := map.height_at_sample(i, j + 1) - map.height_at_sample(i, j - 1)
	return Vector3(-dx, 2.0 * map.cell_size, -dz).normalized()


# ---------------------------------------------------------------- rock

func _rock(root: Node3D) -> int:
	var node := Node3D.new()
	node.name = "Rock"
	root.add_child(node)
	var tris := 0
	# Near: T2 over the zone box. Far: T3 over the zone box (LOD) and the ring.
	tris += _rock_field(node, "near", VoxelZone.T2, near_min, near_max, 1, 0.0, NEAR_END, true)
	_rock_field(node, "far", VoxelZone.T3, near_min, near_max, 4, NEAR_END, 0.0, false)
	tris += _rock_field(node, "ring", VoxelZone.T3, ring_min, ring_max, 4, 0.0, 0.0, false, true)
	return tris


## One rock field: columns wherever the floor (at `step` samples) is missing,
## tops snapped down to strata bands. ring: skip columns inside the zone box.
func _rock_field(node: Node3D, key: String, cell: float, lo: Vector2, hi: Vector2, step: int,
		begin: float, end: float, shadows: bool, ring := false) -> int:
	var hf := VoxelHeightfield.new(cell, lo + Vector2.ONE * cell * 0.01, hi - Vector2.ONE * cell * 0.01)
	hf.chunk = roundi(89.6 / cell)
	var band := BAND_CELLS * VoxelZone.T2
	var band_cells := band / cell
	var mat := ShaderMaterial.new()
	mat.shader = ROCK_SHADER
	var tex_path := CACHE + "rock_%s.res" % key
	var meshes: Array = []
	if ResourceLoader.exists(tex_path):
		var saved: Dictionary = (load(tex_path) as RockCache).data
		for k: String in ["cell", "field_origin", "field_size", "colour_tex", "level_tex", "down", "smooth_top"]:
			mat.set_shader_parameter(k, saved[k])
		meshes = saved.meshes
	else:
		var white := Color(1, 1, 1, 0)
		for z in hf.size.y:
			for x in hf.size.x:
				var w := hf.centre(x, z)
				if ring and _in_near(w):
					continue
				var s := _sample_of(w)
				var si := s.x - posmod(s.x, step)
				var sj := s.y - posmod(s.y, step)
				if _floor_cell(si, sj, step):
					continue
				var h := height(w.x, w.y) - 0.06
				var top := floori(h / band) * band_cells
				var foot := h - 14.0
				for d: Vector2 in [Vector2(-4, 0), Vector2(4, 0), Vector2(0, -4), Vector2(0, 4)]:
					foot = minf(foot, height(w.x + d.x * step, w.y + d.y * step) - 3.0)
				hf.set_column(x, z, roundi(top), floori(foot / cell), white)
		hf.bake_step_ao(0.4, 2 if cell < 1.0 else 1)
		hf.bind(mat)
		var built := hf.build(node, mat, "tmp")
		for mi: MeshInstance3D in built.get_children():
			meshes.append(mi.mesh)
		built.free()
		var save := RockCache.new()
		save.data = {"meshes": meshes}
		for k: String in ["cell", "field_origin", "field_size", "colour_tex", "level_tex", "down", "smooth_top"]:
			save.data[k] = mat.get_shader_parameter(k)
		DirAccess.make_dir_recursive_absolute(CACHE)
		ResourceSaver.save(save, tex_path)
	mat.set_shader_parameter("band", band)
	rock_materials.append(mat)
	var tris := 0
	var group := Node3D.new()
	group.name = key.capitalize()
	node.add_child(group)
	for m: ArrayMesh in meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat
		mi.visibility_range_begin = begin
		mi.visibility_range_end = end
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(mi)
		tris += m.surface_get_array_len(0) / 3
	return tris


# ---------------------------------------------------------------- macro colour

## sRGB floor colour per metre over the ring box: sand, dunes, washes, the
## dark caprock on high treads with sand pockets, talus sand and contact
## shade at cliff feet. Alpha: 1 in a dry wash (mud cracks).
func _macro_texture() -> ImageTexture:
	var path := CACHE + "macro.res"
	if ResourceLoader.exists(path):
		return load(path) as ImageTexture
	var size := Vector2i((ring_max - ring_min).ceil())
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var dune := FastNoiseLite.new()
	dune.seed = 91
	dune.frequency = 0.022
	dune.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	dune.fractal_octaves = 2
	var wash := FastNoiseLite.new()
	wash.seed = 92
	wash.frequency = 0.0065
	wash.fractal_octaves = 2
	var patch := FastNoiseLite.new()
	patch.seed = 93
	patch.frequency = 0.05
	patch.fractal_octaves = 3
	# Distance (in 2 m cells, capped) to the nearest cliff cell.
	var n := map.size
	var s0 := _sample_of(ring_min) - Vector2i(4, 4)
	var s1 := _sample_of(ring_max) + Vector2i(4, 4)
	var dw := s1.x - s0.x
	var dh := s1.y - s0.y
	var dist := PackedByteArray()
	dist.resize(dw * dh)
	for j in dh:
		for i in dw:
			var ii := clampi(s0.x + i, 0, n - 2)
			var jj := clampi(s0.y + j, 0, n - 2)
			dist[j * dw + i] = 0 if _steep[jj * n + ii] == 1 else 6
	for _round in 5:
		var nxt := dist.duplicate()
		for j in range(1, dh - 1):
			for i in range(1, dw - 1):
				var k := j * dw + i
				var m := mini(mini(dist[k - 1], dist[k + 1]), mini(dist[k - dw], dist[k + dw])) + 1
				if m < nxt[k]:
					nxt[k] = m
		dist = nxt
	var sand := Color("#E2D2B4")
	var crest := Color("#EADCC2")
	var trough := Color("#D2BE9E")
	var talus := Color("#C9A68A")
	var cap := Color("#6E5E54")
	var cap_light := Color("#857262")
	var drift := Color("#D6C2A2")
	for y in size.y:
		for x in size.x:
			var w := ring_min + Vector2(x + 0.5, y + 0.5)
			var h := height(w.x, w.y)
			var di := Vector2i(floori((w.x - map.origin.x) / 2.0) - s0.x, floori((w.y - map.origin.y) / 2.0) - s0.y)
			var d := float(dist[clampi(di.y, 0, dh - 1) * dw + clampi(di.x, 0, dw - 1)]) * 2.0
			var c: Color
			var a := 0.0
			var pn := patch.get_noise_2d(w.x, w.y)
			if h < 30.0:
				var dn := dune.get_noise_2d(w.x * 0.8 + w.y * 0.3, w.y * 0.6 - w.x * 0.2)
				c = sand.lerp(crest, clampf(dn * 1.6, 0.0, 1.0)).lerp(trough, clampf(-dn * 1.2, 0.0, 0.6))
				var wn := absf(wash.get_noise_2d(w.x, w.y))
				if wn < 0.035 and d > 8.0:
					var k := 1.0 - wn / 0.035
					c = c.lerp(crest, k * 0.6)
					a = 1.0 if k > 0.45 else 0.0
					if k < 0.45:
						c = c.lerp(Color("#BBA184"), (0.45 - k) * 0.8)
				# Talus sand and contact shade at cliff feet.
				if d < 10.0:
					c = c.lerp(talus, (1.0 - d / 10.0) * 0.55)
					c *= 1.0 - 0.18 * (1.0 - d / 10.0)
				c = c.lerp(drift, clampf(pn * 0.6, 0.0, 0.3))
			else:
				# High treads: caprock with sand pockets; edges polished lighter.
				c = cap.lerp(cap_light, clampf(pn + 0.3, 0.0, 1.0) * 0.6)
				var pocket := clampf((patch.get_noise_2d(w.x * 0.5 + 70.0, w.y * 0.5) - 0.05) * 3.0, 0.0, 1.0)
				c = c.lerp(drift, pocket * 0.85)
				if d < 4.0:
					c = c.lerp(cap_light * 1.12, (1.0 - d / 4.0) * 0.4)
				var blend := clampf((h - 30.0) / 6.0, 0.0, 1.0)
				c = talus.lerp(c, blend)
			c.a = a
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	DirAccess.make_dir_recursive_absolute(CACHE)
	ResourceSaver.save(tex, path)
	return tex


## Cached floor chunk mesh (null meshes are remembered as empty files).
func _cached(key: String, make: Callable) -> ArrayMesh:
	var path := CACHE + key + ".res"
	if ResourceLoader.exists(path):
		var m := load(path) as ArrayMesh
		return m if m.get_surface_count() > 0 else null
	var mesh: ArrayMesh = make.call()
	DirAccess.make_dir_recursive_absolute(CACHE)
	ResourceSaver.save(mesh if mesh != null else ArrayMesh.new(), path)
	return mesh
