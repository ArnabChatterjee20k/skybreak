extends SceneTree
## Builds every voxel weapon headless and prints its vertex count, surfaces,
## cell size and build time (no GPU needed).
##   godot --headless --path . -s res://game/characters/voxel_weapons/preview/voxel_weapon_stats.gd [-- --kinds=a,b]


func _initialize() -> void:
	var names := LookdevArgs.parse().get_option("kinds", "")
	for kind: Weapon.Kind in VoxelWeapons.DESIGNS:
		if names != "" and not String(Weapon.weapon_name(kind)) in names.split(","):
			continue
		var started := Time.get_ticks_msec()
		var d := VoxelWeapons.design_of(kind)
		var count := VoxelWeapons.vertex_count(kind)
		var mesh := VoxelWeapons.mesh_of(kind)
		print("%-10s %7d vertices %6d tris %d surfaces  cell %.2f mm (world %.1f mm)  aabb %s  %d ms" % [
			Weapon.weapon_name(kind), count, count / 2, mesh.get_surface_count(), d.cell() * 1000.0,
			d.cell() * d.model_scale() * 1000.0, mesh.get_aabb(), Time.get_ticks_msec() - started])
	quit()
