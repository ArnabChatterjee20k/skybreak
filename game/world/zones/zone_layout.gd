class_name ZoneLayout
extends RefCounted
## Which zone owns each map point, and the blend weights across ~100 m borders.
## Pure math on the zone centres: same input, same output, on CPU and in bakes.
## Ground zones split the map in 2D; a floating zone owns the air above its band.

const ZONE_DIR := "res://game/world/zones/"
const ZONE_IDS: Array[StringName] = [
	&"shattered_mesa", &"skyhold_ruins", &"stormfall_city",
	&"frozen_peaks", &"verdant_falls", &"ember_rift",
	&"heartbloom_gardens",
]
## The first six zones are on the ground; the terrain and its bake only know these.
const GROUND_ZONE_COUNT := 6
## Width (m) of the blend band across a border.
const BORDER_WIDTH := 100.0
## Amplitude (m) of the border wobble so borders aren't straight lines.
const BORDER_WOBBLE := 45.0
## Floating zones fade out over this outer fraction of their elliptical extent.
const FLOAT_EDGE := 0.22

var zones: Array[ZoneData] = []
var _centres := PackedVector2Array()


static func load_default() -> ZoneLayout:
	var layout := ZoneLayout.new()
	for zone_id in ZONE_IDS:
		layout.zones.append(load(ZONE_DIR + String(zone_id) + ".tres") as ZoneData)
	layout._cache()
	return layout


func _cache() -> void:
	_centres.clear()
	for i in GROUND_ZONE_COUNT:
		_centres.append(zones[i].centre)


func index_of(zone_id: StringName) -> int:
	return ZONE_IDS.find(zone_id)


func ground_zones() -> Array[ZoneData]:
	return zones.slice(0, GROUND_ZONE_COUNT)


## Distance to each ground zone centre, plus a smooth deterministic wobble per zone.
func _warped_distances(x: float, z: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_centres.size())
	for i in _centres.size():
		var c := _centres[i]
		var wobble := sin(x * 0.0071 + float(i) * 1.7) * cos(z * 0.0053 + float(i) * 0.9) \
			+ 0.5 * sin((x + z) * 0.013 + float(i) * 2.3)
		out[i] = Vector2(x - c.x, z - c.y).length() + wobble * BORDER_WOBBLE
	return out


## 0..1 ownership of floating zone `i` at (x, y, z): its ellipse times its altitude band.
func floating_weight(i: int, x: float, z: float, y: float) -> float:
	var zone := zones[i]
	if not zone.is_floating() or y <= zone.altitude_band.x:
		return 0.0
	var s := Vector2((x - zone.centre.x) / zone.extent.x, (z - zone.centre.y) / zone.extent.y).length()
	return _smooth(1.0, 1.0 - FLOAT_EDGE, s) * _smooth(zone.altitude_band.x, zone.altitude_band.y, y)


## Index of the zone that owns (x, z), at altitude `y` (default: on the ground).
func index_at(x: float, z: float, y: float = -INF) -> int:
	for i in range(GROUND_ZONE_COUNT, zones.size()):
		if floating_weight(i, x, z, y) >= 0.5:
			return i
	var d := _warped_distances(x, z)
	var best := 0
	for i in range(1, d.size()):
		if d[i] < d[best]:
			best = i
	return best


## Blend weights per zone at (x, z) and altitude `y`; they sum to 1 and are
## continuous in x, y and z. On the ground (default y) floating zones weigh 0.
func weights_at(x: float, z: float, y: float = -INF) -> PackedFloat32Array:
	var d := _warped_distances(x, z)
	var nearest := d[0]
	for value in d:
		nearest = minf(nearest, value)
	var w := PackedFloat32Array()
	w.resize(zones.size())
	var total := 0.0
	for i in d.size():
		var t := clampf(1.0 - (d[i] - nearest) / BORDER_WIDTH, 0.0, 1.0)
		w[i] = t * t * (3.0 - 2.0 * t)
		total += w[i]
	var air := 0.0
	for i in range(GROUND_ZONE_COUNT, zones.size()):
		w[i] = floating_weight(i, x, z, y)
		air += w[i]
	air = minf(air, 1.0)
	for i in d.size():
		w[i] = w[i] / total * (1.0 - air)
	return w


static func _smooth(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
