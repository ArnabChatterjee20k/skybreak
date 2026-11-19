class_name VfxScreen
extends CanvasLayer
## Full-screen anime overlays: burst lines, a two-tone impact frame, the KO colour pop
## and a white flash. Each one is hidden (free) unless it is playing.

enum Mode { LINES, IMPACT, POP, FLASH }

const SKY_POP := Color(0.55, 0.8, 1.0)
## Longest white flash, in rendered frames: slow-mo must not stretch it into a whiteout.
const MAX_FLASH_FRAMES := 4
## Strongest KO colour pop: a grade, not a wash.
const MAX_POP := 0.35
const _TIMED: Array[int] = [Mode.LINES, Mode.POP]

var _rects: Array[ColorRect] = []
var _left := PackedFloat32Array([0, 0, 0, 0])
var _length := PackedFloat32Array([1, 1, 1, 1])
var _peak := PackedFloat32Array([1, 1, 1, 1])
## Impact frames hold for whole rendered frames, not seconds.
var _impact_frames := 0
var _flash_frames := 0
var _flash_length := 1


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


## A two-tone manga frame for `frames` rendered frames, kept off the screen centre.
func impact(color: Color, center: Vector2, frames: int = 2) -> void:
	_param(Mode.IMPACT, "color", color)
	_param(Mode.IMPACT, "center", center)
	_impact_frames = maxi(frames, 1)
	_peak[Mode.IMPACT] = 0.85
	_rects[Mode.IMPACT].visible = true
	_param(Mode.IMPACT, &"amount", 0.85)


## The KO colour pop toward a sky tint, fading over `seconds`; capped at MAX_POP.
func color_pop(tint: Color = SKY_POP, seconds: float = 0.6, strength: float = 0.25) -> void:
	_param(Mode.POP, "color", tint)
	_start(Mode.POP, seconds, minf(strength, MAX_POP))


## An edge-weighted white flash fading over `frames` rendered frames (at most MAX_FLASH_FRAMES).
func flash(frames: int = MAX_FLASH_FRAMES, strength: float = 0.45) -> void:
	_param(Mode.FLASH, "color", Color.WHITE)
	_flash_length = clampi(frames, 1, MAX_FLASH_FRAMES)
	_flash_frames = _flash_length
	_peak[Mode.FLASH] = strength
	_param(Mode.FLASH, &"amount", strength)
	_rects[Mode.FLASH].visible = true


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
	if _flash_frames > 0:
		_flash_frames -= 1
		_rects[Mode.FLASH].visible = _flash_frames > 0
		_param(Mode.FLASH, &"amount", _peak[Mode.FLASH] * float(_flash_frames) / _flash_length)
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
