extends Node3D
## Preview only: cycles a character through every mapped state and Kael move
## on a fake FighterState at 60 ticks a second. Space skips, Left/Right turns.

const MOVE_SET_PATH := "res://game/combat/moves/kael/kael_move_set.tres"
const STATE_SECONDS := 2.0
## Ticks shown after a move ends before the next entry.
const MOVE_TAIL_TICKS := 20
const KAEL_ENERGY := Color(1.0, 0.6, 0.2, 0.6)

@export var character_scene: PackedScene

var _fighter := FighterState.new()
var _view: CharacterView
var _entries: Array[Dictionary] = []
var _index := -1
var _entry_ticks := 0
var _tick_time := 0.0
@onready var _body: Node3D = $Body
@onready var _label: Label = $Overlay/Label


func _ready() -> void:
	_view = character_scene.instantiate() as CharacterView
	_body.add_child(_view)
	_view.set_energy_color(KAEL_ENERGY)
	_entries = preview_entries(load(MOVE_SET_PATH) as MoveSet)
	# Command line (after --): closeup, start=<entry number>.
	var args := OS.get_cmdline_user_args()
	if args.has("closeup"):
		$Camera3D.position = Vector3(0.45, 1.75, -1.1)
		$Camera3D.look_at(Vector3(0, 1.62, 0))
	else:
		$Camera3D.look_at(Vector3(0, 0.9, 0))
	for arg in args:
		if arg.begins_with("start="):
			_index = int(arg.trim_prefix("start=")) - 2
	_next_entry()


## Every state the sim has (by name, so later states show up) and every move.
static func preview_entries(move_set: MoveSet) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for state_name: String in FighterState.State.keys():
		if state_name == "ATTACKING":
			continue
		entries.append({"label": state_name, "state": FighterState.State[state_name]})
		if state_name == "FLYING":
			entries.append({"label": "FLYING fast", "state": FighterState.State.FLYING, "velocity": Vector3(0, 0, -25)})
		if state_name == "MOVING":
			entries.append({"label": "blocking", "state": FighterState.State.IDLE, "blocking": true})
	var moves: Array[MoveData] = []
	moves.append_array(move_set.light_string)
	moves.append_array([move_set.smash, move_set.breaker, move_set.launcher, move_set.rising,
		move_set.spike, move_set.sweep, move_set.push_block])
	moves.append_array(move_set.charged_smash)
	for move in moves:
		entries.append({"label": "ATTACKING " + String(move.id), "state": FighterState.State.ATTACKING, "move": move})
	if move_set.smash.can_charge():
		entries.append({"label": "ATTACKING smash (hold)", "state": FighterState.State.ATTACKING, "move": move_set.smash, "hold": true})
	return entries


func _process(delta: float) -> void:
	_tick_time += delta
	while _tick_time >= 1.0 / 60.0:
		_tick_time -= 1.0 / 60.0
		_step_tick()
	_view.apply_state(_fighter, delta)
	_label.text = "%d/%d  %s\nclip: %s  %s" % [_index + 1, _entries.size(), _entries[_index].label,
		_view.current_clip(), _phase_text()]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE: _next_entry()
			KEY_LEFT: _body.rotate_y(deg_to_rad(-30))
			KEY_RIGHT: _body.rotate_y(deg_to_rad(30))


func _step_tick() -> void:
	_entry_ticks += 1
	_fighter.state_ticks += 1
	var entry := _entries[_index]
	var move: MoveData = entry.get("move")
	if move and not entry.get("hold", false):
		_fighter.move_tick = mini(_fighter.move_tick + 1, move.total_ticks() - 1)
		if _entry_ticks >= move.total_ticks() + MOVE_TAIL_TICKS:
			_next_entry()
	elif move:
		_fighter.charge_ticks += 1
		if _entry_ticks >= int(STATE_SECONDS * 60):
			_next_entry()
	elif _entry_ticks >= int(STATE_SECONDS * 60):
		_next_entry()


func _next_entry() -> void:
	_index = (_index + 1) % _entries.size()
	_entry_ticks = 0
	var entry := _entries[_index]
	_fighter = FighterState.new()
	var move: MoveData = entry.get("move")
	if move:
		_fighter.begin_move(move)
		_fighter.holding_charge = entry.get("hold", false)
	else:
		_fighter.enter_state(entry.state)
		# Stun states (HITSTUN, BLOCKSTUN, KNOCKDOWN) last the whole entry.
		_fighter.stun_ticks = int(STATE_SECONDS * 60)
	_fighter.velocity = entry.get("velocity", Vector3.ZERO)
	if entry.state == FighterState.State.MOVING:
		_fighter.velocity = Vector3(0, 0, -12)
	_fighter.blocking = entry.get("blocking", false)


func _phase_text() -> String:
	if _fighter.move == null:
		return ""
	return "%s tick %d" % [FighterState.AttackPhase.find_key(_fighter.attack_phase()), _fighter.move_tick]
