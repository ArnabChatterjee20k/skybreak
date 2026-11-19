extends Node3D
## Grey-box arena: runs the combat sim at the physics tick and draws each
## fighter as a capsule, interpolated between the last two sim states.

const FIGHTER_STARTS: Array[Vector3] = [Vector3(0, 1, 6), Vector3(0, 1, -6)]

var sim := CombatSim.new()

var _previous_positions: Array[Vector3] = []

@onready var _player_input: KeyboardMouseInput = $KeyboardMouseInput
@onready var _fighter_views: Array[Node3D] = [$Fighter1, $Fighter2]
@onready var _camera: FighterCamera = $FighterCamera


func _ready() -> void:
	for start in FIGHTER_STARTS:
		sim.add_fighter(start)
		_previous_positions.append(start)
	sim.lock_everyone_onto_nearest()
	$DebugOverlay.sim = sim


func _physics_process(_delta: float) -> void:
	for i in sim.fighters.size():
		_previous_positions[i] = sim.fighters[i].position
	var inputs: Array[FighterInput] = [
		_player_input.read_tick(_camera.view_yaw(), _camera.orbit),
		FighterInput.new(),
	]
	sim.tick(inputs)


func _process(delta: float) -> void:
	var blend := Engine.get_physics_interpolation_fraction()
	for i in _fighter_views.size():
		_fighter_views[i].position = _previous_positions[i].lerp(sim.fighters[i].position, blend)
	var player := sim.fighters[0]
	var locked := player.lock_on_target >= 0
	var target := _fighter_views[player.lock_on_target].position if locked else Vector3.ZERO
	_camera.follow(_fighter_views[0].position, target, locked, delta)
