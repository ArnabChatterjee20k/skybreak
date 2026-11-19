extends GutTest
## T-D18b: Vexa's own move set and the posed clips that animate it.

const VEXA_PATH := "res://game/characters/vexa/vexa.tscn"
const VEXA_MOVES := "res://game/combat/moves/vexa/vexa_move_set.tres"
const KAEL_MOVES := "res://game/combat/moves/kael/kael_move_set.tres"
const PEAK_TOLERANCE_TICKS := 2

var _view: VexaView
var _fighter: FighterState


func before_each() -> void:
	_view = (load(VEXA_PATH) as PackedScene).instantiate() as VexaView
	add_child_autofree(_view)
	_fighter = FighterState.new()


func _moves() -> Array[MoveData]:
	return VexaMoveClips.moves_of(load(VEXA_MOVES) as MoveSet)


func _skeleton() -> Skeleton3D:
	return _view.model.get_node("%GeneralSkeleton") as Skeleton3D


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


func _mean_active_hitbox(move: MoveData) -> Vector3:
	var sum := Vector3.ZERO
	for tick in move.active_ticks:
		sum += move.hitbox_offsets[mini(tick, move.hitbox_offsets.size() - 1)]
	return sum / move.active_ticks


func test_every_vexa_move_follows_the_move_data_conventions() -> void:
	for move in _moves():
		assert_ne(move.id, &"", "has an id")
		assert_gt(move.startup_ticks, 0, "%s startup" % move.id)
		assert_gt(move.active_ticks, 0, "%s active" % move.id)
		assert_gt(move.recovery_ticks, 0, "%s recovery" % move.id)
		assert_false(move.hitbox_offsets.is_empty(), "%s has a hitbox" % move.id)
		assert_eq(move.hitbox_radii.size(), move.hitbox_offsets.size(), "%s radius per offset" % move.id)
		if not move.hitbox_lengths.is_empty():
			assert_eq(move.hitbox_axes.size(), move.hitbox_lengths.size(), "%s axis per capsule" % move.id)
		assert_lte(move.cancel_end_tick, move.total_ticks(), "%s cancel window inside the move" % move.id)
		if move.kind == MoveData.Kind.STRIKE:
			assert_gt(move.damage, 0, "%s deals damage" % move.id)
			assert_gt(move.hitstun_ticks, move.blockstun_ticks, "%s: hit stuns longer than block" % move.id)
			assert_eq(move.cancel_start_tick, move.startup_ticks, "%s cancels from its first active tick" % move.id)


func test_vexa_is_lighter_faster_and_strings_longer_than_kael() -> void:
	var vexa := load(VEXA_MOVES) as MoveSet
	var kael := load(KAEL_MOVES) as MoveSet
	assert_gt(vexa.light_string.size(), kael.light_string.size(), "a longer light string")
	assert_lt(vexa.light_string[0].startup_ticks, kael.light_string[0].startup_ticks, "faster jab")
	for name in ["smash", "breaker", "launcher", "rising", "spike", "sweep", "grab"]:
		var her: MoveData = vexa.get(name)
		var his: MoveData = kael.get(name)
		assert_lt(her.startup_ticks, his.startup_ticks, "%s starts faster" % name)
		assert_lt(her.damage, his.damage, "%s hits lighter" % name)
	for i in kael.charged_smash.size():
		assert_lt(vexa.charged_smash[i].damage, kael.charged_smash[i].damage, "charged %d lighter" % (i + 1))


func test_her_launcher_spike_and_chakram_do_their_jobs() -> void:
	var vexa := load(VEXA_MOVES) as MoveSet
	assert_eq(vexa.launcher.knockback_type, MoveData.KnockbackType.LAUNCH)
	assert_eq(vexa.spike.knockback_type, MoveData.KnockbackType.SPIKE)
	assert_lt(vexa.spike.knockback.y, 0.0, "the spike drives down")
	for move in vexa.charged_smash:
		var far := move.hitboxes_at(move.startup_ticks)[0]
		assert_lt(minf(far.start.z, far.end.z), -2.0, "%s reaches past 2 m like a thrown chakram" % move.id)
	assert_true(vexa.smash.can_charge(), "the smash charges into the chakram")


func test_the_view_maps_each_move_to_its_own_posed_clip() -> void:
	for move in _moves():
		var clip := _view.clips.clip_for_move(move.id)
		assert_eq(clip, StringName(VexaMoveClips.CLIP_PREFIX + move.id), "%s plays her clip" % move.id)
		assert_true(_view.clips.library.has_animation(clip))


func test_attack_clips_last_exactly_the_move() -> void:
	for move in _moves():
		var clip := _view.clips.clip_for_move(move.id)
		assert_almost_eq(_view.clips.library.get_animation(clip).length, move.total_ticks() / 60.0, 0.001,
			"%s clip lasts the move" % move.id)


func test_each_strike_peaks_inside_its_active_ticks() -> void:
	for move in _moves():
		var bone := VexaMoveClips.strike_bone(move.id)
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


func test_clips_have_no_root_motion_and_start_and_end_in_guard() -> void:
	var hips_path := NodePath("%GeneralSkeleton:Hips")
	for move in _moves():
		var animation := _view.clips.library.get_animation(_view.clips.clip_for_move(move.id))
		assert_eq(animation.find_track(NodePath("%GeneralSkeleton:Root"), Animation.TYPE_ROTATION_3D), -1)
		var track := animation.find_track(hips_path, Animation.TYPE_POSITION_3D)
		var first: Vector3 = animation.track_get_key_value(track, 0)
		var last: Vector3 = animation.track_get_key_value(track, animation.track_get_key_count(track) - 1)
		assert_almost_eq(last, first, Vector3.ONE * 0.001, "%s returns to guard" % move.id)
		for key in animation.track_get_key_count(track):
			var value: Vector3 = animation.track_get_key_value(track, key)
			assert_almost_eq(Vector2(value.x, value.z), Vector2(first.x, first.z), Vector2(0.001, 0.001),
				"%s hips stay put horizontally" % move.id)


func test_feet_stay_planted_through_punches() -> void:
	var poser := FigurePoser.new(_skeleton())
	var move: MoveData = (load(VEXA_MOVES) as MoveSet).smash
	var style: Dictionary = VexaMoveClips.STYLES[move.id]
	var pose := VexaMoveClips._pose(style, VexaMoveClips.strike_point(move), 0.5, 0.2, 0.1)
	var at := poser.positions(pose)
	for foot: StringName in [&"LeftFoot", &"RightFoot"]:
		assert_almost_eq(at[foot], VexaMoveClips.GUARD_TARGETS[foot], Vector3.ONE * 0.01, "%s stays on its mark" % foot)


func test_the_same_move_set_bakes_the_same_clips() -> void:
	var moves := load(VEXA_MOVES) as MoveSet
	var poser := FigurePoser.new(_skeleton())
	var a := VexaMoveClips.bake(poser, moves.smash)
	var b := VexaMoveClips.bake(poser, moves.smash)
	for track in a.get_track_count():
		for key in a.track_get_key_count(track):
			assert_eq(a.track_get_key_value(track, key), b.track_get_key_value(track, key))
