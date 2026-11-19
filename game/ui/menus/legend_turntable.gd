class_name LegendTurntable
extends SubViewportContainer
## A legend's CharacterView in its own little lit world: a slowly turning live
## model, or a portrait rendered once for cards.

const IDLE_STATE := FighterState.State.IDLE
## Turntable speed (radians per second) when live.
const TURN_SPEED := 0.45

var legend: StringName = &""
var live := true
## FighterState shown: IDLE in menus, CHARGING for the winner pose.
var pose: FighterState.State = IDLE_STATE
## Camera framing: full body or a head-and-shoulders portrait.
var portrait := false
var character_view: CharacterView
var viewport: SubViewport

var _fighter := FighterState.new()
var _pivot: Node3D
var _camera: Camera3D
var _tick_time := 0.0


func _init(legend_id: StringName = &"", is_live := true, is_portrait := false, pixel_size := Vector2i(512, 640)) -> void:
	legend = legend_id
	live = is_live
	portrait = is_portrait
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.size = pixel_size
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_ONCE
	add_child(viewport)
	_build_stage()


func _ready() -> void:
	set_legend(legend)


## Swaps the model shown.
func set_legend(id: StringName) -> void:
	legend = id
	if character_view != null:
		character_view.queue_free()
		character_view = null
	var entry := LegendCatalog.character(id)
	if entry == null or entry.scene == null:
		return
	character_view = entry.scene.instantiate() as CharacterView
	if character_view == null:
		return
	_pivot.add_child(character_view)
	character_view.set_energy_color(Color(LegendCatalog.color(id), 0.55 if pose == FighterState.State.CHARGING else 0.0))
	_fighter.state = pose
	_fighter.state_ticks = 0
	_pivot.rotation.y = -0.45 if portrait else -0.35
	if not live:
		_present(0.0)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func set_pose(state: FighterState.State) -> void:
	pose = state
	set_legend(legend)


func _process(delta: float) -> void:
	if not live or character_view == null:
		return
	_pivot.rotation.y += TURN_SPEED * delta * (0.0 if portrait else 1.0)
	_present(delta)


## Advances the fake fighter at the sim rate and poses the model.
func _present(delta: float) -> void:
	_tick_time += delta
	while _tick_time >= 1.0 / CombatSim.TICKS_PER_SECOND:
		_tick_time -= 1.0 / CombatSim.TICKS_PER_SECOND
		_fighter.state_ticks += 1
	character_view.apply_state(_fighter, delta)


func _build_stage() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.6, 0.8)
	environment.ambient_light_energy = 0.7
	env.environment = environment
	viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.6, -0.5, 0)
	key.light_energy = 1.3
	viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.2, 2.6, 0)
	rim.light_color = Color(0.6, 0.8, 1.0)
	rim.light_energy = 0.9
	viewport.add_child(rim)
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	viewport.add_child(_camera)
	# CharacterView: origin at the capsule centre, about 2 m tall, facing -Z.
	if portrait:
		_camera.position = Vector3(0, 0.55, -3.2)
		_camera.look_at_from_position(_camera.position, Vector3(0, 0.45, 0))
	else:
		_camera.position = Vector3(0, 0.3, -4.9)
		_camera.look_at_from_position(_camera.position, Vector3(0, 0.0, 0))
	_camera.current = true
