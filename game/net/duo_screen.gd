class_name DuoScreen
extends MenuScreen
## Front-end Duo page (GAME_DESIGN §8.2): sign in with a player account (remembered),
## host a room (short code) or join one, then both pick legends, the host sets the
## zone and the AI, both ready up, and the host starts the match on both devices.
## The connection lives in DuoLink, so it survives the match and comes back here.

enum Page { SIGN_IN, CHOOSE, WAITING, SETUP }

## Set before adding the screen to swap the link (tests) or the session file.
var link: DuoLink
var session_store: SessionStore
var page := Page.SIGN_IN

var status_label: Label
var email_field: LineEdit
var password_field: LineEdit
var remember_check: CheckBox
var sign_in_button: Button
var player_label: Label
var host_button: Button
var code_field: LineEdit
var join_button: Button
var sign_out_button: Button
var code_label: Label
var cancel_button: Button
var my_legend_label: Label
var partner_label: Label
var zone_label: Label
var ai_label: Label
var rules_label: Label
var ready_button: Button
var start_button: Button
var leave_button: Button
var host_rows: Array[Control] = []

var _pages: Dictionary = {}
var _restoring := false
var _launched := false


func _ready() -> void:
	var title := MenuScreen.heading("Duo", "You and your partner against AI legends, each on your own device")
	title.position = Vector2(120, 60)
	add_child(title)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuTheme.box(Color(MenuTheme.PANEL, 0.9), MenuTheme.INK, 6))
	panel.position = Vector2(120, 300)
	panel.custom_minimum_size = Vector2(1100, 560)
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	panel.add_child(body)
	status_label = MenuTheme.label("", 26, MenuTheme.GOLD, 6)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(1040, 0)
	body.add_child(status_label)
	_pages[Page.SIGN_IN] = _build_sign_in(body)
	_pages[Page.CHOOSE] = _build_choose(body)
	_pages[Page.WAITING] = _build_waiting(body)
	_pages[Page.SETUP] = _build_setup(body)
	var hints := MenuScreen.key_hints([["Tab", "Next field"], ["Enter", "Select"], ["Esc", "Back"]])
	hints.position = Vector2(120, 1000)
	add_child(hints)
	if session_store == null:
		session_store = SessionStore.new()
	_show_page(Page.SIGN_IN)


func enter() -> void:
	_launched = false
	if link == null:
		link = DuoLink.instance(get_tree())
	if not link.changed.is_connected(refresh):
		link.changed.connect(refresh)
		link.start_requested.connect(_launch)
		link.failed.connect(_on_link_failed)
	if not WebRtcTransport.is_available():
		_set_status("WebRTC is missing in this build (desktop needs the webrtc-native GDExtension: see game/net/README.md).")
	if link.is_connected_to_partner():
		link.reset_for_lobby()
	elif link.client.is_signed_in():
		_show_page(Page.CHOOSE)
	else:
		_show_page(Page.SIGN_IN)
		restore_saved_session()
	refresh()
	if DuoTestPilot.enabled():
		DuoTestPilot.drive_lobby(self)


func first_focus() -> Control:
	match page:
		Page.SIGN_IN:
			return email_field
		Page.CHOOSE:
			return host_button
		Page.WAITING:
			return cancel_button
	return ready_button


func go_back() -> void:
	if page == Page.SETUP or page == Page.WAITING:
		leave_room()
		return
	super()


## Signs back in from a remembered session, if there is one.
func restore_saved_session() -> void:
	var saved := session_store.load_session()
	if saved.is_empty() or _restoring:
		return
	_restoring = true
	remember_check.button_pressed = true
	_set_sign_in_enabled(false)
	_set_status("Signing in")
	var error := await link.client.restore_session(saved)
	_restoring = false
	_set_sign_in_enabled(true)
	if error:
		session_store.clear()
		_set_status("Saved sign-in expired: sign in again")
		return
	session_store.save(link.client.export_session())
	_set_status("Signed in as %s" % link.client.user_name)
	_show_page(Page.CHOOSE)


func sign_in() -> void:
	var email := email_field.text.strip_edges()
	var password := password_field.text
	if email.is_empty() or password.is_empty():
		_set_status("Type your email and password")
		return
	_set_sign_in_enabled(false)
	_set_status("Signing in")
	var error := await link.client.sign_in_with_email(email, password)
	password = ""
	password_field.clear()
	_set_sign_in_enabled(true)
	if error:
		_set_status("Sign-in failed: " + error)
		return
	if remember_check.button_pressed:
		session_store.save(link.client.export_session())
	else:
		session_store.clear()
	_set_status("Signed in as %s" % link.client.user_name)
	_show_page(Page.CHOOSE)


func sign_out() -> void:
	sign_out_button.disabled = true
	session_store.clear()
	link.leave()
	await link.client.sign_out()
	sign_out_button.disabled = false
	_set_status("Signed out")
	_show_page(Page.SIGN_IN)


func host_room() -> void:
	_set_status("Opening a room")
	_set_choose_enabled(false)
	_show_page(Page.WAITING)
	code_label.text = "ROOM CODE  ·····"
	link.host()


func join_room() -> void:
	var code := code_field.text.strip_edges().to_upper()
	if code.length() != AppwriteSignalling.CODE_LENGTH:
		_set_status("Type the %d-letter code from your partner" % AppwriteSignalling.CODE_LENGTH)
		return
	_set_choose_enabled(false)
	_show_page(Page.WAITING)
	code_label.text = "JOINING  " + code
	link.join(code)


func leave_room() -> void:
	link.leave()
	_set_choose_enabled(true)
	_show_page(Page.CHOOSE if link.client.is_signed_in() else Page.SIGN_IN)
	_set_status("Left the room")


## Host: steps a setup value through its choices.
func step_setup(key: String, step: int) -> void:
	var values: Array = []
	match key:
		"zone":
			values = ZoneCatalog.ids()
		"ai_count":
			values = range(DuoMatch.MIN_AI, DuoMatch.MAX_AI + 1)
		"ai_level":
			values = range(MatchRules.MIN_AI_LEVEL, MatchRules.MAX_AI_LEVEL + 1)
		"lives":
			values = DuoMatch.LIVES_CHOICES
		"minutes":
			values = DuoMatch.MINUTE_CHOICES
	if values.is_empty():
		return
	var at := maxi(values.find(link.setup[key]), 0)
	link.set_setup({key: values[posmod(at + step, values.size())]})


func step_legend(step: int) -> void:
	var legends := LegendCatalog.ids()
	var mine: StringName = link.setup["host_legend" if link.is_host() else "guest_legend"]
	var at := maxi(legends.find(mine), 0)
	link.pick_legend(legends[posmod(at + step, legends.size())])


func toggle_ready() -> void:
	link.set_ready(not link.ready_flags[link.local_peer])


func start() -> void:
	if not link.start_match():
		_set_status("Both players must be ready")


## Updates every page from the link.
func refresh() -> void:
	if link == null or status_label == null:
		return
	if link.status:
		_set_status(link.status)
	match link.stage:
		DuoLink.Stage.HOSTING:
			if link.lobby_code:
				code_label.text = "ROOM CODE  " + link.lobby_code
				_set_status("Tell your partner the code %s, then wait here" % link.lobby_code)
		DuoLink.Stage.CONNECTED:
			if not link.is_connected_to_partner():
				return
			if page != Page.SETUP:
				_show_page(Page.SETUP)
			_refresh_setup()


func _refresh_setup() -> void:
	var host := link.is_host()
	var mine: StringName = link.setup["host_legend" if host else "guest_legend"]
	var theirs: StringName = link.setup["guest_legend" if host else "host_legend"]
	var me := link.local_peer
	my_legend_label.text = LegendCatalog.display_name(mine).to_upper()
	partner_label.text = "%s  ·  %s  ·  %s" % [link.partner_name if link.partner_name else "Partner",
		LegendCatalog.display_name(theirs).to_upper(), "READY" if link.ready_flags[1 - me] else "picking"]
	zone_label.text = ZoneCatalog.display_name(link.setup.zone).to_upper()
	ai_label.text = "%d AI  ·  LEVEL %d" % [link.setup.ai_count, link.setup.ai_level]
	rules_label.text = "%d LIVES  ·  %d MIN" % [link.setup.lives, link.setup.minutes]
	for row in host_rows:
		row.visible = host
	ready_button.text = "NOT READY" if link.ready_flags[me] else "READY"
	start_button.visible = host
	start_button.disabled = not link.both_ready()
	if link.both_ready():
		_set_status("Both ready: %s" % ("start the match" if host else "waiting for the host to start"))


func _launch(config: Dictionary) -> void:
	if _launched or not is_visible_in_tree():
		return
	_launched = true
	_set_status("Starting the match")
	var match_config := get_node_or_null(^"/root/MatchConfig")
	if match_config == null:
		return
	match_config.call(&"set_config", config)
	match_config.call(&"launch")


func _on_link_failed(message: String) -> void:
	_set_status(message)
	if page == Page.WAITING:
		_set_choose_enabled(true)
		_show_page(Page.CHOOSE)


func _show_page(next: Page) -> void:
	page = next
	for id: int in _pages:
		(_pages[id] as Control).visible = id == next
	if next == Page.CHOOSE:
		player_label.text = "Signed in as %s" % link.client.user_name if link and link.client.is_signed_in() else ""
		_set_choose_enabled(true)
	var focus := first_focus()
	if focus and is_visible_in_tree():
		focus.grab_focus()


func _set_status(message: String) -> void:
	status_label.text = message


func _set_sign_in_enabled(enabled: bool) -> void:
	sign_in_button.disabled = not enabled
	email_field.editable = enabled
	password_field.editable = enabled


func _set_choose_enabled(enabled: bool) -> void:
	host_button.disabled = not enabled
	join_button.disabled = not enabled
	sign_out_button.disabled = not enabled


func _build_sign_in(parent: Control) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	parent.add_child(box)
	email_field = _field("Email (skybreak-player-1@example.com or -2)")
	box.add_child(email_field)
	password_field = _field("Password")
	password_field.secret = true
	password_field.text_submitted.connect(func(_text: String) -> void: sign_in())
	box.add_child(password_field)
	remember_check = CheckBox.new()
	remember_check.text = "Remember me on this device"
	remember_check.button_pressed = true
	remember_check.add_theme_font_size_override("font_size", 26)
	box.add_child(remember_check)
	sign_in_button = make_button("Sign in", sign_in, 34)
	box.add_child(sign_in_button)
	return box


func _build_choose(parent: Control) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	parent.add_child(box)
	player_label = MenuTheme.label("", 28, MenuTheme.TEXT, 6)
	box.add_child(player_label)
	host_button = make_button("Host a room", host_room, 36)
	box.add_child(host_button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	code_field = _field("Room code")
	code_field.max_length = AppwriteSignalling.CODE_LENGTH
	code_field.custom_minimum_size = Vector2(320, 64)
	code_field.text_submitted.connect(func(_text: String) -> void: join_room())
	row.add_child(code_field)
	join_button = make_button("Join", join_room, 36)
	row.add_child(join_button)
	sign_out_button = make_button("Sign out", sign_out, 26)
	box.add_child(sign_out_button)
	return box


func _build_waiting(parent: Control) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	parent.add_child(box)
	code_label = MenuTheme.label("", 72, MenuTheme.TEXT, 12)
	box.add_child(code_label)
	box.add_child(MenuTheme.label("Peer-to-peer over WebRTC (public STUN).", 22, MenuTheme.TEXT_DIM, 4))
	cancel_button = make_button("Cancel", leave_room, 30)
	box.add_child(cancel_button)
	return box


func _build_setup(parent: Control) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	parent.add_child(box)
	my_legend_label = _stepper_row(box, "You", func(step: int) -> void: step_legend(step))[0]
	partner_label = _info_row(box, "Partner")
	var zone_row := _stepper_row(box, "Zone", func(step: int) -> void: step_setup("zone", step))
	zone_label = zone_row[0]
	var ai_row := _stepper_row(box, "AI", func(step: int) -> void: step_setup("ai_count", step))
	ai_label = ai_row[0]
	var level_row := _stepper_row(box, "AI level", func(step: int) -> void: step_setup("ai_level", step))
	var lives_row := _stepper_row(box, "Lives", func(step: int) -> void: step_setup("lives", step))
	rules_label = lives_row[0]
	var minutes_row := _stepper_row(box, "Minutes", func(step: int) -> void: step_setup("minutes", step))
	for row: Array in [zone_row, ai_row, lives_row]:
		for button: Control in row.slice(1):
			host_rows.append(button)
	# Value-less rows (level, minutes) are host-only buttons: hidden whole for the guest.
	host_rows.append((level_row[0] as Label).get_parent())
	host_rows.append((minutes_row[0] as Label).get_parent())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	box.add_child(buttons)
	ready_button = make_button("Ready", toggle_ready, 32)
	buttons.add_child(ready_button)
	start_button = make_button("Start", start, 32)
	buttons.add_child(start_button)
	leave_button = make_button("Leave", leave_room, 26)
	buttons.add_child(leave_button)
	return box


## [value label, back button, next button].
func _stepper_row(parent: Control, caption: String, step: Callable) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var name_label := MenuTheme.label(caption.to_upper(), 24, MenuTheme.TEXT_DIM, 4)
	name_label.custom_minimum_size = Vector2(170, 0)
	row.add_child(name_label)
	var back := make_button("<", step.bind(-1), 24)
	row.add_child(back)
	var value := MenuTheme.label("", 28, MenuTheme.TEXT, 6)
	value.custom_minimum_size = Vector2(440, 0)
	row.add_child(value)
	var next := make_button(">", step.bind(1), 24)
	row.add_child(next)
	return [value, back, next]


func _info_row(parent: Control, caption: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var name_label := MenuTheme.label(caption.to_upper(), 24, MenuTheme.TEXT_DIM, 4)
	name_label.custom_minimum_size = Vector2(170, 0)
	row.add_child(name_label)
	var value := MenuTheme.label("", 28, MenuTheme.TEXT, 6)
	row.add_child(value)
	return value


func _field(placeholder: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.custom_minimum_size = Vector2(760, 64)
	field.add_theme_font_size_override("font_size", 28)
	return field
