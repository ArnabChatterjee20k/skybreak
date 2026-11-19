extends GutTest

const SCENE_PATH := "res://game/characters/kael_chunky/kael_chunky.tscn"
const PREVIEW_PATH := "res://game/characters/kael_chunky/preview/kael_chunky_preview.tscn"
const SHARED_LIBRARY_PATH := "res://game/characters/animations/humanoid_clips.res"
const MOVE_SET_PATH := "res://game/combat/moves/kael/kael_move_set.tres"
const TOON_SHADER_PATH := "res://game/view/shaders/toon.gdshader"
const OUTLINE_SHADER_PATH := "res://game/view/shaders/outline.gdshader"
const SCARF_BONES: Array[StringName] = [&"Scarf1", &"Scarf2", &"Scarf3", &"Scarf4", &"Scarf5"]
## The striking point of each move (a bone head), as authored in source/kael_anims.py.
const STRIKE_BONES := {
	&"light_1": &"LeftMiddleProximal", &"light_2": &"RightMiddleProximal", &"light_3": &"LeftMiddleProximal",
	&"light_4": &"RightToes", &"smash": &"RightMiddleProximal", &"breaker": &"LeftMiddleProximal",
	&"launcher": &"RightMiddleProximal", &"rising": &"RightToes", &"spike": &"RightToes", &"sweep": &"RightToes",
	&"charged_smash_1": &"RightMiddleProximal", &"charged_smash_2": &"RightMiddleProximal",
	&"charged_smash_3": &"RightMiddleProximal", &"push_block": &"LeftMiddleProximal",
}
const FRAME := 1.0 / 60.0
const PEAK_TOLERANCE_TICKS := 2

var _view: CharacterView
var _fighter: FighterState


func before_each() -> void:
	_view = (load(SCENE_PATH) as PackedScene).instantiate() as CharacterView
	add_child_autofree(_view)
	_fighter = FighterState.new()


func _moves() -> Array[MoveData]:
	var move_set := load(MOVE_SET_PATH) as MoveSet
	var moves: Array[MoveData] = []
	moves.append_array(move_set.light_string)
	moves.append_array(move_set.charged_smash)
	for move: MoveData in [move_set.smash, move_set.breaker, move_set.launcher, move_set.rising,
			move_set.spike, move_set.sweep, move_set.push_block]:
		moves.append(move)
	return moves


func _skeleton() -> Skeleton3D:
	return _view.model.get_node("%GeneralSkeleton") as Skeleton3D


func _meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for node in _view.model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	return meshes


func _scarf() -> ScarfLag:
	return _skeleton().find_children("*", "SkeletonModifier3D", false, false)[0] as ScarfLag


## A bone's position in the view's space, from the local poses the clip just set.
func _bone_in_view(bone: StringName) -> Vector3:
	var skeleton := _skeleton()
	var id := skeleton.find_bone(bone)
	var pose := skeleton.get_bone_pose(id)
	var parent := skeleton.get_bone_parent(id)
	while parent >= 0:
		pose = skeleton.get_bone_pose(parent) * pose
		parent = skeleton.get_bone_parent(parent)
	var to_view := _view.global_transform.affine_inverse() * skeleton.global_transform
	return to_view * pose.origin


func _mean_active_hitbox(move: MoveData) -> Vector3:
	var sum := Vector3.ZERO
	for tick in move.active_ticks:
		sum += move.hitbox_offsets[mini(tick, move.hitbox_offsets.size() - 1)]
	return sum / move.active_ticks


func _bounds() -> AABB:
	var bounds := AABB()
	var first := true
	for mesh in _meshes():
		var box := (_view.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func test_the_scene_loads_as_a_character_view() -> void:
	assert_not_null(_view)
	assert_not_null(_view.clips, "has a clip set")
	assert_not_null(_view.model, "has a model")
	assert_eq(_meshes().size(), 1, "one skinned mesh")


func test_the_skeleton_maps_to_the_humanoid_profile_with_its_parents() -> void:
	var skeleton := _skeleton()
	assert_not_null(skeleton, "model has a unique %GeneralSkeleton")
	var profile := SkeletonProfileHumanoid.new()
	for i in profile.bone_size:
		var bone := profile.get_bone_name(i)
		var id := skeleton.find_bone(bone)
		assert_ne(id, -1, "skeleton has profile bone %s" % bone)
		if id < 0 or profile.get_bone_parent(i) == &"":
			continue
		assert_eq(skeleton.get_bone_name(skeleton.get_bone_parent(id)), String(profile.get_bone_parent(i)),
			"%s hangs from the profile's parent" % bone)


func test_every_shared_humanoid_clip_finds_its_bones() -> void:
	var skeleton := _skeleton()
	var shared: AnimationLibrary = load(SHARED_LIBRARY_PATH)
	for clip in shared.get_animation_list():
		var animation := shared.get_animation(clip)
		for track in animation.get_track_count():
			var bone := String(animation.track_get_path(track)).get_slice(":", 1)
			assert_ne(skeleton.find_bone(bone), -1, "shared clip %s drives bone %s" % [clip, bone])


func test_every_mapped_clip_exists_and_every_move_has_its_own_clip() -> void:
	for clip in _view.clips.mapped_clips():
		assert_true(_view.clips.library.has_animation(clip), "library has clip %s" % clip)
	for move in _moves():
		assert_true(_view.clips.move_clips.has(move.id), "%s is mapped" % move.id)
		assert_true(_view.clips.library.has_animation(_view.clips.move_clips.get(move.id, &"")),
			"%s's clip exists" % move.id)


func test_clips_only_animate_the_humanoid_skeleton() -> void:
	for clip in _view.clips.library.get_animation_list():
		var animation := _view.clips.library.get_animation(clip)
		for track in animation.get_track_count():
			assert_eq(String(animation.track_get_path(track)).get_slice(":", 0), "%GeneralSkeleton",
				"%s track %d targets the retargeted skeleton" % [clip, track])


func test_apply_state_handles_every_fighter_state() -> void:
	for state_value: int in FighterState.State.values():
		_fighter = FighterState.new()
		_fighter.enter_state(state_value)
		_fighter.stun_ticks = 30
		for _frame in 10:
			_fighter.state_ticks += 1
			_view.apply_state(_fighter, FRAME)
		var clip := _view.current_clip()
		assert_true(_view.clips.library.has_animation(clip), "%s plays a clip (%s)"
			% [FighterState.State.find_key(state_value), clip])


func test_states_pick_kaels_own_clips_where_he_has_them() -> void:
	var expected := {
		FighterState.State.IDLE: &"idle",
		FighterState.State.CHARGING: &"power_up",
		FighterState.State.FLYING: &"hover",
		FighterState.State.MOVING: &"run",
	}
	for state_value: int in expected:
		_fighter.enter_state(state_value)
		_view.apply_state(_fighter, FRAME)
		assert_eq(_view.current_clip(), expected[state_value])
	_fighter.enter_state(FighterState.State.FLYING)
	_fighter.velocity = Vector3(0, 0, -25)
	_view.apply_state(_fighter, FRAME)
	assert_eq(_view.current_clip(), &"fly", "fast flight dives")


func test_holding_a_charge_plays_the_hold_clip() -> void:
	var move_set := load(MOVE_SET_PATH) as MoveSet
	_fighter.begin_move(move_set.smash)
	_fighter.holding_charge = true
	_fighter.charge_ticks = 5
	_view.apply_state(_fighter, FRAME)
	assert_eq(_view.current_clip(), &"smash_hold")


func test_attack_clips_last_exactly_the_move() -> void:
	for move in _moves():
		var clip := _view.clips.clip_for_move(move.id)
		assert_almost_eq(_view.clips.library.get_animation(clip).length, move.total_ticks() / 60.0, 0.001,
			"%s clip lasts the move" % move.id)


func test_each_strike_peaks_inside_its_active_ticks() -> void:
	for move in _moves():
		var bone: StringName = STRIKE_BONES[move.id]
		var target := _mean_active_hitbox(move)
		_fighter.begin_move(move)
		var best_tick := -1
		var best := INF
		for tick in move.total_ticks():
			_fighter.move_tick = tick
			_view.apply_state(_fighter, 0.0)
			var distance := _bone_in_view(bone).distance_to(target)
			if distance < best:
				best = distance
				best_tick = tick
		assert_between(best_tick, move.startup_ticks - PEAK_TOLERANCE_TICKS,
			move.recovery_start_tick() - 1 + PEAK_TOLERANCE_TICKS,
			"%s: %s is closest to the hitbox on tick %d (active %d-%d)" % [move.id, bone, best_tick,
			move.startup_ticks, move.recovery_start_tick() - 1])


func test_apply_state_never_moves_or_turns_the_view() -> void:
	var before := _view.transform
	var model_before := _view.model.transform
	for state_value: int in FighterState.State.values():
		_fighter.enter_state(state_value)
		_fighter.velocity = Vector3(5, 3, -20)
		for _frame in 20:
			_view.apply_state(_fighter, FRAME)
	for move in _moves():
		_fighter.begin_move(move)
		for tick in move.total_ticks():
			_fighter.move_tick = tick
			_view.apply_state(_fighter, FRAME)
	assert_eq(_view.transform, before)
	assert_eq(_view.model.transform, model_before)


func test_clips_have_no_root_motion() -> void:
	var hips_path := NodePath("%GeneralSkeleton:Hips")
	for clip in _view.clips.library.get_animation_list():
		var animation := _view.clips.library.get_animation(clip)
		assert_eq(animation.find_track(NodePath("%GeneralSkeleton:Root"), Animation.TYPE_POSITION_3D), -1,
			"%s never moves the Root" % clip)
		var track := animation.find_track(hips_path, Animation.TYPE_POSITION_3D)
		if track < 0:
			continue
		var first: Vector3 = animation.track_get_key_value(track, 0)
		for key in animation.track_get_key_count(track):
			var value: Vector3 = animation.track_get_key_value(track, key)
			assert_almost_eq(Vector2(value.x, value.z), Vector2(first.x, first.z), Vector2(0.001, 0.001),
				"%s hips stay put horizontally" % clip)


func test_impacts_squash_and_stretch_the_chest() -> void:
	var animation := _view.clips.library.get_animation(&"smash")
	var track := animation.find_track(NodePath("%GeneralSkeleton:Chest"), Animation.TYPE_SCALE_3D)
	assert_ne(track, -1, "smash has a chest scale track")
	var low := INF
	var high := -INF
	for key in animation.track_get_key_count(track):
		var y: float = (animation.track_get_key_value(track, key) as Vector3).y
		low = minf(low, y)
		high = maxf(high, y)
	assert_lt(low, 0.92, "squashes on the wind-up")
	assert_gt(high, 1.06, "stretches on the hit")


func test_the_model_is_about_two_metres_tall_centred_one_metre_above_the_feet() -> void:
	var bounds := _bounds()
	assert_almost_eq(bounds.size.y, 2.0, 0.1, "about 2 m tall")
	assert_almost_eq(bounds.position.y, -1.0, 0.03, "feet 1 m below the origin")
	assert_almost_eq(bounds.get_center().y, 0.0, 0.08, "centred on the capsule centre")
	assert_lt(absf(bounds.get_center().x), 0.1, "centred left/right")
	assert_lt(absf(bounds.get_center().z), 0.15, "centred front/back")


func test_the_model_faces_minus_z() -> void:
	var skeleton := _skeleton()
	var to_view := _view.global_transform.affine_inverse() * skeleton.global_transform
	var left_hand := to_view * skeleton.get_bone_global_rest(skeleton.find_bone(&"LeftHand")).origin
	var left_toes := to_view * skeleton.get_bone_global_rest(skeleton.find_bone(&"LeftToes")).origin
	var left_foot := to_view * skeleton.get_bone_global_rest(skeleton.find_bone(&"LeftFoot")).origin
	assert_lt(left_hand.x, -0.3, "the left hand is on -X, so the model faces -Z")
	assert_lt(left_toes.z, left_foot.z, "toes point to -Z")


func test_every_surface_uses_the_toon_shader_with_an_outline() -> void:
	var mesh := _meshes()[0]
	assert_gte(mesh.mesh.get_surface_count(), 8, "a material slot per part")
	for surface in mesh.mesh.get_surface_count():
		var material := mesh.get_active_material(surface) as ShaderMaterial
		assert_not_null(material, "surface %d is a ShaderMaterial" % surface)
		if material == null:
			continue
		assert_eq(material.shader.resource_path, TOON_SHADER_PATH, "%s uses the toon shader" % material.resource_name)
		var outline := material.next_pass as ShaderMaterial
		assert_not_null(outline, "%s has an outline pass" % material.resource_name)
		if outline:
			assert_eq(outline.shader.resource_path, OUTLINE_SHADER_PATH)


func test_the_scarf_has_a_chain_of_bones() -> void:
	var skeleton := _skeleton()
	var parent := &"UpperChest"
	for bone in SCARF_BONES:
		var id := skeleton.find_bone(bone)
		assert_ne(id, -1, "%s exists" % bone)
		if id >= 0:
			assert_eq(skeleton.get_bone_name(skeleton.get_bone_parent(id)), String(parent), "%s chains" % bone)
		parent = bone
	assert_eq(_scarf().bones, SCARF_BONES, "the scarf lag drives the chain")


func test_the_scarf_trails_behind_motion_and_settles_back() -> void:
	var scarf := _scarf()
	scarf.reset_chain()
	var rest := _chain_targets(Vector3.ZERO)
	scarf.advance(rest, FRAME)
	var moved := _chain_targets(Vector3(1, 0, 0))
	var points := scarf.advance(moved, FRAME)
	assert_lt(points[-1].x, moved[-1].x - 0.3, "the tip lags behind a sudden move")
	for _i in 600:
		points = scarf.advance(moved, FRAME)
	assert_almost_eq(points[-1].x, moved[-1].x, 0.05, "and settles back")


func test_the_scarf_lag_is_deterministic() -> void:
	var first := ScarfLag.new()
	var second := ScarfLag.new()
	var deltas := [FRAME, 0.007, 0.031, FRAME, 0.05, 0.002, FRAME]
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	for i in 120:
		var targets := _chain_targets(Vector3(sin(i * 0.2), cos(i * 0.13) * 0.5, i * 0.05))
		var delta: float = deltas[i % deltas.size()]
		a = first.advance(targets, delta)
		b = second.advance(targets, delta)
	assert_eq(a, b, "same motion and frame times give the same scarf")
	first.free()
	second.free()


func test_the_scarf_moves_in_the_scene() -> void:
	_fighter.enter_state(FighterState.State.IDLE)
	for _frame in 5:
		_view.apply_state(_fighter, FRAME)
		await wait_physics_frames(1)
	var skeleton := _skeleton()
	var tip := skeleton.find_bone(SCARF_BONES[-1])
	var before := skeleton.get_bone_global_pose(tip).origin
	_view.position.x += 2.0
	for _frame in 3:
		_view.apply_state(_fighter, FRAME)
		await wait_physics_frames(1)
	assert_ne(skeleton.get_bone_global_pose(tip).origin, before, "the scarf swings when he moves")


func test_energy_colour_and_vanish() -> void:
	_view.set_energy_color(Color(1.0, 0.6, 0.2, 0.75))
	for mesh in _meshes():
		assert_eq(mesh.get_instance_shader_parameter(&"rim_energy_color"), Color(1.0, 0.6, 0.2, 1.0))
		assert_almost_eq(float(mesh.get_instance_shader_parameter(&"rim_energy_mix")), 0.75, 0.0001)
	_view.set_vanished(true)
	assert_false(_view.model.visible)
	_view.set_vanished(false)
	assert_true(_view.model.visible)


func test_the_preview_shows_chunky_kael() -> void:
	var preview := (load(PREVIEW_PATH) as PackedScene).instantiate()
	assert_eq((preview.character_scene as PackedScene).resource_path, SCENE_PATH)
	preview.free()


## Joint positions of a straight chain hanging from origin.
func _chain_targets(origin: Vector3) -> PackedVector3Array:
	var targets := PackedVector3Array()
	for i in 6:
		targets.append(origin + Vector3(0, -0.19 * i, -0.2))
	return targets
