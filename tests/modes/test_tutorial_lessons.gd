extends GutTest
## Every tutorial lesson can be completed by the scripted autopilot, and none
## completes by standing still.

## Generous cap per lesson; the autopilot needs far less.
const MAX_TICKS := 1800


func _session() -> TutorialSession:
	var sim := CombatSim.new(11)
	sim.add_fighter(Vector3(0, 1, 6), Roster.character(&"kael").stats)
	sim.add_fighter(Vector3(0, 1, -6), Roster.character(&"vexa").stats)
	sim.lock_everyone_onto_nearest()
	return TutorialSession.new(sim)


## Runs the current lesson with the autopilot; returns the ticks it took, or -1.
func _autopilot(session: TutorialSession) -> int:
	var pilot := TutorialAutopilot.new()
	for tick in MAX_TICKS:
		session.sim.tick(session.inputs_for(pilot.input_for(session)))
		session.after_tick()
		if session.lesson_complete:
			return tick + 1
	return -1


func test_tutorial_has_eight_to_twelve_short_lessons() -> void:
	var lessons := TutorialLessons.all()
	assert_between(lessons.size(), 8, 12)
	for lesson in lessons:
		assert_ne(lesson.title, "")
		assert_between(lesson.steps.size(), 1, 5, lesson.title)
		for step in lesson.steps:
			assert_lt((step.text as String).length(), 90, "short copy: %s" % step.text)


func test_lessons_cover_the_core_topics() -> void:
	var ids: Array = TutorialLessons.all().map(func(l: TutorialLesson) -> StringName: return l.id)
	for topic in [&"move", &"light", &"heavy", &"air", &"defense", &"grab", &"dash", &"meters", &"weapons"]:
		assert_has(ids, topic)


func test_every_lesson_is_completed_by_the_autopilot() -> void:
	var session := _session()
	for index in session.lessons.size():
		session.start_lesson(index)
		var ticks := _autopilot(session)
		assert_gt(ticks, 0, "lesson %d (%s) passes, stuck on step %d" % [
			index, session.lesson().title, session.step_index])


func test_the_whole_tutorial_runs_through_in_order() -> void:
	var session := _session()
	var passed := []
	session.lesson_passed.connect(func(index: int) -> void: passed.append(index))
	while true:
		assert_gt(_autopilot(session), 0, "lesson %d passes" % session.lesson_index)
		if not session.next_lesson():
			break
	assert_eq(passed.size(), session.lessons.size())
	assert_true(session.is_last_lesson())


func test_standing_still_passes_no_lesson() -> void:
	var session := _session()
	for index in session.lessons.size():
		session.start_lesson(index)
		for _tick in 300:
			session.sim.tick(session.inputs_for(FighterInput.new()))
			session.after_tick()
		assert_false(session.lesson_complete, "%s needs the player" % session.lesson().title)
		assert_eq(session.step_index, 0, "%s step 1 needs the player" % session.lesson().title)


func test_steps_pass_in_order_and_report_it() -> void:
	var session := _session()
	var steps := []
	session.step_passed.connect(func(index: int) -> void: steps.append(index))
	session.start_lesson(0)
	_autopilot(session)
	assert_eq(steps, [0, 1, 2, 3])


func test_retry_starts_the_lesson_over() -> void:
	var session := _session()
	session.start_lesson(1)
	_autopilot(session)
	session.retry()
	assert_false(session.lesson_complete)
	assert_eq(session.step_index, 0)
	assert_eq(session.lesson_index, 1)
