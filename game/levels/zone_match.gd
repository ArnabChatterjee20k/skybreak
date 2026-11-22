class_name ZoneMatch
extends Node3D
## The real match (T-106): a fight in one zone of the world map. Wiring follows the
## test arena (sim, fighter views, camera, HUD and round flow, combat feedback,
## weapons, audio, VFX prewarm); the zone gives the ground, spawn points, arena box,
## atmosphere, weather and ambience. Call configure() before adding it to the tree.

const DEFAULT_CONFIG := {
	"zone": &"heartbloom_gardens",
	"fighters": [
		{"character": &"kael", "team": 0, "is_ai": false, "ai_level": 0},
		{"character": &"vexa", "team": 1, "is_ai": true, "ai_level": 3},
	],
	"rounds": 3,
	"mode": &"versus",
}
## Arena box per zone: half size (m) around the zone centre and ceiling height (m).
const ARENAS := {
	&"shattered_mesa": Vector2(300, 380),
	&"skyhold_ruins": Vector2(300, 380),
	&"stormfall_city": Vector2(300, 380),
	&"frozen_peaks": Vector2(300, 395),
	&"verdant_falls": Vector2(300, 380),
	&"ember_rift": Vector2(300, 380),
	&"heartbloom_gardens": Vector2(290, 395),
}
const TEAM_COLORS: Array[Color] = [
	Color(1, 0.55, 0.2, 0.6), Color(0.3, 0.8, 1, 0.8), Color(0.45, 1, 0.45, 0.7), Color(0.85, 0.45, 1, 0.7),
]
## Teammates stand this far apart, side by side.
const TEAMMATE_SPACING := 6.0
const AI_DRIVER_PATH := "res://game/ai/ai_driver.gd"
const WORLD_SCENE := preload("res://game/world/world_map.tscn")

var config := {}
var zone_id: StringName
var sim := CombatSim.new()
var world: WorldMap
## The zone's voxel look (Voxel art style), or null in Classic.
var voxel_zone: VoxelZoneView
var ground: ZoneGround
## Team per fighter, as configured.
var teams: Array[int] = []
## Driver per fighter: null for the human, else an object with next_input(sim).
var drivers: Array = []
## Fighter the camera follows and the keyboard drives.
var player := 0
## Optional scripted control, as in the test arena: func(fighter_index, tick) -> FighterInput.
var input_override: Callable
## Duo online (mode duo with an open DuoLink): the sim advances through net_session.
var online := false
var duo_link: DuoLink
var net_session: RollbackSession
var duo_hud: DuoHud
## Input is neutral while true (the online pause menu: the match keeps running).
var input_blocked := false
var _net_started := false
var _net_wait_ticks := 0
var _partner_gone := false
var _duo_test: DuoTestPilot

var vfx_prewarm := VfxPrewarm.new()
var combat_feedback := CombatFeedback.new()
var combo_counter := ComboCounter.new()
var match_flow: MatchFlow
var match_hud := MatchHud.new()
var control_hints := ControlHints.new()
var match_audio := MatchAudio.new()
## Round cues and music from the match flow (T-127).
var match_cues := MatchCues.new()
## Through a KO the camera keeps framing both fighters while within this (m).
const KO_FRAMING_RANGE := 40.0
## Last lock-on target of the followed fighter, kept for KO framing.
var _camera_target := -1
var weapon_layer := WeaponLayer.new()
var fighter_views: Array[FighterView] = []
## The ground marker under each fighter: contact shadow plus airborne team ring.
var contact_shadows := ContactShadows.new()

@onready var camera: FighterCamera = $FighterCamera
@onready var opponent_marker: OpponentMarker = $Hud/OpponentMarker
@onready var _player_input: KeyboardMouseInput = $KeyboardMouseInput


## {zone, fighters: [{character, team, is_ai, ai_level}], rounds, mode}; missing keys
## fall back to DEFAULT_CONFIG. Optional voxel_zone (bool) overrides the art style for
## the zone only (characters follow ArtStyle).
func configure(match_config: Dictionary) -> void:
	assert(not is_inside_tree(), "configure the zone match before adding it to the tree")
	_apply_config(match_config)


func _apply_config(match_config: Dictionary) -> void:
	config = DEFAULT_CONFIG.duplicate(true)
	config.merge(match_config, true)
	zone_id = StringName(config.zone)
	if config.has("seed"):
		sim = CombatSim.new(int(config.seed))


func _ready() -> void:
	if config.is_empty():
		_apply_config({})
	if is_duo():
		duo_link = DuoLink.find(get_tree())
		online = duo_link != null and duo_link.is_connected_to_partner()
	_build_world()
	_build_fighters()
	add_child(contact_shadows)
	contact_shadows.setup(fighter_views.size())
	for i in fighter_views.size():
		contact_shadows.set_ring_color(i, fighter_views[i]._height_marker.color)
	sim.pickups_enabled = true
	camera.obstacles = CameraObstacles.from_zone_match(self)
	add_child(weapon_layer)
	weapon_layer.setup(sim, fighter_views)
	$DebugOverlay.sim = sim
	opponent_marker.camera = camera
	add_child(combat_feedback)
	combat_feedback.camera = camera
	var impact_frame: ImpactFrame = preload("res://game/view/shaders/screen/impact_frame.tscn").instantiate()
	$Hud.add_child(impact_frame)
	combat_feedback.impact_frame = impact_frame
	$Hud.add_child(combo_counter)
	match_flow = DuoMatch.new_flow(config) if is_duo() else MatchFlow.new(fighter_views.size())
	match_flow.spawn_points = spawn_positions()
	match_hud.sim = sim
	match_hud.flow = match_flow
	for i in fighter_views.size():
		match_hud.names.append(fighter_views[i].display_name)
		match_hud.team_colors.append(Color(fighter_views[i].energy_color, 1.0))
		match_hud.is_ai.append(drivers[i] != null)
		match_hud.portraits.append(_hud_portrait(fighter_views[i].character_id))
	match_hud.teams = teams
	match_hud.player = player
	$Hud.add_child(match_hud)
	control_hints.sim = sim
	control_hints.player = player
	control_hints.keyboard = _player_input
	control_hints.active = false
	$Hud.add_child(control_hints)
	add_child(vfx_prewarm)
	match_audio.sim = sim
	# No world on the audio: the ambience stays on this zone (T-D19).
	match_audio.default_zone = zone_id
	add_child(match_audio)
	match_cues.zone = zone_id
	match_cues.player_index = player
	add_child(match_cues)
	if is_duo():
		_setup_duo()
	_start_prewarm.call_deferred()


func _build_world() -> void:
	world = WORLD_SCENE.instantiate()
	world.focus_zone = zone_id
	add_child(world)
	move_child(world, 0)
	var data := world.zone(zone_id)
	assert(data != null, "unknown zone %s" % zone_id)
	var arena: Vector2 = ARENAS.get(zone_id, Vector2(300, 380))
	var tuning := sim.tuning.duplicate() as MovementTuning
	tuning.arena_half_size = arena.x
	tuning.arena_ceiling = arena.y
	sim.tuning = tuning
	sim.zone = zone_id
	sim.arena_centre = data.centre
	ground = ZoneGround.bake(world.heightmap, world.islands, data.centre, arena.x)
	sim.ground_height = ground.height_at
	if bool(config.get("voxel_zone", ArtStyle.is_voxel())) and VoxelZoneView.supports(zone_id):
		_build_voxel_zone()


## Voxel art style: the zone's voxel look over the same ground (visual only).
func _build_voxel_zone() -> void:
	voxel_zone = VoxelZoneView.new()
	add_child(voxel_zone)
	move_child(voxel_zone, 1)
	VoxelZoneView.hide_classic(world)
	voxel_zone.build(zone_id, int(config.get("quality", GraphicsSettings.load_saved().quality)))


func _build_fighters() -> void:
	var entries: Array = config.fighters
	var starts := spawn_positions()
	player = -1
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var character_id := StringName(entry.get("character", &"kael"))
		var team := int(entry.get("team", i))
		var view := FighterView.new()
		view.name = "Fighter%d" % (i + 1)
		view.character_id = character_id
		view.slot = i
		view.energy_color = TEAM_COLORS[team % TEAM_COLORS.size()]
		var roster := Roster.character(character_id)
		view.display_name = roster.display_name.to_upper() if roster else String(character_id).to_upper()
		add_child(view)
		view.fighter = sim.add_fighter(starts[i], view.fighter_stats())
		if is_duo():
			view.fighter.team = team
		view.remember_previous_tick()
		fighter_views.append(view)
		teams.append(team)
		var is_ai := bool(entry.get("is_ai", false))
		drivers.append(_make_driver(i, int(entry.get("ai_level", 3))) if is_ai else null)
		if not is_ai and player < 0:
			player = i
	player = maxi(player, 0)
	if online:
		player = duo_link.local_peer
	_lock_onto_nearest_rival()


## Start positions: each team around one of the zone's two spawn points, on the ground
## (or hovering where the zone spawns in the air).
func spawn_positions() -> Array[Vector3]:
	var data := world.zone(zone_id)
	var points := data.fighter_spawns()
	var entries: Array = config.fighters
	var team_ids: Array[int] = []
	for i in entries.size():
		var team := int((entries[i] as Dictionary).get("team", i))
		if not team_ids.has(team):
			team_ids.append(team)
	var placed := {}
	var out: Array[Vector3] = []
	for i in entries.size():
		var team := int((entries[i] as Dictionary).get("team", i))
		var side := team_ids.find(team)
		var point := points[side % points.size()]
		var other := points[(side + 1) % points.size()]
		var across := Vector3(other.z - point.z, 0.0, point.x - other.x).normalized()
		if across == Vector3.ZERO:
			across = Vector3.RIGHT
		var slot: int = placed.get(team, 0)
		placed[team] = slot + 1
		var offset := across * TEAMMATE_SPACING * float((slot + 1) / 2) * (1.0 if slot % 2 == 1 else -1.0)
		var at := Vector3(point.x, 0.0, point.z) + offset
		var stand := ground.height_at(at.x, at.z, INF) + sim.tuning.ground_height
		at.y = maxf(point.y, stand)
		out.append(at)
	return out


func _make_driver(index: int, level: int) -> Object:
	if ResourceLoader.exists(AI_DRIVER_PATH):
		var script: Script = load(AI_DRIVER_PATH)
		var driver: Object = script.new()
		if driver.has_method("next_input"):
			if driver.has_method("setup"):
				driver.call("setup", index, level)
			return driver
	return WeaponBot.new(index, 7919 * (index + 1) + level)


func _lock_onto_nearest_rival() -> void:
	for i in sim.fighters.size():
		var best := -1
		var best_distance := INF
		for j in sim.fighters.size():
			if teams[j] == teams[i]:
				continue
			var distance := sim.fighters[i].position.distance_squared_to(sim.fighters[j].position)
			if distance < best_distance:
				best = j
				best_distance = distance
		sim.fighters[i].lock_on_target = best


func _start_prewarm() -> void:
	vfx_prewarm.start(camera)


func _physics_process(_delta: float) -> void:
	step_tick()
	# Online both peers keep the same fixed tick rate: no slow motion.
	Engine.time_scale = 1.0 if is_duo() else match_flow.time_scale() * combat_feedback.time_scale()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if net_session and net_session.transport and net_session.transport.received.is_connected(net_session.on_receive):
		net_session.transport.received.disconnect(net_session.on_receive)


## A Duo match (two humans vs AI), online or carried on alone.
func is_duo() -> bool:
	return StringName(config.get("mode", &"")) == MatchRules.MODE_DUO


## Online wiring: the rollback session over the open link, the Duo overlay, then
## the loaded barrier. Without a link (tests, a dropped partner) the other human
## slot gets an AI driver and the match runs locally.
func _setup_duo() -> void:
	duo_hud = DuoHud.new()
	duo_hud.flow = match_flow as DuoFlow
	duo_hud.sim = sim
	$Hud.add_child(duo_hud)
	duo_hud.continue_alone_requested.connect(continue_alone)
	duo_hud.leave_requested.connect(leave_online)
	if not online:
		_give_partner_to_ai()
		return
	duo_hud.partner_name = duo_link.partner_name if duo_link.partner_name else "your partner"
	net_session = RollbackSession.new(sim, duo_link.transport, duo_link.local_peer, DuoMatch.HUMAN_PEERS,
		DuoMatch.fighter_peers(sim.fighters.size()), drivers, DuoMatch.INPUT_DELAY)
	net_session.rules = match_flow
	net_session.desynced.connect(_on_desync)
	duo_hud.session = net_session
	duo_link.partner_left.connect(_on_partner_left)
	if DuoTestPilot.enabled():
		_duo_test = DuoTestPilot.new(self)
	duo_link.report_loaded()


func _give_partner_to_ai() -> void:
	for i in mini(DuoMatch.HUMAN_PEERS, drivers.size()):
		if i != player and drivers[i] == null:
			drivers[i] = _make_driver(i, DuoMatch.DEFAULT_AI_LEVEL)
			match_hud.is_ai[i] = true


## After a disconnect: the partner's fighter goes to the AI and the match runs here.
func continue_alone() -> void:
	if net_session == null and not online:
		duo_hud.hide_panel()
		return
	if duo_link:
		duo_link.leave()
	net_session = null
	online = false
	duo_hud.session = null
	duo_hud.hide_panel()
	_give_partner_to_ai()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Back to the Duo lobby (or the main menu when the link is gone).
func leave_online() -> void:
	var config_node := get_node_or_null(^"/root/MatchConfig")
	var connected := duo_link != null and duo_link.is_connected_to_partner() and not _partner_gone
	if config_node:
		config_node.call(&"return_to_menu", &"duo_lobby" if connected else &"main")


func _on_partner_left() -> void:
	if online and not _partner_gone:
		_partner_gone = true
		duo_hud.show_disconnected("%s left the match." % duo_hud.partner_name.capitalize())


func _on_desync(frame: int, local_hash: int, remote_hash: int) -> void:
	printerr("Duo desync at tick %d: %x vs %x" % [frame, local_hash, remote_hash])
	duo_hud.show_desync(frame)


## One online tick: waits for the partner to load, then advances the session.
func _step_online() -> void:
	if not _net_started:
		if not duo_link.partner_loaded():
			_net_wait_ticks += 1
			duo_hud.show_loading()
			if _net_wait_ticks > 60 * CombatSim.TICKS_PER_SECOND and not _partner_gone:
				_partner_gone = true
				duo_hud.show_disconnected("%s did not finish loading." % duo_hud.partner_name.capitalize())
			return
		_net_started = true
		duo_hud.hide_panel()
	for view in fighter_views:
		view.remember_previous_tick()
	weapon_layer.remember_previous_tick()
	var input := _local_input()
	if net_session.advance(input):
		combat_feedback.react(sim.events)
		match_cues.after_tick(match_flow, sim)
		match_audio.after_tick()
	if _duo_test:
		_duo_test.after_tick()
	_watch_partner()


func _local_input() -> FighterInput:
	if _duo_test:
		return _duo_test.local_input()
	var input := _player_input.read_tick(camera.view_yaw(), camera.orbit, sim.fighters[player].is_grounded())
	return FighterInput.new() if input_blocked else input


## Stalled for over two seconds: say so; DISCONNECT_SECONDS without a packet: offer to carry on.
const STALL_NOTICE_MS := 2000
const DISCONNECT_SECONDS := 30


func _watch_partner() -> void:
	if _partner_gone or net_session == null or net_session.desync_frame >= 0:
		return
	var quiet := net_session.ms_since_remote()
	if quiet > DISCONNECT_SECONDS * 1000:
		_partner_gone = true
		duo_hud.show_disconnected("No packets from %s for %d s." % [duo_hud.partner_name, DISCONNECT_SECONDS])
	elif quiet > STALL_NOTICE_MS:
		duo_hud.show_waiting(DISCONNECT_SECONDS - quiet / 1000)
	elif duo_hud.panel_visible():
		duo_hud.hide_panel()


func _process(delta: float) -> void:
	present_frame(Engine.get_physics_interpolation_fraction(), delta)


## A legend's head shot for the HUD portrait tile, rendered once like the
## character-select cards; the container itself stays invisible.
func _hud_portrait(id: StringName) -> Texture2D:
	var shot := LegendTurntable.new(id, false, true, Vector2i(156, 232))
	shot.stretch = false
	shot.self_modulate = Color.TRANSPARENT
	$Hud.add_child(shot)
	return shot.viewport.get_texture()


## Advances the sim one tick: keyboard for the player, drivers for AI slots.
func step_tick() -> void:
	if online and net_session:
		_step_online()
		return
	for view in fighter_views:
		view.remember_previous_tick()
	weapon_layer.remember_previous_tick()
	var inputs: Array[FighterInput] = []
	for i in sim.fighters.size():
		if not match_flow.accepts_input():
			inputs.append(FighterInput.new())
		elif input_override.is_valid():
			inputs.append(input_override.call(i, sim.current_tick))
		elif drivers[i] != null:
			inputs.append(drivers[i].next_input(sim))
		elif i == player:
			var keyboard := _player_input.read_tick(camera.view_yaw(), camera.orbit,
				sim.fighters[i].is_grounded())
			inputs.append(FighterInput.new() if input_blocked else keyboard)
		else:
			inputs.append(FighterInput.new())
	sim.tick(inputs)
	combat_feedback.react(sim.events)
	match_flow.step(sim)
	match_cues.after_tick(match_flow, sim)
	match_audio.after_tick()


## Other fighters' bodies, so the camera never sits inside one (issue #107).
func _update_camera_bodies() -> void:
	if camera.obstacles == null:
		return
	var centres := PackedVector3Array()
	for i in fighter_views.size():
		if i != player and fighter_views[i].visible and sim.fighters[i].state != FighterState.State.VANISHING:
			centres.append(fighter_views[i].position)
	var stats := CombatSim.DEFAULT_FIGHTER_STATS as FighterStats
	var width := stats.pushbox_radius * 2.0
	camera.obstacles.set_bodies(centres, Vector3(width, stats.pushbox_height, width))


## Draws one frame: fighters between the last two ticks, then the camera.
func present_frame(blend: float, delta: float) -> void:
	for view in fighter_views:
		view.present(blend, delta)
		# The ground marker sits on the zone's floor under the fighter, not y = 0.
		view._height_marker.ground_y = view.fighter.stand_height - sim.tuning.ground_height
	_place_contact_shadows()
	weapon_layer.present(blend, delta)
	var me := sim.fighters[player]
	var locked := me.lock_on_target >= 0
	if locked:
		_camera_target = me.lock_on_target
	# Through a KO the lock drops: keep framing the last target so the winner
	# and the launched loser both stay in view (issue #75).
	# Only while they are close enough to share a frame: a loser falling off a
	# floating island can end up hundreds of metres away.
	if match_flow.phase == MatchFlow.Phase.KO and _camera_target >= 0:
		var apart := fighter_views[player].position.distance_to(fighter_views[_camera_target].position)
		locked = apart < KO_FRAMING_RANGE
	var target := _camera_target if locked else (1 if player == 0 and fighter_views.size() > 1 else 0)
	var opponent := fighter_views[target].position
	_update_camera_bodies()
	camera.follow(fighter_views[player].position, opponent, locked, delta)
	for view in fighter_views:
		view.fade_for_camera(camera.global_position)
	opponent_marker.target = opponent
	opponent_marker.origin = fighter_views[player].position
	opponent_marker.locked = locked
	combo_counter.show_combo(sim.fighters, delta)
	# Hints only for a human at the keyboard: not in scripted or all-AI matches.
	control_hints.player = player
	match_hud.player = player
	control_hints.active = not input_override.is_valid() and drivers[player] == null


func _place_contact_shadows() -> void:
	for i in fighter_views.size():
		var view := fighter_views[i]
		var floor_y := view.fighter.stand_height - sim.tuning.ground_height
		var near := func(x: float, z: float) -> float: return ground.height_at(x, z, floor_y + 0.5)
		contact_shadows.place(i, view.position.x, view.position.z,
			view.position.y - HeightMarker.FEET_BELOW_CENTRE, floor_y, near)
