extends GutTest
## Specials on the voxel legends (T-SP1 x voxel art): every special move plays a
## motion clip on the voxel rig, and the hand glow sits on the rig's hand bones
## with the voxel glow material while a special runs.

const RIGS := {
	"kael": ["res://game/characters/kael_voxel/kael_voxel.tscn",
		"res://game/combat/moves/kael/kael_fighter_stats.tres"],
	"vexa": ["res://game/characters/vexa_voxel/vexa_voxel.tscn",
		"res://game/combat/vexa_fighter_stats.tres"],
}
const FRAME := 1.0 / 60.0


func _view(legend: String) -> CharacterView:
	var view := (load(RIGS[legend][0]) as PackedScene).instantiate() as CharacterView
	add_child_autofree(view)
	return view


func _fighter(legend: String) -> FighterState:
	var fighter := FighterState.new()
	fighter.stats = load(RIGS[legend][1]) as FighterStats
	return fighter


func _moves_of(kit: SpecialKit) -> Array[MoveData]:
	var moves: Array[MoveData] = []
	var all: Array[SpecialMove] = kit.specials.duplicate()
	if kit.ultimate:
		all.append(kit.ultimate)
	for special in all:
		for move in [special.move, special.rise_move, special.dive_move, special.counter_move]:
			if move != null:
				moves.append(move)
	return moves


func _attack(fighter: FighterState, move: MoveData, tick: int) -> void:
	fighter.state = FighterState.State.ATTACKING
	fighter.move = move
	fighter.move_tick = tick
	fighter.state_ticks = tick


func _hand(view: CharacterView, bone: StringName) -> Vector3:
	var skeleton := view.model.get_node("%GeneralSkeleton") as Skeleton3D
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


func test_every_special_move_plays_a_motion_clip_on_the_voxel_rigs() -> void:
	for legend: String in RIGS:
		var view := _view(legend)
		var kit := SpecialRules.kit_of(_fighter(legend))
		assert_not_null(kit, "%s has a special kit" % legend)
		var moves := _moves_of(kit)
		assert_gt(moves.size(), 2, "%s has special moves" % legend)
		for move in moves:
			assert_ne(view._motion_move_clip(move.id), &"", "%s %s has a clip on the voxel rig" % [legend, move.id])


func test_a_special_lights_a_glow_orb_on_each_voxel_hand_bone() -> void:
	for legend: String in RIGS:
		var view := _view(legend)
		var fighter := _fighter(legend)
		var special: SpecialMove = SpecialRules.kit_of(fighter).specials[0]
		_attack(fighter, special.move, special.move.startup_ticks)
		view.apply_state(fighter, FRAME)
		# The sockets follow the skeleton's pose update, which runs at the end of the frame.
		await wait_physics_frames(2)
		assert_not_null(view.special_glow, "%s builds the hand glow" % legend)
		assert_eq(view.special_glow.orbs.size(), 2, "%s: one orb per hand" % legend)
		var sockets := [WeaponGrip.RIGHT_HAND, WeaponGrip.LEFT_HAND]
		for i in 2:
			var orb := view.special_glow.orbs[i]
			assert_true(orb.visible, "%s orb %d is lit" % [legend, i])
			var socket := orb.get_parent() as BoneAttachment3D
			assert_eq(socket.bone_name, sockets[i], "%s orb %d rides its hand bone" % [legend, i])
			# Read outside the skeleton update, the pose lacks the motion layers' few cm.
			var own := orb.global_position.distance_to(_hand(view, sockets[i]))
			var other := orb.global_position.distance_to(_hand(view, sockets[1 - i]))
			assert_lt(own, 0.12, "%s orb %d sits on its hand" % [legend, i])
			assert_lt(own, other, "%s orb %d is on its own hand, not the other" % [legend, i])
			var radius := orb.global_transform.basis.get_scale().x
			assert_almost_eq(radius, SpecialHandGlow.RADIUS, 0.002, "%s orb %d is world-sized" % [legend, i])


func test_the_hand_glow_uses_the_voxel_glow_material_in_the_special_colour() -> void:
	var view := _view("kael")
	var fighter := _fighter("kael")
	var special: SpecialMove = SpecialRules.kit_of(fighter).specials[0]
	_attack(fighter, special.move, 0)
	view.apply_state(fighter, FRAME)
	var mat := view.special_glow.orbs[0].material_override as StandardMaterial3D
	assert_not_null(mat, "a StandardMaterial3D")
	assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_PER_PIXEL, "lit, so emission shows")
	assert_eq(mat.albedo_color, Color.BLACK, "black albedo")
	assert_true(mat.emission_enabled)
	assert_eq(mat.emission, special.color, "the special's colour")
	assert_almost_eq(mat.emission_energy_multiplier, SpecialHandGlow.ENERGY * 0.27, 0.0001, "x GLOW_GAIN 0.27")


func test_the_hand_glow_swells_through_startup_and_goes_out_after_the_special() -> void:
	var view := _view("vexa")
	var fighter := _fighter("vexa")
	var special: SpecialMove = SpecialRules.kit_of(fighter).specials[0]
	_attack(fighter, special.move, 0)
	view.apply_state(fighter, FRAME)
	var early := view.special_glow.orbs[0].global_transform.basis.get_scale().x
	_attack(fighter, special.move, special.move.startup_ticks)
	view.apply_state(fighter, FRAME)
	var late := view.special_glow.orbs[0].global_transform.basis.get_scale().x
	assert_lt(early, late, "smaller on the first tick than at the active frame")
	fighter.state = FighterState.State.IDLE
	fighter.move = null
	view.apply_state(fighter, FRAME)
	for orb in view.special_glow.orbs:
		assert_false(orb.visible, "out once the special ends")


func test_a_normal_attack_does_not_light_the_hand_glow() -> void:
	var view := _view("kael")
	var fighter := _fighter("kael")
	var special: SpecialMove = SpecialRules.kit_of(fighter).specials[0]
	_attack(fighter, special.move, 0)
	view.apply_state(fighter, FRAME)
	_attack(fighter, fighter.stats.move_set.light_string[0], 2)
	view.apply_state(fighter, FRAME)
	for orb in view.special_glow.orbs:
		assert_false(orb.visible, "no glow on a normal")


func test_a_legend_without_a_kit_builds_no_hand_glow() -> void:
	var view := _view("kael")
	var fighter := FighterState.new()
	view.apply_state(fighter, FRAME)
	assert_null(view.special_glow)
