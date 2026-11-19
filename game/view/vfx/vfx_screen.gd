class_name VfxScreen
extends CanvasLayer
## Full-screen anime overlays: burst lines, a two-tone impact frame, the KO colour pop
## and a white flash. Each one is hidden (free) unless it is playing.

enum Mode { LINES, IMPACT, POP, FLASH }

const SKY_POP := Color(0.55, 0.8, 1.0)
const _TIMED: Array[int] = [Mode.LINES, Mode.POP, Mode.FLASH]

var _rects: Array[ColorRect] = []
var _left := PackedFloat32Array([0, 0, 0, 0])
var _length := PackedFloat32Array([1, 1, 1, 1])
var _peak := PackedFloat32Array([1, 1, 1, 1])
## Impact frames hold for whole rendered frames, not seconds.
var _impact_frames := 0


func _init() -> void:
	layer = 90
	for mode in 4:
		var rect := ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = VfxKit.SCREEN
		material.set_shader_parameter("mode", mode)
		rect.material = material
		rect.visible = false
		add_child(rect)
		_rects.append(rect)


## Burst lines converging on a screen UV for `seconds`.
func burst_lines(center: Vector2, color: Color, seconds: float = 0.3) -> void:
	_param(Mode.LINES, "center", center)
	_param(Mode.LINES, "color", color)
	_start(Mode.LINES, seconds, 1.0)


## A two-tone manga frame for `frames` rendered frames.
func impact(color: Color, center: Vector2, frames: int = 2) -> void:
	_param(Mode.IMPACT, "color", color)
	_param(Mode.IMPACT, "center", center)
	_impact_frames = maxi(frames, 1)
	_peak[Mode.IMPACT] = 0.92
	_rects[Mode.IMPACT].visible = true
	_param(Mode.IMPACT, &"amount", 0.92)


## The KO colour pop toward a sky tint, fading over `seconds`.
func color_pop(tint: Color = SKY_POP, seconds: float = 1.1) -> void:
	_param(Mode.POP, "color", tint)
	_start(Mode.POP, seconds, 0.85)


func flash(seconds: float = 0.12, strength: float = 0.8) -> void:
	_param(Mode.FLASH, "color", Color.WHITE)
	_start(Mode.FLASH, seconds, strength)


func is_active(mode: Mode) -> bool:
	return _rects[mode].visible


## Shows every overlay at once (prewarm).
func show_all() -> void:
	burst_lines(Vector2(0.5, 0.5), Color.WHITE)
	impact(Color.WHITE, Vector2(0.5, 0.5), 4)
	color_pop()
	flash()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _impact_frames > 0:
		_impact_frames -= 1
		if _impact_frames == 0:
			_rects[Mode.IMPACT].visible = false
	for mode in _TIMED:
		if _left[mode] <= 0.0:
			continue
		_left[mode] -= delta
		if _left[mode] <= 0.0:
			_rects[mode].visible = false
		else:
			var t := _left[mode] / _length[mode]
			_param(mode, &"amount", _peak[mode] * t * t * (3.0 - 2.0 * t))


func _start(mode: Mode, seconds: float, peak: float) -> void:
	_left[mode] = seconds
	_length[mode] = seconds
	_peak[mode] = peak
	_param(mode, &"amount", peak)
	_rects[mode].visible = true


func _param(mode: int, key: StringName, value: Variant) -> void:
	(_rects[mode].material as ShaderMaterial).set_shader_parameter(key, value)
