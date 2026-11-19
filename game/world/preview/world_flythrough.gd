extends Node3D
## Scripted camera flight through all seven zones: ~90 s at cruise speed, plus a slow
## pass through Heartbloom Gardens at dusk.
## Keys: T cycles day / dusk / night, M toggles the top-down map, Space pauses.

const DURATION := 90.0
## Speed factor while over Heartbloom Gardens, so the flight lingers there.
const LINGER := 0.4
const MIN_CLEARANCE := 14.0
const LOOK_AHEAD := 0.012
## City, Verdant Falls, Frozen Peaks, Skyhold Ruins, Ember Rift, Shattered Mesa, then up
## into Heartbloom Gardens (arch, fountain, Blossom Crown, meadow, lanterns) and down.
const WAYPOINTS: Array[Vector3] = [
	Vector3(-20, 40, 360), Vector3(-150, 60, 560), Vector3(-420, 50, 600), Vector3(-620, 35, 520),
	Vector3(-660, 80, 400), Vector3(-660, 150, 230), Vector3(-640, 120, -320), Vector3(-650, 100, -530),
	Vector3(-450, 150, -620), Vector3(-150, 160, -620), Vector3(40, 150, -560), Vector3(250, 170, -640),
	Vector3(470, 90, -330), Vector3(660, 75, -480), Vector3(820, 190, -320), Vector3(760, 60, 200),
	Vector3(600, 40, 430), Vector3(800, 70, 700), Vector3(500, 60, 760), Vector3(200, 60, 520),
	Vector3(100, 230, 390), Vector3(40, 282, 190), Vector3(8, 300, 105), Vector3(-30, 308, 30),
	Vector3(-150, 298, 112), Vector3(-212, 300, 20), Vector3(-120, 326, -112), Vector3(20, 330, -122),
	Vector3(140, 300, -96), Vector3(205, 292, 40), Vector3(60, 220, 330),
]
const MAP_HEIGHT := 1600.0

var progress := 0.0
var paused := false
var map_mode := false
var curve := Curve3D.new()
var _in_heartbloom := false
var _time_before := WorldAtmosphere.TimeOfDay.DAY

@onready var world: WorldMap = $WorldMap
@onready var camera: Camera3D = $Camera
@onready var label: Label = $Hud/Label


func _ready() -> void:
	curve.bake_interval = 2.0
	var n := WAYPOINTS.size()
	for i in n + 1:
		var p := WAYPOINTS[i % n]
		var tangent := (WAYPOINTS[(i + 1) % n] - WAYPOINTS[(i - 1 + n) % n]) * 0.2
		curve.add_point(p, -tangent, tangent)
	world.atmosphere.camera = camera
	_place(0.0)


func _process(delta: float) -> void:
	if not paused:
		var speed := LINGER if _zone_under_camera().id == &"heartbloom_gardens" else 1.0
		progress = fposmod(progress + delta * speed / DURATION, 1.0)
	if not map_mode:
		_place(progress)
	var zone := _zone_under_camera()
	if not map_mode:
		_dusk_in_heartbloom(zone.id == &"heartbloom_gardens")
	label.text = "%s  |  %s  |  T time of day, M map, Space pause" % [
		zone.display_name, WorldAtmosphere.TimeOfDay.keys()[world.atmosphere.time_of_day]]


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_T:
			world.set_time_of_day((world.atmosphere.time_of_day + 1) % WorldAtmosphere.TimeOfDay.size())
		KEY_M:
			set_map_mode(not map_mode)
		KEY_SPACE:
			paused = not paused


## Camera pose at `t` (0..1) along the flight.
func pose_at(t: float) -> Transform3D:
	var length := curve.get_baked_length()
	var p := _lifted(curve.sample_baked(t * length, true))
	var ahead := _lifted(curve.sample_baked(fposmod(t + LOOK_AHEAD, 1.0) * length, true))
	ahead.y -= 6.0
	return Transform3D(Basis.looking_at(ahead - p, Vector3.UP), p)


## Top-down orthographic view of the whole map, north up, fog off.
func set_map_mode(enabled: bool) -> void:
	map_mode = enabled
	world.set_overview(enabled)
	if enabled:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = world.bounds().size.x * 1.04
		camera.far = MAP_HEIGHT + 500.0
		camera.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(0, MAP_HEIGHT, 0))
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.far = 1300.0
		_place(progress)


func _zone_under_camera() -> ZoneData:
	var at := camera.global_position
	return world.zone_at(at.x, at.z, -INF if map_mode else at.y)


# Heartbloom is shown at dusk; the previous time of day comes back on the way out.
func _dusk_in_heartbloom(inside: bool) -> void:
	if inside == _in_heartbloom:
		return
	_in_heartbloom = inside
	if inside:
		_time_before = world.atmosphere.time_of_day
		world.set_time_of_day(WorldAtmosphere.TimeOfDay.DUSK)
	else:
		world.set_time_of_day(_time_before)


func _place(t: float) -> void:
	camera.global_transform = pose_at(t)


func _lifted(p: Vector3) -> Vector3:
	return Vector3(p.x, maxf(p.y, world.ground_height_at(p.x, p.z, p.y) + MIN_CLEARANCE), p.z)
