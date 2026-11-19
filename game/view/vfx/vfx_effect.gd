class_name VfxEffect
extends Node3D
## A pooled one-shot effect built from shared VfxKit layers. play_at() starts it,
## it hides itself when its lifetime ends and waits in its VfxPool to be reused.

## Seconds the effect stays visible; covers its longest particle lifetime.
var lifetime := 0.5
## Used when play_at() gets no colour.
var default_color := Color.WHITE
## Spawn order, so a full pool recycles its oldest effect.
var started_order := 0

var _age := 0.0
var _playing := false
var _meshes: Array[MeshInstance3D] = []
var _particles: Array[GPUParticles3D] = []
var _secondary: Array[GeometryInstance3D] = []


func _init() -> void:
	visible = false
	set_process(false)


## A camera-facing sprite of a VfxKit look.
func add_sprite(look: StringName, size: float, offset: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := add_mesh(look, VfxKit.quad(Vector2(size, size)))
	mesh.position = offset
	return mesh


func add_mesh(look: StringName, mesh: Mesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = VfxKit.layer_material(look)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_meshes.append(instance)
	return instance


## One-shot particles (or continuous when one_shot is false) drawn with a look.
func add_particles(look: StringName, emitter_name: StringName, amount: int, life: float,
		size: Vector2, one_shot: bool = true) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = life
	particles.one_shot = one_shot
	particles.explosiveness = 1.0 if one_shot else 0.0
	particles.emitting = false
	particles.process_material = VfxKit.emitter(emitter_name)
	particles.draw_pass_1 = VfxKit.quad(size)
	particles.material_override = VfxKit.layer_material(look)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	add_child(particles)
	_particles.append(particles)
	return particles


## Starts the effect at a world point; a transparent colour means default_color.
func play_at(where: Vector3, color: Color = Color.TRANSPARENT, effect_scale: float = 1.0,
		orientation: Basis = Basis.IDENTITY) -> void:
	var tint := default_color if color.a <= 0.0 else color
	global_transform = Transform3D(orientation * Basis.from_scale(Vector3.ONE * effect_scale), where)
	for mesh in _meshes:
		VfxKit.set_param(mesh, &"tint", tint)
	for particles in _particles:
		VfxKit.set_param(particles, &"tint", tint)
		particles.restart()
		particles.emitting = true
	_age = 0.0
	_playing = true
	_set_progress(0.0)
	visible = true
	set_process(true)
	_started()


## Marks a layer as tinted by tint_secondary() instead of the main colour.
func make_secondary(layer: GeometryInstance3D) -> void:
	_secondary.append(layer)


## Recolours the secondary layers (e.g. debris under a dust cloud) after play_at().
func tint_secondary(color: Color) -> void:
	for layer in _secondary:
		VfxKit.set_param(layer, &"tint", color)


func is_playing() -> bool:
	return _playing


## Seconds since play_at().
func age() -> float:
	return _age


func _process(delta: float) -> void:
	advance(delta)


## Moves the animation on; pools and tests call it directly.
func advance(delta: float) -> void:
	if not _playing:
		return
	_age += delta
	_set_progress(minf(_age / lifetime, 1.0))
	_advanced(delta)
	if _age >= lifetime:
		stop()


## Ends the effect early and returns it to its pool.
func stop() -> void:
	_playing = false
	visible = false
	set_process(false)
	for particles in _particles:
		particles.emitting = false


func meshes() -> Array[MeshInstance3D]:
	return _meshes


func particles() -> Array[GPUParticles3D]:
	return _particles


## Subclass hooks.
func _started() -> void:
	pass


func _advanced(_delta: float) -> void:
	pass


func _set_progress(value: float) -> void:
	for mesh in _meshes:
		VfxKit.set_param(mesh, &"progress", value)
