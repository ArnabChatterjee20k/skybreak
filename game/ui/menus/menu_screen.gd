class_name MenuScreen
extends Control
## One full-screen page of the front end. Asks the front end to move on
## through `navigate` and `back_requested`; plays the T-D20 UI cues.

signal navigate(screen: StringName)
signal back_requested

## The front end that shows this screen (null in isolated tests).
var front_end: FrontEnd


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Called each time the screen is shown.
func enter() -> void:
	pass


## The control that takes keyboard focus when the screen opens.
func first_focus() -> Control:
	return null


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()


func go_back() -> void:
	play_cue(&"back")
	back_requested.emit()


## A themed button that plays the confirm cue and calls `action`.
func make_button(text: String, action: Callable, size := 40) -> Button:
	var b := MenuTheme.button(text, size)
	b.pressed.connect(func() -> void:
		play_cue(&"confirm")
		action.call())
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	return b


## Plays a UI cue (move, confirm, back) through AudioDirector when it exists.
func play_cue(kind: StringName) -> void:
	MenuScreen.cue(self, kind)


static func cue(from: Node, kind: StringName) -> void:
	if from == null or not from.is_inside_tree():
		return
	var director := from.get_node_or_null(^"/root/AudioDirector")
	var id := StringName("ui_" + String(kind))
	if director != null and director.has_method(&"play") and director.get(&"cues") is Dictionary \
			and (director.get(&"cues") as Dictionary).has(id):
		director.call(&"play", id)


## A title strip: big slanted heading with a gold underline bar.
static func heading(text: String, sub := "") -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -6)
	box.add_child(MenuTheme.label(text.to_upper(), 84, MenuTheme.TEXT, 16))
	var bar := ColorRect.new()
	bar.color = MenuTheme.GOLD
	bar.custom_minimum_size = Vector2(420, 10)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(bar)
	if not sub.is_empty():
		var s := MenuTheme.label(sub, 28, MenuTheme.TEXT_DIM, 8)
		box.add_child(s)
	return box


## Footer key hints, e.g. [["Enter", "Select"], ["Esc", "Back"]].
static func key_hints(pairs: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	for pair: Array in pairs:
		var key := MenuTheme.label(" %s " % pair[0], 24, MenuTheme.INK, 0)
		var chip := PanelContainer.new()
		var style := MenuTheme.box(MenuTheme.GOLD, MenuTheme.INK, 3)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		chip.add_theme_stylebox_override("panel", style)
		chip.add_child(key)
		row.add_child(chip)
		row.add_child(MenuTheme.label(pair[1], 24, MenuTheme.TEXT, 6))
	return row
