class_name SpecialKit
extends Resource
## One legend's specials (keys 1/2/3), unique mechanic and the hooks the
## ultimate and transformation lanes fill in (GAME_DESIGN §5.2, §5.9, §6).

enum Mechanic {
	NONE,
	MOMENTUM, ## Kael: each consecutive landed hit adds damage until he is hit.
	AFTERIMAGE, ## Vexa: a decoy that takes one hit and bursts.
}

@export var legend: StringName = &""
## Specials by key: index 0 is key 1.
@export var specials: Array[SpecialMove] = []
@export var mechanic: Mechanic = Mechanic.NONE

@export_group("Momentum")
@export var momentum_percent_per_hit: int = 2
@export var momentum_max_stacks: int = 10

@export_group("Afterimage")
## Ticks a decoy stays before it fades.
@export var decoy_ticks: int = 150
@export var decoy_radius: float = 0.45
@export var decoy_height: float = 2.0
## The burst when the decoy is struck: damage, stun, knockback; hits everyone in decoy_blast_radius.
@export var decoy_blast: MoveData
@export var decoy_blast_radius: float = 2.4

@export_group("Ultimate and transform")
## Next lane (T-SP2): null leaves key 4 to the ki beam ultimate.
@export var ultimate: SpecialMove
@export var ultimate_burst_stocks: int = 2
## Next lane: transformation (T) costs this many burst stocks; 0 here means not built yet.
@export var transform_burst_stocks: int = 1
@export var transform_ki_drain_per_second: int = 5

@export_group("Look")
@export var color: Color = Color(1.0, 0.65, 0.3)


## The special on key slot (1-3), or null.
func special_for(slot: int) -> SpecialMove:
	if slot < 1 or slot > specials.size():
		return null
	return specials[slot - 1]


## The special a move belongs to, or null.
func special_of(move: MoveData) -> SpecialMove:
	if move == null:
		return null
	for special in specials:
		if special != null and special.owns(move):
			return special
	if ultimate != null and ultimate.owns(move):
		return ultimate
	return null
