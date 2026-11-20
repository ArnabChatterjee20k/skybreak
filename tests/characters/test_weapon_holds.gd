extends GutTest
## Weapon holds (T-D30): grips, scale to the hand, hold classes and body clearance.


func _view(id: StringName) -> CharacterView:
	var view: CharacterView = Roster.character(id).scene.instantiate()
	add_child_autofree(view)
	return view


func test_every_weapon_has_a_hold_class_and_a_hand() -> void:
	for kind: Weapon.Kind in Weapon.Kind.values().slice(1):
		assert_ne(WeaponGrip.hold_of(kind), WeaponGrip.Hold.NONE, Weapon.weapon_name(kind))
		assert_false(WeaponGrip.hands_of(kind).is_empty(), Weapon.weapon_name(kind))


func test_two_handed_weapons_have_an_off_hand_grip() -> void:
	for kind: Weapon.Kind in Weapon.Kind.values().slice(1):
		var hold := WeaponGrip.hold_of(kind)
		var two := hold == WeaponGrip.Hold.HEAVY or hold == WeaponGrip.Hold.BRACED
		assert_eq(WeaponGrip.off_hand_of(kind) != Vector3.INF, two, Weapon.weapon_name(kind))


func test_weapons_scale_with_the_holders_hand() -> void:
	for id: StringName in Roster.ids():
		var view := _view(id)
		var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
		var grip := WeaponGrip.grip_transform(skeleton, Weapon.Kind.KI_BOW, WeaponGrip.LEFT_HAND)
		var expected := 0.7 * WeaponGrip.hand_size(skeleton, WeaponGrip.LEFT_HAND) / WeaponGrip.REFERENCE_HAND
		assert_almost_eq(grip.basis.get_scale().x, expected, 0.001, String(id))
		# The bow is no taller than the legend: about 1 m against ~1.6 m.
		assert_lt(1.4 * grip.basis.get_scale().x, 1.2, String(id))


func test_every_legend_measures_body_capsules_and_soles() -> void:
	for id: StringName in Roster.ids():
		var view := _view(id)
		assert_not_null(view.body, String(id))
		assert_gt(float(view.body.radii[&"chest"]), 0.1, String(id))
		assert_gt(float(view.body.radii[&"head"]), 0.1, String(id))
		assert_false(view.body.soles.is_empty(), String(id))


func test_every_legend_has_arm_ik_for_weapons() -> void:
	for id: StringName in Roster.ids():
		assert_not_null(_view(id).layers, String(id))


func test_a_box_inside_a_capsule_is_pushed_out() -> void:
	var box := Transform3D(Basis.from_scale(Vector3.ONE * 0.1), Vector3(0.05, 0.5, 0))
	var hit := BodyCapsules.box_depth(Vector3.ZERO, Vector3(0, 1, 0), 0.2, box)
	assert_gt(float(hit[0]), 0.2)
	assert_gt((hit[1] as Vector3).x, 0.5, "pushed out along +X")


func test_a_far_box_is_clear_of_a_capsule() -> void:
	var box := Transform3D(Basis.from_scale(Vector3.ONE * 0.1), Vector3(1, 0.5, 0))
	assert_lt(float(BodyCapsules.box_depth(Vector3.ZERO, Vector3(0, 1, 0), 0.2, box)[0]), 0.0)


func test_airborne_is_judged_against_the_fighters_own_floor() -> void:
	var fighter := FighterState.new()
	fighter.stand_height = 41.0
	fighter.position = Vector3(0, 41.0, 0)
	assert_false(CharacterView.is_airborne(fighter), "standing on a 40 m hill")
	fighter.position.y = 43.0
	assert_true(CharacterView.is_airborne(fighter))


func test_the_bow_draw_keeps_the_string_and_arrow_a_centimetre_beside_the_face() -> void:
	for id: StringName in Roster.ids():
		var view := _view(id)
		var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
		var held := WeaponLayer.attach(skeleton, Weapon.Kind.KI_BOW)
		var string := held[0].find_child("BowString", true, false) as BowString
		string.drawn = true
		# The drawn pose: bone poses once the modifiers ran (the skeleton restores the clip pose after).
		var poses: Array[Transform3D] = []
		skeleton.skeleton_updated.connect(func() -> void:
			poses.resize(skeleton.get_bone_count())
			for b in poses.size():
				poses[b] = skeleton.get_bone_global_pose(b))
		var fighter := FighterState.new()
		fighter.stats = Roster.character(id).stats
		fighter.weapons[0] = Weapon.Kind.KI_BOW
		fighter.active_slot = 0
		fighter.begin_move(WeaponMoves.move_set(Weapon.Kind.KI_BOW, fighter.stats.move_set).light_string[0])
		for _f in 20:
			view.apply_state(fighter, 1.0 / 60.0)
			await get_tree().process_frame
		var head: Array = view.body.capsules(func(b: int) -> Transform3D: return poses[b],
			skeleton.global_transform, [&"head"])[&"head"]
		assert_lt(BodyCapsules.segment_depth(string.tip_top, string.nock, head), -0.01, "%s upper string" % id)
		assert_lt(BodyCapsules.segment_depth(string.nock, string.tip_bottom, head), -0.01, "%s lower string" % id)
		assert_lt(BodyCapsules.segment_depth(string.nock, string.arrow_tip, head), -0.01, "%s arrow" % id)
		assert_gt(string.nock.distance_to(string.tip_top), 0.3, "%s string is drawn" % id)


func test_a_drawn_bow_shows_exactly_one_arrow_on_its_string() -> void:
	var view := _view(&"kael")
	var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
	var held := WeaponLayer.attach(skeleton, Weapon.Kind.HEARTSTRING_BOW)
	var string := held[0].find_child("BowString", true, false) as BowString
	assert_eq(held[0].find_children("NockedArrow", "", true, false).size(), 1, "one nocked arrow")
	assert_eq(string.arrow, held[0].find_child("NockedArrow", true, false), "the string carries it")
	assert_eq(string.find_children("*", "MeshInstance3D", true, false).size(), 2, "the string draws only its two halves")


func _deepest_box_by_pairs(capsule_set: Dictionary, boxes: Array[Transform3D]) -> Array:
	var result := [-INF, Vector3.ZERO, &"", Vector3.ZERO, Vector3.ZERO]
	for name: StringName in capsule_set:
		var c: Array = capsule_set[name]
		for box in boxes:
			var reach := box.basis.x.length() + box.basis.y.length() + box.basis.z.length()
			var p: Vector3 = box.origin
			if p.distance_to(Geometry3D.get_closest_point_to_segment(p, c[0], c[1])) > reach + float(c[2]):
				continue
			var hit := BodyCapsules.box_depth(c[0], c[1], c[2], box)
			if hit[0] > result[0]:
				result = [hit[0], hit[1], name, hit[2], box.origin]
	return result


func test_deepest_box_matches_box_depth_over_every_pair_exactly() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 30
	var v := func(s: float) -> Vector3: return Vector3(rng.randf_range(-s, s), rng.randf_range(-s, s), rng.randf_range(-s, s))
	var hits := 0
	for trial in 400:
		var capsules := {}
		for name: StringName in [&"pelvis", &"chest", &"head", &"upper_arm_l", &"upper_arm_r"]:
			var a: Vector3 = v.call(0.4)
			capsules[name] = [a, a + v.call(0.3), rng.randf_range(0.04, 0.15)]
		var boxes: Array[Transform3D] = []
		var weapon := Transform3D(Basis.from_euler(v.call(PI)), v.call(0.5))
		for i in rng.randi_range(1, 16):
			var basis := Basis.from_euler(v.call(PI)).scaled(Vector3(rng.randf_range(0.01, 0.3),
				rng.randf_range(0.01, 0.3), rng.randf_range(0.01, 0.3)))
			boxes.append(weapon * Transform3D(basis, v.call(0.6)))
		var expected := _deepest_box_by_pairs(capsules, boxes)
		assert_eq(BodyCapsules.deepest_box(capsules, boxes), expected, "trial %d" % trial)
		if float(expected[0]) > 0.0:
			hits += 1
	assert_gt(hits, 50, "enough trials overlap")


func test_a_bow_in_a_hit_reaction_or_in_flight_is_held_clear_of_the_body() -> void:
	var cases := {FighterState.State.HITSTUN: MotionLayers.ArmPose.BOW_TUCK,
		FighterState.State.FLYING: MotionLayers.ArmPose.BOW_FLY}
	for id: StringName in Roster.ids():
		for state: FighterState.State in cases:
			var view := _view(id)
			var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
			var held := WeaponLayer.attach(skeleton, Weapon.Kind.HEARTSTRING_BOW)
			var poses: Array[Transform3D] = []
			skeleton.skeleton_updated.connect(func() -> void:
				poses.resize(skeleton.get_bone_count())
				for b in poses.size():
					poses[b] = skeleton.get_bone_global_pose(b))
			var fighter := FighterState.new()
			fighter.stats = Roster.character(id).stats
			fighter.weapons[0] = Weapon.Kind.HEARTSTRING_BOW
			fighter.active_slot = 0
			fighter.enter_state(state)
			if state == FighterState.State.FLYING:
				fighter.position.y = fighter.stand_height + 5.0
			for _f in 20:
				view.apply_state(fighter, 1.0 / 60.0)
				await get_tree().process_frame
			var label := "%s %s" % [id, FighterState.State.find_key(state)]
			assert_eq(view.layers.arm_pose, cases[state], label)
			var torso := view.body.capsules(func(b: int) -> Transform3D: return poses[b],
				skeleton.global_transform, [&"pelvis", &"chest", &"head"])
			var boxes: Array[Transform3D] = []
			for box in WeaponGrip.part_boxes(held[0]):
				boxes.append(held[0].global_transform * box)
			assert_lt(float(BodyCapsules.deepest_box(torso, boxes)[0]), 0.0, "%s: the bow is clear of the torso" % label)


func test_a_bow_hands_the_solver_its_boxes_without_the_resting_string() -> void:
	var view := _view(&"lyra")
	var fighter := FighterState.new()
	fighter.stats = Roster.character(&"lyra").stats
	fighter.weapons[0] = Weapon.Kind.HEARTSTRING_BOW
	fighter.active_slot = 0
	view.apply_state(fighter, 1.0 / 60.0)
	assert_eq(view.layers.weapon_drawn_boxes.size(), WeaponGrip.model_boxes(Weapon.Kind.HEARTSTRING_BOW).size())
	assert_lt(view.layers.weapon_drawn_boxes.size(), view.layers.weapon_boxes.size(), "the resting string is left out")
	fighter.weapons[0] = Weapon.Kind.SKY_LANCE
	view.apply_state(fighter, 1.0 / 60.0)
	assert_true(view.layers.weapon_drawn_boxes.is_empty(), "no drawn string on a lance")


func test_a_segment_box_covers_its_segment_as_thick_as_a_string() -> void:
	var box := MotionLayers._segment_box(Vector3(0, 0, 0), Vector3(0, 0, -1))
	var through := {&"head": [Vector3(-1, 0, -0.5), Vector3(1, 0, -0.5), 0.1]}
	var beside := {&"head": [Vector3(-1, 0.2, -0.5), Vector3(1, 0.2, -0.5), 0.1]}
	var past := {&"head": [Vector3(-1, 0, -1.2), Vector3(1, 0, -1.2), 0.1]}
	assert_gt(float(BodyCapsules.deepest_box(through, [box])[0]), 0.09, "a capsule across the middle overlaps")
	assert_lt(float(BodyCapsules.deepest_box(beside, [box])[0]), -0.05, "20 cm off the segment is clear")
	assert_lt(float(BodyCapsules.deepest_box(past, [box])[0]), -0.05, "past the end is clear")


func test_a_bow_drawn_out_of_a_hit_reaction_never_passes_through_the_chest() -> void:
	for id: StringName in Roster.ids():
		var view := _view(id)
		var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
		var held := WeaponLayer.attach(skeleton, Weapon.Kind.HEARTSTRING_BOW)
		var poses: Array[Transform3D] = []
		skeleton.skeleton_updated.connect(func() -> void:
			poses.resize(skeleton.get_bone_count())
			for b in poses.size():
				poses[b] = skeleton.get_bone_global_pose(b))
		var fighter := FighterState.new()
		fighter.stats = Roster.character(id).stats
		fighter.weapons[0] = Weapon.Kind.HEARTSTRING_BOW
		fighter.active_slot = 0
		fighter.enter_state(FighterState.State.HITSTUN)
		for _f in 20:
			view.apply_state(fighter, 1.0 / 60.0)
			await get_tree().process_frame
		# The tucked bow swings up into the draw: the biggest arm turn a bow makes.
		fighter.begin_move(WeaponMoves.move_set(Weapon.Kind.HEARTSTRING_BOW, fighter.stats.move_set).light_string[0])
		var deepest := -INF
		for _f in 16:
			view.apply_state(fighter, 1.0 / 60.0)
			await get_tree().process_frame
			var torso := view.body.capsules(func(b: int) -> Transform3D: return poses[b],
				skeleton.global_transform, [&"pelvis", &"chest", &"head"])
			var boxes: Array[Transform3D] = []
			for box in WeaponGrip.part_boxes(held[0]):
				boxes.append(held[0].global_transform * box)
			deepest = maxf(deepest, float(BodyCapsules.deepest_box(torso, boxes)[0]))
		assert_lt(deepest, VisualQa.OVERLAP_TOLERANCE, "%s: the bow stays out of the body through the draw" % id)
