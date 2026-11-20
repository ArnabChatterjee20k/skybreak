extends GutTest
## Voxel weapons (docs/lookdev/weapons.md): every weapon has a voxel model that is a rigid,
## drop-in replacement for the old mesh, used only where a VoxelArmory (or the global flag)
## asks for it.

const ALL_KINDS: Array[Weapon.Kind] = [
	Weapon.Kind.KI_GAUNTLETS, Weapon.Kind.STORM_BLADE, Weapon.Kind.SKY_LANCE, Weapon.Kind.TITAN_HAMMER,
	Weapon.Kind.ORBIT_CHAKRAM, Weapon.Kind.EMBER_SCYTHE, Weapon.Kind.KI_BOW, Weapon.Kind.ARC_REVOLVER,
	Weapon.Kind.STORM_REPEATER, Weapon.Kind.SCATTER_CANNON, Weapon.Kind.HEARTSTRING_BOW,
]
## Vertices a weapon may use (a voxel character is ~150-250k).
const VERTEX_BUDGET := 80000


func after_each() -> void:
	WeaponModels.voxel_everywhere = false


func test_every_weapon_kind_has_a_voxel_design() -> void:
	assert_eq(ALL_KINDS.size(), Weapon.Kind.size() - 1, "the list covers every kind but NONE")
	for kind in ALL_KINDS:
		assert_true(VoxelWeapons.has(kind), "%s has a voxel design" % Weapon.weapon_name(kind))
		assert_eq(VoxelWeapons.design_of(kind).kind(), kind, "%s's design names its kind" % Weapon.weapon_name(kind))


func test_every_voxel_weapon_is_built_at_the_fine_world_cell() -> void:
	for kind in ALL_KINDS:
		var d := VoxelWeapons.design_of(kind)
		assert_almost_eq(d.cell() * d.model_scale(), VoxelWeaponDesign.WORLD_CELL, 0.0001,
			"%s: 1.1 cm voxels in the world" % Weapon.weapon_name(kind))


func test_every_voxel_mesh_is_rigid_within_budget_and_has_an_energy_glow() -> void:
	for kind in ALL_KINDS:
		var mesh := VoxelWeapons.mesh_of(kind)
		var count := VoxelWeapons.vertex_count(kind)
		gut.p("%s: %d vertices, %d surfaces" % [Weapon.weapon_name(kind), count, mesh.get_surface_count()])
		assert_gt(count, 2000, "%s has real geometry" % Weapon.weapon_name(kind))
		assert_lt(count, VERTEX_BUDGET, "%s stays within the vertex budget" % Weapon.weapon_name(kind))
		var glow := false
		for s in mesh.get_surface_count():
			assert_eq(mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_BONES, 0,
				"%s is rigid (no skin weights): it rides its attach bone" % Weapon.weapon_name(kind))
			var m := mesh.surface_get_material(s) as ShaderMaterial
			var emission: Variant = m.get_shader_parameter(&"emission_value") if m != null else null
			if emission != null and is_equal_approx(float(emission), VoxelWeaponDesign.GLOW_EMISSION):
				glow = true
		assert_true(glow, "%s has GLOW parts in its energy colour" % Weapon.weapon_name(kind))


func test_every_voxel_weapon_keeps_the_old_models_size_and_grip() -> void:
	for kind in ALL_KINDS:
		var old := _box_of(WeaponModels.build(kind))
		var voxel := _box_of(VoxelWeapons.build(kind))
		var name := String(Weapon.weapon_name(kind))
		# Same grip (the origin is in the grip), the same reach along the long axis, and no part
		# further out than the old model's bounds plus 10 cm (its clearance boxes still cover it).
		assert_true(voxel.grow(0.02).has_point(Vector3.ZERO), "%s: the grip is at the origin" % name)
		var axis := old.get_longest_axis_index()
		assert_almost_eq(voxel.size[axis], old.size[axis], old.size[axis] * 0.15,
			"%s: the reach matches the old model" % name)
		assert_true(old.grow(0.1).encloses(voxel), "%s: %s fits in the old model's bounds %s" % [name, voxel, old])


func test_a_voxel_model_has_the_old_models_node_shape() -> void:
	for kind in ALL_KINDS:
		var old := WeaponModels.build(kind)
		var voxel := VoxelWeapons.build(kind)
		assert_eq(voxel.name, old.name, "same root name")
		assert_eq(voxel.scale, old.scale, "%s: same root scale" % Weapon.weapon_name(kind))
		assert_eq(voxel.get_node_or_null("String") != null, old.get_node_or_null("String") != null,
			"%s: a bow keeps its resting string part" % Weapon.weapon_name(kind))
		old.free()
		voxel.free()


func test_old_weapons_stay_the_default() -> void:
	var holder := Node.new()
	var model := WeaponModels.build_for(Weapon.Kind.TITAN_HAMMER, holder)
	assert_false(model.has_meta(&"voxel"), "without a VoxelArmory the old mesh is used")
	model.free()
	model = WeaponModels.build_for(Weapon.Kind.TITAN_HAMMER)
	assert_false(model.has_meta(&"voxel"), "pickups use the old mesh by default")
	model.free()
	holder.free()


func test_a_tagged_holder_or_the_global_flag_gets_the_voxel_model() -> void:
	var holder := Node.new()
	holder.set_meta(WeaponModels.VOXEL_META, true)
	var model := WeaponModels.build_for(Weapon.Kind.STORM_BLADE, holder)
	assert_true(model.has_meta(&"voxel"), "a tagged skeleton gets voxel weapons")
	model.free()
	WeaponModels.voxel_everywhere = true
	model = WeaponModels.build_for(Weapon.Kind.SCATTER_CANNON)
	assert_true(model.has_meta(&"voxel"), "voxel_everywhere swaps pickups too")
	model.free()
	holder.free()


func test_voxel_kael_holds_voxel_weapons_at_the_classic_grip() -> void:
	var view: CharacterView = load("res://game/characters/kael_voxel/kael_voxel.tscn").instantiate()
	add_child_autofree(view)
	var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
	assert_true(bool(skeleton.get_meta(WeaponModels.VOXEL_META, false)), "voxel Kael's VoxelArmory tags his skeleton")
	for kind: Weapon.Kind in [Weapon.Kind.STORM_BLADE, Weapon.Kind.ARC_REVOLVER, Weapon.Kind.KI_GAUNTLETS]:
		var held := WeaponLayer.attach(skeleton, kind)
		assert_eq(held.size(), WeaponGrip.hands_of(kind).size(), "one attachment per hand")
		for node in held:
			var attachment := node as BoneAttachment3D
			var model := attachment.get_child(0) as Node3D
			assert_true(model.has_meta(&"voxel"), "%s is the voxel model" % Weapon.weapon_name(kind))
			assert_eq(model.transform, WeaponGrip.grip_transform(skeleton, kind, attachment.bone_name),
				"%s sits at the classic grip on %s" % [Weapon.weapon_name(kind), attachment.bone_name])
			node.queue_free()


func test_a_voxel_armory_swaps_brann_s_stowed_weapons() -> void:
	var view: CharacterView = Roster.character(&"brann").scene.instantiate()
	var armory := VoxelArmory.new()
	view.add_child(armory)
	add_child_autofree(view)
	var stowed := (view as BrannView).stowed_weapons()
	assert_eq(stowed.size(), 2, "hammer and cannon are stowed")
	for node in stowed:
		assert_true((node.get_child(0) as Node3D).has_meta(&"voxel"), "%s is stowed as its voxel model" % node.name)


func test_brann_keeps_the_old_stowed_weapons_without_an_armory() -> void:
	var view: CharacterView = Roster.character(&"brann").scene.instantiate()
	add_child_autofree(view)
	for node in (view as BrannView).stowed_weapons():
		assert_false((node.get_child(0) as Node3D).has_meta(&"voxel"), "%s is the old model" % node.name)


## The model's mesh bounds in its own (root) space, including the root's scale.
func _box_of(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.name == "String":
			continue
		var to_root := Transform3D.IDENTITY
		var at: Node = part
		while at != model:
			to_root = (at as Node3D).transform * to_root
			at = at.get_parent()
		var b := Transform3D(model.basis, Vector3.ZERO) * to_root * part.get_aabb()
		box = b if first else box.merge(b)
		first = false
	model.free()
	return box
