class_name AmbienceZoneTracker
extends RefCounted
## Picks which zone's ambience plays from the world's zone weights at the
## listener's real altitude, so a floating zone (Heartbloom) fully replaces the
## ground zone under it. Hysteresis keeps it from flickering along borders.

## A new zone must outweigh the current one by this much to take over.
const HYSTERESIS := 0.1

var zone: StringName = &""


## Zone id for weights (indexed like ids). Returns the current zone, updated.
func update(weights: PackedFloat32Array, ids: Array[StringName]) -> StringName:
	var best := -1
	for i in weights.size():
		if best < 0 or weights[i] > weights[best]:
			best = i
	if best < 0:
		return zone
	var current := ids.find(zone)
	if current < 0 or weights[best] > weights[current] + HYSTERESIS:
		zone = ids[best]
	return zone


## Zone for a world position on map, with the altitude counted.
func update_at(map: WorldMap, at: Vector3) -> StringName:
	return update(map.layout.weights_at(at.x, at.z, at.y), ZoneLayout.ZONE_IDS)
