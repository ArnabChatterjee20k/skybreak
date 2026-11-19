class_name FighterStats
extends Resource
## Numbers and moves that differ between fighters. Meters in display units.

## Health at the start of each round.
@export var max_health: int = 10_000
## Full guard meter.
@export var guard_max: int = 100
## Ki cost of the first vanish counter in an exchange (used from T-D06).
@export var vanish_counter_ki_cost: int = 25
## Ki cost of the second vanish counter in the same exchange (used from T-D06).
@export var second_vanish_counter_ki_cost: int = 40
## Which move each attack input performs.
@export var move_set: MoveSet
