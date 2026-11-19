class_name SplashScreen
extends MenuScreen
## Boot splash: the SKYBREAK logo punches in over the backdrop, then the main
## menu. Any key or click skips it.

signal finished

const HOLD_SECONDS := 1.8

var elapsed := 0.0
var _done := false
var _logo: Control


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(MenuTheme.INK, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_logo = SkybreakLogo.new(1.0)
	center.add_child(_logo)
	var credit := MenuTheme.label("PRESS ANY KEY", 24, MenuTheme.TEXT_DIM, 6)
	credit.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	credit.offset_top = -90
	credit.offset_bottom = -50
	credit.offset_left = -500
	credit.offset_right = 500
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(credit)


func enter() -> void:
	elapsed = 0.0
	_done = false
	_logo.pivot_offset = _logo.size / 2
	_logo.scale = Vector2(1.6, 1.6)
	_logo.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(_logo, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_logo, "modulate:a", 1.0, 0.2)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	elapsed += delta
	if elapsed >= HOLD_SECONDS:
		finish()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		get_viewport().set_input_as_handled()
		finish()


func finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	navigate.emit(&"main")
