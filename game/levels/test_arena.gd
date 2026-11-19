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

@onready var camera: FighterCamera = $FighterCamera
@onready var opponent_marker: OpponentMarker = $Hud/OpponentMarker
@onready var _player_input: KeyboardMouseInput = $KeyboardMouseInput
@onready var _fighter_views: Array[FighterView] = [$Fighter1, $Fighter2]


func _ready() -> void:
	for i in FIGHTER_STARTS.size():
		_fighter_views[i].fighter = sim.add_fighter(FIGHTER_STARTS[i])
		_fighter_views[i].remember_previous_tick()
	sim.lock_everyone_onto_nearest()
	$DebugOverlay.sim = sim
	opponent_marker.camera = camera
	add_child(vfx_prewarm)
	# After the first frame so the camera has its starting pose.
	(func(): vfx_prewarm.start(camera)).call_deferred()


func _physics_process(_delta: float) -> void:
	step_tick()


func _process(delta: float) -> void:
	present_frame(Engine.get_physics_interpolation_fraction(), delta)


## Advances the sim by one tick with keyboard (or scripted) input.
func step_tick() -> void:
	for view in _fighter_views:
		view.remember_previous_tick()
	var inputs: Array[FighterInput] = []
	if input_override.is_valid():
		for i in sim.fighters.size():
			inputs.append(input_override.call(i, sim.current_tick))
	else:
		inputs.append(_player_input.read_tick(camera.view_yaw(), camera.orbit))
		inputs.append(FighterInput.new())
	sim.tick(inputs)


## Draws one frame: fighters at blend between the last two ticks, then the camera.
func present_frame(blend: float, delta: float) -> void:
	for view in _fighter_views:
		view.present(blend, delta)
	var player := sim.fighters[0]
	var locked := player.lock_on_target >= 0
	var opponent := _fighter_views[player.lock_on_target if locked else 1].position
	camera.follow(_fighter_views[0].position, opponent, locked, delta)
	opponent_marker.target = opponent
	opponent_marker.locked = locked
