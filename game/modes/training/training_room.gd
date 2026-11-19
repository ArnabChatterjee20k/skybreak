class_name TrainingRoom
extends Node
## Training mode entry scene: the test arena with a dummy, the frame-data
## overlay, the settings menu (F1) and the move list (F2). Backspace resets
## positions, F4 spawns a weapon, F5 cycles the dummy, F6/F7 record and play.

## Emitted on Esc while the menu is open, for the menus lane.
signal exit_requested

const MENU_KEY := KEY_F1
const MOVE_LIST_KEY := KEY_F2
const SPAWN_KEY := KEY_F4
const DUMMY_KEY := KEY_F5
const RECORD_KEY := KEY_F6
const PLAYBACK_KEY := KEY_F7
const RESET_KEY := KEY_BACKSPACE

@export var player_id: StringName = &"kael"
@export var dummy_id: StringName = &"vexa"

var session: TrainingSession
var host := ArenaHost.new()
## Weapons F4 cycles through.
var spawn_order: Array[Weapon.Kind] = []

var _spawn_index := 0
var _ui := CanvasLayer.new()
var _overlay := TrainingOverlay.new()
var _menu := TrainingMenu.new()
var _move_list := MoveListPanel.new()


func _ready() -> void:
	for kind: Weapon.Kind in Weapon.NAMES:
		if kind != Weapon.Kind.NONE:
			spawn_order.append(kind)
	add_child(host)
	_ui.layer = 20
	add_child(_ui)
	_ui.add_child(_overlay)
	_ui.add_child(_menu)
	_ui.add_child(_move_list)
	_menu.visible = false
	_move_list.visible = false
	_menu.characters_chosen.connect(_on_characters_chosen)
	_menu.dummy_mode_chosen.connect(func(mode: TrainingDummy.Mode) -> void: session.set_dummy_mode(mode))
	_menu.meters_toggled.connect(func(on: bool) -> void: session.infinite_meters = on)
	_menu.health_toggled.connect(func(on: bool) -> void: session.infinite_health = on)
	_menu.weapon_requested.connect(func(kind: Weapon.Kind) -> void: session.spawn_weapon(kind))
	_menu.reset_requested.connect(func() -> void: session.reset_positions())
	_menu.closed.connect(toggle_menu)
	_start(player_id, dummy_id)


func _physics_process(_delta: float) -> void:
	if _menu.visible or _move_list.visible:
		return
	host.step(session.inputs_for(host.read_player_input()))
	session.after_tick()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		MENU_KEY:
			toggle_menu()
		MOVE_LIST_KEY:
			toggle_move_list()
		RESET_KEY:
			session.reset_positions()
		SPAWN_KEY:
			spawn_next_weapon()
		DUMMY_KEY:
			var next := (session.dummy.mode + 1) % TrainingDummy.Mode.size()
			if next == TrainingDummy.Mode.PLAYBACK and not session.input_loop.has_recording():
				next = 0
			session.set_dummy_mode(next as TrainingDummy.Mode)
		RECORD_KEY:
			session.toggle_recording()
		PLAYBACK_KEY:
			session.toggle_playback()
		KEY_ESCAPE:
			if _menu.visible:
				exit_requested.emit()
		_:
			return
	get_viewport().set_input_as_handled()


func toggle_menu() -> void:
	_move_list.visible = false
	_menu.visible = not _menu.visible
	_overlay.visible = not _menu.visible
	if _menu.visible:
		_menu.show_settings(session, player_id, dummy_id)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func toggle_move_list() -> void:
	_menu.visible = false
	_move_list.visible = not _move_list.visible
	_overlay.visible = not _move_list.visible
	if _move_list.visible:
		var character := Roster.character(player_id)
		_move_list.show_moves(character.display_name, character.stats.move_set)


## Drops the next weapon of spawn_order in front of the player.
func spawn_next_weapon() -> void:
	session.spawn_weapon(spawn_order[_spawn_index])
	_spawn_index = (_spawn_index + 1) % spawn_order.size()
	_overlay.next_weapon = _weapon_name(spawn_order[_spawn_index])


func _start(player: StringName, dummy: StringName) -> void:
	player_id = player
	dummy_id = dummy
	var mode := session.dummy.mode if session else TrainingDummy.Mode.STAND
	var loop := session.input_loop if session else null
	host.build(player_id, dummy_id)
	session = TrainingSession.new(host.sim)
	if loop:
		session.input_loop = loop
		session.dummy.input_loop = loop
	session.set_dummy_mode(mode)
	_overlay.session = session
	_overlay.next_weapon = _weapon_name(spawn_order[_spawn_index])


func _on_characters_chosen(player: StringName, dummy: StringName) -> void:
	_start(player, dummy)


static func _weapon_name(kind: Weapon.Kind) -> String:
	return String(Weapon.NAMES[kind]).capitalize()
