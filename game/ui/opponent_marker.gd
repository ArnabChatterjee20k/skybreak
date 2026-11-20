class_name OpponentMarker
extends Control
## Shows where the opponent is: a reticle on them while locked and on screen,
## an arrow at the screen edge pointing at them when they are off screen, with
## their distance, an above/below cue and a "behind" tag.

## Pixels between an edge arrow and the screen edge.
const EDGE_MARGIN := 48.0
const ARROW_SIZE := 34.0
const OUTLINE := MenuTheme.INK
const FONT_SIZE := 22
## Height difference (m) beyond which the arrow says above or below.
const HEIGHT_CUE := 4.0
const RETICLE_RADIUS := 26.0
const COLOR := MenuTheme.GOLD

## Set by the scene each frame.
var camera: Camera3D
var target := Vector3.ZERO
## The player's position, for the distance and height cues.
var origin := Vector3.ZERO
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
	var arrow := PackedVector2Array([
		at + forward * ARROW_SIZE,
		at - forward * ARROW_SIZE * 0.6 + side * ARROW_SIZE * 0.7,
		at - forward * ARROW_SIZE * 0.6 - side * ARROW_SIZE * 0.7,
	])
	draw_colored_polygon(arrow, COLOR)
	arrow.append(arrow[0])
	draw_polyline(arrow, OUTLINE, 2.0, true)
	var cue := cue_for(origin, target, _placement.behind)
	# Text sits on the inner side of the arrow, toward the screen centre.
	var text_at := at - forward * ARROW_SIZE * 1.9
	var font := MenuTheme.font()
	var label: String = cue.label
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var baseline := text_at + Vector2(-width / 2.0, FONT_SIZE * 0.35)
	draw_string_outline(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 6, OUTLINE)
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR)
	if cue.vertical != 0:
		# A small triangle after the text: up = above you, down = below.
		var tip := baseline + Vector2(width + 16.0, -FONT_SIZE * 0.35)
		var up: Vector2 = Vector2.UP * float(cue.vertical) * 9.0
		var tri := PackedVector2Array([tip + up, tip - up + Vector2(8, 0), tip - up - Vector2(8, 0)])
		draw_colored_polygon(tri, COLOR)


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
				"behind": false,
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
		"behind": local.z >= 0.0,
	}


## What the edge arrow says: label ("42 m", plus " behind" when the opponent
## is behind the camera) and vertical (1 above, -1 below, 0 level).
static func cue_for(from: Vector3, to: Vector3, behind: bool) -> Dictionary:
	var rise := to.y - from.y
	var vertical := 0
	if rise > HEIGHT_CUE:
		vertical = 1
	elif rise < -HEIGHT_CUE:
		vertical = -1
	var label := "%d m" % roundi(from.distance_to(to))
	if behind:
		label += " behind"
	return {"label": label, "vertical": vertical}
