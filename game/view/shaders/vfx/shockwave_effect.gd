class_name ShockwaveEffect
extends ImpactEffect
## Shockwave ring that never gets cut by the ground: it lies flat on a nearby surface,
## and otherwise faces the camera and fades softly where it nears the ground.

## Normal of the surface the effect was spawned on. ZERO = auto: flat on the ground when near it.
@export var surface_normal := Vector3.ZERO
## World height of the ground plane, for the auto mode and the soft fade.
@export var ground_height := 0.0
## Spawned lower than this above the ground (metres), the ring lies flat on it.
@export var flat_below := 0.6
## Metres above the ground over which a camera-facing ring fades in.
@export var ground_fade := 0.5
## Metres a flat ring floats above its surface, so it never z-fights it.
@export var surface_lift := 0.03


func play(color: Color = Color.TRANSPARENT, effect_scale: float = 1.0) -> void:
	super.play(color, effect_scale)
	_place()


## Plays on a surface: the ring lies flat on it, centred on the effect's position.
func play_on_surface(normal: Vector3, color: Color = Color.TRANSPARENT, effect_scale: float = 1.0) -> void:
	surface_normal = normal
	play(color, effect_scale)


func _place() -> void:
	var normal := surface_normal
	var origin := global_position
	if normal.is_zero_approx() and origin.y - ground_height < flat_below:
		normal = Vector3.UP
		origin.y = ground_height
	var flat := not normal.is_zero_approx()
	if flat:
		normal = normal.normalized()
		global_transform = Transform3D(_basis_facing(normal).scaled(scale), origin + normal * surface_lift)
	for geometry in _geometry():
		geometry.set_instance_shader_parameter("lie_flat", flat)
		geometry.set_instance_shader_parameter("surface_plane", Vector4(0.0, 1.0, 0.0, ground_height))
		geometry.set_instance_shader_parameter("surface_fade", 0.0 if flat else ground_fade)


## Basis whose +Z (the quad's face) points along normal.
static func _basis_facing(normal: Vector3) -> Basis:
	var side := Vector3.UP if absf(normal.y) < 0.99 else Vector3.FORWARD
	var x := side.cross(normal).normalized()
	return Basis(x, normal.cross(x), normal)
