class_name Weapon
extends RefCounted
## Every pickup weapon (GAME_DESIGN §5.11) and its fixed numbers. Melee weapons
## swap in their own MoveSet (WeaponMoves); ranged ones fire sim projectiles.

enum Kind {
	NONE, ## Unarmed.
	KI_GAUNTLETS,
	STORM_BLADE,
	SKY_LANCE,
	TITAN_HAMMER,
	ORBIT_CHAKRAM,
	EMBER_SCYTHE,
	KI_BOW,
	ARC_REVOLVER,
	STORM_REPEATER,
	SCATTER_CANNON,
	HEARTSTRING_BOW, ## Heartbloom Gardens only.
}

## What a projectile does on top of its hit.
enum Effect {
	NONE,
	SMITTEN, ## Heartstring arrow: Smitten.
	PIN, ## Level-3 Ki Bow arrow: pierces, and pins the target to a wall it is knocked into.
	TETHER, ## Charged Heartstring arrow: ties shooter and target together.
	DISC, ## Orbit Chakram disc: flies out, then comes back to the thrower.
}

const MELEE: Array[Kind] = [
	Kind.KI_GAUNTLETS, Kind.STORM_BLADE, Kind.SKY_LANCE,
	Kind.TITAN_HAMMER, Kind.ORBIT_CHAKRAM, Kind.EMBER_SCYTHE,
]
const RANGED: Array[Kind] = [
	Kind.KI_BOW, Kind.ARC_REVOLVER, Kind.STORM_REPEATER, Kind.SCATTER_CANNON, Kind.HEARTSTRING_BOW,
]

## Short stable names: move id prefixes, view lookups, logs.
const NAMES := {
	Kind.NONE: &"unarmed",
	Kind.KI_GAUNTLETS: &"gauntlets",
	Kind.STORM_BLADE: &"blade",
	Kind.SKY_LANCE: &"lance",
	Kind.TITAN_HAMMER: &"hammer",
	Kind.ORBIT_CHAKRAM: &"chakram",
	Kind.EMBER_SCYTHE: &"scythe",
	Kind.KI_BOW: &"bow",
	Kind.ARC_REVOLVER: &"revolver",
	Kind.STORM_REPEATER: &"repeater",
	Kind.SCATTER_CANNON: &"scatter",
	Kind.HEARTSTRING_BOW: &"heartstring",
}

## Ranged numbers: ammo, magazine (0 = no reload), reload ticks, pellets per
## shot, spread (radians), speed (m/s), gravity (m/s²), radius (m), lifetime
## (ticks), effect. Projectile hit numbers live in WeaponMoves.
const RANGED_STATS := {
	Kind.KI_BOW: {
		"ammo": 12, "magazine": 0, "reload": 0, "pellets": 1, "spread": 0.0,
		"speed": 70.0, "gravity": 9.0, "radius": 0.25, "lifetime": 120, "effect": Effect.NONE,
	},
	Kind.ARC_REVOLVER: {
		"ammo": 18, "magazine": 6, "reload": 72, "pellets": 1, "spread": 0.01,
		"speed": 120.0, "gravity": 0.0, "radius": 0.2, "lifetime": 40, "effect": Effect.NONE,
	},
	Kind.STORM_REPEATER: {
		"ammo": 120, "magazine": 0, "reload": 0, "pellets": 1, "spread": 0.035,
		"speed": 100.0, "gravity": 0.0, "radius": 0.18, "lifetime": 35, "effect": Effect.NONE,
	},
	Kind.SCATTER_CANNON: {
		"ammo": 8, "magazine": 0, "reload": 0, "pellets": 6, "spread": 0.12,
		"speed": 80.0, "gravity": 0.0, "radius": 0.3, "lifetime": 9, "effect": Effect.NONE,
	},
	Kind.HEARTSTRING_BOW: {
		"ammo": 8, "magazine": 0, "reload": 0, "pellets": 1, "spread": 0.0,
		"speed": 65.0, "gravity": 6.0, "radius": 0.3, "lifetime": 120, "effect": Effect.SMITTEN,
	},
}

## A thrown weapon flies like a heavy, slow projectile.
const THROWN_STATS := {
	"speed": 45.0, "gravity": 6.0, "radius": 0.45, "lifetime": 60,
}


## Bow draw: draw ticks (held at full draw) needed for levels 2 and 3, and the cap.
const DRAW_LEVEL_TICKS: Array[int] = [24, 54]
const DRAW_MAX_TICKS := 150
## Ki Bow arrow speed multiplier per draw level (index = level - 1).
const DRAW_SPEED_SCALE: Array[float] = [1.0, 1.3, 1.6]

## Storm Repeater heat (thirds of a tick of fire): 2 s of fire overheats, 1.5 s cools.
const REPEATER_HEAT_PER_TICK := 3
const REPEATER_HEAT_MAX := 360
const REPEATER_COOL_PER_TICK := 4
## Movement speed while firing the repeater, percent.
const REPEATER_MOVE_PERCENT := 60
## Ki (display units) a dash gains for each repeater bullet it absorbs.
const DASH_ABSORB_KI := 2

## Orbit Chakram disc: speed out, ticks before it turns, speed back, catch distance.
const DISC_SPEED := 36.0
const DISC_OUT_TICKS := 22
const DISC_RETURN_SPEED := 40.0
const DISC_RADIUS := 0.6
const DISC_CATCH_DISTANCE := 1.2
const DISC_LIFETIME := 150

## Ki Bow level-3 pin: window in which a wall catches the target, and how long it sticks.
const PIN_WINDOW_TICKS := 60
const PIN_HOLD_TICKS := 45

## Heartstring Tether: duration, and where and how fast a yank pulls the other fighter.
const TETHER_TICKS := 240
const YANK_DISTANCE := 2.5
const YANK_TICKS := 14

## Ranged hits start combos at this damage percent (§5.11).
const RANGED_COMBO_PERCENT := 80
## Swap-cancel cost in ki (display units).
const SWAP_CANCEL_KI := 10


static func is_ranged(kind: Kind) -> bool:
	return RANGED_STATS.has(kind)


static func is_melee(kind: Kind) -> bool:
	return kind in MELEE


static func weapon_name(kind: Kind) -> StringName:
	return NAMES.get(kind, &"unarmed")


## Full ammo of a fresh pickup; 0 for melee weapons.
static func full_ammo(kind: Kind) -> int:
	return RANGED_STATS[kind].ammo if is_ranged(kind) else 0


static func is_bow(kind: Kind) -> bool:
	return kind == Kind.KI_BOW or kind == Kind.HEARTSTRING_BOW


static func ranged_stat(kind: Kind, key: String) -> Variant:
	return RANGED_STATS[kind][key]
