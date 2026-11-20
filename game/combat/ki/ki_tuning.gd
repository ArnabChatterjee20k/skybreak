class_name KiTuning
extends Resource
## Shared ki blast, beam and beam clash numbers (GAME_DESIGN §5.8). Per-legend
## moves and shapes live in each legend's KiKit. Meters in display units.

@export_group("Blasts")
## Ki a dash toward a tap blast spends to soak it up (dash armour, tap blasts only).
@export var dash_absorb_ki_cost: int = 2
## A dash soaks a blast only when its direction points this much toward the shot (cosine).
@export var dash_absorb_facing: float = 0.3

@export_group("Beams")
## A beam keeps tracking the target until this many ticks before it fires, then its line is set.
@export var beam_aim_lock_ticks: int = 12
## Guard removed per tick while blocking a beam.
@export var beam_block_guard_per_tick: int = 2
## Chip damage per tick while blocking a beam.
@export var beam_block_chip_per_tick: int = 6
## Blockstun kept up while a blocked beam pushes.
@export var beam_block_stun_ticks: int = 6
## Speed (m/s) a blocked beam pushes the blocker along it.
@export var beam_block_push_speed: float = 7.0
## A blocked beam repeats its BLOCK event (sound, spark) this often (0 counts as every tick).
@export var beam_block_event_every: int = 8
## Extra recovery when a beam ends without touching anyone.
@export var beam_whiff_extra_recovery_ticks: int = 30

@export_group("Clash")
## Ticks from the clash to its first beat.
@export var clash_lead_ticks: int = 36
## Beat prompts per clash (GAME_DESIGN: 4 to 8).
@export var clash_beats: int = 6
## Ticks between beats.
@export var clash_beat_ticks: int = 22
## A press this many ticks from its beat counts.
@export var clash_window_ticks: int = 4
## A press this close to its beat is perfect.
@export var clash_perfect_ticks: int = 1
@export var clash_push_good: int = 10
@export var clash_push_perfect: int = 16
## Wrong button or off-beat press (mashing loses ground).
@export var clash_push_miss: int = -6
## Special press mid-clash: ki spent for push, at most clash_ki_spends times.
@export var clash_ki_cost: int = 10
@export var clash_ki_push: int = 6
@export var clash_ki_spends: int = 3
## Starting push per 100 points of beam damage difference.
@export var clash_push_per_100_damage: int = 1
## Ticks after the last beat's window before the clash resolves.
@export var clash_settle_ticks: int = 12
## Metres the meeting point slides per push point.
@export var clash_metres_per_push: float = 0.08
## Burst the clash winner gains.
@export var clash_win_burst: int = 50
