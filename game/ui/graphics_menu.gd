class_name GraphicsMenu
extends CanvasLayer
## Graphics settings panel: quality preset, resolution scale, vsync.
## F10 toggles it. Changes apply at once and are saved.

const TOGGLE_KEY := KEY_F10

var settings: GraphicsSettings

var _quality_picker: OptionButton
var _scale_slider: HSlider
var _scale_label: Label
var _vsync_toggle: CheckBox
var _fullscreen_toggle: CheckBox


func _ready() -> void:
	layer = 90
	visible = false
	settings = GraphicsSettings.load_saved()
	settings.apply_to(get_viewport())
	_build_panel()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.physical_keycode == TOGGLE_KEY:
		visible = not visible


func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	panel.add_child(rows)

	var title := Label.new()
	title.text = "Graphics  (F10 to close)"
	rows.add_child(title)

	_quality_picker = OptionButton.new()
	for quality_name in GraphicsSettings.Quality.keys():
		_quality_picker.add_item(quality_name.capitalize())
	_quality_picker.selected = settings.quality
	_quality_picker.item_selected.connect(_on_quality_selected)
	rows.add_child(_labelled("Quality", _quality_picker))

	_scale_slider = HSlider.new()
	_scale_slider.min_value = GraphicsSettings.MIN_RESOLUTION_SCALE
	_scale_slider.max_value = GraphicsSettings.MAX_RESOLUTION_SCALE
	_scale_slider.step = 0.05
	_scale_slider.custom_minimum_size.x = 200
	_scale_slider.value = settings.resolution_scale
	_scale_slider.value_changed.connect(_on_scale_changed)
	_scale_label = Label.new()
	var scale_row := HBoxContainer.new()
	scale_row.add_child(_scale_slider)
	scale_row.add_child(_scale_label)
	rows.add_child(_labelled("Resolution scale", scale_row))
	_update_scale_label()

	_vsync_toggle = CheckBox.new()
	_vsync_toggle.button_pressed = settings.vsync_enabled
	_vsync_toggle.toggled.connect(_on_vsync_toggled)
	rows.add_child(_labelled("VSync", _vsync_toggle))

	_fullscreen_toggle = CheckBox.new()
	_fullscreen_toggle.button_pressed = settings.fullscreen
	_fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	rows.add_child(_labelled("Fullscreen", _fullscreen_toggle))


func _labelled(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 160
	row.add_child(label)
	row.add_child(control)
	return row


func _on_quality_selected(index: int) -> void:
	settings.quality = index as GraphicsSettings.Quality
	_apply_and_save()


func _on_scale_changed(value: float) -> void:
	settings.resolution_scale = value
	_update_scale_label()
	_apply_and_save()


func _on_vsync_toggled(enabled: bool) -> void:
	settings.vsync_enabled = enabled
	_apply_and_save()


func _on_fullscreen_toggled(enabled: bool) -> void:
	settings.fullscreen = enabled
	_apply_and_save()


func _update_scale_label() -> void:
	_scale_label.text = "%d%%" % roundi(settings.resolution_scale * 100)


func _apply_and_save() -> void:
	settings.apply_to(get_viewport())
	settings.save()
