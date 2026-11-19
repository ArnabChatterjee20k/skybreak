class_name VfxKit
extends RefCounted
## Shared materials, meshes and particle setups for the T-D27 effects. Built once
## and shared by every pooled instance, so the whole set compiles in a few pipelines.

const ENERGY := preload("res://game/view/vfx/shaders/vfx_energy.gdshader")
const OVERLAY := preload("res://game/view/vfx/shaders/vfx_energy_overlay.gdshader")
const DEBRIS := preload("res://game/view/vfx/shaders/vfx_debris.gdshader")
const SCREEN := preload("res://game/view/vfx/shaders/vfx_screen.gdshader")

enum Pass { ENERGY, OVERLAY, DEBRIS }

## Every material look: pass and shader parameters.
const LOOKS := {
	&"flash": {"pass": Pass.OVERLAY, "shape": 0, "start_scale": 0.5, "end_scale": 1.2, "pace": 2.5, "fade_power": 2.0, "intensity": 2.0},
	&"orb": {"pass": Pass.OVERLAY, "shape": 0, "start_scale": 1.0, "end_scale": 1.0, "fade_power": 0.0, "intensity": 1.6, "core_whiteness": 0.9},
	&"ring": {"pass": Pass.OVERLAY, "shape": 1, "start_scale": 0.2, "end_scale": 1.6, "edge_width": 0.08, "fade_power": 1.2, "core_whiteness": 0.5},
	&"spikes": {"pass": Pass.OVERLAY, "shape": 2, "start_scale": 0.5, "end_scale": 1.3, "pace": 1.6, "ray_count": 14.0, "fade_power": 1.4, "intensity": 1.8, "core_whiteness": 0.8},
	&"spark": {"pass": Pass.OVERLAY, "shape": 3, "use_particle_age": true, "align_to_velocity": true, "start_scale": 1.0, "end_scale": 0.5, "fade_power": 1.0, "intensity": 2.0},
	&"streak": {"pass": Pass.ENERGY, "shape": 3, "use_particle_age": true, "align_to_velocity": true, "start_scale": 1.0, "end_scale": 0.6, "fade_power": 1.0, "intensity": 0.9, "core_whiteness": 0.7},
	&"mote": {"pass": Pass.ENERGY, "shape": 0, "use_particle_age": true, "start_scale": 1.0, "end_scale": 0.3, "fade_power": 1.0, "intensity": 1.6},
	&"sparkle": {"pass": Pass.OVERLAY, "shape": 8, "use_particle_age": true, "start_scale": 0.4, "end_scale": 1.2, "fade_power": 1.5, "intensity": 2.0, "core_whiteness": 0.7},
	&"smear": {"pass": Pass.ENERGY, "shape": 4, "billboard": false, "intensity": 1.9, "core_whiteness": 0.8},
	&"shell": {"pass": Pass.ENERGY, "shape": 5, "billboard": false, "start_scale": 1.0, "end_scale": 1.0, "edge_width": 0.15, "fade_power": 1.2, "intensity": 1.8, "core_whiteness": 0.4},
	&"glow": {"pass": Pass.ENERGY, "shape": 0, "start_scale": 1.0, "end_scale": 1.0, "fade_power": 0.0, "intensity": 0.8, "core_whiteness": 0.25},
	&"flare": {"pass": Pass.ENERGY, "shape": 5, "billboard": false, "start_scale": 0.7, "end_scale": 1.7, "edge_width": 0.05, "fade_power": 1.8, "intensity": 1.6, "core_whiteness": 0.5},
	&"dome": {"pass": Pass.ENERGY, "shape": 5, "billboard": false, "start_scale": 0.3, "end_scale": 1.0, "edge_width": 0.0, "rim_power": 5.0, "back_faces_only": true, "fade_power": 2.0, "intensity": 0.6, "core_whiteness": 0.3},
	&"flat_ring": {"pass": Pass.ENERGY, "shape": 1, "billboard": false, "start_scale": 0.3, "end_scale": 1.0, "edge_width": 0.1, "fade_power": 1.3, "intensity": 1.8, "core_whiteness": 0.6},
	&"beam": {"pass": Pass.ENERGY, "shape": 6, "billboard": false, "fade_power": 0.0, "scroll_speed": 6.0, "intensity": 0.9, "core_whiteness": 0.75},
	&"beam_halo": {"pass": Pass.ENERGY, "shape": 6, "billboard": false, "fade_power": 0.0, "scroll_speed": 9.0, "intensity": 0.3, "core_whiteness": 0.0},
	&"bolt": {"pass": Pass.OVERLAY, "shape": 7, "billboard": false, "start_scale": 1.0, "end_scale": 1.0, "fade_power": 1.2, "intensity": 2.4, "core_whiteness": 0.9},
	&"dust": {"pass": Pass.DEBRIS, "shape": 0, "start_scale": 0.5, "end_scale": 1.6, "opacity": 0.75},
	&"chunk": {"pass": Pass.DEBRIS, "shape": 1, "start_scale": 1.0, "end_scale": 0.7, "opacity": 1.0},
	&"petal": {"pass": Pass.DEBRIS, "shape": 2, "start_scale": 1.0, "end_scale": 0.8, "opacity": 0.95, "edge_shade": 0.35},
}

## Particle setups: direction, spread, speed range, gravity, damping, scale range, align, sphere radius.
const EMITTERS := {
	&"burst": [Vector3.UP, 180.0, Vector2(7, 14), Vector3(0, -6, 0), 14.0, Vector2(0.6, 1.0), true, 0.0],
	&"shards": [Vector3.UP, 180.0, Vector2(4, 9), Vector3(0, -14, 0), 2.0, Vector2(0.6, 1.2), false, 0.2],
	&"rise": [Vector3.UP, 35.0, Vector2(3, 7), Vector3(0, 2, 0), 3.0, Vector2(0.6, 1.0), true, 0.7],
	&"puff": [Vector3.UP, 85.0, Vector2(2, 5), Vector3(0, 0.6, 0), 4.0, Vector2(0.8, 1.3), false, 0.5],
	&"debris": [Vector3.UP, 55.0, Vector2(4, 8), Vector3(0, -18, 0), 0.5, Vector2(0.5, 1.0), false, 0.4],
	&"drift": [Vector3.UP, 180.0, Vector2(1.5, 4), Vector3(0, -1.2, 0), 1.0, Vector2(0.7, 1.2), false, 0.5],
	&"twinkle": [Vector3.UP, 180.0, Vector2(1, 3.5), Vector3.ZERO, 2.0, Vector2(0.5, 1.0), false, 0.6],
	&"trail": [Vector3.BACK, 10.0, Vector2(1, 2), Vector3.ZERO, 0.0, Vector2(0.7, 1.0), true, 0.15],
	&"speed": [Vector3.BACK, 4.0, Vector2(1, 3), Vector3.ZERO, 0.0, Vector2(0.6, 1.0), true, 0.9],
}

## Swing smear shapes per style: arc degrees, inner radius share, sweep tilt (degrees).
const SMEAR_STYLES := {
	&"fist": [110.0, 0.55],
	&"gauntlets": [80.0, 0.6],
	&"blade": [160.0, 0.35],
	&"lance": [0.0, 0.0],
	&"hammer": [170.0, 0.2],
	&"chakram": [360.0, 0.8],
	&"scythe": [270.0, 0.45],
}

## Height (unit reach) the smear band rises from its inner to its outer edge.
const CONE_DROP := 0.32

static var _materials: Dictionary = {}
static var _emitters: Dictionary = {}
static var _meshes: Dictionary = {}


## The shared material for a look (built on first use).
static func material(look: StringName) -> ShaderMaterial:
	if _materials.has(look):
		return _materials[look]
	var spec: Dictionary = LOOKS[look]
	var made := ShaderMaterial.new()
	match spec["pass"]:
		Pass.ENERGY:
			made.shader = ENERGY
		Pass.OVERLAY:
			made.shader = OVERLAY
			made.render_priority = 2
		_:
			made.shader = DEBRIS
			made.render_priority = 1
	for key: String in spec:
		if key != "pass":
			made.set_shader_parameter(key, spec[key])
	_materials[look] = made
	return made


## A layer's own copy of a look's material. Tint and progress are plain uniforms on it,
## not instance uniforms: GLES3 (Compatibility, web) caps those at 4096 per scene and
## the arena's toon world already uses most of them.
static func layer_material(look: StringName) -> ShaderMaterial:
	var made := material(look).duplicate() as ShaderMaterial
	made.set_meta(&"look", look)
	return made


## Sets a uniform on a layer's own material.
static func set_param(layer: GeometryInstance3D, key: StringName, value: Variant) -> void:
	(layer.material_override as ShaderMaterial).set_shader_parameter(key, value)


## Every material the effects use, for prewarm checks.
static func all_materials() -> Array[ShaderMaterial]:
	var found: Array[ShaderMaterial] = []
	for look: StringName in LOOKS:
		found.append(material(look))
	return found


static func emitter(name: StringName) -> ParticleProcessMaterial:
	if _emitters.has(name):
		return _emitters[name]
	var spec: Array = EMITTERS[name]
	var made := ParticleProcessMaterial.new()
	made.direction = spec[0]
	made.spread = spec[1]
	made.initial_velocity_min = (spec[2] as Vector2).x
	made.initial_velocity_max = (spec[2] as Vector2).y
	made.gravity = spec[3]
	made.damping_min = spec[4]
	made.damping_max = spec[4] * 1.3
	made.scale_min = (spec[5] as Vector2).x
	made.scale_max = (spec[5] as Vector2).y
	made.particle_flag_align_y = spec[6]
	if spec[7] > 0.0:
		made.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		made.emission_sphere_radius = spec[7]
	_emitters[name] = made
	return made


static func quad(size: Vector2) -> QuadMesh:
	var key := "quad_%s" % size
	if not _meshes.has(key):
		var made := QuadMesh.new()
		made.size = size
		_meshes[key] = made
	return _meshes[key]


static func capsule() -> CapsuleMesh:
	if not _meshes.has("capsule"):
		var made := CapsuleMesh.new()
		made.radius = 0.42
		made.height = 1.9
		made.radial_segments = 16
		made.rings = 6
		_meshes["capsule"] = made
	return _meshes["capsule"]


static func sphere(hemisphere: bool = false) -> SphereMesh:
	var key := "hemisphere" if hemisphere else "sphere"
	if not _meshes.has(key):
		var made := SphereMesh.new()
		made.radius = 1.0
		made.height = 1.0 if hemisphere else 2.0
		made.is_hemisphere = hemisphere
		made.radial_segments = 24
		made.rings = 8 if hemisphere else 12
		_meshes[key] = made
	return _meshes[key]


## Unit cylinder along +Y from 0 to 1, for beams.
static func beam_cylinder() -> ArrayMesh:
	if not _meshes.has("beam"):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		const SIDES := 16
		for i in SIDES:
			var a0 := TAU * float(i) / SIDES
			var a1 := TAU * float(i + 1) / SIDES
			for c: Array in [[a0, 0.0], [a1, 0.0], [a1, 1.0], [a0, 0.0], [a1, 1.0], [a0, 1.0]]:
				var angle: float = c[0]
				var along: float = c[1]
				tool.set_uv(Vector2(angle / TAU, along))
				tool.set_normal(Vector3(cos(angle), 0.0, sin(angle)))
				tool.add_vertex(Vector3(cos(angle), along, sin(angle)))
		_meshes["beam"] = tool.commit()
	return _meshes["beam"]


## Flat swing ribbon around +Y facing -Z, outer radius 1: UV.x along the swing, UV.y inner to outer.
static func smear(style: StringName) -> ArrayMesh:
	var key := "smear_%s" % style
	if _meshes.has(key):
		return _meshes[key]
	var spec: Array = SMEAR_STYLES[style]
	var degrees: float = spec[0]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	if degrees <= 0.0:
		# Thrust: a tapered streak along -Z.
		var rows := 8
		for i in rows:
			var z0 := -0.2 - 1.1 * float(i) / rows
			var z1 := -0.2 - 1.1 * float(i + 1) / rows
			var w0 := 0.22 * (1.0 - float(i) / rows) + 0.03
			var w1 := 0.22 * (1.0 - float(i + 1) / rows) + 0.03
			var u0 := float(i) / rows
			var u1 := float(i + 1) / rows
			_ribbon_quad(tool, Vector3(-w0, -w0, z0), Vector3(w0, w0, z0), Vector3(-w1, -w1, z1), Vector3(w1, w1, z1),
				Vector2(u0, 0.5), Vector2(u0, 1.0), Vector2(u1, 0.5), Vector2(u1, 1.0))
	else:
		var inner: float = spec[1]
		var segments := maxi(int(degrees / 10.0), 6)
		var half := deg_to_rad(degrees) * 0.5
		for i in segments:
			var t0 := float(i) / segments
			var t1 := float(i + 1) / segments
			# Sweep from the right (+X) across the front (-Z) to the left.
			var a0 := lerpf(half, -half, t0)
			var a1 := lerpf(half, -half, t1)
			var d0 := Vector3(sin(a0), 0.0, -cos(a0))
			var d1 := Vector3(sin(a1), 0.0, -cos(a1))
			# A shallow cone (inner edge low, outer high) keeps the arc readable edge-on.
			var low := Vector3.DOWN * CONE_DROP
			_ribbon_quad(tool, d0 * inner + low, d0 + Vector3.UP * CONE_DROP * 0.4, d1 * inner + low, d1 + Vector3.UP * CONE_DROP * 0.4, Vector2(t0, 0.0), Vector2(t0, 1.0), Vector2(t1, 0.0), Vector2(t1, 1.0))
	var made := tool.commit()
	_meshes[key] = made
	return made


static func _ribbon_quad(tool: SurfaceTool, a_in: Vector3, a_out: Vector3, b_in: Vector3, b_out: Vector3,
		uv_a_in: Vector2, uv_a_out: Vector2, uv_b_in: Vector2, uv_b_out: Vector2) -> void:
	for pair: Array in [[a_in, uv_a_in], [a_out, uv_a_out], [b_out, uv_b_out], [a_in, uv_a_in], [b_out, uv_b_out], [b_in, uv_b_in]]:
		tool.set_normal(Vector3.UP)
		tool.set_uv(pair[1])
		tool.add_vertex(pair[0])
