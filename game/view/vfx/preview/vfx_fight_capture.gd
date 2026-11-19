extends SceneTree
## Captures 8 frames of a seeded WeaponBot fight in the test arena, a few ticks after
## the most spectacular VFX moments (KO, guard break, heavies, landings, swings).
## Two runs: `-- <out dir>` prints the moments, `-- <out dir> <t1,t2,...>` renders them.
## godot --path . --rendering-method gl_compatibility --resolution 1280x720 -s res://game/view/vfx/preview/vfx_fight_capture.gd -- <out dir>

const SEED := 11
const TICKS := 3600
const FRAMES := 8
## Ticks after the moment that the frame is taken, so effects are mid-flight.
const DELAY := 3
const ZONE := &"heartbloom_gardens"
const E := CombatSim.EventType

var _out_dir := "."
## Ticks to capture, from a previous scan run; empty = scan and print them.
var _picks: Array[int] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out_dir = args[0]
	if args.size() > 1:
		for part in args[1].split(","):
			_picks.append(int(part))
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run.call_deferred()


func _moments() -> Array[int]:
	# Pass one over the same deterministic arena fight: rank ticks by how much VFX they show.
	var arena := _new_arena()
	var sim: CombatSim = arena.sim
	var scored: Array = []
	for tick in TICKS:
		arena.step_tick()
		var score := 0
		for event in sim.events:
			score += {E.KO: 100, E.GUARD_BREAK: 60, E.COUNTER: 40}.get(event.type, 0)
			if event.type == E.HIT and event.hitstop >= MatchVfx.HEAVY_HITSTOP:
				score += 30
		for fighter in sim.fighters:
			if fighter.attack_phase() == FighterState.AttackPhase.ACTIVE and fighter.move_tick == fighter.move.startup_ticks \
					and MatchVfx.smear_for(fighter.held_weapon(), fighter.move_id()) != &"":
				score += 15
			if fighter.state == FighterState.State.DASHING and fighter.state_ticks == 3:
				score += 10
		if score > 0:
			scored.append([score, tick])
		if sim.round_over:
			break
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var picks: Array[int] = []
	for entry: Array in scored:
		var tick: int = entry[1]
		if picks.all(func(t: int) -> bool: return absi(t - tick) > 30):
			picks.append(tick)
		if picks.size() == FRAMES:
			break
	picks.sort()
	print("moments ", ",".join(picks.map(func(t: int) -> String: return str(t))))
	return picks


func _new_arena() -> Node:
	var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.set_process(false)
	arena.match_flow.enabled = false
	arena.sim.zone = ZONE
	var bots := _bots()
	arena.input_override = func(index: int, _tick: int) -> FighterInput: return bots[index].next_input(arena.sim)
	arena.combat_feedback.vfx.process_mode = Node.PROCESS_MODE_DISABLED
	return arena


func _run() -> void:
	if _picks.is_empty():
		# Scan pass: one arena per process (two arenas overrun GLES3's instance-uniform buffer).
		_moments()
		quit()
		return
	var picks := _picks
	# Software GL draws ~8 fps here, so the effects are pinned to sim time (disabled processing).
	var arena := _new_arena()
	var vfx: MatchVfx = arena.combat_feedback.vfx
	for i in 6:
		await process_frame
	var shot := 0
	for tick in TICKS:
		var near := picks.any(func(t: int) -> bool: return tick >= t - 10 and tick <= t + DELAY)
		arena.step_tick()
		vfx.advance(CombatSim.TICK_SECONDS)
		if near:
			arena.present_frame(1.0, CombatSim.TICK_SECONDS)
			vfx.follow_fighters()
			await process_frame
		if shot < picks.size() and tick == picks[shot] + DELAY:
			var image := root.get_texture().get_image()
			var path := _out_dir.path_join("fight_%d_tick%04d.png" % [shot, tick])
			image.save_png(path)
			print("wrote ", path)
			shot += 1
		if shot >= picks.size():
			break
	quit()


func _bots() -> Array[WeaponBot]:
	return [WeaponBot.new(0, SEED * 3 + 1), WeaponBot.new(1, SEED * 3 + 2)]
