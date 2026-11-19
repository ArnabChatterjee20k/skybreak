class_name LyraDesign
extends Resource
## Lyra's shape as numbers: edit these (or lyra_design.tres) and re-run to see
## the change. Metres, T-pose, feet at y = 0, facing +Z.

@export_group("Body")
@export var hips_height := 0.8
@export var chest_size := Vector3(0.42, 0.26, 0.27)
@export var waist_size := Vector3(0.3, 0.2, 0.22)
@export var shoulder_x := 0.2
@export var upper_arm_length := 0.2
@export var lower_arm_length := 0.2
@export var leg_x := 0.1
@export var limb_radius := 0.058
## Robe skirt: how far below the hips it hangs and its hem radii (side, front).
@export var skirt_length := 0.3
@export var skirt_hem := Vector2(0.27, 0.24)

@export_group("Head and hat")
@export var head_size := Vector3(0.38, 0.37, 0.35)
@export var brim_radius := 0.45
## Brim tilt toward the front (radians); the hat sits slightly forward.
@export var brim_tilt := 0.1
@export var crown_height := 0.4
@export var crown_radius := 0.19
## How far the crown's tip bends back (metres).
@export var crown_bend := 0.24

@export_group("Hands and feet")
@export var glove_size := Vector3(0.16, 0.15, 0.16)
@export var boot_size := Vector3(0.17, 0.15, 0.3)

@export_group("Extras")
@export var cape_length := 0.88
@export var cape_width := 0.3
@export var astrolabe_radius := 0.12
@export var lance_length := 1.2
