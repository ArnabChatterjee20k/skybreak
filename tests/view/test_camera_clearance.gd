extends GutTest
## T-135: CameraClearance, the fight camera's no-clip measure on voxel zones:
## near a solid triangle, under the ground, or inside a closed prop copy.

const STUB := "res://tests/world/stub_flight_zone.gd"


func _stub() -> VoxelZone:
	var zone := (load(STUB) as GDScript).new() as VoxelZone
	add_child_autofree(zone)
	zone.build()
	return zone


func test_camera_clearance_finds_a_camera_deep_inside_a_placed_voxel_prop() -> void:
	var zone := _stub()
	var arrays := BoxMesh.new().get_mesh_arrays()
	var cube := ArrayMesh.new()
	cube.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var spot := Vector3(0, 10, 8)
	var copies: Array[Transform3D] = [Transform3D(Basis.from_scale(Vector3(6, 6, 2)), spot)]
	var meshes: Array[ArrayMesh] = [cube]
	VoxelProp.place(zone, "Wall", meshes, [0.0], copies, 0)
	var r := CameraClearance.sweep(zone, PackedVector3Array([spot, spot + Vector3(0, 0, 3)]))
	assert_eq((r.samples as Array).size(), 1, "the centre is 1 m from every face, yet inside")
	assert_eq(r.samples[0].index, 0)
	assert_string_ends_with(r.samples[0].what, "(inside)")


func test_camera_clearance_reports_points_near_or_under_the_ground_and_clear_ones_not() -> void:
	var zone := _stub()
	var r := CameraClearance.sweep(zone, PackedVector3Array([Vector3(10, 3, 10), Vector3(10, -0.5, 10),
		Vector3(0, 2, 2.05), Vector3(0.3, 2.2, 0.4)]))
	var hits := {}
	for s: Dictionary in r.samples:
		hits[s.index] = s.what
	assert_false(hits.has(0), "3 m up in the open is clear")
	assert_eq(hits.get(1), "ground", "under the ground")
	assert_eq(hits.get(2), "Box", "5 cm off the box face")
	assert_eq(hits.get(3), "Box (inside)", "deep inside the box")
