extends GutTest
## The voxel legends in the game: every roster entry has a voxel scene that the
## Voxel art style draws, loaded from its bake (well under a second), holding
## voxel weapons; Classic keeps the old models.

const REBAKE := "rebake with: godot --headless --path . -s res://tools/voxel_bake.gd"


func after_each() -> void:
	ArtStyle.reset()


func test_every_legend_has_a_voxel_scene_beside_its_classic_one() -> void:
	for id in Roster.ids():
		var entry := Roster.character(id)
		assert_not_null(entry.voxel_scene, "%s has a voxel scene" % id)
		assert_ne(entry.voxel_scene, entry.scene, "%s keeps its classic scene" % id)


func test_scene_for_follows_the_art_style() -> void:
	var kael := Roster.character(&"kael")
	assert_eq(kael.scene_for(ArtStyle.Kind.VOXEL), kael.voxel_scene)
	assert_eq(kael.scene_for(ArtStyle.Kind.CLASSIC), kael.scene)
	ArtStyle.set_current(ArtStyle.Kind.CLASSIC)
	assert_eq(kael.scene_for(), kael.scene)
	ArtStyle.set_current(ArtStyle.Kind.VOXEL)
	assert_eq(kael.scene_for(), kael.voxel_scene)


func test_a_fighter_view_draws_the_voxel_legend_in_the_voxel_style() -> void:
	ArtStyle.set_current(ArtStyle.Kind.VOXEL)
	for id in Roster.ids():
		var view := FighterView.new()
		view.character_id = id
		view.fighter = FighterState.new()
		add_child_autofree(view)
		assert_eq(view.character_scene, Roster.character(id).voxel_scene, String(id))
		assert_eq(view.find_children("*", "VoxelBody", true, false).size(), 1, "%s draws a voxel body" % id)


func test_a_fighter_view_draws_the_classic_legend_in_the_classic_style() -> void:
	ArtStyle.set_current(ArtStyle.Kind.CLASSIC)
	for id in Roster.ids():
		var view := FighterView.new()
		view.character_id = id
		view.fighter = FighterState.new()
		add_child_autofree(view)
		assert_eq(view.character_scene, Roster.character(id).scene, String(id))
		assert_eq(view.find_children("*", "VoxelBody", true, false).size(), 0, "%s draws no voxel body" % id)


func test_every_voxel_legend_loads_from_its_bake_well_under_a_second() -> void:
	for id in Roster.ids():
		var scene := Roster.character(id).voxel_scene
		var t0 := Time.get_ticks_usec()
		var view: Node = scene.instantiate()
		add_child_autofree(view)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		gut.p("%s voxel instantiate + ready: %.1f ms" % [id, ms])
		var body: VoxelBody = view.get_node("VoxelBody")
		var target := body.get_node(body.mesh_path) as MeshInstance3D
		var bake := VoxelBake.load_for(body.design, target.get_parent() as Skeleton3D)
		assert_not_null(bake, "%s bake is current; %s" % [id, REBAKE])
		if bake != null:
			assert_eq(target.mesh, bake.mesh, "%s draws the baked mesh" % id)
		assert_lt(ms, 1000.0, "%s loads well under a second" % id)


func test_every_voxel_legend_holds_voxel_weapons() -> void:
	for id in Roster.ids():
		var view: Node = Roster.character(id).voxel_scene.instantiate()
		add_child_autofree(view)
		assert_eq(view.find_children("*", "VoxelArmory", true, false).size(), 1, "%s has a VoxelArmory" % id)
		for skeleton: Skeleton3D in view.find_children("*", "Skeleton3D", true, false):
			assert_true(bool(skeleton.get_meta(WeaponModels.VOXEL_META, false)), "%s skeleton is tagged" % id)


func test_every_voxel_weapon_has_a_current_bake() -> void:
	for kind: Weapon.Kind in VoxelWeapons.DESIGNS:
		var why := []
		var parts := VoxelBake.load_rigid(load(VoxelWeapons.DESIGNS[kind]) as Script, VoxelWeapons.BAKE_SOURCES, "", why)
		assert_eq(parts.size(), 1, "%s: %s; %s" % [Weapon.weapon_name(kind), why[0] if why else "", REBAKE])


func test_a_baked_weapon_equals_a_fresh_build() -> void:
	var script := load(VoxelWeapons.DESIGNS[Weapon.Kind.KI_BOW]) as Script
	var parts := VoxelBake.load_rigid(script, VoxelWeapons.BAKE_SOURCES)
	if parts.is_empty():
		fail_test("no current Ki Bow bake; " + REBAKE)
		return
	var fresh := VoxelWeapons.build_mesh(script.new() as VoxelWeaponDesign)
	assert_eq(VoxelBake.checksum(parts[0]), VoxelBake.checksum(fresh))


func test_lyras_astrolabe_rings_have_a_current_bake() -> void:
	var why := []
	var parts := VoxelBake.load_rigid(load("res://game/characters/lyra_voxel/lyra_voxel_design.gd") as Script,
		LyraAstrolabe.BAKE_SOURCES, LyraAstrolabe.BAKE_KEY, why)
	assert_eq(parts.size(), LyraVoxelDesign.RINGS.size(), "%s; %s" % [why[0] if why else "", REBAKE])


func test_a_stale_rigid_bake_is_refused() -> void:
	var script := load(VoxelWeapons.DESIGNS[Weapon.Kind.KI_BOW]) as Script
	var why := []
	var parts := VoxelBake.load_rigid(script, ["res://game/characters/voxel_weapons/voxel_armory.gd"], "", why)
	assert_true(parts.is_empty(), "other sources than the bake's give another hash")
	assert_string_contains(why[0] if why else "", "stale")
