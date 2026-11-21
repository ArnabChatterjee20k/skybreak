class_name EscapeVfx
extends RefCounted
## What the escape tools (T-DEF3) look like: world effects for MatchVfx, sparks
## and shake for CombatFeedback, and the view-only perfect-block slow (§5.10).

const E := CombatSim.EventType
## Combo breaker: exactly one beat (art bible §7), a single shockwave ring in its colour.
const BREAKER_EFFECTS: Array[StringName] = [&"breaker_ring"]
## Breaker ring size: about 1.2x the ring's base size.
const BREAKER_RING_SCALE := 1.2
const BREAKER_COLOR := Color(1.0, 0.95, 0.75)
const TECH_COLOR := Color(0.75, 0.9, 1.0)
const ROLL_DUST := Color(0.8, 0.72, 0.6)


## MatchVfx kinds for an air tech or tech roll: a ghost where it left; a caught tech bursts.
static func tech_effects(event: Dictionary) -> Array[StringName]:
	if event.get("caught", false):
		return [&"anime_burst"]
	return [&"tech_ghost"]


## CombatFeedback plan for an escape event, or {} when it is not one.
static func plan_for(event: Dictionary, shockwave: PackedScene, spark: PackedScene,
		counter: PackedScene) -> Dictionary:
	match event.get("type", -1):
		E.COMBO_BREAKER:
			# The ring comes from MatchVfx; here only the shake, so nothing stacks on it.
			return {"effects": [], "color": BREAKER_COLOR, "scale": 1.0, "shake": 0.55, "impact_frames": 0}
		E.AIR_TECH:
			if event.get("caught", false):
				return {"effects": [counter], "color": Color.TRANSPARENT, "scale": 1.0, "shake": 0.3,
					"impact_frames": 0}
			return {"effects": [shockwave], "color": TECH_COLOR, "scale": 0.45, "shake": 0.0, "impact_frames": 0}
		E.TECH_ROLL:
			return {"effects": [shockwave], "color": ROLL_DUST, "scale": 0.35, "shake": 0.05, "impact_frames": 0}
		E.CHASE:
			return {"effects": [shockwave], "color": TECH_COLOR, "scale": 0.3, "shake": 0.0, "impact_frames": 0}
		E.WAKEUP:
			return {"effects": [shockwave], "color": ROLL_DUST, "scale": 0.25, "shake": 0.0, "impact_frames": 0}
	return {}


## View-only slow-motion after a perfect block: Engine.time_scale wanted per sim tick.
## The sim never changes speed; the arena multiplies this into Engine.time_scale.
class ViewSlow:
	extends RefCounted
	var scale: float = 0.8
	var ticks: int = 6
	var enabled: bool = true
	var _left: int = 0

	func _init(tuning: EscapeTuning = null) -> void:
		if tuning != null:
			scale = tuning.perfect_block_view_scale
			ticks = tuning.perfect_block_view_ticks

	## Counts one sim tick down, then starts the slow if this tick perfect-blocked.
	func react(events: Array[Dictionary]) -> void:
		_left = maxi(_left - 1, 0)
		if not enabled:
			return
		for event in events:
			if event.get("type", -1) == E.PERFECT_BLOCK:
				_left = ticks

	func time_scale() -> float:
		return scale if _left > 0 else 1.0
