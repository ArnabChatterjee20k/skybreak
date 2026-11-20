class_name ContactShadows
extends Node3D
## A dark disc on the floor straight under each fighter (T-ART1), so height above the
## ground reads at a glance. Visual only: the floor comes from the sim's ground.

const SHADER := preload("res://game/world/shadows/contact_shadow.gdshader")
## Disc diameter (m) on the ground and its growth per metre of height.
const BASE_SIZE := 1.6
const GROWTH := 0.035
## Fades out completely this high (m) above the floor.
const FADE_HEIGHT := 30.0
const STRENGTH := 0.6
## Ground samples this far apart (m) give the disc its tilt on slopes.
const SLOPE_STEP := 0.6

var _discs: Array[MeshInstance3D] = []


## Makes `count` discs.
func setup(count: int) -> void:
	for disc in _discs:
		disc.queue_free()
	_discs.clear()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE
	for i in count:
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.render_priority = -1
		var disc := MeshInstance3D.new()
		disc.name = "Shadow%d" % i
		disc.mesh = mesh
		disc.material_override = material
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.layers = WorldAtmosphere.WORLD_LAYERS
		add_child(disc)
		_discs.append(disc)


## Places disc `index` under feet at (x, feet_y, z) on a floor at floor_y; `floor_at(x, z)`
## gives the floor height nearby for the tilt.
func place(index: int, x: float, z: float, feet_y: float, floor_y: float, floor_at: Callable) -> void:
	var disc := _discs[index]
	var height := maxf(feet_y - floor_y, 0.0)
	var fade := 1.0 - clampf(height / FADE_HEIGHT, 0.0, 1.0)
	disc.visible = fade > 0.01
	if not disc.visible:
		return
	var dx: float = floor_at.call(x + SLOPE_STEP, z) - floor_at.call(x - SLOPE_STEP, z)
	var dz: float = floor_at.call(x, z + SLOPE_STEP) - floor_at.call(x, z - SLOPE_STEP)
	var up := Vector3(-dx, 2.0 * SLOPE_STEP, -dz).normalized()
	var size := BASE_SIZE + height * GROWTH
	var right := Vector3.FORWARD.cross(up).normalized()
	var back := right.cross(up).normalized()
	disc.global_transform = Transform3D(Basis(right * size, up, back * size), Vector3(x, floor_y, z))
	(disc.material_override as ShaderMaterial).set_shader_parameter("strength", STRENGTH * fade)


func disc(index: int) -> MeshInstance3D:
	return _discs[index]
