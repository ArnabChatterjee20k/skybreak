class_name TerrainHeightmap
extends Resource
## Baked terrain heights on a square grid, plus low-res zone blend weights.
## `ground_height_at` is pure math on this data, so the sim can use it too.

## Samples per side (cells + 1).
@export var size := 1025
## Metres between samples.
@export var cell_size := 2.0
## World (x, z) of sample (0, 0).
@export var origin := Vector2(-1024.0, -1024.0)
## Row-major heights in metres: index = row (z) * size + column (x).
@export var heights := PackedFloat32Array()
## Zone weights at `weights_size`² points over the same square, 6 bytes each (0..255).
@export var weights_size := 257
@export var zone_weights := PackedByteArray()


func height_at_sample(column: int, row: int) -> float:
	column = clampi(column, 0, size - 1)
	row = clampi(row, 0, size - 1)
	return heights[row * size + column]


## Bilinear ground height at world (x, z); clamps outside the grid.
func ground_height_at(x: float, z: float) -> float:
	var fx := clampf((x - origin.x) / cell_size, 0.0, float(size - 1))
	var fz := clampf((z - origin.y) / cell_size, 0.0, float(size - 1))
	var cx := mini(int(fx), size - 2)
	var cz := mini(int(fz), size - 2)
	var tx := fx - float(cx)
	var tz := fz - float(cz)
	var i := cz * size + cx
	var top := lerpf(heights[i], heights[i + 1], tx)
	var bottom := lerpf(heights[i + size], heights[i + size + 1], tx)
	return lerpf(top, bottom, tz)


## World (x, z) of a sample.
func sample_position(column: int, row: int) -> Vector2:
	return origin + Vector2(column, row) * cell_size


func world_size() -> float:
	return float(size - 1) * cell_size


## Min and max height over a block of samples (inclusive).
func height_range(column0: int, row0: int, column1: int, row1: int) -> Vector2:
	var lo := INF
	var hi := -INF
	for row in range(row0, row1 + 1):
		for column in range(column0, column1 + 1):
			var h := height_at_sample(column, row)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return Vector2(lo, hi)


## Heights as a single-channel float image (the terrain shader displaces with it).
func to_height_image() -> Image:
	return Image.create_from_data(size, size, false, Image.FORMAT_RF, heights.to_byte_array())


## Zone weights as two RGBA8 images: zones 0-3 and zones 4-5.
func to_weight_images() -> Array[Image]:
	var a := PackedByteArray()
	var b := PackedByteArray()
	var count := weights_size * weights_size
	a.resize(count * 4)
	b.resize(count * 4)
	for p in count:
		for k in 4:
			a[p * 4 + k] = zone_weights[p * 6 + k]
		b[p * 4] = zone_weights[p * 6 + 4]
		b[p * 4 + 1] = zone_weights[p * 6 + 5]
		b[p * 4 + 3] = 255
	return [
		Image.create_from_data(weights_size, weights_size, false, Image.FORMAT_RGBA8, a),
		Image.create_from_data(weights_size, weights_size, false, Image.FORMAT_RGBA8, b),
	]
