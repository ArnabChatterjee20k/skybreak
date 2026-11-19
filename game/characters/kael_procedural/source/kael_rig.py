"""Kael's humanoid skeleton (names match Godot's SkeletonProfileHumanoid) and distance-based skin weights."""

from mathutils import Vector

import kael_params as P
from kael_mesh import arm_points

J = P.JOINTS


def bone_layout():
	"""Bones as (name, parent, head, tail) in the T-pose, Blender axes (+Z up, facing -Y)."""
	b = []
	b.append(("Root", None, (0, 0, 0), (0, 0, 0.12)))
	b.append(("Hips", "Root", (0, 0, J["hips"]), (0, 0, J["spine"])))
	b.append(("Spine", "Hips", (0, 0, J["spine"]), (0, 0, J["chest"])))
	b.append(("Chest", "Spine", (0, 0, J["chest"]), (0, 0, J["upper_chest"])))
	b.append(("UpperChest", "Chest", (0, 0, J["upper_chest"]), (0, 0.004, J["neck"] - 0.03)))
	b.append(("Neck", "UpperChest", (0, 0.004, J["neck"]), (0, 0.004, J["head"])))
	b.append(("Head", "Neck", (0, 0.004, J["head"]), (0, 0.004, J["head_top"])))
	# Hair bones for secondary motion: they start inside the skull and point along the main spikes.
	c = Vector((0, -0.006, 1.738))
	b.append(("HairTop", "Head", tuple(c + Vector((0, 0.0, 0.1))), tuple(c + Vector((0, 0.08, 0.28)))))
	b.append(("HairBack", "Head", tuple(c + Vector((0, 0.08, 0.06))), tuple(c + Vector((0, 0.3, 0.16)))))
	b.append(("HairLeft", "Head", tuple(c + Vector((0.08, 0.02, 0.06))), tuple(c + Vector((0.2, 0.2, 0.12)))))
	b.append(("HairRight", "Head", tuple(c + Vector((-0.08, 0.02, 0.06))), tuple(c + Vector((-0.2, 0.2, 0.12)))))
	b.append(("HairFront", "Head", tuple(c + Vector((0, -0.09, 0.09))), tuple(c + Vector((0, -0.13, -0.02)))))
	for sign, side in ((1, "Left"), (-1, "Right")):
		shoulder, elbow, wrist, knuckles = arm_points(sign)
		b.append((side + "Shoulder", "UpperChest", (sign * J["shoulder_x"], 0.004, J["arm_z"] - 0.01),
			tuple(shoulder)))
		b.append((side + "UpperArm", side + "Shoulder", tuple(shoulder), tuple(elbow)))
		b.append((side + "LowerArm", side + "UpperArm", tuple(elbow), tuple(wrist)))
		b.append((side + "Hand", side + "LowerArm", tuple(wrist), tuple(knuckles)))
		lengths = [0.085, 0.092, 0.087, 0.072]
		for i, (finger, length) in enumerate(zip(["Index", "Middle", "Ring", "Little"], lengths)):
			root = knuckles + Vector((-sign * 0.006, -0.036 + i * 0.024, 0.002))
			tip = root + Vector((sign * length, 0, -0.004))
			p1, p2 = root.lerp(tip, 0.42), root.lerp(tip, 0.72)
			b.append((side + finger + "Proximal", side + "Hand", tuple(root), tuple(p1)))
			b.append((side + finger + "Intermediate", side + finger + "Proximal", tuple(p1), tuple(p2)))
			b.append((side + finger + "Distal", side + finger + "Intermediate", tuple(p2), tuple(tip)))
		t_root = wrist.lerp(knuckles, 0.25) + Vector((0, -0.04, -0.006))
		t_tip = t_root + Vector((sign * 0.06, -0.035, -0.012))
		t_mid = t_root.lerp(t_tip, 0.5)
		b.append((side + "ThumbMetacarpal", side + "Hand", tuple(wrist + Vector((sign * 0.01, -0.02, -0.004))),
			tuple(t_root)))
		b.append((side + "ThumbProximal", side + "ThumbMetacarpal", tuple(t_root), tuple(t_mid)))
		b.append((side + "ThumbDistal", side + "ThumbProximal", tuple(t_mid), tuple(t_tip)))
		x = sign * J["leg_x"]
		b.append((side + "UpperLeg", "Hips", (x, 0, J["hips"] - 0.02), (x, 0.0, J["knee_z"])))
		b.append((side + "LowerLeg", side + "UpperLeg", (x, 0.0, J["knee_z"]), (x, 0.01, J["ankle_z"])))
		b.append((side + "Foot", side + "LowerLeg", (x, 0.01, J["ankle_z"]), (x * 1.04, J["toe_y"], 0.035)))
		b.append((side + "Toes", side + "Foot", (x * 1.04, J["toe_y"], 0.035), (x * 1.06, J["toe_tip_y"], 0.032)))
	return b


def _segment_distance(p, a, b):
	ab = b - a
	t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
	return (a + ab * t - p).length


def skin_weights(verts, bones, allowed, power=6.0, keep=3):
	"""Per-vertex {bone: weight} from inverse distance to bone segments, limited to allowed bones."""
	segs = [(name, Vector(h), Vector(t)) for name, _, h, t in bones
		if name != "Root" and not name.startswith("Hair") and (allowed is None or name in allowed)]
	out = []
	for v in verts:
		scored = []
		for name, h, t in segs:
			d = _segment_distance(v, h, t)
			scored.append((1.0 / (d + 0.004) ** power, name))
		scored.sort(reverse=True)
		top = scored[:keep]
		total = sum(w for w, _ in top)
		out.append({name: w / total for w, name in top if w / total > 0.02})
	return out
