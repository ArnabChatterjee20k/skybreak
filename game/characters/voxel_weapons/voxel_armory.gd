class_name VoxelArmory
extends Node
## Look-dev switch: put this node in a voxel character scene and every weapon
## drawn on that character (held through WeaponLayer.attach, stowed by
## BrannView) uses its voxel model (VoxelWeapons) instead of the old mesh.
## It tags the character's skeleton; WeaponModels.build_for reads the tag.
## Runs before the view's _ready (children are ready first).

@export var enabled := true


func _ready() -> void:
	var owner_view := get_parent()
	for found in owner_view.find_children("*", "Skeleton3D", true, false):
		(found as Skeleton3D).set_meta(WeaponModels.VOXEL_META, enabled)
