class_name ContactShadows
extends Node3D
## The one ground marker under each fighter: a dark contact disc (T-ART1) that grows and
## fades with height, plus a team-colour rim once airborne (T-118, T-UX1). Visual only.

const SHADER := preload("res://game/world/shadows/contact_shadow.gdshader")
## Disc diameter (m) on the ground and its growth per metre of height.
const BASE_SIZE := 1.6
const GROWTH := 0.035
## Fades out completely this high (m) above the floor.
const FADE_HEIGHT := 30.0
const STRENGTH := 0.6
## Ground samples this far apart (m) give the disc its tilt on slopes.
const SLOPE_STEP := 0.6
## The rim fades in over RING_FADE_IN (m) once the feet are RING_ABOVE (m) up.
const RING_ABOVE := HeightMarker.SHOW_ABOVE
const RING_FADE_IN := 1.0
const RING_STRENGTH := 0.85
## The rim fades to RING_HIGH of its strength by RING_FULL_HEIGHT (m), so it reads from afar but quietly.
const RING_HIGH := 0.6
const RING_FULL_HEIGHT := 40.0

var _discs: Array[MeshInstance3D] = []
var _has_ring: Array[bool] = []


## Makes `count` discs.
func setup(count: int) -> void:
	for disc in _discs:
		disc.queue_free()
	_discs.clear()
	_has_ring.clear()
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
		_has_ring.append(false)


## Gives disc `index` a rim in `color` while airborne.
func set_ring_color(index: int, color: Color) -> void:
	_has_ring[index] = true
	(_discs[index].material_override as ShaderMaterial).set_shader_parameter("ring_color", Color(color, 1.0))


## Places disc `index` under feet at (x, feet_y, z) on a floor at floor_y; `floor_at(x, z)`
## gives the floor height nearby for the tilt.
func place(index: int, x: float, z: float, feet_y: float, floor_y: float, floor_at: Callable) -> void:
	var disc := _discs[index]
	var height := maxf(feet_y - floor_y, 0.0)
	var fade := 1.0 - clampf(height / FADE_HEIGHT, 0.0, 1.0)
	var ring := ring_strength(height) if _has_ring[index] else 0.0
	disc.visible = fade > 0.01 or ring > 0.01
	if not disc.visible:
		return
	var dx: float = floor_at.call(x + SLOPE_STEP, z) - floor_at.call(x - SLOPE_STEP, z)
	var dz: float = floor_at.call(x, z + SLOPE_STEP) - floor_at.call(x, z - SLOPE_STEP)
	var up := Vector3(-dx, 2.0 * SLOPE_STEP, -dz).normalized()
	var size := disc_size(height)
	var right := Vector3.FORWARD.cross(up).normalized()
	var back := right.cross(up).normalized()
	disc.global_transform = Transform3D(Basis(right * size, up, back * size), Vector3(x, floor_y, z))
	var material := disc.material_override as ShaderMaterial
	material.set_shader_parameter("strength", STRENGTH * fade)
	material.set_shader_parameter("ring_strength", ring)


## Disc diameter (m) for feet this high above the floor: wider the higher.
static func disc_size(height: float) -> float:
	return BASE_SIZE + maxf(height, 0.0) * GROWTH


## Team rim opacity for feet this high: none on the ground, fades in, then quieter the higher.
static func ring_strength(height: float) -> float:
	var fade_in := clampf((height - RING_ABOVE) / RING_FADE_IN, 0.0, 1.0)
	return RING_STRENGTH * fade_in * lerpf(1.0, RING_HIGH, clampf(height / RING_FULL_HEIGHT, 0.0, 1.0))


func disc(index: int) -> MeshInstance3D:
	return _discs[index]
