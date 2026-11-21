extends VoxelZone
## A stand-in voxel zone for hookup tests: one lawn tile, built instantly.


func build() -> void:
	var lawn := MeshInstance3D.new()
	lawn.mesh = PlaneMesh.new()
	add_child(lawn)
