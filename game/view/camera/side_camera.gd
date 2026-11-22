class_name SideCamera
extends Camera3D
## Pure Fight camera (GAME_DESIGN §16.4): side-on to the fight line, always framing both
## fighters with the zone behind them, zooming gently with their distance. Punch-ins for
## finishers and a decaying shake for heavy hits. Reads positions only.

const MIN_DISTANCE := 5.2
const MAX_DISTANCE := 9.0
## Distance added per metre between the fighters.
const ZOOM_PER_METRE := 0.62
const HEIGHT := 1.35
const LOOK_HEIGHT := 1.05
const SMOOTH := 6.0
## Share of the screen width the two fighters may span at most.
const FRAME_SHARE := 0.72

var line_dir := Vector3.RIGHT
var floor_y := 0.0
var _centre := Vector3.ZERO
var _distance := MIN_DISTANCE
var _shake := 0.0
var _shake_time := 0.0
var _punch := 0.0
var _punch_target := Vector3.ZERO
var _ready_once := false


func _init() -> void:
	fov = 38.0
	near = 0.1
	far = 4000.0


## Where the camera looks from: the side of the line with screen right = line_dir.
func view_dir() -> Vector3:
	return Vector3.UP.cross(line_dir).normalized()


## Distance that keeps both fighters (apart metres) inside FRAME_SHARE of the width.
func distance_for(apart: float) -> float:
	var half_width := tan(deg_to_rad(fov) * 0.5) * (16.0 / 9.0)
	var needed := (apart * 0.5 + 0.9) / (half_width * FRAME_SHARE)
	return clampf(maxf(MIN_DISTANCE + apart * ZOOM_PER_METRE * 0.25, needed), MIN_DISTANCE, MAX_DISTANCE)


func follow(a: Vector3, b: Vector3, delta: float) -> void:
	var centre := (a + b) * 0.5
	centre.y = floor_y + maxf((a.y + b.y) * 0.5 - floor_y, 0.0) * 0.5
	var apart := absf((b - a).dot(line_dir))
	var want := distance_for(apart)
	var k := 1.0 - exp(-SMOOTH * delta)
	if not _ready_once:
		k = 1.0
		_ready_once = true
	_centre = _centre.lerp(centre, k)
	_distance = lerpf(_distance, want, k)
	var forward := view_dir()
	var look := _centre + Vector3.UP * LOOK_HEIGHT
	var distance := _distance
	if _punch > 0.0:
		look = look.lerp(_punch_target, _punch)
		distance = lerpf(_distance, 2.8, _punch)
		_punch = maxf(_punch - delta * 1.2, 0.0)
	var eye := look - forward * distance + Vector3.UP * (HEIGHT - LOOK_HEIGHT + 0.25)
	if _shake > 0.0:
		_shake_time += delta
		var jitter := Vector3(sin(_shake_time * 71.0), cos(_shake_time * 53.0), 0.0) * _shake * 0.08
		eye += line_dir * jitter.x + Vector3.UP * jitter.y
		_shake = maxf(_shake - delta * 4.0, 0.0)
	global_transform = Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func punch_in(target: Vector3, amount := 1.0) -> void:
	_punch_target = target
	_punch = amount


## True when a world point is inside the view (with a margin as a share of the screen).
func frames_point(point: Vector3, margin := 0.04) -> bool:
	if is_position_behind(point):
		return false
	var size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920, 1080)
	var at := unproject_position(point)
	return at.x > size.x * margin and at.x < size.x * (1.0 - margin) and at.y > 0.0 and at.y < size.y
