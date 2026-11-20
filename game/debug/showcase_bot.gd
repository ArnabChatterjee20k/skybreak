class_name ShowcaseBot
extends RefCounted
## Scripted Kael (0) vs Lyra (1) showcase: approach, simultaneous beams -> clash
## (Kael perfect on every beat, Lyra misses some), close in, Lyra attacks and
## Kael dodges at dodge_offset ticks into her attack, then Kael's ki blasts and
## a held charged blast. Phases advance on sim events.

const A := FighterInput.Action

var sim: CombatSim
var phase := "approach"
var phase_tick := 0
var dodge_offset := 4
var log: PackedStringArray = []
var _previous: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]
var _attack_tick := -1


func _init(combat_sim: CombatSim, offset: int = 4) -> void:
	sim = combat_sim
	dodge_offset = offset


## Call once per tick after sim.tick() to react to events.
func observe() -> void:
	for e in sim.events:
		var n: String = CombatSim.EventType.find_key(e.type)
		if n in ["BEAM_START", "BEAM_CLASH", "CLASH_END", "PERFECT_DODGE", "DODGE", "KI_FIRE", "KI_CHARGE", "HIT", "KO"]:
			log.append("%d %s %s" % [sim.current_tick, n, phase])
		if n == "CLASH_END" and phase == "clash":
			_go("close")
		if n == "PERFECT_DODGE" and phase == "dodge":
			_go("blasts")
		if n == "HIT" and phase == "dodge":
			_go("close")  # missed the timing; try again
	phase_tick += 1


func _go(next: String) -> void:
	phase = next
	phase_tick = 0
	_attack_tick = -1


func input_for(index: int, _tick: int) -> FighterInput:
	var me := sim.fighters[index]
	var them := sim.fighters[1 - index]
	var gap := me.position.distance_to(them.position)
	var held := 0
	var move := Vector2.ZERO
	var vertical := 0
	me.ki = maxi(me.ki, 80 * FighterState.METER_UNIT)  # showcase: never short of ki
	match phase:
		"approach":
			if gap > 16.0:
				move = Vector2(0, 1)
			elif index == 0 and phase_tick > 0:
				_go("beam")
		"beam":
			if phase_tick < 2:
				# Key 1 is the beam only for a legend without a special kit (Lyra); Kael's beam is
				# his ultimate on 4 since T-SP1 (key 1 is Comet Drive), so give it the burst.
				if SpecialRules.owns_key(me, 1):
					me.burst = maxi(me.burst, 2 * sim.meter_tuning.burst_stock_size * FighterState.METER_UNIT)
					held |= A.ULTIMATE
				else:
					held |= A.SPECIAL_1
			if not sim.beam_clashes.is_empty():
				_go("clash")
			elif phase_tick > 240:
				_go("close")
		"clash":
			if not sim.beam_clashes.is_empty():
				var clash: BeamClash = sim.beam_clashes[0]
				for k in clash.beat_ticks.size():
					var due := clash.beat_ticks[k] + (0 if index == 0 else (6 if k % 2 == 0 else 0))
					if sim.current_tick + 1 == due:
						held |= clash.beat_buttons[k]
			elif phase_tick > 30:
				_go("close")
		"close":
			var dy := them.position.y - me.position.y
			if absf(dy) > 0.4:
				vertical = 1 if dy > 0.0 else -1
			if gap > 2.0:
				move = Vector2(0, 1)
			elif index == 0:
				_go("dodge")
			if phase_tick > 600:
				_go("blasts")
		"dodge":
			if index == 1 and phase_tick % 60 < 2 and phase_tick < 300:
				held |= A.LIGHT
				if phase_tick % 60 == 0:
					_attack_tick = phase_tick
			if index == 0 and _attack_tick >= 0 and phase_tick - _attack_tick in [dodge_offset, dodge_offset + 1]:
				held |= A.DASH
				move = Vector2(1, 0)
			if phase_tick > 320:
				_go("blasts")
		"blasts":
			if index == 0:
				if gap < 10.0:
					move = Vector2(0, -1)
				if phase_tick in [10, 11, 40, 41, 70, 71]:
					held |= A.KI_BLAST
				if phase_tick >= 110 and phase_tick < 200:
					held |= A.KI_BLAST  # held: charged blast
			if phase_tick > 260:
				_go("free")
	var input := FighterInput.from_held(held, _previous[index])
	input.move = move
	input.vertical = vertical
	_previous[index] = input
	return input
