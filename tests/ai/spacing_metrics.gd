class_name SpacingMetrics
extends RefCounted
## Fight-shape numbers over seeded AI matches: time near the ground, vertical
## stacking, altitude, FFA dog-piles. Restarts a fresh round after a KO so
## every match covers the full tick count.

const LEGENDS: Array[StringName] = [&"kael", &"vexa", &"brann", &"lyra"]
## Near-ground: within this height of the floor (m).
const NEAR_GROUND := 3.0
## A pair is stacked when |dy| > planar distance and planar distance < this (m).
const STACK_RADIUS := 1.5
## A dog-pile: this many fighters on one target within DOG_PILE_RADIUS (m).
const DOG_PILE := 3
const DOG_PILE_RADIUS := 6.0

var fighter_ticks: int = 0
var near_ground_ticks: int = 0
var altitude_sum: float = 0.0
var ticks: int = 0
var stacked_ticks: int = 0
var dog_pile_ticks: int = 0


## fighters: 2 or 4; matches seeded bouts of ticks each at levels cycling 2..5.
## weapon_bot: drive with the combat WeaponBot instead (the old zone_match fallback).
static func measure(fighters: int, matches: int, match_ticks: int, weapon_bot := false) -> SpacingMetrics:
	var metrics := SpacingMetrics.new()
	for m in matches:
		var levels: Array = []
		var characters: Array = []
		for slot in fighters:
			levels.append(2 + (m + slot) % 4)
			characters.append(LEGENDS[(m + slot * (1 + m % 3)) % LEGENDS.size()])
		var played := 0
		var round_index := 0
		while played < match_ticks:
			var bout := AIBout.new(4200 + 97 * m + 13 * round_index, levels, true, characters)
			var bots: Array[WeaponBot] = []
			if weapon_bot:
				for slot in fighters:
					bots.append(WeaponBot.new(slot, 7919 * (slot + 1) + levels[slot] + m))
			while played < match_ticks and not bout.sim.round_over:
				if weapon_bot:
					var inputs: Array[FighterInput] = []
					for bot in bots:
						inputs.append(bot.next_input(bout.sim))
					bout.sim.tick(inputs)
				else:
					bout.step()
				metrics.record(bout.sim)
				played += 1
			round_index += 1
	return metrics


func record(sim: CombatSim) -> void:
	ticks += 1
	var stacked := false
	var aimed := {}
	for i in sim.fighters.size():
		var fighter := sim.fighters[i]
		if fighter.is_knocked_out():
			continue
		var altitude := fighter.position.y - sim._stand_height(fighter)
		fighter_ticks += 1
		altitude_sum += altitude
		if altitude < NEAR_GROUND:
			near_ground_ticks += 1
		var target := fighter.lock_on_target
		if target >= 0 and fighter.position.distance_to(sim.fighters[target].position) < DOG_PILE_RADIUS:
			aimed[target] = aimed.get(target, 0) + 1
		for j in range(i + 1, sim.fighters.size()):
			var other := sim.fighters[j]
			if other.is_knocked_out():
				continue
			var offset := other.position - fighter.position
			var planar := Vector2(offset.x, offset.z).length()
			if absf(offset.y) > planar and planar < STACK_RADIUS:
				stacked = true
	if stacked:
		stacked_ticks += 1
	for count: int in aimed.values():
		if count >= DOG_PILE:
			dog_pile_ticks += 1
			break


func near_ground_percent() -> float:
	return 100.0 * near_ground_ticks / maxf(fighter_ticks, 1)


func stacked_percent() -> float:
	return 100.0 * stacked_ticks / maxf(ticks, 1)


func dog_pile_percent() -> float:
	return 100.0 * dog_pile_ticks / maxf(ticks, 1)


func mean_altitude() -> float:
	return altitude_sum / maxf(fighter_ticks, 1)


func summary() -> String:
	return "near-ground %.1f%%  stacked %.2f%%  mean altitude %.2f m  dog-pile %.2f%%" % [
		near_ground_percent(), stacked_percent(), mean_altitude(), dog_pile_percent()]
