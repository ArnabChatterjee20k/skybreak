class_name HeightMarker
extends Node3D
## A faint short dashed tick rising from the ground under a high fighter (T-UX1).
## The ground disc and team ring are ContactShadows': this draws no marker of its own.
## Lives under FighterView (which only moves, never turns), in team colour.

## Feet above this height (m) count as airborne: ContactShadows shows its team ring.
const SHOW_ABOVE := 0.4
## The dashed tick: this many dashes, only while the feet are above TICK_ABOVE.
const DASHES := 3
const DASH_LENGTH := 0.22
const DASH_GAP := 0.2
const TICK_ABOVE := 3.0
## The fighter's position is its capsule centre, this far above its feet.
const FEET_BELOW_CENTRE := 1.0

var color := Color(1, 0.6, 0.2)
## World height of the floor under the fighter.
var ground_y := 0.0

var _dashes: Array[MeshInstance3D] = []


func _ready() -> void:
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.05, DASH_LENGTH, 0.05)
	for i in DASHES:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(color, 0.55 * (1.0 - float(i) / DASHES))
		var dash := MeshInstance3D.new()
		dash.mesh = dash_mesh
		dash.material_override = material
		dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(dash)
		_dashes.append(dash)
	visible = false


## Call every frame with the fighter's drawn (capsule centre) position.
func update(centre: Vector3) -> void:
	var feet := feet_height(centre, ground_y)
	visible = feet > TICK_ABOVE
	if not visible:
		return
	# Local to the (non-rotating) FighterView at centre.
	var ground_local := -FEET_BELOW_CENTRE - feet
	for i in _dashes.size():
		_dashes[i].position = Vector3(0, ground_local + DASH_GAP + DASH_LENGTH / 2.0 + i * (DASH_LENGTH + DASH_GAP), 0)


## Height of the feet above the ground for a capsule-centre position.
static func feet_height(centre: Vector3, ground: float) -> float:
	return centre.y - FEET_BELOW_CENTRE - ground
