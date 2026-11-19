class_name HitTuning
extends Resource
## Constants for what a hit does that are the same for every move: combo
## scaling, hitstun decay, hitstop rules and knockback flight. Per-move numbers
## live in MoveData. Durations in ticks, speeds in m/s, accelerations in m/s².

@export_group("Combo scaling")
## Hit n of a combo deals 100% minus this many percent per earlier hit.
@export var scaling_step_percent: int = 8
## Lowest damage share of a combo hit, in percent.
@export var scaling_floor_percent: int = 30
## Lowest damage share of an ultimate (cancel level ULTIMATE), in percent.
@export var ultimate_scaling_floor_percent: int = 50

@export_group("Stun")
## Hits up to this one in a combo keep their full hitstun.
@export var hitstun_decay_after_hit: int = 8
## Hitstun lost per hit past hitstun_decay_after_hit, cumulative.
@export var hitstun_decay_per_hit: int = 2
## Decay never takes hitstun below this.
@export var min_hitstun_ticks: int = 4
## Time on the floor after a spike bounce.
@export var knockdown_ticks: int = 40

@export_group("Hitstop")
## Extra hitstop for a counter-hit (a hit during the target's startup).
@export var counter_hit_extra_hitstop_ticks: int = 4
## Hitstop of a blocked hit, in percent of the move's hitstop.
@export var blocked_hitstop_percent: int = 50
## Hitstop when a block breaks the guard.
@export var guard_break_hitstop_ticks: int = 14
## Hitstop of the round-ending hit.
@export var knockout_hitstop_ticks: int = 20

@export_group("Knockback")
## Slows a thrown fighter (air friction); for LAUNCH, SWEEP and SPIKE only the planar part.
@export var knockback_drag: float = 30.0
## Pulls LAUNCH, SWEEP and bounced SPIKE targets down while in hitstun.
@export var juggle_gravity: float = 30.0
## Upward speed of the one floor bounce after a spike.
@export var spike_bounce_speed: float = 8.0
