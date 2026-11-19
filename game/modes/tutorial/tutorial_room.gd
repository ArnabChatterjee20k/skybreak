class_name TutorialRoom
extends Node
## Tutorial mode entry scene: the test arena, the lesson prompts and the goal
## checks. Enter goes on after a lesson clears, Backspace retries, PgUp/PgDn
## change lesson.

## Emitted after the last lesson (Enter), for the menus lane.
signal finished

@export var player_id: StringName = &"kael"
@export var dummy_id: StringName = &"vexa"
## Lesson to open on (0-based).
@export var first_lesson := 0
## True to let the scripted autopilot play (attract mode and screen captures).
@export var autopilot_enabled := false

var session: TutorialSession
var host := ArenaHost.new()
var autopilot := TutorialAutopilot.new()

var _ui := CanvasLayer.new()
var _prompt := TutorialPrompt.new()


func _ready() -> void:
	add_child(host)
	host.build(player_id, dummy_id)
	session = TutorialSession.new(host.sim)
	session.step_passed.connect(func(_index: int) -> void: _prompt.pop())
	session.start_lesson(first_lesson)
	_ui.layer = 20
	add_child(_ui)
	_prompt.session = session
	_ui.add_child(_prompt)


func _physics_process(_delta: float) -> void:
	var player := host.read_player_input()
	if autopilot_enabled:
		player = autopilot.input_for(session)
	host.step(session.inputs_for(player))
	session.after_tick()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if not session.lesson_complete:
				return
			if not session.next_lesson():
				finished.emit()
		KEY_BACKSPACE:
			session.retry()
		KEY_PAGEDOWN:
			session.start_lesson(session.lesson_index + 1)
		KEY_PAGEUP:
			session.start_lesson(session.lesson_index - 1)
		_:
			return
	get_viewport().set_input_as_handled()
