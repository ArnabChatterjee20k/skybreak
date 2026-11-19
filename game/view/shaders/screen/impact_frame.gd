class_name ImpactFrame
extends ColorRect
## Full-screen anime impact frame, shown for a frame or two then hidden again.

var _frames_left := 0
var _flashed_on_frame := -1


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows the frame for `frames` rendered frames at the given strength.
func flash(frames: int = 2, amount: float = 1.0) -> void:
	_frames_left = maxi(frames, 1)
	_flashed_on_frame = Engine.get_process_frames()
	(material as ShaderMaterial).set_shader_parameter("amount", amount)
	visible = true


func _process(_delta: float) -> void:
	# The frame flash() ran in is drawn either way, so counting starts on the next one.
	if _frames_left <= 0 or Engine.get_process_frames() == _flashed_on_frame:
		return
	_frames_left -= 1
	if _frames_left == 0:
		visible = false
