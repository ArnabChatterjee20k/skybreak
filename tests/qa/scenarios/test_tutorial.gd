extends QaScenario
## Every tutorial lesson, played start to finish by its autopilot, one scenario per lesson.

## Generous cap per lesson; the autopilot needs far less.
const MAX_TICKS := 1800


## Plays lesson id with the autopilot; asserts it passes every step in order.
func _play(id: StringName) -> void:
	sim = CombatSim.new(11)
	sim.add_fighter(Vector3(0, 1, 6), Roster.character(&"kael").stats)
	sim.add_fighter(Vector3(0, 1, -6), Roster.character(&"vexa").stats)
	sim.lock_everyone_onto_nearest()
	var session := TutorialSession.new(sim)
	var ids: Array = session.lessons.map(func(lesson: TutorialLesson) -> StringName: return lesson.id)
	assert_has(ids, id)
	if not ids.has(id):
		return
	session.start_lesson(ids.find(id))
	var steps: Array[int] = []
	session.step_passed.connect(func(index: int) -> void: steps.append(index))
	var pilot := TutorialAutopilot.new()
	var ticks := 0
	while ticks < MAX_TICKS and not session.lesson_complete:
		sim.tick(session.inputs_for(pilot.input_for(session)))
		session.after_tick()
		ticks += 1
	assert_true(session.lesson_complete, "%s passes (stuck on step %d after %d ticks)" % [id, session.step_index, ticks])
	var expected: Array[int] = []
	for index in session.lesson().steps.size():
		expected.append(index)
	assert_eq(steps, expected, "every step in order")
	gut.p("%s: %d ticks" % [id, ticks])


func test_the_move_lesson_is_completed_by_its_autopilot() -> void:
	_play(&"move")


func test_the_light_lesson_is_completed_by_its_autopilot() -> void:
	_play(&"light")


func test_the_heavy_lesson_is_completed_by_its_autopilot() -> void:
	_play(&"heavy")


func test_the_air_lesson_is_completed_by_its_autopilot() -> void:
	_play(&"air")


func test_the_defense_lesson_is_completed_by_its_autopilot() -> void:
	_play(&"defense")


func test_the_grab_lesson_is_completed_by_its_autopilot() -> void:
	_play(&"grab")


func test_the_dash_lesson_is_completed_by_its_autopilot() -> void:
	_play(&"dash")


func test_the_meters_lesson_is_completed_by_its_autopilot() -> void:
	_play(&"meters")


func test_the_weapons_lesson_is_completed_by_its_autopilot() -> void:
	_play(&"weapons")
