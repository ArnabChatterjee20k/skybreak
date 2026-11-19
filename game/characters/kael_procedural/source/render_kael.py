"""Quick Cycles preview renders (turnaround and posed frames) for iterating on the design.

The look is only approximate; the real toon look is rendered in Godot (see README.md).
"""

import math
import os

import bpy
from mathutils import Vector


def _setup(scene, size=(480, 640)):
	scene.render.engine = "CYCLES"
	scene.cycles.samples = 12
	scene.cycles.use_denoising = False
	scene.render.resolution_x, scene.render.resolution_y = size
	scene.render.film_transparent = False
	world = bpy.data.worlds.new("w")
	world.use_nodes = True
	world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.6, 0.68, 1)
	world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
	scene.world = world
	sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
	sun.data.energy = 3.0
	sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
	scene.collection.objects.link(sun)
	# Freestyle ink lines approximate the outline pass.
	scene.render.use_freestyle = True
	scene.render.line_thickness = 1.2
	settings = scene.view_layers[0].freestyle_settings
	lineset = settings.linesets[0] if len(settings.linesets) else settings.linesets.new("ink")
	lineset.linestyle = bpy.data.linestyles.new("ink")
	lineset.linestyle.color = (0.06, 0.04, 0.1)
	cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
	cam.data.type = "ORTHO"
	cam.data.ortho_scale = 2.35
	scene.collection.objects.link(cam)
	scene.camera = cam
	return cam


def _aim(cam, yaw_deg, height=1.02, dist=6.0):
	a = math.radians(yaw_deg)
	# yaw 0 = in front of him (he faces -Y).
	cam.location = Vector((math.sin(a) * dist, -math.cos(a) * dist, height))
	direction = Vector((0, 0, height)) - cam.location
	cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def render_turnaround(arm, body, out_dir, frames=None):
	os.makedirs(out_dir, exist_ok=True)
	scene = bpy.context.scene
	cam = _setup(scene)
	arm.animation_data_clear() if arm.animation_data else None
	for name, yaw in (("front", 0), ("three_quarter", 35), ("side", 90), ("back", 180)):
		_aim(cam, yaw)
		scene.render.filepath = os.path.join(out_dir, "turn_%s.png" % name)
		bpy.ops.render.render(write_still=True)
	# Close-ups of the head for the face and hair.
	cam.data.ortho_scale = 0.75
	for name, yaw in (("face", 0), ("face_three_quarter", 35), ("face_side", 90), ("face_back", 180)):
		_aim(cam, yaw, height=1.78)
		scene.render.filepath = os.path.join(out_dir, "turn_%s.png" % name)
		bpy.ops.render.render(write_still=True)
	cam.data.ortho_scale = 2.35


def render_action_frames(arm, out_dir, action_name, frame_list, yaw=35, size=(360, 480)):
	scene = bpy.context.scene
	cam = scene.camera or _setup(scene, size)
	scene.render.resolution_x, scene.render.resolution_y = size
	_aim(cam, yaw)
	arm.animation_data_create()
	arm.animation_data.action = bpy.data.actions[action_name]
	paths = []
	for f in frame_list:
		scene.frame_set(f)
		path = os.path.join(out_dir, "%s_%03d.png" % (action_name, f))
		scene.render.filepath = path
		bpy.ops.render.render(write_still=True)
		paths.append(path)
	return paths
