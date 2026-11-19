extends GutTest
## T-D24: Brann, the stone smith: his code-built figure, posed move clips,
## heavy move set and roster entry.

const BRANN_PATH := "res://game/characters/brann/brann.tscn"
const DESIGN_PATH := "res://game/characters/brann/brann_design.tres"
const BRANN_MOVES := "res://game/combat/moves/brann/brann_move_set.tres"
const KAEL_MOVES := "res://game/combat/moves/kael/kael_move_set.tres"
const KAEL_STATS := "res://game/combat/default_fighter_stats.tres"
const FRAME := 1.0 / 60.0
const MAX_TRIANGLES := 15000
const MAX_DRAW_CALLS := 30
const PEAK_TOLERANCE_TICKS := 2

var _view: BrannView
var _fighter: FighterState


func before_each() -> void:
	_view = (load(BRANN_PATH) as PackedScene).instantiate() as BrannView
	add_child_autofree(_view)
	_fighter = FighterState.new()


func _design() -> BrannDesign:
	return load(DESIGN_PATH) as BrannDesign


func _skeleton() -> Skeleton3D:
	return _view.model.get_node("%GeneralSkeleton") as Skeleton3D


func _moves() -> Array[MoveData]:
	return BrannMoveClips.moves_of(load(BRANN_MOVES) as MoveSet)


func _bone_in_view(bone: StringName) -> Vector3:
	var skeleton := _skeleton()
	var id := skeleton.find_bone(bone)
	var pose := skeleton.get_bone_pose(id)
	var parent := skeleton.get_bone_parent(id)
	while parent >= 0:
		pose = skeleton.get_bone_pose(parent) * pose
		parent = skeleton.get_bone_parent(parent)
	return (_view.global_transform.affine_inverse() * skeleton.global_transform) * pose.origin


func _mean_active_hitbox(move: MoveData) -> Vector3:
	var sum := Vector3.ZERO
	for tick in move.active_ticks:
		sum += move.hitbox_offsets[mini(tick, move.hitbox_offsets.size() - 1)]
	return sum / move.active_ticks


func _posed_bounds() -> AABB:
	var skeleton := _skeleton()
	var to_view := _view.global_transform.affine_inverse() * skeleton.global_transform
	var bounds := AABB()
	var first := true
	for instance in (_view.model as BrannFigure).meshes:
		for s in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			for i in vertices.size():
				var bone := bones[i * 4]
				var point := to_view * (skeleton.get_bone_global_pose(bone)
					* skeleton.get_bone_global_rest(bone).affine_inverse() * vertices[i])
				if first:
					bounds = AABB(point, Vector3.ZERO)
					first = false
				else:
					bounds = bounds.expand(point)
	return bounds


func test_the_scene_loads_as_a_character_view_with_the_code_built_figure() -> void:
	assert_true(_view is CharacterView)
	assert_true(_view.model is BrannFigure)
	assert_eq((_view.model as BrannFigure).meshes.size(), 1, "merged into one skinned mesh")


func test_the_figure_builds_the_same_every_time() -> void:
	var a := BrannFigure.parts(_design())
	var b := BrannFigure.parts(_design())
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i].bone, b[i].bone)
		assert_eq(a[i].material, b[i].material)
		assert_eq(a[i].shape.vertices, b[i].shape.vertices, "part %d vertices" % i)
		assert_eq(a[i].shape.indices, b[i].shape.indices, "part %d indices" % i)


func test_skeleton_has_every_profile_bone_and_the_spring_bones() -> void:
	var skeleton := _skeleton()
	var profile := SkeletonProfileHumanoid.new()
	for i in profile.bone_size:
		assert_ne(skeleton.find_bone(profile.get_bone_name(i)), -1, "has %s" % profile.get_bone_name(i))
	for bone in BrannFigure.SPRING_BONES:
		assert_ne(skeleton.find_bone(bone), -1, "has spring bone %s" % bone)
	for part in BrannFigure.parts(_design()):
		assert_ne(skeleton.find_bone(part.bone), -1, "part on %s has a bone" % part.bone)


func test_he_is_about_two_metres_tall_feet_one_metre_below_the_origin_and_broad() -> void:
	_fighter.enter_state(FighterState.State.IDLE)
	_view.apply_state(_fighter, FRAME)
	var bounds := _posed_bounds()
	assert_between(bounds.size.y, 1.85, 2.15, "about 2 m tall")
	assert_almost_eq(bounds.position.y, -1.0, 0.06, "feet 1 m below the origin")
	assert_almost_eq(bounds.get_center().x, 0.0, 0.15, "centred on the capsule")
	assert_gt(bounds.size.x, 1.2, "a hulking, broad silhouette")


func test_render_cost_is_within_the_fighter_budget_and_glows_are_unshaded() -> void:
	var meshes := (_view.model as BrannFigure).meshes
	var cost := FigureRig.render_cost(meshes)
	assert_lte(cost.x, MAX_TRIANGLES)
	assert_lte(cost.y, MAX_DRAW_CALLS)
	var glows := 0
	for s in meshes[0].mesh.get_surface_count():
		var material := meshes[0].mesh.surface_get_material(s)
		if material is StandardMaterial3D:
			assert_eq((material as StandardMaterial3D).shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
			glows += 1
		else:
			assert_not_null(material.next_pass, "toon surfaces have an outline")
	assert_eq(glows, 2, "ember cracks and eyes glow")


func test_every_brann_move_follows_the_move_data_conventions() -> void:
	for move in _moves():
		assert_gt(move.startup_ticks, 0, "%s startup" % move.id)
		assert_gt(move.active_ticks, 0, "%s active" % move.id)
		assert_gt(move.recovery_ticks, 0, "%s recovery" % move.id)
		assert_eq(move.hitbox_radii.size(), move.hitbox_offsets.size(), "%s radius per offset" % move.id)
		if not move.hitbox_lengths.is_empty():
			assert_eq(move.hitbox_axes.size(), move.hitbox_lengths.size(), "%s axis per capsule" % move.id)
		assert_lte(move.cancel_end_tick, move.total_ticks(), "%s cancel window inside the move" % move.id)
		assert_lte(move.armor_end_tick, move.recovery_start_tick(), "%s armour ends by recovery" % move.id)
		if move.kind == MoveData.Kind.STRIKE:
			assert_gt(move.damage, 0, "%s deals damage" % move.id)
			assert_gt(move.hitstun_ticks, move.blockstun_ticks, "%s: hit stuns longer than block" % move.id)
			assert_eq(move.cancel_start_tick, move.startup_ticks, "%s cancels from its first active tick" % move.id)


func test_brann_is_slower_harder_hitting_and_tougher_than_kael() -> void:
	var brann := load(BRANN_MOVES) as MoveSet
	var kael := load(KAEL_MOVES) as MoveSet
	assert_lt(brann.light_string.size(), kael.light_string.size(), "a shorter, heavier string")
	assert_gt(brann.light_string[0].startup_ticks, kael.light_string[0].startup_ticks, "slower jab")
	for name in ["smash", "breaker", "launcher", "spike", "sweep", "grab"]:
		var his: MoveData = brann.get(name)
		var theirs: MoveData = kael.get(name)
		assert_gte(his.startup_ticks, theirs.startup_ticks, "%s starts no faster" % name)
		assert_gt(his.damage, theirs.damage, "%s hits harder" % name)
	for i in kael.charged_smash.size():
		assert_gt(brann.charged_smash[i].damage, kael.charged_smash[i].damage, "charged %d harder" % (i + 1))
	var stats := Roster.character(&"brann").stats
	var kael_stats := load(KAEL_STATS) as FighterStats
	assert_gt(stats.max_health, kael_stats.max_health, "more health")
	assert_gt(stats.hurtbox_radius, kael_stats.hurtbox_radius, "a big hurtbox")
	assert_eq(stats.vanish_counter_ki_cost, 35, "vanishes cost 35 ki")
	assert_eq(stats.second_vanish_counter_ki_cost, 55, "and 55 for the second")


func test_heavies_are_armoured_and_the_charged_smash_is_unstoppable() -> void:
	var brann := load(BRANN_MOVES) as MoveSet
	for move: MoveData in [brann.smash, brann.breaker, brann.spike]:
		assert_gt(move.armor_end_tick, move.armor_start_tick, "%s has armour" % move.id)
	var top: MoveData = brann.charged_smash[2]
	assert_eq(top.armor_start_tick, 0, "level 3 is armoured from its first tick")
	assert_eq(top.armor_end_tick, top.recovery_start_tick(), "through its last active tick")
	assert_eq(top.knockback_type, MoveData.KnockbackType.WALL_SPLAT)
	assert_true(brann.smash.can_charge())


func test_ground_pound_and_quake_stomp_are_low_widening_shockwaves() -> void:
	var brann := load(BRANN_MOVES) as MoveSet
	for move: MoveData in [brann.spike, brann.sweep]:
		var first: Dictionary = move.hitboxes_at(move.startup_ticks)[0]
		var last: Dictionary = move.hitboxes_at(move.recovery_start_tick() - 1)[0]
		assert_lt(first.start.y, -0.5, "%s hits low, at the floor" % move.id)
		assert_gt(last.radius + last.start.distance_to(last.end), first.radius + first.start.distance_to(first.end),
			"%s widens as it spreads" % move.id)
	assert_eq(brann.spike.knockback_type, MoveData.KnockbackType.SPIKE)
	assert_eq(brann.launcher.knockback_type, MoveData.KnockbackType.LAUNCH)


func test_the_view_maps_each_move_to_its_own_clip_lasting_exactly_the_move() -> void:
	for move in _moves():
		var clip := _view.clips.clip_for_move(move.id)
		assert_eq(clip, StringName(BrannMoveClips.CLIP_PREFIX + move.id), "%s plays his clip" % move.id)
		assert_almost_eq(_view.clips.library.get_animation(clip).length, move.total_ticks() / 60.0, 0.001,
			"%s clip lasts the move" % move.id)


func test_each_strike_peaks_inside_its_active_ticks() -> void:
	for move in _moves():
		var bone := BrannMoveClips.strike_bone(move.id)
		var target := _mean_active_hitbox(move)
		_fighter = FighterState.new()
		_fighter.begin_move(move)
		var best_tick := -1
		var best := INF
		var start_distance := 0.0
		for tick in move.total_ticks():
			_fighter.move_tick = tick
			_view.apply_state(_fighter, 0.0)
			var distance := _bone_in_view(bone).distance_to(target)
			if tick == 0:
				start_distance = distance
			if distance < best:
				best = distance
				best_tick = tick
		assert_between(best_tick, move.startup_ticks - PEAK_TOLERANCE_TICKS,
			move.recovery_start_tick() - 1 + PEAK_TOLERANCE_TICKS,
			"%s: %s is closest to the hitbox on tick %d (active %d-%d)" % [move.id, bone, best_tick,
			move.startup_ticks, move.recovery_start_tick() - 1])
		assert_lt(best, start_distance - 0.15, "%s visibly reaches toward its hitbox" % move.id)


func test_the_same_move_set_bakes_the_same_clips() -> void:
	var moves := load(BRANN_MOVES) as MoveSet
	var poser := FigurePoser.new(_skeleton())
	var a := BrannMoveClips.bake(poser, moves.spike)
	var b := BrannMoveClips.bake(poser, moves.spike)
	for track in a.get_track_count():
		for key in a.track_get_key_count(track):
			assert_eq(a.track_get_key_value(track, key), b.track_get_key_value(track, key))


func test_apply_state_handles_every_state_without_moving_the_view() -> void:
	var view_transform := _view.transform
	var root := _skeleton().find_bone(&"Root")
	for state_value: int in FighterState.State.values():
		_fighter = FighterState.new()
		_fighter.enter_state(state_value)
		_fighter.stun_ticks = 30
		_fighter.velocity = Vector3(2, 0, -12)
		for _frame in 10:
			_fighter.state_ticks += 1
			_view.apply_state(_fighter, FRAME)
		assert_ne(_view.current_clip(), &"", "%s plays a clip" % FighterState.State.find_key(state_value))
	assert_eq(_view.transform, view_transform, "the view never moves itself")
	assert_eq(_skeleton().get_bone_pose(root), _skeleton().get_bone_rest(root), "no root motion")


func test_the_procedural_layer_and_ember_glow_are_pure() -> void:
	for state_value: int in FighterState.State.values():
		_fighter = FighterState.new()
		_fighter.enter_state(state_value)
		_fighter.state_ticks = 3
		_fighter.velocity = Vector3(2, 0, -9)
		for time: float in [0.0, 0.41, 2.7]:
			assert_eq(BrannView.procedural_layer(_fighter, time), BrannView.procedural_layer(_fighter, time))
			assert_eq(BrannView.ember_energy(_fighter, time), BrannView.ember_energy(_fighter, time))


func test_cracks_flare_while_charging_and_on_his_own_material() -> void:
	var idle := FighterState.new()
	idle.enter_state(FighterState.State.IDLE)
	var charging := FighterState.new()
	charging.enter_state(FighterState.State.CHARGING)
	charging.charge_ticks = BrannView.EMBER_CHARGE_TICKS
	assert_gt(BrannView.ember_energy(charging, 0.0), BrannView.ember_energy(idle, 0.0) + 2.0)
	var other := (load(BRANN_PATH) as PackedScene).instantiate() as BrannView
	add_child_autofree(other)
	assert_ne(_view.ember_material(), other.ember_material(), "each Brann flares on its own")
	_view.apply_state(charging, FRAME)
	assert_almost_eq(_view.ember_material().emission_energy_multiplier,
		BrannView.ember_energy(charging, FRAME), 1e-4)


func test_two_views_fed_the_same_states_pose_identically() -> void:
	var other := (load(BRANN_PATH) as PackedScene).instantiate() as BrannView
	add_child_autofree(other)
	for state_value: int in [FighterState.State.IDLE, FighterState.State.MOVING, FighterState.State.HITSTUN,
			FighterState.State.FLYING]:
		_fighter = FighterState.new()
		_fighter.enter_state(state_value)
		_fighter.stun_ticks = 20
		_fighter.velocity = Vector3(1, 0, -12)
		for _frame in 15:
			_fighter.state_ticks += 1
			_view.apply_state(_fighter, FRAME)
			other.apply_state(_fighter, FRAME)
	for bone in _skeleton().get_bone_count():
		assert_eq(_view.skeleton().get_bone_pose(bone), other.skeleton().get_bone_pose(bone))


func test_beard_braid_swings_behind_a_dash_and_settles() -> void:
	var skeleton := _skeleton()
	var braid := skeleton.find_bone(BrannFigure.BRAID_BONE)
	_fighter.enter_state(FighterState.State.IDLE)
	for _frame in 30:
		_view.apply_state(_fighter, FRAME)
	_fighter = FighterState.new()
	_fighter.enter_state(FighterState.State.DASHING)
	_fighter.velocity = Vector3(0, 0, -25)
	for _frame in 5:
		_view.apply_state(_fighter, FRAME)
	var swing := skeleton.get_bone_pose_rotation(braid).get_angle()
	assert_gt(swing, 0.05, "the braid trails the dash")
	_fighter = FighterState.new()
	_fighter.enter_state(FighterState.State.IDLE)
	for _frame in 240:
		_view.apply_state(_fighter, FRAME)
	assert_lt(skeleton.get_bone_pose_rotation(braid).get_angle(), swing * 0.5, "and swings back")


func test_signature_weapons_are_stowed_until_he_picks_one_up() -> void:
	var stowed := _view.stowed_weapons()
	assert_eq(stowed.size(), 2, "Titan Hammer and Scatter Cannon")
	_fighter.enter_state(FighterState.State.IDLE)
	_view.apply_state(_fighter, FRAME)
	for node in stowed:
		assert_true(node.visible, "%s shows at idle" % node.name)
	_fighter.weapons[0] = Weapon.Kind.TITAN_HAMMER
	_fighter.active_slot = 0
	_view.apply_state(_fighter, FRAME)
	for node in stowed:
		assert_false(node.visible, "%s hides while a weapon is in hand" % node.name)


func test_palettes_recolour_his_parts_for_p2() -> void:
	var brann := Roster.character(&"brann")
	assert_eq(brann.palette_for(0), {}, "P1 wears his own colours")
	var p2 := brann.palette_for(1)
	for part in ["stone", "beard", "moss", "leather", "cloth"]:
		assert_true(p2.has(part), "P2 recolours %s" % part)
	FighterPalette.apply(_view, p2)
	var instance := (_view.model as BrannFigure).meshes[0]
	for s in instance.mesh.get_surface_count():
		if instance.mesh.surface_get_name(s) == "stone":
			var material := instance.get_active_material(s) as ShaderMaterial
			assert_eq(material.get_shader_parameter(&"albedo_color"), p2["stone"])


func test_the_roster_lists_brann_and_the_sim_runs_his_moves() -> void:
	assert_has(Roster.ids(), &"brann")
	var brann := Roster.character(&"brann")
	assert_eq(brann.display_name, "Brann")
	assert_eq(brann.scene.resource_path, BRANN_PATH)
	var sim := CombatSim.new(5)
	sim.add_fighter(Vector3(0, 1, 2), Roster.character(&"kael").stats)
	var fighter := sim.add_fighter(Vector3(0, 1, -2), brann.stats)
	sim.lock_everyone_onto_nearest()
	var press := FighterInput.new()
	press.pressed_actions = FighterInput.Action.LIGHT
	press.held_actions = FighterInput.Action.LIGHT
	var inputs: Array[FighterInput] = [FighterInput.new(), press]
	sim.tick(inputs)
	assert_eq(fighter.move, brann.stats.move_set.light_string[0], "his own jab")
	assert_eq(fighter.stats.max_health, brann.stats.max_health)


## A seeded 3600-tick bot match, Brann against Kael; returns its state hash.
func _bot_match(seed_value: int) -> Array:
	var sim := CombatSim.new(seed_value)
	sim.add_fighter(Vector3(0, 1, 6), Roster.character(&"brann").stats)
	sim.add_fighter(Vector3(0, 1, -6), Roster.character(&"kael").stats)
	sim.lock_everyone_onto_nearest()
	var bots: Array[WeaponBot] = [WeaponBot.new(0, seed_value * 3 + 1), WeaponBot.new(1, seed_value * 3 + 2)]
	var brann_moves := {}
	var hits := 0
	for _tick in 3600:
		var inputs: Array[FighterInput] = []
		for bot in bots:
			inputs.append(bot.next_input(sim))
		sim.tick(inputs)
		if sim.fighters[0].move:
			brann_moves[sim.fighters[0].move.id] = true
		for event in sim.events:
			if event.type == CombatSim.EventType.HIT:
				hits += 1
		if sim.round_over:
			sim.start_round()
	return [sim.state_hash(), brann_moves, hits]


func test_a_3600_tick_bot_match_with_brann_runs_clean_and_repeats() -> void:
	var first := _bot_match(24)
	var second := _bot_match(24)
	assert_eq(first[0], second[0], "same seed, same match")
	assert_gt((first[1] as Dictionary).size(), 1, "Brann used several of his moves")
	assert_gt(first[2], 0, "hits landed")
