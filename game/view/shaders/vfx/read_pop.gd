class_name ReadPop
extends Node3D
## "READ" text pop for a perfect dodge (T-DEF2): snaps in big, settles, rises and fades.
## Same play() contract as ImpactEffect; frees itself when done.

const TEXT := "READ!"
const LIFETIME := 0.55
const RISE := 0.6
const COLOR := Color(0.78, 0.92, 1.0)
const OUTLINE := Color(0.05, 0.1, 0.25)

var _label: Label3D
var _age := 0.0
var _playing := false
var _size := 1.0


func _ready() -> void:
	_ensure_label()
	if not _playing:
		visible = false


func play(color: Color = Color.TRANSPARENT, effect_scale: float = 1.0) -> void:
	_ensure_label()
	_label.modulate = COLOR if color.a <= 0.0 else color
	_size = effect_scale
	_age = 0.0
	_playing = true
	visible = true
	_pose(0.0)


func is_playing() -> bool:
	return _playing


func _process(delta: float) -> void:
	if not _playing:
		return
	_age += delta
	if _age >= LIFETIME:
		_playing = false
		queue_free()
		return
	_pose(_age / LIFETIME)


## Overshoot to 1.35x in the first 15%, settle to 1x, fade out over the last 40%.
func _pose(t: float) -> void:
	var pop := 1.0 + 0.35 * clampf(1.0 - absf(t - 0.15) / 0.15, 0.0, 1.0)
	_label.scale = Vector3.ONE * pop * _size
	_label.position = Vector3(0, 0.9 + RISE * t, 0)
	_label.modulate.a = clampf((1.0 - t) / 0.4, 0.0, 1.0)
	_label.outline_modulate.a = _label.modulate.a


func _ensure_label() -> void:
	if _label != null:
		return
	_label = Label3D.new()
	_label.text = TEXT
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0016
	_label.font_size = 56
	_label.outline_size = 14
	_label.outline_modulate = OUTLINE
	_label.render_priority = 10
	_label.shaded = false
	add_child(_label)
