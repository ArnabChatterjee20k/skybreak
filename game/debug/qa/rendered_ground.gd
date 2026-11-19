class_name RenderedGround
extends RefCounted
## The ground as drawn (T-D30 QA): the terrain's LOD 0 triangles exactly as the terrain
## shader lifts them, plus the island grass mesh, so feet are judged against what is seen.

const BUCKET := 4.0
## Surfaces up to this far above a probe point still count as under it (step-ups).
const REACH_UP := 0.5

var heightmap: TerrainHeightmap
var _island_tris := {}


static func of(world: WorldMap) -> RenderedGround:
	var ground := RenderedGround.new()
	ground.heightmap = world.heightmap
	var islands := world.find_child("Islands", true, false) as MeshInstance3D
	if islands == null or islands.mesh == null:
		return ground
	# The grass (surface 0) and the rim squares drawn from the sim's grid.
	for surface in islands.mesh.get_surface_count():
		if surface != 0 and islands.mesh.surface_get_name(surface) != HeartbloomProps.RIM_SURFACE:
			continue
		var arrays := islands.mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		var to_world := islands.global_transform
		var count := (indices as PackedInt32Array).size() if indices != null else verts.size()
		for t in range(0, count, 3):
			var tri := PackedVector3Array()
			for k in 3:
				var i: int = (indices as PackedInt32Array)[t + k] if indices != null else t + k
				tri.append(to_world * verts[i])
			ground._add_triangle(tri)
	return ground


func _add_triangle(tri: PackedVector3Array) -> void:
	var lo := Vector2(minf(tri[0].x, minf(tri[1].x, tri[2].x)), minf(tri[0].z, minf(tri[1].z, tri[2].z)))
	var hi := Vector2(maxf(tri[0].x, maxf(tri[1].x, tri[2].x)), maxf(tri[0].z, maxf(tri[1].z, tri[2].z)))
	for bx in range(floori(lo.x / BUCKET), floori(hi.x / BUCKET) + 1):
		for bz in range(floori(lo.y / BUCKET), floori(hi.y / BUCKET) + 1):
			var key := Vector2i(bx, bz)
			if not _island_tris.has(key):
				_island_tris[key] = []
			(_island_tris[key] as Array).append(tri)


## Drawn terrain height at (x, z): the LOD 0 grid triangles (a b c, b d c per cell).
func terrain_at(x: float, z: float) -> float:
	var gx := (x - heightmap.origin.x) / heightmap.cell_size
	var gz := (z - heightmap.origin.y) / heightmap.cell_size
	var i := clampi(floori(gx), 0, heightmap.size - 2)
	var j := clampi(floori(gz), 0, heightmap.size - 2)
	var u := gx - i
	var v := gz - j
	var a := heightmap.height_at_sample(i, j)
	var b := heightmap.height_at_sample(i + 1, j)
	var c := heightmap.height_at_sample(i, j + 1)
	var d := heightmap.height_at_sample(i + 1, j + 1)
	if u + v <= 1.0:
		return a + u * (b - a) + v * (c - a)
	return d + (1.0 - u) * (c - d) + (1.0 - v) * (b - d)


## Highest drawn surface under (x, z) at or just above from_y (terrain or island grass).
func height_at(x: float, z: float, from_y: float) -> float:
	var best := terrain_at(x, z)
	var key := Vector2i(floori(x / BUCKET), floori(z / BUCKET))
	var origin := Vector3(x, from_y + REACH_UP, z)
	for tri: PackedVector3Array in _island_tris.get(key, []):
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin, Vector3.DOWN, tri[0], tri[1], tri[2])
		if hit != null:
			best = maxf(best, (hit as Vector3).y)
	return best
