class_name FlightPlaytest
extends RefCounted
## Plays one FlightScenarios route through a test arena faster than real time:
## each advance() runs one sim tick and one presented frame (1/60 s) using the
## arena's own code, then records what the camera shows.

const FRAME_SECONDS := 1.0 / 60.0
## Height of the placeholder fighter, for its on-screen size.
const FIGHTER_HEIGHT := 2.0

var arena: Node
var ticks: int
var tick := 0

var _plan: Callable
var _previous: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]


## arena must already be in the scene tree (its _ready has run).
func _init(arena_node: Node, scenario: Dictionary) -> void:
	arena = arena_node
	ticks = scenario.ticks
	_plan = scenario.plan
	arena.set_physics_process(false)
	arena.set_process(false)
	arena.input_override = _input_for


func is_finished() -> bool:
	return tick >= ticks


## Runs one tick and frame. Returns that frame's record:
## tick, locked, camera (Transform3D), fov, player, opponent (positions),
## player_on_screen, opponent_on_screen, player_screen_height (fraction),
## camera_distance (to the player, m), view_pitch (radians, negative = down).
func advance() -> Dictionary:
	arena.step_tick()
	arena.present_frame(1.0, FRAME_SECONDS)
	tick += 1
	var camera: FighterCamera = arena.camera
	var screen := Vector2(1920, 1080)
	var player: Vector3 = arena.get_node("Fighter1").position
	var opponent: Vector3 = arena.opponent_marker.target
	var view := camera.global_transform
	var player_local := view.affine_inverse() * player
	var depth := maxf(-player_local.z, 0.001)
	return {
		"tick": tick,
		"locked": arena.sim.fighters[0].lock_on_target >= 0,
		"camera": view,
		"fov": camera.fov,
		"player": player,
		"opponent": opponent,
		"player_on_screen": OpponentMarker.placement(view, camera.fov, screen, player).on_screen,
		"opponent_on_screen": OpponentMarker.placement(view, camera.fov, screen, opponent).on_screen,
		"player_screen_height": FIGHTER_HEIGHT / (2.0 * depth * tan(deg_to_rad(camera.fov) / 2.0)),
		"camera_distance": view.origin.distance_to(player),
		"view_pitch": asin(clampf(-view.basis.z.y, -1.0, 1.0)),
	}


## Plays the whole scenario and returns every frame's record.
func run() -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	while not is_finished():
		frames.append(advance())
	return frames


func _input_for(index: int, at_tick: int) -> FighterInput:
	var spec: Dictionary = _plan.call(index, at_tick)
	var input := FighterInput.from_held(spec.get("held", 0), _previous[index])
	input.move = spec.get("move", Vector2.ZERO)
	input.vertical = spec.get("vertical", 0)
	input.view_yaw = arena.camera.view_yaw()
	_previous[index] = input
	return input
