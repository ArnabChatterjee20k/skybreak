extends GutTest
## T-135: the fight camera respects the visible voxel floor where it stands above
## the sim's heightmap (Verdant Falls' FloorT2 tier), and steep banks beside the lens.


## A flat floor slab top at height top over [x0, x1] x [z0, z1] (two triangles).
func _slab(x0: float, x1: float, z0: float, z1: float, top: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: Vector3 in [Vector3(x0, top, z0), Vector3(x1, top, z0), Vector3(x1, top, z1),
			Vector3(x0, top, z0), Vector3(x1, top, z1), Vector3(x0, top, z1)]:
		st.add_vertex(v)
	return st.commit()


## One big sloped triangle rising 1 m per metre along +x.
func _ramp() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: Vector3 in [Vector3(0, 0, 0), Vector3(30, 30, 0), Vector3(0, 0, 30)]:
		st.add_vertex(v)
	return st.commit()


func _flat_ground(height: float) -> Callable:
	return func(_x: float, _z: float, _from_y: float) -> float: return height


func test_a_raised_floor_tier_lifts_the_camera_ground_above_the_heightmap() -> void:
	var obstacles := CameraObstacles.new()
	obstacles.ground_height = _flat_ground(0.0)
	obstacles.voxel_floor = CameraFloor.new()
	obstacles.voxel_floor.add_chunk(_slab(0, 32, 0, 32, 0.7), Transform3D.IDENTITY)
	assert_almost_eq(obstacles.ground_at(Vector3(10, 1.0, 10)), 0.7, 0.001, "on the tier")
	assert_almost_eq(obstacles.ground_at(Vector3(40, 1.0, 10)), 0.0, 0.001, "off it: the heightmap")
	assert_true(obstacles.is_inside(Vector3(10, 0.5, 10)), "under the visible floor is inside it")


func test_a_floor_top_far_above_the_point_is_overhead_not_its_floor() -> void:
	var f := CameraFloor.new()
	f.add_chunk(_slab(0, 32, 0, 32, 10.0), Transform3D.IDENTITY)
	assert_almost_eq(f.height_at(5, 5, 9.0), 10.0, 0.001, "just under the top: still its floor")
	assert_eq(f.height_at(5, 5, 2.0), -INF, "8 m under it: something overhead")


func test_a_sloped_face_gives_its_height_per_cell_not_its_top_vertex() -> void:
	var f := CameraFloor.new()
	f.add_chunk(_ramp(), Transform3D.IDENTITY)
	var h := f.height_at(4.2, 2.0, 50.0)
	assert_gte(h, 4.2, "never under the face")
	assert_lt(h, 4.2 + CameraFloor.CELL * 2.0, "about the face's height there, not its 30 m top")


func test_chunks_are_placed_by_their_transform_and_warmed_ahead() -> void:
	var f := CameraFloor.new()
	f.add_chunk(_slab(0, 32, 0, 32, 1.0), Transform3D(Basis.IDENTITY, Vector3(100, 2, 0)))
	f.warm(Vector3(110, 3, 10))
	assert_almost_eq(f.height_at(110, 10, 5.0), 3.0, 0.001)
	assert_eq(f.height_at(10, 10, 5.0), -INF)


func test_a_steep_bank_beside_the_lens_counts_as_its_ground() -> void:
	var obstacles := CameraObstacles.new()
	# A 70 degree bank rising along +x.
	obstacles.ground_height = func(x: float, _z: float, _from_y: float) -> float: return maxf(0.0, x * 2.75)
	var at := Vector3(0.0, 0.0, 0.0)
	assert_almost_eq(obstacles.ground_at(at), 0.0, 0.001)
	assert_almost_eq(obstacles.ground_near(at), CameraObstacles.CLEARANCE * 2.75, 0.01)


func test_the_fight_camera_stays_clear_above_a_raised_tier() -> void:
	var obstacles := CameraObstacles.new()
	obstacles.ground_height = _flat_ground(0.0)
	obstacles.voxel_floor = CameraFloor.new()
	obstacles.voxel_floor.add_chunk(_slab(-40, 40, -40, 40, 0.8), Transform3D.IDENTITY)
	var camera := FighterCamera.new()
	camera.obstacles = obstacles
	add_child_autofree(camera)
	# Player low, target above: the boom dips toward the floor.
	for i in 180:
		camera.follow(Vector3(0, 1.8, 0), Vector3(0, 9, -8), true, 1.0 / 60.0)
		assert_gte(camera.global_position.y, 0.8 + CameraObstacles.CLEARANCE - 0.001, "frame %d" % i)
