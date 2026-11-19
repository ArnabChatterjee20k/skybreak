class_name MovementTuning
extends Resource
## Every movement constant the sim uses. developer tunes these values for feel.
## Distances in metres, speeds in m/s, accelerations in m/s², durations in ticks.

@export_group("Ground")
## Height of a standing fighter's origin above the floor (capsule centre).
@export var ground_height: float = 1.0
## Top running speed on the ground.
@export var ground_speed: float = 12.0
## How fast ground speed builds up while a direction is held.
@export var ground_acceleration: float = 90.0
## How fast a fighter stops on the ground once no direction is held.
@export var ground_deceleration: float = 120.0
## Steepest slope (degrees) a fighter walks up on zone terrain; steeper is a wall.
@export var max_walk_slope: float = 55.0
## Upward speed when jumping off the ground into flight (Space on the ground).
@export var takeoff_speed: float = 14.0

## Slow drift speed while blocking, on the ground and in the air.
@export var guard_drift_speed: float = 2.5

@export_group("Flight")
## Top horizontal speed in free flight.
@export var fly_speed: float = 30.0
## How fast flight speed changes toward the held direction.
@export var fly_acceleration: float = 70.0
## How fast a flying fighter comes to a hover once nothing is held.
@export var fly_deceleration: float = 60.0
## Climbing speed while ascend is held.
@export var ascend_speed: float = 18.0
## Sinking speed while descend is held.
@export var descend_speed: float = 22.0
## Ticks a full-speed climb or dive takes to ease to a hover once ascend/descend is let go.
@export var climb_ease_out_ticks: int = 24

@export_group("Falling")
## Downward acceleration while airborne and not flying.
@export var gravity: float = 30.0
## Fastest a falling fighter can drop.
@export var max_fall_speed: float = 50.0

@export_group("Dash")
## Distance covered by a tapped dash (the short step).
@export var dash_step_distance: float = 8.0
## Length of the short step; still holding dash after it turns into a sustained dash.
@export var dash_step_ticks: int = 10
## Speed of the sustained flight-dash while dash is held.
@export var sustained_dash_speed: float = 55.0
## Speed of the rush dash toward the lock-on target.
@export var rush_speed: float = 80.0
## Minimum alignment (cosine) between dash direction and target for a rush dash.
@export var rush_alignment: float = 0.7
## A rush dash stops this far from the target.
@export var rush_stop_distance: float = 2.5
## Ticks a rush takes to brake from full speed to its stop point (9 = 0.15 s).
@export var rush_brake_ticks: int = 9
## Longest a rush dash can last before it gives up.
@export var rush_max_ticks: int = 90

@export_group("Vanish step")
## Teleport distance of a vanish step.
@export var vanish_step_distance: float = 6.0
## Ticks a fighter stays vanished before it can act again.
@export var vanish_step_ticks: int = 12

@export_group("Lock-on")
## Fastest a locked strafe circles its target, in degrees per second. Only
## bites close in (T-D29): at ground speed under ~3.8 m. Matches the camera turn cap.
@export var max_orbit_turn_speed: float = 180.0

@export_group("Arena")
## Half the arena's width and depth, centred on the origin (300 = 600 m x 600 m).
@export var arena_half_size: float = 300.0
## Highest a fighter's origin can go.
@export var arena_ceiling: float = 250.0
