extends GutTest
## T-D22c: motion pass 2. Fitted mocap strikes, motion profiles, get-up, turn steps, jab
## anticipation, flight, the pop guard and the single lean source.

const SCENES := {
	&"kael": "res://game/characters/kael_chunky/kael_chunky.tscn",
	&"vexa": "res://game/characters/vexa/vexa.tscn",
	&"lyra": "res://game/characters/lyra/lyra.tscn",
	&"brann": "res://game/characters/brann/brann.tscn",
}
const MOVE_SETS := {
	&"kael": "res://game/combat/moves/kael/kael_move_set.tres",
	&"vexa": "res://game/combat/moves/vexa/vexa_move_set.tres",
	&"lyra": "res://game/combat/moves/lyra/lyra_move_set.tres",
	&"brann": "res://game/combat/moves/brann/brann_move_set.tres",
}
const VEXA_FITTED: Array[StringName] = [&"breaker", &"launcher", &"light_5", &"push_block", &"rising", &"grab"]
const DT := 1.0 / 60.0


func _view(who: StringName) -> CharacterView:
	var view := (load(SCENES[who]) as PackedScene).instantiate() as CharacterView
	add_child_autofree(view)
	return view


func _moves(who: StringName) -> Array[MoveData]:
	return VexaMoveClips.moves_of(load(MOVE_SETS[who]) as MoveSet)


func _move(who: StringName, id: StringName) -> MoveData:
	for move in _moves(who):
		if move.id == id:
			return move
	return null


func _skeleton(view: CharacterView) -> Skeleton3D:
	return view.model.get_node("%GeneralSkeleton") as Skeleton3D


func _step(view: CharacterView, fighter: FighterState, frames: int) -> void:
	for _i in frames:
		view.apply_state(fighter, DT)
		view.layers._process_modification_with_delta(DT)


func _global(view: CharacterView, bone: StringName) -> Vector3:
	var skeleton := _skeleton(view)
	var id := skeleton.find_bone(bone)
	var pose := skeleton.get_bone_pose(id)
	var parent := skeleton.get_bone_parent(id)
	while parent >= 0:
		pose = skeleton.get_bone_pose(parent) * pose
		parent = skeleton.get_bone_parent(parent)
	return pose.origin


func test_vexa_plays_fitted_mocap_for_her_six_posed_moves() -> void:
	var view := _view(&"vexa")
	for id in VEXA_FITTED:
		var fighter := FighterState.new()
		fighter.begin_move(_move(&"vexa", id))
		view.apply_state(fighter, 0.0)
		assert_true(view.is_playing_motion(), "%s plays mocap" % id)
		assert_eq(view.current_clip(), StringName("fit_%s" % id))
	assert_string_contains(view._motion.clip_sources[&"fit_launcher"], "mirrored",
		"her left-handed launcher is the right-handed uppercut, mirrored")


func test_lyra_and_brann_play_fitted_mocap_for_every_move() -> void:
	for who: StringName in [&"lyra", &"brann"]:
		var view := _view(who)
		assert_not_null(view.layers, "%s runs MotionLayers" % who)
		for move in _moves(who):
			var fighter := FighterState.new()
			fighter.begin_move(move)
			view.apply_state(fighter, 0.0)
			assert_eq(view.current_clip(), StringName("fit_%s" % move.id), "%s %s plays its fitted take" % [who, move.id])
			assert_almost_eq(view._motion.get_animation(view.current_clip()).length, move.total_ticks() / 60.0, 0.001,
				"%s %s lasts the move" % [who, move.id])


func test_a_mirrored_clip_swaps_the_sides() -> void:
	var view := _view(&"kael")
	var rig := MotionClips.Rig.new(_skeleton(view))
	var take := view._motion.get_animation(&"light_2")
	var mirrored := MotionClips.mirror(take, rig)
	var time := take.length * 0.5
	var a := MotionClips._sample(take, rig, time)
	var b := MotionClips._sample(mirrored, rig, time)
	var right := (rig.world(a[0], a[1])[rig.index[&"RightHand"]] as Transform3D).origin
	var left := (rig.world(b[0], b[1])[rig.index[&"LeftHand"]] as Transform3D).origin
	assert_almost_eq(left.x, -right.x, 0.02, "the left hand goes where the right hand went, reflected")
	assert_almost_eq(left.y, right.y, 0.02)
	assert_almost_eq(left.z, right.z, 0.02)
	rig.free_layers()


func test_every_legend_has_its_own_motion_profile() -> void:
	var profiles := {}
	for who: StringName in SCENES:
		var view := _view(who)
		assert_not_null(view.clips.motion_profile, "%s has a profile" % who)
		profiles[who] = view.profile
		assert_eq(view.layers.blend_frequency, view.profile.blend_frequency, "%s layers take the profile" % who)
	assert_lt(profiles[&"brann"].blend_frequency, profiles[&"kael"].blend_frequency, "Brann blends slower (heavier)")
	assert_gt(profiles[&"vexa"].blend_frequency, profiles[&"kael"].blend_frequency, "Vexa blends quicker")
	assert_gt(profiles[&"vexa"].crouch, profiles[&"kael"].crouch, "Vexa fights lower")
	assert_gt(profiles[&"brann"].landing_scale, profiles[&"kael"].landing_scale, "Brann lands heavier")
	assert_gt(profiles[&"brann"].impact_weight, 0.0, "Brann's strikes carry weight")
	assert_gt(profiles[&"lyra"].hover_bob, profiles[&"kael"].hover_bob * 2.0, "Lyra floats")
	assert_lt(profiles[&"lyra"].lean_frequency, profiles[&"kael"].lean_frequency, "Lyra's lean is softer")


func test_vexa_crouches_with_her_feet_still_on_the_floor() -> void:
	var view := _view(&"vexa")
	var fighter := FighterState.new()
	fighter.position.y = MovementTuning.new().ground_height
	_step(view, fighter, 60)
	assert_almost_eq(view.layers._crouch, view.profile.crouch, 0.005, "the stance sinks by her crouch")
	var rest := _skeleton(view).get_bone_global_rest(_skeleton(view).find_bone(&"LeftFoot")).origin.y
	var low := minf(_global(view, &"LeftFoot").y, _global(view, &"RightFoot").y)
	assert_almost_eq(low, rest, 0.04, "a foot stays planted at its height")


func test_brann_takes_the_weight_when_a_strike_lands() -> void:
	var view := _view(&"brann")
	var move := _move(&"brann", &"smash")
	var fighter := FighterState.new()
	fighter.begin_move(move)
	for tick in move.startup_ticks:
		fighter.move_tick = tick
		view.apply_state(fighter, DT)
	assert_eq(view.layers._landing_velocity, 0.0)
	fighter.move_tick = move.startup_ticks
	view.apply_state(fighter, DT)
	assert_lt(view.layers._landing_velocity, -1.0, "the hips drop into the impact")


func test_every_legend_stands_up_fully_inside_the_knockdown() -> void:
	for who: StringName in SCENES:
		var view := _view(who)
		var standing := FighterState.new()
		view.apply_state(standing, DT)
		var stand_height := _global(view, &"Head").y
		var lowest := INF
		for tick in 100:
			var fighter := FighterState.new()
			fighter.state = FighterState.State.KNOCKDOWN
			fighter.state_ticks = tick
			fighter.stun_ticks = 100 - tick
			view.apply_state(fighter, DT)
			lowest = minf(lowest, _global(view, &"Head").y)
		var end := _global(view, &"Head").y
		assert_lt(lowest, stand_height * 0.4, "%s goes down" % who)
		assert_gt(end, stand_height * 0.92, "%s is back up in the stance by the end (%.2f of %.2f m)" % [who, end, stand_height])


func test_idle_turns_wider_than_45_degrees_step_the_feet_round() -> void:
	var view := _view(&"kael")
	var fighter := FighterState.new()
	_step(view, fighter, 10)
	fighter.facing_yaw = deg_to_rad(30.0)
	_step(view, fighter, 2)
	assert_eq(view.current_clip(), &"fight_idle", "a small turn just twists the hips")
	fighter.facing_yaw = deg_to_rad(100.0)
	_step(view, fighter, 2)
	assert_eq(view.current_clip(), &"turn_step", "a wide turn steps")
	_step(view, fighter, 120)
	assert_eq(view.current_clip(), &"fight_idle", "then settles back into the stance")


func test_turn_step_keeps_the_body_facing_ahead() -> void:
	var view := _view(&"kael")
	var take := view._motion.get_animation(&"turn_step")
	var track := take.find_track(NodePath("%GeneralSkeleton:Hips"), Animation.TYPE_ROTATION_3D)
	var start := MotionLayers._yaw_of(take.rotation_track_interpolate(track, 0.0))
	for i in 11:
		var yaw := MotionLayers._yaw_of(take.rotation_track_interpolate(track, take.length * i / 10.0))
		assert_almost_eq(angle_difference(start, yaw), 0.0, 0.05, "no body yaw at %d/10" % i)


func test_jabs_load_the_shoulder_inside_startup() -> void:
	var view := _view(&"kael")
	for item: Array in [[&"light_1", &"LeftHand"], [&"light_2", &"RightHand"]]:
		var move := _move(&"kael", item[0])
		var target := VexaMoveClips.strike_point(move)
		var fighter := FighterState.new()
		fighter.begin_move(move)
		var away := 0
		var last := INF
		for tick in move.startup_ticks + 1:
			fighter.move_tick = tick
			view.apply_state(fighter, 0.0)
			var d := _global(view, item[1]).distance_to(target)
			if tick > 0 and d > last + 0.002:
				away += 1
			last = d
		assert_between(away, 2, move.startup_ticks - 1, "%s pulls back %d ticks before it fires" % [item[0], away])


func test_a_dive_goes_horizontal_and_an_air_dash_bursts() -> void:
	var view := _view(&"kael")
	var fighter := FighterState.new()
	fighter.enter_state(FighterState.State.FLYING)
	fighter.position = Vector3(0, 8, 0)
	fighter.velocity = Vector3(0, -22, -12)
	_step(view, fighter, 90)
	assert_gt(view.layers.lean.x, deg_to_rad(84.0), "the dive is a horizontal superman line")
	assert_lt(view.layers.lean.x, deg_to_rad(100.0), "and never flips over")
	fighter = FighterState.new()
	fighter.enter_state(FighterState.State.DASHING)
	fighter.position = Vector3(0, 8, 0)
	fighter.velocity = Vector3(0, 0, -30)
	_step(view, fighter, 4)
	assert_eq(view.current_clip(), &"hover", "the air dash builds on the upright base, not a pitched take")
	assert_gt(view.layers._burst, 0.4, "and snaps into the burst pose")
	for who: StringName in [&"vexa", &"lyra"]:
		var other := _view(who)
		fighter.state_ticks = 0
		other.apply_state(fighter, DT)
		other.layers._process_modification_with_delta(DT)
		other.layers._process_modification_with_delta(DT)
		assert_gt(other.layers._burst, 0.1, "%s's dash snap still bursts" % who)


func test_arm_twist_is_limited_and_never_wraps() -> void:
	var view := _view(&"kael")
	var layers := view.layers
	var skeleton := _skeleton(view)
	var bone := skeleton.find_bone(&"RightLowerArm")
	var axis: Vector3 = layers._bone_axis[bone]
	var rest: Quaternion = layers._rest_rot[bone]
	var rotations: Array[Quaternion] = []
	for i in skeleton.get_bone_count():
		rotations.append(skeleton.get_bone_pose_rotation(i))
	var hips := skeleton.get_bone_pose_position(skeleton.find_bone(&"Hips"))
	var last := Quaternion.IDENTITY
	for step in 40:
		# The source twists on past 180 degrees: the output must stop at the limit, not flip.
		var twisted := rotations.duplicate()
		twisted[bone] = rest * Quaternion(axis, step * 0.12)
		layers.process_pose(twisted, hips, DT)
		var out: Quaternion = twisted[bone]
		var local := rest.inverse() * out
		var angle := 2.0 * atan2(Vector3(local.x, local.y, local.z).dot(axis), local.w)
		assert_lt(absf(wrapf(angle, -PI, PI)), MotionLayers.TWIST_LIMITS[&"RightLowerArm"] + 0.01)
		if step > 0:
			assert_lt(last.angle_to(out), 0.2, "no flip at step %d" % step)
		last = out


func test_no_body_bone_turns_faster_than_the_pop_guard_allows() -> void:
	var view := _view(&"kael")
	var layers := view.layers
	var skeleton := _skeleton(view)
	var rotations: Array[Quaternion] = []
	for i in skeleton.get_bone_count():
		rotations.append(skeleton.get_bone_pose_rotation(i))
	var hips := skeleton.get_bone_pose_position(skeleton.find_bone(&"Hips"))
	layers.process_pose(rotations.duplicate(), hips, DT)
	var before := layers._last_out.duplicate()
	var flipped := rotations.duplicate()
	var chest := skeleton.find_bone(&"Chest")
	flipped[chest] = Quaternion(Vector3.UP, 2.5) * flipped[chest]
	layers.process_pose(flipped, hips, DT)
	assert_lt((before[chest] as Quaternion).angle_to(layers._last_out[chest]), MotionLayers.MAX_TURN_RATE * DT + 0.01,
		"a 2.5 rad jump is spread over frames")


func test_motion_legends_lean_through_their_layers_only() -> void:
	var view := FighterView.new()
	view.character_scene = load(SCENES[&"kael"]) as PackedScene
	var fighter := FighterState.new()
	fighter.state = FighterState.State.MOVING
	fighter.velocity = Vector3(0, 0, -30)
	view.fighter = fighter
	add_child_autofree(view)
	assert_true(view.leans_itself())
	for _i in 30:
		view.present(1.0, DT)
	var body := view.get_child(0) as Node3D
	assert_almost_eq(body.basis.get_euler().x, 0.0, 0.001, "the body node stays upright")
	var vexa := _view(&"vexa")
	var layer := vexa.defer_to_layers(VexaView.procedural_layer(fighter, 1.0), fighter)
	assert_eq(layer[&"Spine"].rotation, Quaternion.IDENTITY, "Vexa's own lean is off while her layers lean")
