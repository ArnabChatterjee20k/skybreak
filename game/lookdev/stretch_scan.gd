extends SceneTree
## Rig check for a voxel character: poses it in its idle and reports every
## voxel face that stretches more than 3x from rest (a wrong rig tag or weight
## shows up as a long sliver). Headless is fine.
##   godot --headless --path . -s res://game/lookdev/stretch_scan.gd -- --scene=<character scene>
## Prints "stretched kinds 0" when clean; exits 1 otherwise.
func _initialize():
	_go.call_deferred()
func _go():
	var args := LookdevArgs.parse()
	var scene := args.need("scene", "stretch_scan.gd -- --scene=<character scene>")
	if scene == "":
		return
	var view: CharacterView = load(scene).instantiate()
	root.add_child(view)
	var f := FighterState.new()
	f.enter_state(FighterState.State.IDLE)
	for t in 40:
		f.state_ticks += 1
		view.apply_state(f, 1.0 / 60.0)
		await process_frame
	var sk := view.model.get_node("%GeneralSkeleton") as Skeleton3D
	var mi: MeshInstance3D = sk.find_children("*", "MeshInstance3D", false, false)[0]
	var mats := []
	sk.skeleton_updated.connect(func():
		if mats.is_empty():
			for b in sk.get_bone_count():
				mats.append(sk.get_bone_global_pose(b) * sk.get_bone_global_rest(b).affine_inverse()))
	f.state_ticks += 1
	view.apply_state(f, 1.0 / 60.0)
	await process_frame
	await process_frame
	print("captured ", mats.size())
	var found := {}
	for si in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		for fi in verts.size() / 4:
			var posed := []
			for k in 4:
				var v := fi * 4 + k
				var p := Vector3.ZERO
				for j in 4:
					p += (mats[bones[v * 4 + j]] * verts[v]) * ws[v * 4 + j]
				posed.append(p)
			for k in 4:
				var q: Vector3 = posed[k]
				if not q.is_finite() or q.length() > 10.0:
					print("BAD posed vertex ", verts[fi * 4 + k], " -> ", q, " bones ", bones.slice((fi * 4 + k) * 4, (fi * 4 + k) * 4 + 4), " w ", ws.slice((fi * 4 + k) * 4, (fi * 4 + k) * 4 + 4))
			var rest_len := verts[fi * 4].distance_to(verts[fi * 4 + 2])
			var posed_len: float = posed[0].distance_to(posed[2])
			if posed_len > rest_len * 3.0 + 0.01:
				var v := fi * 4
				var desc := ""
				for k in 4:
					var parts := []
					for j in 4:
						if ws[(v + k) * 4 + j] > 0.01:
							parts.append("%s %.2f" % [sk.get_bone_name(bones[(v + k) * 4 + j]), ws[(v + k) * 4 + j]])
					desc += str(parts) + " "
				var key := desc
				if not found.has(key) and found.size() < 12:
					print("rest ", verts[v], " len %.3f -> %.3f :: " % [rest_len, posed_len], desc)
				found[key] = true
	print("stretched kinds ", found.size())
	quit(0 if found.is_empty() else 1)
