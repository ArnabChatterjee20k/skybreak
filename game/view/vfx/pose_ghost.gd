class_name PoseGhost
extends Node3D
## A dash afterimage that is the fighter's own silhouette (#127): the body mesh drawn
## again by a frozen copy of its bone poses, as a faint additive rim in the energy
## colour that fades out in LIFETIME. GPU skinned from the shared mesh; nothing baked.

## Seconds a ghost lasts.
const LIFETIME := 0.16
## Rim strength at spawn (additive; the body itself stays mostly see-through).
const START_ALPHA := 0.45
const SHADER := preload("res://game/view/vfx/shaders/pose_ghost.gdshader")

var age := LIFETIME
var _skeleton: Skeleton3D
var _mesh: MeshInstance3D
var _material: ShaderMaterial


## Builds the ghost's skeleton (one parentless bone per source bone) and mesh once.
func setup(source_skeleton: Skeleton3D, source_mesh: MeshInstance3D) -> void:
	top_level = true
	_skeleton = Skeleton3D.new()
	for bone in source_skeleton.get_bone_count():
		_skeleton.add_bone(source_skeleton.get_bone_name(bone))
	add_child(_skeleton)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = source_mesh.mesh
	_mesh.skin = source_mesh.skin
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_mesh.material_override = _material
	_skeleton.add_child(_mesh)
	_mesh.skeleton = _mesh.get_path_to(_skeleton)
	visible = false


## Freezes the source's drawn pose (global bone poses, as snapshotted after its modifiers).
func play(space: Transform3D, poses: Array[Transform3D], color: Color) -> void:
	global_transform = space
	for bone in mini(poses.size(), _skeleton.get_bone_count()):
		_skeleton.set_bone_pose(bone, poses[bone])
	_material.set_shader_parameter(&"tint", Color(color, 1.0))
	age = 0.0
	visible = true
	_fade()


func is_playing() -> bool:
	return age < LIFETIME


func advance(delta: float) -> void:
	if not is_playing():
		return
	age += delta
	_fade()


func _fade() -> void:
	var left := clampf(1.0 - age / LIFETIME, 0.0, 1.0)
	_material.set_shader_parameter(&"alpha", START_ALPHA * left * left)
	visible = left > 0.0
