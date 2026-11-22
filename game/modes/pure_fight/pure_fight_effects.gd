class_name PureFightEffects
extends Node3D
## Pure Fight presentation for sim events (GAME_DESIGN §16.5): voxel hit sparks and flashes
## scaled by strength, impact frames on heavy hits and counters, screen shake, dust on
## landings and knockdowns, speed lines on dashes, the finisher punch-in. Glow stays clamped
## (no white blobs): emission is capped and sparks are small cubes, not additive discs.

const Ev := PureFightSim.Ev
const MAX_BITS := 160
const COLORS := {
	"hit": Color(1.0, 0.82, 0.35), "counter": Color(1.0, 0.35, 0.2), "block": Color(0.45, 0.8, 1.0),
	"just": Color(0.35, 0.55, 1.0), "armor": Color(0.85, 0.85, 0.9), "dust": Color(0.62, 0.58, 0.52),
}

var sim: PureFightSim
var camera: SideCamera
var impact_frame: ImpactFrame
var speed_lines: ColorRect
## Called with a short text to flash on the HUD (counter, just defend, finisher name).
var callout: Callable
var _bits: Array[Dictionary] = []
var _cube := BoxMesh.new()
var _materials: Dictionary = {}
var _speed := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_cube.size = Vector3(0.07, 0.07, 0.07)
	for key in COLORS:
		var material := StandardMaterial3D.new()
		material.albedo_color = COLORS[key]
		material.emission_enabled = key != "dust"
		material.emission = COLORS[key]
		material.emission_energy_multiplier = 1.2
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if key != "dust" \
			else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_materials[key] = material
	_rng.seed = 5


func world(x_mm: int, y_mm: int) -> Vector3:
	return sim.line_origin + sim.line_dir * (x_mm / 1000.0) + Vector3.UP * (y_mm / 1000.0)


func react(events: Array) -> void:
	for event: Dictionary in events:
		var type: int = event.type
		var strength: int = event.strength
		var at := world(int(event.x), int(event.y))
		if event.t >= 0 and event.a >= 0:
			var attacker := sim.pf[int(event.a)]
			at = world((attacker.x + sim.pf[int(event.t)].x) / 2, int(event.y))
		match type:
			Ev.HIT, Ev.COUNTER, Ev.PUNISH, Ev.FINISHER_HIT:
				var counter := type != Ev.HIT
				_burst(at, "counter" if counter else "hit", 10 + strength * 8, 2.5 + strength)
				camera.shake(0.25 + strength * 0.3 + (0.3 if counter else 0.0))
				if strength >= 2 or counter:
					impact_frame.flash(2 if strength >= 3 or counter else 1, 0.7 + 0.1 * strength)
				if type == Ev.COUNTER:
					_say("COUNTER")
				elif type == Ev.PUNISH:
					_say("PUNISH")
			Ev.BLOCK:
				_burst(at, "block", 6 + strength * 3, 1.8)
				camera.shake(0.1 + strength * 0.08)
			Ev.JUST_DEFEND:
				_burst(at, "just", 14, 2.2)
				_say("JUST DEFEND")
			Ev.ARMOR:
				_burst(at, "armor", 10, 2.0)
				camera.shake(0.3)
				_say("ARMOR")
			Ev.COUNTER_STANCE:
				_burst(at, "counter", 22, 3.5)
				impact_frame.flash(2, 1.0)
				camera.shake(0.8)
				_say("STARGUARD!")
			Ev.THROW_TECH:
				_burst(at, "block", 12, 2.0)
				_say("TECH")
			Ev.WALL_BOUNCE:
				_burst(at, "hit", 16, 3.0)
				camera.shake(0.7)
				_say("WALL BOUNCE")
			Ev.GROUND_BOUNCE:
				_dust(world(int(event.x), 0), 14)
				camera.shake(0.6)
			Ev.KNOCKDOWN:
				_dust(world(int(event.x), 0), 10 + strength * 6)
				camera.shake(0.2 * strength)
			Ev.LAND:
				_dust(world(sim.pf[int(event.a)].x, 0), 5)
			Ev.DASH:
				_dust(world(sim.pf[int(event.a)].x, 0), 4)
				_speed = 1.0
			Ev.FINISHER:
				var fighter := sim.pf[int(event.a)]
				impact_frame.flash(3, 1.0)
				camera.punch_in(world(fighter.x, 1300), 1.0)
				_say(String(PureMoves.get_move(fighter.legend, event.move).name).to_upper())
				_speed = 1.0
			Ev.KO:
				impact_frame.flash(4, 1.0)
				camera.shake(1.2)
				_burst(at, "counter", 30, 4.5)


func _say(text: String) -> void:
	if callout.is_valid():
		callout.call(text)


func _burst(at: Vector3, kind: String, count: int, speed: float) -> void:
	for i in count:
		var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 1), _rng.randf_range(-1, 1)).normalized()
		_spawn(at, dir * speed * _rng.randf_range(0.4, 1.0), kind, 0.28)


func _dust(at: Vector3, count: int) -> void:
	for i in count:
		var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.1, 0.6), _rng.randf_range(-1, 1))
		_spawn(at + Vector3(0, 0.05, 0), dir * 1.4, "dust", 0.45)


func _spawn(at: Vector3, velocity: Vector3, kind: String, life: float) -> void:
	if _bits.size() >= MAX_BITS:
		var old: Dictionary = _bits.pop_front()
		(old.node as Node).queue_free()
	var node := MeshInstance3D.new()
	node.mesh = _cube
	node.material_override = _materials[kind]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.global_position = at
	_bits.append({"node": node, "v": velocity, "life": life, "age": 0.0, "dust": kind == "dust"})


func _process(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for bit in _bits:
		bit.age += delta
		var node: MeshInstance3D = bit.node
		if bit.age >= bit.life:
			node.queue_free()
			continue
		var v: Vector3 = bit.v
		v.y -= (2.0 if bit.dust else 6.0) * delta
		v *= 1.0 - (3.0 if bit.dust else 1.5) * delta
		bit.v = v
		node.global_position += v * delta
		var s: float = 1.0 - bit.age / bit.life
		node.scale = Vector3.ONE * (s if not bit.dust else 0.6 + bit.age * 2.0)
		keep.append(bit)
	_bits = keep
	if speed_lines != null:
		_speed = maxf(_speed - delta * 3.0, 0.0)
		speed_lines.visible = _speed > 0.01
		(speed_lines.material as ShaderMaterial).set_shader_parameter("amount", _speed * 0.6)
