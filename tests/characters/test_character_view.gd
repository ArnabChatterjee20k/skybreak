extends GutTest

const KAEL_PATH := "res://game/characters/kael/kael.tscn"
const MOVE_SET_PATH := "res://game/combat/moves/kael/kael_move_set.tres"
const PREVIEW_PATH := "res://game/characters/preview/character_preview.tscn"
const TOON_SHADER_PATH := "res://game/view/shaders/toon.gdshader"
const OUTLINE_SHADER_PATH := "res://game/view/shaders/outline.gdshader"
## Face decals (eyes, brows, lashes) are alpha-cut overlays, not toon surfaces.
const DECAL_MATERIALS := ["kael_brow", "kael_eyelash", "kael_eyeline", "kael_iris",
	"kael_eye_highlight", "kael_eye_extra"]
## Surfaces that are toon-shaded but drawn without the ink outline.
const NO_OUTLINE_MATERIALS := ["kael_mouth", "kael_eye_white"]
## Profile bones a VRoid body has no bone for.
const OPTIONAL_PROFILE_BONES := ["Jaw"]
const FRAME := 1.0 / 60.0
const TIMING_TOLERANCE_TICKS := 2

var _view: CharacterView
var _fighter: FighterState


func before_each() -> void:
	_view = (load(KAEL_PATH) as PackedScene).instantiate() as CharacterView
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


## Bounds of all meshes in the CharacterView's space.
func _bounds() -> AABB:
	var bounds := AABB()
	var first := true
	for mesh in _meshes():
		var to_view := _view.global_transform.affine_inverse() * mesh.global_transform
		var box := to_view * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _clip_time_at(tick: int) -> float:
	_fighter.move_tick = tick
	_view.apply_state(_fighter, 0.0)
	return _view.current_clip_time()


func test_kael_scene_loads_as_a_character_view() -> void:
	assert_not_null(_view)
	assert_not_null(_view.clips, "has a clip set")
	assert_not_null(_view.model, "has a model")


func test_skeleton_maps_to_the_humanoid_profile() -> void:
	var skeleton := _skeleton()
	assert_not_null(skeleton, "model has a unique %GeneralSkeleton")
	var profile := SkeletonProfileHumanoid.new()
	for i in profile.bone_size:
		var bone := profile.get_bone_name(i)
		if String(bone) in OPTIONAL_PROFILE_BONES:
			continue
		assert_ne(skeleton.find_bone(bone), -1, "skeleton has profile bone %s" % bone)


func test_every_mapped_clip_exists() -> void:
	for clip in _view.clips.mapped_clips():
		assert_true(_view.clips.library.has_animation(clip), "library has clip %s" % clip)


func test_every_kael_move_has_its_own_clip() -> void:
	for move in _moves():
		assert_true(_view.clips.move_clips.has(move.id), "%s is mapped" % move.id)


func test_clips_only_animate_the_humanoid_skeleton() -> void:
	for clip in _view.clips.library.get_animation_list():
		var animation := _view.clips.library.get_animation(clip)
		for track in animation.get_track_count():
			assert_eq(String(animation.track_get_path(track)).get_slice(":", 0), "%GeneralSkeleton",
				"%s track %d targets the retargeted skeleton" % [clip, track])


func test_apply_state_handles_every_state() -> void:
	for state_value: int in FighterState.State.values():
		_fighter = FighterState.new()
		_fighter.enter_state(state_value)
		for _frame in 10:
			_fighter.state_ticks += 1
			_view.apply_state(_fighter, FRAME)
		assert_ne(_view.current_clip(), &"", "%s plays a clip" % FighterState.State.find_key(state_value))


func test_apply_state_handles_every_attack_phase() -> void:
	var move_set := load(MOVE_SET_PATH) as MoveSet
	_fighter.begin_move(move_set.smash)
	_fighter.holding_charge = true
	_fighter.charge_ticks = 5
	_view.apply_state(_fighter, FRAME)
	assert_eq(_view.current_clip(), _view.clips.charge_hold_clip, "holding a charge plays the hold clip")
	_fighter.holding_charge = false
	for tick in move_set.smash.total_ticks():
		_fighter.move_tick = tick
		_view.apply_state(_fighter, FRAME)
	assert_eq(_view.current_clip(), _view.clips.clip_for_move(&"smash"))


func test_states_pick_their_clips() -> void:
	var expected := {
		FighterState.State.IDLE: &"fight_stance",
		FighterState.State.MOVING: &"run",
		FighterState.State.FLYING: &"fly_hover",
		FighterState.State.FALLING: &"fall",
		FighterState.State.DASHING: &"dash",
		FighterState.State.CHARGING: &"power_up_start",
		FighterState.State.GUARD_BROKEN: &"guard_broken",
	}
	for state_value: int in expected:
		_fighter.enter_state(state_value)
		_view.apply_state(_fighter, FRAME)
		assert_eq(_view.current_clip(), expected[state_value])


func test_fast_flight_and_blocking_pick_their_clips() -> void:
	_fighter.enter_state(FighterState.State.FLYING)
	_fighter.velocity = Vector3(0, 0, -25)
	_view.apply_state(_fighter, FRAME)
	assert_eq(_view.current_clip(), _view.clips.fly_fast_clip)
	_fighter.velocity = Vector3.ZERO
	_fighter.blocking = true
	_view.apply_state(_fighter, FRAME)
	assert_eq(_view.current_clip(), _view.clips.block_clip)


func test_states_added_later_fall_back_or_map_by_name() -> void:
	assert_eq(_view.clips.clip_for_state(&"NOT_A_STATE"), &"fight_stance")
	assert_eq(_view.clips.clip_for_state(&"HITSTUN"), &"hit")
	assert_eq(_view.clips.clip_for_state(&"KNOCKDOWN"), &"knockdown")


func test_hit_states_pick_their_clips() -> void:
	var expected := {&"HITSTUN": &"hit", &"BLOCKSTUN": &"block_hit", &"KNOCKDOWN": &"knockdown",
		&"BLOCKING": &"block", &"GRABBED": &"guard_broken", &"THROWING": &"overhead"}
	for state_name: StringName in expected:
		if not FighterState.State.has(state_name):
			continue
		_fighter.enter_state(FighterState.State[state_name])
		_fighter.stun_ticks = 20
		_view.apply_state(_fighter, FRAME)
		assert_eq(_view.current_clip(), expected[state_name])


func test_a_knockout_falls_and_lies_down_in_one_unbroken_clip() -> void:
	_fighter.position.y = 6.0
	_fighter.enter_state(FighterState.State.KO_FALL)
	for _frame in 40:
		_fighter.state_ticks += 1
		_view.apply_state(_fighter, FRAME)
	assert_eq(_view.current_clip(), &"knockdown")
	var fall_time := _view.current_clip_time()
	assert_gt(fall_time, 0.5, "the fall clip runs on")
	_fighter.position.y = 1.0
	_fighter.enter_state(FighterState.State.KO_DOWN)
	for _frame in 400:
		_fighter.state_ticks += 1
		_view.apply_state(_fighter, FRAME)
	assert_eq(_view.current_clip(), &"knockdown", "no get-up while knocked out")
	assert_gt(_view.current_clip_time(), fall_time, "not restarted on landing: it ends lying down")


func test_knockdown_ends_getting_up() -> void:
	if not FighterState.State.has("KNOCKDOWN"):
		pass_test("no KNOCKDOWN state yet")
		return
	_fighter.enter_state(FighterState.State.KNOCKDOWN)
	_fighter.stun_ticks = 40
	_view.apply_state(_fighter, FRAME)
	assert_eq(_view.current_clip(), &"knockdown")
	_fighter.state_ticks = 30
	_view.apply_state(_fighter, FRAME)
	assert_eq(_view.current_clip(), _view.clips.get_up_clip)


func test_hitstun_clip_fills_the_stun() -> void:
	_fighter.enter_state(FighterState.State.HITSTUN)
	_fighter.stun_ticks = 16
	for frame in 16:
		_fighter.state_ticks = frame
		_view.apply_state(_fighter, FRAME)
	var length := _view.clips.library.get_animation(&"hit").length
	assert_almost_eq(_view.current_clip_time(), length, length * 0.1, "the hit clip ends with the stun")


func test_hitstop_freezes_the_pose() -> void:
	_fighter.enter_state(FighterState.State.HITSTUN)
	_fighter.stun_ticks = 30
	_view.apply_state(_fighter, FRAME)
	var before := _view.current_clip_time()
	_fighter.hitstop_ticks = 4
	for _frame in 4:
		_view.apply_state(_fighter, FRAME)
	assert_eq(_view.current_clip_time(), before)


func test_apply_state_never_moves_or_turns_the_node() -> void:
	var before := _view.transform
	for state_value: int in FighterState.State.values():
		_fighter.enter_state(state_value)
		_fighter.velocity = Vector3(5, 3, -20)
		for _frame in 30:
			_view.apply_state(_fighter, FRAME)
	for move in _moves():
		_fighter.begin_move(move)
		for tick in move.total_ticks():
			_fighter.move_tick = tick
			_view.apply_state(_fighter, FRAME)
	assert_eq(_view.transform, before)


func test_clips_have_no_horizontal_root_motion() -> void:
	var track_path := NodePath("%GeneralSkeleton:Hips")
	for clip in _view.clips.library.get_animation_list():
		var animation := _view.clips.library.get_animation(clip)
		var track := animation.find_track(track_path, Animation.TYPE_POSITION_3D)
		if track < 0:
			continue
		var first: Vector3 = animation.track_get_key_value(track, 0)
		for key in animation.track_get_key_count(track):
			var value: Vector3 = animation.track_get_key_value(track, key)
			assert_almost_eq(Vector2(value.x, value.z), Vector2(first.x, first.z), Vector2(0.001, 0.001),
				"%s hips stay put horizontally" % clip)


func test_model_is_about_two_metres_tall_and_centred_on_the_capsule() -> void:
	var bounds := _bounds()
	assert_almost_eq(bounds.size.y, 2.0, 0.1, "about 2 m tall")
	assert_almost_eq(bounds.position.y, -1.0, 0.05, "feet 1 m below the origin")
	assert_almost_eq(bounds.get_center().y, 0.0, 0.1, "centred on the capsule centre")
	assert_lt(absf(bounds.get_center().x), 0.1, "centred left/right")
	assert_lt(absf(bounds.get_center().z), 0.15, "centred front/back")


func test_model_faces_minus_z() -> void:
	var skeleton := _skeleton()
	var to_view := _view.global_transform.affine_inverse() * skeleton.global_transform
	var left_hand := to_view * skeleton.get_bone_global_rest(skeleton.find_bone(&"LeftHand")).origin
	var left_toes := to_view * skeleton.get_bone_global_rest(skeleton.find_bone(&"LeftToes")).origin
	var left_foot := to_view * skeleton.get_bone_global_rest(skeleton.find_bone(&"LeftFoot")).origin
	assert_lt(left_hand.x, -0.3, "the left hand is on -X, so the model faces -Z")
	assert_lt(left_toes.z, left_foot.z, "toes point to -Z")


func test_body_surfaces_use_the_toon_shader_with_an_outline() -> void:
	var checked := 0
	for mesh in _meshes():
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			assert_not_null(material, "%s surface %d has a material" % [mesh.name, surface])
			if material == null or material.resource_name in DECAL_MATERIALS:
				continue
			assert_is(material, ShaderMaterial, "%s is a toon material" % material.resource_name)
			if not material is ShaderMaterial:
				continue
			assert_eq((material as ShaderMaterial).shader.resource_path, TOON_SHADER_PATH,
				"%s uses the toon shader" % material.resource_name)
			if material.resource_name in NO_OUTLINE_MATERIALS:
				continue
			var outline := material.next_pass as ShaderMaterial
			assert_not_null(outline, "%s has an outline pass" % material.resource_name)
			if outline:
				assert_eq(outline.shader.resource_path, OUTLINE_SHADER_PATH)
			checked += 1
	assert_gt(checked, 5, "skin, face, hair and clothes are outlined toon surfaces")


func test_attack_active_window_lines_up_with_the_active_phase() -> void:
	for move in _moves():
		var clip := _view.clips.clip_for_move(move.id)
		var window: Vector2 = _view.clips.impact_windows.get(clip, Vector2(-1, -1))
		assert_true(_view.clips.impact_windows.has(clip), "%s (%s) has a measured impact window" % [move.id, clip])
		_fighter.begin_move(move)
		var first := -1
		var last := -1
		for tick in move.total_ticks():
			var time := _clip_time_at(tick)
			if time >= window.x - 0.0001 and time <= window.y + 0.0001:
				if first < 0:
					first = tick
				last = tick
		assert_almost_eq(first, move.startup_ticks, TIMING_TOLERANCE_TICKS,
			"%s: strike lands on the first active tick" % move.id)
		assert_almost_eq(last, move.recovery_start_tick() - 1, TIMING_TOLERANCE_TICKS,
			"%s: strike ends on the last active tick" % move.id)


func test_attack_clip_time_only_moves_forward() -> void:
	for move in _moves():
		_fighter.begin_move(move)
		var previous := -1.0
		for tick in move.total_ticks():
			var time := _clip_time_at(tick)
			assert_gte(time, previous, "%s tick %d" % [move.id, tick])
			previous = time


func test_energy_colour_sets_the_rim_instance_uniforms() -> void:
	_view.set_energy_color(Color(1.0, 0.6, 0.2, 0.75))
	for mesh in _meshes():
		assert_eq(mesh.get_instance_shader_parameter(&"rim_energy_color"), Color(1.0, 0.6, 0.2, 1.0))
		assert_almost_eq(float(mesh.get_instance_shader_parameter(&"rim_energy_mix")), 0.75, 0.0001)


func test_vanished_hides_the_model_only() -> void:
	_view.set_vanished(true)
	assert_false(_view.model.visible)
	assert_true(_view.visible, "the node itself stays FighterView's to show or hide")
	_view.set_vanished(false)
	assert_true(_view.model.visible)


func test_preview_cycles_every_state_and_move() -> void:
	var preview := (load(PREVIEW_PATH) as PackedScene).instantiate()
	var entries: Array[Dictionary] = preview.preview_entries(load(MOVE_SET_PATH) as MoveSet)
	preview.free()
	var labels := entries.map(func(entry: Dictionary) -> String: return entry.label)
	for state_name: String in FighterState.State.keys():
		if state_name != "ATTACKING":
			assert_has(labels, state_name)
	for move in _moves():
		assert_has(labels, "ATTACKING " + String(move.id))
