class_name MoveListPanel
extends PanelContainer
## The move list (F2): every move of a fighter with its input, frame data and
## a short description, built from its MoveSet by MoveList.

const COLUMNS := ["Input", "Move", "Start", "Active", "Recov", "Dmg", "Hit", "Block", ""]

var _title := Label.new()
var _grid := GridContainer.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 120.0
	offset_right = -120.0
	offset_top = 90.0
	offset_bottom = -90.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(MatchHud.PANEL, 0.95)
	style.border_color = MatchHud.BANNER
	style.border_width_top = 6
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	add_theme_stylebox_override("panel", style)
	var list := VBoxContainer.new()
	add_child(list)
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", MatchHud.BANNER)
	list.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.add_child(scroll)
	_grid.columns = COLUMNS.size()
	_grid.add_theme_constant_override("h_separation", 22)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)


## Fills the list for a fighter.
func show_moves(fighter_name: String, move_set: MoveSet) -> void:
	_title.text = "%s — MOVE LIST   (F2 closes)" % fighter_name.to_upper()
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for column: String in COLUMNS:
		_cell(column, MatchHud.BANNER)
	for row in MoveList.rows_for(move_set):
		_cell(row.input, MatchHud.KI)
		_cell(row.name)
		_cell(str(row.startup))
		_cell(str(row.active))
		_cell(str(row.recovery))
		_cell(str(row.damage))
		_cell(row.on_hit)
		_cell(row.on_block)
		var text := _cell(row.description, Color(0.8, 0.82, 0.86))
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(420, 0)


## Number of move rows shown, for tests.
func row_count() -> int:
	return _grid.get_child_count() / COLUMNS.size() - 1


func _cell(text: String, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	_grid.add_child(label)
	return label
