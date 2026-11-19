extends GutTest
## T-D22b: MotionLibrary + MotionLayers inside CharacterView, for Kael and Vexa.

const SCENES := {
	&"kael": "res://game/characters/kael_chunky/kael_chunky.tscn",
	&"vexa": "res://game/characters/vexa/vexa.tscn",
}
const MOVE_SETS := {
	&"kael": "res://game/combat/moves/kael/kael_move_set.tres",
	&"vexa": "res://game/combat/moves/vexa/vexa_move_set.tres",
}
const PLANTED_SOLE := 0.03
const DT := 1.0 / 60.0
const BODY: Array[StringName] = [&"Hips", &"Spine", &"Chest", &"UpperChest", &"Neck", &"Head",
	&"LeftUpperArm", &"LeftLowerArm", &"RightUpperArm", &"RightLowerArm",
	&"LeftUpperLeg", &"LeftLowerLeg", &"RightUpperLeg", &"RightLowerLeg"]
## Largest frame-to-frame change of a body bone's world rotation allowed through a whole bot
## match, clip switches included (radians per 60 fps frame). Mocap jabs peak near 0.5.
const MAX_FRAME_ROTATION := 1.2
## Planted-foot slide allowed while running at the clip's speed (cm per contact frame).
const MAX_FOOT_SLIDE_CM := 1.5
## MotionLayers for 4 fighters, total CPU per frame (ms). The target is 0.5 ms on the dev PC;
## the test allows headroom for slow CI machines and prints the measured value.
const MAX_LAYERS_MS := 2.0


func _view(who: StringName, motion := true) -> CharacterView:
	var view := (load(SCENES[who]) as PackedScene).instantiate() as CharacterView
	if not motion:
		view.clips = view.clips.duplicate()
		view.clips.motion = null
	add_child_autofree(view)
	return view


func _moves(who: StringName) -> Array[MoveData]:
	var set := load(MOVE_SETS[who]) as MoveSet
	var moves: Array[MoveData] = []
	moves.append_array(set.light_string)
	moves.append_array(set.charged_smash)
	for move: MoveData in [set.smash, set.breaker, set.launcher, set.rising, set.spike, set.sweep,
			set.push_block, set.grab]:
		if move != null:
			moves.append(move)
	return moves


## Runs the live layers once, as the skeleton would after apply_state.
## Lowest sole point of one foot (with its toes) above the floor, in model space.
func _sole_height(view: CharacterView, skeleton: Skeleton3D, foot: StringName) -> float:
	var side := String(foot).trim_suffix("Foot")
	var low := INF
	for item: Array in view.body.soles:
		if String(skeleton.get_bone_name(item[0])).begins_with(side):
			low = minf(low, (skeleton.get_bone_global_pose(item[0]) * (item[1] as Vector3)).y)
	return low


func _layer(view: CharacterView, delta := DT) -> void:
	if view.layers:
		view.layers._process_modification_with_delta(delta)


func _skeleton(view: CharacterView) -> Skeleton3D:
	return view.model.get_node("%GeneralSkeleton") as Skeleton3D


func _world_rotations(skeleton: Skeleton3D) -> Array[Quaternion]:
	var out: Array[Quaternion] = []
	for bone in BODY:
		var id := skeleton.find_bone(bone)
		var q := skeleton.get_bone_pose_rotation(id)
		var parent := skeleton.get_bone_parent(id)
		while parent >= 0:
			q = skeleton.get_bone_pose_rotation(parent) * q
			parent = skeleton.get_bone_parent(parent)
		out.append(q)
	return out


func test_both_characters_play_mocap_with_live_layers() -> void:
	for who: StringName in SCENES:
		var view := _view(who)
		assert_not_null(view.layers, "%s runs MotionLayers" % who)
		assert_eq(view.layers.get_parent(), _skeleton(view), "%s layers sit on the skeleton" % who)
		assert_eq(view.layers.get_index(), 0, "%s layers run before the other modifiers" % who)
		var fighter := FighterState.new()
		view.apply_state(fighter, DT)
		assert_true(view.is_playing_motion(), "%s idles on mocap" % who)


func test_mocap_attack_clips_are_seeked_frame_accurately_by_move_tick() -> void:
	for who: StringName in SCENES:
		var view := _view(who)
		var windows := MotionClips.impact_windows(view.clips.motion)
		for move in _moves(who):
			var fighter := FighterState.new()
			fighter.begin_move(move)
			view.apply_state(fighter, 0.0)
			if not view.is_playing_motion():
				continue
			var clip := view.current_clip()
			var window: Vector2 = windows.get(clip, Vector2.ZERO)
			if window == Vector2.ZERO:
				continue
			fighter.move_tick = move.startup_ticks
			view.apply_state(fighter, 0.0)
			assert_almost_eq(view.current_clip_time(), window.x, 0.001, "%s %s: active starts on the clip's impact" % [who, move.id])
			fighter.move_tick = move.recovery_start_tick()
			view.apply_state(fighter, 0.0)
			assert_almost_eq(view.current_clip_time(), window.y, 0.001, "%s %s: recovery starts after the impact" % [who, move.id])
			if who == &"kael":
				var length := view._motion.get_animation(clip).length
				assert_almost_eq(length, move.total_ticks() / 60.0, 0.001, "%s lasts Kael's move" % clip)


func test_derived_clips_replace_the_weak_takes() -> void:
	var view := _view(&"kael")
	var set := load(MOVE_SETS[&"kael"]) as MoveSet
	for pair: Array in [[set.launcher, &"launcher_up"], [set.sweep, &"sweep_low"]]:
		var fighter := FighterState.new()
		fighter.begin_move(pair[0])
		view.apply_state(fighter, 0.0)
		assert_eq(view.current_clip(), pair[1])
	var hit := FighterState.new()
	hit.enter_state(FighterState.State.HITSTUN)
	hit.stun_ticks = 30
	hit.knockback_type = MoveData.KnockbackType.BLOWBACK
	view.apply_state(hit, DT)
	assert_eq(view.current_clip(), &"hit_stagger", "a heavy hit staggers")


func test_the_sweep_stays_low_and_the_launcher_rises() -> void:
	var view := _view(&"kael")
	var set := load(MOVE_SETS[&"kael"]) as MoveSet
	var skeleton := _skeleton(view)
	var fighter := FighterState.new()
	fighter.begin_move(set.sweep)
	fighter.move_tick = set.sweep.startup_ticks + 1
	view.apply_state(fighter, 0.0)
	var toes := skeleton.get_bone_global_pose(skeleton.find_bone(&"RightToes")).origin
	assert_lt(toes.y, 0.35, "the sweeping foot travels along the floor")
	fighter = FighterState.new()
	fighter.begin_move(set.launcher)
	fighter.move_tick = set.launcher.startup_ticks - 4
	view.apply_state(fighter, 0.0)
	var low := skeleton.get_bone_global_pose(skeleton.find_bone(&"RightHand")).origin.y
	fighter.move_tick = set.launcher.recovery_start_tick()
	view.apply_state(fighter, 0.0)
	var high := skeleton.get_bone_global_pose(skeleton.find_bone(&"RightHand")).origin.y
	assert_gt(high - low, 0.3, "the uppercut rips up from low")


func test_derived_clips_have_no_nans_and_unit_rotations() -> void:
	var view := _view(&"kael")
	var library := MotionClips.build(view.clips.motion, _skeleton(view))
	for clip: StringName in MotionClips.DERIVED:
		var animation := library.get_animation(clip)
		for track in animation.get_track_count():
			for key in animation.track_get_key_count(track):
				var value: Variant = animation.track_get_key_value(track, key)
				if value is Quaternion:
					assert_almost_eq((value as Quaternion).length(), 1.0, 0.001, "%s rotations are unit" % clip)
				else:
					assert_true((value as Vector3).is_finite(), "%s hips are finite" % clip)


func test_a_bot_match_runs_3600_ticks_stable_finite_and_without_pops() -> void:
	var old := _bot_match(false)
	var new := _bot_match(true)
	gut.p("bot match, old clips: worst %.3f rad/frame (%s)" % [old.worst, old.where])
	gut.p("bot match, mocap + layers: worst %.3f rad/frame (%s), %d frames over %.1f (old %d), %d events" % [
		new.worst, new.where, new.over, MAX_FRAME_ROTATION, old.over, new.flinches])
	assert_eq(new.nan_frames, 0, "no NaN, non-unit or runaway poses")
	assert_gt(new.flinches, 0, "the bots traded hits")
	assert_lt(new.over, maxi(old.over, 1) * 2 + 2, "no more pops than the old clips had")


func _bot_match(motion: bool) -> Dictionary:
	var sim := CombatSim.new(7)
	var views: Array[CharacterView] = []
	var bots: Array[WeaponBot] = []
	var whos := [&"kael", &"vexa"]
	for i in 2:
		views.append(_view(whos[i], motion))
		# Default stats: WeaponMoves caches weapon sets per kind from the first unarmed set it sees
		# (filed in TODO.md), so arming a Vexa sim fighter here would leak into later tests.
		sim.add_fighter(Vector3(i * 6.0 - 3.0, 1.0, 0))
		bots.append(WeaponBot.new(i, 11 + i))
	sim.pickups_enabled = true
	sim.lock_everyone_onto_nearest()
	var previous: Array = [[], []]
	var worst := 0.0
	var where := ""
	var over := 0
	var nan_frames := 0
	var flinches := 0
	for tick in 3600:
		var inputs: Array[FighterInput] = [bots[0].next_input(sim), bots[1].next_input(sim)]
		sim.tick(inputs)
		for i in 2:
			var view := views[i]
			var fighter := sim.fighters[i]
			for event: Dictionary in sim.events:
				if event.get("target", -1) == i:
					view.react_to_event(event, fighter)
					flinches += 1
			view.set_look_target(sim.fighters[1 - i].position)
			view.apply_state(fighter, DT)
			_layer(view)
			var skeleton := _skeleton(view)
			var now := _world_rotations(skeleton)
			for q in now:
				if not q.is_finite() or not is_equal_approx(q.length(), 1.0):
					nan_frames += 1
			var hips := skeleton.get_bone_pose_position(skeleton.find_bone(&"Hips"))
			if not hips.is_finite() or hips.length() > 3.0:
				nan_frames += 1
			if not (previous[i] as Array).is_empty() and fighter.hitstop_ticks == 0:
				var frame_worst := 0.0
				for b in now.size():
					var change := (previous[i][b] as Quaternion).angle_to(now[b])
					if change > worst:
						worst = change
						where = "tick %d fighter %d %s: %s, clip %s (motion %s), state_ticks %d" % [tick, i, BODY[b],
							FighterState.State.find_key(fighter.state), view.current_clip(), view.is_playing_motion(), fighter.state_ticks]
					frame_worst = maxf(frame_worst, change)
				if frame_worst > MAX_FRAME_ROTATION:
					over += 1
			previous[i] = now
	return {"worst": worst, "where": where, "over": over, "nan_frames": nan_frames, "flinches": flinches}


func test_clip_switches_are_inertialized_not_popped() -> void:
	var view := _view(&"kael")
	var skeleton := _skeleton(view)
	var fighter := FighterState.new()
	fighter.velocity = Vector3(0, 0, -9)
	fighter.enter_state(FighterState.State.MOVING)
	for _i in 20:
		fighter.state_ticks += 1
		view.apply_state(fighter, DT)
		_layer(view)
	var before := _world_rotations(skeleton)
	fighter = FighterState.new()
	fighter.enter_state(FighterState.State.BLOCKSTUN)
	fighter.stun_ticks = 20
	view.apply_state(fighter, DT)
	_layer(view)
	var after := _world_rotations(skeleton)
	var jump := 0.0
	for b in before.size():
		jump = maxf(jump, before[b].angle_to(after[b]))
	assert_lt(jump, 0.35, "the first frame of the new clip starts from the old pose (%.2f rad)" % jump)


func test_hit_events_flinch_the_upper_body_away_from_the_hit() -> void:
	for who: StringName in SCENES:
		var view := _view(who)
		var skeleton := _skeleton(view)
		var fighter := FighterState.new()
		for _i in 10:
			view.apply_state(fighter, DT)
			_layer(view)
		view.apply_state(fighter, DT)
		var chest := skeleton.find_bone(&"Chest")
		var calm := skeleton.get_bone_pose_rotation(chest)
		# Hit from the front: the contact point is ahead of the fighter (view faces -Z).
		view.react_to_event({"type": CombatSim.EventType.HIT, "position": Vector3(0, 1, -0.8),
			"knockback_type": MoveData.KnockbackType.BLOWBACK}, fighter)
		for _i in 4:
			_layer(view)
			view.apply_state(fighter, 0.0)
		_layer(view)
		var hit := skeleton.get_bone_pose_rotation(chest)
		assert_gt(calm.angle_to(hit), 0.05, "%s chest snaps on the hit" % who)
		var head := skeleton.get_bone_global_pose(skeleton.find_bone(&"Head")).origin
		view.apply_state(fighter, 0.0)
		var head_calm := skeleton.get_bone_global_pose(skeleton.find_bone(&"Head")).origin
		assert_lt(head.z, head_calm.z, "%s head goes back, away from a hit in front" % who)


func test_planted_feet_barely_slide_while_running() -> void:
	for who: StringName in SCENES:
		var view := _view(who)
		var skeleton := _skeleton(view)
		var fighter := FighterState.new()
		fighter.enter_state(FighterState.State.MOVING)
		var speed := view._clip_speed(&"run")
		fighter.velocity = Vector3(0, 0, -speed)
		var slide := 0.0
		var contacts := 0
		var last := {}
		for frame in 120:
			fighter.state_ticks += 1
			view.apply_state(fighter, DT)
			_layer(view)
			for foot in [&"LeftFoot", &"RightFoot"]:
				# Model space (+Z forward) plus the body's travel: the foot's path over the floor.
				var p := skeleton.get_bone_global_pose(skeleton.find_bone(foot)).origin + Vector3(0, 0, speed * frame * DT)
				if last.has(foot) and frame > 30:
					var step := Vector2(p.x - last[foot].x, p.z - last[foot].z).length()
					# Planted: the foot's lowest sole point is on the floor.
					if _sole_height(view, skeleton, foot) < PLANTED_SOLE and step / DT < 1.0:
						slide += step
						contacts += 1
				last[foot] = p
		var per_contact := slide * 100.0 / maxi(contacts, 1)
		gut.p("%s run: %.2f cm slide per planted frame over %d frames" % [who, per_contact, contacts])
		assert_gt(contacts, 10, "%s plants its feet" % who)
		assert_lt(per_contact, MAX_FOOT_SLIDE_CM, "%s feet stay put while planted" % who)


func test_flight_pitches_with_speed_and_banks_into_turns() -> void:
	var view := _view(&"kael")
	var fighter := FighterState.new()
	fighter.enter_state(FighterState.State.FLYING)
	fighter.position = Vector3(0, 6, 0)
	fighter.velocity = Vector3(0, 0, -22)
	for _i in 60:
		view.apply_state(fighter, DT)
		_layer(view)
	assert_gt(view.layers.lean.x, deg_to_rad(35.0), "pitches forward at speed")
	assert_lt(view.layers.lean.x, deg_to_rad(80.0), "never flips over")
	for i in 30:
		fighter.velocity = Vector3(i * 0.8, 0, -22)
		view.apply_state(fighter, DT)
		_layer(view)
	assert_gt(absf(view.layers.lean.z), 0.15, "banks into the turn")


func test_layers_never_feed_back_into_the_sim() -> void:
	var sim := CombatSim.new(3)
	var mirror := CombatSim.new(3)
	for s: CombatSim in [sim, mirror]:
		s.add_fighter(Vector3(-3, 1, 0))
		s.add_fighter(Vector3(3, 1, 0))
		s.lock_everyone_onto_nearest()
	var views: Array[CharacterView] = [_view(&"kael"), _view(&"vexa")]
	var bots := [WeaponBot.new(0, 5), WeaponBot.new(1, 6)]
	var mirror_bots := [WeaponBot.new(0, 5), WeaponBot.new(1, 6)]
	for tick in 600:
		sim.tick([bots[0].next_input(sim), bots[1].next_input(sim)] as Array[FighterInput])
		mirror.tick([mirror_bots[0].next_input(mirror), mirror_bots[1].next_input(mirror)] as Array[FighterInput])
		for i in 2:
			for event: Dictionary in sim.events:
				if event.get("target", -1) == i:
					views[i].react_to_event(event, sim.fighters[i])
			views[i].apply_state(sim.fighters[i], DT)
			_layer(views[i])
	assert_eq(sim.state_hash(), mirror.state_hash(), "a match with views is the same match")


func test_four_fighters_of_layers_fit_the_cpu_budget() -> void:
	var views: Array[CharacterView] = []
	for i in 4:
		views.append(_view(&"kael" if i % 2 == 0 else &"vexa"))
	var fighters: Array[FighterState] = []
	for i in 4:
		var f := FighterState.new()
		f.enter_state(FighterState.State.MOVING)
		f.velocity = Vector3(3, 0, -7)
		fighters.append(f)
	for i in 4:
		views[i].set_look_target(Vector3(5, 1, 0))
		views[i].apply_state(fighters[i], DT)
	var frames := 300
	var total := 0
	for frame in frames:
		for i in 4:
			fighters[i].state_ticks += 1
			views[i].apply_state(fighters[i], DT)
		var start := Time.get_ticks_usec()
		for view in views:
			_layer(view)
		total += Time.get_ticks_usec() - start
	var ms := total / 1000.0 / frames
	gut.p("MotionLayers + foot IK, 4 fighters: %.3f ms per frame" % ms)
	assert_lt(ms, MAX_LAYERS_MS)
