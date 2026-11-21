extends GutTest
## QA-22: voxel Brann's fist clearance (BrannVoxelView._keep_fist_clear) puts his fists and
## forearms exactly where the golden recorded from the original solver does, frame by frame,
## through every move and guard, unarmed and with each of his weapons.
## SKYBREAK_BLESS_FISTS=1 rewrites the golden from the current solver.

const SCENE := "res://game/characters/brann_voxel/brann_voxel.tscn"
const MOVES := "res://game/combat/moves/brann/"
const GOLDEN := "res://tests/characters/goldens/brann_voxel_fists.json"
const BONES: Array[StringName] = [&"LeftHand", &"RightHand", &"LeftLowerArm", &"RightLowerArm"]
const STATES: Array[FighterState.State] = [FighterState.State.IDLE, FighterState.State.BLOCKING,
	FighterState.State.CHARGING]
const WEAPONS: Array[Weapon.Kind] = [Weapon.Kind.NONE, Weapon.Kind.TITAN_HAMMER, Weapon.Kind.SCATTER_CANNON]
const TOLERANCE := 1e-5


## Every frame's hand and forearm positions (skeleton space, flattened xyz), and the solver's turns.
func _record() -> Dictionary:
	var view := (load(SCENE) as PackedScene).instantiate() as BrannVoxelView
	add_child_autofree(view)
	var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
	var bones: Array[int] = []
	for name in BONES:
		bones.append(skeleton.find_bone(name))
	var moves: Array[MoveData] = []
	var files := Array(DirAccess.get_files_at(MOVES))
	files.sort()
	for file: String in files:
		var move := load(MOVES + file.trim_suffix(".remap")) as MoveData
		if move != null:
			moves.append(move)
	var points := PackedFloat64Array()
	for kind in WEAPONS:
		for state in STATES:
			var fighter := _fighter(kind)
			fighter.enter_state(state)
			fighter.blocking = state == FighterState.State.BLOCKING
			for _f in 30:
				fighter.state_ticks += 1
				await _step(view, fighter, skeleton, bones, points)
		for move in moves:
			var fighter := _fighter(kind)
			fighter.enter_state(FighterState.State.IDLE)
			fighter.begin_move(move)
			while fighter.move_tick < move.total_ticks():
				fighter.state_ticks += 1
				fighter.move_tick += 1
				await _step(view, fighter, skeleton, bones, points)
	return {"points": Array(points), "turns": view.fist_turns}


func _fighter(kind: Weapon.Kind) -> FighterState:
	var fighter := FighterState.new()
	fighter.stats = Roster.character(&"brann").stats
	if kind != Weapon.Kind.NONE:
		fighter.weapons[0] = kind
		fighter.active_slot = 0
	return fighter


func _step(view: BrannVoxelView, fighter: FighterState, skeleton: Skeleton3D, bones: Array[int],
		points: PackedFloat64Array) -> void:
	view.apply_state(fighter, 1.0 / 60.0)
	for bone in bones:
		var at := skeleton.get_bone_global_pose(bone).origin
		points.append_array([at.x, at.y, at.z])
	await get_tree().process_frame


func test_fists_and_forearms_land_where_the_original_solver_put_them() -> void:
	var got: Dictionary = await _record()
	if OS.get_environment("SKYBREAK_BLESS_FISTS") == "1":
		var file := FileAccess.open(GOLDEN, FileAccess.WRITE)
		file.store_string(JSON.stringify(got))
		file.close()
		pending("golden rewritten: %d frames, %d turns" % [got.points.size() / 12, got.turns])
		return
	var want: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	assert_gt(int(want.turns), 100, "the golden exercises the solver (it turned the arm %d times)" % int(want.turns))
	assert_eq(got.points.size(), (want.points as Array).size(), "same number of frames")
	var worst := 0.0
	var where := -1
	for i in mini(got.points.size(), (want.points as Array).size()):
		var d := absf(float(got.points[i]) - float(want.points[i]))
		if d > worst:
			worst = d
			where = i
	gut.p("largest difference %s m over %d frames, %d turns" % [String.num_scientific(worst), got.points.size() / 12, got.turns])
	assert_lt(worst, TOLERANCE, "largest fist or forearm difference %s m (frame %d, %s)" % [String.num_scientific(worst), where / 12,
		BONES[(where % 12) / 3] if where >= 0 else &""])
	assert_eq(int(got.turns), int(want.turns), "the solver turned the arms as often as the original")
