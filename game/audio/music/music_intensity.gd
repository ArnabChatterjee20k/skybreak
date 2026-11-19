class_name MusicIntensity
extends RefCounted
## How intense the fight is, for the music: calm, combat or climax.
## Fed once per sim tick; thresholds have hysteresis and a minimum hold so the
## level doesn't flap.

enum Level { CALM, COMBAT, CLIMAX }

## Fighters closer than this are fighting.
const COMBAT_ENTER_DISTANCE := 15.0
## They count as apart again only beyond this.
const COMBAT_EXIT_DISTANCE := 22.0
## A hit keeps the fight "on" for this long.
const RECENT_HIT_TICKS := 3 * CombatSim.TICKS_PER_SECOND
## Calm needs this long without hits as well as distance.
const CALM_AFTER_TICKS := 6 * CombatSim.TICKS_PER_SECOND
## Any fighter below this health ratio raises the climax...
const LOW_HEALTH_ENTER := 0.25
## ...until every fighter is back above this one (grey health regenerates).
const LOW_HEALTH_EXIT := 0.32
## A combo this long triggers the climax.
const LONG_COMBO_HITS := 6
## How long a long combo keeps the climax.
const COMBO_CLIMAX_TICKS := 8 * CombatSim.TICKS_PER_SECOND
## A level holds at least this long before it may drop.
const MIN_HOLD_TICKS := 4 * CombatSim.TICKS_PER_SECOND

var level: Level = Level.CALM
var _ticks_in_level: int = 0
var _ticks_since_hit: int = CALM_AFTER_TICKS
var _fighting: bool = false
var _low_health: bool = false
var _combo_ticks: int = 0


## Reads one sim tick: distances, hit events, health and combos.
func observe(sim: CombatSim, final_round: bool = false) -> Level:
	var closest := INF
	var lowest := 1.0
	var longest := 0
	for i in sim.fighters.size():
		var fighter := sim.fighters[i]
		lowest = minf(lowest, float(fighter.health) / maxf(1.0, float(fighter.stats.max_health * FighterState.METER_UNIT)))
		longest = maxi(longest, fighter.combo_hits)
		for j in range(i + 1, sim.fighters.size()):
			closest = minf(closest, fighter.position.distance_to(sim.fighters[j].position))
	var hit := false
	for event in sim.events:
		if event.get("type", -1) in [CombatSim.EventType.HIT, CombatSim.EventType.COUNTER,
				CombatSim.EventType.ARMOR, CombatSim.EventType.THROW, CombatSim.EventType.KO]:
			hit = true
	return step(closest, hit, lowest, longest, final_round)


## One tick of the rules, from plain numbers.
func step(closest_distance: float, hit_landed: bool, lowest_health_ratio: float,
		longest_combo: int, final_round: bool) -> Level:
	_ticks_since_hit = 0 if hit_landed else _ticks_since_hit + 1
	if not _fighting:
		_fighting = closest_distance < COMBAT_ENTER_DISTANCE or _ticks_since_hit < RECENT_HIT_TICKS
	elif closest_distance > COMBAT_EXIT_DISTANCE and _ticks_since_hit >= CALM_AFTER_TICKS:
		_fighting = false
	if lowest_health_ratio < LOW_HEALTH_ENTER:
		_low_health = true
	elif lowest_health_ratio > LOW_HEALTH_EXIT:
		_low_health = false
	if longest_combo >= LONG_COMBO_HITS:
		_combo_ticks = COMBO_CLIMAX_TICKS
	else:
		_combo_ticks = maxi(0, _combo_ticks - 1)

	var wanted := Level.CALM
	if final_round or _low_health or _combo_ticks > 0:
		wanted = Level.CLIMAX
	elif _fighting:
		wanted = Level.COMBAT

	_ticks_in_level += 1
	if wanted > level or (wanted < level and _ticks_in_level >= MIN_HOLD_TICKS):
		level = wanted
		_ticks_in_level = 0
	return level
