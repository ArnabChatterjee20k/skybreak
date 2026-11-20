class_name PropKit
extends RefCounted
## Grey-block prop building blocks: low-poly meshes, shared toon materials and
## MultiMesh placement on the terrain. Seeded, so the world is the same every load.

const PROP_SHADER := preload("res://game/world/shaders/prop_toon.gdshader")
const OUTLINE_SHADER := preload("res://game/view/shaders/outline.gdshader")
## Ink outline on props (T-ART1): thinner than the fighters' so they stay on top.
const OUTLINE_WIDTH := 1.5
const OUTLINE_COLOR := Color(0.12, 0.08, 0.14)
## Materials without an ink outline (soft shapes: mist, clouds).
const NO_OUTLINE := ["mist", "hb_cloud"]
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
var _outline_material: ShaderMaterial


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
	if params.has("windows") or params.has("night_emission"):
		night_materials.append(m)
	if not key in NO_OUTLINE:
		m.next_pass = _outline()
	materials[key] = m
	return m


func _outline() -> ShaderMaterial:
	if _outline_material:
		return _outline_material
	var m := ShaderMaterial.new()
	m.shader = OUTLINE_SHADER
	m.set_shader_parameter("outline_color", OUTLINE_COLOR)
	m.set_shader_parameter("outline_width", OUTLINE_WIDTH)
	m.set_shader_parameter("outline_fade_distance", 60.0)
	m.set_shader_parameter("outline_min_width", 0.6)
	_outline_material = m
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


## Appends a mesh's first surface to `st`, transformed and tinted (flat normals).
static func append_mesh(st: SurfaceTool, mesh: Mesh, xform: Transform3D, color: Color) -> void:
	var arrays := (mesh as PrimitiveMesh).get_mesh_arrays() if mesh is PrimitiveMesh else mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		indices.resize(verts.size())
		for i in verts.size():
			indices[i] = i
	st.set_smooth_group(-1)
	st.set_color(color)
	for i in indices:
		st.add_vertex(xform * verts[i])


## Meta on each prop MultiMeshInstance3D: its instance transforms (Array[Transform3D]).
const INSTANCE_TRANSFORMS_META := &"instance_transforms"


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
	# Kept CPU-side: headless runs can't read MultiMesh data back from the
	# rendering server, and the camera's obstacle boxes need it (issue #75).
	node.set_meta(INSTANCE_TRANSFORMS_META, transforms)
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
