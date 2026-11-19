class_name MatchFlow
extends RefCounted
## Round flow on top of CombatSim, counted in sim ticks: a "ROUND n / FIGHT!"
## intro with input held, the fight with a round timer, a "K.O.!" moment in
## slow motion, then the next round until someone has WINS_NEEDED wins.
## The arena calls step() after every sim.tick() and only feeds real input
## while accepts_input(). Disabled (scripted playtests), it is always FIGHT.

enum Phase { INTRO, FIGHT, KO, MATCH_OVER }

const TICKS_PER_SECOND := 60
const ROUND_SECONDS := 99
const WINS_NEEDED := 2
## "ROUND n" for the first part of the intro, then "FIGHT!".
const INTRO_TICKS := 120
const INTRO_ROUND_TICKS := 70
## KO banner time before the next round; the first KO_SLOW_TICKS run slowed.
const KO_TICKS := 180
const KO_SLOW_TICKS := 60
const KO_TIME_SCALE := 0.3

var enabled := true
var phase := Phase.INTRO
var phase_ticks := 0
var round_number := 1
var wins: Array[int] = []
var timer_ticks := ROUND_SECONDS * TICKS_PER_SECOND
## Winner of the last finished round, -1 for a draw.
var last_winner := -1
## True when the last round ended on time instead of a KO.
var timed_out := false


func _init(fighter_count: int = 2) -> void:
	for i in fighter_count:
		wins.append(0)


func accepts_input() -> bool:
	return not enabled or phase == Phase.FIGHT


## Advances one sim tick; call right after sim.tick().
func step(sim: CombatSim) -> void:
	if not enabled:
		return
	phase_ticks += 1
	match phase:
		Phase.INTRO:
			if phase_ticks >= INTRO_TICKS:
				_enter(Phase.FIGHT)
		Phase.FIGHT:
			timer_ticks = maxi(timer_ticks - 1, 0)
			if sim.round_over:
				_finish_round(sim.round_winner, false)
			elif timer_ticks == 0:
				_finish_round(_leader(sim), true)
		Phase.KO:
			if phase_ticks >= KO_TICKS:
				if wins.max() >= WINS_NEEDED:
					_enter(Phase.MATCH_OVER)
				else:
					round_number += 1
					timer_ticks = ROUND_SECONDS * TICKS_PER_SECOND
					sim.start_round()
					_enter(Phase.INTRO)


## Engine.time_scale wanted now: slowed right after a KO.
func time_scale() -> float:
	return KO_TIME_SCALE if phase == Phase.KO and phase_ticks < KO_SLOW_TICKS else 1.0


## The big centre text: {title, subtitle}; empty title when none.
func banner(names: Array) -> Dictionary:
	if not enabled:
		return {"title": "", "subtitle": ""}
	match phase:
		Phase.INTRO:
			if phase_ticks < INTRO_ROUND_TICKS:
				return {"title": "ROUND %d" % round_number, "subtitle": ""}
			return {"title": "FIGHT!", "subtitle": ""}
		Phase.KO:
			var title := "TIME!" if timed_out else "K.O.!"
			return {"title": title, "subtitle": _winner_text(names, "WINS THE ROUND")}
		Phase.MATCH_OVER:
			return {"title": _winner_text(names, "WINS!"), "subtitle": ""}
	return {"title": "", "subtitle": ""}


## Whole seconds left on the round clock.
func seconds_left() -> int:
	return ceili(float(timer_ticks) / TICKS_PER_SECOND)


func _finish_round(winner: int, on_time: bool) -> void:
	last_winner = winner
	timed_out = on_time
	if winner >= 0:
		wins[winner] += 1
	_enter(Phase.KO)


func _enter(next: Phase) -> void:
	phase = next
	phase_ticks = 0


## Time-out winner: most health left (fraction of max); -1 on a tie.
static func _leader(sim: CombatSim) -> int:
	var best := -1
	var best_value := -1.0
	var tied := false
	for i in sim.fighters.size():
		var fighter := sim.fighters[i]
		var value := float(fighter.health) / maxf(fighter.stats.max_health * FighterState.METER_UNIT, 1.0)
		if value > best_value + 0.0001:
			best = i
			best_value = value
			tied = false
		elif absf(value - best_value) <= 0.0001:
			tied = true
	return -1 if tied else best


func _winner_text(names: Array, suffix: String) -> String:
	if last_winner < 0 or last_winner >= names.size():
		return "DRAW"
	return "%s %s" % [names[last_winner], suffix]
