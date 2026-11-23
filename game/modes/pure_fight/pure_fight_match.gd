class_name PureFightMatch
extends Node3D
## Pure Fight level (GAME_DESIGN §16): a 2.5D 1v1 on a platform in any of the seven zones.
## Builds the zone as a 3D backdrop, the platform, the side camera, both fighters, HUD and
## effects; steps PureFightSim at 60 Hz from keyboard, a second local player or the AI.
## Call configure() before adding it to the tree.

signal match_finished(winner: int)

const MODE := &"pure_fight"
const MODE_TRAINING := &"pure_fight_training"
const DEFAULT_CONFIG := {
	"zone": &"heartbloom_gardens",
	"fighters": [
		{"character": &"kael", "is_ai": false, "ai_level": 3},
		{"character": &"vexa", "is_ai": true, "ai_level": 3},
	],
	"mode": MODE,
	"seed": 1,
}
const WORLD_SCENE := preload("res://game/world/world_map.tscn")
const ARENA_HALF := 300.0
## Seconds after the match ends before the results screen.
const RESULTS_AFTER := 4.0
const SOUNDS := {
	PureFightSim.Ev.BLOCK: &"block", PureFightSim.Ev.JUST_DEFEND: &"perfect_block",
	PureFightSim.Ev.ARMOR: &"armor_hit", PureFightSim.Ev.THROW: &"grab",
	PureFightSim.Ev.THROW_TECH: &"tech", PureFightSim.Ev.WALL_BOUNCE: &"wall_splat",
	PureFightSim.Ev.GROUND_BOUNCE: &"spike_bounce", PureFightSim.Ev.KNOCKDOWN: &"impact_thump",
	PureFightSim.Ev.KO: &"ko", PureFightSim.Ev.COUNTER: &"counter_hit", PureFightSim.Ev.PUNISH: &"counter_hit",
	PureFightSim.Ev.COUNTER_STANCE: &"counter_hit", PureFightSim.Ev.FIGHT: &"round_fight",
	PureFightSim.Ev.DASH: &"dash", PureFightSim.Ev.LAND: &"land_light", PureFightSim.Ev.FINISHER: &"launcher",
	PureFightSim.Ev.FINISHER_HIT: &"hit_heavy", PureFightSim.Ev.MATCH_WIN: &"victory",
}
const HIT_SOUNDS: Array[StringName] = [&"hit_light", &"hit_medium", &"hit_heavy", &"hit_heavy"]
## Training: cycles the dummy. T works on laptops whose F-keys need Fn (Macs).
const DUMMY_KEYS: Array[Key] = [KEY_T, KEY_F4]

var config := {}
var zone_id: StringName
var sim: PureFightSim
var world: WorldMap
var voxel_zone: VoxelZoneView
var ground: ZoneGround
var stage := PureFightStage.new()
var camera := SideCamera.new()
var views: Array[PureFightFighterView] = []
var hud := PureFightHud.new()
var effects := PureFightEffects.new()
## Per fighter: PureFightKeys for a human, PureFightAI for the AI, null for the training dummy.
var drivers: Array = []
## Optional scripted control: func(fighter_index, tick) -> FighterInput.
var input_override: Callable
var training := false
## Training dummy: 0 stands, 1 blocks everything, 2 crouch-blocks, 3 jumps.
var dummy_mode := 0
## Build without the zone (tests that only need the fight).
var skip_world := false
var _ended_for := -1.0
var _finished := false
## Online (mode pure_fight_online with an open DuoLink): the sim advances through net_session.
var online := false
var duo_link: DuoLink
var net_session: RollbackSession
## Fighter this device plays online (the host is 0).
var local_peer := 0
## Set by MatchSession while its menu is open online (the match itself never pauses).
var input_blocked := false
## No free camera: clicks are attacks and the pointer is never captured (MatchSession).
var mouse_look := false
## Web only: logs the first keyboard player's presses for browser tests.
var input_probe := WebInputProbe.new()
var _net_started := false
var _net_wait_ticks := 0
## Partner left: the match carries on locally against the AI.
var _partner_gone := false


func configure(match_config: Dictionary) -> void:
	assert(not is_inside_tree(), "configure the match before adding it to the tree")
	config = DEFAULT_CONFIG.duplicate(true)
	config.merge(match_config, true)
	zone_id = StringName(config.zone)
	training = StringName(config.get("mode", MODE)) == MODE_TRAINING


func is_online_mode() -> bool:
	return StringName(config.get("mode", MODE)) == MatchRules.MODE_PURE_FIGHT_ONLINE


## Members built in field initialisers are only parented in _ready; free them if it never ran.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for node: Node in [stage, camera, hud, effects]:
			if is_instance_valid(node) and node.get_parent() == null:
				node.free()


func _ready() -> void:
	if config.is_empty():
		configure({})
	var entries: Array = config.fighters
	var legends: Array[StringName] = []
	for i in 2:
		legends.append(StringName((entries[i] as Dictionary).get("character", &"kael")))
	if is_online_mode() and is_inside_tree():
		duo_link = DuoLink.find(get_tree())
		online = duo_link != null and duo_link.is_connected_to_partner()
		local_peer = duo_link.local_peer if online else 0
	sim = PureFightNet.new_sim(int(config.get("seed", 1)), legends) if is_online_mode() \
		else PureFightSim.new(int(config.get("seed", 1)), legends)
	if not skip_world:
		_build_world()
	add_child(stage)
	if skip_world:
		stage.place(func(_x: float, _z: float) -> float: return 0.0, Vector2.ZERO, Vector2(0, 50))
	sim.line_origin = stage.origin
	sim.line_dir = stage.line_dir
	add_child(camera)
	camera.line_dir = stage.line_dir
	camera.floor_y = stage.floor_y
	camera.current = true
	for i in 2:
		var view := PureFightFighterView.new()
		view.name = "Fighter%d" % (i + 1)
		view.setup(sim, i)
		view.energy = [MenuTheme.HOT, MenuTheme.CYAN][i]
		add_child(view)
		views.append(view)
		drivers.append(_make_driver(i, entries[i]))
	add_child(effects)
	effects.sim = sim
	effects.camera = camera
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	layer.layer = 10
	add_child(layer)
	var impact: ImpactFrame = preload("res://game/view/shaders/screen/impact_frame.tscn").instantiate()
	layer.add_child(impact)
	effects.impact_frame = impact
	var lines: ColorRect = preload("res://game/view/shaders/screen/speed_lines.tscn").instantiate()
	lines.visible = false
	layer.add_child(lines)
	effects.speed_lines = lines
	hud.sim = sim
	hud.training = training
	# A human on P1's keys (vs AI, training, Duo online) sees the mouse scheme for a few seconds.
	if online or drivers.any(func(d: Variant) -> bool: return d is PureFightKeys and (d as PureFightKeys).player == 0):
		hud.hint = PureFightKeys.hint_text()
	for i in 2:
		var roster := Roster.character(legends[i])
		hud.names[i] = roster.display_name.to_upper() if roster else String(legends[i]).to_upper()
	layer.add_child(hud)
	effects.callout = hud.show_callout
	hud.after_tick(sim.events)
	if online:
		_setup_online()


## Online wiring: a rollback session over the open link; both peers play with P1's keys.
func _setup_online() -> void:
	drivers[local_peer] = PureFightKeys.new(0)
	drivers[1 - local_peer] = null
	net_session = PureFightNet.new_session(sim, duo_link.transport, local_peer, DuoMatch.INPUT_DELAY)
	net_session.desynced.connect(func(frame: int, _a: int, _b: int) -> void:
		printerr("Pure Fight desync at tick %d" % frame)
		hud.show_callout("OUT OF SYNC"))
	duo_link.partner_left.connect(_on_partner_left)
	duo_link.report_loaded()
	hud.show_callout("WAITING FOR PARTNER")


func _on_partner_left() -> void:
	if _partner_gone:
		return
	_partner_gone = true
	hud.show_callout("PARTNER LEFT: VS AI")
	_go_offline()


## Carries on locally: the partner's fighter goes to the AI.
func _go_offline() -> void:
	if net_session and net_session.transport and net_session.transport.received.is_connected(net_session.on_receive):
		net_session.transport.received.disconnect(net_session.on_receive)
	net_session = null
	online = false
	var ai := PureFightAI.new()
	ai.setup(1 - local_peer, 3, int(config.get("seed", 1)))
	drivers[1 - local_peer] = ai


func _exit_tree() -> void:
	if net_session and net_session.transport and net_session.transport.received.is_connected(net_session.on_receive):
		net_session.transport.received.disconnect(net_session.on_receive)


## One online tick: waits for the partner to load, then advances the session.
func _step_online() -> void:
	if not _net_started:
		if not duo_link.partner_loaded():
			_net_wait_ticks += 1
			if _net_wait_ticks > 60 * PureFightSim.TICKS_PER_SECOND:
				_on_partner_left()
			return
		_net_started = true
	for view in views:
		view.remember_previous_tick(sim)
	var keys := drivers[local_peer] as PureFightKeys
	var input := keys.read_tick() if keys != null else FighterInput.new()
	if input_blocked:
		input = FighterInput.new()
	if net_session.advance(input):
		input_probe.record(sim.current_tick, input, String(sim.pf[local_peer].move), sim.pf[local_peer].state)
		effects.react(sim.events)
		hud.after_tick(sim.events)
		_play_sounds(sim.events)
	for view in views:
		view.remember_current(sim)
	if net_session.ms_since_remote() > 30000:
		_on_partner_left()


func _build_world() -> void:
	world = WORLD_SCENE.instantiate()
	world.focus_zone = zone_id
	add_child(world)
	move_child(world, 0)
	var data := world.zone(zone_id)
	ground = ZoneGround.bake(world.heightmap, world.islands, data.centre, ARENA_HALF)
	if bool(config.get("voxel_zone", ArtStyle.is_voxel())) and VoxelZoneView.supports(zone_id):
		voxel_zone = VoxelZoneView.new()
		add_child(voxel_zone)
		move_child(voxel_zone, 1)
		VoxelZoneView.hide_classic(world)
		voxel_zone.build(zone_id, int(config.get("quality", GraphicsSettings.load_saved().quality)))
	var spawns := data.fighter_spawns()
	var near := data.centre
	if spawns.size() >= 2:
		near = Vector2((spawns[0].x + spawns[1].x) * 0.5, (spawns[0].z + spawns[1].z) * 0.5)
	stage.place(func(x: float, z: float) -> float: return ground.height_at(x, z, INF), near, data.centre)


func _make_driver(index: int, entry: Dictionary) -> Variant:
	if bool(entry.get("is_ai", false)):
		var level := int(entry.get("ai_level", 3))
		if training and index == 1:
			return null
		var ai := PureFightAI.new()
		ai.setup(index, level, int(config.get("seed", 1)))
		return ai
	return PureFightKeys.new(index if bool(entry.get("second_keyboard", index == 1)) else 0)


func _physics_process(_delta: float) -> void:
	step_tick()


func _process(delta: float) -> void:
	present_frame(Engine.get_physics_interpolation_fraction(), delta)
	if sim.is_match_over() and not _finished:
		_ended_for += delta
		if _ended_for >= RESULTS_AFTER:
			_finished = true
			match_finished.emit(sim.match_winner)


func _unhandled_input(event: InputEvent) -> void:
	for driver: Variant in drivers:
		if driver is PureFightKeys:
			(driver as PureFightKeys).note_event(event)


func _unhandled_key_input(event: InputEvent) -> void:
	if training and event.is_pressed() and not event.is_echo() and (event as InputEventKey).physical_keycode in DUMMY_KEYS:
		dummy_mode = (dummy_mode + 1) % 4
		hud.show_callout(["DUMMY: STAND", "DUMMY: BLOCK ALL", "DUMMY: CROUCH BLOCK", "DUMMY: JUMP"][dummy_mode])


## Advances the sim one tick.
func step_tick() -> void:
	if online and net_session:
		_step_online()
		return
	for view in views:
		view.remember_previous_tick(sim)
	var inputs: Array[FighterInput] = []
	var probed := -1
	for i in 2:
		if input_override.is_valid():
			inputs.append(input_override.call(i, sim.current_tick))
		elif drivers[i] is PureFightAI:
			inputs.append((drivers[i] as PureFightAI).next_input(sim))
		elif drivers[i] is PureFightKeys:
			inputs.append((drivers[i] as PureFightKeys).read_tick())
			if probed < 0:
				probed = i
		else:
			inputs.append(_dummy_input(i))
	sim.tick(inputs)
	if probed >= 0:
		input_probe.record(sim.current_tick, inputs[probed], String(sim.pf[probed].move), sim.pf[probed].state)
	if training:
		_refill()
	effects.react(sim.events)
	hud.after_tick(sim.events)
	_play_sounds(sim.events)
	for view in views:
		view.remember_current(sim)


func present_frame(blend: float, delta: float) -> void:
	for view in views:
		view.present(sim, blend, delta)
	camera.follow(views[0].position, views[1].position, delta)


func _dummy_input(index: int) -> FighterInput:
	var input := FighterInput.new()
	var me := sim.pf[index]
	var away := -float(signi(sim.opponent(index).x - me.x))
	match dummy_mode:
		1:
			var guard: StringName = PureMoves.get_move(sim.opponent(index).legend, sim.opponent(index).move).get("guard", &"mid")
			input.move = Vector2(away, -1.0 if guard == &"low" else 0.0)
		2:
			input.move = Vector2(away, -1.0)
		3:
			input.move = Vector2(0, 1)
	return input


## Training: health comes back once a combo ends; the meter stays full.
func _refill() -> void:
	for fighter in sim.pf:
		fighter.meter = PureMoves.METER_MAX
		var free := fighter.state in [PureFighter.State.IDLE, PureFighter.State.WALK, PureFighter.State.CROUCH]
		if free and fighter.combo_hits == 0:
			fighter.health = fighter.max_health
	sim.timer_ticks = PureFightSim.ROUND_SECONDS * PureFightSim.TICKS_PER_SECOND


func _play_sounds(events: Array) -> void:
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio == null:
		return
	for event: Dictionary in events:
		var type: int = event.type
		var cue: StringName = SOUNDS.get(type, &"")
		if type == PureFightSim.Ev.HIT:
			cue = HIT_SOUNDS[clampi(int(event.strength), 0, 3)]
		elif type == PureFightSim.Ev.MOVE:
			cue = &"whoosh_heavy" if int(event.strength) >= 2 else &"whoosh_light"
		if cue != &"" and audio.cues.has(cue):
			audio.play(cue, effects.world(int(event.x), int(event.y)))


## Every legend's move list (pause menu).
func move_list_text() -> String:
	var lines: Array[String] = ["CONTROLS", PureFightKeys.controls_text(0), PureFightKeys.controls_text(1),
		"Techniques: motion + attack, or technique key + direction (fwd 236, down 623, back 214).",
		"Motions are directions, not keypad keys: 2 down, 3 down-forward, 6 forward, 4 back, 1 down-back",
		"(forward = toward the opponent; 236 = down, down-forward, forward). P2 does them on the arrows.", ""]
	var seen := {}
	for fighter in sim.pf:
		if seen.has(fighter.legend):
			continue
		seen[fighter.legend] = true
		lines.append_array(PureFightMoveList.lines(fighter.legend))
		lines.append("")
	return "\n".join(lines)
