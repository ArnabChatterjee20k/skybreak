extends Node3D
## Cycles the procedural Kael through every FighterState state, every move of his move set (sim
## timing, the charged smash with its hold) and every clip, while the camera orbits slowly.

const STATE_TICKS := 120
const ATTACK_REPEATS := 2
const ORBIT_SPEED := 0.25

var _fighter := FighterState.new()
var _steps: Array[Dictionary] = []
var _step := 0
var _tick := 0
var _yaw := 0.6

@onready var _view: ProceduralKaelView = $ProceduralKael
@onready var _camera: Camera3D = $Camera3D
@onready var _label: Label = $Label


func _ready() -> void:
	for state_name: String in FighterState.State.keys():
		if state_name != "ATTACKING":
			_steps.append({"label": "state " + state_name, "state": FighterState.State[state_name]})
	var moves: MoveSet = load("res://game/combat/moves/kael/kael_move_set.tres")
	var list: Array[MoveData] = []
	list.append_array(moves.light_string)
	list.append_array([moves.smash, moves.breaker, moves.launcher, moves.rising, moves.spike, moves.sweep,
		moves.push_block])
	for move in list:
		_steps.append({"label": "move " + move.id, "move": move})
	for level in moves.charged_smash.size():
		_steps.append({"label": "charge hold → " + moves.charged_smash[level].id, "move": moves.smash,
			"hold": moves.smash.charge_level_ticks[level] + 10, "release": moves.charged_smash[level]})
	for clip in ProceduralKaelView.CLIPS:
		_steps.append({"label": "clip " + clip, "clip": clip})
	_begin()


func _physics_process(_delta: float) -> void:
	var step := _steps[_step]
	_tick += 1
	if step.has("clip"):
		var length := _view.clip_ticks(step.clip) + 1
		_view.pose_at(step.clip, _tick % length)
		if _tick >= length * 2:
			_next()
	elif step.has("move"):
		_advance_attack(step)
	else:
		_fighter.state_ticks = _tick
		_fighter.velocity = Vector3(0, 0, -12) if _tick > STATE_TICKS / 2 else Vector3.ZERO
		_view.apply_state(_fighter, 1.0 / 60.0)
		if _tick >= STATE_TICKS:
			_next()


func _process(delta: float) -> void:
	_yaw += delta * ORBIT_SPEED
	var target := Vector3(0, 0.1, 0)
	_camera.position = target + Vector3(-sin(_yaw), 0.15, -cos(_yaw)) * 4.2
	_camera.look_at(target)
	_label.text = "%s   tick %d" % [_steps[_step].label, _tick]


func _advance_attack(step: Dictionary) -> void:
	var hold: int = step.get("hold", 0)
	if hold > 0 and _fighter.holding_charge:
		_fighter.charge_ticks = _tick
		if _tick >= hold:
			_fighter.begin_move(step.release)
	elif _fighter.move != null:
		_fighter.move_tick += 1
		if _fighter.move_tick >= _fighter.move.total_ticks():
			step["repeat"] = int(step.get("repeat", 0)) + 1
			if step.repeat >= ATTACK_REPEATS:
				_next()
				return
			_begin()
	_view.apply_state(_fighter, 1.0 / 60.0)


func _next() -> void:
	_step = (_step + 1) % _steps.size()
	_steps[_step].erase("repeat")
	_begin()


func _begin() -> void:
	_tick = 0
	_fighter = FighterState.new()
	_fighter.health = 1
	var step := _steps[_step]
	if step.has("state"):
		_fighter.enter_state(step.state)
	elif step.has("move"):
		_fighter.begin_move(step.move)
		if step.has("hold"):
			_fighter.holding_charge = true
	_view.apply_state(_fighter, 0.0)
