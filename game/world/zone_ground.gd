class_name ZoneGround
extends RefCounted
## The sim's floor in one zone (T-D13): terrain and island tops baked once into integer
## centimetre grids, then sampled with integer weights: terrain on the drawn LOD 0 triangles,
## island tops bilinear. No render data and no float accumulation, so the same position
## always gives the same height.

## Grid spacing in metres; matches the terrain heightmap so terrain samples are exact.
const CELL := 2.0
## Sub-cell steps for the bilinear weights (12 bits, half a millimetre).
const SUB_BITS := 12
const SUB := 1 << SUB_BITS
## Island cells with no island top.
const NONE := -2147483648
## A fighter this far below an island top still stands on it (as IslandField.STEP_UP).
const STEP_UP_CM := 50

## World (x, z) of sample (0, 0), on the heightmap grid.
var origin := Vector2.ZERO
var columns := 0
var rows := 0
## Terrain height per sample, centimetres.
var terrain := PackedInt32Array()
## Highest island top per sample, centimetres, or NONE.
var island_tops := PackedInt32Array()


## Bakes the ground of the square box `centre` ± `half_size` (plus a margin).
static func bake(heightmap: TerrainHeightmap, islands: IslandField, centre: Vector2, half_size: float) -> ZoneGround:
	var ground := ZoneGround.new()
	var reach := half_size + 8.0
	var first := Vector2i(floori((centre.x - reach - heightmap.origin.x) / CELL),
		floori((centre.y - reach - heightmap.origin.y) / CELL))
	first = first.clamp(Vector2i.ZERO, Vector2i(heightmap.size - 2, heightmap.size - 2))
	var last := Vector2i(ceili((centre.x + reach - heightmap.origin.x) / CELL),
		ceili((centre.y + reach - heightmap.origin.y) / CELL))
	last = last.clamp(first + Vector2i.ONE, Vector2i(heightmap.size - 1, heightmap.size - 1))
	ground.origin = heightmap.origin + Vector2(first) * CELL
	ground.columns = last.x - first.x + 1
	ground.rows = last.y - first.y + 1
	ground.terrain.resize(ground.columns * ground.rows)
	ground.island_tops.resize(ground.columns * ground.rows)
	ground.island_tops.fill(NONE)
	for row in ground.rows:
		for column in ground.columns:
			var h := heightmap.height_at_sample(first.x + column, first.y + row)
			ground.terrain[row * ground.columns + column] = roundi(h * 100.0)
	if islands != null:
		ground._bake_islands(islands)
	return ground


func _bake_islands(islands: IslandField) -> void:
	for i in islands.size():
		var c := islands.centres[i]
		var r := islands.radii[i] * 1.2
		var lo := Vector2i(floori((c.x - r - origin.x) / CELL), floori((c.y - r - origin.y) / CELL))
		var hi := Vector2i(ceili((c.x + r - origin.x) / CELL), ceili((c.y + r - origin.y) / CELL))
		lo = lo.clamp(Vector2i.ZERO, Vector2i(columns - 1, rows - 1))
		hi = hi.clamp(Vector2i.ZERO, Vector2i(columns - 1, rows - 1))
		for row in range(lo.y, hi.y + 1):
			for column in range(lo.x, hi.x + 1):
				var p := origin + Vector2(column, row) * CELL
				var s := islands.rim_fraction(i, p.x, p.y)
				if s > 1.0:
					continue
				var top := roundi(islands.top_profile(i, s) * 100.0)
				var k := row * columns + column
				island_tops[k] = maxi(island_tops[k], top)


## Floor height at (x, z) for something at height `from_y`: an island top at or just
## above it, else the terrain. Use as CombatSim.ground_height.
func height_at(x: float, z: float, from_y: float) -> float:
	var qx := clampi(floori((x - origin.x) * (SUB / CELL)), 0, (columns - 1) * SUB - 1)
	var qz := clampi(floori((z - origin.y) * (SUB / CELL)), 0, (rows - 1) * SUB - 1)
	var column := qx >> SUB_BITS
	var row := qz >> SUB_BITS
	var tx := qx & (SUB - 1)
	var tz := qz & (SUB - 1)
	var k := row * columns + column
	var ground := _triangle(terrain, k, tx, tz)
	var top := _island_top(k, tx, tz)
	if top != NONE and top > ground and (from_y > 1.0e6 or top <= roundi(from_y * 100.0) + STEP_UP_CM):
		ground = top
	return float(ground) / 100.0


# Terrain height in cm on the drawn LOD 0 triangles (a b c, b d c; see TerrainGrid).
func _triangle(grid: PackedInt32Array, k: int, tx: int, tz: int) -> int:
	var a := grid[k]
	var b := grid[k + 1]
	var c := grid[k + columns]
	var d := grid[k + columns + 1]
	if tx + tz <= SUB:
		return a + (((b - a) * tx + (c - a) * tz) >> SUB_BITS)
	return d + (((c - d) * (SUB - tx) + (b - d) * (SUB - tz)) >> SUB_BITS)


# Integer bilinear blend of the four samples around k, in centimetres.
func _bilinear(grid: PackedInt32Array, k: int, tx: int, tz: int) -> int:
	var a := grid[k] * (SUB - tx) + grid[k + 1] * tx
	var b := grid[k + columns] * (SUB - tx) + grid[k + columns + 1] * tx
	return (a * (SUB - tz) + b * tz) >> (2 * SUB_BITS)


# Island top in cm: blended inside the island, the nearest sample at the rim, NONE outside.
func _island_top(k: int, tx: int, tz: int) -> int:
	var corners := [island_tops[k], island_tops[k + 1], island_tops[k + columns], island_tops[k + columns + 1]]
	if not corners.has(NONE):
		return _bilinear(island_tops, k, tx, tz)
	var nearest: int = corners[(1 if tx >= SUB / 2 else 0) + (2 if tz >= SUB / 2 else 0)]
	return nearest


## Hash of the baked grids, for determinism checks.
func checksum() -> int:
	return hash([origin, columns, rows, terrain, island_tops])
