extends GutTest
## T-D25: Lyra, the star-cartographer zoner: figure, moves, clips, roster and a bot match.

const LYRA_PATH := "res://game/characters/lyra/lyra.tscn"
const DESIGN_PATH := "res://game/characters/lyra/lyra_design.tres"
const LYRA_MOVES := "res://game/combat/moves/lyra/lyra_move_set.tres"
const KAEL_MOVES := "res://game/combat/moves/kael/kael_move_set.tres"
const TOON_SHADER_PATH := "res://game/view/shaders/toon.gdshader"
const FRAME := 1.0 / 60.0
const MAX_TRIANGLES := 15000
const MAX_DRAW_CALLS := 30
const PEAK_TOLERANCE_TICKS := 2
const MATCH_TICKS := 3600

var _view: LyraView
var _fighter: FighterState


func before_each() -> void:
	_view = (load(LYRA_PATH) as PackedScene).instantiate() as LyraView
	add_child_autofree(_view)
	_fighter = FighterState.new()


func _design() -> LyraDesign:
	return load(DESIGN_PATH) as LyraDesign


func _moves() -> Array[MoveData]:
	return LyraMoveClips.moves_of(load(LYRA_MOVES) as MoveSet)


func _skeleton() -> Skeleton3D:
	return _view.skeleton()


func _reach(move: MoveData) -> float:
	var reach := 0.0
	for tick in range(move.startup_ticks, move.recovery_start_tick()):
		for shape: Dictionary in move.hitboxes_at(tick):
			reach = maxf(reach, maxf(-shape.start.z, -shape.end.z) + shape.radius)
	return reach


## A bone's head in the view's space, from the local poses the clip just set.
func _bone_in_view(bone: StringName) -> Vector3:
	var skeleton := _skeleton()
	var id := skeleton.find_bone(bone)
	var pose := skeleton.get_bone_pose(id)
	var parent := skeleton.get_bone_parent(id)
	while parent >= 0:
		pose = skeleton.get_bone_pose(parent) * pose
		parent = skeleton.get_bone_parent(parent)
	return (_view.global_transform.affine_inverse() * skeleton.global_transform) * pose.origin


func _posed_bounds() -> AABB:
	var skeleton := _skeleton()
	var to_view := _view.global_transform.affine_inverse() * skeleton.global_transform
	var bounds := AABB()
	var first := true
	for instance in (_view.model as LyraFigure).meshes:
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


func _bone_poses(view: LyraView) -> Array:
	var skeleton := view.skeleton()
	var poses := []
	for bone in skeleton.get_bone_count():
		poses.append([skeleton.get_bone_pose_position(bone), skeleton.get_bone_pose_rotation(bone),
			skeleton.get_bone_pose_scale(bone)])
	return poses


# --- Figure ---

func test_the_scene_is_a_character_view_with_the_code_built_figure() -> void:
	assert_true(_view is CharacterView)
	assert_true(_view.model is LyraFigure)
	assert_eq((_view.model as LyraFigure).assembly, FigureRig.Assembly.MERGED, "merged-mesh mode")


func test_building_twice_gives_identical_parts() -> void:
	var a := LyraFigure.parts(_design())
	var b := LyraFigure.parts(_design())
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i].bone, b[i].bone)
		assert_eq(a[i].material, b[i].material)
		assert_eq(a[i].shape.vertices, b[i].shape.vertices, "part %d vertices" % i)
		assert_eq(a[i].shape.indices, b[i].shape.indices, "part %d indices" % i)


func test_skeleton_has_every_profile_bone_plus_cape_and_astrolabe() -> void:
	var skeleton := _skeleton()
	var profile := SkeletonProfileHumanoid.new()
	for i in profile.bone_size:
		assert_ne(skeleton.find_bone(profile.get_bone_name(i)), -1, "has %s" % profile.get_bone_name(i))
	for bone: StringName in LyraFigure.CAPE_BONES + [LyraFigure.ASTROLABE_BONE]:
		assert_ne(skeleton.find_bone(bone), -1, "has %s" % bone)
	for part in LyraFigure.parts(_design()):
		assert_ne(skeleton.find_bone(part.bone), -1, "part on %s has a bone" % part.bone)


func test_merged_parts_are_rigid() -> void:
	for instance in (_view.model as LyraFigure).meshes:
		for s in instance.mesh.get_surface_count():
			var weights: PackedFloat32Array = instance.mesh.surface_get_arrays(s)[Mesh.ARRAY_WEIGHTS]
			for i in range(0, weights.size(), 4):
				if weights[i] != 1.0:
					fail_test("vertex %d of surface %d is blended" % [i / 4, s])
					return
	pass_test("every vertex follows one bone")


func test_she_is_about_two_metres_tall_hat_included_and_faces_minus_z() -> void:
	_fighter.enter_state(FighterState.State.IDLE)
	_view.apply_state(_fighter, FRAME)
	var bounds := _posed_bounds()
	assert_between(bounds.size.y, 1.85, 2.15, "about 2 m tall")
	assert_almost_eq(bounds.position.y, -1.0, 0.06, "feet 1 m below the origin")
	var skeleton := _skeleton()
	var to_view := _view.global_transform.affine_inverse() * skeleton.global_transform
	var toes := to_view * skeleton.get_bone_global_rest(skeleton.find_bone(&"LeftToes")).origin
	var foot := to_view * skeleton.get_bone_global_rest(skeleton.find_bone(&"LeftFoot")).origin
	assert_lt(toes.z, foot.z, "toes point to -Z")


func test_chunky_proportions_put_the_head_near_a_quarter_of_her_height() -> void:
	var d := _design()
	var head_top := LyraFigure.face_center(d).y + d.head_size.y * 0.5
	assert_between(head_top / d.head_size.y, 4.0, 5.0, "about 4.5 heads to the top of the head")


func test_toon_surfaces_and_one_starlight_glow() -> void:
	var glows := 0
	for instance in (_view.model as LyraFigure).meshes:
		for s in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(s)
			if material is ShaderMaterial:
				assert_eq((material as ShaderMaterial).shader.resource_path, TOON_SHADER_PATH)
				assert_not_null(material.next_pass, "has an outline pass")
			else:
				var glow := material as StandardMaterial3D
				assert_eq(glow.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)
				assert_true(glow.emission_enabled)
				glows += 1
	assert_eq(glows, 1, "the constellation starlight is the one glowing surface")


func test_render_cost_is_within_the_fighter_budget() -> void:
	var cost := FigureRig.render_cost((_view.model as LyraFigure).meshes)
	assert_lte(cost.x, MAX_TRIANGLES)
	assert_lte(cost.y, MAX_DRAW_CALLS)


func test_apply_state_handles_every_state_without_moving_the_view() -> void:
	var view_transform := _view.transform
	for state_value: int in FighterState.State.values():
		_fighter = FighterState.new()
		_fighter.enter_state(state_value)
		_fighter.stun_ticks = 30
		_fighter.velocity = Vector3(2, 0, -12)
		for _frame in 10:
			_fighter.state_ticks += 1
			_view.apply_state(_fighter, FRAME)
		assert_ne(_view.current_clip(), &"", "%s plays a clip" % FighterState.State.find_key(state_value))
	assert_eq(_view.transform, view_transform)
	var root := _skeleton().find_bone(&"Root")
	assert_eq(_skeleton().get_bone_pose(root), _skeleton().get_bone_rest(root), "no root motion")


func test_two_views_fed_the_same_states_pose_identically() -> void:
	var other := (load(LYRA_PATH) as PackedScene).instantiate() as LyraView
	add_child_autofree(other)
	for state_value: int in [FighterState.State.IDLE, FighterState.State.DASHING, FighterState.State.HITSTUN,
			FighterState.State.FLYING]:
		_fighter = FighterState.new()
		_fighter.enter_state(state_value)
		_fighter.stun_ticks = 20
		_fighter.velocity = Vector3(1, 0, -12)
		for _frame in 15:
			_fighter.state_ticks += 1
			_view.apply_state(_fighter, FRAME)
			other.apply_state(_fighter, FRAME)
	assert_eq(_bone_poses(_view), _bone_poses(other), "same input, same pose (cape springs included)")


func test_the_cape_trails_a_dash_and_settles() -> void:
	var bone := _skeleton().find_bone(LyraFigure.CAPE_BONES[0])
	_fighter.enter_state(FighterState.State.IDLE)
	for _frame in 30:
		_view.apply_state(_fighter, FRAME)
	_fighter = FighterState.new()
	_fighter.enter_state(FighterState.State.DASHING)
	_fighter.velocity = Vector3(0, 0, -25)
	for _frame in 5:
		_view.apply_state(_fighter, FRAME)
	var swing := _skeleton().get_bone_pose_rotation(bone).get_angle()
	assert_gt(swing, 0.05, "the cape flies back")
	_fighter = FighterState.new()
	_fighter.enter_state(FighterState.State.IDLE)
	for _frame in 180:
		_view.apply_state(_fighter, FRAME)
	assert_lt(_skeleton().get_bone_pose_rotation(bone).get_angle(), swing * 0.5, "and falls back")


func test_the_astrolabe_spins_as_a_pure_function_of_time() -> void:
	assert_eq(LyraView.astrolabe_pose(1.3), LyraView.astrolabe_pose(1.3))
	assert_ne(LyraView.astrolabe_pose(0.0).basis, LyraView.astrolabe_pose(0.5).basis, "it turns")
	var bone := _skeleton().find_bone(LyraFigure.ASTROLABE_BONE)
	_view.apply_state(_fighter, FRAME)
	var before := _skeleton().get_bone_pose_rotation(bone)
	for _frame in 20:
		_view.apply_state(_fighter, FRAME)
	assert_ne(_skeleton().get_bone_pose_rotation(bone), before, "and the view spins it")


func test_star_step_blinks_her_out_then_back_and_respects_vanish() -> void:
	var step := (load(LYRA_MOVES) as MoveSet).launcher
	_fighter.begin_move(step)
	var hidden := 0
	for tick in step.total_ticks():
		_fighter.move_tick = tick
		_view.apply_state(_fighter, FRAME)
		if not _view.model.visible:
			hidden += 1
	assert_eq(hidden, LyraView.BLINK_TICKS.y - LyraView.BLINK_TICKS.x, "hidden only mid-blink")
	assert_true(_view.model.visible, "visible again after")
	_view.set_vanished(true)
	_view.apply_state(_fighter, FRAME)
	assert_false(_view.model.visible, "a vanish still hides her")
	_view.set_vanished(false)
	_view.apply_state(_fighter, FRAME)
	assert_true(_view.model.visible)


# --- Moves ---

func test_every_move_follows_the_move_data_conventions() -> void:
	for move in _moves():
		assert_gt(move.startup_ticks, 0, "%s startup" % move.id)
		assert_gt(move.active_ticks, 0, "%s active" % move.id)
		assert_gt(move.recovery_ticks, 0, "%s recovery" % move.id)
		assert_eq(move.hitbox_radii.size(), move.hitbox_offsets.size(), "%s radius per offset" % move.id)
		if not move.hitbox_lengths.is_empty():
			assert_eq(move.hitbox_axes.size(), move.hitbox_lengths.size(), "%s axis per capsule" % move.id)
		assert_lte(move.cancel_end_tick, move.total_ticks(), "%s cancel window inside the move" % move.id)
		if move.kind == MoveData.Kind.STRIKE:
			assert_gt(move.damage, 0, "%s deals damage" % move.id)
			assert_gt(move.hitstun_ticks, move.blockstun_ticks, "%s: hit stuns longer than block" % move.id)
			assert_eq(move.cancel_start_tick, move.startup_ticks, "%s cancels from its first active tick" % move.id)


func test_she_zones_far_but_is_weaker_up_close_than_kael() -> void:
	var lyra := load(LYRA_MOVES) as MoveSet
	var kael := load(KAEL_MOVES) as MoveSet
	assert_lt(lyra.light_string.size(), kael.light_string.size(), "a shorter light string")
	var total := func(string: Array[MoveData]) -> int:
		return string.reduce(func(sum: int, move: MoveData) -> int: return sum + move.damage, 0)
	assert_lt(float(total.call(lyra.light_string)), total.call(kael.light_string) * 0.7, "her string deals far less")
	assert_lt(lyra.light_string[-1].damage, kael.light_string[-1].damage, "a lighter finisher")
	assert_lt(lyra.light_string[0].damage, kael.light_string[0].damage, "a lighter jab")
	assert_gte(lyra.light_string[0].startup_ticks, kael.light_string[0].startup_ticks, "no faster jab")
	assert_lt(lyra.grab.damage, kael.grab.damage, "a weaker throw")
	assert_gt(_reach(lyra.smash), 2.0 * _reach(kael.smash), "her smash reaches twice as far")
	var previous := _reach(lyra.smash)
	for move in lyra.charged_smash:
		assert_gt(_reach(move), previous, "%s reaches further than the level before" % move.id)
		previous = _reach(move)
	assert_gte(lyra.charged_smash[2].startup_ticks, 24, "the full beam has a beam's tell (§5.8)")


func test_star_step_teleports_back_invincible_and_bursts_where_she_stood() -> void:
	var step := (load(LYRA_MOVES) as MoveSet).launcher
	assert_lte(step.step_distance, -4.0, "steps at least 4 m back")
	assert_eq(step.invincible_start_tick, 0)
	assert_gte(step.invincible_end_tick, step.startup_ticks, "invincible through the whole step")
	assert_eq(step.knockback_type, MoveData.KnockbackType.LAUNCH)
	var burst: Dictionary = step.hitboxes_at(step.startup_ticks)[0]
	assert_lt(minf(burst.start.z, burst.end.z), step.step_distance, "the burst covers her old spot")


func test_star_trap_lingers_to_deny_space() -> void:
	var trap := (load(LYRA_MOVES) as MoveSet).sweep
	assert_gte(trap.active_ticks, 24, "stays out for 24+ ticks")
	var first: Dictionary = trap.hitboxes_at(trap.startup_ticks)[0]
	var last: Dictionary = trap.hitboxes_at(trap.recovery_start_tick() - 1)[0]
	assert_lt(first.start.z, -1.5, "placed ahead of her, not on her")
	assert_lt(last.start.z, first.start.z, "and blooms outward")
	assert_lt(first.start.y, 0.0, "low, on the ground")


func test_the_sim_runs_her_star_step_and_moves_her_back() -> void:
	var sim := CombatSim.new(5)
	sim.add_fighter(Vector3(0, 1, 2), Roster.character(&"kael").stats)
	var lyra := sim.add_fighter(Vector3(0, 1, -0.5), Roster.character(&"lyra").stats)
	sim.lock_everyone_onto_nearest()
	var idle := FighterInput.new()
	var press := FighterInput.new()
	press.pressed_actions = FighterInput.Action.HEAVY
	press.held_actions = FighterInput.Action.HEAVY
	press.move = Vector2(0, -1)
	var start := lyra.position
	var distance_before := start.distance_to(sim.fighters[0].position)
	var release := FighterInput.new()
	release.released_actions = FighterInput.Action.HEAVY
	release.move = Vector2(0, -1)
	var used := false
	for tick in 40:
		var mine := press if tick == 0 else (release if tick == 1 else idle)
		sim.tick([idle, mine] as Array[FighterInput])
		if lyra.move and lyra.move.id == &"launcher":
			used = true
	assert_true(used, "away + heavy performs Star-Step")
	assert_gt(lyra.position.distance_to(sim.fighters[0].position), distance_before + 3.0, "she ends far away")


# --- Clips ---

func test_each_move_has_its_own_clip_lasting_exactly_its_ticks() -> void:
	for move in _moves():
		var clip := _view.clips.clip_for_move(move.id)
		assert_eq(clip, StringName(LyraMoveClips.CLIP_PREFIX + move.id), "%s plays her clip" % move.id)
		assert_almost_eq(_view.clips.library.get_animation(clip).length, move.total_ticks() / 60.0, 0.001,
			"%s clip lasts the move" % move.id)


func test_each_strike_peaks_inside_its_active_ticks() -> void:
	for move in _moves():
		var bone := LyraMoveClips.strike_bone(move.id)
		var sum := Vector3.ZERO
		for tick in move.active_ticks:
			sum += move.hitbox_offsets[mini(tick, move.hitbox_offsets.size() - 1)]
		var target := sum / move.active_ticks
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
			"%s peaks on tick %d (active %d-%d)" % [move.id, best_tick, move.startup_ticks, move.recovery_start_tick() - 1])
		assert_lt(best, start_distance - 0.15, "%s visibly reaches toward its hitbox" % move.id)


func test_clips_start_and_end_in_guard_with_the_hips_in_place() -> void:
	var hips_path := NodePath("%GeneralSkeleton:Hips")
	for move in _moves():
		var animation := _view.clips.library.get_animation(_view.clips.clip_for_move(move.id))
		var track := animation.find_track(hips_path, Animation.TYPE_POSITION_3D)
		var first: Vector3 = animation.track_get_key_value(track, 0)
		var last: Vector3 = animation.track_get_key_value(track, animation.track_get_key_count(track) - 1)
		assert_almost_eq(last, first, Vector3.ONE * 0.001, "%s returns to guard" % move.id)


func test_the_same_move_set_bakes_the_same_clips() -> void:
	var moves := load(LYRA_MOVES) as MoveSet
	var poser := FigurePoser.new(_skeleton())
	var a := LyraMoveClips.bake(poser, moves.sweep)
	var b := LyraMoveClips.bake(poser, moves.sweep)
	for track in a.get_track_count():
		for key in a.track_get_key_count(track):
			assert_eq(a.track_get_key_value(track, key), b.track_get_key_value(track, key))


# --- Roster and match ---

func test_the_roster_lists_lyra_with_her_stats_and_palettes() -> void:
	assert_true(Roster.ids().has(&"lyra"), "Lyra is on the roster")
	var lyra := Roster.character(&"lyra")
	assert_eq(lyra.display_name, "Lyra")
	assert_eq(lyra.stats.move_set, load(LYRA_MOVES))
	assert_eq(lyra.stats.guard_max, 80, "low guard (§6)")
	var kael := Roster.character(&"kael")
	assert_lt(lyra.stats.max_health, kael.stats.max_health, "lighter than Kael")
	assert_lt(lyra.stats.hurtbox_radius, kael.stats.hurtbox_radius, "a slimmer target")
	assert_eq(lyra.palette_for(0), {}, "P1 wears her own colours")
	assert_true(lyra.palette_for(1).has("navy"), "P2 recolours the robe")
	assert_ne(lyra.palette_for(2), lyra.palette_for(1), "an alt palette too")


func test_a_fighter_view_draws_lyra_in_her_slot_palette() -> void:
	var view := FighterView.new()
	view.character_id = &"lyra"
	view.slot = 1
	view.fighter = FighterState.new()
	add_child_autofree(view)
	assert_eq(view.find_children("*", "LyraView", true, false).size(), 1)
	assert_eq(view.palette, Roster.character(&"lyra").palette_for(1))


func test_a_3600_tick_bot_match_with_lyra_runs_clean_and_uses_her_kit() -> void:
	var sim := CombatSim.new(25)
	sim.add_fighter(Vector3(0, 1, 6), Roster.character(&"kael").stats)
	sim.add_fighter(Vector3(0, 1, -6), Roster.character(&"lyra").stats)
	sim.lock_everyone_onto_nearest()
	var bots := [WeaponBot.new(0, 101), WeaponBot.new(1, 202)]
	var lyra_moves := {}
	for move in _moves():
		lyra_moves[move.id] = true
	var used := {}
	var hits := 0
	for tick in MATCH_TICKS:
		var inputs: Array[FighterInput] = [bots[0].next_input(sim), bots[1].next_input(sim)]
		sim.tick(inputs)
		var lyra := sim.fighters[1]
		if lyra.move and lyra_moves.has(lyra.move.id):
			used[lyra.move.id] = true
		_view.apply_state(lyra, FRAME)
		for event in sim.events:
			if event.type == CombatSim.EventType.HIT and event.get("attacker", -1) == 1:
				hits += 1
		for fighter in sim.fighters:
			if not fighter.position.is_finite() or fighter.health < 0:
				fail_test("tick %d: bad fighter state %s / %d" % [tick, fighter.position, fighter.health])
				return
		if sim.round_over:
			sim.start_round()
	gut.p("lyra moves used: %s, her hits: %d" % [used.keys(), hits])
	assert_gte(used.size(), 3, "she used several of her moves")
	assert_eq(sim.state_hash(), _replay_hash(25), "the match replays to the same hash")


func _replay_hash(seed_value: int) -> int:
	var sim := CombatSim.new(seed_value)
	sim.add_fighter(Vector3(0, 1, 6), Roster.character(&"kael").stats)
	sim.add_fighter(Vector3(0, 1, -6), Roster.character(&"lyra").stats)
	sim.lock_everyone_onto_nearest()
	var bots := [WeaponBot.new(0, 101), WeaponBot.new(1, 202)]
	for tick in MATCH_TICKS:
		var inputs: Array[FighterInput] = [bots[0].next_input(sim), bots[1].next_input(sim)]
		sim.tick(inputs)
		if sim.round_over:
			sim.start_round()
	return sim.state_hash()
