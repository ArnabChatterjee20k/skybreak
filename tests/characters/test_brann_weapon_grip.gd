extends GutTest
## Voxel Brann's held weapons (QA-20): every weapon clear of his body in every held pose,
## measured like VisualQa's weapon_vs_holder on the pose as drawn.

const FRAME := 1.0 / 60.0


func _brann() -> CharacterView:
	var view: CharacterView = Roster.character(&"brann").voxel_scene.instantiate()
	add_child_autofree(view)
	return view


func _fighter(kind: Weapon.Kind) -> FighterState:
	var fighter := FighterState.new()
	fighter.stats = Roster.character(&"brann").stats
	fighter.weapons[0] = kind
	fighter.ammo[0] = Weapon.full_ammo(kind)
	fighter.active_slot = 0
	return fighter


## Every distinct attack a weapon performs.
static func _moves(kind: Weapon.Kind, unarmed: MoveSet) -> Array[MoveData]:
	var set := WeaponMoves.move_set(kind, unarmed)
	var out: Array[MoveData] = []
	var seen := {}
	var all: Array = set.light_string.duplicate()
	all.append_array([set.smash, set.breaker, set.launcher, set.rising, set.spike, set.sweep])
	for move: MoveData in all:
		if move != null and not seen.has(move.id):
			seen[move.id] = true
			out.append(move)
	return out


func test_voxel_brann_holds_every_weapon_clear_of_his_body_in_every_held_pose() -> void:
	var view := _brann()
	var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
	assert_true(bool(skeleton.get_meta(WeaponModels.VOXEL_META, false)), "voxel Brann draws voxel weapons")
	var poses: Array[Transform3D] = []
	skeleton.skeleton_updated.connect(func() -> void:
		poses.resize(skeleton.get_bone_count())
		for b in poses.size():
			poses[b] = skeleton.get_bone_global_pose(b))
	for kind: Weapon.Kind in Weapon.Kind.values().slice(1):
		var hands := WeaponGrip.hands_of(kind)
		if hands.size() != 1:
			continue
		var held := WeaponLayer.attach(skeleton, kind)
		var model := held[0].get_child(0) as Node3D
		var names: Array = MotionLayers.CLEAR_OF[hands[0]]
		if WeaponGrip.off_hand_of(kind) != Vector3.INF:
			names = names.filter(func(n: StringName) -> bool: return not n.begins_with("lower_arm"))
		var fighter := _fighter(kind)
		var worst := [-INF, ""]
		var measure := func(label: String) -> void:
			var capsules := view.body.capsules(func(b: int) -> Transform3D: return poses[b],
				skeleton.global_transform, names)
			var boxes: Array[Transform3D] = []
			for box in WeaponGrip.part_boxes(model):
				boxes.append(model.global_transform * box)
			var hit := BodyCapsules.deepest_box(capsules, boxes)
			if float(hit[0]) > float(worst[0]):
				worst[0] = float(hit[0])
				worst[1] = "%s (%s)" % [label, hit[2]]
		var held_states := {FighterState.State.IDLE: Vector3.ZERO, FighterState.State.BLOCKING: Vector3.ZERO,
			FighterState.State.MOVING: Vector3(0, 0, 6), FighterState.State.FLYING: Vector3(0, 0, 9)}
		for state: FighterState.State in held_states:
			fighter.enter_state(state)
			fighter.velocity = held_states[state]
			fighter.position.y = fighter.stand_height + (5.0 if state == FighterState.State.FLYING else 0.0)
			for f in 30:
				fighter.state_ticks = f
				view.apply_state(fighter, FRAME)
				await get_tree().process_frame
				if f >= 8:
					measure.call(String(FighterState.State.find_key(state)))
		fighter.velocity = Vector3.ZERO
		fighter.position.y = fighter.stand_height
		for move in _moves(kind, fighter.stats.move_set):
			fighter.enter_state(FighterState.State.IDLE)
			for f in 6:
				view.apply_state(fighter, FRAME)
				await get_tree().process_frame
			fighter.begin_move(move)
			for t in move.total_ticks():
				fighter.move_tick = t
				fighter.state_ticks = t
				view.apply_state(fighter, FRAME)
				await get_tree().process_frame
				measure.call("%s tick %d" % [move.id, t])
		assert_lte(float(worst[0]), VisualQa.OVERLAP_TOLERANCE, "%s: deepest %.3f m in %s" % [
			Weapon.Kind.find_key(kind), worst[0], worst[1]])
		for node in held:
			node.free()


func test_his_fist_clearance_turns_the_arm_without_scaling_it() -> void:
	var view := _brann()
	var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
	var fighter := _fighter(Weapon.Kind.SCATTER_CANNON)
	fighter.enter_state(FighterState.State.BLOCKING)
	var worst := 0.0
	for f in 60:
		fighter.state_ticks = f
		view.apply_state(fighter, FRAME)
		await get_tree().process_frame
		for bone: StringName in [&"LeftUpperArm", &"RightUpperArm"]:
			var scale := skeleton.get_bone_pose_scale(skeleton.find_bone(bone))
			worst = maxf(worst, (scale - Vector3.ONE).abs()[(scale - Vector3.ONE).abs().max_axis_index()])
	# The breath scales his upper chest; a global pose write folded that skew into the arm (QA-20).
	assert_lt(worst, 1e-3, "upper arms keep unit scale")


func test_the_clearance_covers_the_voxel_weapon_he_draws() -> void:
	var view := _brann()
	var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
	for kind: Weapon.Kind in [Weapon.Kind.STORM_BLADE, Weapon.Kind.TITAN_HAMMER, Weapon.Kind.SCATTER_CANNON]:
		assert_true(WeaponModels.is_voxel_for(kind, skeleton), "%s is drawn as voxels" % Weapon.Kind.find_key(kind))
		var fighter := _fighter(kind)
		view.apply_state(fighter, FRAME)
		var drawn := VoxelWeapons.build(kind)
		var voxel_boxes := WeaponGrip.part_boxes(drawn)
		drawn.free()
		for box in voxel_boxes:
			assert_true(view.layers.weapon_boxes.has(box), "%s: every drawn voxel slice is kept clear" % Weapon.Kind.find_key(kind))
