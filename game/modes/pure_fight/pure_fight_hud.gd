class_name PureFightHud
extends Control
## Pure Fight HUD (GAME_DESIGN §16.5): health bars, round pips, the 99 s timer, finisher
## meters, combo counters, round banners and callouts; in training, the last move's frame
## data and the measured frame advantage. Reads the sim only.

const BAR_SIZE := Vector2(720, 34)
const METER_SIZE := Vector2(420, 18)

var sim: PureFightSim
var names: Array[String] = ["", ""]
var colors: Array[Color] = [MenuTheme.HOT, MenuTheme.CYAN]
var training := false
## One-line controls hint along the bottom for the match's first HINT_TICKS ("" = none). Set before
## _ready. Counted in sim ticks, so a slow first frame (a zone loading) never uses it up.
var hint := ""
const HINT_TICKS := 12 * 60
var _hint: Label
var _bars: Array[ColorRect] = []
var _trails: Array[ColorRect] = []
var _meters: Array[ColorRect] = []
var _meter_text: Array[Label] = []
var _pips: Array[Label] = []
var _combo: Array[Label] = []
var _timer: Label
var _banner: Label
var _callout: Label
var _info: Label
var _banner_time := 0.0
var _callout_time := 0.0
var _trail_hp: Array[float] = [1.0, 1.0]
var _combo_shown: Array[float] = [0.0, 0.0]
var _last_move: Array[StringName] = [&"", &""]
## Training: ticks each fighter became actionable, for the measured advantage.
var _free_at: Array[int] = [0, 0]
var _was_free: Array[bool] = [true, true]
var _advantage := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 2:
		var left := i == 0
		var x := 80.0 if left else 1920.0 - 80.0 - BAR_SIZE.x
		var frame := ColorRect.new()
		frame.color = MenuTheme.INK
		frame.position = Vector2(x - 6, 54)
		frame.size = BAR_SIZE + Vector2(12, 12)
		add_child(frame)
		var trail := ColorRect.new()
		trail.color = Color(1, 1, 1, 0.8)
		trail.position = Vector2(x, 60)
		trail.size = BAR_SIZE
		add_child(trail)
		_trails.append(trail)
		var bar := ColorRect.new()
		bar.color = Color(1.0, 0.82, 0.2)
		bar.position = Vector2(x, 60)
		bar.size = BAR_SIZE
		add_child(bar)
		_bars.append(bar)
		var name := MenuTheme.label(names[i], 34, colors[i], 8)
		name.position = Vector2(x if left else x + BAR_SIZE.x - 300, 100)
		name.size = Vector2(300, 40)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
		add_child(name)
		var pips := MenuTheme.label("", 30, MenuTheme.GOLD, 6)
		pips.position = Vector2(x + BAR_SIZE.x - 120 if left else x, 100)
		pips.size = Vector2(120, 40)
		pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if left else HORIZONTAL_ALIGNMENT_LEFT
		add_child(pips)
		_pips.append(pips)
		var mx := 80.0 if left else 1920.0 - 80.0 - METER_SIZE.x
		var meter_back := ColorRect.new()
		meter_back.color = Color(MenuTheme.INK, 0.85)
		meter_back.position = Vector2(mx - 4, 1000)
		meter_back.size = METER_SIZE + Vector2(8, 8)
		add_child(meter_back)
		var meter := ColorRect.new()
		meter.color = MenuTheme.CYAN
		meter.position = Vector2(mx, 1004)
		meter.size = Vector2(0, METER_SIZE.y)
		add_child(meter)
		_meters.append(meter)
		var meter_text := MenuTheme.label("", 24, MenuTheme.TEXT, 6)
		meter_text.position = Vector2(mx, 960)
		meter_text.size = Vector2(METER_SIZE.x, 30)
		meter_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
		add_child(meter_text)
		_meter_text.append(meter_text)
		var combo := MenuTheme.label("", 44, MenuTheme.GOLD, 10)
		combo.position = Vector2(80 if left else 1920 - 80 - 420, 300)
		combo.size = Vector2(420, 120)
		combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
		add_child(combo)
		_combo.append(combo)
	_timer = MenuTheme.label("99", 72, MenuTheme.TEXT, 12)
	_timer.position = Vector2(960 - 80, 36)
	_timer.size = Vector2(160, 90)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_timer)
	_banner = MenuTheme.label("", 120, MenuTheme.GOLD, 18)
	_banner.position = Vector2(0, 380)
	_banner.size = Vector2(1920, 200)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_banner)
	_callout = MenuTheme.label("", 46, MenuTheme.HOT, 10)
	_callout.position = Vector2(0, 170)
	_callout.size = Vector2(1920, 70)
	_callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_callout)
	_info = MenuTheme.label("", 24, MenuTheme.TEXT, 6)
	_info.position = Vector2(80, 600)
	_info.size = Vector2(700, 300)
	_info.visible = training
	add_child(_info)
	_hint = MenuTheme.label(hint, 22, MenuTheme.TEXT, 6)
	_hint.position = Vector2(0, 1016)
	_hint.size = Vector2(1920, 44)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.visible = hint != ""
	add_child(_hint)


func show_callout(text: String) -> void:
	_callout.text = text
	_callout_time = 1.0


## Per tick: banners from events, training bookkeeping.
func after_tick(events: Array) -> void:
	for event: Dictionary in events:
		match int(event.type):
			PureFightSim.Ev.ROUND_START:
				_show("ROUND %d" % sim.round_number if sim.round_number < 3 or sim.pf[0].round_wins != sim.pf[1].round_wins \
					else "FINAL ROUND", 1.6)
			PureFightSim.Ev.FIGHT:
				_show("FIGHT!", 0.8)
			PureFightSim.Ev.KO:
				_show("K.O.", 2.0)
			PureFightSim.Ev.TIME_UP:
				_show("TIME", 2.0)
			PureFightSim.Ev.MATCH_WIN:
				var winner := int(event.a)
				_show(("%s WINS" % names[winner]) if winner >= 0 else "DRAW", 6.0)
			PureFightSim.Ev.MOVE:
				_last_move[int(event.a)] = event.move
	if training:
		_measure_advantage()


func _show(text: String, seconds: float) -> void:
	_banner.text = text
	_banner_time = seconds


func _measure_advantage() -> void:
	for i in 2:
		var fighter := sim.pf[i]
		var free := fighter.state in [PureFighter.State.IDLE, PureFighter.State.WALK, PureFighter.State.CROUCH]
		if free and not _was_free[i]:
			_free_at[i] = sim.current_tick
			var other := sim.pf[1 - i]
			var other_free := other.state in [PureFighter.State.IDLE, PureFighter.State.WALK, PureFighter.State.CROUCH]
			if other_free:
				_advantage = (_free_at[i] - _free_at[1 - i]) * (1 if i == 1 else -1)
		_was_free[i] = free


func _process(delta: float) -> void:
	if sim == null:
		return
	for i in 2:
		var fighter := sim.pf[i]
		var share := float(fighter.health) / fighter.max_health
		var width := BAR_SIZE.x * share
		_trail_hp[i] = maxf(share, move_toward(_trail_hp[i], share, delta * 0.5))
		var left := i == 0
		var x0 := 80.0 if left else 1920.0 - 80.0 - BAR_SIZE.x
		_bars[i].size.x = width
		_bars[i].position.x = x0 + (0.0 if left else BAR_SIZE.x - width)
		_bars[i].color = Color(1.0, 0.82, 0.2) if share > 0.3 else Color(1.0, 0.3, 0.2)
		_trails[i].size.x = BAR_SIZE.x * _trail_hp[i]
		_trails[i].position.x = x0 + (0.0 if left else BAR_SIZE.x - _trails[i].size.x)
		var pips := ""
		for r in PureFightSim.ROUNDS_TO_WIN:
			pips += "◆" if r < fighter.round_wins else "◇"
		_pips[i].text = pips
		var meter_share := float(fighter.meter) / PureMoves.METER_MAX
		_meters[i].size.x = METER_SIZE.x * meter_share
		var mx := 80.0 if left else 1920.0 - 80.0 - METER_SIZE.x
		_meters[i].position.x = mx + (0.0 if left else METER_SIZE.x * (1.0 - meter_share))
		var ready := fighter.meter >= PureMoves.METER_MAX
		_meters[i].color = MenuTheme.GOLD if ready else MenuTheme.CYAN
		_meter_text[i].text = "FINISHER READY" if ready else "FINISHER"
		var target := sim.pf[1 - i]
		if target.combo_hits >= 2:
			_combo[i].text = "%d HITS\n%d DMG" % [target.combo_hits, target.combo_damage]
			_combo_shown[i] = 1.2
		else:
			_combo_shown[i] = maxf(_combo_shown[i] - delta, 0.0)
		_combo[i].modulate.a = clampf(_combo_shown[i] / 0.4, 0.0, 1.0)
	_timer.text = "%02d" % ceili(sim.timer_ticks / 60.0)
	_banner_time = maxf(_banner_time - delta, 0.0)
	_banner.modulate.a = clampf(_banner_time / 0.3, 0.0, 1.0)
	_callout_time = maxf(_callout_time - delta, 0.0)
	_callout.modulate.a = clampf(_callout_time / 0.3, 0.0, 1.0)
	_hint.modulate.a = clampf((HINT_TICKS - sim.current_tick) / 60.0, 0.0, 1.0)
	if training:
		_info.text = _training_text()


func _training_text() -> String:
	var id := _last_move[0]
	var legend := sim.pf[0].legend
	if id == &"":
		return "TRAINING  (dummy blocks nothing; T or F4 cycles dummy mode)\nAttack to see frame data."
	var data := PureMoves.get_move(legend, id)
	var adv := PureMoves.advantage(data)
	return "%s  [%s]\nstartup %d  active %d  recovery %d\ndamage %d  guard %s\non block %+d  on hit %s\nmeasured advantage %+d" % [
		data.name, data.input, data.startup, data.active, data.recovery, data.damage, data.guard,
		adv.x, "KD" if adv.y == 999 else "%+d" % adv.y, _advantage]
