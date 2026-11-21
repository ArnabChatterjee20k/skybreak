class_name VoxelZoneView
extends Node3D
## The voxel look of one zone in a match (Voxel art style): loads the zone's
## offline bake for the quality tier (or builds its VoxelZone builder live when
## the bake is missing or stale) and its VoxelStage as siblings under this node (zones look
## for the stage among their siblings), drives the zone's animation, and hides
## the classic world's visuals. The classic WorldMap stays in the tree: the sim's
## ground, the camera's obstacles and the spawns still come from it. View-only.

## Builder per zone (VoxelZone scripts).
const BUILDERS := {
	&"heartbloom_gardens": "res://game/world/voxel_zones/heartbloom/heartbloom_voxel.gd",
	&"shattered_mesa": "res://game/world/zones_voxel/shattered_mesa/shattered_mesa_voxel.gd",
	&"skyhold_ruins": "res://game/world/zones_voxel/skyhold_ruins/skyhold_ruins_voxel.gd",
	&"stormfall_city": "res://game/world/zones_voxel/stormfall_city/stormfall_city_voxel.gd",
	&"frozen_peaks": "res://game/world/zones_voxel/frozen_peaks/frozen_peaks_voxel.gd",
	&"verdant_falls": "res://game/world/zones_voxel/verdant_falls/verdant_falls_voxel.gd",
	&"ember_rift": "res://game/world/zones_voxel/ember_rift/ember_rift_voxel.gd",
}
## Lighting preset per zone: its hero time of day (docs/lookdev/zones_overview.md).
const HERO_PRESETS := {
	&"heartbloom_gardens": "dusk",
	&"shattered_mesa": "day",
	&"skyhold_ruins": "day",
	&"stormfall_city": "night",
	&"frozen_peaks": "night",
	&"verdant_falls": "day",
	&"ember_rift": "night",
}
## Web tier: zone lamps fade out from this far (m).
const WEB_LIGHT_FADE := 60.0
## The builder that draws each zone (starts as BUILDERS; tests swap in stand-ins).
static var builders := BUILDERS.duplicate()

var zone_id: StringName
var zone: VoxelZone
var stage: VoxelStage
var quality: GraphicsSettings.Quality = GraphicsSettings.Quality.HIGH
## Milliseconds the zone took to appear (bake load or live build).
var build_ms := 0
## True when the zone came from its offline bake (VoxelZoneBake), false when built live.
var from_bake := false
var _clock := 0.0


static func supports(id: StringName) -> bool:
	return builders.has(id)


## Shows the zone and its stage; call after adding this node to the tree. Loads
## the zone's bake for the tier when it is current, else builds it live.
func build(id: StringName, tier: GraphicsSettings.Quality = GraphicsSettings.Quality.HIGH) -> void:
	var t := Time.get_ticks_msec()
	var why := []
	var baked := VoxelZoneBake.instantiate(id, tier, builders[id], why) if builders[id] == BUILDERS.get(id) else null
	if baked != null:
		show_baked(baked, id, tier)
	else:
		push_warning("VoxelZoneView: building %s live (%s); run tools/voxel_zone_bake.gd" % [id, why[0] if why else "no bake"])
		show_zone((load(builders[id]) as GDScript).new() as VoxelZone, id, tier)
	build_ms = Time.get_ticks_msec() - t


## Builds a given VoxelZone (not yet in the tree) at a tier, and its stage.
func show_zone(built: VoxelZone, id: StringName, tier: GraphicsSettings.Quality) -> void:
	_begin(id, tier)
	zone = built
	add_child(zone)
	var t := Time.get_ticks_msec()
	zone.build()
	build_ms = Time.get_ticks_msec() - t
	from_bake = false
	_finish()


## Shows an already built zone (a loaded bake, state restored) and its stage.
func show_baked(baked: VoxelZone, id: StringName, tier: GraphicsSettings.Quality) -> void:
	_begin(id, tier)
	zone = baked
	add_child(zone)
	from_bake = true
	_finish()


func _begin(id: StringName, tier: GraphicsSettings.Quality) -> void:
	zone_id = id
	quality = tier
	name = "VoxelZone"
	# The kit reads the tier while it builds (prop ranges, clutter shadows, chunks).
	VoxelQuality.tier = tier


func _finish() -> void:
	stage = VoxelStage.new()
	stage.name = "Stage"
	add_child(stage)
	stage.setup(zone.presets(), zone.cloud_sea())
	stage.lantern_materials = zone.lantern_materials
	stage.apply(HERO_PRESETS.get(zone_id, "day"))
	stage.apply_quality(quality)
	if quality == GraphicsSettings.Quality.WEB:
		light_tier(zone)
	zone.animate(0.0)


## The web tier's lights: zone lamps cast no shadows and fade out past
## WEB_LIGHT_FADE metres, so WebGL draws only the few near the fight.
static func light_tier(root: Node) -> void:
	for node in root.find_children("*", "Light3D", true, false):
		if node is OmniLight3D or node is SpotLight3D:
			var light := node as Light3D
			light.shadow_enabled = false
			light.distance_fade_enabled = true
			light.distance_fade_begin = WEB_LIGHT_FADE
			light.distance_fade_length = 10.0


## Hides the classic world's look (terrain, props, planes, sky, lights, weather)
## and stops its atmosphere; the nodes stay for the sim and the camera.
static func hide_classic(world: WorldMap) -> void:
	world.terrain.visible = false
	world.props.visible = false
	world.sun.visible = false
	world.rim_light.visible = false
	world.environment_node.environment = null
	world.atmosphere.set_process(false)
	for particles: Node in world.atmosphere.find_children("*", "GPUParticles3D", true, false):
		(particles as GPUParticles3D).emitting = false
		(particles as GPUParticles3D).visible = false


func _process(delta: float) -> void:
	if zone == null:
		return
	_clock += delta
	zone.animate(_clock)
