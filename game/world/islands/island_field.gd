class_name IslandField
extends RefCounted
## Floating islands as a second ground layer above the terrain. Pure math on authored
## data (no nodes, no randomness), so the sim can land fighters on them like on the
## heightmap. Each island has a gently domed top inside a wobbly round outline and a
## rocky cone underneath. The island meshes are built from these same functions.

## Heartbloom Gardens: name, centre (x, z), top height, radius, underside depth, outline phase.
const HEARTBLOOM := [
	["Heart Isle", Vector2(0, 0), 285.0, 64.0, 74.0, 0.0],
	["Wishing Isle", Vector2(-150, 72), 276.0, 44.0, 52.0, 1.3],
	["Lantern Rise", Vector2(152, 76), 280.0, 42.0, 50.0, 2.1],
	["Blossom Crown", Vector2(-122, -112), 298.0, 48.0, 62.0, 3.7],
	["Picnic Meadow", Vector2(140, -96), 272.0, 54.0, 56.0, 4.4],
	["West Petal", Vector2(-262, -18), 288.0, 26.0, 32.0, 0.7],
	["East Petal", Vector2(262, -10), 292.0, 24.0, 30.0, 5.1],
	["South Petal", Vector2(6, 152), 264.0, 26.0, 32.0, 2.8],
	["North Petal", Vector2(22, -172), 310.0, 22.0, 28.0, 1.9],
	["Dew Drop", Vector2(-70, 176), 258.0, 17.0, 22.0, 3.3],
	["Twin Drop", Vector2(-232, 112), 268.0, 18.0, 24.0, 0.4],
]
## Dome height of the top, as a fraction of the radius.
const DOME := 0.06
## A fighter this far below a top still counts as standing on it.
const STEP_UP := 0.5

var names := PackedStringArray()
var centres := PackedVector2Array()
var tops := PackedFloat32Array()
var radii := PackedFloat32Array()
var depths := PackedFloat32Array()
var phases := PackedFloat32Array()


static func heartbloom() -> IslandField:
	var field := IslandField.new()
	for island in HEARTBLOOM:
		field.add(island[0], island[1], island[2], island[3], island[4], island[5])
	return field


func add(island_name: String, centre: Vector2, top: float, radius: float, depth: float, phase: float) -> void:
	names.append(island_name)
	centres.append(centre)
	tops.append(top)
	radii.append(radius)
	depths.append(depth)
	phases.append(phase)


func size() -> int:
	return centres.size()


func index_of(island_name: String) -> int:
	return Array(names).find(island_name)


## Outline radius of island `i` towards `angle` (radians, atan2(dz, dx)).
func rim_radius(i: int, angle: float) -> float:
	var p := phases[i]
	return radii[i] * (1.0 + 0.07 * sin(3.0 * angle + p) + 0.04 * sin(5.0 * angle + 2.0 * p))


## 0 at the island centre, 1 on its rim, > 1 outside.
func rim_fraction(i: int, x: float, z: float) -> float:
	var d := Vector2(x, z) - centres[i]
	return d.length() / rim_radius(i, atan2(d.y, d.x))


## Top height of island `i` at a rim fraction `s` (0..1).
func top_profile(i: int, s: float) -> float:
	return tops[i] + radii[i] * DOME * (1.0 - s * s)


## Index of the island whose outline contains (x, z), or -1.
func island_at(x: float, z: float) -> int:
	var best := -1
	for i in centres.size():
		if rim_fraction(i, x, z) <= 1.0 and (best < 0 or tops[i] > tops[best]):
			best = i
	return best


## Highest island top at (x, z) at or below `from_y` (+ STEP_UP), or -INF if none.
func surface_at(x: float, z: float, from_y: float = INF) -> float:
	var best := -INF
	for i in centres.size():
		var s := rim_fraction(i, x, z)
		if s > 1.0:
			continue
		var h := top_profile(i, s)
		if h <= from_y + STEP_UP:
			best = maxf(best, h)
	return best


## Underside height of island `i` at a rim fraction `s` (0..1): rim at the top, tip at the bottom.
func underside_profile(i: int, s: float) -> float:
	return tops[i] - depths[i] * (1.0 - pow(clampf(s, 0.0, 1.0), 1.6))


## Lowest point of the island body over (x, z), or INF outside every island.
func underside_at(x: float, z: float) -> float:
	var best := INF
	for i in centres.size():
		var s := rim_fraction(i, x, z)
		if s <= 1.0:
			best = minf(best, underside_profile(i, s))
	return best


## True if `p` is inside an island body (between its underside and its top).
func contains(p: Vector3) -> bool:
	for i in centres.size():
		var s := rim_fraction(i, p.x, p.z)
		if s <= 1.0 and p.y < top_profile(i, s) and p.y > underside_profile(i, s):
			return true
	return false


## World position on the top of island `i` at polar offset (angle, rim fraction).
func top_point(i: int, angle: float, s: float) -> Vector3:
	var r := rim_radius(i, angle) * s
	var c := centres[i]
	return Vector3(c.x + cos(angle) * r, top_profile(i, s), c.y + sin(angle) * r)
