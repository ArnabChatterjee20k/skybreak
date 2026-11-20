class_name DodgeTuning
extends Resource
## Every dodge constant (T-DEF2, proposal docs/proposals/defense-dodge.md M1/M2/S5).
## Frames are 1-based sim ticks of the dodge: frame 1 is the press tick.

@export_group("Directional")
## Vulnerable frames before the i-frames start.
@export var directional_startup_ticks: int = 2
## Invulnerable frames (strikes, grabs, projectiles).
@export var directional_invuln_ticks: int = 12
## Vulnerable, throw-vulnerable frames after the i-frames.
@export var directional_recovery_ticks: int = 12
## Travel in metres over startup + i-frames, eased out.
@export var directional_distance: float = 4.5

@export_group("Spot")
@export var spot_startup_ticks: int = 1
@export var spot_invuln_ticks: int = 16
@export var spot_recovery_ticks: int = 14

@export_group("Sidestep")
## Arc around the locked target, in degrees, over startup + i-frames (same timing as directional).
@export var sidestep_arc_degrees: float = 70.0
## Closer than this (planar metres) the arc widens to the same arc length, up to sidestep_max_arc_degrees.
## The distance to the target does not change: a sidestep goes round, not away.
@export var sidestep_min_radius: float = 3.0
@export var sidestep_max_arc_degrees: float = 90.0

@export_group("Hold")
## A Shift still held on this frame turns the dodge into the sustained flight-dash;
## the i-frames end there and the dash cannot be let go before the dodge's last frame.
@export var hold_to_dash_tick: int = 10

@export_group("Anti-mash")
## A dodge within this many ticks of the last one ending is a chain.
@export var chain_window_ticks: int = 45
## A chained dodge: recovery longer, i-frames shorter.
@export var chain_extra_recovery_ticks: int = 8
@export var chain_invuln_loss_ticks: int = 4
## The third dodge of a chain has no i-frames, and so does every dodge until this many quiet ticks pass.
@export var stale_cooldown_ticks: int = 90
## Dodges per airborne spell; landing, being hit or this many ticks without a dodge refresh them.
@export var air_dodges: int = 2
@export var air_refresh_ticks: int = 120

@export_group("Perfect dodge")
## A live hitbox or projectile meeting the first this-many i-frames is a perfect dodge.
@export var perfect_window_ticks: int = 6
@export var perfect_recovery_cut_ticks: int = 6
## Ki for a perfect dodge (display units), at most once per perfect_ki_cooldown_ticks.
@export var perfect_ki: int = 10
@export var perfect_ki_cooldown_ticks: int = 180
## Hitstop on the attacker only.
@export var perfect_attacker_freeze_ticks: int = 6

@export_group("Punish")
## Moves whose hitboxes catch a sidestep through its i-frames (Tekken tracking).
@export var tracking_move_ids: Array[StringName] = [&"sweep"]
## How fast a tracking move turns after a sidestepper, in degrees per tick.
@export var tracking_turn_degrees_per_tick: float = 12.0
## A grab landing in dodge recovery is a counter-hit: extra hitstop on the throw, no tech.
@export var recovery_grab_extra_hitstop_ticks: int = 4
