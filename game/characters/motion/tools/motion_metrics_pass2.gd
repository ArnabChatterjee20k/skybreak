extends "res://game/characters/motion/tools/motion_metrics.gd"
## T-D22c realism metrics for all four legends, measured on the clips CharacterView actually plays
## (whatever the branch maps: posed, mocap, fitted or derived), so the same script run on two
## commits gives an old-vs-new table. Also counts live pops (a body bone turning more than 1.2 rad
## in one frame) in two 3600-tick bot matches with the views and their layers running.
##   godot --headless --path . -s res://game/characters/motion/tools/motion_metrics_pass2.gd

const LEGENDS := {
	"kael": ["res://game/characters/kael_chunky/kael_chunky.tscn", "res://game/combat/moves/kael/kael_move_set.tres"],
	"vexa": ["res://game/characters/vexa/vexa.tscn", "res://game/combat/moves/vexa/vexa_move_set.tres"],
	"lyra": ["res://game/characters/lyra/lyra.tscn", "res://game/combat/moves/lyra/lyra_move_set.tres"],
	"brann": ["res://game/characters/brann/brann.tscn", "res://game/combat/moves/brann/brann_move_set.tres"],
}
const STRIKES := ["light_1", "light_2", "light_3", "smash", "launcher", "sweep", "spike", "breaker", "rising", "grab"]
const POP_ANGLE := 1.2
const STYLE_SCRIPTS := {"vexa": "VexaMoveClips", "lyra": "LyraMoveClips", "brann": "BrannMoveClips"}

var _ran := false


func _initialize() -> void:
	pass


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	for who: String in LEGENDS:
		_legend(who)
	for pair: Array in [["kael", "vexa"], ["lyra", "brann"]]:
		var result := _live_pops(pair)
		print("LIVE %s-%s pops=%d worst=%.3f" % [pair[0], pair[1], result.x, result.y])
	quit(0)
	return true


func _legend(who: String) -> void:
	var view := (load(LEGENDS[who][0]) as PackedScene).instantiate() as CharacterView
	root.add_child(view)
	view.set_process(false)
	var skeleton := view.model.get_node("%GeneralSkeleton") as Skeleton3D
	if view.layers:
		view.layers.active = false
	var set := load(LEGENDS[who][1]) as MoveSet
	var moves := {}
	for move in VexaMoveClips.moves_of(set):
		moves[String(move.id)] = move
	var rows := [["idle", _state_fighter(FighterState.State.IDLE, Vector3.ZERO, 0, 0)],
		["run", _state_fighter(FighterState.State.MOVING, Vector3(0, 0, -9), 10, 0)]]
	for id: String in STRIKES:
		if moves.has(id):
			var f := FighterState.new()
			f.begin_move(moves[id])
			rows.append([id, f])
	var hit := _state_fighter(FighterState.State.HITSTUN, Vector3.ZERO, 0, 36)
	hit.knockback_type = MoveData.KnockbackType.BLOWBACK
	rows.append(["heavy hit", hit])
	rows.append(["KO fall", _state_fighter(FighterState.State.KNOCKDOWN, Vector3.ZERO, 0, 100)])
	rows.append(["get up", _state_fighter(FighterState.State.KNOCKDOWN, Vector3.ZERO, 70, 30)])
	for row: Array in rows:
		var fighter: FighterState = row[1]
		view.apply_state(fighter, 1.0 / 60.0)
		var clip := view.current_clip()
		var motion := view.is_playing_motion()
		var library: AnimationLibrary = view._motion if motion else view.clips.library
		var character := {"player": null, "skeleton": skeleton, "library": library}
		var m := _measure(character, String(clip), row[0] == "run", motion, String(row[0]))
		var phases := "–"
		if moves.has(row[0]):
			var p := _legend_phases(who, skeleton, library.get_animation(clip), moves[row[0]])
			phases = "%d/%d" % [p.x, p.y]
		print("ROW %s|%s|%s|%.1f|%d|%.0f|%.1f|%.1f|%s" % [who, row[0], clip, m["slide"], m["pops"], m["jerk"],
			m["com"], m["bob"], phases])
	view.queue_free()


func _state_fighter(state: FighterState.State, velocity: Vector3, ticks: int, stun: int) -> FighterState:
	var f := FighterState.new()
	f.state = state
	f.velocity = velocity
	f.state_ticks = ticks
	f.stun_ticks = stun
	return f


## Anticipation and follow-through of the legend's own strike limb toward its own hitbox.
func _legend_phases(who: String, skeleton: Skeleton3D, animation: Animation, move: MoveData) -> Vector2i:
	var bone := _strike_bone(who, move.id)
	var target := VexaMoveClips.strike_point(move)
	var frames := int(round(animation.length / DT)) + 1
	var points: Array[Vector3] = []
	for f in frames:
		apply_clip(skeleton, animation, minf(f * DT, animation.length))
		points.append(_global_pose(skeleton, skeleton.find_bone(bone)).origin)
	var anticipation := 0
	var top := 0.0
	var peak := 0
	var best := INF
	for f in frames:
		var d := points[f].distance_to(target)
		if d < best:
			best = d
			peak = f
		if f > 0:
			top = maxf(top, (points[f] - points[f - 1]).length())
			if f <= move.startup_ticks and d > points[f - 1].distance_to(target) + 0.002:
				anticipation += 1
	var follow := 0
	for f in range(peak + 1, frames):
		if (points[f] - points[f - 1]).length() < top * 0.15:
			break
		follow += 1
	return Vector2i(anticipation, follow)


func _strike_bone(who: String, id: StringName) -> StringName:
	if who == "kael":
		return {&"light_1": &"LeftHand", &"light_3": &"LeftHand", &"breaker": &"LeftHand", &"sweep": &"RightFoot",
			&"rising": &"RightFoot", &"spike": &"RightFoot"}.get(id, &"RightHand")
	var styles: Dictionary = {"vexa": VexaMoveClips.STYLES, "lyra": LyraMoveClips.STYLES, "brann": BrannMoveClips.STYLES}[who]
	var limb: StringName = (styles.get(id, {"limb": &"RightHand"}) as Dictionary).limb
	return &"RightHand" if limb == &"BothHands" else limb


## Live pops over a 3600-tick bot match (frames where any body bone turns more than POP_ANGLE).
func _live_pops(pair: Array) -> Vector2:
	var sim := CombatSim.new(7)
	var views: Array[CharacterView] = []
	var bots: Array[WeaponBot] = []
	for i in 2:
		var view := (load(LEGENDS[pair[i]][0]) as PackedScene).instantiate() as CharacterView
		root.add_child(view)
		view.set_process(false)
		views.append(view)
		sim.add_fighter(Vector3(i * 6.0 - 3.0, 1.0, 0))
		bots.append(WeaponBot.new(i, 11 + i))
	sim.pickups_enabled = true
	sim.lock_everyone_onto_nearest()
	var previous: Array = [[], []]
	var pops := 0
	var worst := 0.0
	for tick in 3600:
		sim.tick([bots[0].next_input(sim), bots[1].next_input(sim)] as Array[FighterInput])
		for i in 2:
			var view := views[i]
			for event: Dictionary in sim.events:
				if event.get("target", -1) == i:
					view.react_to_event(event, sim.fighters[i])
			view.set_look_target(sim.fighters[1 - i].position)
			view.apply_state(sim.fighters[i], DT)
			if view.layers:
				view.layers._process_modification_with_delta(DT)
			var skeleton := view.model.get_node("%GeneralSkeleton") as Skeleton3D
			var now: Array[Quaternion] = []
			for bone: StringName in BODY:
				now.append(_global_pose(skeleton, skeleton.find_bone(bone)).basis.get_rotation_quaternion())
			if not (previous[i] as Array).is_empty() and sim.fighters[i].hitstop_ticks == 0:
				var frame := 0.0
				for b in now.size():
					frame = maxf(frame, (previous[i][b] as Quaternion).angle_to(now[b]))
				worst = maxf(worst, frame)
				if frame > POP_ANGLE:
					pops += 1
			previous[i] = now
	for view in views:
		view.queue_free()
	return Vector2(pops, worst)
