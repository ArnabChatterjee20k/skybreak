class_name ShatteredMesaVoxel
extends VoxelZone
## Shattered Mesa's voxel look-dev (docs/lookdev/shattered_mesa.md): a visual
## pass over the sim's truth. The ground is the baked TerrainHeightmap
## (TerrainShape._mesa), the hoodoos, boulders and arch keep the transforms
## ShatteredMesaProps makes with PropKit seed 4242; nothing here feeds the sim.

const VERSION := 1
const ZONE := preload("res://game/world/zones/shattered_mesa.tres")

var map: TerrainHeightmap
var zone: ZoneData
var terrain: MesaTerrain
var props: MesaProps


func _init() -> void:
	name = "ShatteredMesa"
	map = load(WorldMap.HEIGHTMAP_PATH)
	zone = ZONE


func build() -> void:
	var c := zone.centre
	terrain = MesaTerrain.new(map, c - zone.extent, c + zone.extent, Vector2(-1022, -1022),
		Vector2(1022, 1022))
	terrain.build(self)
	stats.merge(terrain.stats)
	props = MesaProps.new(self)
	props.build()
	stats.merge(props.stats)
	_bounce()


## Visible ground (the sim's: the floor mesh lies on the heightmap grid).
func ground_at(x: float, z: float) -> float:
	return map.ground_height_at(x, z)


## The sand lights the undersides: a warm unshadowed fill from below.
func _bounce() -> void:
	var light := DirectionalLight3D.new()
	light.name = "SandBounce"
	light.light_color = Color("#f0c8a0")
	light.light_energy = 0.32
	light.shadow_enabled = false
	light.light_specular = 0.0
	light.basis = Basis.looking_at(Vector3(0.25, 1.0, 0.15).normalized(), Vector3.FORWARD)
	add_child(light)
	set_meta("bounce", light)


func presets() -> Dictionary:
	var p := VoxelStage.PRESETS.duplicate(true)
	# High noon: hard white sun, cobalt zenith over a pale cool horizon, thin cool haze.
	p.day.sky_top = Color("#2A50B0")
	p.day.sky_horizon = Color("#BACCE4")
	p.day.sky_below = Color("#C8D0DC")
	p.day.cloud = Color("#ffffff")
	p.day.cloud_shadow = Color("#c4cee0")
	p.day.cloud_cover = 0.22
	p.day.sun_dir = Vector3(-0.35, -0.85, -0.4)
	p.day.sun_color = Color("#fff8ee")
	p.day.sun_energy = 2.4
	p.day.sun_size = 0.018
	p.day.rim_color = Color("#ffe6c8")
	p.day.rim_energy = 0.3
	p.day.ambient_color = Color("#b4b8c8")
	p.day.ambient_energy = 0.5
	p.day.fog_color = Color("#C8D0DC")
	p.day.fog_density = 0.0007
	p.day.exposure = 0.9
	p.day.lantern = 0.3
	# Dusk: low deep-orange sun, rose ambient, long shadows; fog stays neutral.
	p.dusk.sky_top = Color("#3a4a8c")
	p.dusk.sky_horizon = Color("#f2b47a")
	p.dusk.sky_below = Color("#d8b8a0")
	p.dusk.sun_dir = Vector3(-0.9, -0.24, -0.33)
	p.dusk.sun_color = Color("#ffb070")
	p.dusk.sun_energy = 2.3
	p.dusk.sun_size = 0.05
	p.dusk.ambient_color = Color("#a08ea8")
	p.dusk.fog_color = Color("#d8c4b8")
	p.dusk.fog_density = 0.0008
	# Night: cool moonlight, fog kept off violet.
	p.night.sky_horizon = Color("#2c3a5c")
	p.night.fog_color = Color("#283448")
	p.night.sky_below = Color("#202a3c")
	return p


func shots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var arch := props.arch_centre
	var ay := props.arch_base_y
	var f := props.arch_forward
	var side := Vector3(-f.z, 0, f.x)
	var all := ["day", "dusk", "night"]
	# The key image: the Red Arch at noon from the sand, Kael under it.
	var k := Vector2(arch.x, arch.z) + Vector2(f.x, f.z) * 9.0 + Vector2(side.x, side.z) * 4.0
	var from := arch + f * 70.0 - side * 26.0 + Vector3(0, 0, 0)
	from.y = ground_at(from.x, from.z) + 3.0
	out.append({"name": "red_arch", "from": from, "at": arch + Vector3(0, 30, 0) + side * 4.0, "fov": 62.0,
		"kael": [k, atan2(f.x, f.z)], "times": all})
	# The hoodoo field from the floor, Kael beside a hoodoo, the cluster behind.
	var hd: Transform3D = props.hoodoo_hero
	var hp := Vector2(hd.origin.x, hd.origin.z)
	var away := (hp - Vector2(470, 760)).normalized()
	var kh := hp + away.rotated(0.35) * (props.hoodoo_hero_r + 2.5)
	var hcam := hp + away.rotated(0.55) * (props.hoodoo_hero_r + 19.0)
	var hfrom := _clear(Vector3(hcam.x, 0, hcam.y), Vector3(hp.x, 0, hp.y), 1.9)
	out.append({"name": "hoodoo_field", "from": hfrom,
		"at": Vector3(hp.x, ground_at(hp.x, hp.y) + 11.0, hp.y) - Vector3(away.x, 0, away.y) * 12.0, "fov": 62.0,
		"kael": [kh, atan2(hfrom.x - kh.x, hfrom.z - kh.y) + 0.4], "times": ["day", "dusk"]})
	# The Anvil Mesa's top: the surveyor's camp, Kael beside it, looking toward the arch.
	var camp: Vector3 = props.camp_at
	var to_arch := (Vector2(arch.x, arch.z) - Vector2(camp.x, camp.z)).normalized()
	var cam2 := Vector2(camp.x, camp.z) - to_arch * 8.0 + to_arch.orthogonal() * 2.0
	var kc := Vector2(camp.x, camp.z) - to_arch * 3.6 + to_arch.orthogonal() * 0.6
	out.append({"name": "anvil_camp", "from": Vector3(cam2.x, camp.y + 1.7, cam2.y),
		"at": Vector3(camp.x, camp.y + 1.0, camp.z) + Vector3(to_arch.x, 0, to_arch.y) * 1.0 + Vector3(to_arch.orthogonal().x, 0, to_arch.orthogonal().y) * 1.2, "fov": 55.0,
		"kael": [kc, atan2(-to_arch.x, -to_arch.y) + 0.5], "times": ["day", "dusk", "night"]})
	# Story corners: the petroglyph boulder, the well, the fallen hoodoo.
	var pg: Vector3 = get_meta("petroglyphs")
	var pf: Vector3 = get_meta("petroglyph_face")
	out.append({"name": "petroglyphs", "from": pg + pf * 5.2 + Vector3(0, 1.5, 0) + Vector3(-pf.z, 0, pf.x) * 1.2,
		"at": pg + Vector3(0, 1.0, 0), "fov": 50.0, "times": ["day"]})
	var wl: Vector3 = get_meta("well")
	out.append({"name": "well", "from": wl + Vector3(4.6, 2.3, 3.8), "at": wl + Vector3(0, 0.5, 0), "fov": 50.0,
		"kael": [Vector2(wl.x - 2.2, wl.z + 2.3), PI * 0.2], "times": ["day"]})
	var fh: Vector3 = get_meta("fallen_hoodoo")
	out.append({"name": "fallen_hoodoo", "from": fh + Vector3(-6, 4.5, 18), "at": fh + Vector3(4, 1.5, 0), "fov": 55.0,
		"times": ["day"]})
	# Overview from above the plateau: the Great Mesa, the Anvil, the arch, the field.
	out.append({"name": "overview", "from": Vector3(900, 230, 820), "at": Vector3(560, 40, 470), "fov": 55.0,
		"times": all})
	# Gameplay-ish camera at the spawn: Kael on the sand against a mesa wall.
	var sp := Vector2(zone.spawn_points[0].x, zone.spawn_points[0].z)
	var gy := ground_at(sp.x, sp.y)
	out.append({"name": "spawn_gameplay", "from": Vector3(sp.x + 5.5, gy + 3.2, sp.y + 4.0),
		"at": Vector3(sp.x - 4.0, gy + 4.0, sp.y - 6.0), "fov": 60.0, "kael": [sp, PI * 1.2], "times": all})
	return out


## A camera spot near `from` (rotated about `at`) clear of hoodoos and boulders, `up` m over the ground.
func _clear(from: Vector3, at: Vector3, up: float) -> Vector3:
	for k in 24:
		var o := Vector2(from.x - at.x, from.z - at.z).rotated(0.13 * float(k) * (1.0 if k % 2 == 0 else -1.0))
		var p := Vector3(at.x + o.x, 0, at.z + o.y)
		p.y = ground_at(p.x, p.z) + up
		if props.camera_clear(p):
			return p
	return Vector3(from.x, ground_at(from.x, from.z) + up, from.z)


## A 20 s flight: low between the hoodoos in the south-west cluster, up the
## open lane between the mesas, through the Red Arch, over the next mesa and
## round the Anvil Mesa's camp, ending on the Great Mesa. Heights follow the
## ground (clearance over the highest ground within 12 m); the path is checked
## against the hoodoos by flight_check.gd.
func flight() -> Array[Dictionary]:
	var arch := props.arch_centre
	var f := props.arch_forward
	var camp: Vector3 = props.camp_at
	var gap := arch + Vector3(0, 27, 0)
	var route := [
		[Vector2(452, 742), 5.0], [Vector2(470, 672), 6.0], [Vector2(540, 632), 10.0], [Vector2(598, 598), 9.0],
		[Vector2(594, 515), 11.0], [Vector2(600, 445), 14.0], [Vector2(gap.x + f.x * 60.0, gap.z + f.z * 60.0), 0.0],
		[Vector2(gap.x, gap.z), 0.0], [Vector2(gap.x - f.x * 45.0, gap.z - f.z * 45.0), 0.0], [Vector2(645, 342), 16.0],
		[Vector2(694, 352), 42.0], [Vector2(camp.x + 14.0, camp.z - 34.0), 20.0], [Vector2(camp.x - 22.0, camp.z + 6.0), 12.0],
		[Vector2(camp.x - 60.0, camp.z + 70.0), 60.0], [Vector2(530, 525), 70.0],
	]
	var out: Array[Dictionary] = []
	for i in route.size():
		var xz: Vector2 = route[i][0]
		var y := _lift(xz, route[i][1])
		if i >= 6 and i <= 8:
			y = gap.y + (2.0 if i == 6 else 0.0)
		out.append({"from": Vector3(xz.x, y, xz.y), "fov": 64.0})
	for i in out.size():
		var ahead: Vector3 = out[mini(i + 2, out.size() - 1)].from
		var nxt: Vector3 = out[mini(i + 1, out.size() - 1)].from
		var at: Vector3 = (ahead + nxt) * 0.5 + Vector3(0, -2.0, 0)
		if i >= 5 and i <= 7:
			at = gap - f * 60.0
		elif i >= 8 and i <= 10:
			at.y = minf(at.y, out[i].from.y - 4.0)
		elif i == 11 or i == 12:
			at = camp + Vector3(0, 1, 0)
		elif i >= 13:
			at = Vector3(400, 92, 540)
		if (at - out[i].from).length() < 5.0:
			at = out[i].from + (out[i].from - out[maxi(i - 1, 0)].from)
		out[i]["at"] = at
	return out


## Height for a flight point: `clear` m over the highest ground within 12 m.
func _lift(xz: Vector2, clear: float) -> float:
	var top := ground_at(xz.x, xz.y)
	for k in 8:
		var o := Vector2.from_angle(k * TAU / 8.0) * 12.0
		top = maxf(top, ground_at(xz.x + o.x, xz.y + o.y))
	return top + clear


func flight_kael() -> Array:
	var camp: Vector3 = props.camp_at
	var to_arch := (Vector2(props.arch_centre.x, props.arch_centre.z) - Vector2(camp.x, camp.z)).normalized()
	var k := Vector2(camp.x, camp.z) + to_arch.orthogonal() * -2.6 + to_arch * 1.5
	return [k, atan2(to_arch.x, to_arch.y)]


func animate(t: float) -> void:
	if props != null:
		props.animate(t)
