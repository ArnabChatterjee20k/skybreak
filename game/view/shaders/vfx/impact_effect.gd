class_name ImpactEffect
extends Node3D
## One-shot impact VFX. Instance, add to the tree, call play(); it frees itself when done.

## Seconds until the effect frees itself; covers its longest particle lifetime.
@export var lifetime := 0.35
## Used when play() gets no colour.
@export var default_color := Color.WHITE

var _age := 0.0
var _playing := false


func _ready() -> void:
	if not _playing:
		visible = false


## Starts the effect. A transparent colour means default_color.
func play(color: Color = Color.TRANSPARENT, effect_scale: float = 1.0) -> void:
	var tint := default_color if color.a <= 0.0 else color
	scale = Vector3.ONE * effect_scale
	for geometry in _geometry():
		geometry.set_instance_shader_parameter("tint", tint)
	for particles in find_children("*", "GPUParticles3D", true, false):
		(particles as GPUParticles3D).restart()
	_age = 0.0
	_playing = true
	_set_progress(0.0)
	visible = true


func is_playing() -> bool:
	return _playing


func _process(delta: float) -> void:
	if not _playing:
		return
	_age += delta
	_set_progress(minf(_age / lifetime, 1.0))
	if _age >= lifetime:
		_playing = false
		queue_free()


func _set_progress(value: float) -> void:
	for mesh in find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).set_instance_shader_parameter("progress", value)


func _geometry() -> Array[GeometryInstance3D]:
	var found: Array[GeometryInstance3D] = []
	for node in find_children("*", "GeometryInstance3D", true, false):
		found.append(node as GeometryInstance3D)
	return found
