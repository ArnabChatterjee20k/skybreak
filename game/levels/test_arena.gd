extends Node3D
## Grey-box arena: runs the combat sim at the physics tick and draws each
## fighter through a FighterView, interpolated between the last two sim states.
## Scripts (benchmarks, scripted playtests) can turn off processing and call
## step_tick() and present_frame() themselves to run faster than real time.

const FIGHTER_STARTS: Array[Vector3] = [Vector3(0, 1, 6), Vector3(0, 1, -6)]

var sim := CombatSim.new()
## Optional scripted control for benchmarks and bot playtests:
## func(fighter_index: int, tick: int) -> FighterInput. Replaces keyboard and idle input.
var input_override: Callable

## Compiles VFX at load behind a loading cover; scripts can await
## vfx_prewarm.finished (or check is_finished) before capturing frames.
var vfx_prewarm := VfxPrewarm.new()
## Hit sparks, shake and impact frames from sim.events (T-121).
var combat_feedback := CombatFeedback.new()
var combo_counter := ComboCounter.new()
## Rounds, clock, intro and KO (T-126). Scripted playtests turn it off
## (match_flow.enabled = false) so input is never held for an intro.
var match_flow := MatchFlow.new(FIGHTER_STARTS.size())
var match_hud := MatchHud.new()
## Sound for sim events and fighter states (T-D20).
var match_audio := MatchAudio.new()
## Pickups, projectiles and weapons in hand (T-D14).
var weapon_layer := WeaponLayer.new()

@onready var camera: FighterCamera = $FighterCamera
@onready var opponent_marker: OpponentMarker = $Hud/OpponentMarker
@onready var _player_input: KeyboardMouseInput = $KeyboardMouseInput
@onready var _fighter_views: Array[FighterView] = [$Fighter1, $Fighter2]


func _ready() -> void:
	for i in FIGHTER_STARTS.size():
		_fighter_views[i].fighter = sim.add_fighter(FIGHTER_STARTS[i], _fighter_views[i].fighter_stats())
		_fighter_views[i].remember_previous_tick()
	sim.lock_everyone_onto_nearest()
	sim.pickups_enabled = true
	add_child(weapon_layer)
	weapon_layer.setup(sim, _fighter_views)
	$DebugOverlay.sim = sim
	opponent_marker.camera = camera
	add_child(combat_feedback)
	combat_feedback.camera = camera
	var impact_frame: ImpactFrame = preload("res://game/view/shaders/screen/impact_frame.tscn").instantiate()
	$Hud.add_child(impact_frame)
	combat_feedback.impact_frame = impact_frame
	$Hud.add_child(combo_counter)
	match_hud.sim = sim
	match_hud.flow = match_flow
	for view in _fighter_views:
		match_hud.names.append(view.display_name)
		match_hud.team_colors.append(Color(view.energy_color, 1.0))
	$Hud.add_child(match_hud)
	add_child(vfx_prewarm)
	match_audio.sim = sim
	add_child(match_audio)
	# After the first frame so the camera has its starting pose. A method,
	# not a lambda: deferred calls on a freed arena are then simply dropped.
	_start_prewarm.call_deferred()


func _start_prewarm() -> void:
	vfx_prewarm.start(camera)


func _physics_process(_delta: float) -> void:
	step_tick()
	# Slow motion after a KO; only when the arena runs in real time.
	Engine.time_scale = match_flow.time_scale()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	present_frame(Engine.get_physics_interpolation_fraction(), delta)


## Advances the sim by one tick with keyboard (or scripted) input.
func step_tick() -> void:
	for view in _fighter_views:
		view.remember_previous_tick()
	weapon_layer.remember_previous_tick()
	var inputs: Array[FighterInput] = []
	if not match_flow.accepts_input():
		# Intro and KO: everyone holds still.
		for i in sim.fighters.size():
			inputs.append(FighterInput.new())
	elif input_override.is_valid():
		for i in sim.fighters.size():
			inputs.append(input_override.call(i, sim.current_tick))
	else:
		inputs.append(_player_input.read_tick(camera.view_yaw(), camera.orbit))
		inputs.append(FighterInput.new())
	sim.tick(inputs)
	# sim.events holds only this tick's events, so read them every tick.
	combat_feedback.react(sim.events)
	for i in _fighter_views.size():
		_fighter_views[i].react_to_tick(sim, i)
	match_flow.step(sim)
	match_audio.after_tick()


## Draws one frame: fighters at blend between the last two ticks, then the camera.
func present_frame(blend: float, delta: float) -> void:
	for view in _fighter_views:
		view.present(blend, delta)
	weapon_layer.present(blend, delta)
	var player := sim.fighters[0]
	var locked := player.lock_on_target >= 0
	var opponent := _fighter_views[player.lock_on_target if locked else 1].position
	camera.follow(_fighter_views[0].position, opponent, locked, delta)
	for view in _fighter_views:
		view.fade_for_camera(camera.global_position)
	opponent_marker.target = opponent
	opponent_marker.origin = _fighter_views[0].position
	opponent_marker.locked = locked
	combo_counter.show_combo(sim.fighters, delta)
