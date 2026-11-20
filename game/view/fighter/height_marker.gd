class_name HeightMarker
extends Node3D
## Shows where an airborne fighter is above the ground (T-UX1): a soft contact
## disc with a crisp rim on the ground under them, in team colour, growing and
## fading with height, plus a faint short dashed tick rising from its centre.
## No line up to the fighter. Lives under FighterView (which only moves, never turns).

## Feet above this height (m) count as airborne enough to mark.
const SHOW_ABOVE := 0.4
## Disc radius (m) at the ground and at FULL_HEIGHT and above.
const RADIUS_LOW := 0.7
const RADIUS_HIGH := 1.6
## Opacity at the ground and at FULL_HEIGHT and above.
const ALPHA_LOW := 0.9
const ALPHA_HIGH := 0.5
const FULL_HEIGHT := 40.0
## The dashed tick: this many dashes, only while the feet are above TICK_ABOVE.
const DASHES := 3
const DASH_LENGTH := 0.22
const DASH_GAP := 0.2
const TICK_ABOVE := 3.0
## Lift off the ground so the disc does not z-fight with it.
const LIFT := 0.06
## The fighter's position is its capsule centre, this far above its feet.
const FEET_BELOW_CENTRE := 1.0

var color := Color(1, 0.6, 0.2)
## World height of the floor under the fighter.
var ground_y := 0.0

var _disc: MeshInstance3D
var _disc_material: StandardMaterial3D
var _dashes: Array[MeshInstance3D] = []


func _ready() -> void:
	_disc_material = _material(disc_texture())
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	quad.orientation = PlaneMesh.FACE_Y
	_disc = _mesh(quad, _disc_material)
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.05, DASH_LENGTH, 0.05)
	for i in DASHES:
		var dash_material := _material(null)
		dash_material.albedo_color = Color(color, 0.55 * (1.0 - float(i) / DASHES))
		_dashes.append(_mesh(dash_mesh, dash_material))
	visible = false


## Call every frame with the fighter's drawn (capsule centre) position.
func update(centre: Vector3) -> void:
	var feet := feet_height(centre, ground_y)
	visible = feet > SHOW_ABOVE
	if not visible:
		return
	# Local to the (non-rotating) FighterView at centre.
	var ground_local := -FEET_BELOW_CENTRE - feet
	var radius := disc_radius(feet)
	_disc.position = Vector3(0, ground_local + LIFT, 0)
	_disc.scale = Vector3(radius, 1, radius)
	_disc_material.albedo_color = Color(color, disc_alpha(feet))
	for i in _dashes.size():
		_dashes[i].visible = feet > TICK_ABOVE
		_dashes[i].position = Vector3(0, ground_local + DASH_GAP + DASH_LENGTH / 2.0 + i * (DASH_LENGTH + DASH_GAP), 0)


## Height of the feet above the ground for a capsule-centre position.
static func feet_height(centre: Vector3, ground: float) -> float:
	return centre.y - FEET_BELOW_CENTRE - ground


## Disc radius (m) for feet at this height: wider the higher, so it reads from afar.
static func disc_radius(feet: float) -> float:
	return lerpf(RADIUS_LOW, RADIUS_HIGH, clampf(feet / FULL_HEIGHT, 0.0, 1.0))


## Disc opacity for feet at this height: fainter the higher.
static func disc_alpha(feet: float) -> float:
	return lerpf(ALPHA_LOW, ALPHA_HIGH, clampf(feet / FULL_HEIGHT, 0.0, 1.0))


## White radial texture: a soft fill that fades out, then a crisp rim.
static func disc_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 0.8, 0.84, 0.92, 0.97])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.42), Color(1, 1, 1, 0.24), Color(1, 1, 1, 0.12),
		Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


func _material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, ALPHA_LOW)
	material.albedo_texture = texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance
