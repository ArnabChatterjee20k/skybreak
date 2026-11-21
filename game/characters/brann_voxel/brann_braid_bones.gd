class_name BrannBraidBones
extends Node
## Adds the braid's chain bones to Brann's rig before VoxelBody skins the mesh
## (it must sit between the model and VoxelBody in the scene).

@export var skeleton_path: NodePath


func _ready() -> void:
	BrannVoxelDesign.add_braid_bones(get_node(skeleton_path) as Skeleton3D)
