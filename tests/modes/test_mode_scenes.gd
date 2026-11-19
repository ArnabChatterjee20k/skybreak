extends GutTest
## The training and tutorial entry scenes load, host the arena and run.

const TRAINING := "res://game/modes/training/training.tscn"
const TUTORIAL := "res://game/modes/tutorial/tutorial.tscn"


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	return event


func test_training_scene_hosts_the_arena_with_a_dummy() -> void:
	var room: TrainingRoom = load(TRAINING).instantiate()
	add_child_autofree(room)
	await wait_physics_frames(10)
	assert_not_null(room.session)
	assert_eq(room.host.sim.fighters.size(), 2)
	assert_false(room.host.arena.match_flow.enabled, "no rounds in training")
	assert_false(room.host.sim.pickups_enabled, "weapons come from the spawner only")
	assert_gt(room.host.sim.current_tick, 0, "the room ticks the sim")


func test_training_keys_reset_spawn_and_cycle_the_dummy() -> void:
	var room: TrainingRoom = load(TRAINING).instantiate()
	add_child_autofree(room)
	await wait_physics_frames(2)
	room.host.sim.fighters[0].position.x = 40.0
	room._unhandled_key_input(_key(TrainingRoom.RESET_KEY))
	assert_almost_eq(room.host.sim.fighters[0].position.x, 0.0, 0.001)
	room._unhandled_key_input(_key(TrainingRoom.SPAWN_KEY))
	assert_eq(room.host.sim.pickups.size(), 1)
	room._unhandled_key_input(_key(TrainingRoom.DUMMY_KEY))
	assert_eq(room.session.dummy.mode, TrainingDummy.Mode.CROUCH)


func test_training_menu_pauses_and_changes_characters() -> void:
	var room: TrainingRoom = load(TRAINING).instantiate()
	add_child_autofree(room)
	await wait_physics_frames(2)
	room.toggle_menu()
	var tick := room.host.sim.current_tick
	await wait_physics_frames(5)
	assert_eq(room.host.sim.current_tick, tick, "paused while the menu is open")
	room._on_characters_chosen(&"vexa", &"kael")
	assert_eq(room.host.sim.fighters[0].stats, Roster.character(&"vexa").stats)
	assert_eq(room.host.sim.fighters[1].stats, Roster.character(&"kael").stats)


func test_move_list_panel_lists_every_move() -> void:
	var room: TrainingRoom = load(TRAINING).instantiate()
	add_child_autofree(room)
	await wait_physics_frames(1)
	room.toggle_move_list()
	var panel: MoveListPanel = room._move_list
	var moves := MoveList.all_moves(Roster.character(room.player_id).stats.move_set)
	assert_eq(panel.row_count(), moves.size())


func test_tutorial_scene_runs_a_lesson_with_the_autopilot() -> void:
	var room: TutorialRoom = load(TUTORIAL).instantiate()
	room.autopilot_enabled = true
	room.first_lesson = 1
	add_child_autofree(room)
	await wait_until(func() -> bool: return room.session.lesson_complete, 20.0)
	assert_true(room.session.lesson_complete, "the light string lesson clears in the real scene")
	room._unhandled_key_input(_key(KEY_ENTER))
	assert_eq(room.session.lesson_index, 2)
	assert_false(room.session.lesson_complete)


func test_tutorial_page_keys_change_lesson() -> void:
	var room: TutorialRoom = load(TUTORIAL).instantiate()
	add_child_autofree(room)
	await wait_physics_frames(1)
	room._unhandled_key_input(_key(KEY_PAGEDOWN))
	assert_eq(room.session.lesson_index, 1)
	room._unhandled_key_input(_key(KEY_PAGEUP))
	assert_eq(room.session.lesson_index, 0)
