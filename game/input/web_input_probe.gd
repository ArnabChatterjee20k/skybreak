class_name WebInputProbe
extends RefCounted
## On the web only: logs the local player's presses and the moves they start in
## window.skybreakInputs, so browser tests (tools/web/controls_web.js mouse) see clicks land.

## Entries kept in the page (oldest dropped).
const MAX_ENTRIES := 200

var enabled := OS.has_feature("web")
var _last_move := ""


## Call once per tick with the local input, the local fighter's current move id ("" for none)
## and its state (the sim's enum value, for test logs).
func record(tick: int, input: FighterInput, move: String, state: int = -1) -> void:
	if not enabled:
		return
	var started := move != _last_move and move != ""
	_last_move = move
	if input.pressed_actions == 0 and not started:
		return
	var entry := {"tick": tick, "pressed": input.pressed_actions, "held": input.held_actions, "move": move,
		"state": state}
	JavaScriptBridge.eval("(function(e){var a=window.skybreakInputs=window.skybreakInputs||[];a.push(e);if(a.length>%d)a.shift();})(%s);"
		% [MAX_ENTRIES, JSON.stringify(entry)])
