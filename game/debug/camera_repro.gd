extends SceneTree
## Camera repros for the art critic's #134 (Mesa cliff) and #136 (small duel
## fighters), mirroring tools/qa/art_shots.gd on claude/art-bible (seed 7).
## godot --headless --path . -s res://game/debug/camera_repro.gd -- [mesa|clip|all]

const SEED := 7
const CLOSE_GAP := 2.6
const SETTLE_TICKS := 90


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var which: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "all"
	if which in ["mesa", "all"]:
		await _mesa()
	if which in ["clip", "all"]:
		await _clip()
	if which == "qa":
		await _qa_frame()
	quit()


func _level(zone: StringName, legends: Array, flow: bool, ai: bool) -> ZoneMatch:
	var fighters := []
	for i in legends.size():
		fighters.append({"character": legends[i], "team": i, "is_ai": ai, "ai_level": 3})
	var level: ZoneMatch = load("res://game/levels/zone_match.tscn").instantiate()
	level.sim.rng.seed = SEED
	level.configure({"zone": zone, "fighters": fighters, "rounds": 3})
	root.add_child(level)
	level.set_process(false)
	level.set_physics_process(false)
	level.match_flow.enabled = flow
	if not ai:
		level.input_override = func(_slot: int, _tick: int) -> FighterInput: return FighterInput.new()
	await process_frame
	return level


func _place(level: ZoneMatch, gap: float) -> void:
	var sim := level.sim
	var a := sim.fighters[0].position
	var b := sim.fighters[1].position
	var dir := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var stand := sim.tuning.ground_height
	var p1 := a + dir * gap
	p1.y = level.ground.height_at(p1.x, p1.z, INF) + stand
	sim.fighters[1].position = p1
	for f in sim.fighters:
		f.velocity = Vector3.ZERO


func _step(level: ZoneMatch, ticks: int) -> void:
	for t in ticks:
		level.step_tick()
		level.present_frame(1.0, 1.0 / 60.0)


func _report(name: String, level: ZoneMatch) -> String:
	var camera: FighterCamera = level.camera
	var view := camera.global_transform
	var obstacles := CameraObstacles.from_zone_match(level)
	var cover := CameraQaMetrics.terrain_cover(view, camera.fov, obstacles, level)
	var h0 := CameraQaMetrics.screen_height(view, camera.fov, level.fighter_views[0].position)
	var h1 := CameraQaMetrics.screen_height(view, camera.fov, level.fighter_views[1].position)
	return "%s: terrain %.0f%% | heights %.1f%% / %.1f%% | cam-player %.1f m | pitch %.0f | fov %.0f" % [name,
		cover * 100.0, h0 * 100.0, h1 * 100.0, view.origin.distance_to(level.fighter_views[0].position),
		rad_to_deg(asin(clampf(-view.basis.z.y, -1, 1))), camera.fov]


func _mesa() -> void:
	for legend in [&"kael", &"vexa", &"lyra"]:
		var level := await _level(&"shattered_mesa", [legend, &"brann"], false, false)
		_step(level, 2)
		_place(level, CLOSE_GAP)
		_step(level, SETTLE_TICKS)
		print(_report("mesa %s close" % legend, level))
		await _save(level, "mesa_%s" % legend)
		level.free()


func _clip() -> void:
	var level := await _level(&"frozen_peaks", [&"vexa", &"brann"], true, true)
	_step(level, 240)
	var heights: Array[float] = []
	var covers: Array[float] = []
	var obstacles := CameraObstacles.from_zone_match(level)
	for frame in 600:
		_step(level, 1)
		var view := level.camera.global_transform
		heights.append(CameraQaMetrics.screen_height(view, level.camera.fov, level.fighter_views[0].position))
		covers.append(CameraQaMetrics.terrain_cover(view, level.camera.fov, obstacles, level))
		if frame % 100 == 0:
			print(_report("clip f%d" % frame, level))
			await _save(level, "clip_%03d" % frame)
	heights.sort()
	covers.sort()
	print("clip: player height median %.1f%%, terrain cover median %.0f%% p90 %.0f%%" % [
		heights[heights.size() / 2] * 100.0, covers[covers.size() / 2] * 100.0, covers[int(covers.size() * 0.9)] * 100.0])
	level.free()


## Saves the current frame when rendering (not headless) and SHOT_DIR is set.
func _save(level: ZoneMatch, name: String) -> void:
	var out := OS.get_environment("SHOT_DIR")
	if out == "" or DisplayServer.get_name() == "headless":
		return
	level.present_frame(1.0, 1.0 / 60.0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


## camera_qa's ffa4_frozen config (seed 3, AI 3) rendered at QA_TICKS (comma list).
func _qa_frame() -> void:
	var fighters := []
	var legends: Array = Array(OS.get_environment("QA_LEGENDS").split(",")).map(func(x): return StringName(x)) 		if OS.get_environment("QA_LEGENDS") != "" else [&"vexa", &"lyra", &"kael", &"brann"]
	for i in legends.size():
		fighters.append({"character": legends[i], "team": i, "is_ai": true, "ai_level": 3})
	var level: ZoneMatch = load("res://game/levels/zone_match.tscn").instantiate()
	level.configure({"zone": StringName(OS.get_environment("QA_ZONE")) if OS.get_environment("QA_ZONE") != "" else &"frozen_peaks", "fighters": fighters})
	level.sim.rng.seed = int(OS.get_environment("QA_SEED")) if OS.get_environment("QA_SEED") != "" else 3
	root.add_child(level)
	level.set_physics_process(false)
	level.set_process(false)
	await process_frame
	if not level.vfx_prewarm.is_finished:
		await level.vfx_prewarm.finished
	var wanted := Array(OS.get_environment("QA_TICKS").split(",")).map(func(x): return int(x))
	for t in wanted.max() + 1:
		level.step_tick()
		level.present_frame(1.0, 1.0 / 60.0)
		if OS.get_environment("QA_SCAN") != "" and level.camera.has_method("exchange_weight") and t % 30 == 0:
			print("scan t%d xw=%.2f" % [t, level.camera.exchange_weight()])
		if t in wanted:
			print(_report("qa t%d" % t, level))
			await _save(level, "qa_t%d" % t)
	level.free()
