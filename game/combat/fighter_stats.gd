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
## Hurtbox: a vertical capsule centred on the fighter's position, in metres.
@export var hurtbox_radius: float = 0.5
## Full capsule height, end caps included.
@export var hurtbox_height: float = 2.0
## Pushbox: the solid body other fighters cannot pass through, a vertical capsule
## centred on the position. Slimmer than the hurtbox so strikes still reach at contact.
@export var pushbox_radius: float = 0.5
## Full pushbox height, end caps included.
@export var pushbox_height: float = 1.8
## Weight in pushbox contacts: the lighter fighter gives way more.
@export var mass: float = 1.0
## Which move each attack input performs.
@export var move_set: MoveSet
