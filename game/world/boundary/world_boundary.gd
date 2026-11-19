class_name WorldBoundary
extends Node3D
## Energy-dome edge of the map: four walls and the ceiling, fading in near the camera.
## The sim treats the same box (WorldMap.bounds()) as a wall-splat surface.

const SHADER := preload("res://game/world/shaders/energy_dome.gdshader")
const HALF_SIZE := 1000.0
const CEILING := 400.0
const FLOOR := -60.0


static func bounds() -> AABB:
	return AABB(Vector3(-HALF_SIZE, FLOOR, -HALF_SIZE), Vector3(HALF_SIZE * 2.0, CEILING - FLOOR, HALF_SIZE * 2.0))


func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var b := bounds()
	var lo := b.position
	var hi := b.end
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Walls: (corner a, corner b) pairs going round the map.
	var corners := [Vector2(lo.x, lo.z), Vector2(hi.x, lo.z), Vector2(hi.x, hi.z), Vector2(lo.x, hi.z)]
	for i in 4:
		var a: Vector2 = corners[i]
		var c: Vector2 = corners[(i + 1) % 4]
		_quad(st, Vector3(a.x, lo.y, a.y), Vector3(c.x, lo.y, c.y), Vector3(c.x, hi.y, c.y), Vector3(a.x, hi.y, a.y))
	_quad(st, Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z))
	var dome := MeshInstance3D.new()
	dome.name = "EnergyDome"
	dome.mesh = st.commit()
	dome.material_override = material
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.set_meta("wall_splat", true)
	add_child(dome)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)
