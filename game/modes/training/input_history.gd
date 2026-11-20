class_name InputHistory
extends RefCounted
## The input display: the player's recent inputs, newest first. Identical
## ticks merge into one row with a tick count, like a fighting-game input log.

const MAX_ROWS := 14

const BUTTON_LABELS := {
	FighterInput.Action.LIGHT: "L",
	FighterInput.Action.HEAVY: "H",
	FighterInput.Action.BLOCK: "E",
	FighterInput.Action.DASH: "Sh",
	FighterInput.Action.GRAB: "F",
	FighterInput.Action.CHARGE: "R",
	FighterInput.Action.PICKUP: "G",
	FighterInput.Action.THROW: "V",
	FighterInput.Action.WEAPON_NEXT: "C",
	FighterInput.Action.LOCK_TOGGLE: "Tab",
}

## Newest first: {text, ticks}.
var rows: Array[Dictionary] = []


func add(input: FighterInput) -> void:
	var text := label_for(input)
	if not rows.is_empty() and rows[0].text == text:
		rows[0].ticks += 1
		return
	rows.push_front({"text": text, "ticks": 1})
	if rows.size() > MAX_ROWS:
		rows.pop_back()


## A note row between inputs (ticks 0), e.g. what a Shift tap turned into (T-DEF2).
func note(text: String) -> void:
	rows.push_front({"text": text, "ticks": 0})
	if rows.size() > MAX_ROWS:
		rows.pop_back()


## The note for a DODGE or PERFECT_DODGE event, or "" for anything else.
static func dodge_note(event: Dictionary) -> String:
	match event.get("type", -1):
		CombatSim.EventType.DODGE:
			var kind := String(FighterDodge.Kind.keys()[int(event.kind)])
			return "» %s DODGE%s" % [kind, " (no i-frames)" if event.stale else ""]
		CombatSim.EventType.PERFECT_DODGE:
			return "» PERFECT DODGE%s" % (" +%d ki" % event.ki if event.ki > 0 else "")
	return ""


func clear() -> void:
	rows = []


## Direction (numpad-style arrow, ↑↓ for ascend/descend) plus held buttons; "·" when idle.
static func label_for(input: FighterInput) -> String:
	var parts: Array[String] = []
	var direction := direction_arrow(input.move)
	if direction != "":
		parts.append(direction)
	if input.vertical > 0:
		parts.append("Up")
	elif input.vertical < 0:
		parts.append("Down")
	for action in BUTTON_LABELS:
		if input.is_held(action):
			parts.append(BUTTON_LABELS[action])
	return " ".join(parts) if not parts.is_empty() else "·"


static func direction_arrow(move: Vector2) -> String:
	if move.length() < 0.3:
		return ""
	var arrows := ["→", "↗", "↑", "↖", "←", "↙", "↓", "↘"]
	# move.y is forward, so atan2 counts counter-clockwise from right.
	return arrows[posmod(roundi(atan2(move.y, move.x) / (PI / 4.0)), 8)]
