class_name BrannDesign
extends Resource
## Brann's shape as numbers: edit these (or brann_design.tres) and re-run to see
## the change. Metres, T-pose, feet at y = 0, facing +Z.

@export_group("Body")
@export var hips_height := 0.84
@export var chest_size := Vector3(0.84, 0.46, 0.56)
@export var belly_size := Vector3(0.7, 0.36, 0.56)
@export var pelvis_size := Vector3(0.6, 0.26, 0.44)
@export var shoulder_x := 0.42
@export var upper_arm_length := 0.25
@export var lower_arm_length := 0.25
@export var leg_x := 0.18
@export var arm_radius := 0.11
@export var forearm_radius := 0.135
@export var thigh_radius := 0.15

@export_group("Head and beard")
@export var head_size := Vector3(0.44, 0.42, 0.42)
@export var brow_size := Vector3(0.46, 0.1, 0.12)
@export var beard_size := Vector3(0.42, 0.24, 0.2)
@export var braid_length := 0.34
@export var braid_radius := 0.055

@export_group("Rock and apron")
## Mossy boulders on the shoulders: his silhouette feature.
@export var boulder_size := Vector3(0.38, 0.3, 0.42)
@export var apron_width := 0.44
@export var apron_length := 0.42

@export_group("Hands and feet")
@export var fist_size := Vector3(0.3, 0.28, 0.3)
@export var boot_size := Vector3(0.26, 0.18, 0.38)
