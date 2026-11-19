class_name FigureRig
extends RefCounted
## Builds a toy-figure rig: a Skeleton3D on SkeletonProfileHumanoid names and
## rests (so the shared retargeted clips drive it), plus rigid parts that each
## follow exactly one bone. No blended skin weights: joints never deform.

## MERGED: one surface per material, every vertex bound 100% to its part's bone
## (rigid, few draw calls). ATTACHED: one MeshInstance3D per bone under a
## BoneAttachment3D (the literal action figure; more draw calls).
enum Assembly { MERGED, ATTACHED }

const SKELETON_NAME := &"GeneralSkeleton"


## One rigid piece: a shape in the rest (T-pose) model space, the bone it
## follows and its material key.
class Part:
	var bone: StringName
	var material: StringName
	var shape: FigureShape

	func _init(bone_name: StringName, material_key: StringName, part_shape: FigureShape) -> void:
		bone = bone_name
		material = material_key
		shape = part_shape


## joints: profile bone -> rest position in model space (T-pose, facing +Z).
## Profile bones without a joint are placed from the profile's reference pose
## times profile_scale. extra_bones: [{name, parent, position}] for secondary
## motion; their rest basis is aligned with the model.
static func build_skeleton(joints: Dictionary, profile_scale: float, extra_bones: Array = []) -> Skeleton3D:
	var profile := SkeletonProfileHumanoid.new()
	var skeleton := Skeleton3D.new()
	skeleton.name = SKELETON_NAME
	var globals: Array[Transform3D] = []
	for i in profile.bone_size:
		var bone := profile.get_bone_name(i)
		var parent_name := profile.get_bone_parent(i)
		var parent := skeleton.find_bone(parent_name) if parent_name != &"" else -1
		var reference := profile.get_reference_pose(i)
		var parent_global := globals[parent] if parent >= 0 else Transform3D.IDENTITY
		var position: Vector3 = joints.get(bone, parent_global * (reference.origin * profile_scale))
		var global := Transform3D(parent_global.basis * reference.basis, position)
		skeleton.add_bone(bone)
		skeleton.set_bone_parent(i, parent)
		skeleton.set_bone_rest(i, parent_global.affine_inverse() * global)
		globals.append(global)
	for extra: Dictionary in extra_bones:
		var parent := skeleton.find_bone(extra.parent)
		var index := skeleton.add_bone(extra.name)
		skeleton.set_bone_parent(index, parent)
		skeleton.set_bone_rest(index, globals[parent].affine_inverse() * Transform3D(Basis(), extra.position))
		globals.append(Transform3D(Basis(), extra.position))
	skeleton.motion_scale = joints.get(&"Hips", Vector3(0, 1, 0)).y
	skeleton.reset_bone_poses()
	return skeleton


## Puts the parts on the skeleton. Returns the mesh instances made.
static func assemble(skeleton: Skeleton3D, parts: Array[Part], materials: Dictionary,
		assembly := Assembly.MERGED) -> Array[MeshInstance3D]:
	if assembly == Assembly.MERGED:
		return [_merged(skeleton, parts, materials)]
	return _attached(skeleton, parts, materials)


## Triangles and draw calls (every pass of every surface) of mesh instances.
static func render_cost(meshes: Array[MeshInstance3D]) -> Vector2i:
	var triangles := 0
	var draws := 0
	for instance in meshes:
		for s in instance.mesh.get_surface_count():
			triangles += instance.mesh.surface_get_array_index_len(s) / 3
			var material := instance.mesh.surface_get_material(s)
			while material:
				draws += 1
				material = material.next_pass
	return Vector2i(triangles, draws)


static func _merged(skeleton: Skeleton3D, parts: Array[Part], materials: Dictionary) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for key: StringName in _material_order(parts):
		var group: Array[Part] = []
		for part in parts:
			if part.material == key:
				group.append(part)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _surface_arrays(skeleton, group, true))
		mesh.surface_set_material(mesh.get_surface_count() - 1, materials[key])
		mesh.surface_set_name(mesh.get_surface_count() - 1, key)
	var skin := Skin.new()
	for bone in skeleton.get_bone_count():
		skin.add_named_bind(skeleton.get_bone_name(bone), skeleton.get_bone_global_rest(bone).affine_inverse())
	var instance := MeshInstance3D.new()
	instance.name = "Figure"
	instance.mesh = mesh
	instance.skin = skin
	skeleton.add_child(instance)
	instance.skeleton = NodePath("..")
	return instance


static func _attached(skeleton: Skeleton3D, parts: Array[Part], materials: Dictionary) -> Array[MeshInstance3D]:
	var instances: Array[MeshInstance3D] = []
	var bones: Array[StringName] = []
	for part in parts:
		if not bones.has(part.bone):
			bones.append(part.bone)
	for bone in bones:
		var mesh := ArrayMesh.new()
		var on_bone: Array[Part] = []
		for part in parts:
			if part.bone == bone:
				on_bone.append(part)
		for key: StringName in _material_order(on_bone):
			var group: Array[Part] = []
			for part in on_bone:
				if part.material == key:
					group.append(part)
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _surface_arrays(skeleton, group, false))
			mesh.surface_set_material(mesh.get_surface_count() - 1, materials[key])
			mesh.surface_set_name(mesh.get_surface_count() - 1, key)
		var attachment := BoneAttachment3D.new()
		attachment.name = String(bone)
		skeleton.add_child(attachment)
		attachment.bone_name = bone
		var instance := MeshInstance3D.new()
		instance.name = "Part"
		instance.mesh = mesh
		instance.transform = skeleton.get_bone_global_rest(skeleton.find_bone(bone)).affine_inverse()
		attachment.add_child(instance)
		instances.append(instance)
	return instances


static func _material_order(parts: Array[Part]) -> Array[StringName]:
	var keys: Array[StringName] = []
	for part in parts:
		if not keys.has(part.material):
			keys.append(part.material)
	return keys


## Godot treats clockwise triangles as front faces; FigureShape is
## counter-clockwise, so each triangle is written reversed.
static func _surface_arrays(skeleton: Skeleton3D, parts: Array[Part], skinned: bool) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	for part in parts:
		var offset := vertices.size()
		var bone := skeleton.find_bone(part.bone)
		assert(bone >= 0, "part bone %s is not in the skeleton" % part.bone)
		vertices.append_array(part.shape.vertices)
		normals.append_array(part.shape.normals)
		for i in part.shape.vertices.size():
			bones.append_array([bone, 0, 0, 0])
			weights.append_array([1.0, 0.0, 0.0, 0.0])
		for t in range(0, part.shape.indices.size(), 3):
			indices.append_array([part.shape.indices[t] + offset, part.shape.indices[t + 2] + offset,
				part.shape.indices[t + 1] + offset])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	if skinned:
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
	return arrays
