extends SceneTree
## Art-direction stills (T-ART3): the look mockup's frozen moments (Heartbloom and Ember Rift,
## hit and beam) and every zone, at a close anime-arena framing (fighters ~30% of the height)
## and a side-on exchange framing (~38%). The camera here is a stand-in for review only.
##   godot --path . --resolution 1280x720 -s res://game/view/shaders/preview/look_capture.gd -- <out dir> [moments|zones]

const SEED := 7
const CLOSE_GAP := 1.8
const BEAM_GAP := 10.0
const LEGENDS: Array[StringName] = [&"kael", &"vexa"]

var _out := "user://look"
var _script: Dictionary = {}
var _camera: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else _out
	var only := args[1] if args.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(_out)
	if only == "" or only == "moments":
		for zone: StringName in [&"heartbloom_gardens", &"ember_rift"]:
			await _hit(zone)
			await _beam(zone)
	if only == "" or only == "zones":
		for zone: StringName in ZoneLayout.ZONE_IDS:
			await _zone(zone)
	print("[look] done")
	quit()


func _level(zone: StringName) -> ZoneMatch:
	var fighters := []
	for i in LEGENDS.size():
		fighters.append({"character": LEGENDS[i], "team": i, "is_ai": false})
	var level: ZoneMatch = load("res://game/levels/zone_match.tscn").instantiate()
	level.sim.rng.seed = SEED
	level.configure({"zone": zone, "fighters": fighters, "rounds": 3})
	root.add_child(level)
	level.set_process(false)
	level.set_physics_process(false)
	level.match_flow.enabled = false
	level.sim.pickups_enabled = false
	for layer: CanvasLayer in level.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	_script = {}
	level.input_override = func(slot: int, tick: int) -> FighterInput:
		var input := FighterInput.new()
		var mask: int = _script.get("%d:%d" % [slot, tick], 0)
		input.held_actions = mask
		input.pressed_actions = mask
		return input
	await process_frame
	if not level.vfx_prewarm.is_finished:
		await level.vfx_prewarm.finished
	for particles in level.world.atmosphere.weather.values():
		(particles as GPUParticles3D).speed_scale = 1.0
	_camera = Camera3D.new()
	root.add_child(_camera)
	return level


func _place(level: ZoneMatch, gap: float) -> void:
	var sim := level.sim
	var a := sim.fighters[0].position
	var b := sim.fighters[1].position
	var dir := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	if dir == Vector3.ZERO:
		dir = Vector3.FORWARD
	var stand := sim.tuning.ground_height
	var p1 := a + dir * gap
	p1.y = level.ground.height_at(p1.x, p1.z, INF) + stand
	a.y = level.ground.height_at(a.x, a.z, INF) + stand
	sim.fighters[0].position = a
	sim.fighters[1].position = p1
	for f in sim.fighters:
		f.velocity = Vector3.ZERO
	sim.fighters[0].facing_yaw = atan2(-dir.x, -dir.z)
	sim.fighters[1].facing_yaw = atan2(dir.x, dir.z)


func _step(level: ZoneMatch, ticks: int) -> void:
	for t in ticks:
		level.step_tick()
		level.present_frame(1.0, 1.0 / 60.0)
		await process_frame


## Over-shoulder anime-arena camera behind fighter 0 (B framing), or side-on (D framing).
func _frame(level: ZoneMatch, side_on: bool) -> void:
	var a := level.sim.fighters[0].position
	var b := level.sim.fighters[1].position
	var line := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var right := line.cross(Vector3.UP).normalized()
	var mid := (a + b) * 0.5
	if side_on:
		_camera.fov = 30.0
		var span := maxf(a.distance_to(b), 2.0)
		var dist := maxf(7.5, span * 1.6)
		_camera.global_position = mid - right * dist + Vector3.UP * 0.6
		_camera.look_at(mid + Vector3.UP * 0.1, Vector3.UP)
	else:
		_camera.fov = 50.0
		_camera.global_position = a - line * 3.4 + right * 1.6 + Vector3.UP * 1.0
		_camera.look_at(lerp(a, b, 0.45) + Vector3.UP * 0.2, Vector3.UP)
	_camera.make_current()


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("[look] ", name)


func _free(level: Node) -> void:
	level.queue_free()
	_camera.queue_free()
	await process_frame


## Kael's light lands; frozen 3 ticks after contact.
func _hit(zone: StringName) -> void:
	var level := await _level(zone)
	await _step(level, 2)
	_place(level, CLOSE_GAP)
	await _step(level, 30)
	for t in 3:
		_script["0:%d" % (level.sim.current_tick + t)] = FighterInput.Action.LIGHT
	var after := -1
	for i in 40:
		await _step(level, 1)
		for event: Dictionary in level.sim.events:
			if event.type == CombatSim.EventType.HIT and after < 0:
				after = 0
		if after >= 0:
			after += 1
			if after > 3:
				break
	for side_on in [false, true]:
		_frame(level, side_on)
		await _shot("%s_hit_%s" % [zone, "side" if side_on else "close"])
	await _free(level)


## Kael's beam special at 10 m, 28 ticks after the press.
func _beam(zone: StringName) -> void:
	var level := await _level(zone)
	await _step(level, 2)
	_place(level, BEAM_GAP)
	level.sim.fighters[0].ki = 100 * FighterState.METER_UNIT
	await _step(level, 20)
	_script["0:%d" % level.sim.current_tick] = FighterInput.Action.SPECIAL_1
	await _step(level, 28)
	for side_on in [false, true]:
		_frame(level, side_on)
		await _shot("%s_beam_%s" % [zone, "side" if side_on else "close"])
	await _free(level)


## Idle exchange distance, close framing; plus the real gameplay camera.
func _zone(zone: StringName) -> void:
	var level := await _level(zone)
	await _step(level, 2)
	_place(level, CLOSE_GAP + 1.0)
	await _step(level, 60)
	_frame(level, false)
	await _shot("zone_%s_close" % zone)
	level.camera.make_current()
	await _step(level, 2)
	await _shot("zone_%s_game" % zone)
	await _free(level)
