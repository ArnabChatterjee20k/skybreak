extends GutTest
## Fly-through paths keep FlightClearance.MIN_CLEARANCE (1 m) from every solid
## triangle of their zone and from the visible ground: the sweep itself on a
## stand-in zone, then every real zone from its current HIGH bake.

const STUB := "res://tests/world/stub_flight_zone.gd"


func _stub(offset: Vector3) -> VoxelZone:
	var zone := (load(STUB) as GDScript).new() as VoxelZone
	zone.set("offset", offset)
	add_child_autofree(zone)
	zone.build()
	return zone


func test_the_nearest_point_on_a_triangle_is_inside_on_an_edge_or_a_corner() -> void:
	var a := Vector3(0, 0, 0)
	var b := Vector3(2, 0, 0)
	var c := Vector3(0, 0, 2)
	assert_eq(FlightClearance.closest_on_triangle(Vector3(0.5, 3, 0.5), a, b, c), Vector3(0.5, 0, 0.5))
	assert_eq(FlightClearance.closest_on_triangle(Vector3(1, 1, -3), a, b, c), Vector3(1, 0, 0))
	assert_eq(FlightClearance.closest_on_triangle(Vector3(-1, 0, -1), a, b, c), a)
	assert_eq(FlightClearance.closest_on_triangle(Vector3(3, 0, 3), a, b, c), Vector3(1, 0, 1))


func test_a_path_through_a_solid_box_is_reported_with_the_box() -> void:
	var r := FlightClearance.sweep(_stub(Vector3.ZERO))
	assert_false((r.samples as Array).is_empty())
	assert_eq(r.samples[0].what, "Box")
	assert_lt(r.min, 0.01)


func test_a_path_beside_the_box_and_through_mist_is_clear() -> void:
	# 3.5 m to the side of the box (half width 2): 1.5 m clear; the mist sphere sits on the path.
	var zone := _stub(Vector3(0, 0, 3.5))
	zone.get_node("Mist").position = Vector3(20, 2, 3.5)
	var r := FlightClearance.sweep(zone)
	assert_eq((r.samples as Array).size(), 0, str(r.samples.slice(0, 3)))
	assert_almost_eq(FlightClearance.sweep(zone, 2.0).min, 1.5, 0.05, "measured within a 2 m limit")


func test_a_path_through_a_placed_prop_copy_is_reported() -> void:
	var r := FlightClearance.sweep(_stub(Vector3(0, 0, 40)))
	assert_false((r.samples as Array).is_empty())
	assert_string_starts_with(r.samples[0].what, "Crates_")


func test_a_path_skimming_the_ground_is_reported() -> void:
	var r := FlightClearance.sweep(_stub(Vector3(0, -1.5, 10)))
	assert_false((r.samples as Array).is_empty())
	assert_eq(r.samples[0].what, "ground")


func test_every_zone_fly_through_keeps_a_metre_from_solid_geometry() -> void:
	var saved := VoxelQuality.tier
	VoxelQuality.tier = GraphicsSettings.Quality.HIGH
	var missing: Array[String] = []
	for id: StringName in VoxelZoneView.BUILDERS:
		var why := []
		var zone := VoxelZoneBake.instantiate(id, VoxelQuality.tier, VoxelZoneView.BUILDERS[id], why)
		if zone == null:
			missing.append("%s (%s)" % [id, ", ".join(why)])
			continue
		add_child(zone)
		var r := FlightClearance.sweep(zone)
		var first: Dictionary = r.samples[0] if not (r.samples as Array).is_empty() else {}
		assert_eq((r.samples as Array).size(), 0, "%s: %d samples under %.1f m, first %s"
			% [id, (r.samples as Array).size(), FlightClearance.MIN_CLEARANCE, first])
		zone.free()
	VoxelQuality.tier = saved
	if missing.is_empty():
		return
	# Bakes are generated locally (VOXEL-BAKES); without a current one there is no geometry to sweep.
	if not QaKnownIssues.strict():
		pending("%s — %d zones without a current HIGH bake: %s" % [QaKnownIssues.describe(&"VOXEL-BAKES"),
			missing.size(), missing[0]])
		return
	assert_eq(missing, [] as Array[String], "rebake: tools/voxel_zone_bake.gd --tier=high")
