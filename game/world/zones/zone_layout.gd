class_name ZoneLayout
extends RefCounted
## Which zone owns each map point, and the blend weights across ~100 m borders.
## Pure math on the zone centres: same input, same output, on CPU and in bakes.

const ZONE_DIR := "res://game/world/zones/"
const ZONE_IDS: Array[StringName] = [
	&"shattered_mesa", &"skyhold_ruins", &"stormfall_city",
	&"frozen_peaks", &"verdant_falls", &"ember_rift",
]
## Width (m) of the blend band across a border.
const BORDER_WIDTH := 100.0
## Amplitude (m) of the border wobble so borders aren't straight lines.
const BORDER_WOBBLE := 45.0

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
	for zone in zones:
		_centres.append(zone.centre)


func index_of(zone_id: StringName) -> int:
	return ZONE_IDS.find(zone_id)


## Distance to each zone centre, plus a smooth deterministic wobble per zone.
func _warped_distances(x: float, z: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_centres.size())
	for i in _centres.size():
		var c := _centres[i]
		var wobble := sin(x * 0.0071 + float(i) * 1.7) * cos(z * 0.0053 + float(i) * 0.9) \
			+ 0.5 * sin((x + z) * 0.013 + float(i) * 2.3)
		out[i] = Vector2(x - c.x, z - c.y).length() + wobble * BORDER_WOBBLE
	return out


## Index of the zone that owns (x, z).
func index_at(x: float, z: float) -> int:
	var d := _warped_distances(x, z)
	var best := 0
	for i in range(1, d.size()):
		if d[i] < d[best]:
			best = i
	return best


## Blend weights per zone at (x, z); they sum to 1 and are continuous in x and z.
func weights_at(x: float, z: float) -> PackedFloat32Array:
	var d := _warped_distances(x, z)
	var nearest := d[0]
	for value in d:
		nearest = minf(nearest, value)
	var w := PackedFloat32Array()
	w.resize(d.size())
	var total := 0.0
	for i in d.size():
		var t := clampf(1.0 - (d[i] - nearest) / BORDER_WIDTH, 0.0, 1.0)
		w[i] = t * t * (3.0 - 2.0 * t)
		total += w[i]
	for i in w.size():
		w[i] /= total
	return w
