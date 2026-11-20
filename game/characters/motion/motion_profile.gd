class_name MotionProfile
extends Resource
## A legend's motion personality, applied to MotionLayers and CharacterView: how stiff the springs
## are, how much the body leans, how long the stride is and how fast reactions play. One profile
## per character; the code paths are the same for everyone.

## Lean into acceleration and velocity (x the layer defaults), and how fast the lean follows.
@export var lean_scale := 1.0
@export var lean_frequency := 9.0
## Secondary motion (head and arms lagging the chest): spring frequency and amount.
@export var secondary_frequency := 14.0
@export var secondary_scale := 1.0
## Inertialized clip switches: decay rate (1/s); lower is a slower, heavier blend.
@export var blend_frequency := 18.0
@export var flinch_frequency := 16.0
@export var flinch_scale := 1.0
## Landings and heavy impacts: how deep the knees give.
@export var landing_scale := 1.0
## Hips lowered in every grounded pose (m); the foot IK bends the knees to keep the feet planted.
@export var crouch := 0.0
## Stride length: locomotion clips play at speed / stride_scale (longer stride, slower cadence).
@export var stride_scale := 1.0
## Playback rate of idles and reactions (1 = the take's own timing).
@export var timing_scale := 1.0
## Hover bob while flying slowly: amplitude (m) and rate (Hz).
@export var hover_bob := 0.02
@export var hover_bob_hz := 0.5
## Flight arm read (x the layer's tuck and reach) and dive pitch limit (degrees).
@export var flight_arm_scale := 1.0
@export var dive_pitch := 95.0
## Hips dip (m) when a strike lands on the active tick; 0 for none (Brann's ground-pound weight).
@export var impact_weight := 0.0
## Held-weapon grip points pushed forward and out from the shoulder (arm lengths), for builds
## whose chest or short arms would bring a hold into the body (chibi Lyra, bulky Brann).
@export var hold_forward := 0.0
@export var hold_out := 0.0
## Two-handed heavy guard: the weapon's +Y in chest space (as ARM_POSES); zero keeps the shared
## diagonal. Brann's wide pauldrons need the head forward of his shoulder, not over it (#98).
@export var heavy_guard_up := Vector3.ZERO
## Heavy weapons rest at the side between attacks instead of across the chest.
@export var heavy_at_side := false
## Dodge feel (T-DEF2), procedural on top of the clips: lean into a directional dodge, bank into
## a sidestep, twist through a spot dodge (degrees), and how far the hips drop (m).
@export var dodge_lean_degrees := 22.0
@export var dodge_roll_degrees := 26.0
@export var dodge_twist_degrees := 40.0
@export var dodge_drop := 0.16
