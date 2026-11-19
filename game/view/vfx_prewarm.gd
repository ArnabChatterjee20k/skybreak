class_name VfxPrewarm
extends Node
## Draws every VFX once at match load, hidden behind a loading cover, so their
## shaders and particle pipelines compile then instead of on the first hit
## (the first impact cost ~400 ms on the GTX 1650 without this).

signal finished

const WORLD_EFFECTS: Array[PackedScene] = [
	preload("res://game/view/shaders/vfx/hit_spark_light.tscn"),
	preload("res://game/view/shaders/vfx/hit_spark_heavy.tscn"),
	preload("res://game/view/shaders/vfx/counter_hit.tscn"),
	preload("res://game/view/shaders/vfx/perfect_block_flash.tscn"),
	preload("res://game/view/shaders/vfx/guard_break_shatter.tscn"),
	preload("res://game/view/shaders/vfx/shockwave.tscn"),
]
const AURA := preload("res://game/view/shaders/vfx/fighter_aura.tscn")
const SCREEN_EFFECTS: Array[PackedScene] = [
	preload("res://game/view/shaders/screen/impact_frame.tscn"),
	preload("res://game/view/shaders/screen/speed_lines.tscn"),
]
## Frames to keep everything on screen; pipelines compile on the first draw,
## the extra frames cover particles that start emitting a frame later.
const DRAW_FRAMES := 4
## How far in front of the camera the effects are placed (m).
const DISTANCE := 6.0

var is_finished := false

var _spawned: Array[Node] = []
var _frames_left := 0
var _cover: CanvasLayer


## Starts the prewarm in front of camera; emits finished a few frames later.
## Headless runs (tests, CI) have nothing to compile and finish at once.
func start(camera: Camera3D) -> void:
	if DisplayServer.get_name() == "headless" or camera == null:
		_finish.call_deferred()
		return
	_cover = _make_cover()
	add_child(_cover)
	var origin := camera.global_position - camera.global_basis.z * DISTANCE
	for scene in WORLD_EFFECTS:
		var effect := scene.instantiate() as Node3D
		add_child(effect)
		effect.global_position = origin
		effect.play()
		_spawned.append(effect)
	_spawned.append_array(VfxCatalog.build_prewarm(self, origin))
	var aura := AURA.instantiate() as Node3D
	add_child(aura)
	aura.global_position = origin
	aura.power_level = 3.0
	aura.snap()
	_spawned.append(aura)
	var screen := CanvasLayer.new()
	screen.layer = _cover.layer - 1  # under the cover, still drawn
	add_child(screen)
	_spawned.append(screen)
	for scene in SCREEN_EFFECTS:
		var rect := scene.instantiate() as ColorRect
		screen.add_child(rect)
		if rect is ImpactFrame:
			rect.flash(DRAW_FRAMES)
		else:
			(rect.material as ShaderMaterial).set_shader_parameter("amount", 1.0)
	_frames_left = DRAW_FRAMES


func _process(_delta: float) -> void:
	if _frames_left <= 0:
		return
	_frames_left -= 1
	if _frames_left == 0:
		for node in _spawned:
			if is_instance_valid(node):  # impact effects may already have freed themselves
				node.queue_free()
		_spawned.clear()
		_finish()


func _finish() -> void:
	if _cover:
		_cover.queue_free()
		_cover = null
	is_finished = true
	finished.emit()


static func _make_cover() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 120
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	var label := Label.new()
	label.text = "Loading..."
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 32)
	layer.add_child(label)
	return layer
