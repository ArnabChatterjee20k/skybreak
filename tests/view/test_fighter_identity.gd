extends GutTest
## T-118: team palette and the height marker.

const KAEL := preload("res://game/characters/kael_chunky/kael_chunky.tscn")


func _albedo_of(root: Node, part: String) -> Color:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if FighterPalette.part_name(material) == part:
				return (material as ShaderMaterial).get_shader_parameter(FighterPalette.ALBEDO)
	return Color(0, 0, 0, 0)


func _view(palette: Dictionary) -> FighterView:
	var view := FighterView.new()
	view.character_scene = KAEL
	view.palette = palette
	view.fighter = FighterState.new()
	add_child_autofree(view)
	return view


func test_part_name_is_the_last_word_of_the_material_name() -> void:
	var material := ShaderMaterial.new()
	material.resource_name = "kael_chunky_coat"
	assert_eq(FighterPalette.part_name(material), "coat")
	assert_eq(FighterPalette.part_name(null), "")


func test_palette_recolours_only_the_named_parts() -> void:
	var plain := _view({})
	var red := Color(0.8, 0.1, 0.1)
	var team := _view({"coat": red})
	assert_ne(_albedo_of(plain, "coat"), Color(0, 0, 0, 0), "kael has a coat material")
	assert_eq(_albedo_of(team, "coat"), red)
	assert_eq(_albedo_of(team, "skin"), _albedo_of(plain, "skin"), "skin untouched")


func test_palette_never_edits_the_shared_material() -> void:
	var before := _albedo_of(_view({}), "coat")
	_view({"coat": Color(0.1, 0.9, 0.1)})
	assert_eq(_albedo_of(_view({}), "coat"), before, "a later plain Kael keeps its coat")


func test_arena_p2_vexa_wears_her_alt_palette() -> void:
	var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
	add_child_autofree(arena)
	var p2: Node = arena.get_node("Fighter2")
	var plain := FighterView.new()
	plain.character_id = &"vexa"
	plain.fighter = FighterState.new()
	add_child_autofree(plain)
	var a := _albedo_of(plain, "violet")
	var b := _albedo_of(p2, "violet")
	assert_ne(a, Color(0, 0, 0, 0), "vexa has a violet material")
	var hue_gap := absf(a.h - b.h)
	assert_gt(minf(hue_gap, 1.0 - hue_gap), 0.2, "P2's main colour differs clearly from her P1 look")


func test_arena_fighters_keep_their_team_rims() -> void:
	var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
	add_child_autofree(arena)
	var p1: FighterView = arena.get_node("Fighter1")
	var p2: FighterView = arena.get_node("Fighter2")
	assert_gt(p1.energy_color.r, p1.energy_color.b, "P1 rim is warm")
	assert_gt(p2.energy_color.b, p2.energy_color.r, "P2 rim is cool")
	for view: FighterView in [p1, p2]:
		for mesh: MeshInstance3D in view.find_children("*", "MeshInstance3D", true, false):
			if mesh.get_instance_shader_parameter(&"rim_energy_color") == null:
				continue
			assert_eq(mesh.get_instance_shader_parameter(&"rim_energy_color"), Color(view.energy_color, 1.0),
				"%s rim tinted" % view.name)


func test_height_marker_draws_no_ring_of_its_own() -> void:
	var marker := HeightMarker.new()
	add_child_autofree(marker)
	assert_eq(marker.get_child_count(), 1, "the ground ring is the contact shadow's rim")


func test_height_marker_shows_only_when_airborne() -> void:
	var marker := HeightMarker.new()
	add_child_autofree(marker)
	marker.update(Vector3(0, 1.0, 0))  # standing: feet on the ground
	assert_false(marker.visible)
	marker.update(Vector3(0, 12.0, 0))
	assert_true(marker.visible)


func test_feet_height_measures_from_the_feet() -> void:
	assert_almost_eq(HeightMarker.feet_height(Vector3(0, 12, 0), 0.0), 11.0, 0.001)
	assert_almost_eq(HeightMarker.feet_height(Vector3(0, 12, 0), 2.0), 9.0, 0.001)
