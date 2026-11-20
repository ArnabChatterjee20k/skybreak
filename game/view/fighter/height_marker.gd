class_name HeightMarker
extends Node3D
## Shows how high an airborne fighter is: a thin line from the feet to the
## ground. Hidden near the ground. The ring on the ground is ContactShadows' rim.
## Lives under FighterView (which only moves, never turns), in team colour.

## Feet above this height (m) count as airborne enough to mark.
const SHOW_ABOVE := 1.5
const LINE_WIDTH := 0.04
## The fighter's position is its capsule centre, this far above its feet.
const FEET_BELOW_CENTRE := 1.0

var color := Color(1, 0.6, 0.2)
## World height of the floor under the fighter.
var ground_y := 0.0

var _line: MeshInstance3D


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, 0.7)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var line_mesh := CylinderMesh.new()
	line_mesh.top_radius = LINE_WIDTH
	line_mesh.bottom_radius = LINE_WIDTH
	line_mesh.height = 1.0
	line_mesh.radial_segments = 6
	line_mesh.rings = 1
	_line = MeshInstance3D.new()
	_line.mesh = line_mesh
	_line.material_override = material
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	visible = false


## Call every frame with the fighter's drawn (capsule centre) position.
func update(centre: Vector3) -> void:
	var feet := feet_height(centre, ground_y)
	visible = feet > SHOW_ABOVE
	if not visible:
		return
	# Local to the (non-rotating) FighterView at centre.
	_line.position = Vector3(0, -FEET_BELOW_CENTRE - feet / 2.0, 0)
	_line.scale = Vector3(1, feet, 1)


## Height of the feet above the ground for a capsule-centre position.
static func feet_height(centre: Vector3, ground: float) -> float:
	return centre.y - FEET_BELOW_CENTRE - ground
