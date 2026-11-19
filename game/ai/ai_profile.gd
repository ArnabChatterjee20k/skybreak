class_name AIProfile
extends RefCounted
## How well one AI plays: reaction time, defence, punishes, combos, habits.
## Levels 1 (Easy) to 5 (punishing); each AI jitters its numbers a little
## (personality) from its own seeded rng so two AIs never feel identical.

const MIN_LEVEL := 1
const MAX_LEVEL := 5

## Per level 1..5. Ticks between seeing something and acting on it.
const REACTION_TICKS: Array[int] = [28, 20, 15, 12, 9]
## Ticks between neutral re-plans (lower re-plans more often).
const PLAN_TICKS: Array[int] = [42, 28, 18, 12, 8]
## Chance to guard a seen attack that will reach.
const BLOCK_CHANCE: Array[float] = [0.12, 0.35, 0.6, 0.78, 0.92]
## Chance to time a fresh block press as a perfect block when it can.
const PERFECT_BLOCK_CHANCE: Array[float] = [0.0, 0.05, 0.15, 0.25, 0.4]
## Chance to punish a seen whiff or a perfect-blocked move.
const PUNISH_CHANCE: Array[float] = [0.08, 0.3, 0.55, 0.78, 0.97]
## Chance to drop each combo link.
const DROP_CHANCE: Array[float] = [0.45, 0.32, 0.18, 0.09, 0.04]
## Longest combo route the level knows (see FighterAI.Route).
const ROUTE_SKILL: Array[int] = [0, 1, 2, 3, 4]
## Chance to tech a grab in time.
const TECH_CHANCE: Array[float] = [0.03, 0.15, 0.35, 0.6, 0.85]
## Chance to grab (instead of strike) a seen guard up close.
const GRAB_GUARD_CHANCE: Array[float] = [0.0, 0.2, 0.45, 0.7, 0.9]
## Weight of mix-ups (grab, delay, bait) when opening up a close opponent.
const MIXUP: Array[float] = [0.0, 0.1, 0.3, 0.5, 0.7]
## Weight of attacking options in neutral.
const AGGRESSION: Array[float] = [0.35, 0.45, 0.55, 0.62, 0.7]
## Chance per plan to stand around (Easy is slow and readable).
const IDLE_CHANCE: Array[float] = [0.5, 0.25, 0.1, 0.03, 0.0]
## Chance to hold the guard up close when nothing is seen yet (anticipation).
const GUARD_HABIT: Array[float] = [0.0, 0.06, 0.15, 0.25, 0.3]
## Interest in weapons on the field.
const WEAPON_INTEREST: Array[float] = [0.25, 0.45, 0.65, 0.8, 0.9]
## Chance per tick to start an attack once in range (Easy waits, so it reads clearly).
const ATTACK_RATE: Array[float] = [0.04, 0.1, 0.2, 0.35, 0.5]
## Whether the AI waits to see a hit before committing to the rest of a string.
const HIT_CONFIRM: Array[bool] = [false, false, true, true, true]
## Chance to escape pressure (push-block, vanish out) when it can.
const ESCAPE_CHANCE: Array[float] = [0.0, 0.15, 0.35, 0.55, 0.75]

var level: int = 3
var reaction_ticks: int
var plan_ticks: int
var block_chance: float
var perfect_block_chance: float
var punish_chance: float
var drop_chance: float
var route_skill: int
var tech_chance: float
var grab_guard_chance: float
var mixup: float
var aggression: float
var idle_chance: float
var guard_habit: float
var weapon_interest: float
var hit_confirm: bool
var attack_rate: float
var escape_chance: float
## Personality: preferred spacing distance (m) and how much it likes ranged weapons.
var spacing: float
var zoning: float


## Profile for level (clamped to 1..5), jittered by up to about 10% from rng.
static func for_level(level_value: int, rng: RandomNumberGenerator) -> AIProfile:
	var profile := AIProfile.new()
	var i := clampi(level_value, MIN_LEVEL, MAX_LEVEL) - 1
	profile.level = i + 1
	profile.reaction_ticks = maxi(REACTION_TICKS[i] + rng.randi_range(-1, 1), 1)
	profile.plan_ticks = maxi(PLAN_TICKS[i] + rng.randi_range(-2, 2), 4)
	profile.block_chance = _jitter(BLOCK_CHANCE[i], rng)
	profile.perfect_block_chance = _jitter(PERFECT_BLOCK_CHANCE[i], rng)
	profile.punish_chance = _jitter(PUNISH_CHANCE[i], rng)
	profile.drop_chance = _jitter(DROP_CHANCE[i], rng)
	profile.route_skill = ROUTE_SKILL[i]
	profile.tech_chance = _jitter(TECH_CHANCE[i], rng)
	profile.grab_guard_chance = _jitter(GRAB_GUARD_CHANCE[i], rng)
	profile.mixup = _jitter(MIXUP[i], rng)
	profile.aggression = _jitter(AGGRESSION[i], rng)
	profile.idle_chance = _jitter(IDLE_CHANCE[i], rng)
	profile.guard_habit = _jitter(GUARD_HABIT[i], rng)
	profile.weapon_interest = _jitter(WEAPON_INTEREST[i], rng)
	profile.hit_confirm = HIT_CONFIRM[i]
	profile.attack_rate = _jitter(ATTACK_RATE[i], rng)
	profile.escape_chance = _jitter(ESCAPE_CHANCE[i], rng)
	profile.spacing = rng.randf_range(3.6, 5.0)
	profile.zoning = rng.randf_range(0.7, 1.3)
	return profile


static func _jitter(value: float, rng: RandomNumberGenerator) -> float:
	return clampf(value * rng.randf_range(0.9, 1.1), 0.0, 1.0)
