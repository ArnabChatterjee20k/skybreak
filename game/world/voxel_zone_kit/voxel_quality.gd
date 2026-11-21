class_name VoxelQuality
extends RefCounted
## Per-tier costs of a voxel zone, read by the kit while a zone builds
## (VoxelProp.place, VoxelHeightfield.build) and by VoxelStage.apply_quality.
## Tiers are GraphicsSettings.Quality. HIGH and MEDIUM keep the look: they only
## change what can't be seen at gameplay distance. LOW and WEB trade detail.
##   VoxelQuality.tier = GraphicsSettings.Quality.MEDIUM   # before zone.build()

## The tier zones build at: WEB in a web build, else the player's saved quality.
static var tier: GraphicsSettings.Quality = GraphicsSettings.load_saved().quality

## range_scale: prop LOD ranges (where each tier ends) are multiplied by it.
## clutter_size: props whose mesh is smaller than this (m, longest side)
## never cast shadows. shadow_tiers: at most this many of a prop's finest
## tiers cast (0 = as the zone asks). shadow_distance (m), shadow_splits,
## near_split (m, the first split's far edge), shadow_atlas (px): the sun.
## terrain_chunk: heightfield chunk side (m). ssao: screen-space AO.
## clutter_range: scale on ranges of props that end under 60 m (scatter).
const VALUES := {
	GraphicsSettings.Quality.HIGH: {
		"range_scale": 1.0, "clutter_range": 1.0, "clutter_size": 0.0, "shadow_tiers": 0,
		"shadow_distance": 180.0, "shadow_splits": 2, "near_split": 32.4, "shadow_atlas": 4096,
		"terrain_chunk": 32.0, "ssao": true,
	},
	GraphicsSettings.Quality.MEDIUM: {
		"range_scale": 1.0, "clutter_range": 1.0, "clutter_size": 0.6, "shadow_tiers": 0,
		"shadow_distance": 150.0, "shadow_splits": 2, "near_split": 32.4, "shadow_atlas": 4096,
		"terrain_chunk": 32.0, "ssao": true,
	},
	GraphicsSettings.Quality.LOW: {
		"range_scale": 0.75, "clutter_range": 0.7, "clutter_size": 1.5, "shadow_tiers": 1,
		"shadow_distance": 110.0, "shadow_splits": 2, "near_split": 28.0, "shadow_atlas": 2048,
		"terrain_chunk": 96.0, "ssao": true,
	},
	GraphicsSettings.Quality.WEB: {
		"range_scale": 0.6, "clutter_range": 0.5, "clutter_size": 3.0, "shadow_tiers": 1,
		"shadow_distance": 80.0, "shadow_splits": 1, "near_split": 80.0, "shadow_atlas": 2048,
		"terrain_chunk": 128.0, "ssao": false,
	},
}


static func value(key: String) -> Variant:
	return VALUES[tier][key]


## Tier names as the benchmark and the command line spell them.
static func from_name(tier_name: String) -> GraphicsSettings.Quality:
	return GraphicsSettings.Quality[tier_name.to_upper()]
