class_name HeartbloomProps
extends RefCounted
## Heartbloom Gardens: cherry-blossom floating islands joined by lantern bridges, the
## Heart Arch, the Wishing Fountain, a stream that falls off Blossom Crown into the
## clouds, petal whirlwinds, and fireflies plus glowing lanterns at night.

const WATERFALL_SHADER := preload("res://game/world/shaders/waterfall.gdshader")
const WATER_SHADER := preload("res://game/world/shaders/sparkle_water.gdshader")
const GLOW_SHADER := preload("res://game/world/shaders/lantern_glow.gdshader")
const SWIRL_SHADER := preload("res://game/world/shaders/petal_swirl.gdshader")
## Own seed, so the six ground zones keep their props exactly.
const SEED := 5151
const SEGMENTS := 40
const TOP_RINGS := 7
const UNDER_RINGS := 6
const LIP := 1.6
## Islands joined by rope-plank lantern bridges.
const BRIDGES := [
	["Heart Isle", "Wishing Isle"], ["Heart Isle", "Lantern Rise"], ["Heart Isle", "Blossom Crown"],
	["Heart Isle", "Picnic Meadow"], ["Wishing Isle", "West Petal"], ["Wishing Isle", "Twin Drop"],
	["Picnic Meadow", "East Petal"], ["South Petal", "Dew Drop"],
]
## Trees per island (big islands get more).
const TREES := {
	"Heart Isle": 9, "Wishing Isle": 6, "Lantern Rise": 5, "Blossom Crown": 10, "Picnic Meadow": 5,
	"West Petal": 2, "East Petal": 2, "South Petal": 2, "North Petal": 2, "Dew Drop": 1, "Twin Drop": 1,
}
const BLOSSOMS: Array[Color] = [
	Color(1.0, 0.7, 0.82), Color(0.98, 0.56, 0.74), Color(0.93, 0.44, 0.66), Color(1.0, 0.82, 0.9),
]
const LANTERN_COLORS: Array[Color] = [
	Color(1.0, 0.36, 0.32), Color(1.0, 0.52, 0.64), Color(1.0, 0.64, 0.4), Color(1.0, 0.8, 0.4),
]
const FLOWER_COLORS: Array[Color] = [
	Color(1.0, 1.0, 0.98), Color(1.0, 0.78, 0.86), Color(0.98, 0.46, 0.68), Color(1.0, 0.86, 0.4),
]
## Heart Arch: offset from the Heart Isle centre and height (m).
const ARCH_OFFSET := Vector2(0, -26)
const ARCH_HEIGHT := 46.0

var kit: PropKit
var zone: ZoneData
var field: IslandField
var rng := RandomNumberGenerator.new()
## Circles (x, z, radius) trees and lanterns keep clear of.
var reserved: Array[Vector3] = []
var wood: Array[Transform3D] = []
var wood_tint := PackedColorArray()
var lanterns: Array[Transform3D] = []
var lantern_tint := PackedColorArray()
var canopies: Array[Transform3D] = []
var canopy_tint := PackedColorArray()
var trunks: Array[Transform3D] = []
var flowers: Array[Transform3D] = []
var flower_tint := PackedColorArray()
var clouds: Array[Transform3D] = []
var stream_points: Array[Vector3] = []


## Builds the zone under `parent`. Returns {unshaded: Array[ShaderMaterial], night_nodes: Array[Node3D]}.
static func build(parent: Node3D, prop_kit: PropKit, zone_data: ZoneData, islands: IslandField) -> Dictionary:
	var b := HeartbloomProps.new()
	b.kit = prop_kit
	b.zone = zone_data
	b.field = islands
	b.rng.seed = SEED
	return b._build(parent)


func _build(parent: Node3D) -> Dictionary:
	var unshaded: Array[ShaderMaterial] = []
	var night_nodes: Array[Node3D] = []
	for p in zone.spawn_points:
		reserved.append(Vector3(p.x, p.z, 22.0))
	var fountain: Dictionary = zone.get_meta("wishing_fountain")
	var fc: Vector3 = fountain.centre
	reserved.append(Vector3(fc.x, fc.z, 13.0))
	var heart := field.index_of("Heart Isle")
	var arch_base := field.centres[heart] + ARCH_OFFSET
	reserved.append(Vector3(arch_base.x, arch_base.y, 24.0))
	# An open lawn in front of the arch, so it is seen from its pedestal up.
	reserved.append(Vector3(arch_base.x, arch_base.y + 26.0, 16.0))
	reserved.append(Vector3(arch_base.x, arch_base.y + 50.0, 11.0))
	_plan_stream()
	_bridges()
	_island_lanterns(fc, arch_base)
	_trees()
	_flowers()
	_islands(parent)
	_cloud_tufts()
	var stone := kit.material("hb_stone", Color(1, 1, 1), {"strata": 0.2, "strata_spacing": 1.2,
		"shadow_tint": Color(0.74, 0.56, 0.7), "rim_color": Color(1.0, 0.88, 0.92), "rim_strength": 0.3,
		"emission_color": Color(1.0, 0.5, 0.7), "night_emission": 0.18})
	_heart_arch(parent, arch_base, stone)
	unshaded.append_array(_fountain(parent, fc, stone))
	unshaded.append_array(_stream(parent))
	unshaded.append(_whirlwinds(parent))
	var blossom := kit.material("hb_blossom", Color(1, 1, 1), {"shadow_tint": Color(0.8, 0.42, 0.64),
		"rim_color": Color(1.0, 0.92, 0.96), "rim_strength": 0.4})
	var bark := kit.material("hb_bark", Color(0.38, 0.25, 0.27), {"strata": 0.25, "strata_spacing": 1.5})
	var flower := kit.material("hb_flower", Color(1, 1, 1), {"shadow_tint": Color(0.75, 0.62, 0.75), "rim_strength": 0.0})
	var plank := kit.material("hb_wood", Color(1, 1, 1), {"shadow_tint": Color(0.55, 0.45, 0.6)})
	var paper := kit.material("hb_lantern", Color(1, 1, 1), {"emission_color": Color(1.0, 0.7, 0.45),
		"emission_strength": 0.35, "night_emission": 2.4, "shadow_tint": Color(0.85, 0.6, 0.6), "rim_strength": 0.0})
	var cloud := kit.material("hb_cloud", Color(1.0, 0.94, 0.96), {"shadow_tint": Color(0.86, 0.7, 0.9),
		"rim_color": Color(1.0, 0.9, 0.95), "rim_strength": 0.45})
	kit.multimesh(parent, "Trunks", PropKit.cylinder(0.32, 0.5, 7), bark, trunks)
	var canopy_node := kit.multimesh(parent, "Canopies", PropKit.sphere(10, 6), blossom, canopies, canopy_tint, "blossom_branch")
	canopy_node.set_meta("breaks_into", "petal_burst")
	kit.multimesh(parent, "Flowers", PropKit.cylinder(0.5, 0.5, 8), flower, flowers, flower_tint, "", false)
	kit.multimesh(parent, "BridgeWood", PropKit.box(), plank, wood, wood_tint)
	var lantern_node := kit.multimesh(parent, "Lanterns", PropKit.sphere(8, 5), paper, lanterns, lantern_tint, "lantern", false)
	lantern_node.set_meta("breaks_into", "petal_burst")
	_lantern_halos(parent)
	kit.multimesh(parent, "CloudTufts", PropKit.sphere(10, 6), cloud, clouds, PackedColorArray(), "", false)
	night_nodes.append_array(_fireflies(parent))
	parent.set_meta("island_count", field.size())
	return {"unshaded": unshaded, "night_nodes": night_nodes}


# --- Placement helpers -------------------------------------------------------------

func _is_free(x: float, z: float, radius: float) -> bool:
	for c in reserved:
		if Vector2(x - c.x, z - c.y).length() < c.z + radius:
			return false
	return true


## Basis that tilts +Y onto the island surface normal at (x, z).
func _surface_basis(x: float, z: float, y: float) -> Basis:
	var e := 0.6
	var hx := field.surface_at(x + e, z, y + 2.0) - field.surface_at(x - e, z, y + 2.0)
	var hz := field.surface_at(x, z + e, y + 2.0) - field.surface_at(x, z - e, y + 2.0)
	if not is_finite(hx) or not is_finite(hz):
		return Basis.IDENTITY
	var n := Vector3(-hx / (2.0 * e), 1.0, -hz / (2.0 * e)).normalized()
	var axis := Vector3.UP.cross(n)
	if axis.length() < 0.0001:
		return Basis.IDENTITY
	return Basis(axis.normalized(), Vector3.UP.angle_to(n))


func _random_spot(i: int, s_min: float, s_max: float) -> Vector3:
	var a := rng.randf() * TAU
	var s := sqrt(rng.randf_range(s_min * s_min, s_max * s_max))
	return field.top_point(i, a, s)


func _near_stream(x: float, z: float, radius: float) -> bool:
	for p in stream_points:
		if Vector2(x - p.x, z - p.z).length() < radius:
			return true
	return false


# --- Islands -----------------------------------------------------------------------

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	# Godot's front face: -(b - a) x (c - a) points out.
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _islands(parent: Node3D) -> void:
	var grass := SurfaceTool.new()
	grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rock := SurfaceTool.new()
	rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rock_rng := RandomNumberGenerator.new()
	rock_rng.seed = SEED + 1
	for i in field.size():
		var c := field.centres[i]
		var top := field.tops[i]
		# Rings of the domed top: exactly the IslandField profile at every vertex.
		var rings: Array[PackedVector3Array] = []
		for k in TOP_RINGS + 1:
			var ring := PackedVector3Array()
			for j in SEGMENTS:
				ring.append(field.top_point(i, TAU * float(j) / SEGMENTS, float(k) / TOP_RINGS))
			rings.append(ring)
		grass.set_smooth_group(0)
		for k in TOP_RINGS:
			for j in SEGMENTS:
				var j2 := (j + 1) % SEGMENTS
				var shade := _grass_color(i, k, j)
				grass.set_color(shade)
				_tri(grass, rings[k][j], rings[k + 1][j], rings[k + 1][j2], Vector3.UP)
				if k > 0:
					_tri(grass, rings[k][j], rings[k + 1][j2], rings[k][j2], Vector3.UP)
		# Grass lip folding over the rim.
		var rim := rings[TOP_RINGS]
		var lip := PackedVector3Array()
		for j in SEGMENTS:
			var out := Vector3(rim[j].x - c.x, 0.0, rim[j].z - c.y).normalized()
			lip.append(rim[j] + out * 0.5 + Vector3.DOWN * LIP)
		grass.set_smooth_group(-1)
		grass.set_color(Color(0.3, 0.52, 0.3))
		for j in SEGMENTS:
			var j2 := (j + 1) % SEGMENTS
			var out := Vector3(rim[j].x - c.x, 0.0, rim[j].z - c.y).normalized()
			_tri(grass, rim[j], lip[j], lip[j2], out)
			_tri(grass, rim[j], lip[j2], rim[j2], out)
		# Rocky cone under the lip, chunky and faceted.
		var under: Array[PackedVector3Array] = [lip]
		for k in range(1, UNDER_RINGS):
			var s := 1.0 - float(k) / UNDER_RINGS
			var ring := PackedVector3Array()
			for j in SEGMENTS:
				var a := TAU * float(j) / SEGMENTS
				var r := field.rim_radius(i, a) * s * rock_rng.randf_range(0.93, 1.07)
				var y := field.underside_profile(i, s) - LIP + rock_rng.randf_range(-1.2, 1.2)
				ring.append(Vector3(c.x + cos(a) * r, y, c.y + sin(a) * r))
			under.append(ring)
		var tip := Vector3(c.x, top - field.depths[i], c.y)
		for k in under.size():
			var t := float(k) / UNDER_RINGS
			var col := Color(0.9, 0.72, 0.78).lerp(Color(0.54, 0.44, 0.7), t)
			rock.set_color(col)
			for j in SEGMENTS:
				var j2 := (j + 1) % SEGMENTS
				var a := under[k][j]
				var b := under[k][j2]
				var out := Vector3((a.x + b.x) * 0.5 - c.x, -0.3, (a.z + b.z) * 0.5 - c.y)
				if k + 1 < under.size():
					_tri(rock, a, under[k + 1][j], under[k + 1][j2], out)
					_tri(rock, a, under[k + 1][j2], b, out)
				else:
					_tri(rock, a, tip, b, out)
		# Hanging rock drips under the cone.
		for d in 2 + int(field.radii[i] / 18.0):
			var a := rock_rng.randf() * TAU
			var s := rock_rng.randf_range(0.35, 0.7)
			var r := field.rim_radius(i, a) * s
			var y := field.underside_profile(i, s) - LIP + 2.0
			var length := field.depths[i] * rock_rng.randf_range(0.25, 0.5)
			var w := field.radii[i] * rock_rng.randf_range(0.12, 0.2)
			var xform := Transform3D(Basis.from_scale(Vector3(w, length, w)), Vector3(c.x + cos(a) * r, y - length * 0.5, c.y + sin(a) * r))
			PropKit.append_mesh(rock, PropKit.cylinder(0.5, 0.0, 6), xform, Color(0.6, 0.45, 0.66))
	# Spring stones where the stream starts.
	if not stream_points.is_empty():
		var p := stream_points[0]
		for k in 6:
			var a := TAU * float(k) / 6.0
			var s := rock_rng.randf_range(1.2, 1.8)
			PropKit.append_mesh(rock, PropKit.sphere(6, 3), Transform3D(Basis.from_scale(Vector3(s * 1.4, s, s * 1.2)),
				p + Vector3(cos(a) * 3.2, 0.1, sin(a) * 3.2)), Color(0.86, 0.74, 0.78))
	_add_rim(grass)
	grass.generate_normals()
	rock.generate_normals()
	var mesh := grass.commit()
	rock.commit(mesh)
	mesh.surface_set_material(0, kit.material("hb_grass", Color(1, 1, 1), {"shadow_tint": Color(0.5, 0.52, 0.66), "rim_strength": 0.12}))
	mesh.surface_set_material(1, kit.material("hb_rock", Color(1, 1, 1), {"strata": 0.15, "strata_spacing": 7.0,
		"shadow_tint": Color(0.6, 0.44, 0.64), "rim_strength": 0.2}))
	var node := kit.single(parent, "Islands", mesh, null, Transform3D.IDENTITY)
	node.set_meta("islands", field.names)


## Grass squares at the island rims, built from the sim's ground grid (ZoneGround) so the drawn
## rim is where fighters stand.
func _add_rim(grass: SurfaceTool) -> void:
	var reach := 0.0
	for i in field.size():
		reach = maxf(reach, (field.centres[i] - zone.centre).length() + field.radii[i] * 1.2)
	var ground := ZoneGround.bake(kit.map, field, zone.centre, reach)
	var half := ZoneGround.CELL * 0.25
	grass.set_smooth_group(-1)
	grass.set_color(Color(0.3, 0.52, 0.3))
	for c in ground.island_rim_squares():
		var a := c + Vector3(-half, 0, -half)
		var b := c + Vector3(half, 0, -half)
		var d := c + Vector3(half, 0, half)
		var e := c + Vector3(-half, 0, half)
		_tri(grass, a, b, d, Vector3.UP)
		_tri(grass, a, d, e, Vector3.UP)


func _grass_color(i: int, k: int, j: int) -> Color:
	# Lighter towards the middle, with a soft deterministic mottling.
	var base := Color(0.3, 0.56, 0.38).lerp(Color(0.4, 0.64, 0.4), 1.0 - float(k) / TOP_RINGS)
	var m := 0.5 + 0.5 * sin(float(j) * 1.7 + float(k) * 2.3 + field.phases[i] * 3.0)
	return base * (0.94 + 0.08 * m)


func _cloud_tufts() -> void:
	for i in field.size():
		var c := field.centres[i]
		var r := field.radii[i]
		var count := 2 + int(r / 16.0)
		for k in count:
			var a := TAU * float(k) / count + rng.randf_range(-0.3, 0.3)
			var off := r * rng.randf_range(0.3, 0.6)
			var y := field.tops[i] - field.depths[i] * rng.randf_range(0.5, 0.75)
			var w := r * rng.randf_range(0.35, 0.5)
			# A cluster of round puffs hugging the rock cone.
			for m in 3:
				var dir := Vector3(cos(a + m * 0.7), 0.0, sin(a + m * 0.7))
				var s := w * (1.0 if m == 0 else rng.randf_range(0.55, 0.75))
				var at := Vector3(c.x, y, c.y) + Vector3(cos(a), 0.0, sin(a)) * off + dir * w * 0.45 * float(m)
				clouds.append(PropKit.placed(at + Vector3.DOWN * s * (0.3 + 0.1 * m), Vector3(s * 1.15, s * 0.7, s), rng.randf() * TAU))


# --- Trees and flowers -------------------------------------------------------------

func _trees() -> void:
	var placed: Array[Vector3] = []
	for i in field.size():
		var count: int = TREES.get(field.names[i], 1)
		var small := field.radii[i] < 30.0
		var tries := 0
		var made := 0
		while made < count and tries < 300:
			tries += 1
			var p := _random_spot(i, 0.3 if not small else 0.0, 0.82)
			if not _is_free(p.x, p.z, 4.0) or _near_stream(p.x, p.z, 6.0):
				continue
			var crowded := false
			for q in placed:
				if Vector2(p.x - q.x, p.z - q.z).length() < 11.0:
					crowded = true
					break
			if crowded:
				continue
			placed.append(p)
			made += 1
			_tree(p, 0.75 if small else rng.randf_range(0.9, 1.25))


func _tree(p: Vector3, scale: float) -> void:
	var h := rng.randf_range(5.5, 8.0) * scale
	var r := rng.randf_range(0.9, 1.25) * scale
	var lean := Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))
	var yaw := rng.randf() * TAU
	trunks.append(PropKit.placed(p + Vector3.DOWN * 0.5, Vector3(r * 2.0, h + 0.5, r * 2.0), yaw, lean))
	var crown := p + Basis.from_euler(lean) * Vector3(0.0, h, 0.0)
	var w := rng.randf_range(8.0, 10.5) * scale
	var tint := BLOSSOMS[rng.randi() % BLOSSOMS.size()]
	canopies.append(PropKit.placed(crown + Vector3.DOWN * w * 0.3, Vector3(w, w * 0.72, w), yaw))
	canopy_tint.append(tint)
	for k in 4:
		var a := yaw + TAU * float(k) / 4.0 + rng.randf_range(-0.4, 0.4)
		var s := w * rng.randf_range(0.5, 0.68)
		var off := Vector3(cos(a), 0.0, sin(a)) * w * 0.42
		canopies.append(PropKit.placed(crown + off + Vector3.DOWN * (s * 0.55 + rng.randf_range(0.0, 1.2)), Vector3(s, s * 0.78, s), a))
		canopy_tint.append(tint.lerp(BLOSSOMS[(k + 2) % BLOSSOMS.size()], 0.35))
	# A carpet of fallen petals under the tree.
	var carpet := w * 0.45
	flowers.append(Transform3D(_surface_basis(p.x, p.z, p.y) * Basis.from_scale(Vector3(carpet * 2.0, 0.06, carpet * 1.7)), p + Vector3.UP * 0.04))
	flower_tint.append(tint * 0.92)


func _flowers() -> void:
	for i in field.size():
		var patches := 2 + int(field.radii[i] / 7.0)
		for k in patches:
			var centre := _random_spot(i, 0.1, 0.85)
			if _near_stream(centre.x, centre.z, 4.0):
				continue
			var near_spawn := false
			for p in zone.spawn_points:
				near_spawn = near_spawn or Vector2(centre.x - p.x, centre.z - p.z).length() < 13.0
			var fountain: Vector3 = zone.get_meta("wishing_fountain").centre
			if near_spawn or Vector2(centre.x - fountain.x, centre.z - fountain.z).length() < 12.0:
				continue
			var color := FLOWER_COLORS[rng.randi() % FLOWER_COLORS.size()] if rng.randf() < 0.85 else FLOWER_COLORS[3]
			var spread := rng.randf_range(2.5, 4.5)
			for f in rng.randi_range(12, 20):
				var a := rng.randf() * TAU
				var d := spread * sqrt(rng.randf())
				var x := centre.x + cos(a) * d
				var z := centre.z + sin(a) * d
				var y := field.surface_at(x, z)
				if not is_finite(y):
					continue
				var size := rng.randf_range(0.45, 0.8)
				flowers.append(Transform3D(_surface_basis(x, z, y) * Basis.from_scale(Vector3(size, 0.22, size)), Vector3(x, y + 0.1, z)))
				flower_tint.append(color * rng.randf_range(0.94, 1.04))


# --- Bridges and lanterns ----------------------------------------------------------

func _bridges() -> void:
	for pair in BRIDGES:
		var a := field.index_of(pair[0])
		var b := field.index_of(pair[1])
		var dir := (field.centres[b] - field.centres[a]).normalized()
		var angle := atan2(dir.y, dir.x)
		var start := field.top_point(a, angle, 0.92)
		var end := field.top_point(b, angle + PI, 0.92)
		reserved.append(Vector3(start.x, start.z, 5.0))
		reserved.append(Vector3(end.x, end.z, 5.0))
		_bridge(start, end)


func _bridge(start: Vector3, end: Vector3) -> void:
	var length := start.distance_to(end)
	var sag := length * 0.07
	var flat := Vector3(end.x - start.x, 0.0, end.z - start.z).normalized()
	var side := Vector3.UP.cross(flat).normalized()
	var deck := func(u: float) -> Vector3:
		return start.lerp(end, u) + Vector3.DOWN * sag * 4.0 * u * (1.0 - u)
	var planks := int(length / 0.95)
	var wood_color := Color(0.66, 0.46, 0.32)
	var rope_color := Color(0.9, 0.8, 0.64)
	for k in planks:
		var u := (float(k) + 0.5) / planks
		var p: Vector3 = deck.call(u)
		var ahead: Vector3 = deck.call(minf(u + 0.01, 1.0)) - deck.call(maxf(u - 0.01, 0.0))
		var forward := ahead.normalized()
		var basis := Basis(side, forward.cross(side).normalized(), forward)
		wood.append(Transform3D(basis * Basis.from_scale(Vector3(3.2, 0.2, 0.72)), p))
		wood_tint.append(wood_color * rng.randf_range(0.85, 1.1))
	# Hand ropes, suspenders and end posts.
	var segments := maxi(8, int(length / 2.0))
	for side_sign in [-1.0, 1.0]:
		for k in segments:
			var u0 := float(k) / segments
			var u1 := float(k + 1) / segments
			var p0: Vector3 = deck.call(u0) + side * 1.6 * side_sign + Vector3.UP * 1.15
			var p1: Vector3 = deck.call(u1) + side * 1.6 * side_sign + Vector3.UP * 1.15
			wood.append(_beam(p0, p1, 0.13))
			wood_tint.append(rope_color)
			if k > 0:
				wood.append(_beam(p0 + Vector3.DOWN * 1.15, p0, 0.08))
				wood_tint.append(rope_color)
		for u in [0.0, 1.0]:
			var base: Vector3 = deck.call(u) + side * 1.7 * side_sign
			wood.append(PropKit.placed(base + Vector3.DOWN * 0.4, Vector3(0.42, 3.0, 0.42), atan2(flat.x, flat.z)))
			wood_tint.append(wood_color * 0.75)
			_lantern(base + Vector3.UP * 3.2, 1.0, true)
	# Lanterns hanging from the ropes, alternating sides.
	var count := maxi(1, int(length / 8.0))
	for k in count:
		var u := (float(k) + 0.5) / count
		var side_sign := 1.0 if k % 2 == 0 else -1.0
		var p: Vector3 = deck.call(u) + side * 1.75 * side_sign + Vector3.UP * 0.35
		_lantern(p, 0.85, false)


func _beam(a: Vector3, b: Vector3, thickness: float) -> Transform3D:
	var d := b - a
	var z := d.normalized()
	var x := Vector3.UP.cross(z)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x)
	return Transform3D(Basis(x * thickness, y * thickness, z * d.length()), (a + b) * 0.5)


## A paper lantern centred at `p`, with dark caps; `on_post` adds no cord.
func _lantern(p: Vector3, scale: float, on_post: bool) -> void:
	var tint := LANTERN_COLORS[rng.randi() % LANTERN_COLORS.size()]
	lanterns.append(Transform3D(Basis.from_scale(Vector3(0.95, 1.2, 0.95) * scale), p))
	lantern_tint.append(tint)
	var cap := Color(0.32, 0.2, 0.22)
	wood.append(Transform3D(Basis.from_scale(Vector3(0.5, 0.16, 0.5) * scale), p + Vector3.UP * 0.62 * scale))
	wood_tint.append(cap)
	wood.append(Transform3D(Basis.from_scale(Vector3(0.4, 0.12, 0.4) * scale), p + Vector3.DOWN * 0.62 * scale))
	wood_tint.append(cap)
	if not on_post:
		wood.append(Transform3D(Basis.from_scale(Vector3(0.05, 0.6, 0.05)), p + Vector3.UP * 0.95 * scale))
		wood_tint.append(Color(0.9, 0.8, 0.64))


## A wooden post with a lantern on top, standing on the island surface.
func _lantern_post(x: float, z: float) -> void:
	var y := field.surface_at(x, z)
	if not is_finite(y):
		return
	wood.append(PropKit.placed(Vector3(x, y - 0.3, z), Vector3(0.38, 3.6, 0.38), 0.0))
	wood_tint.append(Color(0.48, 0.32, 0.26))
	wood.append(PropKit.placed(Vector3(x, y + 3.2, z), Vector3(1.4, 0.18, 0.3), 0.0))
	wood_tint.append(Color(0.48, 0.32, 0.26))
	_lantern(Vector3(x + 0.6, y + 2.35, z), 1.15, false)
	_lantern(Vector3(x - 0.6, y + 2.35, z), 1.15, false)


func _island_lanterns(fountain: Vector3, arch_base: Vector2) -> void:
	# A ring of posts around the Wishing Fountain plaza.
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.5
		_lantern_post(fountain.x + cos(a) * 11.0, fountain.z + sin(a) * 11.0)
	# Posts flanking the Heart Arch, front and back.
	for dx in [-14.0, 14.0]:
		for dz in [-7.0, 7.0]:
			_lantern_post(arch_base.x + dx, arch_base.y + dz)
	# Lantern Rise: a ring of posts strung together with small lanterns.
	var rise := field.index_of("Lantern Rise")
	var posts: Array[Vector3] = []
	for k in 6:
		var p := field.top_point(rise, TAU * float(k) / 6.0 + 0.3, 0.62)
		posts.append(p)
		_lantern_post(p.x, p.z)
		reserved.append(Vector3(p.x, p.z, 3.0))
	for k in posts.size():
		var a := posts[k] + Vector3.UP * 3.3
		var b := posts[(k + 1) % posts.size()] + Vector3.UP * 3.3
		var segs := 8
		for s in segs:
			var u0 := float(s) / segs
			var u1 := float(s + 1) / segs
			var p0 := a.lerp(b, u0) + Vector3.DOWN * 1.4 * 4.0 * u0 * (1.0 - u0)
			var p1 := a.lerp(b, u1) + Vector3.DOWN * 1.4 * 4.0 * u1 * (1.0 - u1)
			wood.append(_beam(p0, p1, 0.06))
			wood_tint.append(Color(0.9, 0.8, 0.64))
			if s % 2 == 1:
				_lantern(p1 + Vector3.DOWN * 0.55, 0.55, false)
	# Picnic Meadow: posts on the rim, clear of the spawns.
	var meadow := field.index_of("Picnic Meadow")
	for k in 4:
		var p := field.top_point(meadow, TAU * float(k) / 4.0 + PI * 0.25, 0.8)
		if _is_free(p.x, p.z, 1.0):
			_lantern_post(p.x, p.z)


func _lantern_halos(parent: Node3D) -> void:
	var halos: Array[Transform3D] = []
	for t in lanterns:
		halos.append(Transform3D(Basis.from_scale(Vector3.ONE * 6.5 * t.basis.get_scale().x), t.origin))
	var mat := ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	kit.night_materials.append(mat)
	var quad := QuadMesh.new()
	kit.multimesh(parent, "LanternHalos", quad, mat, halos, lantern_tint, "", false)


# --- Landmarks ---------------------------------------------------------------------

## Heart curve, x in [-16, 16], y in [-17, 12.5].
static func heart_point(t: float) -> Vector2:
	var s := sin(t)
	return Vector2(16.0 * s * s * s, 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))


func _heart_arch(parent: Node3D, base: Vector2, stone: ShaderMaterial) -> void:
	var ground := field.surface_at(base.x, base.y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var scale := ARCH_HEIGHT / 29.5
	var lift := 17.0 * scale + 2.2
	var half_in := 2.7
	var half_depth := 3.2
	var sides := 8
	var steps := 34
	var rose := Color(0.95, 0.66, 0.74)
	for half in [1.0, -1.0]:
		var rings: Array[PackedVector3Array] = []
		for k in steps + 1:
			var t := lerpf(0.03, PI - 0.03, float(k) / steps)
			var p := heart_point(t) * scale
			var q := heart_point(t + 0.01) * scale
			var tangent := (q - p).normalized()
			var normal := Vector2(-tangent.y, tangent.x)
			var ring := PackedVector3Array()
			for j in sides:
				var a := TAU * (float(j) + 0.5) / sides
				var off := normal * cos(a) * half_in
				ring.append(Vector3((p.x + off.x) * half, p.y + off.y + lift, sin(a) * half_depth))
			rings.append(ring)
		for k in steps:
			var shade := rose * (0.96 + 0.06 * float(k % 2))
			st.set_color(shade)
			for j in sides:
				var j2 := (j + 1) % sides
				var mid := (rings[k][j] + rings[k + 1][j2]) * 0.5
				var axis := (rings[k][0] + rings[k][sides / 2] + rings[k + 1][0] + rings[k + 1][sides / 2]) * 0.25
				_tri(st, rings[k][j], rings[k + 1][j], rings[k + 1][j2], mid - axis)
				_tri(st, rings[k][j], rings[k + 1][j2], rings[k][j2], mid - axis)
	# Keystone at the top dip, a gold heart-lock at the tip, and a stepped pedestal.
	var cusp := heart_point(0.0) * scale
	PropKit.append_mesh(st, PropKit.box(), Transform3D(Basis(Vector3.BACK, PI * 0.25) * Basis.from_scale(Vector3(5.2, 5.2, 6.6)),
		Vector3(0, cusp.y + lift + 0.6, 0)), Color(1.0, 0.8, 0.84))
	PropKit.append_mesh(st, PropKit.box(), Transform3D(Basis(Vector3.BACK, PI * 0.25) * Basis.from_scale(Vector3(2.4, 2.4, 6.9)),
		Vector3(0, cusp.y + lift + 0.6, 0)), Color(1.0, 0.8, 0.42))
	PropKit.append_mesh(st, PropKit.box(), Transform3D(Basis.from_scale(Vector3(14.0, 1.4, 10.0)), Vector3(0, 0.2, 0)), Color(0.9, 0.78, 0.78))
	PropKit.append_mesh(st, PropKit.box(), Transform3D(Basis.from_scale(Vector3(9.0, 1.4, 7.0)), Vector3(0, 1.4, 0)), Color(0.95, 0.82, 0.82))
	st.generate_normals()
	var node := kit.single(parent, "HeartArch", st.commit(), stone, Transform3D(Basis.IDENTITY, Vector3(base.x, ground, base.y)))
	node.set_meta("landmark", "Heart Arch")
	# Blossom vines along both lobes.
	for half in [1.0, -1.0]:
		for k in 9:
			var t := lerpf(0.3, 2.3, float(k) / 8.0)
			var p := heart_point(t) * scale
			var outward := Vector2(p.x, p.y - 2.0).normalized()
			var s := rng.randf_range(4.2, 6.2)
			var world := Vector3(base.x + (p.x + outward.x * 1.8) * half, ground + lift + p.y + outward.y * 1.8, base.y + rng.randf_range(-1.0, 1.0))
			canopies.append(PropKit.placed(world + Vector3.DOWN * s * 0.4, Vector3(s, s * 0.8, s), rng.randf() * TAU))
			canopy_tint.append(BLOSSOMS[(k + int(half > 0.0)) % BLOSSOMS.size()])


func _fountain(parent: Node3D, centre: Vector3, stone: ShaderMaterial) -> Array[ShaderMaterial]:
	var ground := field.surface_at(centre.x, centre.z)
	var origin := Vector3(centre.x, ground, centre.z)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pale := Color(0.97, 0.9, 0.88)
	var warm := Color(0.92, 0.76, 0.78)
	# Plaza that marks the healing spray, then the tiered fountain.
	PropKit.append_mesh(st, PropKit.cylinder(0.5, 0.5, 28), Transform3D(Basis.from_scale(Vector3(19.0, 0.6, 19.0)), Vector3(0, -0.1, 0)), Color(0.8, 0.62, 0.68))
	PropKit.append_mesh(st, PropKit.cylinder(0.5, 0.5, 24), Transform3D(Basis.from_scale(Vector3(13.0, 0.5, 13.0)), Vector3(0, 0.4, 0)), warm)
	for k in 18:
		var a := TAU * float(k) / 18.0
		PropKit.append_mesh(st, PropKit.box(), Transform3D(Basis(Vector3.UP, -a) * Basis.from_scale(Vector3(0.9, 1.3, 2.4)),
			Vector3(cos(a) * 6.4, 1.15, sin(a) * 6.4)), pale)
	PropKit.append_mesh(st, PropKit.cylinder(0.5, 0.6, 10), Transform3D(Basis.from_scale(Vector3(1.8, 3.4, 1.8)), Vector3(0, 2.3, 0)), warm)
	PropKit.append_mesh(st, PropKit.cylinder(0.5, 0.16, 16), Transform3D(Basis.from_scale(Vector3(6.6, 1.1, 6.6)), Vector3(0, 4.45, 0)), pale)
	PropKit.append_mesh(st, PropKit.cylinder(0.5, 0.6, 10), Transform3D(Basis.from_scale(Vector3(1.0, 2.2, 1.0)), Vector3(0, 6.0, 0)), warm)
	PropKit.append_mesh(st, PropKit.cylinder(0.5, 0.2, 12), Transform3D(Basis.from_scale(Vector3(3.2, 0.8, 3.2)), Vector3(0, 7.3, 0)), pale)
	PropKit.append_mesh(st, PropKit.sphere(8, 4), Transform3D(Basis.from_scale(Vector3(0.9, 1.1, 0.9)), Vector3(0, 8.1, 0)), Color(1.0, 0.8, 0.45))
	st.generate_normals()
	var node := kit.single(parent, "WishingFountain", st.commit(), stone, Transform3D(Basis.IDENTITY, origin))
	node.set_meta("landmark", "Wishing Fountain")
	# Water: three pools and the sheets spilling from the two upper bowls.
	var water := ShaderMaterial.new()
	water.shader = WATER_SHADER
	var pools := SurfaceTool.new()
	pools.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pool in [[5.9, 1.25], [3.05, 5.03], [1.42, 7.72]]:
		PropKit.append_mesh(pools, PropKit.cylinder(0.5, 0.5, 24), Transform3D(Basis.from_scale(Vector3(pool[0] * 2.0, 0.04, pool[0] * 2.0)), Vector3(0, pool[1], 0)), Color.WHITE)
	pools.generate_normals()
	var pool_node := kit.single(parent, "FountainWater", pools.commit(), water, Transform3D(Basis.IDENTITY, origin))
	pool_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sheet := ShaderMaterial.new()
	sheet.shader = WATERFALL_SHADER
	sheet.set_shader_parameter("side_fade", 0.0)
	sheet.set_shader_parameter("speed", 1.4)
	sheet.set_shader_parameter("water_color", Color(0.7, 0.92, 1.0))
	sheet.set_shader_parameter("columns", 48.0)
	var sheets := ArrayMesh.new()
	for spill in [[3.25, 3.7, 5.0, 1.3], [1.6, 2.0, 7.75, 5.1]]:
		var cyl := PropKit.cylinder(spill[0], spill[1], 20)
		cyl.cap_top = false
		cyl.cap_bottom = false
		var arrays := cyl.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var height: float = spill[2] - spill[3]
		for v in verts.size():
			verts[v] = Vector3(verts[v].x, spill[3] + (verts[v].y + 0.5) * height, verts[v].z)
		arrays[Mesh.ARRAY_VERTEX] = verts
		sheets.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var sheet_node := kit.single(parent, "FountainSheets", sheets, sheet, Transform3D(Basis.IDENTITY, origin))
	sheet_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(_spray(origin + Vector3.UP * 8.4))
	return [water, sheet]


func _spray(at: Vector3) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 16.0
	process.initial_velocity_min = 6.0
	process.initial_velocity_max = 8.0
	process.gravity = Vector3(0, -9.8, 0)
	process.scale_min = 0.6
	process.scale_max = 1.2
	var draw := StandardMaterial3D.new()
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.albedo_color = Color(0.88, 0.97, 1.0, 0.85)
	draw.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw.billboard_keep_scale = true
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.28, 0.28)
	mesh.material = draw
	var particles := GPUParticles3D.new()
	particles.name = "FountainSpray"
	particles.amount = 160
	particles.lifetime = 1.6
	particles.preprocess = 1.6
	particles.process_material = process
	particles.draw_pass_1 = mesh
	particles.visibility_aabb = AABB(Vector3(-8, -10, -8), Vector3(16, 16, 16))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.position = at
	return particles


func _plan_stream() -> void:
	var i := field.index_of("Blossom Crown")
	var a0 := 0.4
	var a1 := PI * 0.97
	var n := 26
	for k in n + 1:
		var u := float(k) / n
		var a := lerpf(a0, a1, u) + 0.22 * sin(u * 8.0)
		var s := lerpf(0.18, 1.0, u)
		stream_points.append(field.top_point(i, a, s))
	reserved.append(Vector3(stream_points[0].x, stream_points[0].z, 4.0))


func _stream(parent: Node3D) -> Array[ShaderMaterial]:
	var water := ShaderMaterial.new()
	water.shader = WATER_SHADER
	water.set_shader_parameter("flow_speed", 0.35)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := 0.0
	var n := stream_points.size()
	var lefts := PackedVector3Array()
	var rights := PackedVector3Array()
	var vs := PackedFloat32Array()
	for k in n:
		var p := stream_points[k]
		var d := (stream_points[mini(k + 1, n - 1)] - stream_points[maxi(k - 1, 0)])
		var side := Vector3(-d.z, 0.0, d.x).normalized()
		var width := lerpf(1.2, 2.0, float(k) / (n - 1))
		var l := p + side * width
		var r := p - side * width
		l.y = field.surface_at(l.x, l.z) + 0.25 if is_finite(field.surface_at(l.x, l.z)) else p.y + 0.25
		r.y = field.surface_at(r.x, r.z) + 0.25 if is_finite(field.surface_at(r.x, r.z)) else p.y + 0.25
		lefts.append(l)
		rights.append(r)
		if k > 0:
			along += stream_points[k].distance_to(stream_points[k - 1])
		vs.append(along / 4.0)
	for k in n - 1:
		var quad := [[lefts[k], 0.0, vs[k]], [rights[k], 1.0, vs[k]], [rights[k + 1], 1.0, vs[k + 1]],
			[lefts[k], 0.0, vs[k]], [rights[k + 1], 1.0, vs[k + 1]], [lefts[k + 1], 0.0, vs[k + 1]]]
		for v in quad:
			st.set_uv(Vector2(v[1], v[2]))
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0])
	var node := kit.single(parent, "Stream", st.commit(), water, Transform3D.IDENTITY)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Waterfall off the rim, into a cloud bank far below.
	var lip := stream_points[n - 1]
	var out := Vector3(lip.x - stream_points[n - 2].x, 0.0, lip.z - stream_points[n - 2].z).normalized()
	var top := lip + out * 1.0 + Vector3.DOWN * 0.2
	var bottom := lip + out * 9.0 + Vector3.DOWN * 92.0
	var side := Vector3(-out.z, 0.0, out.x)
	var mat := ShaderMaterial.new()
	mat.shader = WATERFALL_SHADER
	mat.set_shader_parameter("speed", 0.7)
	mat.set_shader_parameter("water_color", Color(0.9, 0.98, 1.0))
	mat.set_shader_parameter("columns", 9.0)
	var curtain := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([top - side * 3.0, top + side * 3.0, bottom - side * 6.0, bottom + side * 6.0])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 3), Vector2(1, 3)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([out, out, out, out])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2])
	curtain.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var fall := kit.single(parent, "Waterfall", curtain, mat, Transform3D.IDENTITY)
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fall.set_meta("landmark", "Blossom Falls")
	for k in 6:
		var w := rng.randf_range(12.0, 20.0)
		clouds.append(PropKit.placed(bottom + side * rng.randf_range(-12.0, 12.0) + out * rng.randf_range(-6.0, 6.0) + Vector3.DOWN * w * 0.3,
			Vector3(w * 1.3, w * 0.5, w), rng.randf() * TAU))
	return [water, mat]


func _whirlwinds(parent: Node3D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SWIRL_SHADER
	var petals: Array[Transform3D] = []
	var bounds := AABB()
	var winds: Array = zone.get_meta("petal_whirlwinds")
	for w in winds:
		var c: Vector3 = w.centre
		var r: float = w.radius
		var h: float = w.height
		var box := AABB(c - Vector3(r, 0.0, r), Vector3(r * 2.0, h, r * 2.0))
		bounds = box if petals.is_empty() else bounds.merge(box)
		for k in 140:
			petals.append(Transform3D(Basis.from_scale(Vector3(r, h, r)), c))
	var node := kit.multimesh(parent, "PetalWhirlwinds", QuadMesh.new(), mat, petals, PackedColorArray(), "", false)
	node.custom_aabb = bounds
	node.set_meta("petal_whirlwinds", winds.size())
	return mat


func _fireflies(parent: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length() / 7.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, a * a))
	var texture := ImageTexture.create_from_image(image)
	for i in field.size():
		if field.radii[i] < 40.0:
			continue
		var process := ParticleProcessMaterial.new()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(field.radii[i] * 0.8, 4.0, field.radii[i] * 0.8)
		process.direction = Vector3.UP
		process.spread = 180.0
		process.initial_velocity_min = 0.2
		process.initial_velocity_max = 0.7
		process.gravity = Vector3.ZERO
		process.turbulence_enabled = true
		process.turbulence_noise_strength = 1.2
		process.turbulence_noise_scale = 6.0
		var draw := StandardMaterial3D.new()
		draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		draw.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		draw.albedo_color = Color(1.0, 1.0, 0.62)
		draw.albedo_texture = texture
		draw.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		draw.billboard_keep_scale = true
		var mesh := QuadMesh.new()
		mesh.size = Vector2(1.6, 1.6)
		mesh.material = draw
		var particles := GPUParticles3D.new()
		particles.name = "Fireflies%d" % i
		particles.amount = 60
		particles.lifetime = 6.0
		particles.preprocess = 6.0
		particles.process_material = process
		particles.draw_pass_1 = mesh
		particles.visibility_aabb = AABB(Vector3(-70, -12, -70), Vector3(140, 30, 140))
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles.position = Vector3(field.centres[i].x, field.tops[i] + 5.0, field.centres[i].y)
		particles.visible = false
		particles.emitting = false
		parent.add_child(particles)
		out.append(particles)
	return out
