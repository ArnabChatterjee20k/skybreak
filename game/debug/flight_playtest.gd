class_name FlightPlaytest
extends RefCounted
## Plays one FlightScenarios route through a test arena faster than real time:
## each advance() runs one sim tick and one presented frame (1/60 s) using the
## arena's own code, then records what the camera shows.

const FRAME_SECONDS := 1.0 / 60.0
## Height of the placeholder fighter, for its on-screen size.
const FIGHTER_HEIGHT := 2.0
const FIGHTER_RADIUS := 0.5

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
## camera_distance (to the player, m), view_pitch (radians, negative = down),
## opponent_hidden (fraction of the opponent's screen box the player covers),
## opponent_pixels (opponent's on-screen height at 1080p), silhouette_gap
## (horizontal space between the two fighters' screen boxes as a fraction of
## the screen width; negative when they overlap), band (the camera's
## LockOnFraming.Band), player_visible (false while vanished).
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
		"opponent_hidden": opponent_hidden_fraction(view, camera.fov, screen, player, opponent),
		"opponent_pixels": _screen_box(view, camera.fov, screen, opponent).size.y,
		"silhouette_gap": silhouette_gap(view, camera.fov, screen, player, opponent),
		"band": camera.range_band(),
		"player_visible": arena.sim.fighters[0].state != FighterState.State.VANISHING,
	}


## Horizontal gap between the fighters' screen boxes / screen width (< 0 = overlap).
static func silhouette_gap(view: Transform3D, fov: float, screen: Vector2,
		player: Vector3, opponent: Vector3) -> float:
	var a := _screen_box(view, fov, screen, player)
	var b := _screen_box(view, fov, screen, opponent)
	if not a.has_area() or not b.has_area():
		return 1.0
	var gap := maxf(b.position.x - a.end.x, a.position.x - b.end.x)
	return gap / screen.x


## How much of the opponent's on-screen box the player's box covers (0..1),
## counting only when the player is in front of the opponent.
static func opponent_hidden_fraction(view: Transform3D, fov: float, screen: Vector2,
		player: Vector3, opponent: Vector3) -> float:
	var player_box := _screen_box(view, fov, screen, player)
	var opponent_box := _screen_box(view, fov, screen, opponent)
	if not player_box.has_area() or not opponent_box.has_area():
		return 0.0
	var player_depth := -(view.affine_inverse() * player).z
	var opponent_depth := -(view.affine_inverse() * opponent).z
	if player_depth >= opponent_depth:
		return 0.0
	return player_box.intersection(opponent_box).get_area() / opponent_box.get_area()


## Screen rectangle of a standing fighter capsule, or an empty rect if behind.
static func _screen_box(view: Transform3D, fov: float, screen: Vector2, centre: Vector3) -> Rect2:
	var local := view.affine_inverse() * centre
	if local.z >= -0.1:
		return Rect2()
	var placement := OpponentMarker.placement(view, fov, screen, centre)
	var pixels_per_metre := screen.y * 0.5 / (-local.z * tan(deg_to_rad(fov) / 2.0))
	var half := Vector2(FIGHTER_RADIUS, FIGHTER_HEIGHT * 0.5) * pixels_per_metre
	var at: Vector2 = Vector2(local.x, -local.y) * pixels_per_metre + screen * 0.5
	return Rect2(at - half, half * 2.0)


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
