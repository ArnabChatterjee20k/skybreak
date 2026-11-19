class_name ResultsScreen
extends CanvasLayer
## After the match: the winner in a victory pose with a big banner, the
## placings, and rematch / character select / main menu.

signal rematch_requested
signal character_select_requested
signal main_menu_requested

var winner := -1
var buttons: Dictionary = {}
var turntable: LegendTurntable

var _banner: Label
var _winner_name: Label
var _winner_title: Label
var _placings: VBoxContainer
var _burst: TextureRect

var _root: Control


func _init() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = MenuTheme.theme()
	add_child(root)
	_root = root
	get_viewport().size_changed.connect(_fit)
	_fit()
	var dim := ColorRect.new()
	dim.color = Color(MenuTheme.INK, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var burst := TextureRect.new()
	burst.texture = MenuTheme.glow(MenuTheme.GOLD)
	burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	burst.position = Vector2(60, 120)
	burst.size = Vector2(800, 860)
	root.add_child(burst)
	_burst = burst
	turntable = LegendTurntable.new(&"", true, false, Vector2i(760, 820))
	turntable.pose = FighterState.State.CHARGING
	turntable.position = Vector2(80, 140)
	turntable.size = Vector2(760, 820)
	root.add_child(turntable)
	_banner = MenuTheme.label("VICTORY!", 150, MenuTheme.GOLD, 24)
	_banner.position = Vector2(900, 90)
	root.add_child(_banner)
	_winner_name = MenuTheme.label("", 90, MenuTheme.TEXT, 16)
	_winner_name.position = Vector2(910, 280)
	root.add_child(_winner_name)
	_winner_title = MenuTheme.label("", 32, MenuTheme.CYAN, 8)
	_winner_title.position = Vector2(916, 395)
	root.add_child(_winner_title)
	_placings = VBoxContainer.new()
	_placings.position = Vector2(910, 470)
	_placings.add_theme_constant_override("separation", 8)
	root.add_child(_placings)
	var row := HBoxContainer.new()
	row.position = Vector2(900, 900)
	row.add_theme_constant_override("separation", 18)
	root.add_child(row)
	for entry: Array in [["rematch", "Rematch", rematch_requested], ["character_select", "Characters", character_select_requested],
			["main", "Main menu", main_menu_requested]]:
		var b := MenuTheme.button(entry[1], 34)
		b.custom_minimum_size = Vector2(300, 80)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sig: Signal = entry[2]
		b.pressed.connect(func() -> void:
			MenuScreen.cue(self, &"confirm")
			sig.emit())
		b.mouse_entered.connect(b.grab_focus)
		row.add_child(b)
		buttons[StringName(entry[0])] = b


## Shows the result for `fighters` (MatchConfig entries); winner -1 is a draw.
func open(fighters: Array, winner_index: int) -> void:
	winner = winner_index
	visible = true
	var has_winner := winner >= 0 and winner < fighters.size()
	var human_won: bool = has_winner and not fighters[winner].is_ai
	_banner.text = "DRAW!" if not has_winner else ("VICTORY!" if human_won else "DEFEAT")
	_banner.add_theme_color_override("font_color", MenuTheme.GOLD if human_won or not has_winner else MenuTheme.CYAN)
	if has_winner:
		var id: StringName = fighters[winner].character
		turntable.set_legend(id)
		_burst.texture = MenuTheme.glow(LegendCatalog.color(id) if human_won else MenuTheme.CYAN)
		_winner_name.text = "%s WINS" % LegendCatalog.display_name(id).to_upper()
		_winner_title.text = LegendCatalog.title(id)
	else:
		_winner_name.text = "NO WINNER"
		_winner_title.text = ""
	for child in _placings.get_children():
		child.queue_free()
	for i in fighters.size():
		var f: Dictionary = fighters[i]
		var seat := ("AI %d (LV %d)" % [i, f.ai_level]) if f.is_ai else "P%d" % (i + 1)
		var text := "%s  %s  -  %s" % ["1ST" if i == winner else "   ", LegendCatalog.display_name(f.character).to_upper(), seat]
		_placings.add_child(MenuTheme.label(text, 32, MenuTheme.team_color(f.team).lightened(0.2) if i == winner else MenuTheme.TEXT_DIM, 8))
	(buttons[&"rematch"] as Button).grab_focus()
	_banner.pivot_offset = Vector2(300, 80)
	_banner.scale = Vector2(1.5, 1.5)
	create_tween().tween_property(_banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fit() -> void:
	MenuTheme.fit(_root, get_viewport().get_visible_rect().size)
