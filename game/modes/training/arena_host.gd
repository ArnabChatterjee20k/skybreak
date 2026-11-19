class_name ArenaHost
extends Node
## Hosts an instance of the test arena for a mode: picks the two characters,
## turns off the round flow and the arena's own tick, and steps it with the
## inputs the mode chooses. The arena scene itself stays untouched.

const ARENA_SCENE := preload("res://game/levels/test_arena.tscn")

## The arena instance; replaced by build().
var arena: Node3D
var sim: CombatSim

var _inputs: Array[FighterInput] = []


## (Re)builds the arena with these roster characters for P1 and P2.
func build(player_id: StringName, opponent_id: StringName) -> void:
	if arena != null:
		remove_child(arena)
		arena.queue_free()
	arena = ARENA_SCENE.instantiate() as Node3D
	_cast(arena.get_node("Fighter1"), player_id)
	_cast(arena.get_node("Fighter2"), opponent_id)
	add_child(arena)
	arena.match_flow.enabled = false
	arena.set_physics_process(false)
	arena.input_override = _input_for
	sim = arena.sim


## The local player's keyboard and mouse input for this tick. Call once per tick.
func read_player_input() -> FighterInput:
	var keyboard: KeyboardMouseInput = arena.get_node("KeyboardMouseInput")
	var camera: FighterCamera = arena.camera
	return keyboard.read_tick(camera.view_yaw(), camera.orbit)


## Advances the arena one tick with inputs (one per fighter).
func step(inputs: Array[FighterInput]) -> void:
	_inputs = inputs
	arena.step_tick()


func _input_for(fighter_index: int, _tick: int) -> FighterInput:
	return _inputs[fighter_index] if fighter_index < _inputs.size() else FighterInput.new()


static func _cast(view: FighterView, id: StringName) -> void:
	var character := Roster.character(id)
	if character == null:
		return
	view.character_id = id
	view.display_name = character.display_name.to_upper()
