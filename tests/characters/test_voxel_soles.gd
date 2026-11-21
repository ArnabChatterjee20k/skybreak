extends GutTest
## QA-24: every legend's rest soles meet the floor its clips are authored on, in both art
## styles, so the voxel boots no longer sink below the ground the classic ones stand on.

const LEGENDS: Array[StringName] = [&"kael", &"vexa", &"lyra", &"brann"]
## Classic Vexa's mesh reaches 0.5 mm below its rig's floor; everything else sits on it.
const TOLERANCE := 0.001


## The lowest point of the skinned rest meshes, in the view's space (its floor is at -1).
func _rest_bottom(view: CharacterView) -> float:
	var bottom := INF
	for mesh: MeshInstance3D in view.model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or mesh.skin == null:
			continue
		bottom = minf(bottom, (view.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()).position.y)
	return bottom


## Lowest sole over the floor as QaViewChecks measures it (posed ankle minus the rest sole
## depth), after 40 frames in a state (m).
func _standing_gap(view: CharacterView, state: FighterState.State) -> float:
	var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
	var to_skeleton := skeleton.global_transform.affine_inverse() * view.global_transform
	var feet: Array[int] = [skeleton.find_bone(&"LeftFoot"), skeleton.find_bone(&"RightFoot")]
	var ankle := INF
	for bone in feet:
		ankle = minf(ankle, skeleton.get_bone_global_rest(bone).origin.y)
	var sole := ankle - (to_skeleton * Vector3(0, _rest_bottom(view), 0)).y
	var fighter := FighterState.new()
	fighter.enter_state(state)
	for _f in 40:
		view.apply_state(fighter, 1.0 / 60.0)
		await get_tree().process_frame
	var lowest := INF
	for bone in feet:
		var at := view.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
		lowest = minf(lowest, at.y - sole + fighter.stand_height)
	return lowest


func _view(id: StringName, style: ArtStyle.Kind) -> CharacterView:
	var view: CharacterView = Roster.character(id).scene_for(style).instantiate()
	add_child_autofree(view)
	return view


func test_every_legends_rest_soles_meet_the_floor_in_both_art_styles() -> void:
	for id in LEGENDS:
		for style: ArtStyle.Kind in [ArtStyle.Kind.CLASSIC, ArtStyle.Kind.VOXEL]:
			var bottom := _rest_bottom(_view(id, style))
			assert_almost_eq(bottom, -1.0, TOLERANCE, "%s %s: rest soles at %+.2f cm from the floor" % [id,
				ArtStyle.NAMES[style], (bottom + 1.0) * 100.0])


func test_voxel_kael_and_brann_stand_on_the_floor_like_their_classic_models() -> void:
	# Same rig and clips as the classic model, so the same gap (charging holds still).
	for id: StringName in [&"kael", &"brann"]:
		var classic: float = await _standing_gap(_view(id, ArtStyle.Kind.CLASSIC), FighterState.State.CHARGING)
		var voxel: float = await _standing_gap(_view(id, ArtStyle.Kind.VOXEL), FighterState.State.CHARGING)
		assert_almost_eq(voxel, classic, TOLERANCE, "%s lowest sole over the floor: voxel %+.2f cm, classic %+.2f cm" % [
			id, voxel * 100.0, classic * 100.0])
