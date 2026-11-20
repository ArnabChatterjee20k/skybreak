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
	map = load(WorldMap.HEIGHTMAP_PATH)
	zone = ZONE


func build() -> void:
	var c := zone.centre
	terrain = MesaTerrain.new(map, c - zone.extent, c + zone.extent, c - Vector2(720, 700),
		Vector2(1012, 1012))
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
	p.day.fog_density = 0.0011
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
	p.dusk.fog_density = 0.0012
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
	# The hoodoo field from the floor, Kael beside a hoodoo.
	var hd: Transform3D = props.hoodoo_hero
	var hp := Vector2(hd.origin.x, hd.origin.z)
	var away := (hp - Vector2(560, 700)).normalized()
	var kh := hp + away.rotated(0.9) * (props.hoodoo_hero_r + 3.0)
	var hcam := kh + away.rotated(0.9) * 16.0 + away.rotated(2.4) * 9.0
	out.append({"name": "hoodoo_field", "from": Vector3(hcam.x, ground_at(hcam.x, hcam.y) + 2.4, hcam.y),
		"at": Vector3(kh.x, ground_at(kh.x, kh.y) + 9.0, kh.y) - Vector3(away.x, 0, away.y) * 8.0, "fov": 60.0,
		"kael": [kh, atan2(away.rotated(0.9).x, away.rotated(0.9).y)], "times": ["day", "dusk"]})
	# The Anvil Mesa's top: the surveyor's camp, Kael beside it, the arch beyond.
	var camp: Vector3 = props.camp_at
	var to_arch := (Vector2(arch.x, arch.z) - Vector2(camp.x, camp.z)).normalized()
	var cam2 := Vector2(camp.x, camp.z) - to_arch * 11.0 + to_arch.orthogonal() * 5.0
	var kc := Vector2(camp.x, camp.z) + to_arch.orthogonal() * -2.6 + to_arch * 1.5
	out.append({"name": "anvil_camp", "from": Vector3(cam2.x, camp.y + 3.2, cam2.y),
		"at": Vector3(camp.x, camp.y + 0.6, camp.z) + Vector3(to_arch.x, 0, to_arch.y) * 6.0, "fov": 60.0,
		"kael": [kc, atan2(to_arch.x, to_arch.y)], "times": ["day", "dusk"]})
	# Overview from above the plateau: the Great Mesa, the Anvil, the arch, the field.
	out.append({"name": "overview", "from": Vector3(900, 230, 820), "at": Vector3(560, 40, 470), "fov": 55.0,
		"times": all})
	# Gameplay-ish camera at the spawn: Kael on the sand against a mesa wall.
	var sp := Vector2(zone.spawn_points[0].x, zone.spawn_points[0].z)
	var gy := ground_at(sp.x, sp.y)
	out.append({"name": "spawn_gameplay", "from": Vector3(sp.x + 5.5, gy + 3.2, sp.y + 4.0),
		"at": Vector3(sp.x - 4.0, gy + 4.0, sp.y - 6.0), "fov": 60.0, "kael": [sp, PI * 1.2], "times": all})
	return out


## A 20 s flight: low across the sand through the hoodoo field, up and through
## the Red Arch, over the Anvil Mesa's camp, out over the Great Mesa.
func flight() -> Array[Dictionary]:
	var arch := props.arch_centre
	var f := props.arch_forward
	var camp: Vector3 = props.camp_at
	var gap := arch + Vector3(0, 26, 0)
	return [
		{"from": Vector3(600, 24, 790), "at": Vector3(560, 26, 640), "fov": 62.0},
		{"from": Vector3(582, 22, 720), "at": Vector3(555, 24, 600), "fov": 62.0},
		{"from": Vector3(560, 24, 650), "at": Vector3(560, 28, 520), "fov": 62.0},
		{"from": Vector3(560, 30, 575), "at": gap + f * 30.0, "fov": 62.0},
		{"from": gap + f * 85.0, "at": gap, "fov": 62.0},
		{"from": gap + f * 30.0, "at": gap - f * 40.0, "fov": 64.0},
		{"from": gap - f * 30.0 + Vector3(0, 6, 0), "at": camp + Vector3(0, 10, 0), "fov": 62.0},
		{"from": camp + Vector3(-60, 40, -70), "at": camp, "fov": 58.0},
		{"from": camp + Vector3(-14, 18, -12), "at": camp + Vector3(0, 1, 0), "fov": 58.0},
		{"from": camp + Vector3(-70, 30, 30), "at": Vector3(400, 90, 540), "fov": 58.0},
		{"from": Vector3(480, 140, 520), "at": Vector3(400, 96, 540), "fov": 58.0},
		{"from": Vector3(430, 170, 600), "at": Vector3(330, 90, 480), "fov": 58.0},
	]


func flight_kael() -> Array:
	var camp: Vector3 = props.camp_at
	return [Vector2(camp.x - 2.0, camp.z + 1.5), PI * 0.6]


func animate(t: float) -> void:
	if props != null:
		props.animate(t)
