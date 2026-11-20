class_name EscapeTuning
extends Resource
## Numbers for the escape tools (T-DEF3): combo breaker, air tech and chase,
## tech roll and wakeups. All durations in sim ticks, distances in metres.

@export_group("Combo breaker")
## Burst stocks one breaker costs.
@export var breaker_burst_stocks: int = 1
## Both fighters freeze this long on the burst (the big moment).
@export var breaker_hitstop_ticks: int = 12
## Intangible ticks after the freeze; starting an attack ends it early.
@export var breaker_intangible_ticks: int = 20
## The burst pose: the breaker cannot act for this long (intangible throughout).
@export var breaker_pose_ticks: int = 12
## Opponents within this radius are blown out to breaker_push_distance.
@export var breaker_radius: float = 6.0
@export var breaker_push_distance: float = 5.5
## Ticks the blown-away attacker slides and cannot act.
@export var breaker_push_ticks: int = 18
## A second breaker needs this long after the first (anti-chain).
@export var breaker_cooldown_ticks: int = 300

@export_group("Air tech and chase")
## Ticks of knockback flight in which Shift + direction techs (inclusive).
@export var air_tech_first_tick: int = 12
@export var air_tech_last_tick: int = 24
## Tech travel and length; the first air_tech_invuln_ticks are intangible.
@export var air_tech_distance: float = 4.0
@export var air_tech_ticks: int = 14
@export var air_tech_invuln_ticks: int = 8
## A teched fighter caught by a correct chase stays in hitstun this much longer.
@export var air_tech_caught_ticks: int = 18
## Frame advantage the defender gets over a chaser who guessed wrong.
@export var chase_miss_advantage_ticks: int = 8
## After a knockback hit, Dash within this many ticks chases (auto-homing rush).
@export var chase_window_ticks: int = 20
## Ki a chase costs (display units).
@export var chase_ki_cost: int = 15
## An over or under chase homes on a point this far above or below the target, so the way reads.
@export var chase_offset_height: float = 1.8

@export_group("Knockdown and wakeup")
## Lying ticks for a delayed (hold descend) wakeup; the neutral one is HitTuning.knockdown_ticks.
@export var delayed_wakeup_ticks: int = 70
## WASD + Space within this many ticks of landing rolls.
@export var tech_roll_window_ticks: int = 10
@export var tech_roll_distance: float = 3.5
@export var tech_roll_ticks: int = 18
## Every wakeup and roll is intangible for this long, then vulnerable.
@export var wakeup_invuln_ticks: int = 6

@export_group("Perfect block view")
## View-only slow on a perfect block (GAME_DESIGN §5.10); the sim never changes speed.
@export var perfect_block_view_scale: float = 0.8
@export var perfect_block_view_ticks: int = 6
