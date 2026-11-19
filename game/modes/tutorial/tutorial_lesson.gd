class_name TutorialLesson
extends RefCounted
## One tutorial lesson: a title, a short intro and a list of steps. Each step
## is a dictionary {text, check, dummy_mode, sparring}: check(session) -> bool
## passes the step, dummy_mode is a TrainingDummy.Mode, sparring "" / "jab" /
## "grab" makes the dummy attack. Key names in [brackets] show as key caps.

var id: StringName
var title: String
var intro: String
var steps: Array[Dictionary] = []
## Ki, guard and burst stay full (off when the lesson teaches the meters).
var infinite_meters := true
## Runs once when the lesson starts, after the reset: placement, spawns.
var setup: Callable


func _init(lesson_id: StringName, lesson_title: String, lesson_intro: String) -> void:
	id = lesson_id
	title = lesson_title
	intro = lesson_intro


## Adds a step; returns the lesson so steps chain.
func step(text: String, check: Callable, sparring := "",
		dummy_mode: TrainingDummy.Mode = TrainingDummy.Mode.STAND) -> TutorialLesson:
	steps.append({"text": text, "check": check, "sparring": sparring, "dummy_mode": dummy_mode})
	return self
