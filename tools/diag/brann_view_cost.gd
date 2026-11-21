extends SceneTree
## Per-frame cost of a legend's view.apply_state, through guard, idle,
## charge and every move, unarmed and armed. QA-22.
##   godot --headless --path . -s res://tools/diag/brann_view_cost.gd [-- brann|kael|... voxel|classic]

const STATES: Array[FighterState.State] = [FighterState.State.IDLE, FighterState.State.BLOCKING,
	FighterState.State.CHARGING]


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	var id := StringName(args[0]) if args.size() > 0 else &"brann"
	var style := ArtStyle.Kind.CLASSIC if args.size() > 1 and args[1] == "classic" else ArtStyle.Kind.VOXEL
	var entry: RosterCharacter = Roster.character(id)
	var view: CharacterView = entry.scene_for(style).instantiate()
	root.add_child(view)
	var skeleton: Skeleton3D = view.model.get_node("%GeneralSkeleton")
	var dir := "res://game/combat/moves/%s/" % id
	var moves: Array[MoveData] = []
	for file in DirAccess.get_files_at(dir):
		var move := load(dir + file.trim_suffix(".remap")) as MoveData
		if move != null:
			moves.append(move)
	var times: Array[float] = []
	for round_index in 3:
		for kind: int in [0, Weapon.Kind.TITAN_HAMMER]:
			for state in STATES:
				var fighter := _fighter(entry, kind)
				fighter.enter_state(state)
				fighter.blocking = state == FighterState.State.BLOCKING
				for _f in 30:
					fighter.state_ticks += 1
					times.append(await _step(view, skeleton, fighter))
			for move in moves:
				var fighter := _fighter(entry, kind)
				fighter.enter_state(FighterState.State.IDLE)
				fighter.begin_move(move)
				while fighter.move_tick < move.total_ticks():
					fighter.state_ticks += 1
					fighter.move_tick += 1
					times.append(await _step(view, skeleton, fighter))
	times = times.slice(times.size() / 3)
	times.sort()
	var total := 0.0
	for t in times:
		total += t
	print("view_cost %s %s: %d frames, mean %.3f ms, p50 %.3f, p95 %.3f" % [id, ArtStyle.NAMES[style], times.size(),
		total / times.size(), times[times.size() / 2], times[int(times.size() * 0.95)]])
	quit()


func _fighter(entry: RosterCharacter, kind: int) -> FighterState:
	var fighter := FighterState.new()
	fighter.stats = entry.stats
	if kind != 0:
		fighter.weapons[0] = kind
		fighter.active_slot = 0
	return fighter


## One frame's apply_state, in ms (the skeleton modifiers run after, in the frame).
func _step(view: CharacterView, skeleton: Skeleton3D, fighter: FighterState) -> float:
	var start := Time.get_ticks_usec()
	view.apply_state(fighter, 1.0 / 60.0)
	var spent := (Time.get_ticks_usec() - start) / 1000.0
	await process_frame
	return spent
