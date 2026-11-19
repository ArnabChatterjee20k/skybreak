"""Builds chunky Kael (mesh, rig, weights, override clips) and exports two GLBs.

- kael_chunky.glb: the skinned model (no animations).
- animations/kael_chunky_moves.glb: the armature with Kael's own clips, retargeted on import and
  merged with the shared humanoid clips by tools/build_kael_chunky_clips.gd.

Run with Python 3.11 and the bpy module (see README.md):
	python game/characters/kael_chunky/source/build_kael.py [--no-anim] [--no-export]
"""

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402

import face_texture  # noqa: E402
import kael_mesh  # noqa: E402
import kael_params as P  # noqa: E402
import kael_rig  # noqa: E402

OUT_DIR = os.path.normpath(os.path.join(HERE, ".."))
GLB_PATH = os.path.join(OUT_DIR, "kael_chunky.glb")
MOVES_GLB_PATH = os.path.join(OUT_DIR, "animations", "kael_chunky_moves.glb")
FACE_PATH = os.path.join(OUT_DIR, "textures", "kael_chunky_face.png")
MATERIALS_DIR = os.path.join(OUT_DIR, "materials")
RES_DIR = "res://game/characters/kael_chunky"


def reset_scene():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.context.scene.render.fps = 60


def make_materials():
	mats = {}
	for name, rgb in P.COLORS.items():
		m = bpy.data.materials.new(name)
		m.use_nodes = True
		bsdf = m.node_tree.nodes.get("Principled BSDF")
		bsdf.inputs["Base Color"].default_value = (*_linear(rgb), 1.0)
		bsdf.inputs["Roughness"].default_value = 1.0
		mats[name] = m
	return mats


def _linear(rgb):
	return tuple(((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92 for c in rgb)


def write_godot_materials():
	"""One toon ShaderMaterial per slot, sharing one outline pass."""
	os.makedirs(MATERIALS_DIR, exist_ok=True)
	with open(os.path.join(MATERIALS_DIR, "kael_chunky_outline.tres"), "w") as f:
		f.write('[gd_resource type="ShaderMaterial" load_steps=2 format=3]\n\n'
			'[ext_resource type="Shader" path="res://game/view/shaders/outline.gdshader" id="1_outline"]\n\n'
			'[resource]\nresource_name = "kael_chunky_outline"\nshader = ExtResource("1_outline")\n'
			'shader_parameter/outline_width = 2.6\n')
	for name, rgb in P.COLORS.items():
		face = name == "face"
		lines = ['[gd_resource type="ShaderMaterial" load_steps=%d format=3]' % (4 if face else 3), "",
			'[ext_resource type="Shader" path="res://game/view/shaders/toon.gdshader" id="1_toon"]',
			'[ext_resource type="Material" path="%s/materials/kael_chunky_outline.tres" id="2_outline"]' % RES_DIR]
		if face:
			lines.append('[ext_resource type="Texture2D" path="%s/textures/kael_chunky_face.png" id="3_face"]' % RES_DIR)
		lines += ["", "[resource]", 'resource_name = "kael_chunky_%s"' % name, 'next_pass = ExtResource("2_outline")',
			'shader = ExtResource("1_toon")']
		if face:
			lines += ["shader_parameter/albedo_color = Color(1, 1, 1, 1)",
				'shader_parameter/albedo_texture = ExtResource("3_face")']
		else:
			lines.append("shader_parameter/albedo_color = Color(%.3f, %.3f, %.3f, 1)" % rgb)
		lines.append("shader_parameter/specular_enabled = %s" % ("true" if name in P.SPECULAR_SLOTS else "false"))
		if name in P.SHADOW_TINTS:
			lines.append("shader_parameter/shadow_tint = Color(%.2f, %.2f, %.2f, 1)" % P.SHADOW_TINTS[name])
		with open(os.path.join(MATERIALS_DIR, "kael_chunky_%s.tres" % name), "w") as f:
			f.write("\n".join(lines) + "\n")


def make_armature():
	arm_data = bpy.data.armatures.new("KaelChunkyRig")
	arm = bpy.data.objects.new("KaelChunky", arm_data)
	bpy.context.scene.collection.objects.link(arm)
	bpy.context.view_layer.objects.active = arm
	bpy.ops.object.mode_set(mode="EDIT")
	layout = kael_rig.bone_layout()
	for name, parent, head, tail in layout:
		eb = arm_data.edit_bones.new(name)
		eb.head = head
		eb.tail = tail
		eb.roll = 0.0
		if parent:
			eb.parent = arm_data.edit_bones[parent]
	bpy.ops.object.mode_set(mode="OBJECT")
	for b in arm_data.bones:
		b.use_deform = b.name != "Root"
	return arm, layout


def part_to_object(part, mats, layout):
	"""Turns a Part into a Blender mesh object with its materials and vertex group weights."""
	from mathutils import Vector
	used = sorted({i for f in part.faces for i in f})
	remap = {old: new for new, old in enumerate(used)}
	verts = [tuple(part.verts[i]) for i in used]
	faces = [[remap[i] for i in f] for f in part.faces]
	mesh = bpy.data.meshes.new(part.name)
	mesh.from_pydata(verts, [], faces)
	mesh.validate()
	obj = bpy.data.objects.new(part.name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	slots = [part.material] + sorted(set(part.face_materials.values()) - {part.material})
	for s in slots:
		mesh.materials.append(mats[s])
	indices = [slots.index(part.face_materials.get(i, part.material)) for i in range(len(faces))]
	mesh.polygons.foreach_set("material_index", indices)
	if not part.keep_winding:
		_fix_normals(mesh)
	for poly in mesh.polygons:
		poly.use_smooth = True
	uv = mesh.uv_layers.new(name="UVMap")
	for loop in mesh.loops:
		uv.data[loop.index].uv = kael_mesh.face_uv(Vector(verts[loop.vertex_index]))
	if part.fixed_weights is not None:
		weights = [part.fixed_weights[i] or {"Head": 1.0} for i in used]
	elif part.weight_fn is not None:
		weights = [part.weight_fn(Vector(v), lambda p, allowed: kael_rig.skin_weights(p, layout, allowed))
			for v in verts]
	else:
		weights = [kael_rig.skin_weights(Vector(v), layout, part.bones) for v in verts]
	groups = {}
	for vi, wmap in enumerate(weights):
		for bone, w in sorted(wmap.items()):
			if bone not in groups:
				groups[bone] = obj.vertex_groups.new(name=bone)
			groups[bone].add([vi], w, "REPLACE")
	return obj


def _fix_normals(mesh):
	import bmesh
	bm = bmesh.new()
	bm.from_mesh(mesh)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(mesh)
	bm.free()


def build_character():
	os.makedirs(os.path.dirname(FACE_PATH), exist_ok=True)
	face_texture.draw_face(P.COLORS["face"], FACE_PATH)
	write_godot_materials()
	mats = make_materials()
	arm, layout = make_armature()
	objs = [part_to_object(p, mats, layout) for p in kael_mesh.build_all()]
	body = _join(objs, "KaelChunkyMesh")
	_dedupe_slots(body)
	body.parent = arm
	mod = body.modifiers.new("Armature", "ARMATURE")
	mod.object = arm
	return arm, body


def _join(objs, name):
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]
	bpy.ops.object.join()
	body = bpy.context.view_layer.objects.active
	body.name = name
	body.data.name = name
	return body


def _dedupe_slots(obj):
	"""Merges material slots that share a material after the join, in COLORS order."""
	mesh = obj.data
	names = [m.name for m in mesh.materials]
	order = [n for n in P.COLORS if n in names]
	indices = [order.index(names[p.material_index]) for p in mesh.polygons]
	mesh.materials.clear()
	for name in order:
		mesh.materials.append(bpy.data.materials[name])
	mesh.polygons.foreach_set("material_index", indices)
	mesh.update()


def make_proxy(arm):
	"""A tiny hidden triangle skinned to the hips, so the moves GLB imports with a Skeleton3D."""
	mesh = bpy.data.meshes.new("Proxy")
	mesh.from_pydata([(0, 0, 0.8), (0.01, 0, 0.8), (0, 0, 0.81)], [], [[0, 1, 2]])
	obj = bpy.data.objects.new("Proxy", mesh)
	bpy.context.scene.collection.objects.link(obj)
	obj.vertex_groups.new(name="Hips").add([0, 1, 2], 1.0, "REPLACE")
	obj.parent = arm
	obj.modifiers.new("Armature", "ARMATURE").object = arm
	return obj


def triangle_count(obj):
	return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def export(objs, path, animations):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.select_set(True)
	bpy.ops.export_scene.gltf(
		filepath=path,
		export_format="GLB",
		use_selection=True,
		export_animations=animations,
		export_animation_mode="ACTIONS",
		export_force_sampling=True,
		export_frame_step=1,
		export_optimize_animation_size=True,
		export_def_bones=False,
		export_skins=True,
		export_morph=False,
		export_yup=True,
		export_texcoords=True,
		export_normals=True,
		export_materials="EXPORT" if not animations else "NONE",
		export_image_format="NONE",
	)
	print("exported", path, os.path.getsize(path) // 1024, "KB")


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("--no-export", action="store_true")
	parser.add_argument("--no-anim", action="store_true")
	args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
	reset_scene()
	arm, body = build_character()
	print("triangles:", triangle_count(body))
	if not args.no_export:
		export([arm, body], GLB_PATH, animations=False)
	if not args.no_anim:
		import kael_anims
		kael_anims.build_all(arm)
		if not args.no_export:
			proxy = make_proxy(arm)
			body.select_set(False)
			export([arm, proxy], MOVES_GLB_PATH, animations=True)


if __name__ == "__main__":
	main()
