class_name DebugOverlay
extends CanvasLayer
## Frame-rate, frame-time and sim readout. Hidden by default; F3 toggles it
## in debug builds only (never in player-facing exports, issue #79).

const TOGGLE_KEY := KEY_F3

## Set by the scene that owns the sim, so the overlay can show its tick.
var sim: CombatSim

var _label: Label


func _ready() -> void:
	visible = false
	layer = 100
	_label = Label.new()
	_label.position = Vector2(12, 8)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if OS.is_debug_build() and key.pressed and not key.echo and key.physical_keycode == TOGGLE_KEY:
		visible = not visible


func _process(delta: float) -> void:
	if not visible:
		return
	var lines := PackedStringArray([
		"FPS %d   frame %.2f ms" % [Engine.get_frames_per_second(), delta * 1000.0],
		"GPU %s" % RenderingServer.get_video_adapter_name(),
	])
	if sim:
		lines.append("sim tick %d @ %d Hz" % [sim.current_tick, CombatSim.TICKS_PER_SECOND])
	_label.text = "\n".join(lines)
