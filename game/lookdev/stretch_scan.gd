extends SceneTree
## Rig check for a voxel character: poses it and reports every voxel face that
## stretches more than 3x from rest (a wrong rig tag or weight shows up as a
## long sliver). Scans idle, guard, flight and hitstun, and with --moves every
## move's startup, active and recovery frames. Headless is fine.
##   godot --headless --path . -s res://game/lookdev/stretch_scan.gd -- --scene=<character scene>
##       [--moves=res://game/combat/moves/<name>/]
## Prints "stretched kinds 0" when clean; exits 1 otherwise.

const S := FighterState.State

var _view: CharacterView
var _skeleton: Skeleton3D
var _mesh: MeshInstance3D
var _fighter := FighterState.new()
var _found := {}


func _initialize():
	_go.call_deferred()


func _go():
	var args := LookdevArgs.parse()
	var scene := args.need("scene", "stretch_scan.gd -- --scene=<character scene> [--moves=<move dir/>]")
	if scene == "":
		return
	_view = load(scene).instantiate()
	root.add_child(_view)
	_skeleton = _view.model.get_node("%GeneralSkeleton") as Skeleton3D
	_mesh = _skeleton.find_children("*", "MeshInstance3D", false, false)[0]
	for state: S in [S.IDLE, S.BLOCKING, S.FLYING, S.HITSTUN]:
		_fighter.enter_state(state)
		await _advance(40)
		await _scan(S.keys()[state].to_lower())
	var moves := args.get_option("moves")
	if moves != "":
		for file in DirAccess.get_files_at(moves):
			if not file.ends_with(".tres"):
				continue
			var move := load(moves.path_join(file)) as MoveData
			if move == null:
				continue
			_fighter.enter_state(S.IDLE)
			await _advance(10)
			_fighter.begin_move(move)
			var marks := [move.startup_ticks / 2, move.startup_ticks, move.startup_ticks + move.active_ticks / 2,
				move.recovery_start_tick(), move.total_ticks() - 2]
			for tick in move.total_ticks():
				_fighter.move_tick = tick
				await _advance(1)
				if tick in marks:
					await _scan("%s@%d" % [move.id, tick])
	print("stretched kinds ", _found.size())
	quit(0 if _found.is_empty() else 1)


func _advance(ticks: int) -> void:
	for t in ticks:
		_fighter.state_ticks += 1
		_view.apply_state(_fighter, 1.0 / 60.0)
		await process_frame


## Checks every face against the skeleton's pose on its next update.
func _scan(label: String) -> void:
	var mats := []
	var grab := func():
		if mats.is_empty():
			for b in _skeleton.get_bone_count():
				mats.append(_skeleton.get_bone_global_pose(b) * _skeleton.get_bone_global_rest(b).affine_inverse())
	_skeleton.skeleton_updated.connect(grab)
	_fighter.state_ticks += 1
	_view.apply_state(_fighter, 1.0 / 60.0)
	await process_frame
	await process_frame
	_skeleton.skeleton_updated.disconnect(grab)
	var before := _found.size()
	for si in _mesh.mesh.get_surface_count():
		var arr: Array = _mesh.mesh.surface_get_arrays(si)
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
					print("BAD posed vertex ", verts[fi * 4 + k], " -> ", q)
			var rest_len := verts[fi * 4].distance_to(verts[fi * 4 + 2])
			var posed_len: float = posed[0].distance_to(posed[2])
			if posed_len > rest_len * 3.0 + 0.01:
				var v := fi * 4
				var desc := ""
				for k in 4:
					var parts := []
					for j in 4:
						if ws[(v + k) * 4 + j] > 0.01:
							parts.append("%s %.2f" % [_skeleton.get_bone_name(bones[(v + k) * 4 + j]), ws[(v + k) * 4 + j]])
					desc += str(parts) + " "
				if not _found.has(desc) and _found.size() < 12:
					print(label, ": rest ", verts[v], " len %.3f -> %.3f :: " % [rest_len, posed_len], desc)
				_found[desc] = true
	print("%s: %s" % [label, "clean" if _found.size() == before else "%d new stretched kinds" % (_found.size() - before)])
