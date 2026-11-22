class_name MotionInput
extends RefCounted
## Lenient motion-input reading over a fighter's direction history (numpad notation,
## relative to facing: 6 = toward the opponent). A motion counts when its directions show up
## in order inside WINDOW ticks and its last one is at most RECENT ticks old.

const WINDOW := 16
const RECENT := 8
const DASH_WINDOW := 12


## True when fighter's history ends in motion (&"236", &"623", &"214", &"236236", &"66", &"44").
static func matches(fighter: PureFighter, motion: StringName) -> bool:
	match motion:
		&"236":
			return _sequence(fighter, [[2], [6]], WINDOW)
		&"214":
			return _sequence(fighter, [[2], [4]], WINDOW)
		&"623":
			return _sequence(fighter, [[6], [2, 1], [3]], WINDOW + 2)
		&"236236":
			return _sequence(fighter, [[2], [6, 3], [2], [6]], WINDOW * 2)
		&"66":
			return _tap_twice(fighter, 6)
		&"44":
			return _tap_twice(fighter, 4)
	return false


## Finds steps (each a set of accepted directions) in order inside window ticks; the
## newest step must be at most RECENT ticks old.
static func _sequence(fighter: PureFighter, steps: Array, window: int) -> bool:
	var step := steps.size() - 1
	for ago in window:
		if (steps[step] as Array).has(fighter.dir_ago(ago)):
			if step == steps.size() - 1 and ago >= RECENT:
				return false
			step -= 1
			if step < 0:
				return true
	return false


## A direction tapped, released to anything else, then tapped again within DASH_WINDOW,
## the second tap this tick.
static func _tap_twice(fighter: PureFighter, dir: int) -> bool:
	if fighter.dir_ago(0) != dir or fighter.dir_ago(1) == dir:
		return false
	var released := false
	for ago in range(1, DASH_WINDOW):
		var seen := fighter.dir_ago(ago)
		if seen != dir:
			released = true
		elif released:
			return true
	return false
