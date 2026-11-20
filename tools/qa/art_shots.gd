extends SceneTree
## Fixed art-review shot list for the Visual & Feel Critic (docs/ART_BIBLE.md).
## Same seeds, inputs and placements every run, so scorecards stay comparable.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##   --rendering-method gl_compatibility --resolution 1280x720 --disable-vsync \
##   -s res://tools/qa/art_shots.gd -- --out DIR [--only zones|legends|ko|ki|hud|menus|clip]

const SIZE := Vector2i(1280, 720)
const SEED := 7
## Fighters stand this far apart (m) for the zone and legend shots.
const ZONE_GAP := 6.0
const CLOSE_GAP := 2.6
const FLIGHT_HEIGHT := 8.0
const SETTLE_TICKS := 90
const LEGENDS: Array[StringName] = [&"kael", &"vexa", &"brann", &"lyra"]

var _out := "user://art_shots"
var _only := ""
var _script: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var raw := OS.get_cmdline_user_args()
	for i in raw.size():
		if raw[i] == "--out" and i + 1 < raw.size():
			_out = raw[i + 1]
		if raw[i] == "--only" and i + 1 < raw.size():
			_only = raw[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = SIZE
	DisplayServer.window_set_size(SIZE)
	if _wants("menus"):
		await _menus()
	if _wants("zones"):
		for zone in ZoneLayout.ZONE_IDS:
			await _zone(zone)
	if _wants("legends"):
		for legend in LEGENDS:
			await _legend(legend)
	if _wants("ko"):
		await _ko()
	if _wants("ki"):
		await _ki()
	if _wants("hud"):
		await _hud(&"1v1", [&"kael", &"vexa"])
		await _hud(&"ffa4", [&"kael", &"vexa", &"brann", &"lyra"])
	if _wants("clip"):
		await _clip()
	print("[art] done")
	quit()


func _wants(part: String) -> bool:
	return _only == "" or _only == part


## Builds a zone match with scripted input (idle unless _script says otherwise).
func _level(zone: StringName, legends: Array, flow := false, ai := false) -> ZoneMatch:
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
	(level.get_node(^"DebugOverlay") as CanvasLayer).visible = false
	_script = {}
	if not ai:
		level.input_override = func(slot: int, tick: int) -> FighterInput: return _input(slot, tick)
	await process_frame
	if not level.vfx_prewarm.is_finished:
		await level.vfx_prewarm.finished
	return level


## Scripted presses: _script["slot:tick"] = action mask.
func _input(slot: int, tick: int) -> FighterInput:
	var input := FighterInput.new()
	var mask: int = _script.get("%d:%d" % [slot, tick], 0)
	input.held_actions = mask
	input.pressed_actions = mask
	return input


## Puts fighter 1 `gap` m from fighter 0 along their spawn line, both `lift` m up.
func _place(level: ZoneMatch, gap: float, lift: float) -> void:
	var sim := level.sim
	var a := sim.fighters[0].position
	var b := sim.fighters[1].position
	var dir := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	if dir == Vector3.ZERO:
		dir = Vector3.FORWARD
	var stand := sim.tuning.ground_height
	var p0 := a + Vector3.UP * lift
	var p1 := a + dir * gap
	p1.y = level.ground.height_at(p1.x, p1.z, INF) + stand + lift
	p0.y = maxf(p0.y, level.ground.height_at(p0.x, p0.z, INF) + stand + lift)
	sim.fighters[0].position = p0
	sim.fighters[1].position = p1
	for f in sim.fighters:
		f.velocity = Vector3.ZERO
		if lift > 0.0:
			f.state = FighterState.State.FLYING
	sim.fighters[0].facing_yaw = atan2(-dir.x, -dir.z)
	sim.fighters[1].facing_yaw = atan2(dir.x, dir.z)


func _step(level: ZoneMatch, ticks: int, draw_last := 2) -> void:
	for t in ticks:
		root.disable_3d = t < ticks - draw_last
		level.step_tick()
		level.present_frame(1.0, 1.0 / 60.0)
		await process_frame


func _shot(name: String) -> void:
	root.disable_3d = false
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("[art] ", name)


func _free(level: Node) -> void:
	level.queue_free()
	await process_frame


func _hide_hud(level: Node) -> void:
	for layer: CanvasLayer in level.find_children("*", "CanvasLayer", true, false):
		layer.visible = false


## Gameplay camera on Kael vs Brann, ZONE_GAP apart, on the ground and at flight height.
func _zone(zone: StringName) -> void:
	for lift in [0.0, FLIGHT_HEIGHT]:
		var level := await _level(zone, [&"kael", &"brann"])
		_hide_hud(level)
		await _step(level, 2, 0)
		_place(level, ZONE_GAP, lift)
		await _step(level, SETTLE_TICKS)
		await _shot("zone_%s_%s" % [zone, "ground" if lift == 0.0 else "air"])
		await _free(level)


## Idle, heavy mid-swing, getting hit, then each weapon held (Shattered Mesa daylight).
func _legend(legend: StringName) -> void:
	var rival: StringName = &"brann" if legend != &"brann" else &"kael"
	var level := await _level(&"shattered_mesa", [legend, rival])
	await _step(level, 2, 0)
	_place(level, CLOSE_GAP, 0.0)
	await _step(level, SETTLE_TICKS)
	await _shot("legend_%s_idle" % legend)
	var at := level.sim.current_tick
	_script["%d:%d" % [0, at]] = FighterInput.Action.HEAVY
	for n in 3:
		await _step(level, 4)
		await _shot("legend_%s_heavy_%d" % [legend, n])
	await _step(level, 60, 0)
	# The heavy knocks the rival away: put it back in reach before it swings.
	_place(level, CLOSE_GAP, 0.0)
	await _step(level, 20, 0)
	at = level.sim.current_tick
	_script["%d:%d" % [1, at]] = FighterInput.Action.HEAVY
	await _step(level, 6)
	for n in 3:
		await _step(level, 4)
		await _shot("legend_%s_hit_%d" % [legend, n])
	_place(level, CLOSE_GAP, 0.0)
	var kinds: Array = Weapon.Kind.values().slice(1)
	for kind: Weapon.Kind in kinds:
		await _step(level, 40, 0)
		var f := level.sim.fighters[0]
		f.weapons[0] = kind
		f.ammo[0] = Weapon.full_ammo(kind)
		f.active_slot = 0
		await _step(level, 20)
		await _shot("legend_%s_weapon_%s" % [legend, String(Weapon.Kind.find_key(kind)).to_lower()])
	await _free(level)


## Kael finishes a 1-health Brann with a heavy; frames before, at and after the KO.
func _ko() -> void:
	var level := await _level(&"ember_rift", [&"kael", &"brann"], true)
	await _step(level, 2, 0)
	while not level.match_flow.accepts_input():
		await _step(level, 1, 0)
	_place(level, CLOSE_GAP, 0.0)
	level.sim.fighters[1].health = 1
	await _step(level, 30, 0)
	var at := level.sim.current_tick
	_script["%d:%d" % [0, at]] = FighterInput.Action.HEAVY
	var ko := -1
	var frame := 0
	while frame < 150:
		level.step_tick()
		level.present_frame(1.0, 1.0 / 60.0)
		await process_frame
		for event: Dictionary in level.sim.events:
			if event.type == CombatSim.EventType.KO and ko < 0:
				ko = frame
		if frame % 3 == 0:
			await _shot("ko_%03d" % frame)
		frame += 1
	print("[art] ko at frame ", ko)
	await _free(level)


## Sim ki (T-KI1): a tap blast and a full-ki beam, Stormfall City at night.
func _ki() -> void:
	var level := await _level(&"stormfall_city", [&"lyra", &"vexa"])
	level.sim.pickups_enabled = false
	await _step(level, 2, 0)
	_place(level, 12.0, 0.0)
	await _step(level, 30, 0)
	var at := level.sim.current_tick
	_script["0:%d" % at] = FighterInput.Action.KI_BLAST
	for n in 4:
		await _step(level, 4)
		await _shot("ki_blast_%d" % n)
	await _step(level, 60, 0)
	_place(level, 16.0, 0.0)
	level.sim.fighters[0].ki = 100 * FighterState.METER_UNIT
	await _step(level, 4, 0)
	at = level.sim.current_tick
	_script["0:%d" % at] = FighterInput.Action.SPECIAL_1
	for n in 6:
		await _step(level, 6)
		await _shot("ki_beam_%d" % n)
	await _free(level)


## The HUD after a short AI exchange.
func _hud(mode: StringName, legends: Array) -> void:
	var level := await _level(&"heartbloom_gardens", legends, true, true)
	await _step(level, 420)
	await _shot("hud_%s" % mode)
	await _free(level)


func _menus() -> void:
	var front: Node = load("res://game/ui/menus/front_end.tscn").instantiate()
	front.skip_splash = true
	root.add_child(front)
	await _frames(100)
	await _shot("menu_main")
	front._on_mode_chosen(&"vs_ai")
	front.go(&"character_select")
	var select: CharacterSelect = front.screens[&"character_select"]
	select.set_active_slot(0)
	select.select_legend(&"kael")
	if select.slots.size() > 1:
		select.set_active_slot(1)
		select.select_legend(&"lyra")
	await _frames(80)
	await _shot("menu_character_select")
	front.go(&"zone_select")
	(front.screens[&"zone_select"] as ZoneSelect).select_zone(&"skyhold_ruins")
	await _frames(80)
	await _shot("menu_zone_select")
	front.go(&"settings")
	await _frames(40)
	await _shot("menu_settings")
	front.queue_free()
	await process_frame


func _frames(n: int) -> void:
	for f in n:
		await process_frame


## 10 s of AI 1v1 (Vexa vs Brann, Frozen Peaks), every 3rd frame.
func _clip() -> void:
	var level := await _level(&"frozen_peaks", [&"vexa", &"brann"], true, true)
	await _step(level, 240, 0)
	for frame in 600:
		root.disable_3d = frame % 3 != 0
		level.step_tick()
		level.present_frame(1.0, 1.0 / 60.0)
		await process_frame
		if frame % 3 == 0:
			await _shot("clip_%03d" % frame)
	await _free(level)
