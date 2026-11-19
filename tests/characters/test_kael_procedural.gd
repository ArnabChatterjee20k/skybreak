extends GutTest

const SCENE := preload("res://game/characters/kael_procedural/procedural_kael.tscn")
const MOVE_SET := preload("res://game/combat/moves/kael/kael_move_set.tres")
const TOON_SHADER := "res://game/view/shaders/toon.gdshader"
const OUTLINE_SHADER := "res://game/view/shaders/outline.gdshader"
const BRIEF_CLIPS: Array[StringName] = [&"idle", &"run", &"fly_hover", &"fly_forward", &"dash",
	&"charge_ki", &"fall", &"light_1", &"light_2", &"light_3", &"light_4", &"smash", &"breaker",
	&"launcher", &"rising", &"spike", &"sweep", &"charged_smash_1", &"charged_smash_2",
	&"charged_smash_3", &"hitstun_light", &"hitstun_heavy", &"blockstun", &"block", &"guard_broken",
	&"knockdown", &"get_up", &"victory", &"defeat"]

var _view: ProceduralKaelView


func before_each() -> void:
	_view = add_child_autofree(SCENE.instantiate())


func _fighter(state: FighterState.State) -> FighterState:
	var fighter := FighterState.new()
	fighter.health = 100
	fighter.enter_state(state)
	return fighter


func _attacking(move: MoveData, tick: int) -> FighterState:
	var fighter := _fighter(FighterState.State.IDLE)
	fighter.begin_move(move)
	fighter.move_tick = tick
	return fighter


func _meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for node in _view.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	return meshes


## A bone's position in the view's own space (origin at the capsule centre, facing -Z).
func _bone_position(bone: StringName) -> Vector3:
	var skeleton := _view.skeleton()
	var pose := skeleton.get_bone_global_pose(skeleton.find_bone(bone))
	return _view.global_transform.affine_inverse() * skeleton.global_transform * pose.origin


func _mean_hitbox(move: MoveData) -> Vector3:
	var total := Vector3.ZERO
	for tick in move.active_ticks:
		total += move.hitboxes_at(move.startup_ticks + tick)[0].start
	return total / move.active_ticks


func test_the_scene_loads_with_a_mesh_skeleton_and_animations() -> void:
	assert_not_null(_view.skeleton())
	assert_gt(_meshes().size(), 0)
	assert_eq(_view.current_clip(), &"idle")


func test_every_required_humanoid_bone_exists_with_the_profile_parent() -> void:
	var profile := SkeletonProfileHumanoid.new()
	var skeleton := _view.skeleton()
	for i in profile.bone_size:
		var bone := profile.get_bone_name(i)
		var index := skeleton.find_bone(bone)
		if profile.is_required(i):
			assert_ne(index, -1, "missing humanoid bone %s" % bone)
		if index == -1 or profile.get_bone_parent(i) == &"":
			continue
		assert_eq(skeleton.get_bone_name(skeleton.get_bone_parent(index)), String(profile.get_bone_parent(i)),
			"parent of %s" % bone)


func test_the_skeleton_has_fingers_and_hair_bones() -> void:
	var skeleton := _view.skeleton()
	for bone in [&"LeftIndexDistal", &"RightThumbDistal", &"LeftLittleProximal", &"RightToes"]:
		assert_ne(skeleton.find_bone(bone), -1, String(bone))
	var hair := 0
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_name(i).begins_with("Hair"):
			hair += 1
	assert_between(hair, 3, 6)


func test_every_clip_in_the_brief_exists() -> void:
	var player: AnimationPlayer = _view.find_children("*", "AnimationPlayer", true, false)[0]
	for clip in BRIEF_CLIPS:
		assert_true(player.has_animation(clip), "missing clip %s" % clip)
	for clip in ProceduralKaelView.CLIPS:
		assert_true(player.has_animation(clip), "missing clip %s" % clip)


func test_every_move_in_the_move_set_has_a_clip() -> void:
	var moves: Array[MoveData] = []
	moves.append_array(MOVE_SET.light_string)
	moves.append_array(MOVE_SET.charged_smash)
	moves.append_array([MOVE_SET.smash, MOVE_SET.breaker, MOVE_SET.launcher, MOVE_SET.rising,
		MOVE_SET.spike, MOVE_SET.sweep, MOVE_SET.push_block])
	for move in moves:
		assert_true(move.id in ProceduralKaelView.CLIPS, "no clip for %s" % move.id)
		assert_true(ProceduralKaelView.STRIKE_BONES.has(move.id), "no strike bone for %s" % move.id)


func test_apply_state_plays_a_clip_for_every_fighter_state() -> void:
	for state: FighterState.State in FighterState.State.values():
		var fighter := _fighter(state)
		if state == FighterState.State.ATTACKING:
			fighter = _attacking(MOVE_SET.smash, 3)
		_view.apply_state(fighter, 1.0 / 60.0)
		assert_true(_view.current_clip() in ProceduralKaelView.CLIPS,
			"state %s -> %s" % [FighterState.State.find_key(state), _view.current_clip()])


func test_states_map_to_their_clips() -> void:
	var expected := {
		FighterState.State.IDLE: &"idle",
		FighterState.State.MOVING: &"run",
		FighterState.State.FALLING: &"fall",
		FighterState.State.FLYING: &"fly_hover",
		FighterState.State.DASHING: &"dash",
		FighterState.State.CHARGING: &"charge_ki",
		FighterState.State.GUARD_BROKEN: &"guard_broken",
		FighterState.State.HITSTUN: &"hitstun_light",
		FighterState.State.BLOCKSTUN: &"blockstun",
		FighterState.State.KNOCKDOWN: &"knockdown",
	}
	for state: FighterState.State in expected:
		_view.apply_state(_fighter(state), 1.0 / 60.0)
		assert_eq(_view.current_clip(), expected[state])


func test_hitstun_is_light_without_knockback_and_heavy_with_it() -> void:
	var fighter := _fighter(FighterState.State.HITSTUN)
	fighter.stun_ticks = 20
	_view.apply_state(fighter, 1.0 / 60.0)
	assert_eq(_view.current_clip(), &"hitstun_light")
	fighter.knockback_type = MoveData.KnockbackType.LAUNCH
	_view.apply_state(fighter, 1.0 / 60.0)
	assert_eq(_view.current_clip(), &"hitstun_heavy")


func test_stun_clips_stretch_over_the_stun_ticks() -> void:
	var fighter := _fighter(FighterState.State.BLOCKSTUN)
	fighter.stun_ticks = 32
	fighter.state_ticks = 17
	_view.apply_state(fighter, 1.0 / 60.0)
	assert_eq(_view.current_clip(), &"blockstun")
	assert_almost_eq(_view.current_clip_time() * 60.0, _view.clip_ticks(&"blockstun") * 0.5, 0.01)


func test_knockdown_lies_on_the_floor_then_gets_up_as_it_ends() -> void:
	var fighter := _fighter(FighterState.State.KNOCKDOWN)
	fighter.stun_ticks = 90
	fighter.state_ticks = 1
	_view.apply_state(fighter, 1.0 / 60.0)
	assert_eq(_view.current_clip(), &"knockdown")
	assert_lt(_bone_position(&"Hips").y, -0.6, "on the floor")
	fighter.state_ticks = 90
	_view.apply_state(fighter, 1.0 / 60.0)
	assert_eq(_view.current_clip(), &"get_up")
	assert_almost_eq(_view.current_clip_time() * 60.0, float(_view.clip_ticks(&"get_up") - 1), 0.01)


func test_fast_flight_leans_forward_and_blocking_raises_the_guard() -> void:
	var flying := _fighter(FighterState.State.FLYING)
	flying.velocity = Vector3(0, 0, -20)
	_view.apply_state(flying, 1.0 / 60.0)
	assert_eq(_view.current_clip(), &"fly_forward")
	var blocking := _fighter(FighterState.State.IDLE)
	blocking.blocking = true
	_view.apply_state(blocking, 1.0 / 60.0)
	assert_eq(_view.current_clip(), &"block")


func test_a_knocked_out_fighter_plays_defeat() -> void:
	var fighter := _fighter(FighterState.State.IDLE)
	fighter.health = 0
	_view.apply_state(fighter, 1.0 / 60.0)
	assert_eq(_view.current_clip(), &"defeat")


func test_unknown_states_fall_back_to_idle() -> void:
	var fighter := _fighter(FighterState.State.IDLE)
	fighter.state = 999 as FighterState.State
	_view.apply_state(fighter, 1.0 / 60.0)
	assert_eq(_view.current_clip(), &"idle")


func test_attack_clips_are_seeked_by_move_tick() -> void:
	for tick in [0, 5, 7, 12]:
		_view.apply_state(_attacking(MOVE_SET.light_string[0], tick), 1.0 / 60.0)
		assert_eq(_view.current_clip(), &"light_1")
		assert_almost_eq(_view.current_clip_time(), tick / 60.0, 0.0001)


func test_holding_a_charge_plays_the_hold_clip_by_phase_tick() -> void:
	var fighter := _attacking(MOVE_SET.smash, 0)
	fighter.holding_charge = true
	fighter.charge_ticks = 11
	_view.apply_state(fighter, 1.0 / 60.0)
	assert_eq(_view.current_clip(), ProceduralKaelView.HOLD_CLIP)
	assert_almost_eq(_view.current_clip_time(), 10 / 60.0, 0.0001)


func test_apply_state_never_moves_or_turns_the_view() -> void:
	var placed := Transform3D(Basis(Vector3.UP, 0.7), Vector3(3, 2, 1))
	_view.transform = placed
	var model: Node3D = _view.get_node("Model")
	var model_transform := model.transform
	var skeleton := _view.skeleton()
	var root_pose := skeleton.get_bone_pose(skeleton.find_bone(&"Root"))
	var fighters: Array[FighterState] = []
	for state: FighterState.State in FighterState.State.values():
		fighters.append(_fighter(state))
	for move in MOVE_SET.light_string + [MOVE_SET.sweep, MOVE_SET.rising, MOVE_SET.charged_smash[2]]:
		for tick in range(0, move.total_ticks(), 3):
			fighters.append(_attacking(move, tick))
	for fighter in fighters:
		_view.apply_state(fighter, 1.0 / 60.0)
		assert_eq(_view.transform, placed)
		assert_eq(model.transform, model_transform)
		assert_eq(skeleton.get_bone_pose(skeleton.find_bone(&"Root")), root_pose)


func test_no_clip_animates_the_root_bone() -> void:
	var player: AnimationPlayer = _view.find_children("*", "AnimationPlayer", true, false)[0]
	for clip in player.get_animation_list():
		var animation := player.get_animation(clip)
		for track in animation.get_track_count():
			var path := String(animation.track_get_path(track))
			assert_false(path.ends_with(":Root"), "%s animates %s" % [clip, path])


func test_the_model_is_about_two_metres_tall_with_its_feet_one_metre_below_the_origin() -> void:
	var bounds := AABB()
	var first := true
	for mesh in _meshes():
		var box := _view.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	assert_almost_eq(bounds.size.y, 2.0, 0.12)
	assert_almost_eq(bounds.position.y, -1.0, 0.03)
	assert_almost_eq(bounds.get_center().y, 0.0, 0.1)
	assert_almost_eq(bounds.get_center().x, 0.0, 0.05)


func test_the_model_faces_minus_z() -> void:
	_view.pose_at(&"idle", 0)
	assert_lt(_bone_position(&"LeftToes").z, _bone_position(&"LeftFoot").z)
	assert_lt(_bone_position(&"LeftUpperArm").x, 0.0, "his left is -X when facing -Z")


func test_every_surface_uses_the_toon_shader_with_an_outline() -> void:
	for mesh in _meshes():
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as ShaderMaterial
			assert_not_null(material, "%s surface %d" % [mesh.name, surface])
			assert_eq(material.shader.resource_path, TOON_SHADER)
			assert_eq((material.next_pass as ShaderMaterial).shader.resource_path, OUTLINE_SHADER)


func test_each_attack_peaks_inside_its_active_window() -> void:
	for clip: StringName in ProceduralKaelView.STRIKE_BONES:
		var move: MoveData = load("res://game/combat/moves/kael/%s.tres" % clip)
		var target := _mean_hitbox(move)
		var best_tick := -1
		var best := INF
		for tick in move.total_ticks():
			_view.pose_at(clip, tick)
			var distance := _bone_position(ProceduralKaelView.STRIKE_BONES[clip]).distance_to(target)
			if distance < best:
				best = distance
				best_tick = tick
		var first_active := move.startup_ticks
		var last_active := move.recovery_start_tick() - 1
		assert_between(best_tick, first_active - 1, last_active + 1,
			"%s peaks at tick %d, active %d-%d" % [clip, best_tick, first_active, last_active])


func test_attack_clips_last_exactly_the_move() -> void:
	for clip: StringName in ProceduralKaelView.STRIKE_BONES:
		var move: MoveData = load("res://game/combat/moves/kael/%s.tres" % clip)
		assert_eq(_view.clip_ticks(clip), move.total_ticks() - 1, String(clip))


func test_set_energy_color_drives_the_rim_instance_uniforms() -> void:
	_view.set_energy_color(Color(1.0, 0.8, 0.2, 0.75))
	for mesh in _meshes():
		assert_eq(mesh.get_instance_shader_parameter(&"rim_energy_color"), Color(1.0, 0.8, 0.2, 1.0))
		assert_almost_eq(float(mesh.get_instance_shader_parameter(&"rim_energy_mix")), 0.75, 0.0001)


func test_set_vanished_hides_and_shows_the_model() -> void:
	_view.set_vanished(true)
	assert_false(_view.visible)
	_view.set_vanished(false)
	assert_true(_view.visible)
