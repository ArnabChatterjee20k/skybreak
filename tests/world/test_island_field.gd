extends GutTest

var field: IslandField


func before_all() -> void:
	field = IslandField.heartbloom()


func test_heartbloom_has_a_central_heart_isle_and_ten_more_islands() -> void:
	assert_eq(field.size(), 11)
	var heart := field.index_of("Heart Isle")
	assert_gte(heart, 0)
	for i in field.size():
		if i != heart:
			assert_lt(field.radii[i], field.radii[heart], "%s smaller than Heart Isle" % field.names[i])


func test_islands_float_high_with_open_sky_between_them() -> void:
	for i in field.size():
		assert_between(field.tops[i], 250.0, 330.0, "%s top height" % field.names[i])
		for j in range(i + 1, field.size()):
			var gap := field.centres[i].distance_to(field.centres[j]) - field.radii[i] * 1.11 - field.radii[j] * 1.11
			assert_gt(gap, 15.0, "%s and %s keep a gap" % [field.names[i], field.names[j]])


func test_surface_is_the_domed_top_inside_the_outline_and_none_outside() -> void:
	var heart := field.index_of("Heart Isle")
	var c := field.centres[heart]
	var dome_top := field.tops[heart] + field.radii[heart] * IslandField.DOME
	assert_almost_eq(field.surface_at(c.x, c.y), dome_top, 0.0001, "centre of the dome")
	var rim := field.top_point(heart, 1.0, 0.999)
	assert_almost_eq(field.surface_at(rim.x, rim.z), field.tops[heart], 0.05, "rim at the top height")
	assert_eq(field.surface_at(c.x + field.radii[heart] * 1.3, c.y), -INF, "outside the outline")
	assert_eq(field.surface_at(-640.0, 470.0), -INF, "far away")


func test_surface_below_a_height_ignores_islands_above_it() -> void:
	var heart := field.index_of("Heart Isle")
	var c := field.centres[heart]
	var top := field.surface_at(c.x, c.y)
	assert_eq(field.surface_at(c.x, c.y, top - 5.0), -INF, "under the island")
	assert_eq(field.surface_at(c.x, c.y, top - IslandField.STEP_UP * 0.5), top, "standing on it")


func test_island_bodies_are_between_the_underside_and_the_top() -> void:
	var heart := field.index_of("Heart Isle")
	var c := field.centres[heart]
	var under := field.underside_at(c.x, c.y)
	assert_almost_eq(under, field.tops[heart] - field.depths[heart], 0.0001, "tip under the centre")
	assert_true(field.contains(Vector3(c.x, under + 5.0, c.y)))
	assert_false(field.contains(Vector3(c.x, under - 5.0, c.y)))
	assert_false(field.contains(Vector3(c.x, field.surface_at(c.x, c.y) + 1.0, c.y)))
	assert_eq(field.underside_at(-640.0, 470.0), INF)


func test_island_queries_are_deterministic() -> void:
	var other := IslandField.heartbloom()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for k in 2000:
		var x := rng.randf_range(-330.0, 330.0)
		var z := rng.randf_range(-240.0, 240.0)
		var y := rng.randf_range(200.0, 340.0)
		assert_eq(field.surface_at(x, z), other.surface_at(x, z))
		assert_eq(field.surface_at(x, z, y), other.surface_at(x, z, y))
		assert_eq(field.island_at(x, z), other.island_at(x, z))
		assert_eq(field.surface_at(x, z), field.surface_at(x, z), "same answer twice")
		if field.surface_at(x, z) != other.surface_at(x, z):
			return


func test_island_tops_match_the_island_mesh() -> void:
	var group := Node3D.new()
	add_child_autofree(group)
	var zone: ZoneData = load("res://game/world/zones/heartbloom_gardens.tres")
	var kit := PropKit.new(load(WorldMap.HEIGHTMAP_PATH), 1)
	HeartbloomProps.build(group, kit, zone, field)
	var mesh: ArrayMesh = (group.get_node("Islands") as MeshInstance3D).mesh
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var checked := 0
	var worst := 0.0
	var worst_inside := 0.0
	for t in range(0, verts.size(), 3):
		var centroid := (verts[t] + verts[t + 1] + verts[t + 2]) / 3.0
		var i := field.island_at(centroid.x, centroid.z)
		if i < 0 or field.rim_fraction(i, centroid.x, centroid.z) > 0.97:
			continue  # The grass lip folding over the rim.
		for k in 3:
			var v := verts[t + k]
			var s := field.rim_fraction(i, v.x, v.z)
			worst = maxf(worst, absf(field.top_profile(i, minf(s, 1.0)) - v.y))
		worst_inside = maxf(worst_inside, absf(field.surface_at(centroid.x, centroid.z) - centroid.y))
		checked += 1
	assert_gt(checked, 2000, "top triangles checked")
	assert_lt(worst, 0.01, "every top vertex lies on the queried surface")
	assert_lt(worst_inside, 0.25, "and between vertices the mesh stays within 25 cm of it")


func test_props_keep_clear_of_spawns_and_stand_on_the_islands() -> void:
	var builder := HeartbloomProps.new()
	builder.kit = PropKit.new(load(WorldMap.HEIGHTMAP_PATH), 1)
	builder.zone = load("res://game/world/zones/heartbloom_gardens.tres")
	builder.field = field
	builder.rng.seed = HeartbloomProps.SEED
	var group := Node3D.new()
	add_child_autofree(group)
	builder._build(group)
	assert_gt(builder.trunks.size(), 30, "a grove of cherry trees")
	assert_gt(builder.lanterns.size(), 80, "plenty of lanterns")
	assert_gt(builder.flowers.size(), 300, "flower patches")
	for t in builder.trunks:
		var base := t.origin - t.basis.y * 0.5
		assert_gte(field.island_at(base.x, base.z), 0, "tree on an island")
		for p in builder.zone.spawn_points:
			assert_gt(Vector2(base.x - p.x, base.z - p.z).length(), 20.0, "tree clear of the spawn")
	for t in builder.lanterns + builder.flowers:
		for p in builder.zone.spawn_points:
			assert_gt(Vector2(t.origin.x - p.x, t.origin.z - p.z).length(), 8.0, "clear of the spawn")


func test_heart_curve_closes_at_the_cusp_and_the_tip() -> void:
	assert_almost_eq(HeartbloomProps.heart_point(0.0).x, 0.0, 0.0001)
	assert_almost_eq(HeartbloomProps.heart_point(PI).x, 0.0, 0.0001)
	assert_almost_eq(HeartbloomProps.heart_point(PI).y, -17.0, 0.0001, "tip at the bottom")
