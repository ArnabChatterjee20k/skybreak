extends SceneTree
## Bakes the terrain heightmap from TerrainShape and the zone resources.
## Run after changing the generator or a zone centre:
## godot --headless --path . -s res://game/world/terrain/bake_terrain.gd

const OUTPUT := "res://game/world/terrain/terrain_heightmap.res"
const SIZE := 1025
const CELL := 2.0


func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var layout := ZoneLayout.load_default()
	var shape := TerrainShape.new(layout)
	var map := TerrainHeightmap.new()
	map.size = SIZE
	map.cell_size = CELL
	map.origin = Vector2(-TerrainShape.HALF_SIZE, -TerrainShape.HALF_SIZE)
	var heights := PackedFloat32Array()
	heights.resize(SIZE * SIZE)
	for row in SIZE:
		for column in SIZE:
			var p := map.sample_position(column, row)
			heights[row * SIZE + column] = shape.height_at(p.x, p.y)
	map.heights = heights
	var weights := PackedByteArray()
	weights.resize(map.weights_size * map.weights_size * 6)
	var step := map.world_size() / float(map.weights_size - 1)
	for row in map.weights_size:
		for column in map.weights_size:
			var p := map.origin + Vector2(column, row) * step
			var w := layout.weights_at(p.x, p.y)
			for k in 6:
				weights[(row * map.weights_size + column) * 6 + k] = roundi(w[k] * 255.0)
	map.zone_weights = weights
	var err := ResourceSaver.save(map, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	print("Baked %s in %.1f s (error %d)" % [OUTPUT, (Time.get_ticks_msec() - started) / 1000.0, err])
	quit(err)
