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
