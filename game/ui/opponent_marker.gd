class_name OpponentMarker
extends Control
## Shows where the opponent is: a reticle on them while locked and on screen,
## an arrow at the screen edge pointing at them when they are off screen.

## Pixels between an edge arrow and the screen edge.
const EDGE_MARGIN := 48.0
const ARROW_SIZE := 22.0
const RETICLE_RADIUS := 26.0
const COLOR := Color(1.0, 0.85, 0.25)

## Set by the scene each frame.
var camera: Camera3D
var target := Vector3.ZERO
var locked := false

var _placement := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if camera == null:
		_placement = {}
	else:
		_placement = placement(camera.global_transform, camera.fov, size, target)
	queue_redraw()


func _draw() -> void:
	if _placement.is_empty():
		return
	var at: Vector2 = _placement.position
	if _placement.on_screen:
		if locked:
			draw_arc(at, RETICLE_RADIUS, 0.0, TAU, 32, COLOR, 3.0, true)
		return
	var forward := Vector2.from_angle(_placement.angle)
	var side := forward.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		at + forward * ARROW_SIZE,
		at - forward * ARROW_SIZE * 0.6 + side * ARROW_SIZE * 0.7,
		at - forward * ARROW_SIZE * 0.6 - side * ARROW_SIZE * 0.7,
	]), COLOR)


## Where to draw the marker for a world point. Returns on_screen, position (px)
## and angle (radians, screen space, 0 = right, y down) of the edge arrow.
static func placement(camera: Transform3D, vertical_fov_degrees: float, screen: Vector2,
		point: Vector3) -> Dictionary:
	var local := camera.affine_inverse() * point
	var tan_half_v := tan(deg_to_rad(vertical_fov_degrees) / 2.0)
	var tan_half_h := tan_half_v * screen.x / screen.y
	if local.z < 0.0:
		var ndc := Vector2(local.x / -local.z / tan_half_h, local.y / -local.z / tan_half_v)
		if absf(ndc.x) <= 1.0 and absf(ndc.y) <= 1.0:
			return {
				"on_screen": true,
				"position": Vector2((ndc.x + 1.0) * 0.5 * screen.x, (1.0 - ndc.y) * 0.5 * screen.y),
				"angle": 0.0,
			}
	# Off screen or behind: point from the centre toward it, pinned to the edge.
	var direction := Vector2(local.x, -local.y)
	if direction.length() < 0.001:
		direction = Vector2.DOWN
	var half := screen * 0.5 - Vector2.ONE * EDGE_MARGIN
	var reach := minf(
		half.x / absf(direction.x) if direction.x != 0.0 else INF,
		half.y / absf(direction.y) if direction.y != 0.0 else INF)
	return {
		"on_screen": false,
		"position": screen * 0.5 + direction * reach,
		"angle": direction.angle(),
	}
