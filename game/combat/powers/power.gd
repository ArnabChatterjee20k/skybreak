class_name Power
extends RefCounted
## Every power and gadget sky drop (GAME_DESIGN §5.11) and its fixed numbers.
## Powers are instant timed buffs; gadgets are one-shot throwables held in a
## single gadget slot and thrown with G. Durations in ticks, distances in metres.

enum Kind {
	NONE,
	OVERDRIVE_ORB, ## Ki regen x3 for 10 s.
	BURST_SHARD, ## +50 burst.
	AEGIS, ## Absorbs the next hit completely.
	HASTE, ## +20% movement and dash speed for 8 s.
	SPIKE_BOMB, ## Gadget: explodes after 1.5 s or on contact; launches.
	GRAVITY_MINE, ## Gadget: placed in the air; pulls nearby fighters in for 2 s.
	MIRROR_DECOY, ## Gadget: a fake that copies your last action for 3 s.
}

const POWERS: Array[Kind] = [Kind.OVERDRIVE_ORB, Kind.BURST_SHARD, Kind.AEGIS, Kind.HASTE]
const GADGETS: Array[Kind] = [Kind.SPIKE_BOMB, Kind.GRAVITY_MINE, Kind.MIRROR_DECOY]

const NAMES := {
	Kind.NONE: &"none",
	Kind.OVERDRIVE_ORB: &"overdrive_orb",
	Kind.BURST_SHARD: &"burst_shard",
	Kind.AEGIS: &"aegis",
	Kind.HASTE: &"haste",
	Kind.SPIKE_BOMB: &"spike_bomb",
	Kind.GRAVITY_MINE: &"gravity_mine",
	Kind.MIRROR_DECOY: &"mirror_decoy",
}

## Aura colour of each power (the view tints the fighter's aura with it).
const AURA := {
	Kind.OVERDRIVE_ORB: Color(0.35, 0.95, 1.0),
	Kind.BURST_SHARD: Color(1.0, 0.35, 0.3),
	Kind.AEGIS: Color(1.0, 0.85, 0.35),
	Kind.HASTE: Color(0.5, 1.0, 0.45),
}

const OVERDRIVE_TICKS := 600
## Overdrive adds this many times the normal regen on top (x3 in total).
const OVERDRIVE_EXTRA_REGEN := 2
const BURST_SHARD_BURST := 50
const HASTE_TICKS := 480
const HASTE_PERCENT := 120

## Spike Bomb: thrown along the aim, fuse, blast radius and hit numbers.
const BOMB_SPEED := 32.0
const BOMB_GRAVITY := 14.0
const BOMB_RADIUS := 0.35
const BOMB_FUSE_TICKS := 90
const BOMB_BLAST_RADIUS := 4.0
## [damage, hitstun, blockstun, hitstop, knockback type, knockback, guard damage]
const BOMB_HIT := [800, 40, 16, 8, MoveData.KnockbackType.LAUNCH, Vector3(0, 22, -6), 25]

## Gravity Mine: placed this far ahead, arms, triggers on a near opponent, pulls.
const MINE_PLACE_DISTANCE := 2.5
const MINE_ARM_TICKS := 20
const MINE_TRIGGER_RADIUS := 6.0
const MINE_PULL_RADIUS := 12.0
const MINE_PULL_SPEED := 9.0
const MINE_PULL_TICKS := 120
## An untriggered mine fizzles after this long.
const MINE_LIFETIME_TICKS := 900

## Mirror Decoy: appears beside the owner, copies its motion and last move, pops on any hit.
const DECOY_TICKS := 180
const DECOY_SIDE_OFFSET := 2.0
const DECOY_RADIUS := 0.45
const DECOY_HEIGHT := 2.0


static func is_gadget(kind: Kind) -> bool:
	return kind in GADGETS


static func is_power(kind: Kind) -> bool:
	return kind in POWERS


static func power_name(kind: Kind) -> StringName:
	return NAMES.get(kind, &"none")


static var _bomb_move: MoveData


## Hit numbers of a Spike Bomb blast.
static func bomb_move() -> MoveData:
	if _bomb_move == null:
		_bomb_move = MoveData.new()
		_bomb_move.id = &"gadget/spike_bomb"
		_bomb_move.damage = BOMB_HIT[0]
		_bomb_move.hitstun_ticks = BOMB_HIT[1]
		_bomb_move.blockstun_ticks = BOMB_HIT[2]
		_bomb_move.hitstop_ticks = BOMB_HIT[3]
		_bomb_move.knockback_type = BOMB_HIT[4]
		_bomb_move.knockback = BOMB_HIT[5]
		_bomb_move.guard_damage = BOMB_HIT[6]
		_bomb_move.cancel_level = MoveData.CancelLevel.SPECIAL
	return _bomb_move
