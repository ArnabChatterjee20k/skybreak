class_name TutorialPrompt
extends ModeCanvas
## Tutorial on-screen prompts in the match HUD style: lesson number and
## title, the intro line, the steps with checks, a "Nice!" pop when a step
## passes, and the lesson-clear banner with pass/next keys.

## Fits between the two fighter plates at the top of the HUD.
const WIDTH := 720.0
const TOP := 32.0
const STEP_HEIGHT := 40.0
const STEP_FONT := 22
const POP_SECONDS := 0.9

var session: TutorialSession

var _pop := 0.0


func _process(delta: float) -> void:
	_pop = maxf(_pop - delta, 0.0)
	queue_redraw()


## Shows the short "Nice!" pop; the room calls it when a step passes.
func pop() -> void:
	_pop = POP_SECONDS


func _draw_design() -> void:
	if session == null:
		return
	var lesson := session.lesson()
	var footer := 44.0
	var height := 112.0 + lesson.steps.size() * STEP_HEIGHT + footer
	var rect := Rect2((DESIGN.x - WIDTH) / 2.0, TOP, WIDTH, height)
	_panel(rect, GOOD if session.lesson_complete else ACCENT)
	var x := rect.position.x + 24.0
	var y := rect.position.y + 42.0
	_text(Vector2(x, y), "LESSON %d / %d" % [session.lesson_index + 1, session.lessons.size()], 20, ACCENT)
	_text(Vector2(x + 150, y), lesson.title, 28)
	y += 34.0
	_text(Vector2(x, y), lesson.intro, 19, DIM)
	y += 14.0
	for i in lesson.steps.size():
		y += STEP_HEIGHT
		var done := session.lesson_complete or i < session.step_index
		var current := not session.lesson_complete and i == session.step_index
		_marker(Vector2(x + 12, y - 8), done, current)
		var color := DIM if done else (Color.WHITE if current else Color(0.55, 0.57, 0.62))
		var text: String = lesson.steps[i].text
		_rich_text(Vector2(x + 40, y), text, fitted_size(text, STEP_FONT, WIDTH - 88.0), color)
	y = rect.end.y - 16.0
	var keys := "[PgUp] [PgDn] Change lesson"
	if session.lesson_complete:
		keys = ("[Enter] Finish" if session.is_last_lesson() else "[Enter] Next lesson") \
			+ "    [Backspace] Retry"
	_rich_text(Vector2(rect.end.x - 24 - rich_width(keys, 18), y), keys, 18, DIM)
	if session.lesson_complete:
		var banner := "TUTORIAL COMPLETE!" if session.is_last_lesson() else "LESSON CLEAR!"
		_text(Vector2(DESIGN.x / 2, rect.end.y + 110), banner, 72, ACCENT, HORIZONTAL_ALIGNMENT_CENTER, 12)
		if session.is_last_lesson():
			_text(Vector2(DESIGN.x / 2, rect.end.y + 160), "Head to Training to keep sharpening your skills.", 28,
				Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	elif _pop > 0.0:
		var rise := (1.0 - _pop / POP_SECONDS) * 30.0
		var color := Color(GOOD, clampf(_pop / POP_SECONDS * 2.0, 0.0, 1.0))
		_text(Vector2(DESIGN.x / 2, rect.end.y + 70 - rise), "Nice!", 48, color, HORIZONTAL_ALIGNMENT_CENTER, 10)


## A check for done steps, an arrow for the current one, a dot for later ones.
func _marker(centre: Vector2, done: bool, current: bool) -> void:
	if done:
		draw_polyline(PackedVector2Array([centre + Vector2(-9, 0), centre + Vector2(-2, 8), centre + Vector2(11, -9)]),
			GOOD, 5.0)
	elif current:
		draw_colored_polygon(PackedVector2Array([centre + Vector2(-8, -10), centre + Vector2(10, 0),
			centre + Vector2(-8, 10)]), ACCENT)
	else:
		draw_circle(centre, 5.0, Color(0.55, 0.57, 0.62))


## The largest size up to font_size at which a line with key caps fits in width.
static func fitted_size(text: String, font_size: int, width: float) -> int:
	var fitted := font_size
	while fitted > 14 and rich_width(text, fitted) > width:
		fitted -= 1
	return fitted
