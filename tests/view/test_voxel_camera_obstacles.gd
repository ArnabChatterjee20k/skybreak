extends GutTest
## T-135: on voxel zones the fight camera avoids the low voxel props (the classic
## props it used to avoid are hidden); terrain-sized and tall mostly-air props stay out.

const STUB := "res://tests/world/stub_flight_zone.gd"
const PLAYER := Vector3(0, 10, 0)
const TARGET := Vector3(0, 10, -12)


func _stub() -> VoxelZone:
	var zone := (load(STUB) as GDScript).new() as VoxelZone
	add_child_autofree(zone)
	zone.build()
	return zone


func _camera(obstacles: CameraObstacles) -> FighterCamera:
	var camera := FighterCamera.new()
	camera.obstacles = obstacles
	add_child_autofree(camera)
	return camera


func _place(zone: VoxelZone, prop_name: String, size: Vector3, at: Vector3) -> void:
	var arrays := BoxMesh.new().get_mesh_arrays()
	var cube := ArrayMesh.new()
	cube.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var copies: Array[Transform3D] = [Transform3D(Basis.from_scale(size), at)]
	var meshes: Array[ArrayMesh] = [cube]
	VoxelProp.place(zone, prop_name, meshes, [0.0], copies, 0)


func test_solid_voxel_props_become_camera_boxes_and_see_through_ones_do_not() -> void:
	var obstacles := CameraObstacles.new()
	obstacles.add_voxel_props(_stub(), Vector2.ZERO, 100.0)
	assert_eq(obstacles.boxes.size(), 2, "the 4 m box and the placed crate copy; not the mist")
	assert_true(obstacles.is_inside(Vector3(0, 2, 0)), "inside the box")
	assert_true(obstacles.is_inside(Vector3(0, 2, 40)), "inside the crate copy")
	assert_false(obstacles.is_inside(Vector3(20, 6, 0)), "the mist ball is see-through")


func test_terrain_sized_and_tall_voxel_props_are_not_camera_boxes() -> void:
	var zone := _stub()
	_place(zone, "Slab", Vector3(CameraObstacles.VOXEL_MAX_WIDTH + 5.0, 3, 30), Vector3(0, 1.5, -80))
	_place(zone, "Spire", Vector3(4, CameraObstacles.VOXEL_MAX_HEIGHT + 10.0, 4), Vector3(60, 8, 0))
	var obstacles := CameraObstacles.new()
	obstacles.add_voxel_props(zone, Vector2.ZERO, 200.0)
	assert_false(obstacles.is_inside(Vector3(0, 1.5, -80)), "a terrain-chunk-sized mesh is the ground's")
	assert_false(obstacles.is_inside(Vector3(60, 8, 0)), "a tall prop's box is mostly air")


func test_the_camera_keeps_out_of_a_low_voxel_prop_placed_where_it_would_sit() -> void:
	var free := _camera(null)
	for i in 120:
		free.follow(PLAYER, TARGET, true, 1.0 / 60.0)
	var spot := free.global_position
	var zone := _stub()
	_place(zone, "Wall", Vector3(6, CameraObstacles.VOXEL_MAX_HEIGHT, 2), spot)
	var blind := CameraClearance.sweep(zone, PackedVector3Array([spot]))
	assert_eq((blind.samples as Array).size(), 1, "an obstacle-blind camera sits inside the wall")
	var obstacles := CameraObstacles.new()
	obstacles.ground_height = func(_x: float, _z: float, _from_y: float) -> float: return 0.0
	obstacles.add_voxel_props(zone, Vector2.ZERO, 100.0)
	var camera := _camera(obstacles)
	var points := PackedVector3Array()
	for i in 120:
		camera.follow(PLAYER, TARGET, true, 1.0 / 60.0)
		points.append(camera.global_position)
	var seen := CameraClearance.sweep(zone, points)
	assert_eq((seen.samples as Array).size(), 0, "never within %.2f m of the wall: %s"
		% [CameraClearance.MIN_CLEARANCE, seen.samples.slice(0, 2)])
	assert_true(VoxelCameraFight.on_screen(camera.global_transform, camera.fov, PLAYER), "player still framed")
	assert_true(VoxelCameraFight.on_screen(camera.global_transform, camera.fov, TARGET), "target still framed")
