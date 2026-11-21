extends VoxelZone
## A stand-in zone for FlightClearance: a 4 m box at the origin and a 2 m
## placed crate at z = 40 over flat ground at y = 0, a see-through mist ball,
## and a straight fly-through at the given offsets.

var offset := Vector3(0, 0, 0)


func build() -> void:
	var box := MeshInstance3D.new()
	box.name = "Box"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(4, 4, 4)
	box.mesh = mesh
	box.position = Vector3(0, 2, 0)
	add_child(box)
	var mist := MeshInstance3D.new()
	mist.name = "Mist"
	var sphere := SphereMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = "shader_type spatial;\nrender_mode blend_mix, unshaded;\nvoid fragment() { ALPHA = 0.3; }\n"
	sphere.material = mat
	mist.mesh = sphere
	mist.position = Vector3(20, 6, 0)
	add_child(mist)
	# A placed prop copy (MultiMesh) on the far side, as zones place props.
	var arrays := BoxMesh.new().get_mesh_arrays()
	var cube := ArrayMesh.new()
	cube.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var copies: Array[Transform3D] = [Transform3D(Basis.from_scale(Vector3(2, 2, 2)), Vector3(0, 2, 40))]
	var meshes: Array[ArrayMesh] = [cube]
	VoxelProp.place(self, "Crates", meshes, [0.0], copies, 0)


func ground_at(_x: float, _z: float) -> float:
	return 0.0


func flight() -> Array[Dictionary]:
	return [
		{"from": Vector3(-30, 2, 0) + offset, "at": Vector3.ZERO},
		{"from": Vector3(-10, 2, 0) + offset, "at": Vector3.ZERO},
		{"from": Vector3(10, 2, 0) + offset, "at": Vector3.ZERO},
		{"from": Vector3(30, 2, 0) + offset, "at": Vector3.ZERO},
	]
