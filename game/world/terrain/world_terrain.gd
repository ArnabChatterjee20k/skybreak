class_name WorldTerrain
extends Node3D
## Chunked terrain: one MeshInstance3D per chunk and LOD, sharing 4 grid meshes.
## The renderer picks the LOD with visibility ranges; distant LODs cast no shadows.

const SHADER := preload("res://game/world/shaders/terrain_toon.gdshader")
## LODs that cast shadows (LOD 0 covers the whole shadow distance).
const SHADOW_LODS := 1

var heightmap: TerrainHeightmap
var materials: Array[ShaderMaterial] = []
var chunks_per_side := 0


func build(map: TerrainHeightmap, zones: Array[ZoneData]) -> void:
	heightmap = map
	chunks_per_side = (map.size - 1) / TerrainGrid.CHUNK_CELLS
	var height_texture := ImageTexture.create_from_image(map.to_height_image())
	var weight_images := map.to_weight_images()
	var weights_a := ImageTexture.create_from_image(weight_images[0])
	var weights_b := ImageTexture.create_from_image(weight_images[1])
	var low := PackedVector4Array()
	var high := PackedVector4Array()
	var rock := PackedVector4Array()
	var params := PackedVector4Array()
	for zone in zones:
		low.append(_vec4(zone.ground_low))
		high.append(_vec4(zone.ground_high))
		rock.append(_vec4(zone.rock))
		params.append(Vector4(zone.ramp_heights.x, zone.ramp_heights.y, zone.strata,
			1.0 if zone.id == &"stormfall_city" else 0.0))
	for lod in TerrainGrid.LOD_COUNT:
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("heightmap", height_texture)
		material.set_shader_parameter("zone_weights_a", weights_a)
		material.set_shader_parameter("zone_weights_b", weights_b)
		material.set_shader_parameter("map_origin", map.origin)
		material.set_shader_parameter("cell_size", map.cell_size)
		material.set_shader_parameter("map_samples", map.size)
		material.set_shader_parameter("weight_samples", map.weights_size)
		material.set_shader_parameter("lod_step", TerrainGrid.lod_step(lod))
		material.set_shader_parameter("skirt_depth", TerrainGrid.SKIRT_DEPTH)
		material.set_shader_parameter("zone_low", low)
		material.set_shader_parameter("zone_high", high)
		material.set_shader_parameter("zone_rock", rock)
		material.set_shader_parameter("zone_params", params)
		materials.append(material)
	var chunk_size := TerrainGrid.CHUNK_CELLS * map.cell_size
	for cz in chunks_per_side:
		for cx in chunks_per_side:
			var c0 := cx * TerrainGrid.CHUNK_CELLS
			var r0 := cz * TerrainGrid.CHUNK_CELLS
			var span := map.height_range(c0, r0, c0 + TerrainGrid.CHUNK_CELLS, r0 + TerrainGrid.CHUNK_CELLS)
			var skirt := TerrainGrid.SKIRT_DEPTH * float(TerrainGrid.lod_step(TerrainGrid.LOD_COUNT - 1))
			var aabb := AABB(Vector3(0.0, span.x - skirt, 0.0),
				Vector3(chunk_size, span.y - span.x + skirt + 1.0, chunk_size))
			var origin := map.sample_position(c0, r0)
			for lod in TerrainGrid.LOD_COUNT:
				var chunk := MeshInstance3D.new()
				chunk.name = "Chunk_%d_%d_L%d" % [cx, cz, lod]
				chunk.mesh = TerrainGrid.mesh_for_lod(lod, map.cell_size)
				chunk.material_override = materials[lod]
				chunk.custom_aabb = aabb
				chunk.position = Vector3(origin.x, 0.0, origin.y)
				chunk.visibility_range_begin = TerrainGrid.lod_begin(lod)
				chunk.visibility_range_end = TerrainGrid.LOD_END[lod]
				chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod < SHADOW_LODS \
					else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				chunk.set_meta("lod", lod)
				chunk.set_meta("triangles", TerrainGrid.triangle_count(lod))
				add_child(chunk)


static func _vec4(c: Color) -> Vector4:
	return Vector4(c.r, c.g, c.b, c.a)


## Overview (map) mode: only the coarsest LOD, never culled by distance.
func set_overview(enabled: bool) -> void:
	for chunk in get_children():
		var lod: int = chunk.get_meta("lod")
		if lod == TerrainGrid.LOD_COUNT - 1:
			chunk.visibility_range_begin = 0.0 if enabled else TerrainGrid.lod_begin(lod)
			chunk.visibility_range_end = 0.0 if enabled else TerrainGrid.LOD_END[lod]
		else:
			chunk.visible = not enabled
