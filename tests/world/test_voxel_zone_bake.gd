extends GutTest
## Zone bakes (VoxelZoneBake): every zone has a current bake per tier, a baked
## zone comes back with its nodes and script state, stale bakes are refused, and
## a match's zone loads from its bake fast.

const STUB := "res://tests/world/stub_baked_zone.gd"
const REBAKE := "rebake: tools/voxel_zone_bake.gd (see game/world/voxel_zone_kit/README.md)"
const TMP := "user://test_stub_zone_bake.scn"


var _saved_tier: GraphicsSettings.Quality


func before_all() -> void:
	_saved_tier = VoxelQuality.tier


func after_each() -> void:
	VoxelQuality.tier = _saved_tier


func _baked_stub() -> VoxelZone:
	var zone := (load(STUB) as GDScript).new() as VoxelZone
	add_child(zone)
	zone.build()
	var scene := VoxelZoneBake.pack(zone, &"stub", GraphicsSettings.Quality.HIGH, STUB, 1)
	zone.free()
	assert_eq(VoxelZoneBake.save(scene, TMP), OK)
	var loaded := ResourceLoader.load(TMP, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var again := loaded.instantiate() as VoxelZone
	VoxelZoneBake.restore(again)
	add_child_autofree(again)
	return again


func after_all() -> void:
	VoxelQuality.tier = _saved_tier
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func test_every_zone_has_a_current_bake_for_every_tier() -> void:
	for id: StringName in VoxelZoneView.BUILDERS:
		for tier in VoxelZoneBake.TIERS:
			var why := VoxelZoneBake.check(id, tier, VoxelZoneView.BUILDERS[id])
			assert_eq(why, "", "%s %s: %s; %s" % [id, GraphicsSettings.Quality.keys()[tier], why, REBAKE])


func test_a_baked_zone_keeps_its_nodes_typed_arrays_and_shared_material() -> void:
	var zone := _baked_stub()
	var lamps: Array[Node3D] = zone.get("lamps")
	assert_eq(lamps.size(), 3)
	assert_eq(lamps[1], zone.get_node("Lamp1"), "node references point into the loaded tree")
	assert_eq(lamps.get_typed_class_name(), &"Node3D", "typed arrays stay typed")
	var bases: Array[Transform3D] = zone.get("bases")
	assert_eq(bases[2].origin, Vector3(2, 0, 0))
	var glow: ShaderMaterial = zone.get("glow")
	assert_same((zone.get_node("Lamp0") as MeshInstance3D).material_override, glow,
		"the variable and the node share one material")
	assert_same(zone.lantern_materials[0], glow)


func test_a_baked_zone_keeps_nested_values_helpers_and_metas() -> void:
	var zone := _baked_stub()
	var nested: Dictionary = zone.get("nested")
	assert_eq(nested.first[0], zone.get_node("Lamp0"))
	assert_eq(nested.count, 3)
	var helper: Object = zone.get("helper")
	assert_not_null(helper, "a helper object is rebuilt")
	assert_eq(helper.get("spins")[0], zone.get_node("Lamp2"))
	assert_eq(zone.get_meta("light"), zone.get_node("Lamp1"), "node metas come back")
	assert_eq(zone.get_meta("spot"), Vector3(1, 2, 3))
	assert_false(zone.has_meta(VoxelZoneBake.META), "the bake header is removed")


func test_a_baked_zone_animates_like_a_built_one() -> void:
	var zone := _baked_stub()
	zone.animate(1.5)
	assert_eq((zone.get_node("Lamp2") as Node3D).position, Vector3(2, 1.5, 0))


func test_a_bake_from_other_sources_is_refused_as_stale() -> void:
	var zone := (load(STUB) as GDScript).new() as VoxelZone
	add_child(zone)
	zone.build()
	var scene := VoxelZoneBake.pack(zone, &"stormfall_city", GraphicsSettings.Quality.HIGH, STUB, 1)
	zone.free()
	var why := VoxelZoneBake.why_unusable(scene, &"stormfall_city", GraphicsSettings.Quality.HIGH,
		VoxelZoneView.BUILDERS[&"stormfall_city"])
	assert_string_contains(why, "stale")


func test_a_bake_for_another_tier_or_zone_is_refused() -> void:
	var zone := (load(STUB) as GDScript).new() as VoxelZone
	add_child(zone)
	zone.build()
	var scene := VoxelZoneBake.pack(zone, &"stub", GraphicsSettings.Quality.HIGH, STUB, 1)
	zone.free()
	assert_ne(VoxelZoneBake.why_unusable(scene, &"stub", GraphicsSettings.Quality.WEB, STUB), "")
	assert_ne(VoxelZoneBake.why_unusable(scene, &"other", GraphicsSettings.Quality.HIGH, STUB), "")
	assert_eq(VoxelZoneBake.why_unusable(scene, &"stub", GraphicsSettings.Quality.HIGH, STUB), "")


func test_zone_sources_cover_the_builder_folder_kit_and_sim_data() -> void:
	var sources := VoxelZoneBake.sources_for(VoxelZoneView.BUILDERS[&"ember_rift"])
	assert_has(sources, VoxelZoneView.BUILDERS[&"ember_rift"])
	assert_has(sources, "res://game/world/voxel_zone_kit/voxel_prop.gd")
	assert_has(sources, "res://game/world/zones/ember_rift.tres")
	assert_has(sources, "res://game/world/terrain/terrain_heightmap.res")
	assert_false(sources.has(VoxelZoneView.BUILDERS[&"frozen_peaks"]), "other zones' folders don't count")


func test_a_match_zone_loads_from_its_bake_in_under_three_seconds() -> void:
	var view := VoxelZoneView.new()
	add_child_autofree(view)
	var t := Time.get_ticks_msec()
	view.build(&"stormfall_city", GraphicsSettings.Quality.WEB)
	var ms := Time.get_ticks_msec() - t
	assert_true(view.from_bake, "the zone came from its bake")
	assert_lt(ms, 3000, "loaded in %d ms" % ms)
	assert_gt(view.zone.get_child_count(), 10)
	view._process(0.5)
	assert_not_null(view.stage.sun)
