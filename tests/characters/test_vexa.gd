extends GutTest

const VEXA_PATH := "res://game/characters/vexa/vexa.tscn"
const PREVIEW_PATH := "res://game/characters/vexa/preview/vexa_preview.tscn"
const DESIGN_PATH := "res://game/characters/vexa/vexa_design.tres"
const MOVE_SET_PATH := "res://game/combat/moves/kael/kael_move_set.tres"
const TOON_SHADER_PATH := "res://game/view/shaders/toon.gdshader"
const OUTLINE_SHADER_PATH := "res://game/view/shaders/outline.gdshader"
const FRAME := 1.0 / 60.0
const MAX_TRIANGLES := 15000
const MAX_DRAW_CALLS := 30

var _view: VexaView
var _fighter: FighterState


func before_each() -> void:
	_view = (load(VEXA_PATH) as PackedScene).instantiate() as VexaView
	add_child_autofree(_view)
	_fighter = FighterState.new()


func _design() -> VexaDesign:
	return load(DESIGN_PATH) as VexaDesign


func _skeleton() -> Skeleton3D:
	return _view.model.get_node("%GeneralSkeleton") as Skeleton3D


func _moves() -> Array[MoveData]:
	var move_set := load(MOVE_SET_PATH) as MoveSet
	var moves: Array[MoveData] = []
	moves.append_array(move_set.light_string)
	moves.append_array(move_set.charged_smash)
	for move: MoveData in [move_set.smash, move_set.breaker, move_set.launcher, move_set.rising,
			move_set.spike, move_set.sweep, move_set.push_block, move_set.grab]:
		if move:
			moves.append(move)
	return moves


## Bounds of every skinned vertex in the view's space, at the current pose.
func _posed_bounds() -> AABB:
	var skeleton := _skeleton()
	var to_view := _view.global_transform.affine_inverse() * skeleton.global_transform
	var bounds := AABB()
	var first := true
	for instance in (_view.model as VexaFigure).meshes:
		var mesh := instance.mesh
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			for i in vertices.size():
				var bone := bones[i * 4]
				var skinned := skeleton.get_bone_global_pose(bone) \
					* skeleton.get_bone_global_rest(bone).affine_inverse() * vertices[i]
				var point := to_view * skinned
				if first:
					bounds = AABB(point, Vector3.ZERO)
					first = false
				else:
					bounds = bounds.expand(point)
	return bounds


func _bone_poses(view: VexaView) -> Array:
	var skeleton := view.skeleton()
	var poses := []
	for bone in skeleton.get_bone_count():
		poses.append([skeleton.get_bone_pose_position(bone), skeleton.get_bone_pose_rotation(bone),
			skeleton.get_bone_pose_scale(bone)])
	return poses


func _kit_shapes() -> Dictionary:
	return {
		"rounded_box": FigureKit.rounded_box(Vector3(0.3, 0.2, 0.25), 0.5),
		"capsule": FigureKit.capsule(Vector3.ZERO, Vector3(0, 0.4, 0), Vector2(0.08, 0.06), Vector2(0.05, 0.05)),
		"point": FigureKit.point(PackedVector3Array([Vector3.ZERO, Vector3(0, 0.2, 0), Vector3(0.05, 0.35, -0.1),
			Vector3(0.1, 0.4, -0.3)]), Vector2(0.08, 0.05), 10, 0.9, Vector3.BACK, 1.6),
		"torus": FigureKit.torus(0.2, 0.04, 20, 8, Vector2(1.0, 0.6)),
		"extrude": FigureKit.extrude(PackedVector2Array([Vector2(-0.1, 0), Vector2(0.1, 0), Vector2(0.03, 0.04),
			Vector2(0, 0.12), Vector2(-0.03, 0.04)]), 0.03, 0.006),
		"cloth_flap": FigureKit.cloth_flap(PackedVector3Array([Vector3.ZERO, Vector3(0, -0.2, -0.05),
			Vector3(0.02, -0.4, -0.08)]), 0.08, 0.02, 0.4),
		"hood_shell": FigureKit.hood_shell(Vector3(0.48, 0.5, 0.5), 0.95, 0.025, 0.75, 0.42, -0.95),
	}


func test_the_scene_loads_as_a_character_view() -> void:
	assert_true(_view is CharacterView, "root is a CharacterView")
	assert_not_null(_view.clips, "has a clip set")
	assert_true(_view.model is VexaFigure, "model is the code-built figure")


func test_skeleton_has_every_profile_bone_with_its_parent_and_reference_rest() -> void:
	var skeleton := _skeleton()
	assert_not_null(skeleton, "model has a unique %GeneralSkeleton")
	var profile := SkeletonProfileHumanoid.new()
	for i in profile.bone_size:
		var bone := skeleton.find_bone(profile.get_bone_name(i))
		assert_ne(bone, -1, "has profile bone %s" % profile.get_bone_name(i))
		if bone == -1:
			continue
		var parent := skeleton.get_bone_parent(bone)
		assert_eq(skeleton.get_bone_name(parent) if parent >= 0 else &"", profile.get_bone_parent(i),
			"%s has the profile's parent" % profile.get_bone_name(i))
		var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		assert_almost_eq(rest.angle_to(profile.get_reference_pose(i).basis.get_rotation_quaternion()), 0.0, 2e-3,
			"%s rests like the profile, so the shared clips drive it" % profile.get_bone_name(i))


func test_every_part_follows_a_bone_of_the_skeleton() -> void:
	var skeleton := _skeleton()
	var parts := VexaFigure.parts(_design())
	assert_gt(parts.size(), 20, "the figure has its parts")
	for part in parts:
		assert_ne(skeleton.find_bone(part.bone), -1, "part on %s has a bone" % part.bone)


func test_merged_parts_are_rigid_one_bone_per_vertex() -> void:
	for instance in (_view.model as VexaFigure).meshes:
		for s in instance.mesh.get_surface_count():
			var weights: PackedFloat32Array = instance.mesh.surface_get_arrays(s)[Mesh.ARRAY_WEIGHTS]
			for i in range(0, weights.size(), 4):
				if weights[i] != 1.0:
					fail_test("vertex %d of surface %d is blended across bones" % [i / 4, s])
					return
	pass_test("every vertex follows exactly one bone")


func test_attached_assembly_puts_every_part_on_a_bone_attachment() -> void:
	var figure := VexaFigure.new()
	figure.design = _design()
	figure.assembly = FigureRig.Assembly.ATTACHED
	add_child_autofree(figure)
	assert_gt(figure.meshes.size(), 10, "one mesh per bone with parts")
	for instance in figure.meshes:
		var attachment := instance.get_parent() as BoneAttachment3D
		assert_not_null(attachment, "%s hangs from a BoneAttachment3D" % instance.get_path())
		if attachment:
			assert_ne(figure.skeleton.find_bone(attachment.bone_name), -1, "%s is a bone" % attachment.bone_name)


func test_apply_state_handles_every_state() -> void:
	for state_value: int in FighterState.State.values():
		_fighter = FighterState.new()
		_fighter.enter_state(state_value)
		_fighter.stun_ticks = 30
		_fighter.velocity = Vector3(0, 0, -10)
		for _frame in 10:
			_fighter.state_ticks += 1
			_view.apply_state(_fighter, FRAME)
		assert_ne(_view.current_clip(), &"", "%s plays a clip" % FighterState.State.find_key(state_value))


func test_vexa_maps_every_state_kael_maps() -> void:
	var kael := load("res://game/characters/kael/kael_clip_set.tres") as ClipSet
	for state_name: StringName in kael.state_clips:
		assert_true(_view.clips.state_clips.has(state_name), "%s is mapped" % state_name)
	for state_name: String in FighterState.State.keys():
		if state_name != "ATTACKING":
			assert_true(_view.clips.state_clips.has(StringName(state_name)), "sim state %s is mapped" % state_name)


func test_every_kael_stand_in_move_has_a_clip() -> void:
	for move in _moves():
		assert_true(_view.clips.library.has_animation(_view.clips.clip_for_move(move.id)), "%s has a clip" % move.id)


func test_no_root_motion_through_every_state_and_move() -> void:
	var skeleton := _skeleton()
	var root := skeleton.find_bone(&"Root")
	var view_transform := _view.transform
	var model_transform: Transform3D = (_view.model.get_parent() as Node3D).transform
	for state_value: int in FighterState.State.values():
		_fighter = FighterState.new()
		_fighter.enter_state(state_value)
		_fighter.velocity = Vector3(3, 0, -20)
		for _frame in 20:
			_fighter.state_ticks += 1
			_view.apply_state(_fighter, FRAME)
	for move in _moves():
		_fighter = FighterState.new()
		_fighter.begin_move(move)
		for tick in move.total_ticks():
			_fighter.move_tick = tick
			_view.apply_state(_fighter, FRAME)
	assert_eq(_view.transform, view_transform, "the view never moves itself")
	assert_eq((_view.model.get_parent() as Node3D).transform, model_transform, "the model holder never moves")
	assert_eq(skeleton.get_bone_pose(root), skeleton.get_bone_rest(root), "the Root bone is never posed")


func test_the_figure_is_about_two_metres_tall_with_feet_one_metre_below_the_origin() -> void:
	_fighter.enter_state(FighterState.State.IDLE)
	_view.apply_state(_fighter, FRAME)
	var bounds := _posed_bounds()
	assert_between(bounds.size.y, 1.85, 2.15, "about 2 m tall")
	assert_almost_eq(bounds.position.y, -1.0, 0.06, "feet 1 m below the origin")
	assert_almost_eq(bounds.get_center().y, 0.0, 0.1, "centred 1 m above the feet")
	assert_almost_eq(bounds.get_center().x, 0.0, 0.15, "centred on the capsule")


func test_the_figure_faces_minus_z() -> void:
	var skeleton := _skeleton()
	var to_view := _view.global_transform.affine_inverse() * skeleton.global_transform
	var toes := to_view * skeleton.get_bone_global_rest(skeleton.find_bone(&"LeftToes")).origin
	var foot := to_view * skeleton.get_bone_global_rest(skeleton.find_bone(&"LeftFoot")).origin
	assert_lt(toes.z, foot.z, "toes point to -Z")


func test_toon_surfaces_use_the_shared_shaders_and_glows_are_unshaded() -> void:
	var glows := 0
	for instance in (_view.model as VexaFigure).meshes:
		for s in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(s)
			if material is ShaderMaterial:
				assert_eq((material as ShaderMaterial).shader.resource_path, TOON_SHADER_PATH, "toon surface")
				var outline := material.next_pass as ShaderMaterial
				assert_not_null(outline, "toon surface has an outline pass")
				if outline:
					assert_eq(outline.shader.resource_path, OUTLINE_SHADER_PATH)
			else:
				var glow := material as StandardMaterial3D
				assert_not_null(glow, "non-toon surfaces are glow materials")
				if glow:
					assert_eq(glow.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "%s is unshaded" % glow.resource_name)
					assert_true(glow.emission_enabled, "%s glows" % glow.resource_name)
					glows += 1
	assert_eq(glows, 2, "visor and eyes are the glowing surfaces")


func test_render_cost_is_within_the_fighter_budget() -> void:
	var cost := FigureRig.render_cost((_view.model as VexaFigure).meshes)
	assert_lte(cost.x, MAX_TRIANGLES, "at most %d triangles" % MAX_TRIANGLES)
	assert_lte(cost.y, MAX_DRAW_CALLS, "at most %d draw calls" % MAX_DRAW_CALLS)


func test_the_procedural_layer_is_a_pure_function_of_state_and_time() -> void:
	for state_value: int in FighterState.State.values():
		_fighter = FighterState.new()
		_fighter.enter_state(state_value)
		_fighter.state_ticks = 3
		_fighter.velocity = Vector3(2, 0, -9)
		_fighter.facing_yaw = 0.7
		for time: float in [0.0, 0.37, 2.5]:
			assert_eq(VexaView.procedural_layer(_fighter, time), VexaView.procedural_layer(_fighter, time))


func test_two_views_fed_the_same_states_pose_identically() -> void:
	var other := (load(VEXA_PATH) as PackedScene).instantiate() as VexaView
	add_child_autofree(other)
	var states := [FighterState.State.IDLE, FighterState.State.MOVING, FighterState.State.DASHING,
		FighterState.State.HITSTUN, FighterState.State.FLYING]
	for state_value: int in states:
		_fighter = FighterState.new()
		_fighter.enter_state(state_value)
		_fighter.stun_ticks = 20
		_fighter.velocity = Vector3(1, 0, -12)
		for _frame in 15:
			_fighter.state_ticks += 1
			_view.apply_state(_fighter, FRAME)
			other.apply_state(_fighter, FRAME)
	assert_eq(_bone_poses(_view), _bone_poses(other), "same input, same pose (springs included)")


func test_the_layer_adds_on_top_of_the_clip_without_drifting() -> void:
	_fighter.enter_state(FighterState.State.HITSTUN)
	_fighter.stun_ticks = 30
	_fighter.hitstop_ticks = 5
	_fighter.state_ticks = 2
	for _frame in 30:
		_view.apply_state(_fighter, FRAME)
	var hips := _skeleton().find_bone(&"Hips")
	var held := _skeleton().get_bone_pose_scale(hips)
	for _frame in 30:
		_view.apply_state(_fighter, FRAME)
	assert_almost_eq(_skeleton().get_bone_pose_scale(hips), held, Vector3.ONE * 1e-5,
		"frozen frames reapply the same layer instead of stacking it")


func test_hits_squash_then_stretch_then_settle() -> void:
	var hips := _skeleton().find_bone(&"Hips")
	_fighter.enter_state(FighterState.State.HITSTUN)
	_fighter.stun_ticks = 30
	var heights: Array[float] = []
	for tick in range(1, 14):
		_fighter.state_ticks = tick
		_view.apply_state(_fighter, FRAME)
		heights.append(_skeleton().get_bone_pose_scale(hips).y)
	assert_lt(heights.min(), 0.9, "squashes on impact")
	assert_gt(heights.max(), 1.0, "then stretches")
	assert_almost_eq(heights[-1], 1.0, 1e-4, "and settles once the pulse is over")


func test_running_forward_leans_the_spine_forward() -> void:
	_fighter.enter_state(FighterState.State.MOVING)
	_fighter.velocity = Vector3(0, 0, -9)
	var lean := VexaView.procedural_layer(_fighter, 0.0)[&"Spine"].rotation as Quaternion
	var top := lean * Vector3.UP
	assert_gt(top.z, 0.1, "chest tips toward the model's front (+Z in the model)")
	_fighter.facing_yaw = PI / 2
	_fighter.velocity = Basis(Vector3.UP, PI / 2) * Vector3(0, 0, -9)
	var turned := VexaView.procedural_layer(_fighter, 0.0)[&"Spine"].rotation as Quaternion
	assert_almost_eq((turned * Vector3.UP).z, top.z, 1e-4, "lean follows the fighter's facing")


func test_dashes_snap_to_one_held_pose() -> void:
	_fighter.enter_state(FighterState.State.IDLE)
	for _frame in 10:
		_view.apply_state(_fighter, FRAME)
	_fighter = FighterState.new()
	_fighter.enter_state(FighterState.State.DASHING)
	_fighter.velocity = Vector3(0, 0, -22)
	_view.apply_state(_fighter, FRAME)
	var arm := _skeleton().find_bone(&"LeftLowerArm")
	var first := _skeleton().get_bone_pose_rotation(arm)
	assert_eq(_view.current_clip(), _view.clips.clip_for_state(&"DASHING"))
	assert_almost_eq(_view.current_clip_time(), _view.dash_snap_time, 1e-4, "jumps straight to the snap pose")
	for _frame in 8:
		_fighter.state_ticks += 1
		_view.apply_state(_fighter, FRAME)
	assert_eq(_skeleton().get_bone_pose_rotation(arm), first, "the clip pose holds for crisp afterimages")
	assert_eq(_view.afterimage_pose().size(), _skeleton().get_bone_count(), "afterimages get every bone")


func test_hood_points_lag_behind_a_sudden_move_and_settle() -> void:
	var skeleton := _skeleton()
	var point := skeleton.find_bone(VexaFigure.HOOD_POINTS[0])
	_fighter.enter_state(FighterState.State.IDLE)
	for _frame in 30:
		_view.apply_state(_fighter, FRAME)
	_fighter = FighterState.new()
	_fighter.enter_state(FighterState.State.DASHING)
	_fighter.velocity = Vector3(0, 0, -25)
	for _frame in 4:
		_view.apply_state(_fighter, FRAME)
	var swing := skeleton.get_bone_pose_rotation(point).get_angle()
	assert_gt(swing, 0.05, "the point trails the dash")
	_fighter = FighterState.new()
	_fighter.enter_state(FighterState.State.IDLE)
	for _frame in 180:
		_view.apply_state(_fighter, FRAME)
	assert_lt(skeleton.get_bone_pose_rotation(point).get_angle(), swing * 0.5, "and swings back")


func test_set_energy_color_and_vanish() -> void:
	_view.set_energy_color(Color(0.6, 0.3, 1.0, 0.5))
	var mesh := (_view.model as VexaFigure).meshes[0]
	assert_eq(mesh.get_instance_shader_parameter(CharacterView.ENERGY_MIX_PARAM), 0.5)
	_view.set_vanished(true)
	assert_false(_view.model.visible)
	_view.set_vanished(false)
	assert_true(_view.model.visible)


func test_kit_primitives_are_closed_with_smooth_outward_normals() -> void:
	var shapes := _kit_shapes()
	for kind: String in shapes:
		var shape: FigureShape = shapes[kind]
		assert_gt(shape.triangle_count(), 8, "%s has triangles" % kind)
		assert_gt(shape.min_triangle_area(), 1e-9, "%s has no degenerate triangles" % kind)
		var edges := {}
		for t in range(0, shape.indices.size(), 3):
			for k in 3:
				edges[Vector2i(shape.indices[t + k], shape.indices[t + (k + 1) % 3])] = true
		var open := 0
		for edge: Vector2i in edges:
			if not edges.has(Vector2i(edge.y, edge.x)):
				open += 1
		assert_eq(open, 0, "%s is closed and consistently wound" % kind)
		var by_position := {}
		var inward := 0
		for i in shape.vertices.size():
			assert_almost_eq(shape.normals[i].length(), 1.0, 1e-4, "%s normal is unit" % kind)
			var key := Vector3i((shape.vertices[i] * 1e5).round())
			if by_position.has(key):
				assert_almost_eq(shape.normals[i], by_position[key], Vector3.ONE * 1e-5,
					"%s shares one normal per position (smooth)" % kind)
			by_position[key] = shape.normals[i]
		var volume := 0.0
		for t in range(0, shape.indices.size(), 3):
			var a := shape.vertices[shape.indices[t]]
			var b := shape.vertices[shape.indices[t + 1]]
			var c := shape.vertices[shape.indices[t + 2]]
			volume += a.dot(b.cross(c))
			var normal_sum := shape.normals[shape.indices[t]] + shape.normals[shape.indices[t + 1]] \
				+ shape.normals[shape.indices[t + 2]]
			if (b - a).cross(c - a).dot(normal_sum) < 0.0:
				inward += 1
		assert_gt(volume, 0.0, "%s faces outward" % kind)
		# Smoothing bends normals at sharp spikes; most faces must still agree.
		assert_lt(float(inward) / shape.triangle_count(), 0.1, "%s normals agree with its winding" % kind)


func test_kit_primitives_are_deterministic() -> void:
	var first := _kit_shapes()
	var second := _kit_shapes()
	for kind: String in first:
		assert_eq((first[kind] as FigureShape).vertices, (second[kind] as FigureShape).vertices, kind)
		assert_eq((first[kind] as FigureShape).indices, (second[kind] as FigureShape).indices, kind)


func test_the_preview_scene_loads() -> void:
	var preview := (load(PREVIEW_PATH) as PackedScene).instantiate()
	add_child_autofree(preview)
	assert_not_null(preview)
