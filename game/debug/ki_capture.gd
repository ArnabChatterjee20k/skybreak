extends SceneTree
## Renders key frames of the ki attacks (T-KI1) in the test arena: tap blast,
## charged blast and its reflect, a beam's tell and hit, and a beam clash.
## xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 960x540 \
##     -s res://game/debug/ki_capture.gd -- <out dir>
## Writes <label>.png per key frame; tools build the strip from them.

const A := FighterInput.Action

var _arena: Node
var _held := [0, 0]
var _previous: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]
var _shots: Array[String] = []
var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://ki_capture"
	DirAccess.make_dir_recursive_absolute(_out)
	_arena = load("res://game/levels/test_arena.tscn").instantiate()
	_arena.match_flow.enabled = false
	_arena.sim.pickups_enabled = false
	root.add_child(_arena)
	_arena.set_physics_process(false)
	_arena.set_process(false)
	_arena.get_node("DebugOverlay").visible = false
	_arena.input_override = _input
	await process_frame
	if not _arena.vfx_prewarm.is_finished:
		await _arena.vfx_prewarm.finished
	var sim: CombatSim = _arena.sim
	_place(16.0)
	# Tap blast: muzzle flash, flight, impact.
	await _press(A.KI_BLAST, 0)
	await _run_ticks(12, {7: "1_tap_muzzle", 10: "2_tap_flight"})
	await _run_until(func() -> bool: return sim.projectiles.is_empty(), 40, "3_tap_impact", 1)
	await _run_ticks(40)
	_place(16.0)
	# Charged blast: hold Q, the orb swells; the defender perfect-blocks it back.
	_held[0] = A.KI_BLAST
	await _run_ticks(23, {14: "4_charge_orb"})
	_held[0] = 0
	await _run_ticks(4, {3: "5_charged_flight"})
	await _run_until(func() -> bool: return _reflected(sim), 40, "6_reflect", 1)
	await _run_ticks(4, {3: "7_reflect_return"})
	await _run_ticks(70)
	_place(22.0)
	sim.fighters[0].ki = 100 * FighterState.METER_UNIT
	# Beam: the tell at the hands, then the beam.
	await _press(A.SPECIAL_1, 0)
	await _run_ticks(40, {12: "8_beam_tell", 27: "9_beam_fire", 29: "9b_beam_side", 33: "10_beam_hit"})
	await _run_ticks(120)
	_place(26.0)
	for fighter in sim.fighters:
		fighter.ki = 100 * FighterState.METER_UNIT
		fighter.health = fighter.stats.max_health * FighterState.METER_UNIT
	# Beam clash: fighter 1 plays the beats, fighter 0 does not.
	_held = [A.SPECIAL_1, A.SPECIAL_1]
	await _run_ticks(1)
	_held = [0, 0]
	await _run_until(func() -> bool: return not sim.beam_clashes.is_empty(), 60, "11_clash_start", 2)
	await _run_ticks(70, {40: "12b_clash_side", 60: "12_clash_beats"}, true)
	await _run_until(func() -> bool: return sim.beam_clashes.is_empty(), 200, "13_clash_end", 3, true)
	await _run_ticks(12, {10: "14_clash_aftermath"})
	print("[ki] wrote %d frames to %s: %s" % [_shots.size(), _out, ", ".join(_shots)])
	quit()


func _place(gap: float) -> void:
	var sim: CombatSim = _arena.sim
	for i in 2:
		var fighter := sim.fighters[i]
		fighter.position = Vector3(0, sim.tuning.ground_height + 1.0, gap * 0.5 * (1 if i == 0 else -1))
		fighter.velocity = Vector3.ZERO
		fighter.ki = 100 * FighterState.METER_UNIT
		fighter.enter_state(FighterState.State.IDLE)
		fighter.facing_yaw = 0.0 if i == 0 else PI
	sim.lock_everyone_onto_nearest()


func _input(index: int, _tick: int) -> FighterInput:
	var input := FighterInput.from_held(_held[index], _previous[index])
	_previous[index] = input
	return input


func _press(action: int, index: int) -> void:
	_held[index] = action
	await _step()
	_held[index] = 0


func _reflected(sim: CombatSim) -> bool:
	for event in sim.events:
		if event.type == CombatSim.EventType.PROJECTILE_HIT and event.reflected:
			return true
	# Times the perfect block: press when the charged blast is about 4 ticks out.
	for projectile in sim.projectiles:
		if projectile.ki == KiRules.Shot.CHARGED and projectile.owner == 0:
			var gap := projectile.position.distance_to(sim.fighters[1].position)
			_held[1] = A.BLOCK if gap < projectile.velocity.length() * 5.0 / 60.0 else 0
	return false


func _run_ticks(ticks: int, shots := {}, clash_beats := false) -> void:
	for t in ticks:
		if clash_beats:
			_play_beats()
		await _step()
		if shots.has(t):
			await _shoot(shots[t])


func _run_until(done: Callable, limit: int, label: String, after: int, clash_beats := false) -> void:
	for _t in limit:
		if clash_beats:
			_play_beats()
		await _step()
		if done.call():
			break
	for _t in after:
		await _step()
	await _shoot(label)


func _play_beats() -> void:
	var sim: CombatSim = _arena.sim
	_held[1] = 0
	for clash in sim.beam_clashes:
		for k in clash.beat_ticks.size():
			if clash.beat_ticks[k] == sim.current_tick:
				_held[1] = clash.beat_buttons[k]


func _step() -> void:
	_arena.step_tick()
	_arena.present_frame(1.0, 1.0 / 60.0)
	await process_frame


func _shoot(label: String) -> void:
	var side: Camera3D = null
	if label.ends_with("_side"):
		# From the side, so the beam's length and thickness read; the fight camera is untouched.
		var sim: CombatSim = _arena.sim
		var mid := (sim.fighters[0].position + sim.fighters[1].position) * 0.5
		side = Camera3D.new()
		_arena.add_child(side)
		side.global_position = mid + Vector3(22, 6, 0)
		side.look_at(mid, Vector3.UP)
		side.current = true
	await process_frame
	var image := root.get_texture().get_image()
	image.resize(480, 270, Image.INTERPOLATE_LANCZOS)
	image.save_png("%s/%s.png" % [_out, label])
	_shots.append(label)
	if side != null:
		(_arena.camera as Camera3D).current = true
		side.queue_free()
