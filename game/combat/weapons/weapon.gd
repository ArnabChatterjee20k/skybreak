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
enum Effect { NONE, SMITTEN }

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


static func is_ranged(kind: Kind) -> bool:
	return RANGED_STATS.has(kind)


static func is_melee(kind: Kind) -> bool:
	return kind in MELEE


static func weapon_name(kind: Kind) -> StringName:
	return NAMES.get(kind, &"unarmed")


## Full ammo of a fresh pickup; 0 for melee weapons.
static func full_ammo(kind: Kind) -> int:
	return RANGED_STATS[kind].ammo if is_ranged(kind) else 0


static func ranged_stat(kind: Kind, key: String) -> Variant:
	return RANGED_STATS[kind][key]
