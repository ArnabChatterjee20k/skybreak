class_name DuoFlow
extends MatchFlow
## Duo match rules (GAME_DESIGN §8.2): one long round, the two humans (team 0)
## against the AI team (team 1), friendly fire off (the sim skips same-team hits),
## a shared life pool per team. A KO spends a life from the team's pool and the
## fighter comes back RESPAWN_TICKS later at its spawn; a team with every fighter
## down and no lives left loses. On time, the team with more lives plus fighters
## standing wins. Runs as RollbackSession rules, so it is rolled back with the sim.

const HUMAN_TEAM := 0
const AI_TEAM := 1
## GAME_DESIGN §8.1: back 3 s after a KO.
const RESPAWN_TICKS := 180
const DEFAULT_LIVES := 6
## The AI team's pool per AI fighter.
const AI_LIVES_EACH := 3
const DEFAULT_MINUTES := 5
## respawn_at value of a fighter that is down for good.
const OUT := -2

## Team per fighter.
var teams := PackedInt32Array()
## Lives left per team (KOs it can still come back from).
var lives := PackedInt32Array()
## Per fighter: sim tick of its respawn, -1 when standing, OUT when out of lives.
var respawn_at := PackedInt32Array()
## Winning team once decided, -1 for none or a draw.
var winning_team: int = -1


## team_of: team per fighter (0 humans, 1 AI); human_lives: the duo's pool.
func _init(team_of: Array[int] = [], human_lives: int = DEFAULT_LIVES,
		minutes: int = DEFAULT_MINUTES) -> void:
	super(team_of.size())
	var ai_count := 0
	for team in team_of:
		teams.append(team)
		respawn_at.append(-1)
		if team == AI_TEAM:
			ai_count += 1
	lives = PackedInt32Array([maxi(human_lives, 0), AI_LIVES_EACH * ai_count])
	timer_ticks = maxi(minutes, 1) * 60 * TICKS_PER_SECOND


## RollbackSession hook: runs after every sim tick.
func after_tick(sim: CombatSim) -> void:
	step(sim)


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
			_track_knockouts(sim)
			var beaten := _beaten_team(sim)
			if beaten >= 0:
				_finish(sim, AI_TEAM if beaten == HUMAN_TEAM else HUMAN_TEAM, false)
			elif timer_ticks == 0:
				_finish(sim, _time_leader(sim), true)
		Phase.KO:
			if phase_ticks >= KO_TICKS:
				_enter(Phase.MATCH_OVER)


## Online play keeps a fixed tick rate: no KO slow motion.
func time_scale() -> float:
	return 1.0


func banner(names: Array) -> Dictionary:
	if not enabled:
		return {"title": "", "subtitle": ""}
	match phase:
		Phase.INTRO:
			if phase_ticks < INTRO_ROUND_TICKS:
				return {"title": "DUO", "subtitle": "%d LIVES VS %d" % [lives[HUMAN_TEAM], lives[AI_TEAM]]}
		Phase.KO:
			return {"title": "TIME!" if timed_out else "K.O.!", "subtitle": _result_text()}
		Phase.MATCH_OVER:
			return {"title": _result_text(), "subtitle": ""}
	return super(names)


## For the desync check: everything this rules object decides.
func state_hash() -> int:
	return hash([phase, phase_ticks, timer_ticks, lives, respawn_at, winning_team, last_winner])


## Fighters of team still standing or coming back.
func alive_on(team: int, sim: CombatSim) -> int:
	var count := 0
	for i in teams.size():
		if teams[i] == team and (not sim.fighters[i].is_knocked_out() or respawn_at[i] >= 0):
			count += 1
	return count


func _track_knockouts(sim: CombatSim) -> void:
	var pending := false
	for i in teams.size():
		var fighter := sim.fighters[i]
		if respawn_at[i] >= 0:
			if sim.current_tick >= respawn_at[i]:
				respawn_at[i] = -1
				var at: Vector3 = spawn_points[i] if i < spawn_points.size() else sim.spawn_points[i]
				sim.respawn_fighter(i, at)
			else:
				pending = true
		elif respawn_at[i] == -1 and fighter.is_knocked_out():
			if lives[teams[i]] > 0:
				lives[teams[i]] -= 1
				respawn_at[i] = sim.current_tick + RESPAWN_TICKS
				pending = true
			else:
				respawn_at[i] = OUT
	# A whole team down at once ends the sim's round; with a respawn coming it goes on.
	if pending and sim.round_over:
		sim.round_over = false
		sim.round_winner = -1
		sim.winning_team = -1


## The team with every fighter out for good, or -1.
func _beaten_team(sim: CombatSim) -> int:
	for team in [HUMAN_TEAM, AI_TEAM]:
		if alive_on(team, sim) == 0:
			return team
	return -1


func _time_leader(sim: CombatSim) -> int:
	var humans := lives[HUMAN_TEAM] + _standing(HUMAN_TEAM, sim)
	var ai := lives[AI_TEAM] + _standing(AI_TEAM, sim)
	if humans == ai:
		return -1
	return HUMAN_TEAM if humans > ai else AI_TEAM


func _standing(team: int, sim: CombatSim) -> int:
	var count := 0
	for i in teams.size():
		if teams[i] == team and not sim.fighters[i].is_knocked_out():
			count += 1
	return count


func _finish(_sim: CombatSim, team: int, on_time: bool) -> void:
	winning_team = team
	timed_out = on_time
	last_winner = teams.find(team) if team >= 0 else -1
	for i in teams.size():
		if team >= 0 and teams[i] == team:
			wins[i] += 1
	_enter(Phase.KO)


func _result_text() -> String:
	if winning_team == HUMAN_TEAM:
		return "DUO WINS!"
	if winning_team == AI_TEAM:
		return "THE AI WINS"
	return "DRAW"
