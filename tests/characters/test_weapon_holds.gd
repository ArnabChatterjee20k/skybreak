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


func test_the_bow_draw_keeps_the_string_beside_the_face() -> void:
	for id: StringName in Roster.ids():
		var view := _view(id)
		var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
		var held := WeaponLayer.attach(skeleton, Weapon.Kind.KI_BOW)
		var string := held[0].find_child("BowString", true, false) as BowString
		string.drawn = true
		var fighter := FighterState.new()
		fighter.stats = Roster.character(id).stats
		fighter.weapons[0] = Weapon.Kind.KI_BOW
		fighter.active_slot = 0
		fighter.begin_move(WeaponMoves.move_set(Weapon.Kind.KI_BOW, fighter.stats.move_set).light_string[0])
		for _f in 20:
			view.apply_state(fighter, 1.0 / 60.0)
			await get_tree().process_frame
		var head: Array = view.body.capsules(func(b: int) -> Transform3D: return skeleton.get_bone_global_pose(b),
			skeleton.global_transform, [&"head"])[&"head"]
		assert_lt(BodyCapsules.segment_depth(string.tip_top, string.nock, head), 0.0, "%s upper string" % id)
		assert_lt(BodyCapsules.segment_depth(string.nock, string.tip_bottom, head), 0.0, "%s lower string" % id)
		assert_lt(BodyCapsules.segment_depth(string.nock, string.arrow_tip, head), 0.0, "%s arrow" % id)
		assert_gt(string.nock.distance_to(string.tip_top), 0.3, "%s string is drawn" % id)
