class_name FighterView
extends Node3D
## Draws one fighter from sim state: a placeholder capsule with a visor that
## shows its facing. It leans into its movement and hides while vanished.
## Interpolates between the last two sim ticks so it is smooth at any fps.

## Lean at full speed, in radians. Dashes lean harder. Only for the capsule and characters
## without MotionLayers: a character with layers leans its own body (one lean source, see
## game/characters/motion/README.md), so the body node stays upright.
const MAX_LEAN := deg_to_rad(18.0)
const MAX_DASH_LEAN := deg_to_rad(32.0)
## Speed (m/s) that gives full lean when not dashing.
const FULL_LEAN_SPEED := 30.0
## How fast the lean catches up with its goal, per second.
const LEAN_SHARPNESS := 10.0

@export var body_color := Color(0.9, 0.4, 0.15)
## Character model (a CharacterView scene). Empty draws the placeholder capsule.
@export var character_scene: PackedScene
## Energy colour for the character's rim; alpha is the blend. Its rgb is also
## the team colour of the height marker.
@export var energy_color := Color(1.0, 0.55, 0.2, 0.0)
## Name on the HUD plate (e.g. "KAEL"); empty shows "P1", "P2"...
@export var display_name := ""
## Team recolour of the character (part name -> Color), see FighterPalette.
@export var palette: Dictionary = {}
## Roster id (e.g. &"kael"); when set it picks character_scene and, unless
## palette is set, the slot's palette. The arena spawns the sim fighter from it too.
@export var character_id: StringName = &""
## Player slot (0 = P1); picks the roster palette.
@export var slot: int = 0

## The roster character drawn, or null for a hand-set scene or the capsule.
var character: RosterCharacter

## The sim state this view draws; set before the first frame.
var fighter: FighterState

var _previous_position := Vector3.ZERO
var _previous_yaw := 0.0
var _lean := Vector2.ZERO
var _body: Node3D
var _character: CharacterView
var _height_marker := HeightMarker.new()


func _ready() -> void:
	character = Roster.character(character_id) if character_id != &"" else null
	if character != null:
		character_scene = character.scene
		if palette.is_empty():
			palette = character.palette_for(slot)
	_body = Node3D.new()
	add_child(_body)
	_height_marker.color = Color(energy_color, 1.0)
	add_child(_height_marker)
	if character_scene != null:
		_character = character_scene.instantiate() as CharacterView
		_body.add_child(_character)
		FighterPalette.apply(_character, palette)
		_character.set_energy_color(energy_color)
		return
	var capsule := MeshInstance3D.new()
	capsule.mesh = CapsuleMesh.new()
	capsule.material_override = _material(body_color)
	_body.add_child(capsule)
	var visor := MeshInstance3D.new()
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.45, 0.18, 0.2)
	visor.mesh = visor_mesh
	visor.position = Vector3(0, 0.55, -0.42)
	visor.material_override = _material(Color(0.1, 0.1, 0.12))
	_body.add_child(visor)


## Sim stats for this view's character; null means the sim's default.
func fighter_stats() -> FighterStats:
	return character.stats if character != null else null


## Call once per sim tick, before the sim advances.
func remember_previous_tick() -> void:
	_previous_position = fighter.position
	_previous_yaw = fighter.facing_yaw


## Call once per sim tick, after the sim advanced: the character flinches at this tick's hits
## and blocks on fighter index and looks at its lock-on target. View-only.
func react_to_tick(sim: CombatSim, index: int) -> void:
	if _character == null:
		return
	for event: Dictionary in sim.events:
		if event.get("target", -1) == index:
			_character.react_to_event(event, fighter)
	var target := fighter.lock_on_target
	if target >= 0 and target < sim.fighters.size():
		_character.set_look_target(sim.fighters[target].position)
	else:
		_character.set_look_target(Vector3.ZERO, 0.0)


## Call every rendered frame. blend: 0 = previous tick, 1 = latest tick.
func present(blend: float, delta: float) -> void:
	position = _previous_position.lerp(fighter.position, blend)
	var yaw := lerp_angle(_previous_yaw, fighter.facing_yaw, blend)
	var dashing := fighter.state == FighterState.State.DASHING
	var goal := Vector2.ZERO if leans_itself() else lean_for(fighter.velocity, fighter.facing_yaw,
		MAX_DASH_LEAN if dashing else MAX_LEAN)
	_lean = _lean.lerp(goal, 1.0 - exp(-LEAN_SHARPNESS * delta))
	_body.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, _lean.x) * Basis(Vector3.BACK, _lean.y)
	visible = fighter.state != FighterState.State.VANISHING
	_height_marker.update(position)
	if _character != null:
		_character.apply_state(fighter, delta)


## True when the character model leans its own body (MotionLayers), so the body node doesn't.
func leans_itself() -> bool:
	return _character != null and _character.layers != null


## Lean angles for a velocity: x = pitch (negative leans forward),
## y = roll (negative leans right). Full lean at FULL_LEAN_SPEED and above.
static func lean_for(velocity: Vector3, facing_yaw: float, max_lean: float) -> Vector2:
	var local := Basis(Vector3.UP, facing_yaw).inverse() * velocity
	var forward := clampf(-local.z / FULL_LEAN_SPEED, -1.0, 1.0)
	var right := clampf(local.x / FULL_LEAN_SPEED, -1.0, 1.0)
	return Vector2(-forward * max_lean, -right * max_lean)


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
