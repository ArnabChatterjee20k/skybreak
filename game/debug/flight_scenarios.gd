class_name FlightScenarios
extends RefCounted
## Scripted bot flights for playtests: the same routes feed the camera asserts
## in tests/playtest and the playtester's rendered frames.
## Each plan is func(fighter_index: int, tick: int) -> Dictionary with optional
## "held" (FighterInput.Action bits), "move" (Vector2) and "vertical" (int).
## Fighter 0 is the player, fighter 1 the opponent.

const DASH := FighterInput.Action.DASH
const BLOCK := FighterInput.Action.BLOCK
const LOCK := FighterInput.Action.LOCK_TOGGLE


## Name -> {"ticks": int, "plan": Callable}, in playtest order.
static func all() -> Dictionary:
	return {
		"1_takeoff": {"ticks": 240, "plan": _takeoff},
		"2_circle_strafe_locked": {"ticks": 300, "plan": _circle_strafe},
		"3_figure_eight": {"ticks": 360, "plan": _figure_eight},
		"4_sustained_dash_300m_unlocked": {"ticks": 300, "plan": _long_dash},
		"5_rush_from_far": {"ticks": 300, "plan": _rush_from_far},
		"6_vanish_steps": {"ticks": 240, "plan": _vanish_steps},
		"7_big_height_gap": {"ticks": 300, "plan": _big_height_gap},
		"8_lock_toggle_mid_flight": {"ticks": 300, "plan": _lock_toggle},
	}


## The opponent takes off and hovers at about 10 m.
static func _hovering_opponent(tick: int) -> Dictionary:
	return {"vertical": 1 if tick < 35 else 0}


static func _takeoff(index: int, tick: int) -> Dictionary:
	if index == 1:
		return {}
	return {"vertical": 1 if tick > 30 and tick < 120 else 0}


static func _circle_strafe(index: int, tick: int) -> Dictionary:
	if index == 1:
		return _hovering_opponent(tick)
	if tick < 35:
		return {"vertical": 1}
	return {"move": Vector2(1, 0)}


static func _figure_eight(index: int, tick: int) -> Dictionary:
	if index == 1:
		return _hovering_opponent(tick)
	if tick < 35:
		return {"vertical": 1}
	var rightward := ((tick - 35) / 80) % 2 == 0
	return {"move": Vector2(1 if rightward else -1, 0.3), "vertical": 1 if rightward else -1}


static func _long_dash(index: int, tick: int) -> Dictionary:
	if index == 1:
		return {}
	if tick < 30:
		return {"vertical": 1}
	if tick == 30 or tick == 31:
		return {"held": LOCK}
	if tick < 40:
		return {}
	return {"held": DASH, "move": Vector2(1, 0)}


static func _rush_from_far(index: int, tick: int) -> Dictionary:
	if index == 1:
		return _hovering_opponent(tick)
	if tick < 35:
		return {"vertical": 1}
	if tick < 150:
		return {"move": Vector2(0, -1), "held": DASH if tick > 40 else 0}
	if tick < 160:
		return {}
	if tick < 164:
		return {"held": DASH, "move": Vector2(0, 1)}
	return {}


static func _vanish_steps(index: int, tick: int) -> Dictionary:
	if index == 1:
		return _hovering_opponent(tick)
	if tick < 35:
		return {"vertical": 1}
	if (tick - 35) % 60 < 3:
		return {"held": DASH | BLOCK, "move": Vector2(1 if (tick / 60) % 2 == 0 else -1, 0)}
	return {}


static func _big_height_gap(index: int, _tick: int) -> Dictionary:
	if index == 1:
		return {}
	return {"vertical": 1 if _tick < 200 else 0, "move": Vector2(0.4, 0)}


static func _lock_toggle(index: int, tick: int) -> Dictionary:
	if index == 1:
		return _hovering_opponent(tick)
	if tick < 35:
		return {"vertical": 1}
	return {"move": Vector2(1, 0.5), "held": LOCK if tick in [100, 101, 200, 201] else 0}
