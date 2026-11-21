extends SceneTree
## Per legend, classic and voxel: sole depth below the ankle (as QaViewChecks measures it), the
## rest mesh bottom in skeleton space, and the lowest sole over the ground standing (IDLE,
## BLOCKING, CHARGING) after 90 frames. godot --headless --path . -s res://tools/diag/sole_depth.gd

const FEET: Array[StringName] = [&"LeftFoot", &"RightFoot"]


func _init() -> void:
	await process_frame
	for id: StringName in [&"kael", &"vexa", &"lyra", &"brann"]:
		var entry: RosterCharacter = Roster.character(id)
		for style in [ArtStyle.Kind.CLASSIC, ArtStyle.Kind.VOXEL]:
			await _measure(id, entry, style)
	quit()


func _measure(id: StringName, entry: RosterCharacter, style: int) -> void:
	var view: CharacterView = entry.scene_for(style).instantiate()
	root.add_child(view)
	await process_frame
	var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
	var to_skel := skeleton.global_transform.affine_inverse()
	var bottom := INF
	for mesh: MeshInstance3D in view.model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or mesh.skin == null:
			continue
		bottom = minf(bottom, (to_skel * mesh.global_transform * mesh.get_aabb()).position.y)
	var ankle := INF
	for name in FEET:
		ankle = minf(ankle, skeleton.get_bone_global_rest(skeleton.find_bone(name)).origin.y)
	var scale := skeleton.global_basis.get_scale().y
	var sole := (ankle - bottom) * scale
	var line := "%-6s %-7s scale %.4f ankle %.2f cm bottom %+.2f cm sole %.2f cm |" % [id,
		"voxel" if style == ArtStyle.Kind.VOXEL else "classic", scale, ankle * scale * 100.0, bottom * scale * 100.0, sole * 100.0]
	var poses: Array[Transform3D] = []
	skeleton.skeleton_updated.connect(func() -> void:
		poses.resize(skeleton.get_bone_count())
		for b in poses.size():
			poses[b] = skeleton.get_bone_global_pose(b))
	for state: FighterState.State in [FighterState.State.IDLE, FighterState.State.BLOCKING, FighterState.State.CHARGING]:
		var fighter := FighterState.new()
		fighter.stats = entry.stats
		fighter.enter_state(state)
		fighter.blocking = state == FighterState.State.BLOCKING
		var errs: Array[float] = []
		var geo: Array[float] = []
		for f in 90:
			view.apply_state(fighter, 1.0 / 60.0)
			await process_frame
			if f < 30 or poses.is_empty():
				continue
			var ground := view.global_position.y - fighter.stand_height
			var lowest := INF
			for name in FEET:
				var at := skeleton.global_transform * poses[skeleton.find_bone(name)].origin
				lowest = minf(lowest, at.y - sole - ground)
			errs.append(lowest)
			geo.append(view.body.lowest_sole(func(b: int) -> Transform3D: return poses[b], skeleton.global_transform).y - ground)
		line += " %s qa %+.2f..%+.2f geo %+.2f..%+.2f |" % [FighterState.State.find_key(state).substr(0, 5),
			errs.min() * 100.0, errs.max() * 100.0, geo.min() * 100.0, geo.max() * 100.0]
	print(line)
	view.queue_free()
	await process_frame
