class_name HeartDrift
extends Control
## Little hearts and petals drifting upward: Heartbloom Gardens' flourish.

var active := false:
	set(value):
		active = value
		visible = value
var count := 18

var _time := 0.0
var _seeds: Array[Vector4] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1402
	for i in count:
		_seeds.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.6, 1.4), rng.randf_range(0.0, TAU)))


func _process(delta: float) -> void:
	if active and is_visible_in_tree():
		_time += delta
		queue_redraw()


func _draw() -> void:
	for i in _seeds.size():
		var s := _seeds[i]
		var rise := fposmod(s.y + _time * 0.06 * s.z, 1.0)
		var x := s.x * size.x + sin(_time * 1.3 * s.z + s.w) * 18.0
		var y := size.y * (1.0 - rise)
		var radius := (9.0 + 10.0 * s.z) * (size.y / 600.0 if size.y < 600.0 else 1.0)
		var alpha := sin(rise * PI) * 0.9
		var color := MenuTheme.ROSE.lerp(Color(1, 0.85, 0.9), float(i % 3) * 0.35)
		draw_heart(Vector2(x, y), radius, Color(color, alpha), sin(_time + s.w) * 0.3)


func draw_heart(centre: Vector2, radius: float, color: Color, tilt: float) -> void:
	var points := PackedVector2Array()
	for k in 28:
		var t := TAU * k / 28.0
		# Classic heart curve, y flipped for screen space.
		var p := Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)))
		points.append(centre + (p / 16.0 * radius).rotated(tilt))
	draw_colored_polygon(points, color)
