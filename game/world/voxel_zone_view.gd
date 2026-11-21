class_name VoxelZoneView
extends Node3D
## The voxel look of one zone in a match (Voxel art style): builds the zone's
## VoxelZone builder and its VoxelStage as siblings under this node (zones look
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
## Per quality: LOD range scale (smaller = coarser tiers sooner), shadow atlas,
## soft shadow filter, sun shadow distance (m), blended splits, SSAO.
const QUALITY := {
	GraphicsSettings.Quality.LOW: {
		"lod_scale": 0.6, "atlas": 2048, "filter": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"shadow_distance": 100.0, "blend_splits": false, "ssao": false, "far_tier_shadows": false,
	},
	GraphicsSettings.Quality.MEDIUM: {
		"lod_scale": 0.8, "atlas": 4096, "filter": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"shadow_distance": 150.0, "blend_splits": true, "ssao": true, "far_tier_shadows": true,
	},
	GraphicsSettings.Quality.HIGH: {
		"lod_scale": 1.0, "atlas": 4096, "filter": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		"shadow_distance": 180.0, "blend_splits": true, "ssao": true, "far_tier_shadows": true,
	},
}

## The builder that draws each zone (starts as BUILDERS; tests swap in stand-ins).
static var builders := BUILDERS.duplicate()

var zone_id: StringName
var zone: VoxelZone
var stage: VoxelStage
var quality: GraphicsSettings.Quality = GraphicsSettings.Quality.HIGH
## Milliseconds the zone's build() took.
var build_ms := 0
var _clock := 0.0


static func supports(id: StringName) -> bool:
	return builders.has(id)


## Builds the zone and its stage; call after adding this node to the tree.
func build(id: StringName, tier: GraphicsSettings.Quality = GraphicsSettings.Quality.HIGH) -> void:
	show_zone((load(builders[id]) as GDScript).new() as VoxelZone, id, tier)


## Builds a given VoxelZone (not yet in the tree) and its stage under this node.
func show_zone(built: VoxelZone, id: StringName, tier: GraphicsSettings.Quality) -> void:
	zone_id = id
	quality = tier
	name = "VoxelZone"
	var t := Time.get_ticks_msec()
	zone = built
	add_child(zone)
	zone.build()
	build_ms = Time.get_ticks_msec() - t
	stage = VoxelStage.new()
	stage.name = "Stage"
	add_child(stage)
	stage.setup(zone.presets(), zone.cloud_sea())
	stage.lantern_materials = zone.lantern_materials
	stage.apply(HERO_PRESETS.get(id, "day"))
	apply_quality(tier)
	zone.animate(0.0)


## The quality tier's LOD ranges and shadows (WEB counts as LOW, with the kit's WEB sun).
func apply_quality(tier: GraphicsSettings.Quality) -> void:
	var values: Dictionary = QUALITY.get(tier, QUALITY[GraphicsSettings.Quality.LOW])
	RenderingServer.directional_soft_shadow_filter_set_quality(values.filter)
	RenderingServer.directional_shadow_atlas_set_size(values.atlas, true)
	stage.sun.directional_shadow_max_distance = values.shadow_distance
	stage.sun.directional_shadow_blend_splits = values.blend_splits
	stage.env.ssao_enabled = values.ssao
	if tier == GraphicsSettings.Quality.WEB:
		# The kit's web sun: one shadow split (one shadow pass on Compatibility), 80 m.
		stage.apply_quality(tier)
		RenderingServer.directional_soft_shadow_filter_set_quality(values.filter)
	scale_lod_ranges(zone, values.lod_scale, values.far_tier_shadows)


## Scales every visibility range under root by k (tiers that chain end-to-begin
## stay seamless); without far_tier_shadows, only the nearest tiers cast shadows.
static func scale_lod_ranges(root: Node, k: float, far_tier_shadows := true) -> void:
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		gi.visibility_range_begin *= k
		gi.visibility_range_end *= k
		gi.visibility_range_begin_margin *= k
		gi.visibility_range_end_margin *= k
		if not far_tier_shadows and gi.visibility_range_begin > 0.0:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
