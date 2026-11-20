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
var ground: ZoneGround
## Team per fighter, as configured.
var teams: Array[int] = []
## Driver per fighter: null for the human, else an object with next_input(sim).
var drivers: Array = []
## Fighter the camera follows and the keyboard drives.
var player := 0
## Optional scripted control, as in the test arena: func(fighter_index, tick) -> FighterInput.
var input_override: Callable

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
## fall back to DEFAULT_CONFIG.
func configure(match_config: Dictionary) -> void:
	assert(not is_inside_tree(), "configure the zone match before adding it to the tree")
	_apply_config(match_config)


func _apply_config(match_config: Dictionary) -> void:
	config = DEFAULT_CONFIG.duplicate(true)
	config.merge(match_config, true)
	zone_id = StringName(config.zone)


func _ready() -> void:
	if config.is_empty():
		_apply_config({})
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
	match_flow = MatchFlow.new(fighter_views.size())
	match_flow.spawn_points = spawn_positions()
	match_hud.sim = sim
	match_hud.flow = match_flow
	for i in fighter_views.size():
		match_hud.names.append(fighter_views[i].display_name)
		match_hud.team_colors.append(Color(fighter_views[i].energy_color, 1.0))
		match_hud.is_ai.append(drivers[i] != null)
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
		view.remember_previous_tick()
		fighter_views.append(view)
		teams.append(team)
		var is_ai := bool(entry.get("is_ai", false))
		drivers.append(_make_driver(i, int(entry.get("ai_level", 3))) if is_ai else null)
		if not is_ai and player < 0:
			player = i
	player = maxi(player, 0)
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
	Engine.time_scale = match_flow.time_scale()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	present_frame(Engine.get_physics_interpolation_fraction(), delta)


## Advances the sim one tick: keyboard for the player, drivers for AI slots.
func step_tick() -> void:
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
			inputs.append(_player_input.read_tick(camera.view_yaw(), camera.orbit,
				sim.fighters[i].is_grounded()))
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
	# Side-on exchange angle for melee exchanges and beam clashes (hybrid cam).
	var exchange := ExchangeCam.participants(sim, player)
	camera.set_exchange(PackedVector3Array([fighter_views[exchange[0]].position, fighter_views[exchange[1]].position]) 		if exchange.size() == 2 else PackedVector3Array())
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
