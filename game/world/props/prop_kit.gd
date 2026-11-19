class_name PropKit
extends RefCounted
## Grey-block prop building blocks: low-poly meshes, shared toon materials and
## MultiMesh placement on the terrain. Seeded, so the world is the same every load.

const PROP_SHADER := preload("res://game/world/shaders/prop_toon.gdshader")
## Group for props the destruction system (later) may break.
const DESTRUCTIBLE_GROUP := &"world_destructible"
## Props past this distance are culled; the fog has hidden them by then.
const PROP_VISIBILITY_END := 1250.0

var map: TerrainHeightmap
var rng := RandomNumberGenerator.new()
var materials: Dictionary = {}
## Materials whose `night` uniform the atmosphere drives.
var night_materials: Array[ShaderMaterial] = []
## Circles (x, z, radius) props must keep clear of, e.g. spawn points.
var keep_clear: Array[Vector3] = []


func _init(heightmap: TerrainHeightmap, seed_value: int) -> void:
	map = heightmap
	rng.seed = seed_value


func ground(x: float, z: float) -> float:
	return map.ground_height_at(x, z)


## Max height difference over a square of half-size `r` around (x, z).
func roughness(x: float, z: float, r: float) -> float:
	var hs := [ground(x - r, z - r), ground(x + r, z - r), ground(x - r, z + r), ground(x + r, z + r), ground(x, z)]
	return hs.max() - hs.min()


func is_clear(x: float, z: float, radius: float) -> bool:
	for c in keep_clear:
		if Vector2(x - c.x, z - c.y).length() < c.z + radius:
			return false
	return true


func material(key: String, color: Color, params: Dictionary = {}) -> ShaderMaterial:
	if materials.has(key):
		return materials[key]
	var m := ShaderMaterial.new()
	m.shader = PROP_SHADER
	m.set_shader_parameter("albedo_color", color)
	for p in params:
		m.set_shader_parameter(p, params[p])
	if params.has("windows"):
		night_materials.append(m)
	materials[key] = m
	return m


static func box() -> BoxMesh:
	return BoxMesh.new()


static func cylinder(top: float, bottom: float, segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = 1
	mesh.cap_top = top > 0.0
	mesh.cap_bottom = bottom > 0.0
	return mesh


static func sphere(segments: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


## Boxes (AABBs in mesh space) merged into one mesh, e.g. an arch.
static func merged_boxes(boxes: Array[AABB]) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var unit := BoxMesh.new().get_mesh_arrays()
	var verts: PackedVector3Array = unit[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = unit[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = unit[Mesh.ARRAY_INDEX]
	for b in boxes:
		for i in indices:
			st.set_normal(normals[i])
			st.add_vertex(b.get_center() + verts[i] * b.size)
	return st.commit()


## One MultiMeshInstance3D for many copies of a mesh; `colors` tints each copy.
func multimesh(parent: Node3D, node_name: String, mesh: Mesh, mat: Material,
		transforms: Array[Transform3D], colors: PackedColorArray = PackedColorArray(),
		destructible_kind: String = "", shadows: bool = true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	var mesh_box := mesh.get_aabb()
	var bounds := AABB()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i] if i < colors.size() else Color.WHITE)
		var box := transforms[i] * mesh_box
		bounds = box if i == 0 else bounds.merge(box)
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	node.material_override = mat
	node.custom_aabb = bounds
	node.visibility_range_end = PROP_VISIBILITY_END
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if destructible_kind != "":
		node.add_to_group(DESTRUCTIBLE_GROUP)
		node.set_meta("destructible", destructible_kind)
	parent.add_child(node)
	return node


## A single landmark mesh.
func single(parent: Node3D, node_name: String, mesh: Mesh, mat: Material, xform: Transform3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = mat
	node.transform = xform
	node.visibility_range_end = PROP_VISIBILITY_END
	parent.add_child(node)
	return node


## Transform scaled to `size`, rotated about Y by `yaw`, with its base at `base`.
static func placed(base: Vector3, size: Vector3, yaw: float, tilt: Vector3 = Vector3.ZERO) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw)
	if tilt != Vector3.ZERO:
		basis = Basis.from_euler(tilt) * basis
	basis = basis * Basis.from_scale(size)
	return Transform3D(basis, base + basis * Vector3(0.0, 0.5, 0.0))


func jitter(c: Color, amount: float) -> Color:
	var k := 1.0 + rng.randf_range(-amount, amount)
	return Color(c.r * k, c.g * k, c.b * k)
