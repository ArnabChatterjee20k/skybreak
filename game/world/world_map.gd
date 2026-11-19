class_name WorldMap
extends Node3D
## The world map: 2 km terrain with six fighting zones, props, boundary dome and
## atmosphere. A drop-in level background; read-only queries for gameplay below.

const HEIGHTMAP_PATH := "res://game/world/terrain/terrain_heightmap.res"
const SKY_SHADER := preload("res://game/world/shaders/world_sky.gdshader")
const PLANE_SHADERS := {
	"water": preload("res://game/world/shaders/water.gdshader"),
	"lava": preload("res://game/world/shaders/lava.gdshader"),
	"clouds": preload("res://game/world/shaders/cloud_sea.gdshader"),
}
const PROP_SEED := 4242
## Spawn points sit at least this far above the ground.
const SPAWN_CLEARANCE := 2.0
## Props keep this far from spawn points.
const SPAWN_CLEAR_RADIUS := 26.0
## Day / dusk / night brightness for unshaded surfaces (water, clouds, waterfall).
const UNSHADED_LEVELS: Array[float] = [1.0, 0.8, 0.38]

@export var start_time_of_day := WorldAtmosphere.TimeOfDay.DAY

var heightmap: TerrainHeightmap
var layout: ZoneLayout
var unshaded_materials: Array[ShaderMaterial] = []
var _night_materials: Array[ShaderMaterial] = []

@onready var environment_node: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var terrain: WorldTerrain = $Terrain
@onready var props: Node3D = $Props
@onready var boundary: WorldBoundary = $Boundary
@onready var atmosphere: WorldAtmosphere = $Atmosphere


func _ready() -> void:
	heightmap = load(HEIGHTMAP_PATH)
	layout = ZoneLayout.load_default()
	terrain.build(heightmap, layout.zones)
	_build_props()
	_build_planes()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	environment_node.environment.sky.sky_material = sky_material
	atmosphere.setup(layout, environment_node.environment, sun, sky_material)
	atmosphere.night_materials.append_array(_night_materials)
	set_time_of_day(start_time_of_day)
	var focus := spawn_points(&"stormfall_city")[0]
	atmosphere.apply_at(focus)


## Playable volume: the dome walls and the ceiling.
func bounds() -> AABB:
	return WorldBoundary.bounds()


## Bilinear ground height at world (x, z), from the baked heightmap.
func ground_height_at(x: float, z: float) -> float:
	return heightmap.ground_height_at(x, z)


func zone_at(x: float, z: float) -> ZoneData:
	return layout.zones[layout.index_at(x, z)]


func zone_ids() -> Array[StringName]:
	return ZoneLayout.ZONE_IDS.duplicate()


func zone(zone_id: StringName) -> ZoneData:
	var i := layout.index_of(zone_id)
	return layout.zones[i] if i >= 0 else null


## Two fighter spawn points about 40 m apart, above the ground.
func spawn_points(zone_id: StringName) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var data := zone(zone_id)
	if data == null:
		return out
	for p in data.spawn_points:
		out.append(Vector3(p.x, maxf(p.y, ground_height_at(p.x, p.z) + SPAWN_CLEARANCE), p.z))
	return out


func set_time_of_day(id: int) -> void:
	atmosphere.set_time_of_day(id)
	for material in unshaded_materials:
		material.set_shader_parameter("light_level", UNSHADED_LEVELS[atmosphere.time_of_day])


## Overview (top-down map) mode: whole map drawn, no distance culling, no fog.
func set_overview(enabled: bool) -> void:
	terrain.set_overview(enabled)
	environment_node.environment.fog_enabled = not enabled
	for node in props.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		gi.visibility_range_end = 0.0 if enabled else PropKit.PROP_VISIBILITY_END



func _build_props() -> void:
	var kit := PropKit.new(heightmap, PROP_SEED)
	for zone_data in layout.zones:
		for p in zone_data.spawn_points:
			kit.keep_clear.append(Vector3(p.x, p.z, SPAWN_CLEAR_RADIUS))
	for zone_data in layout.zones:
		var group := Node3D.new()
		group.name = zone_data.display_name.replace(" ", "")
		group.set_meta("zone_id", zone_data.id)
		props.add_child(group)
		match zone_data.id:
			&"shattered_mesa":
				ShatteredMesaProps.build(group, kit, zone_data, layout)
			&"skyhold_ruins":
				SkyholdRuinsProps.build(group, kit, zone_data, layout)
			&"stormfall_city":
				StormfallCityProps.build(group, kit, zone_data, layout)
			&"frozen_peaks":
				FrozenPeaksProps.build(group, kit, zone_data, layout)
			&"verdant_falls":
				unshaded_materials.append_array(VerdantFallsProps.build(group, kit, zone_data, layout))
			&"ember_rift":
				EmberRiftProps.build(group, kit, zone_data, layout)
	_night_materials = kit.night_materials


# Lake, lava and cloud sea: one plane each over its zone, masked by the zone weight
# and an optional clip radius around the plane centre.
func _build_planes() -> void:
	var specs := [
		["Lake", "water", &"verdant_falls", 0.0, Vector2(-20, -20), Vector2(460, 380), 230.0],
		["Lava", "lava", &"ember_rift", 31.0, Vector2.ZERO, Vector2(640, 640), 215.0],
		["CloudSea", "clouds", &"skyhold_ruins", 40.0, Vector2.ZERO, Vector2(900, 1000), 1.0e6],
	]
	var height_texture: Texture2D = terrain.materials[0].get_shader_parameter("heightmap")
	var weights_a: Texture2D = terrain.materials[0].get_shader_parameter("zone_weights_a")
	var weights_b: Texture2D = terrain.materials[0].get_shader_parameter("zone_weights_b")
	for spec in specs:
		var zone_data := zone(spec[2])
		var material := ShaderMaterial.new()
		material.shader = PLANE_SHADERS[spec[1]]
		material.set_shader_parameter("heightmap", height_texture)
		material.set_shader_parameter("zone_weights_a", weights_a)
		material.set_shader_parameter("zone_weights_b", weights_b)
		material.set_shader_parameter("map_origin", heightmap.origin)
		material.set_shader_parameter("cell_size", heightmap.cell_size)
		material.set_shader_parameter("map_samples", heightmap.size)
		material.set_shader_parameter("weight_samples", heightmap.weights_size)
		material.set_shader_parameter("zone_index", layout.index_of(spec[2]))
		var centre: Vector2 = zone_data.centre + spec[4]
		material.set_shader_parameter("clip_circle", Vector3(centre.x, centre.y, spec[6]))
		var mesh := PlaneMesh.new()
		mesh.size = spec[5]
		var node := MeshInstance3D.new()
		node.name = spec[0]
		node.mesh = mesh
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = PropKit.PROP_VISIBILITY_END
		node.position = Vector3(centre.x, spec[3], centre.y)
		props.add_child(node)
		if spec[1] != "lava":
			unshaded_materials.append(material)
		if spec[1] == "lava":
			node.set_meta("hazard", "lava")
