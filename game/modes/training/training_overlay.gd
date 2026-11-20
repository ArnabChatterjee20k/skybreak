class_name TrainingOverlay
extends ModeCanvas
## Training HUD: frame data of the player's last move and the measured
## advantage of the last exchange, the combo on the dummy with its damage,
## the input display, and the dummy/recording status with the key legend.

const LEFT := 32.0
const TOP := 196.0
const LEGEND := [
	"[F1] Menu", "[F2] Move list", "[Backspace] Reset", "[F4] Spawn weapon",
	"[F5] Dummy mode", "[F6] Record", "[F7] Playback",
]

var session: TrainingSession
## Weapon the next F4 spawns, shown in the legend.
var next_weapon := ""


func _draw_design() -> void:
	if session == null:
		return
	_draw_frame_data(Rect2(LEFT, TOP, 400, 300))
	_draw_inputs(Rect2(LEFT, DESIGN.y - 32 - 420, 220, 420))
	_draw_status(Rect2(DESIGN.x - 32 - 400, TOP, 400, 132))
	_draw_legend(Rect2(DESIGN.x - 32 - 400, DESIGN.y - 32 - 300, 400, 300))
	if session.input_loop.recording:
		var seconds := session.input_loop.length() / float(CombatSim.TICKS_PER_SECOND)
		_text(Vector2(DESIGN.x / 2, 230), "● REC  %.1f / 10 s" % seconds, 40, BAD, HORIZONTAL_ALIGNMENT_CENTER, 8)
		var hint := "You control the dummy. [F6] stops."
		_rich_text(Vector2(DESIGN.x / 2 - rich_width(hint, 24) / 2, 276), hint, 24)


func _draw_frame_data(rect: Rect2) -> void:
	_panel(rect)
	var meter := session.frame_meter
	var x := rect.position.x + 20
	var y := rect.position.y + 40
	_text(Vector2(x, y), "FRAME DATA", 22, ACCENT)
	var move := meter.last_move
	y += 40
	_text(Vector2(x, y), move.display_name if move else "Attack the dummy", 28)
	y += 38
	if move:
		_row(x, y, "Start / Active / Recov",
			"%d / %d / %d" % [move.startup_ticks, move.active_ticks, move.recovery_ticks])
		y += 32
		_row(x, y, "On hit / On block", "%s / %s" % [FrameMeter.on_hit_text(move), FrameMeter.on_block_text(move)])
		y += 32
		_row(x, y, "Damage", "%d" % (meter.last_damage if meter.last_damage > 0 else move.damage))
		y += 32
	if meter.has_measurement:
		var value := FrameMeter.signed(meter.measured_advantage)
		_row(x, y, "Last exchange (%s)" % meter.measured_kind, value,
			GOOD if meter.measured_advantage >= 0 else BAD)
	y = rect.end.y - 22
	if meter.combo_hits > 0:
		_text(Vector2(x, y), "COMBO  %d HITS   %d DMG" % [meter.combo_hits, meter.combo_damage], 26, ACCENT)


func _row(x: float, y: float, label: String, value: String, color: Color = Color.WHITE) -> void:
	_text(Vector2(x, y), label, 20, DIM)
	_text(Vector2(x + 360, y), value, 22, color, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_inputs(rect: Rect2) -> void:
	_panel(rect, KI)
	var x := rect.position.x + 16
	var y := rect.position.y + 36
	_text(Vector2(x, y), "INPUTS", 20, KI)
	for row in session.input_history.rows:
		y += 27
		if y > rect.end.y - 8:
			break
		if row.ticks > 0:
			_text(Vector2(x, y), "%3d" % mini(row.ticks, 999), 18, DIM)
		_text(Vector2(x + 50, y), row.text, 20)


func _draw_status(rect: Rect2) -> void:
	_panel(rect)
	var x := rect.position.x + 20
	_text(Vector2(x, rect.position.y + 38), "DUMMY", 20, ACCENT)
	_text(Vector2(x, rect.position.y + 72), TrainingDummy.MODE_NAMES[session.dummy.mode], 26)
	var flags: Array[String] = []
	flags.append("Meters ∞" if session.infinite_meters else "Meters normal")
	flags.append("Health ∞" if session.infinite_health else "Health normal")
	if session.input_loop.has_recording():
		flags.append("Rec %.1f s" % (session.input_loop.length() / float(CombatSim.TICKS_PER_SECOND)))
	_text(Vector2(x, rect.position.y + 108), "   ".join(flags), 18, DIM)


func _draw_legend(rect: Rect2) -> void:
	_panel(rect, Color(0.5, 0.5, 0.55))
	var y := rect.position.y + 40
	for line: String in LEGEND:
		var text := line
		if line.begins_with("[F4]") and next_weapon != "":
			text += ": " + next_weapon
		_rich_text(Vector2(rect.position.x + 20, y), text, 20)
		y += 37
