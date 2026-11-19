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
## The air guard acts only when the pair is closer than this (planar, m): a juggle beside
## the attacker keeps its knockback, one about to stack is driven apart.
@export var air_knockback_separation: float = 1.5
## Off the floor a hit drives the target at least this fast away from the attacker (planar, m/s).
@export var air_knockback_min_out: float = 9.0
## The same for light-string hits, small enough that the next air light still reaches.
@export var air_light_knockback_min_out: float = 3.0
## Off the floor a blowback-like hit never drives the target down and lifts it by at most
## this much per m/s of outward speed (1 = 45 degrees): never straight over the attacker.
@export var air_knockback_rise: float = 1.0

@export_group("Knockout")
## Pulls a knocked-out fighter down; it has no flight.
@export var ko_gravity: float = 30.0
## Slows a knocked-out fighter's planar flight while airborne.
@export var ko_air_drag: float = 4.0
## Share of the landing speed the one floor bounce keeps.
@export var ko_bounce_restitution: float = 0.4
## The bounce's upward speed stays inside these limits, so even a slow landing bounces.
@export var ko_min_bounce_speed: float = 4.0
@export var ko_max_bounce_speed: float = 9.0
## Share of the planar speed kept through the bounce (the slide).
@export var ko_bounce_slide: float = 0.5
## Floor friction on a lying fighter's slide.
@export var ko_slide_deceleration: float = 20.0
## The KO launch keeps at most this planar speed (m/s); it still reads big.
@export var ko_max_launch_speed: float = 14.0
## The KO launch keeps at most this upward speed (m/s): 18 m/s under ko_gravity peaks 5.4 m up.
@export var ko_max_rise_speed: float = 18.0
## A knocked-out fighter travels at most this far (planar, m) from where the KO started.
@export var ko_max_travel: float = 12.0
## A knocked-out fighter rises at most this far above its stand height (m), or its KO height.
@export var ko_max_apex: float = 6.0
## Share of the speed into an arena wall a knocked-out fighter bounces back with.
@export var ko_wall_restitution: float = 0.5

@export_group("Perfect block")
## A hit landing up to this many ticks after a block press is perfect-blocked.
@export var perfect_block_window_ticks: int = 6
## A missed perfect block bars the next attempt for this long.
@export var perfect_block_lockout_ticks: int = 20
## Recovery added to the attacker's move by a perfect block.
@export var perfect_block_extra_recovery_ticks: int = 16
## Hitstop of a perfect block.
@export var perfect_block_hitstop_ticks: int = 10

@export_group("Grab")
## How long the target is held before the throw.
@export var grab_hold_ticks: int = 30
## Distance in front of the grabber where the target is held.
@export var grab_hold_distance: float = 1.2
## A GRAB press within this many ticks of being grabbed techs it.
@export var grab_tech_ticks: int = 10
## A tech or grab clash pushes both fighters this far apart.
@export var grab_tech_distance: float = 3.0
## Ticks the tech or clash push lasts; both are unable to act meanwhile.
@export var grab_tech_push_ticks: int = 10

@export_group("Push-block")
## Guard spent on a push-block, in display units.
@export var push_block_guard_cost: int = 10
## A push-block shoves its target out to this distance.
@export var push_block_distance: float = 8.0
## Ticks the push lasts; the target is unable to act meanwhile.
@export var push_block_stun_ticks: int = 16
## Push-block can start from blockstun from this blockstun tick on.
@export var push_block_from_blockstun_tick: int = 4

@export_group("Pushback")
## A landed strike slides its target this far away from the attacker (m).
@export var hit_pushback_distance: float = 0.25
## A blocked strike slides the blocker this far away from the attacker (m).
@export var block_pushback_distance: float = 0.6
## Ticks the pushback slide lasts; whatever a wall stops goes to the attacker.
@export var pushback_ticks: int = 8
