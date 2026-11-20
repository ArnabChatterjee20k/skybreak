class_name ZoneData
extends Resource
## One fighting zone of the world map: layout, look per time of day, spawns and landmarks.
## Per-time-of-day arrays are indexed by WorldAtmosphere.TimeOfDay (day, dusk, night).
## Zone gameplay markers live in metadata (see heartbloom_gardens.tres): `petal_whirlwinds`
## and `wishing_fountain`.

## Distance between the two fallback spawns (see fighter_spawns).
const FALLBACK_SPAWN_GAP := 40.0

@export var id: StringName
@export var display_name: String
## Layout centre on the map (x, z) and rough half-size; borders come from ZoneLayout.
@export var centre := Vector2.ZERO
@export var extent := Vector2(350.0, 450.0)
## Floating zones only: the altitude (m) where the zone starts blending in (x) and
## fully owns the air (y). Zero for ground zones.
@export var altitude_band := Vector2.ZERO

@export_group("Terrain colours")
@export var ground_low := Color(0.5, 0.5, 0.5)
@export var ground_high := Color(0.7, 0.7, 0.7)
@export var rock := Color(0.4, 0.4, 0.4)
## Height range (m) the low-to-high ramp spans.
@export var ramp_heights := Vector2(0.0, 100.0)
## 0..1: horizontal rock strata on slopes.
@export var strata := 0.5
## Ground pattern drawn by the terrain shader.
@export_enum("none", "streets", "sastrugi", "cracks", "grass", "basalt") var ground_pattern := 0

@export_group("Atmosphere")
@export var fog_colors: PackedColorArray = [Color(0.7, 0.8, 0.9), Color(0.9, 0.6, 0.5), Color(0.1, 0.12, 0.2)]
## 0..1: 0 = clear air (fog ends ~1.2 km), 1 = storm (fog ends ~450 m).
@export var fog_density := 0.2
@export var sun_directions: PackedVector3Array = [Vector3(-0.4, -0.8, -0.4), Vector3(-0.8, -0.25, -0.3), Vector3(0.3, -0.7, 0.5)]
@export var sun_colors: PackedColorArray = [Color(1, 0.96, 0.9), Color(1, 0.6, 0.4), Color(0.55, 0.65, 1)]
@export var sun_energies: PackedFloat32Array = [1.2, 0.9, 0.35]
@export var ambient_colors: PackedColorArray = [Color(0.55, 0.6, 0.7), Color(0.55, 0.42, 0.45), Color(0.15, 0.18, 0.3)]
@export var sky_top_colors: PackedColorArray = [Color(0.25, 0.45, 0.85), Color(0.3, 0.25, 0.5), Color(0.02, 0.03, 0.08)]
@export var sky_horizon_colors: PackedColorArray = [Color(0.7, 0.8, 0.95), Color(0.95, 0.55, 0.35), Color(0.08, 0.1, 0.2)]
@export_enum("clear", "rain", "snow", "embers", "petals") var weather := 0
## Tonemap exposure per time of day; below 1 keeps bright zones (snow) off white.
@export var exposures: PackedFloat32Array = [1.0, 1.0, 1.0]
## Rim light on the fighters only (not the world), per time of day.
@export var rim_colors: PackedColorArray = [Color(1.0, 0.9, 0.75), Color(1.0, 0.7, 0.5), Color(0.6, 0.75, 1.0)]
@export var rim_energies: PackedFloat32Array = [0.6, 0.6, 0.5]
## Rim light direction relative to the camera: degrees around from straight behind the
## fighters (x) and degrees down from level (y).
@export var rim_angles := Vector2(35.0, 30.0)

@export_group("Gameplay")
## Two spawn points about 40 m apart; y is a minimum, raised above the ground if needed.
@export var spawn_points: PackedVector3Array = []
@export var landmark_names: PackedStringArray = []
@export var landmark_positions: PackedVector3Array = []


## Spawn points, or two FALLBACK_SPAWN_GAP apart across the zone centre when the resource has
## fewer than two (an export that emptied its packed arrays, T-WEB2), so a match still starts.
func fighter_spawns() -> PackedVector3Array:
	if spawn_points.size() >= 2:
		return spawn_points
	push_warning("zone %s has %d spawn points, using two around its centre" % [id, spawn_points.size()])
	var base := spawn_points[0] if spawn_points.size() == 1 else Vector3(centre.x - FALLBACK_SPAWN_GAP * 0.5, 0.0, centre.y)
	return PackedVector3Array([base, base + Vector3(FALLBACK_SPAWN_GAP, 0.0, 0.0)])


func is_floating() -> bool:
	return altitude_band != Vector2.ZERO
