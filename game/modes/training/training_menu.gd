class_name TrainingMenu
extends PanelContainer
## Training settings (F1): characters, dummy behaviour, refill toggles and
## the weapon spawner. Emits what changed; the room applies it.

signal characters_chosen(player_id: StringName, dummy_id: StringName)
signal dummy_mode_chosen(mode: TrainingDummy.Mode)
signal meters_toggled(on: bool)
signal health_toggled(on: bool)
signal weapon_requested(kind: Weapon.Kind)
signal reset_requested
signal closed

var _player := OptionButton.new()
var _dummy := OptionButton.new()
var _mode := OptionButton.new()
var _meters := CheckBox.new()
var _health := CheckBox.new()
var _weapon := OptionButton.new()


func _ready() -> void:
	custom_minimum_size = Vector2(560, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(MatchHud.PANEL, 0.94)
	style.border_color = MatchHud.BANNER
	style.border_width_top = 6
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	add_theme_stylebox_override("panel", style)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	add_child(list)
	var title := Label.new()
	title.text = "TRAINING"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", MatchHud.BANNER)
	list.add_child(title)
	for id in Roster.ids():
		var name := Roster.character(id).display_name
		_player.add_item(name)
		_dummy.add_item(name)
	_row(list, "Your fighter", _player)
	_row(list, "Dummy fighter", _dummy)
	for mode: TrainingDummy.Mode in TrainingDummy.MODE_NAMES:
		_mode.add_item(TrainingDummy.MODE_NAMES[mode], mode)
	_row(list, "Dummy behaviour", _mode)
	_meters.text = "Infinite ki, guard and burst"
	_health.text = "Infinite health"
	list.add_child(_meters)
	list.add_child(_health)
	for kind: Weapon.Kind in Weapon.NAMES:
		if kind != Weapon.Kind.NONE:
			_weapon.add_item(String(Weapon.NAMES[kind]).capitalize(), kind)
	var spawn := Button.new()
	spawn.text = "Spawn"
	spawn.pressed.connect(func() -> void: weapon_requested.emit(_weapon.get_selected_id() as Weapon.Kind))
	var weapon_row := _row(list, "Weapon", _weapon)
	weapon_row.add_child(spawn)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	list.add_child(buttons)
	var reset := Button.new()
	reset.text = "Reset position"
	reset.pressed.connect(reset_requested.emit)
	buttons.add_child(reset)
	var close := Button.new()
	close.text = "Back to training (F1)"
	close.pressed.connect(closed.emit)
	buttons.add_child(close)
	_player.item_selected.connect(_characters_changed.unbind(1))
	_dummy.item_selected.connect(_characters_changed.unbind(1))
	_mode.item_selected.connect(func(index: int) -> void:
		dummy_mode_chosen.emit(_mode.get_item_id(index) as TrainingDummy.Mode))
	_meters.toggled.connect(meters_toggled.emit)
	_health.toggled.connect(health_toggled.emit)


## Shows the session's current settings.
func show_settings(session: TrainingSession, player_id: StringName, dummy_id: StringName) -> void:
	var ids := Roster.ids()
	_player.select(ids.find(player_id))
	_dummy.select(ids.find(dummy_id))
	_mode.select(_mode.get_item_index(session.dummy.mode))
	_meters.set_pressed_no_signal(session.infinite_meters)
	_health.set_pressed_no_signal(session.infinite_health)


func _characters_changed() -> void:
	var ids := Roster.ids()
	characters_chosen.emit(ids[_player.selected], ids[_dummy.selected])


func _row(list: VBoxContainer, label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(200, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	list.add_child(row)
	return row
