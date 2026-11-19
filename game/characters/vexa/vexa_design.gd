class_name VexaDesign
extends Resource
## Vexa's shape as numbers: edit these (or vexa_design.tres) and re-run to see
## the change. Metres, T-pose, feet at y = 0, facing +Z.

@export_group("Body")
@export var hips_height := 0.86
@export var chest_size := Vector3(0.46, 0.25, 0.28)
@export var waist_size := Vector3(0.30, 0.20, 0.22)
@export var pelvis_size := Vector3(0.36, 0.22, 0.26)
@export var shoulder_x := 0.21
@export var upper_arm_length := 0.22
@export var lower_arm_length := 0.21
@export var leg_x := 0.11
@export var limb_radius := 0.062

@export_group("Head and hood")
@export var head_size := Vector3(0.34, 0.34, 0.32)
@export var hood_size := Vector3(0.48, 0.5, 0.5)
## Hood face opening: half-width (radians around the front) and its top
## (latitude, radians); the hood is open below hood_bottom.
@export var hood_opening_half_width := 0.75
@export var hood_opening_top := 0.42
@export var hood_bottom := -0.95
@export var hood_roundness := 0.95
@export var ear_length := 0.46
## Ear points: how far they lean out to the side and back (radians).
@export var ear_spread := 0.4
@export var ear_sweep := 1.0
@export var ear_radius := Vector2(0.085, 0.07)

@export_group("Hands and feet")
@export var fist_size := Vector3(0.17, 0.15, 0.16)
@export var boot_size := Vector3(0.17, 0.15, 0.30)

@export_group("Extras")
@export var chakram_radius := 0.17
@export var sash_length := 0.36
