extends GutTest
## Voxel Brann's held weapons stay out of his bulky stone body in every held pose (QA-20).

## Deepest a held weapon may reach into his body (m): VisualQa's overlap tolerance.
const MAX_DEPTH := VisualQa.OVERLAP_TOLERANCE
## His own weapons and the pickups he holds most.
const KINDS: Array[Weapon.Kind] = [Weapon.Kind.TITAN_HAMMER, Weapon.Kind.SCATTER_CANNON,
	Weapon.Kind.EMBER_SCYTHE, Weapon.Kind.STORM_REPEATER, Weapon.Kind.HEARTSTRING_BOW]
## Lock-on targets around him (world offsets): ahead, both sides, behind, high.
const LOOKS: Array[Vector3] = [Vector3(0, 0, -4), Vector3(4, 0, 0), Vector3(-4, 0, 0), Vector3(0, 0, 4), Vector3(2, 3, -2)]
const FRAMES_PER_POSE := 24


func _view() -> CharacterView:
	var view: CharacterView = Roster.character(&"brann").voxel_scene.instantiate()
	add_child_autofree(view)
	return view


## Held poses in a row: idle, guard, run, flight, dash, hit and block reactions, then each attack.
func _poses(kind: Weapon.Kind, stats: FighterStats) -> Array:
	var poses: Array = []
	for state: FighterState.State in [FighterState.State.IDLE, FighterState.State.BLOCKING, FighterState.State.MOVING,
			FighterState.State.FLYING, FighterState.State.DASHING, FighterState.State.HITSTUN,
			FighterState.State.BLOCKSTUN, FighterState.State.IDLE]:
		poses.append(state)
	var moves := WeaponMoves.move_set(kind, stats.move_set)
	poses.append_array(moves.light_string)
	for slot: String in ["smash", "launcher", "rising", "spike", "sweep"]:
		if moves.get(slot) != null:
			poses.append(moves.get(slot))
	return poses


## Worst overlap (m) of kind's drawn model with the capsules VisualQa tests, through every held pose.
func _worst_depth(kind: Weapon.Kind) -> Array:
	var view := _view()
	var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
	var held := WeaponLayer.attach(skeleton, kind)
	var drawn: Array[Transform3D] = []
	skeleton.skeleton_updated.connect(func() -> void:
		drawn.resize(skeleton.get_bone_count())
		for b in drawn.size():
			drawn[b] = skeleton.get_bone_global_pose(b))
	var names: Array = MotionLayers.CLEAR_OF[WeaponGrip.hands_of(kind)[0]]
	if WeaponGrip.off_hand_of(kind) != Vector3.INF:
		names = names.filter(func(n: StringName) -> bool: return not n.begins_with("lower_arm"))
	var fighter := FighterState.new()
	fighter.stats = Roster.character(&"brann").stats
	fighter.weapons[0] = kind
	fighter.active_slot = 0
	var worst := [-INF, ""]
	var frame := 0
	for pose: Variant in _poses(kind, fighter.stats):
		var label := String((pose as MoveData).id) if pose is MoveData else String(FighterState.State.find_key(pose))
		var ticks := FRAMES_PER_POSE
		if pose is MoveData:
			fighter.begin_move(pose)
			ticks = fighter.move_total_ticks()
		else:
			fighter.enter_state(pose)
			fighter.velocity = Vector3.FORWARD * (20.0 if pose == FighterState.State.DASHING else 6.0)
			if pose == FighterState.State.DASHING:
				fighter.dash_kind = FighterState.DashKind.SUSTAINED
				fighter.dash_direction = Vector3.FORWARD
		var airborne: bool = pose in [FighterState.State.FLYING, FighterState.State.DASHING]
		fighter.position.y = fighter.stand_height + (5.0 if airborne else 0.0)
		for f in ticks:
			var look := LOOKS[(frame / 6) % LOOKS.size()]
			view.set_look_target(fighter.position + look)
			if f == 2 and pose in [FighterState.State.HITSTUN, FighterState.State.BLOCKSTUN]:
				view.react_to_event({"type": CombatSim.EventType.HIT, "knockback_type": MoveData.KnockbackType.LAUNCH,
					"position": fighter.position + look}, fighter)
			view.apply_state(fighter, 1.0 / 60.0)
			await get_tree().process_frame
			fighter.state_ticks += 1
			if pose is MoveData:
				fighter.move_tick += 1
			frame += 1
			if drawn.is_empty() or frame < 6:
				continue
			var capsules := view.body.capsules(func(b: int) -> Transform3D: return drawn[b], skeleton.global_transform, names)
			var boxes: Array[Transform3D] = []
			for node in held:
				var model := node.get_child(0) as Node3D
				for box in WeaponGrip.part_boxes(model):
					boxes.append(model.global_transform * box)
			var depth := float(BodyCapsules.deepest_box(capsules, boxes)[0])
			if depth > float(worst[0]):
				worst = [depth, label]
	return worst


func test_every_held_weapon_stays_out_of_his_body_in_every_held_pose() -> void:
	for kind in KINDS:
		var worst := await _worst_depth(kind)
		gut.p("%s: worst %.3f m (%s)" % [Weapon.weapon_name(kind), worst[0], worst[1]])
		assert_lt(float(worst[0]), MAX_DEPTH, "%s dips %.1f cm into him in %s" % [Weapon.weapon_name(kind),
			float(worst[0]) * 100.0, worst[1]])


func test_the_clearance_solver_keeps_out_the_voxel_model_he_draws() -> void:
	var view := _view()
	var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
	var fighter := FighterState.new()
	fighter.stats = Roster.character(&"brann").stats
	fighter.active_slot = 0
	for kind in KINDS:
		fighter.weapons[0] = kind
		view.apply_state(fighter, 1.0 / 60.0)
		var model := WeaponModels.build_for(kind, skeleton)
		model.transform = Transform3D.IDENTITY
		assert_true(model.has_meta(&"voxel"), "%s is drawn as voxels" % Weapon.weapon_name(kind))
		var drawn := WeaponGrip.part_boxes(model, true)
		assert_eq(view.layers.weapon_boxes.slice(0, drawn.size()), drawn, Weapon.weapon_name(kind))
		model.free()


func test_his_stone_torso_never_scales_so_the_arms_stay_where_the_solver_put_them() -> void:
	var view := _view()
	var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
	var fighter := FighterState.new()
	fighter.stats = Roster.character(&"brann").stats
	fighter.weapons[0] = Weapon.Kind.TITAN_HAMMER
	fighter.active_slot = 0
	for state: FighterState.State in [FighterState.State.IDLE, FighterState.State.HITSTUN, FighterState.State.BLOCKSTUN]:
		fighter.enter_state(state)
		for f in 40:
			view.apply_state(fighter, 1.0 / 60.0)
			for bone: StringName in BrannView.LAYER_BONES:
				var scale := skeleton.get_bone_pose_scale(skeleton.find_bone(bone))
				if not scale.is_equal_approx(Vector3.ONE):
					assert_eq(scale, Vector3.ONE, "%s %s frame %d" % [bone, FighterState.State.find_key(state), f])
					return
	pass_test("no torso bone scaled")
