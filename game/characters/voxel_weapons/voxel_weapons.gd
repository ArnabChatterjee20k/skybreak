class_name VoxelWeapons
extends RefCounted
## Voxel versions of the weapons (docs/lookdev/weapons.md): drop-in models with
## the same node shape as WeaponModels.build (a root named after the kind, grip
## at the origin, +Y the long axis, the ranged x1.3 on the root, a "String"
## part on bows), so grips, holds, stowing and the bow string keep working.
## Each kind's mesh is built once per process and shared.

const DESIGNS := {
	Weapon.Kind.STORM_BLADE: "res://game/characters/voxel_weapons/kael_storm_blade.gd",
	Weapon.Kind.ARC_REVOLVER: "res://game/characters/voxel_weapons/kael_arc_revolver.gd",
	Weapon.Kind.KI_GAUNTLETS: "res://game/characters/voxel_weapons/vexa_ki_gauntlet.gd",
	Weapon.Kind.ORBIT_CHAKRAM: "res://game/characters/voxel_weapons/vexa_orbit_chakram.gd",
	Weapon.Kind.KI_BOW: "res://game/characters/voxel_weapons/lyra_ki_bow.gd",
	Weapon.Kind.SKY_LANCE: "res://game/characters/voxel_weapons/lyra_sky_lance.gd",
	Weapon.Kind.TITAN_HAMMER: "res://game/characters/voxel_weapons/brann_titan_hammer.gd",
	Weapon.Kind.SCATTER_CANNON: "res://game/characters/voxel_weapons/brann_scatter_cannon.gd",
	# Shared pickups, in the item gold family.
	Weapon.Kind.EMBER_SCYTHE: "res://game/characters/voxel_weapons/ember_scythe.gd",
	Weapon.Kind.STORM_REPEATER: "res://game/characters/voxel_weapons/storm_repeater.gd",
	Weapon.Kind.HEARTSTRING_BOW: "res://game/characters/voxel_weapons/heartstring_bow.gd",
}

static var _meshes := {}


static func has(kind: Weapon.Kind) -> bool:
	return DESIGNS.has(kind)


static func design_of(kind: Weapon.Kind) -> VoxelWeaponDesign:
	return (load(DESIGNS[kind]) as Script).new() as VoxelWeaponDesign


## The kind's voxel mesh (built on first use, then shared).
static func mesh_of(kind: Weapon.Kind) -> ArrayMesh:
	if not _meshes.has(kind):
		_meshes[kind] = build_mesh(design_of(kind))
	return _meshes[kind]


## A new voxel model of kind, shaped like WeaponModels.build's.
static func build(kind: Weapon.Kind) -> Node3D:
	var d := design_of(kind)
	var root := Node3D.new()
	root.name = String(Weapon.weapon_name(kind)).capitalize().replace(" ", "")
	root.set_meta(&"voxel", true)
	var part := MeshInstance3D.new()
	part.name = "Voxels"
	part.mesh = mesh_of(kind)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(part)
	if Weapon.is_bow(kind):
		root.add_child(_rest_string(d))
	if kind == Weapon.Kind.HEARTSTRING_BOW:
		root.add_child(WeaponModels.sparkles())
	if Weapon.is_ranged(kind) and not Weapon.is_bow(kind):
		root.scale = Vector3.ONE * 1.3
	return root


## Builds a design's grids into one static mesh, one surface per shader material (rigid:
## no bones, it rides its attach bone through a BoneAttachment3D).
static func build_mesh(d: VoxelWeaponDesign) -> ArrayMesh:
	var materials := VoxelBody.materials_for(d)
	var merged := {}
	var soft := d.soft_materials()
	for g in d.build_grids():
		if not soft.is_empty():
			g.smooth(soft)
		var part := VoxelMesher.build(g, d.color, d.surface_of, d.weights, materials, d.blur_cells(g))
		for s in part.get_surface_count():
			var material := part.surface_get_material(s)
			var arrays := part.surface_get_arrays(s)
			if not merged.has(material):
				merged[material] = arrays
				continue
			var into: Array = merged[material]
			var offset := (into[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			for i in indices.size():
				indices[i] += offset
			arrays[Mesh.ARRAY_INDEX] = indices
			for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR,
					Mesh.ARRAY_TEX_UV, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_INDEX]:
				# Packed arrays are values: append to a local, then store it back.
				var joined: Variant = into[k]
				joined.append_array(arrays[k])
				into[k] = joined
	var mesh := ArrayMesh.new()
	var format := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
		| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	for material: Material in materials:
		if not merged.has(material):
			continue
		var arrays: Array = merged[material]
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


## Vertices in a kind's voxel mesh.
static func vertex_count(kind: Weapon.Kind) -> int:
	var m := mesh_of(kind)
	var total := 0
	for s in m.get_surface_count():
		total += m.surface_get_array_len(s)
	return total


## A bow's resting string in the energy colour (BowString hides it while drawn).
static func _rest_string(d: VoxelWeaponDesign) -> MeshInstance3D:
	var string := MeshInstance3D.new()
	string.name = "String"
	var box := BoxMesh.new()
	var w := d.cell() * 0.9
	box.size = Vector3(w, WeaponGrip.BOW_TIP.y * 2.0, w)
	string.mesh = box
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = d.palette()[VoxelWeaponDesign.Mat.GLOW_CORE]
	string.material_override = m
	string.position = WeaponGrip.BOW_STRING_REST
	string.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return string
