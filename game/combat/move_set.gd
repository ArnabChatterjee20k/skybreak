class_name MoveSet
extends Resource
## Which move each attack input performs for one fighter.

## LMB presses in timing, in order.
@export var light_string: Array[MoveData] = []
## Neutral RMB; holding it charges through its charge_level_ticks.
@export var smash: MoveData
## The move a charged smash performs at each charge level (1 first).
@export var charged_smash: Array[MoveData] = []
## RMB toward the target.
@export var breaker: MoveData
## RMB away from the target.
@export var launcher: MoveData
## RMB with ascend held.
@export var rising: MoveData
## RMB with descend held.
@export var spike: MoveData
## RMB sideways.
@export var sweep: MoveData
## RMB while blocking (used from T-D05).
@export var push_block: MoveData
