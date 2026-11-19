class_name VfxOcclusionRig
extends Node
## Renders a scripted exchange through the real CombatFeedback and measures how much of
## each fighter's head and torso the effects wash out. Two cameras share one world: one
## sees the fighters only (the ID mask), the other the fighters plus every effect.
## Needs a real renderer (e.g. gl_compatibility under xvfb); headless renders nothing.

const SIZE := Vector2i(640, 360)
## Render layer the effects are moved to, so the mask camera can leave them out.
const VFX_LAYER := 2
## A pixel counts as covered when an effect shifts any channel by this much (0-1).
const COVERED_DELTA := 0.3
## Proxy body: torso capsule and head sphere around the capsule centre (about 2 m tall).
const TORSO_RADIUS := 0.24
const TORSO_HEIGHT := 0.8
const TORSO_Y := 0.25
const HEAD_RADIUS := 0.15
const HEAD_Y := 0.82
## ID colours of each fighter's head and torso in the mask.
const IDS: Array[Color] = [Color(0.6, 0.1, 0.1), Color(0.1, 0.1, 0.6)]
const LEGS := Color(0.3, 0.3, 0.3)
const BACKDROP := Color(0.36, 0.42, 0.38)
## Hurtbox radius the sim puts contacts on.
const HURT_RADIUS := 0.42
## Every scripted beat: event type, hitstop ticks and whether it counts as a counter.
const SCENARIOS := {
	&"light": [CombatSim.EventType.HIT, 4, false],
	&"heavy": [CombatSim.EventType.HIT, 9, false],
	&"counter": [CombatSim.EventType.COUNTER, 9, true],
	&"guard_break": [CombatSim.EventType.GUARD_BREAK, 14, false],
	&"ko": [CombatSim.EventType.KO, 20, false],
}
## KO: the loser's launch (m/s) and gravity, and the slow-mo the match flow applies.
const KO_LAUNCH := Vector3(0.0, 5.0, -8.0)
const KO_GRAVITY := 14.0
const KO_TIME_SCALE := 0.3
const KO_SLOW_TICKS := 60

## Read by MatchVfx through its ancestors.
var sim: CombatSim
var feedback: CombatFeedback
var full: SubViewport
var mask: SubViewport

var _cameras: Array[Camera3D] = []
var _bodies: Array[Node3D] = []
var _scenario: StringName = &""
var _frame := 0
var _loser_velocity := Vector3.ZERO
var _freeze_left := 0.0


func _ready() -> void:
	sim = CombatSim.new(11)
	sim.add_fighter(Vector3(0.0, 1.0, 0.8))
	sim.add_fighter(Vector3(0.0, 1.0, -0.8))
	full = _viewport()
	mask = _viewport()
	var world := World3D.new()
	full.world_3d = world
	mask.world_3d = world
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKDROP
	for view: SubViewport in [full, mask]:
		var camera := Camera3D.new()
		camera.fov = 60.0
		camera.environment = environment
		camera.cull_mask = 1 | (1 << (VFX_LAYER - 1)) if view == full else 1
		view.add_child(camera)
		camera.current = true
		_cameras.append(camera)
	for i in 2:
		var body := _body(IDS[i])
		full.add_child(body)
		_bodies.append(body)
	feedback = CombatFeedback.new()
	full.add_child(feedback)
	var hud := CanvasLayer.new()
	full.add_child(hud)
	var impact_frame: ImpactFrame = preload("res://game/view/shaders/screen/impact_frame.tscn").instantiate()
	hud.add_child(impact_frame)
	feedback.impact_frame = impact_frame
	_place()


## Starts one scripted beat: the attacker (0) hits the target (1) at the target's chest.
func play(scenario: StringName) -> void:
	_scenario = scenario
	_frame = 0
	sim.fighters[0].position = Vector3(0.0, 1.0, 0.8)
	sim.fighters[1].position = Vector3(0.0, 1.0, -0.8)
	_place()
	var spec: Array = SCENARIOS[scenario]
	var target := sim.fighters[1].position
	var contact := target + Vector3.UP * TORSO_Y + (sim.fighters[0].position - target).normalized() * HURT_RADIUS
	var event := {"type": spec[0], "attacker": 0, "target": 1, "position": contact, "hitstop": spec[1],
		"move_id": &"heavy_1", "damage": 120, "counter": spec[2]}
	_loser_velocity = KO_LAUNCH
	_freeze_left = float(spec[1]) / 60.0
	if scenario == &"ko":
		Engine.time_scale = KO_TIME_SCALE
	var events: Array[Dictionary] = [event]
	feedback.react(events)
	_tag_effects()


## Moves the scripted world one rendered frame on (call before each capture).
func advance_frame() -> void:
	_frame += 1
	var fixed := 1.0 / 60.0
	if _scenario == &"ko":
		if _frame * KO_TIME_SCALE >= KO_SLOW_TICKS:
			Engine.time_scale = 1.0
		var dt := fixed * Engine.time_scale
		if _freeze_left > 0.0:
			_freeze_left -= dt
		else:
			var loser := sim.fighters[1]
			_loser_velocity.y -= KO_GRAVITY * dt
			loser.position += _loser_velocity * dt
			if loser.position.y < 0.3:
				loser.position.y = 0.3
				_loser_velocity = Vector3.ZERO
	# The pools hand out effects lazily; keep every one of them on the effect layer.
	feedback.vfx.react([] as Array[Dictionary])
	_tag_effects()
	_place()


## Ends a beat and resets the clock.
func finish() -> void:
	Engine.time_scale = 1.0


## The two renders of the current frame: [full, mask].
func capture() -> Array[Image]:
	await RenderingServer.frame_post_draw
	return [full.get_texture().get_image(), mask.get_texture().get_image()]


## Per fighter: covered share (0-1) of its visible head/torso pixels, and the pixel count.
static func coverage(images: Array[Image]) -> Array[Vector2]:
	var shown: Image = images[0]
	var ids: Image = images[1]
	var counts: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	for y in ids.get_height():
		for x in ids.get_width():
			var id := ids.get_pixel(x, y)
			var who := _who(id)
			if who < 0:
				continue
			var over := shown.get_pixel(x, y)
			var delta := maxf(absf(over.r - id.r), maxf(absf(over.g - id.g), absf(over.b - id.b)))
			counts[who] += Vector2(1.0 if delta >= COVERED_DELTA else 0.0, 1.0)
	var result: Array[Vector2] = []
	for c in counts:
		result.append(Vector2(c.x / c.y if c.y > 0.0 else 1.0, c.y))
	return result


static func _who(id: Color) -> int:
	for i in IDS.size():
		var want := IDS[i]
		if absf(id.r - want.r) < 0.06 and absf(id.g - want.g) < 0.06 and absf(id.b - want.b) < 0.06:
			return i
	return -1


func _place() -> void:
	for i in 2:
		_bodies[i].position = sim.fighters[i].position
	var a := sim.fighters[0].position
	var b := sim.fighters[1].position
	var middle := (a + b) * 0.5 + Vector3.UP * 0.3
	var spread := maxf(a.distance_to(b), 1.6)
	# Three-quarter fight camera that pulls back as the fighters separate.
	var eye := middle + Vector3(4.2, 1.2, 2.2).normalized() * (3.6 + spread * 1.1)
	for camera in _cameras:
		camera.look_at_from_position(eye, middle)


func _tag_effects() -> void:
	for node in feedback.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).layers = 1 << (VFX_LAYER - 1)


func _viewport() -> SubViewport:
	var view := SubViewport.new()
	view.size = SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	return view


func _body(id: Color) -> Node3D:
	var root := Node3D.new()
	var torso := CapsuleMesh.new()
	torso.radius = TORSO_RADIUS
	torso.height = TORSO_HEIGHT
	var head := SphereMesh.new()
	head.radius = HEAD_RADIUS
	head.height = HEAD_RADIUS * 2.0
	var legs := CapsuleMesh.new()
	legs.radius = 0.14
	legs.height = 0.95
	for part: Array in [[torso, TORSO_Y, id], [head, HEAD_Y, id], [legs, -0.55, LEGS]]:
		var instance := MeshInstance3D.new()
		instance.mesh = part[0]
		instance.position.y = part[1]
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = part[2]
		instance.material_override = material
		root.add_child(instance)
	return root
