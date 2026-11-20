extends GutTest
## Brann's weapons (#98): the held hammer stays out of his torso, the stowed pair stays off the ground.


func _view() -> CharacterView:
	var view: CharacterView = Roster.character(&"brann").scene.instantiate()
	add_child_autofree(view)
	return view


## Deepest overlap (m) of the held weapon's parts with the torso capsules after 30 frames in state.
func _held_depth(kind: Weapon.Kind, state: FighterState.State, head_only := false) -> float:
	var view := _view()
	var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
	var held := WeaponLayer.attach(skeleton, kind)
	var poses: Array[Transform3D] = []
	skeleton.skeleton_updated.connect(func() -> void:
		poses.resize(skeleton.get_bone_count())
		for b in poses.size():
			poses[b] = skeleton.get_bone_global_pose(b))
	var fighter := FighterState.new()
	fighter.stats = Roster.character(&"brann").stats
	fighter.weapons[0] = kind
	fighter.active_slot = 0
	fighter.enter_state(state)
	for _f in 30:
		view.apply_state(fighter, 1.0 / 60.0)
		await get_tree().process_frame
	var torso := view.body.capsules(func(b: int) -> Transform3D: return poses[b],
		skeleton.global_transform, [&"pelvis", &"chest", &"head"])
	var boxes: Array[Transform3D] = []
	var model := held[0].get_child(0) as Node3D
	for box in WeaponGrip.part_boxes(model):
		# The hammer head sits past 0.7 m up the handle (model space).
		if not head_only or box.origin.y > 0.7:
			boxes.append(model.global_transform * box)
	return float(BodyCapsules.deepest_box(torso, boxes)[0])


func test_the_hammer_held_in_guard_stays_out_of_his_torso() -> void:
	for state: FighterState.State in [FighterState.State.BLOCKING, FighterState.State.IDLE]:
		var depth := await _held_depth(Weapon.Kind.TITAN_HAMMER, state)
		gut.p("%s depth %.3f" % [FighterState.State.find_key(state), depth])
		assert_lt(depth, 0.0, "%s: the hammer is clear of the torso" % FighterState.State.find_key(state))
		var head := await _held_depth(Weapon.Kind.TITAN_HAMMER, state, true)
		gut.p("%s head depth %.3f" % [FighterState.State.find_key(state), head])
		assert_lt(head, -0.12, "%s: the hammer head stays well clear of his chest and head" % FighterState.State.find_key(state))


func test_the_stowed_weapons_stay_well_off_the_ground_at_idle() -> void:
	var view := _view()
	var fighter := FighterState.new()
	fighter.enter_state(FighterState.State.IDLE)
	for _f in 30:
		view.apply_state(fighter, 1.0 / 60.0)
		await get_tree().process_frame
	var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
	var soles := view.body.lowest_sole(func(b: int) -> Transform3D: return skeleton.get_bone_global_pose(b),
		skeleton.global_transform).y
	for node in (view as BrannView).stowed_weapons():
		for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			var box := mesh.global_transform * mesh.get_aabb()
			assert_gt(box.position.y - soles, 0.3, "%s %s stays 30 cm above the soles" % [node.name, mesh.name])


func test_the_scatter_cannon_barrel_is_iron_not_a_gold_cone() -> void:
	var model := WeaponModels.build(Weapon.Kind.SCATTER_CANNON)
	var biggest: MeshInstance3D
	var volume := 0.0
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var size := mesh.get_aabb().size
		if size.x * size.y * size.z > volume:
			volume = size.x * size.y * size.z
			biggest = mesh
	var color: Color = (biggest.material_override as ShaderMaterial).get_shader_parameter("albedo_color")
	assert_lt(color.s, 0.5, "the biggest part is low-saturation iron, not saturated gold")
	model.free()
