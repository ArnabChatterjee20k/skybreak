class_name FighterAura
extends Node3D
## Anime power-up aura around a fighter (view only): layered flame tongues hugging the
## body, a fresnel inner glow, rising voxel motes with soft halos, a ki gather into the
## chest (converging streaks, a pulsing orb, floor shock rings, dust and a light pulse),
## and crackling lightning arcs from level 2. Origin at the capsule centre, feet 1 m below.
## Everything is built once in _ready; per-frame work only sets a few uniforms.

const MAX_POWER_LEVEL := 3.0
## Power levels per second the visible aura moves toward power_level.
const BLEND_RATE := 3.0
## Seconds the ki gather takes to fade in or out.
const CHARGE_FADE := 0.25
## Particle budgets at particle_quality 1.0 (HIGH).
const MOTE_BUDGET := 32
const GATHER_BUDGET := 28
const DUST_BUDGET := 12
const MAX_ARCS := 6
## Metres from the capsule centre: the chest the ki gathers into, and the feet.
const CHEST := Vector3(0.0, 0.22, 0.0)
const FEET := 1.0
## Light from the aura onto the fighter and the floor (energy at level 3, range in m). It sits
## low and falls off gently, so no part of the body close to it blows out.
const LIGHT_ENERGY := 0.9
const LIGHT_RANGE := 4.0
const LIGHT_POSITION := Vector3(0.0, -0.45, 0.0)
const LIGHT_ATTENUATION := 0.35
const MOTE_SIZE := 0.042
const HALO_SIZE := 0.3
## Flame size and brightness per level above 1 (level 3 = 1 + 2 * step).
const FLAME_GROWTH := 0.16
const FLAME_GAIN := 0.22

const FLAME_SHADER := preload("res://game/view/shaders/aura_flame.gdshader")
const SHELL_SHADER := preload("res://game/view/shaders/aura.gdshader")
const SPARK_SHADER := preload("res://game/view/shaders/aura_spark.gdshader")
const VOXEL_SHADER := preload("res://game/view/shaders/aura_voxel.gdshader")
const ARC_SHADER := preload("res://game/view/shaders/aura_arc.gdshader")
const DUST_COLOR := Color(0.72, 0.68, 0.62)

## Flame layers, back to front: depth offset, half-width, height, interior glow, heat, intensity, tongues.
const FLAME_LAYERS := [
	[-0.35, 0.95, 3.1, 0.2, 0.1, 0.7, 3.6],
	[-0.25, 0.68, 2.6, 0.3, 0.55, 0.5, 5.0],
	[0.3, 0.82, 2.9, 0.0, 0.25, 0.65, 4.4],
]

## 0 off, 1 charging ki, 2 transformed, 3 ultimate. The look eases toward it.
@export_range(0.0, 3.0, 0.01) var power_level := 0.0:
	set(value):
		power_level = clampf(value, 0.0, MAX_POWER_LEVEL)
## True while ki gathers into the chest (the CHARGING state).
@export var charging := false
## Energy colour, per fighter.
@export var color := Color(1.0, 0.62, 0.22):
	set(value):
		color = value
		if is_node_ready():
			_apply_color()
## Particle and arc scale for graphics tiers: GraphicsSettings vfx_density (HIGH 1.0 ... WEB 0.4).
@export_range(0.0, 1.0, 0.05) var particle_quality := 1.0:
	set(value):
		particle_quality = clampf(value, 0.0, 1.0)
		if is_node_ready():
			_apply_level()

## The level currently shown, easing toward power_level.
var shown_level := 0.0
## The ki gather currently shown, 0 to 1.
var shown_charge := 0.0

var _shell: MeshInstance3D
var _flames: Array[MeshInstance3D] = []
var _motes: GPUParticles3D
var _gather: GPUParticles3D
var _dust: GPUParticles3D
var _orb: MeshInstance3D
var _floor: MeshInstance3D
var _arcs: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _materials: Array[ShaderMaterial] = []
var _clock := 0.0

static var _arc_mesh: ArrayMesh


func _ready() -> void:
	_build()
	shown_level = power_level
	shown_charge = 1.0 if charging else 0.0
	_apply_color()
	_apply_level()


## Jumps straight to power_level and the charge state without easing.
func snap() -> void:
	shown_level = power_level
	shown_charge = 1.0 if charging else 0.0
	_apply_level()


func _process(delta: float) -> void:
	_clock += delta
	var target_charge := 1.0 if charging and power_level > 0.0 else 0.0
	var moving := not is_equal_approx(shown_level, power_level) or not is_equal_approx(shown_charge, target_charge)
	if moving:
		shown_level = move_toward(shown_level, power_level, BLEND_RATE * delta)
		shown_charge = move_toward(shown_charge, target_charge, delta / CHARGE_FADE)
		_apply_level()
	if _light.visible:
		_light.light_energy = light_energy(shown_level, shown_charge, _clock)


## Share of the mote budget alive at a level: 0, 0.45, 0.75, 1.0 at levels 0 to 3.
static func mote_ratio(level: float) -> float:
	if level <= 1.0:
		return 0.45 * maxf(level, 0.0)
	if level <= 2.0:
		return 0.45 + 0.3 * (level - 1.0)
	return minf(0.75 + 0.25 * (level - 2.0), 1.0)


## Lightning only from level 2 (transformed): share of the arcs lit.
static func arc_ratio(level: float) -> float:
	if level < 1.75:
		return 0.0
	return clampf(0.45 + 0.55 * (level - 2.0), 0.3, 1.0)


## Arcs a quality tier can afford: 6 at HIGH, 5 MEDIUM, 4 LOW, 2 WEB.
static func arc_count(quality: float) -> int:
	return clampi(roundi(MAX_ARCS * quality), 2 if quality > 0.0 else 0, MAX_ARCS)


## Flame layers a tier can afford: the hot middle layer is dropped below 0.5 (WEB).
static func flame_layer_count(quality: float) -> int:
	return FLAME_LAYERS.size() if quality >= 0.5 else FLAME_LAYERS.size() - 1


## The aura light: grows with the level, pulses while ki gathers. Cheap, no shadows.
static func light_energy(level: float, charge: float, time: float) -> float:
	var on := clampf(level, 0.0, 1.0)
	var base := LIGHT_ENERGY * on * (0.45 + 0.55 * clampf((level - 1.0) * 0.5, 0.0, 1.0))
	var pulse := 1.0 + charge * 0.35 * sin(time * TAU * 1.6) + 0.06 * sin(time * 23.0)
	return maxf(base * pulse, 0.0)


## Every particle system the aura owns, for budget checks.
func particle_systems() -> Array[GPUParticles3D]:
	return [_motes, _gather, _dust]


## Total particles at full level for the current quality.
func particle_count() -> int:
	var total := 0
	for particles in particle_systems():
		total += roundi(particles.amount * particles.amount_ratio) if particles.emitting else 0
	return total


## Every material the aura draws with, for checks (no hard-edged quads).
func materials() -> Array[ShaderMaterial]:
	return _materials


func flames() -> Array[MeshInstance3D]:
	return _flames


func arcs() -> Array[MeshInstance3D]:
	return _arcs


func light() -> OmniLight3D:
	return _light


func _apply_color() -> void:
	var energy := Color(color, 1.0)
	for made in _materials:
		if made.has_meta(&"dust"):
			continue
		made.set_shader_parameter(&"color" if made.shader == SHELL_SHADER else &"tint", energy)
	_light.light_color = energy.lerp(Color.WHITE, 0.15)


func _apply_level() -> void:
	var level := shown_level
	var on := clampf(level, 0.0, 1.0)
	var lit := level > 0.01
	var q := particle_quality
	_shell.visible = lit
	(_shell.material_override as ShaderMaterial).set_shader_parameter(&"power_level", level)
	var layers := flame_layer_count(q)
	for i in _flames.size():
		var flame := _flames[i]
		# The hot middle layer (index 1) is the one low tiers drop.
		flame.visible = lit and (layers == FLAME_LAYERS.size() or i != 1)
		var made := flame.material_override as ShaderMaterial
		var above := clampf(level - 1.0, 0.0, 2.0)
		made.set_shader_parameter(&"strength", on * (1.0 + FLAME_GAIN * above) / (1.0 + FLAME_GAIN * 2.0))
		made.set_shader_parameter(&"level", maxf(level, 1.0))
		flame.scale = Vector3.ONE * (1.0 + FLAME_GROWTH * above)
	_set_ratio(_motes, mote_ratio(level) * q)
	_motes.speed_scale = 1.0 + 0.35 * clampf(level - 1.0, 0.0, 2.0)
	var charge := shown_charge * on
	_set_ratio(_gather, charge * q)
	_set_ratio(_dust, charge * q)
	_orb.visible = charge > 0.01
	(_orb.material_override as ShaderMaterial).set_shader_parameter(&"strength", charge)
	_orb.scale = Vector3.ONE * (0.8 + 0.2 * clampf(level - 1.0, 0.0, 2.0))
	_floor.visible = lit
	(_floor.material_override as ShaderMaterial).set_shader_parameter(&"strength", on * (0.35 + 0.65 * shown_charge))
	var arcs_lit := arc_ratio(level)
	var arc_total := arc_count(q)
	for i in _arcs.size():
		var arc := _arcs[i]
		arc.visible = arcs_lit > 0.0 and i < arc_total
		(arc.material_override as ShaderMaterial).set_shader_parameter(&"strength", arcs_lit)
	_light.visible = lit
	_light.omni_range = LIGHT_RANGE * (0.75 + 0.25 * q)
	_light.light_energy = light_energy(level, shown_charge, _clock)


static func _set_ratio(particles: GPUParticles3D, ratio: float) -> void:
	particles.amount_ratio = clampf(ratio, 0.0, 1.0)
	particles.emitting = ratio > 0.001


func _build() -> void:
	_light = OmniLight3D.new()
	_light.name = "Light"
	_light.position = LIGHT_POSITION
	_light.shadow_enabled = false
	_light.omni_attenuation = LIGHT_ATTENUATION
	_light.light_specular = 0.2
	add_child(_light)
	_shell = MeshInstance3D.new()
	_shell.name = "Shell"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.9
	capsule.radial_segments = 24
	capsule.rings = 8
	_shell.mesh = capsule
	_shell.material_override = _own(SHELL_SHADER, {
		&"intensity": 0.35, &"grow": 0.05, &"flame_height": 0.25, &"tongue_softness": 0.2,
		&"root_glow": 0.6, &"center_clear": 0.72,
	})
	_add_layer(_shell)
	for i in FLAME_LAYERS.size():
		var spec: Array = FLAME_LAYERS[i]
		var flame := MeshInstance3D.new()
		flame.name = "Flame%d" % i
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		flame.mesh = quad
		flame.material_override = _own(FLAME_SHADER, {
			&"depth_offset": spec[0], &"half_width": spec[1], &"height": spec[2], &"interior": spec[3],
			&"heat": spec[4], &"intensity": spec[5] * (1.0 + FLAME_GAIN * 2.0), &"tongues": spec[6], &"seed": 17.0 * i + 3.0,
			&"speed": 2.0 + 0.35 * i, &"feet": FEET + 0.05,
		})
		flame.custom_aabb = AABB(Vector3(-1.6, -1.3, -1.6), Vector3(3.2, 5.0, 3.2))
		_add_layer(flame)
		_flames.append(flame)
	_motes = _particles("Motes", MOTE_BUDGET, 1.5, _mote_process())
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * MOTE_SIZE
	cube.material = _own(VOXEL_SHADER, {&"core_whiteness": 0.35, &"intensity": 1.4})
	var halo := QuadMesh.new()
	halo.size = Vector2.ONE * HALO_SIZE
	halo.material = _own(SPARK_SHADER, {&"spark_shape": 0, &"intensity": 0.9, &"core_whiteness": 0.2})
	_motes.draw_passes = 2
	_motes.draw_pass_1 = cube
	_motes.draw_pass_2 = halo
	_gather = _particles("Gather", GATHER_BUDGET, 0.55, _gather_process())
	_gather.position = CHEST
	var streak := QuadMesh.new()
	streak.size = Vector2(0.07, 0.42)
	streak.material = _own(SPARK_SHADER, {&"spark_shape": 1, &"intensity": 0.9, &"core_whiteness": 0.7})
	_gather.draw_pass_1 = streak
	_dust = _particles("Dust", DUST_BUDGET, 0.9, _dust_process())
	_dust.position = Vector3(0.0, -FEET + 0.08, 0.0)
	var puff := QuadMesh.new()
	puff.size = Vector2.ONE * 0.55
	var dust_material := VfxKit.layer_material(&"dust")
	dust_material.set_shader_parameter(&"tint", DUST_COLOR)
	dust_material.set_shader_parameter(&"opacity", 0.35)
	dust_material.set_meta(&"dust", true)
	_materials.append(dust_material)
	puff.material = dust_material
	_dust.draw_pass_1 = puff
	_orb = MeshInstance3D.new()
	_orb.name = "Orb"
	_orb.position = CHEST
	var orb_quad := QuadMesh.new()
	orb_quad.size = Vector2.ONE * 0.5
	_orb.mesh = orb_quad
	_orb.material_override = _own(SPARK_SHADER, {&"spark_shape": 2, &"intensity": 0.9, &"core_whiteness": 0.8, &"pulse_rate": 2.2, &"depth_offset": 0.45})
	_add_layer(_orb)
	_floor = MeshInstance3D.new()
	_floor.name = "FloorRing"
	_floor.position = Vector3(0.0, -FEET + 0.02, 0.0)
	_floor.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	var floor_quad := QuadMesh.new()
	floor_quad.size = Vector2.ONE * 3.4
	_floor.mesh = floor_quad
	_floor.material_override = _own(SPARK_SHADER, {&"spark_shape": 3, &"intensity": 0.8, &"core_whiteness": 0.4, &"pulse_rate": 1.4})
	_add_layer(_floor)
	for i in MAX_ARCS:
		var arc := MeshInstance3D.new()
		arc.name = "Arc%d" % i
		arc.mesh = arc_mesh()
		arc.material_override = _own(ARC_SHADER, {&"seed": 7.3 * i + 1.0, &"rate": 6.0 + 1.3 * i,
			&"width": 0.09, &"intensity": 2.2, &"duty": 0.8})
		arc.custom_aabb = AABB(Vector3(-1.2, -1.4, -1.2), Vector3(2.4, 2.8, 2.4))
		_add_layer(arc)
		_arcs.append(arc)


## A unit ribbon for arcs: x across (-0.5 to 0.5), y along (0 to 1), 16 segments.
static func arc_mesh() -> ArrayMesh:
	if _arc_mesh != null:
		return _arc_mesh
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 16
	for i in SEGMENTS:
		var v0 := float(i) / SEGMENTS
		var v1 := float(i + 1) / SEGMENTS
		for c: Vector2 in [Vector2(-0.5, v0), Vector2(0.5, v0), Vector2(0.5, v1), Vector2(-0.5, v0), Vector2(0.5, v1), Vector2(-0.5, v1)]:
			tool.set_uv(Vector2(c.x + 0.5, c.y))
			tool.set_normal(Vector3.BACK)
			tool.add_vertex(Vector3(c.x, c.y, 0.0))
	_arc_mesh = tool.commit()
	return _arc_mesh


func _own(shader: Shader, params: Dictionary) -> ShaderMaterial:
	var made := ShaderMaterial.new()
	made.shader = shader
	made.render_priority = 1
	for key: StringName in params:
		made.set_shader_parameter(key, params[key])
	_materials.append(made)
	return made


func _add_layer(layer: GeometryInstance3D) -> void:
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.visible = false
	add_child(layer)


func _particles(node_name: String, amount: int, life: float, process: ParticleProcessMaterial) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = life
	particles.randomness = 0.35
	particles.local_coords = true
	particles.emitting = false
	particles.process_material = process
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-2, -1.5, -2), Vector3(4, 5, 4))
	add_child(particles)
	return particles


static func _mote_process() -> ParticleProcessMaterial:
	var made := ParticleProcessMaterial.new()
	made.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	made.emission_ring_axis = Vector3.UP
	made.emission_ring_height = 1.7
	made.emission_ring_radius = 0.6
	made.emission_ring_inner_radius = 0.3
	made.direction = Vector3.UP
	made.spread = 12.0
	made.initial_velocity_min = 0.5
	made.initial_velocity_max = 1.2
	made.gravity = Vector3(0, 0.9, 0)
	made.scale_min = 0.7
	made.scale_max = 1.3
	return made


## Streaks born on a sphere around the chest, pulled straight in.
static func _gather_process() -> ParticleProcessMaterial:
	var made := ParticleProcessMaterial.new()
	made.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	made.emission_sphere_radius = 1.25
	made.direction = Vector3.UP
	made.spread = 0.0
	made.initial_velocity_min = 0.0
	made.initial_velocity_max = 0.0
	made.radial_velocity_min = -2.6
	made.radial_velocity_max = -2.0
	made.gravity = Vector3.ZERO
	made.scale_min = 0.6
	made.scale_max = 1.0
	made.particle_flag_align_y = true
	return made


## Dust pushed out along the floor by the charge.
static func _dust_process() -> ParticleProcessMaterial:
	var made := ParticleProcessMaterial.new()
	made.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	made.emission_ring_axis = Vector3.UP
	made.emission_ring_height = 0.05
	made.emission_ring_radius = 0.55
	made.emission_ring_inner_radius = 0.35
	made.direction = Vector3.UP
	made.spread = 0.0
	made.initial_velocity_min = 0.2
	made.initial_velocity_max = 0.5
	made.radial_velocity_min = 1.6
	made.radial_velocity_max = 2.8
	made.damping_min = 1.5
	made.damping_max = 2.5
	made.gravity = Vector3.ZERO
	made.scale_min = 0.6
	made.scale_max = 1.2
	return made
