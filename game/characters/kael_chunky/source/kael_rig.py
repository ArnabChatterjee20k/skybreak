"""Chunky Kael's skeleton (names match Godot's SkeletonProfileHumanoid, plus a scarf chain) and
distance-based skin weights."""

from mathutils import Vector

import kael_params as P
from kael_mesh import FINGER_LENGTHS, HEAD_C, arm_points, finger_root, scarf_chain, thumb_points

J = P.J
SCARF_BONES = ["Scarf%d" % (i + 1) for i in range(P.SCARF_BONES)]


def bone_layout():
	"""Bones as (name, parent, head, tail) in the T-pose, Blender axes (+Z up, facing -Y)."""
	b = []
	b.append(("Root", None, (0, 0, 0), (0, 0, 0.12)))
	b.append(("Hips", "Root", (0, 0, J["hips"]), (0, 0, J["spine"])))
	b.append(("Spine", "Hips", (0, 0, J["spine"]), (0, 0, J["chest"])))
	b.append(("Chest", "Spine", (0, 0, J["chest"]), (0, 0, J["upper_chest"])))
	b.append(("UpperChest", "Chest", (0, 0, J["upper_chest"]), (0, 0.004, J["neck"])))
	b.append(("Neck", "UpperChest", (0, 0.004, J["neck"]), (0, 0.004, J["head"])))
	b.append(("Head", "Neck", (0, 0.004, J["head"]), (0, 0.004, HEAD_C.z + 0.22)))
	for sign, s in ((1, "Left"), (-1, "Right")):
		eye = HEAD_C + Vector((sign * 0.075, -0.15, -0.03))
		b.append((s + "Eye", "Head", tuple(eye), tuple(eye + Vector((0, -0.05, 0)))))
	b.append(("Jaw", "Head", tuple(HEAD_C + Vector((0, -0.04, -0.1))), tuple(HEAD_C + Vector((0, -0.15, -0.19)))))
	chain = scarf_chain()
	parent = "UpperChest"
	for i, name in enumerate(SCARF_BONES):
		b.append((name, parent, tuple(chain[i]), tuple(chain[i + 1])))
		parent = name
	for sign, s in ((1, "Left"), (-1, "Right")):
		shoulder, elbow, wrist, knuckles = arm_points(sign)
		b.append((s + "Shoulder", "UpperChest", (sign * J["shoulder_x"], 0.004, J["arm_z"] - 0.01), tuple(shoulder)))
		b.append((s + "UpperArm", s + "Shoulder", tuple(shoulder), tuple(elbow)))
		b.append((s + "LowerArm", s + "UpperArm", tuple(elbow), tuple(wrist)))
		b.append((s + "Hand", s + "LowerArm", tuple(wrist), tuple(knuckles)))
		for i, (finger, length) in enumerate(zip(["Index", "Middle", "Ring", "Little"], FINGER_LENGTHS)):
			root = finger_root(sign, i)
			tip = root + Vector((sign * length, 0, -0.004))
			p1, p2 = root.lerp(tip, 0.42), root.lerp(tip, 0.72)
			b.append((s + finger + "Proximal", s + "Hand", tuple(root), tuple(p1)))
			b.append((s + finger + "Intermediate", s + finger + "Proximal", tuple(p1), tuple(p2)))
			b.append((s + finger + "Distal", s + finger + "Intermediate", tuple(p2), tuple(tip)))
		base, t_root, t_tip = thumb_points(sign)
		t_mid = t_root.lerp(t_tip, 0.5)
		b.append((s + "ThumbMetacarpal", s + "Hand", tuple(base), tuple(t_root)))
		b.append((s + "ThumbProximal", s + "ThumbMetacarpal", tuple(t_root), tuple(t_mid)))
		b.append((s + "ThumbDistal", s + "ThumbProximal", tuple(t_mid), tuple(t_tip)))
		x = sign * J["leg_x"]
		b.append((s + "UpperLeg", "Hips", (x, 0, J["hips"] - 0.02), (x, -0.006, J["knee"])))
		b.append((s + "LowerLeg", s + "UpperLeg", (x, -0.006, J["knee"]), (x, 0.01, J["ankle"])))
		b.append((s + "Foot", s + "LowerLeg", (x, 0.01, J["ankle"]), (x * 1.03, J["toe_y"], 0.05)))
		b.append((s + "Toes", s + "Foot", (x * 1.03, J["toe_y"], 0.05), (x * 1.05, J["toe_tip_y"], 0.045)))
	return b


NO_DEFORM = {"Root", "LeftEye", "RightEye", "Jaw"}


def _segment_distance(p, a, b):
	ab = b - a
	t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
	return (a + ab * t - p).length


def skin_weights(v, bones, allowed, power=6.0, keep=3):
	"""{bone: weight} for one vertex from inverse distance to bone segments, limited to allowed bones."""
	scored = []
	for name, _, h, t in bones:
		if name in NO_DEFORM or name in SCARF_BONES or (allowed is not None and name not in allowed):
			continue
		d = _segment_distance(v, Vector(h), Vector(t))
		scored.append((1.0 / (d + 0.004) ** power, name))
	scored.sort(reverse=True)
	top = scored[:keep]
	total = sum(w for w, _ in top)
	return {name: w / total for w, name in top if w / total > 0.02}
