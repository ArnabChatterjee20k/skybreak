class_name SettingsScreen
extends MenuScreen
## Audio volume per bus, graphics (GraphicsSettings, as in GraphicsMenu),
## camera sensitivity and key rebinding. Every change applies and saves at once.

const AUDIO_BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"Ambience", &"UI"]
const TABS: Array[StringName] = [&"audio", &"graphics", &"controls"]

var tab: StringName = &"audio"
var audio: AudioSettings
var graphics: GraphicsSettings
var controls: ControlSettings
## Where settings are saved (tests point it at a temp file).
var save_path := "user://settings.cfg"
var sliders: Dictionary = {}
## Action waiting for a key press, or &"".
var rebinding: StringName = &""

var _pages: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _value_labels: Dictionary = {}
var _quality_buttons: Array[Button] = []
var _style_buttons: Array[Button] = []
var _key_buttons: Dictionary = {}
var _vsync: Button
var _fullscreen: Button
var _built := false
## Whether this is the web build, which offers only the WEB quality tier.
var web := OS.has_feature("web")


func _ready() -> void:
	load_settings()
	var shade := ColorRect.new()
	shade.color = Color(MenuTheme.INK, 0.62)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var head := MenuScreen.heading("Settings")
	head.position = Vector2(80, 40)
	add_child(head)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(80, 200)
	tabs.add_theme_constant_override("separation", 16)
	add_child(tabs)
	for id in TABS:
		var b := make_button(String(id), show_tab.bind(id), 34)
		b.custom_minimum_size = Vector2(280, 70)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tabs.add_child(b)
		_tab_buttons[id] = b
	var panel := PanelContainer.new()
	panel.position = Vector2(80, 300)
	panel.custom_minimum_size = Vector2(1300, 660)
	panel.size = Vector2(1300, 660)
	add_child(panel)
	var stack := Control.new()
	panel.add_child(stack)
	_pages[&"audio"] = _audio_page()
	_pages[&"graphics"] = _graphics_page()
	_pages[&"controls"] = _controls_page()
	for page: Control in _pages.values():
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		stack.add_child(page)
	var back := make_button("<  Back", go_back, 34)
	back.position = Vector2(1500, 980)
	back.custom_minimum_size = Vector2(340, 70)
	add_child(back)
	var hints := MenuScreen.key_hints([["Tab", "Switch page"], ["Arrows", "Adjust"], ["Esc", "Back"]])
	hints.position = Vector2(80, 1000)
	add_child(hints)
	_built = true
	show_tab(tab)


## Reloads every settings group from save_path.
func load_settings() -> void:
	audio = AudioSettings.load_saved(save_path)
	graphics = GraphicsSettings.load_saved(save_path, web)
	controls = ControlSettings.load_saved(save_path)


func enter() -> void:
	rebinding = &""
	show_tab(tab)


func first_focus() -> Control:
	return _tab_buttons[tab]


func show_tab(id: StringName) -> void:
	tab = id
	if not _built:
		return
	for page_id: StringName in _pages:
		(_pages[page_id] as Control).visible = page_id == id
	for tab_id: StringName in _tab_buttons:
		var on := tab_id == id
		(_tab_buttons[tab_id] as Button).add_theme_stylebox_override("normal",
			MenuTheme.box(MenuTheme.CYAN if on else MenuTheme.PANEL, MenuTheme.INK, 5))
		(_tab_buttons[tab_id] as Button).add_theme_color_override("font_color", MenuTheme.INK if on else MenuTheme.TEXT)


## Sets a bus volume (0..1), applies it to the AudioServer and saves.
func set_volume(bus: StringName, linear: float) -> void:
	audio.set_volume(bus, linear)
	var director := get_node_or_null(^"/root/AudioDirector") if is_inside_tree() else null
	if director != null and director.get(&"settings") is AudioSettings and save_path == AudioSettings.SAVE_PATH:
		director.call(&"set_bus_volume", bus, audio.volume(bus), true)
	else:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			AudioServer.set_bus_volume_db(index, audio.volume_db(bus))
		audio.save(save_path)
	if _value_labels.has(bus):
		(_value_labels[bus] as Label).text = "%d%%" % roundi(audio.volume(bus) * 100)
	if sliders.has(bus) and not is_equal_approx(sliders[bus].value, audio.volume(bus)):
		sliders[bus].set_value_no_signal(audio.volume(bus))


## Voxel or Classic art; models and zones built from now on use it.
func set_art_style(kind: ArtStyle.Kind) -> void:
	graphics.art_style = kind
	if save_path == GraphicsSettings.SAVE_PATH:
		ArtStyle.set_current(kind)
	_apply_graphics()


func set_quality(quality: GraphicsSettings.Quality) -> void:
	graphics.quality = quality
	_apply_graphics()


func set_resolution_scale(value: float) -> void:
	graphics.resolution_scale = value
	if _value_labels.has(&"scale"):
		(_value_labels[&"scale"] as Label).text = "%d%%" % roundi(graphics.resolution_scale * 100)
	_apply_graphics()


func set_vsync(enabled: bool) -> void:
	graphics.vsync_enabled = enabled
	_apply_graphics()


func set_fullscreen(enabled: bool) -> void:
	graphics.fullscreen = enabled
	_apply_graphics()


func set_sensitivity(value: float) -> void:
	controls.sensitivity = value
	if _value_labels.has(&"sensitivity"):
		(_value_labels[&"sensitivity"] as Label).text = "%.2fx" % controls.sensitivity
	controls.save(save_path)
	_share_controls()


## Waits for the next key press to bind to `action`.
func start_rebind(action: StringName) -> void:
	rebinding = action
	(_key_buttons[action] as Button).text = "KEY OR CLICK"


func rebind(action: StringName, keycode: Key) -> void:
	rebind_event(action, _key_event(keycode))


## Binds a key or a mouse button (left, right, middle, side buttons) to `action`.
func rebind_event(action: StringName, event: InputEvent) -> void:
	controls.rebind_event(action, event)
	controls.save(save_path)
	rebinding = &""
	_share_controls()
	_refresh_keys()


func reset_keys() -> void:
	controls.reset_bindings()
	controls.save(save_path)
	_share_controls()
	_refresh_keys()


func _input(event: InputEvent) -> void:
	if rebinding == &"" or not is_visible_in_tree():
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and ControlSettings.is_bindable_button(click.button_index):
		get_viewport().set_input_as_handled()
		rebind_event(rebinding, click)
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	if key.physical_keycode == KEY_ESCAPE:
		rebinding = &""
		_refresh_keys()
		return
	rebind(rebinding, key.physical_keycode)


static func _key_event(keycode: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	return key


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		show_tab(TABS[(TABS.find(tab) + 1) % TABS.size()])
		return
	super(event)


func _apply_graphics() -> void:
	if is_inside_tree():
		graphics.apply_to(get_viewport())
	graphics.save(save_path)
	_refresh_graphics()


func _share_controls() -> void:
	var config := get_node_or_null(^"/root/MatchConfig") if is_inside_tree() else null
	if config != null and save_path == ControlSettings.SAVE_PATH:
		config.set(&"controls", controls)


func _audio_page() -> Control:
	var rows := _page_rows()
	for bus in AUDIO_BUSES:
		var slider := _slider(0.0, 1.0, 0.05, audio.volume(bus))
		slider.value_changed.connect(func(v: float) -> void: set_volume(bus, v))
		sliders[bus] = slider
		rows.add_child(_row(String(bus).to_upper() if bus != &"SFX" else "EFFECTS", slider,
			"%d%%" % roundi(audio.volume(bus) * 100), bus))
	return _scroll(rows)


func _graphics_page() -> Control:
	var rows := _page_rows()
	var style_row := HBoxContainer.new()
	style_row.add_theme_constant_override("separation", 12)
	for kind: ArtStyle.Kind in [ArtStyle.Kind.VOXEL, ArtStyle.Kind.CLASSIC]:
		var b := make_button(String(ArtStyle.NAMES[kind]).to_upper(), set_art_style.bind(kind), 28)
		b.custom_minimum_size = Vector2(190, 60)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		style_row.add_child(b)
		_style_buttons.append(b)
	rows.add_child(_row("ART STYLE", style_row))
	var quality_row := HBoxContainer.new()
	quality_row.add_theme_constant_override("separation", 12)
	for q in _tiers():
		var b := make_button(String(GraphicsSettings.Quality.keys()[q]), set_quality.bind(q), 28)
		b.custom_minimum_size = Vector2(190, 60)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		quality_row.add_child(b)
		_quality_buttons.append(b)
	rows.add_child(_row("QUALITY", quality_row))
	var scale := _slider(GraphicsSettings.MIN_RESOLUTION_SCALE, GraphicsSettings.MAX_RESOLUTION_SCALE, 0.05, graphics.resolution_scale)
	scale.value_changed.connect(set_resolution_scale)
	sliders[&"scale"] = scale
	rows.add_child(_row("RESOLUTION SCALE", scale, "%d%%" % roundi(graphics.resolution_scale * 100), &"scale"))
	_vsync = make_button("", func() -> void: set_vsync(not graphics.vsync_enabled), 28)
	_vsync.custom_minimum_size = Vector2(190, 60)
	_vsync.alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_row("VSYNC", _vsync))
	_fullscreen = make_button("", func() -> void: set_fullscreen(not graphics.fullscreen), 28)
	_fullscreen.custom_minimum_size = Vector2(190, 60)
	_fullscreen.alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_row("FULLSCREEN", _fullscreen))
	_refresh_graphics()
	return _scroll(rows)


func _controls_page() -> Control:
	var rows := _page_rows()
	var sens := _slider(ControlSettings.MIN_SENSITIVITY, ControlSettings.MAX_SENSITIVITY, 0.05, controls.sensitivity)
	sens.value_changed.connect(set_sensitivity)
	sliders[&"sensitivity"] = sens
	rows.add_child(_row("CAMERA SENSITIVITY", sens, "%.2fx" % controls.sensitivity, &"sensitivity"))
	var keys := GridContainer.new()
	keys.columns = 4
	keys.add_theme_constant_override("h_separation", 18)
	keys.add_theme_constant_override("v_separation", 4)
	for action: StringName in ControlSettings.REBINDABLE:
		var l := MenuTheme.label(String(ControlSettings.REBINDABLE[action]).to_upper(), 24, MenuTheme.TEXT, 6)
		l.custom_minimum_size.x = 250
		keys.add_child(l)
		var b := make_button("", start_rebind.bind(action), 24)
		b.custom_minimum_size = Vector2(250, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		keys.add_child(b)
		_key_buttons[action] = b
	rows.add_child(keys)
	var reset := make_button("Reset keys", reset_keys, 26)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rows.add_child(reset)
	_refresh_keys()
	return _scroll(rows)


func _refresh_graphics() -> void:
	for i in _style_buttons.size():
		var on := i == graphics.art_style
		_style_buttons[i].add_theme_stylebox_override("normal", MenuTheme.box(MenuTheme.GOLD if on else MenuTheme.PANEL_LIGHT, MenuTheme.INK, 4))
		_style_buttons[i].add_theme_color_override("font_color", MenuTheme.INK if on else MenuTheme.TEXT)
	for i in _quality_buttons.size():
		var on := _tiers()[i] == graphics.quality
		_quality_buttons[i].add_theme_stylebox_override("normal", MenuTheme.box(MenuTheme.GOLD if on else MenuTheme.PANEL_LIGHT, MenuTheme.INK, 4))
		_quality_buttons[i].add_theme_color_override("font_color", MenuTheme.INK if on else MenuTheme.TEXT)
	if _vsync != null:
		_vsync.text = "ON" if graphics.vsync_enabled else "OFF"
		_fullscreen.text = "ON" if graphics.fullscreen else "OFF"


func _refresh_keys() -> void:
	for action: StringName in _key_buttons:
		(_key_buttons[action] as Button).text = ControlSettings.binding_label(action).to_upper()


func _page_rows() -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 18)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return rows


func _scroll(content: Control) -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(content)
	return scroll


func _row(text: String, control: Control, value := "", value_key: StringName = &"") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var l := MenuTheme.label(text, 32, MenuTheme.TEXT, 8)
	l.custom_minimum_size.x = 400
	row.add_child(l)
	row.add_child(control)
	if not value.is_empty():
		var v := MenuTheme.label(value, 32, MenuTheme.GOLD, 8)
		v.custom_minimum_size.x = 120
		row.add_child(v)
		_value_labels[value_key] = v
	return row


func _slider(min_value: float, max_value: float, step: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(560, 44)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	slider.focus_entered.connect(play_cue.bind(&"move"))
	return slider


func _tiers() -> Array[GraphicsSettings.Quality]:
	return GraphicsSettings.tiers(web)
