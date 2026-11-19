"""Reads Kael's frame data straight from the sim's MoveData resources, so clips follow the sim."""

import os
import re

from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
MOVES_DIR = os.path.normpath(os.path.join(HERE, "..", "..", "..", "combat", "moves", "kael"))


def load_moves():
	"""{move id: {"startup", "active", "recovery", "hitbox"}}; hitbox = mean active centre, Blender axes."""
	moves = {}
	for fname in sorted(os.listdir(MOVES_DIR)):
		if not fname.endswith(".tres") or fname == "kael_move_set.tres":
			continue
		text = open(os.path.join(MOVES_DIR, fname)).read()
		mid = re.search(r'^id = &"([^"]+)"', text, re.M).group(1)
		data = {}
		for key in ("startup_ticks", "active_ticks", "recovery_ticks"):
			m = re.search(r"^%s = (\d+)" % key, text, re.M)
			data[key.split("_")[0]] = int(m.group(1)) if m else 1
		m = re.search(r"^hitbox_offsets = PackedVector3Array\(([^)]*)\)", text, re.M)
		nums = [float(x) for x in m.group(1).split(",")] if m and m.group(1).strip() else [0, 0, -1]
		pts = [Vector(nums[i:i + 3]) for i in range(0, len(nums), 3)]
		active = [pts[min(i, len(pts) - 1)] for i in range(data["active"])]
		mean = sum(active, Vector()) / len(active)
		data["hitbox"] = sim_to_blender(mean)
		moves[mid] = data
	return moves


def sim_to_blender(p):
	"""Fighter-local sim point (Godot axes, origin 1 m above the feet, facing -Z) -> Blender armature space."""
	return Vector((-p.x, p.z, p.y + 1.0))
