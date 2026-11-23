class_name CharacterSelect
extends MenuScreen
## Pick legends per seat. A live turntable shows the active seat's legend with
## name, title and stat bars; a grid of rendered portraits lists every roster
## legend; the seat strip sets human/AI, AI level 1-5 and team per seat.

const AI_LEVEL_NAMES: Array[String] = ["", "Rookie", "Easy", "Normal", "Hard", "Brutal"]
const DEFAULT_AI_LEVEL := 3

var mode: StringName = &"vs_ai"
## Each seat: {character, team, is_ai, ai_level}.
var slots: Array[Dictionary] = []
var active_slot := 0
var legends: Array[StringName] = []
var showcase: LegendTurntable
var portraits: Dictionary = {}
var legend_cards: Dictionary = {}

var _title: Label
var _sub: Label
var _name: Label
var _legend_title: Label
var _bars: Array[ProgressBar] = []
var _glow: TextureRect
var _grid: GridContainer
var _strip: HBoxContainer
var _add_button: Button
var _fight_button: Button
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	legends = LegendCatalog.ids()
	var shade := ColorRect.new()
	shade.color = Color(MenuTheme.INK, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var head := MenuScreen.heading("Choose your legend")
	head.position = Vector2(80, 40)
	add_child(head)
	_title = head.get_child(0) as Label
	_sub = MenuTheme.label("", 30, MenuTheme.CYAN, 8)
	_sub.position = Vector2(84, 160)
	add_child(_sub)

	# Showcase: live model on a glowing disc, name, title, stat bars.
	var stage := Panel.new()
	stage.add_theme_stylebox_override("panel", MenuTheme.box(Color(MenuTheme.PANEL_LIGHT, 0.55), MenuTheme.INK, 6))
	stage.position = Vector2(80, 215)
	stage.size = Vector2(620, 520)
	add_child(stage)
	_glow = TextureRect.new()
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.position = Vector2(110, 230)
	_glow.size = Vector2(560, 500)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)
	showcase = LegendTurntable.new(&"", true, false, Vector2i(620, 520))
	showcase.position = Vector2(80, 215)
	showcase.size = Vector2(620, 520)
	add_child(showcase)

	var details := VBoxContainer.new()
	details.position = Vector2(730, 215)
	details.custom_minimum_size = Vector2(520, 0)
	details.add_theme_constant_override("separation", 6)
	add_child(details)
	_name = MenuTheme.label("", 96, MenuTheme.GOLD, 16)
	details.add_child(_name)
	_legend_title = MenuTheme.label("", 32, MenuTheme.TEXT, 8)
	details.add_child(_legend_title)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	details.add_child(spacer)
	for bar_name in LegendCatalog.BAR_NAMES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var l := MenuTheme.label(bar_name.to_upper(), 28, MenuTheme.TEXT, 8)
		l.custom_minimum_size.x = 170
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.max_value = 10
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(320, 30)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("background", MenuTheme.box(MenuTheme.INK, MenuTheme.INK, 3, false, 0.3))
		bar.add_theme_stylebox_override("fill", MenuTheme.box(MenuTheme.GOLD, MenuTheme.INK, 3, false, 0.3))
		row.add_child(bar)
		_bars.append(bar)
		details.add_child(row)

	# Legend grid (portraits rendered once from each character scene).
	var grid_panel := PanelContainer.new()
	grid_panel.position = Vector2(1290, 215)
	grid_panel.custom_minimum_size = Vector2(560, 0)
	add_child(grid_panel)
	var grid_rows := VBoxContainer.new()
	grid_panel.add_child(grid_rows)
	grid_rows.add_child(MenuTheme.label("LEGENDS", 30, MenuTheme.TEXT_DIM, 6))
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	grid_rows.add_child(_grid)
	for id in legends:
		_grid.add_child(_legend_card(id))
	_grid.add_child(_random_card())

	# Seat strip.
	_strip = HBoxContainer.new()
	_strip.position = Vector2(80, 770)
	_strip.add_theme_constant_override("separation", 18)
	add_child(_strip)

	_add_button = make_button("+ Add AI", add_ai, 30)
	_add_button.position = Vector2(80, 1000)
	_add_button.custom_minimum_size = Vector2(240, 56)
	add_child(_add_button)
	_fight_button = make_button("Choose zone  >", confirm, 44)
	_fight_button.position = Vector2(1420, 985)
	_fight_button.custom_minimum_size = Vector2(430, 76)
	_fight_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_fight_button)
	var hints := MenuScreen.key_hints([["Click", "Pick legend"], ["Enter", "Confirm"], ["Esc", "Back"]])
	hints.position = Vector2(400, 1010)
	add_child(hints)


## Resets the seats for a mode: vs_ai (P1 + 1 AI), ffa (P1 + 3 AIs), training (P1 + dummy).
func setup(mode_id: StringName) -> void:
	mode = mode_id
	var first: StringName = legends[0] if not legends.is_empty() else &"kael"
	var second: StringName = legends[1] if legends.size() > 1 else first
	slots.clear()
	slots.append(MatchRules.fighter(first, 0, false))
	match mode:
		&"ffa":
			for i in 3:
				slots.append(MatchRules.fighter(legends[(i + 1) % legends.size()], i + 1, true, DEFAULT_AI_LEVEL))
		&"training":
			slots.append(MatchRules.fighter(second, 1, true, 1))
		_:
			slots.append(MatchRules.fighter(second, 1, true, DEFAULT_AI_LEVEL))
	active_slot = 0
	refresh()


func enter() -> void:
	if slots.is_empty():
		setup(mode)
	refresh()
	var music := get_node_or_null(^"/root/MusicDirector")
	if music != null and music.has_method(&"play_character_select"):
		music.call(&"play_character_select")


func first_focus() -> Control:
	return legend_cards.get(slots[active_slot].character, _fight_button) if not slots.is_empty() else _fight_button


## Gives the active seat this legend.
func select_legend(id: StringName) -> void:
	if not legends.has(id) or slots.is_empty():
		return
	slots[active_slot].character = id
	refresh()


func set_active_slot(index: int) -> void:
	active_slot = clampi(index, 0, slots.size() - 1)
	refresh()


## Pure Fight: the same picks as a training session against a dummy.
func _pure_fight_training() -> void:
	mode = MatchRules.MODE_PURE_FIGHT_TRAINING
	slots[1].is_ai = true
	refresh()


func max_slots() -> int:
	return 2 if mode == &"training" or MatchRules.is_pure_fight(mode) else 4


func min_slots() -> int:
	return 2


## Adds an AI seat (Vs AI: up to 3 AIs; FFA: up to 4 fighters).
func add_ai() -> void:
	if slots.size() >= max_slots():
		return
	var id: StringName = legends[slots.size() % legends.size()]
	slots.append(MatchRules.fighter(id, _free_team(), true, DEFAULT_AI_LEVEL))
	active_slot = slots.size() - 1
	refresh()


func remove_slot(index: int) -> void:
	if index <= 0 or index >= slots.size() or slots.size() <= min_slots():
		return
	slots.remove_at(index)
	active_slot = mini(active_slot, slots.size() - 1)
	refresh()


## FFA and Pure Fight: switches a seat between human and AI (P1 stays human).
func toggle_ai(index: int) -> void:
	if not (mode == &"ffa" or mode == &"pure_fight") or index <= 0 or index >= slots.size():
		return
	slots[index].is_ai = not slots[index].is_ai
	refresh()


func set_ai_level(index: int, level: int) -> void:
	if index < 0 or index >= slots.size():
		return
	slots[index].ai_level = clampi(level, 1, 5)
	refresh()


func cycle_team(index: int, step := 1) -> void:
	if index < 0 or index >= slots.size() or mode == &"training":
		return
	slots[index].team = posmod(slots[index].team + step, 4)
	refresh()


func randomize_slot(index: int) -> void:
	if index < 0 or index >= slots.size() or legends.is_empty():
		return
	slots[index].character = legends[_rng.randi_range(0, legends.size() - 1)]
	refresh()


## Why the seats cannot start, or empty.
func problems() -> PackedStringArray:
	return MatchRules.problems(MatchRules.make(mode, &"preview", slots, 1))


func confirm() -> void:
	if not problems().is_empty():
		_sub.text = "Can't start: " + ", ".join(problems())
		_sub.add_theme_color_override("font_color", MenuTheme.HOT)
		return
	navigate.emit(&"zone_select")


func refresh() -> void:
	if not is_node_ready() or slots.is_empty():
		return
	var subtitle := {
		&"vs_ai": "VERSUS AI  ·  1 TO 3 AI OPPONENTS",
		&"ffa": "FREE-FOR-ALL  ·  2 TO 4 FIGHTERS",
		&"pure_fight": "PURE FIGHT  ·  1V1 HAND TO HAND  ·  P2: AI OR SECOND PLAYER (ARROWS + , . / ; ' ] [ + RIGHT SHIFT)",
		&"pure_fight_training": "PURE FIGHT TRAINING  ·  DUMMY (T CYCLES BLOCKING)  ·  FRAME DATA ON SCREEN",
		&"training": "TRAINING  ·  YOU AND A DUMMY",
	}
	_sub.text = subtitle.get(mode, String(mode).to_upper())
	_sub.add_theme_color_override("font_color", MenuTheme.CYAN)
	var id: StringName = slots[active_slot].character
	if showcase.legend != id:
		showcase.set_legend(id)
	_glow.texture = MenuTheme.glow(LegendCatalog.color(id))
	_name.text = LegendCatalog.display_name(id).to_upper()
	_name.add_theme_color_override("font_color", LegendCatalog.color(id).lerp(Color.WHITE, 0.25))
	_legend_title.text = LegendCatalog.title(id)
	var bars := LegendCatalog.stat_bars(id)
	for i in _bars.size():
		_bars[i].value = bars[i]
	for legend_id: StringName in legend_cards:
		var card: Button = legend_cards[legend_id]
		card.add_theme_stylebox_override("normal", MenuTheme.box(
			Color(LegendCatalog.color(legend_id), 0.9) if legend_id == id else MenuTheme.PANEL,
			MenuTheme.GOLD if legend_id == id else MenuTheme.INK, 6 if legend_id == id else 4, false, 0.0))
	_rebuild_strip()
	_add_button.visible = slots.size() < max_slots()


func _legend_card(id: StringName) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(164, 196)
	card.focus_mode = Control.FOCUS_ALL
	card.tooltip_text = LegendCatalog.display_name(id)
	card.pressed.connect(func() -> void:
		play_cue(&"confirm")
		select_legend(id))
	card.focus_entered.connect(play_cue.bind(&"move"))
	card.mouse_entered.connect(card.grab_focus)
	var portrait := LegendTurntable.new(id, false, true, Vector2i(256, 300))
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 6
	portrait.offset_top = 6
	portrait.offset_right = -6
	portrait.offset_bottom = -34
	card.add_child(portrait)
	portraits[id] = portrait
	var name_label := MenuTheme.label(LegendCatalog.display_name(id).to_upper(), 26, MenuTheme.TEXT, 8)
	name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_top = -40
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_label)
	legend_cards[id] = card
	return card


func _random_card() -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(164, 196)
	card.text = "?"
	card.add_theme_font_size_override("font_size", 110)
	card.add_theme_color_override("font_color", MenuTheme.GOLD)
	card.tooltip_text = "Random"
	card.pressed.connect(func() -> void:
		play_cue(&"confirm")
		randomize_slot(active_slot))
	card.mouse_entered.connect(card.grab_focus)
	return card


func _rebuild_strip() -> void:
	for child in _strip.get_children():
		(child as Control).visible = false
		child.queue_free()
	for i in slots.size():
		_strip.add_child(_slot_card(i))


func _slot_card(index: int) -> Control:
	var slot: Dictionary = slots[index]
	var team_color := MenuTheme.team_color(slot.team)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(420, 200)
	var active := index == active_slot
	var style := MenuTheme.box(Color(team_color.darkened(0.55), 0.95), MenuTheme.GOLD if active else MenuTheme.INK, 7 if active else 5)
	style.border_width_top = 14
	if not active:
		style.border_color = team_color.darkened(0.2)
	card.add_theme_stylebox_override("panel", style)
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			play_cue(&"move")
			set_active_slot(index))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	card.add_child(rows)
	var top := HBoxContainer.new()
	rows.add_child(top)
	var seat := "P1" if index == 0 else ("AI %d" % index if slot.is_ai else "P%d" % (index + 1))
	if mode == &"training" and index == 1:
		seat = "DUMMY"
	top.add_child(MenuTheme.label(seat, 30, team_color.lightened(0.3), 8))
	var name_label := MenuTheme.label("  " + LegendCatalog.display_name(slot.character).to_upper(), 38, MenuTheme.TEXT, 10)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	if index > 0 and slots.size() > min_slots():
		top.add_child(_small_button("X", remove_slot.bind(index)))

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	rows.add_child(controls)
	if (mode == &"ffa" or mode == &"pure_fight") and index > 0:
		controls.add_child(_small_button("AI" if slot.is_ai else "HUMAN", toggle_ai.bind(index)))
	if mode == &"pure_fight":
		controls.add_child(_small_button("TRAINING", _pure_fight_training))
	elif index == 0:
		controls.add_child(MenuTheme.label("HUMAN", 24, MenuTheme.TEXT_DIM, 6))
	if mode != &"training" and not MatchRules.is_pure_fight(mode):
		controls.add_child(_small_button("TEAM %d" % (slot.team + 1), cycle_team.bind(index, 1)))
	if slot.is_ai:
		var level_row := HBoxContainer.new()
		level_row.add_theme_constant_override("separation", 6)
		rows.add_child(level_row)
		level_row.add_child(_small_button("<", set_ai_level.bind(index, slot.ai_level - 1)))
		var pips := MenuTheme.label("LV %d %s" % [slot.ai_level, AI_LEVEL_NAMES[slot.ai_level].to_upper()], 26, MenuTheme.GOLD, 8)
		pips.custom_minimum_size.x = 210
		pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_row.add_child(pips)
		level_row.add_child(_small_button(">", set_ai_level.bind(index, slot.ai_level + 1)))
	return card


func _small_button(text: String, action: Callable) -> Button:
	var b := make_button(text, action, 22)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var style := MenuTheme.box(MenuTheme.PANEL_LIGHT, MenuTheme.INK, 3)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = MenuTheme.GOLD
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", MenuTheme.box(Color(0, 0, 0, 0), MenuTheme.GOLD, 3, true))
	return b


func _free_team() -> int:
	var used := {}
	for slot in slots:
		used[slot.team] = true
	for team in 4:
		if not used.has(team):
			return team
	return slots.size() % 4
