class_name DuoHud
extends Control
## In-match Duo overlay: team lives, ping and partner state along the top, and a
## centre panel while the partner is late or gone (wait, continue vs AI, or leave).

signal continue_alone_requested
signal leave_requested

var flow: DuoFlow
var session: RollbackSession
var sim: CombatSim
var partner_name := "Partner"
var _top: Label
var _panel: PanelContainer
var _title: Label
var _message: Label
var _continue: Button
var _leave: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = MenuTheme.theme()


func _ready() -> void:
	_top = MenuTheme.label("", 22, MenuTheme.TEXT, 6)
	_top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_top.offset_top = 92
	_top.offset_left = -420
	_top.offset_right = 420
	_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_top)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", MenuTheme.box(MenuTheme.PANEL, MenuTheme.INK, 6))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -360
	_panel.offset_right = 360
	_panel.offset_top = -150
	_panel.offset_bottom = 150
	_panel.visible = false
	add_child(_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	_panel.add_child(rows)
	_title = MenuTheme.label("", 40, MenuTheme.GOLD, 8)
	rows.add_child(_title)
	_message = MenuTheme.label("", 24, MenuTheme.TEXT, 4)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(660, 0)
	rows.add_child(_message)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	rows.add_child(buttons)
	_continue = MenuTheme.button("Continue vs AI", 28)
	_continue.pressed.connect(func() -> void: continue_alone_requested.emit())
	buttons.add_child(_continue)
	_leave = MenuTheme.button("Leave", 28)
	_leave.pressed.connect(func() -> void: leave_requested.emit())
	buttons.add_child(_leave)


func _process(_delta: float) -> void:
	if flow == null:
		return
	var text := "LIVES  DUO %d  ·  AI %d" % [flow.lives[DuoFlow.HUMAN_TEAM], flow.lives[DuoFlow.AI_TEAM]]
	if session != null:
		text += "     PING %d ms" % roundi(session.rtt_ms)
		if session.rollbacks > 0:
			text += "  ·  RB %d" % session.rollbacks
	_top.text = text


## A panel that blocks nothing: the match keeps running behind it.
func show_waiting(seconds_left: int) -> void:
	_show("WAITING FOR %s" % partner_name.to_upper(),
		"The connection stalled. Waiting %d s before you can carry on alone." % seconds_left, false)


func show_loading() -> void:
	_show("GET READY", "Waiting for %s to finish loading the zone." % partner_name, false)


func show_disconnected(reason: String) -> void:
	_show("PARTNER DISCONNECTED", reason + " Carry on with an AI partner, or leave to the lobby.", true)
	_continue.grab_focus()


func show_desync(frame: int) -> void:
	_show("OUT OF SYNC", "Your games disagreed at tick %d. Leave and start a new match together." % frame, true)
	_continue.visible = false


func hide_panel() -> void:
	_panel.visible = false


func panel_visible() -> bool:
	return _panel.visible


func _show(title: String, message: String, with_buttons: bool) -> void:
	_title.text = title
	_message.text = message
	_continue.visible = with_buttons
	_leave.visible = with_buttons
	_panel.visible = true
	if with_buttons:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
