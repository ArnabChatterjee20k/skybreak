extends Node3D
## Grey-box arena: runs the combat sim at the physics tick and draws each
## fighter through a FighterView, interpolated between the last two sim states.

const FIGHTER_STARTS: Array[Vector3] = [Vector3(0, 1, 6), Vector3(0, 1, -6)]

var sim := CombatSim.new()
## Optional scripted control for benchmarks and bot playtests:
## func(fighter_index: int, tick: int) -> FighterInput. Replaces keyboard and idle input.
var input_override: Callable

@onready var _player_input: KeyboardMouseInput = $KeyboardMouseInput
@onready var _fighter_views: Array[FighterView] = [$Fighter1, $Fighter2]
@onready var _camera: FighterCamera = $FighterCamera


func _ready() -> void:
	for i in FIGHTER_STARTS.size():
		_fighter_views[i].fighter = sim.add_fighter(FIGHTER_STARTS[i])
		_fighter_views[i].remember_previous_tick()
	sim.lock_everyone_onto_nearest()
	$DebugOverlay.sim = sim


func _physics_process(_delta: float) -> void:
	for view in _fighter_views:
		view.remember_previous_tick()
	var inputs: Array[FighterInput] = []
	if input_override.is_valid():
		for i in sim.fighters.size():
			inputs.append(input_override.call(i, sim.current_tick))
	else:
		inputs.append(_player_input.read_tick(_camera.view_yaw(), _camera.orbit))
		inputs.append(FighterInput.new())
	sim.tick(inputs)


func _process(delta: float) -> void:
	var blend := Engine.get_physics_interpolation_fraction()
	for view in _fighter_views:
		view.present(blend, delta)
	var player := sim.fighters[0]
	var locked := player.lock_on_target >= 0
	var target := _fighter_views[player.lock_on_target].position if locked else Vector3.ZERO
	_camera.follow(_fighter_views[0].position, target, locked, delta)
