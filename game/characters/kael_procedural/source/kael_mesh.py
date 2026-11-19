"""Builds Kael's body, outfit, face and hair as Parts (see kael_geometry)."""

import math
import random

from mathutils import Vector

import kael_params as P
from kael_geometry import Part, ellipsoid, loft, spike

J = P.JOINTS
R = P.RADII

LEGS = ["Hips", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"]
FEET = ["LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot", "LeftToes", "RightToes"]
TORSO = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "LeftShoulder", "RightShoulder"]


def _side(name, sign):
	return name.replace("Left", "Right") if sign < 0 else name


def arm_points(sign):
	"""Shoulder, elbow, wrist and knuckle positions of one arm in the T-pose."""
	z = J["arm_z"]
	x0 = J["upper_arm_x"]
	elbow = x0 + J["upper_arm_len"]
	wrist = elbow + J["lower_arm_len"]
	return (Vector((sign * x0, 0, z)), Vector((sign * elbow, 0.005, z)),
		Vector((sign * wrist, 0, z)), Vector((sign * (wrist + J["hand_len"]), 0, z)))


def build_body(sign):
	"""One arm, from the deltoid to the wrist: skin."""
	shoulder, elbow, wrist, _ = arm_points(sign)
	part = Part("arm", "skin", TORSO + [_side(b, sign) for b in
		["LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand"]])
	start = Vector((sign * (J["upper_arm_x"] - 0.07), 0, J["arm_z"] - 0.01))
	path = [start, shoulder + Vector((sign * 0.02, 0, 0.005)), shoulder.lerp(elbow, 0.45),
		elbow, elbow.lerp(wrist, 0.35), wrist + Vector((sign * 0.01, 0, 0))]
	radii = [(0.075, 0.068), R["shoulder"], R["bicep"], R["elbow"], R["forearm"], R["wrist"]]
	# Rings go round the arm: rx points up so the arm is a bit taller than deep at the deltoid.
	loft(part, path, radii, sides=14, samples=4, side_ref=(0, 0, 1))
	return part


def build_hand(sign):
	"""A slightly large hand: palm block, four fingers and a thumb, palm down in the T-pose."""
	_, _, wrist, knuckles = arm_points(sign)
	hand = _side("LeftHand", sign)
	part = Part("hand", "skin", [_side("LeftLowerArm", sign), hand] + [b for b in _finger_bones(sign)])
	palm_path = [wrist - Vector((sign * 0.015, 0, 0)), wrist.lerp(knuckles, 0.5), knuckles]
	loft(part, palm_path, [(0.026, 0.036), (0.024, 0.048), (0.02, 0.05)], sides=10, samples=2,
		side_ref=(0, 0, 1), squareness=[2.2, 2.8, 3.0])
	lengths = [0.085, 0.092, 0.087, 0.072]
	for i, (name, length) in enumerate(zip(["Index", "Middle", "Ring", "Little"], lengths)):
		y = -0.036 + i * 0.024
		root = knuckles + Vector((-sign * 0.006, y, 0.002))
		tip = root + Vector((sign * length, 0, -0.004))
		pts = [root, root.lerp(tip, 0.42), root.lerp(tip, 0.72), tip]
		r = 0.0125 if name != "Little" else 0.011
		loft(part, pts, [(r, r * 1.05), (r * 0.95, r), (r * 0.9, r * 0.92), (r * 0.82, r * 0.85)],
			sides=8, samples=3, side_ref=(0, 0, 1))
	thumb_root = wrist.lerp(knuckles, 0.25) + Vector((0, -0.04, -0.006))
	thumb_tip = thumb_root + Vector((sign * 0.06, -0.035, -0.012))
	pts = [thumb_root, thumb_root.lerp(thumb_tip, 0.5), thumb_tip]
	loft(part, pts, [(0.016, 0.017), (0.0135, 0.014), (0.011, 0.012)], sides=8, samples=3, side_ref=(0, 0, 1))
	return part


def _finger_bones(sign):
	names = []
	for f in ["Thumb", "Index", "Middle", "Ring", "Little"]:
		segs = ["Metacarpal", "Proximal", "Distal"] if f == "Thumb" else ["Proximal", "Intermediate", "Distal"]
		names += [_side("Left%s%s" % (f, s), sign) for s in segs]
	return names


def _torso_profile(scale=1.0, extra=0.0):
	# (z, rx, ry, forward offset, squareness)
	rows = [
		(1.02, 0.128, 0.092, 0.000, 2.2),
		(1.06, 0.124, 0.091, 0.000, 2.2),
		(1.11, 0.118, 0.090, -0.003, 2.3),
		(1.22, 0.150, 0.104, -0.010, 2.5),
		(1.32, 0.182, 0.112, -0.016, 2.7),
		(1.40, 0.200, 0.106, -0.012, 2.8),
		(1.455, 0.204, 0.092, -0.004, 2.8),
		(1.50, 0.165, 0.078, 0.004, 2.4),
		(1.54, 0.085, 0.066, 0.006, 2.0),
	]
	path, radii, sq, offs = [], [], [], []
	for z, rx, ry, fy, e in rows:
		path.append(Vector((0, 0, z)))
		radii.append((rx * scale + extra, ry * scale + extra))
		sq.append(e)
		offs.append((0.0, fy))
	return path, radii, sq, offs


def build_undershirt():
	"""The torso, seen as the dark undershirt inside the gi's V and armholes."""
	part = Part("undershirt", "navy", TORSO + ["LeftUpperArm", "RightUpperArm"])
	path, radii, sq, offs = _torso_profile()
	# side_ref along X; the front axis is then -Y (tangent up x side).
	loft(part, path, radii, sides=24, samples=3, side_ref=(1, 0, 0), squareness=sq, offsets=offs,
		cap_start=True, cap_end=False)
	neck = Part("neck", "skin", ["UpperChest", "Neck", "Head"])
	loft(neck, [Vector((0, 0.004, 1.47)), Vector((0, 0.006, J["neck"] + 0.05)), Vector((0, 0.004, J["head"] + 0.06))],
		[R["neck"], (R["neck"][0] * 0.95, R["neck"][1] * 0.95), (0.05, 0.05)], sides=12, samples=3,
		side_ref=(1, 0, 0), cap_start=False, cap_end=False)
	return part, neck


def build_gi_top():
	"""Sleeveless gi top: a shell over the torso with a V neck and armholes; the hem flares below the belt."""
	part = Part("gi_top", "gi_orange", TORSO + ["LeftUpperArm", "RightUpperArm"])
	part.keep_winding = True
	rows = [
		(1.045, 0.138, 0.102, 0.0, 2.3),
		(1.11, 0.132, 0.101, -0.003, 2.3),
		(1.22, 0.163, 0.116, -0.010, 2.6),
		(1.32, 0.196, 0.124, -0.016, 2.8),
		(1.40, 0.213, 0.118, -0.012, 2.8),
		(1.455, 0.217, 0.104, -0.004, 2.8),
		(1.50, 0.18, 0.089, 0.004, 2.4),
		(1.535, 0.11, 0.08, 0.006, 2.0),
	]
	path = [Vector((0, 0, r[0])) for r in rows]
	radii = [(r[1], r[2]) for r in rows]
	sq = [r[4] for r in rows]
	offs = [(0.0, r[3]) for r in rows]

	def folds(t, a, p):
		# Soft blousing folds where the top tucks under the belt.
		if p.z > 1.2:
			return 1.0
		k = (1.2 - p.z) / 0.16
		return 1.0 + 0.03 * k * max(0.0, math.sin(a * 6 + 0.6))

	loft(part, path, radii, sides=32, samples=4, side_ref=(1, 0, 0), squareness=sq, offsets=offs,
		cap_start=False, cap_end=False, radial=folds)
	_cut(part, _gi_opening)
	for loop in boundary_loops(part):
		for i in loop:
			if part.verts[i].z > 1.15:
				part.verts[i] = _gi_snap(part.verts[i])
	return part


V_BOTTOM = 1.25
V_SLOPE = 0.6
ARMHOLE_Z = 1.415
ARMHOLE_R = 0.09
NECK_Z = 1.525


def _armhole_vec(c, sx):
	return Vector((c.x - sx * J["upper_arm_x"], c.y * 1.15, (c.z - ARMHOLE_Z) * 0.95))


def _gi_opening(c):
	"""True where the gi is open: the V neck, the armholes and the neck hole."""
	if c.y < -0.02 and c.z > V_BOTTOM and abs(c.x) < (c.z - V_BOTTOM) * V_SLOPE:
		return True
	for sx in (-1, 1):
		if _armhole_vec(c, sx).length < ARMHOLE_R and abs(c.x) > 0.125:
			return True
	return c.z > NECK_Z


def _gi_snap(v):
	"""Moves a boundary vertex onto the nearest opening's edge, so the cut is smooth."""
	options = []
	if v.y < 0 and v.z > V_BOTTOM - 0.03:
		half = max(0.0, (v.z - V_BOTTOM) * V_SLOPE)
		options.append((abs(abs(v.x) - half), Vector((math.copysign(half, v.x), v.y, v.z))))
	for sx in (-1, 1):
		d = _armhole_vec(v, sx)
		if d.length > 1e-6:
			k = ARMHOLE_R / d.length
			goal = Vector((sx * J["upper_arm_x"] + d.x * k, v.y, ARMHOLE_Z + d.z * k / 0.95))
			options.append((abs(d.length - ARMHOLE_R), goal))
	options.append((abs(v.z - NECK_Z), Vector((v.x, v.y, min(v.z, NECK_Z)))))
	return min(options, key=lambda o: o[0])[1]


def _cut(part, is_open):
	"""Deletes faces whose centre is open, then drops unused vertices."""
	keep = []
	for f in part.faces:
		c = sum((part.verts[i] for i in f), Vector()) / len(f)
		if not is_open(c):
			keep.append(f)
	part.faces = keep
	used = sorted({i for f in keep for i in f})
	remap = {old: new for new, old in enumerate(used)}
	part.verts = [part.verts[i] for i in used]
	part.faces = [[remap[i] for i in f] for f in keep]


def boundary_loops(part):
	"""Closed loops of boundary edges, as ordered vertex index lists."""
	count = {}
	for f in part.faces:
		for k in range(len(f)):
			e = (f[k], f[(k + 1) % len(f)])
			key = tuple(sorted(e))
			count[key] = count.get(key, 0) + 1
	edges = [e for e, c in count.items() if c == 1]
	nbrs = {}
	for a, b in edges:
		nbrs.setdefault(a, []).append(b)
		nbrs.setdefault(b, []).append(a)
	loops, seen = [], set()
	for start in nbrs:
		if start in seen:
			continue
		loop = [start]
		seen.add(start)
		prev, cur = None, start
		while True:
			nxt = [n for n in nbrs[cur] if n != prev and n not in seen]
			if not nxt:
				break
			prev, cur = cur, nxt[0]
			loop.append(cur)
			seen.add(cur)
		if len(loop) > 4:
			loops.append(loop)
	return loops


def build_trim(gi):
	"""White trim tubes along every opening of the gi top."""
	part = Part("gi_trim", "gi_trim", gi.bones)
	for loop in boundary_loops(gi):
		pts = [gi.verts[i] for i in loop]
		# Thin out the loop so the tube is smooth, then sweep a flat band around it.
		for _ in range(6):
			pts = [(pts[i - 1] + pts[i] * 2 + pts[(i + 1) % len(pts)]) / 4 for i in range(len(pts))]
		step = max(1, len(pts) // 48)
		pts = pts[::step]
		centre = sum(pts, Vector()) / len(pts)
		if centre.z < 1.08:
			continue  # The hem is tucked under the belt.
		loft(part, pts, [(0.016, 0.009)], sides=6, samples=2, side_ref=(0, 0, 1), closed=True)
	return part


def build_belt():
	"""Wide navy belt with a knot and two hanging ends."""
	part = Part("belt", "navy", ["Hips", "Spine"])
	z0, z1 = 1.035, 1.10
	path = [Vector((0, 0, z0)), Vector((0, 0, (z0 + z1) / 2)), Vector((0, 0, z1))]
	loft(part, path, [(0.157, 0.116), (0.150, 0.112), (0.143, 0.108)], sides=28, samples=2,
		side_ref=(1, 0, 0), squareness=[2.4] * 3, cap_start=False, cap_end=False)
	# Knot on his left front.
	ellipsoid(part, (0.05, -0.112, 1.068), (0.034, 0.022, 0.03), rings=6, sides=10)
	ends = Part("belt_ends", "navy", ["Hips", "LeftUpperLeg"])
	for dx, ang, length in ((0.045, 0.18, 0.27), (0.075, 0.45, 0.22)):
		top = Vector((dx, -0.122, 1.05))
		bot = top + Vector((math.sin(ang) * length * 0.35, -0.045, -length))
		pts = [top, top.lerp(bot, 0.5) + Vector((0, -0.012, 0)), bot]
		loft(ends, pts, [(0.024, 0.006), (0.027, 0.006), (0.03, 0.006)], sides=8, samples=3,
			side_ref=(1, 0, 0))
	return part, ends


def build_pants():
	"""Loose orange pants, tucked into the boots; a few cloth folds."""
	part = Part("pants", "pants_orange", LEGS + ["Spine"])
	loft(part, [Vector((0, 0, 1.075)), Vector((0, 0, 1.0)), Vector((0, 0.005, 0.9)), Vector((0, 0.01, 0.83))],
		[(0.136, 0.1), (0.156, 0.114), (0.165, 0.118), (0.12, 0.09)], sides=24, samples=2, side_ref=(1, 0, 0),
		cap_start=False, cap_end=True)
	rnd = random.Random(P.SEED)
	for sign in (1, -1):
		x = sign * J["leg_x"]
		path = [Vector((x * 0.85, 0.0, 1.0)), Vector((x, 0.0, 0.82)), Vector((x * 1.05, 0.0, J["knee_z"] + 0.04)),
			Vector((x * 1.08, 0.005, 0.40)), Vector((x * 1.02, 0.005, 0.315)), Vector((x, 0.0, 0.25))]
		radii = [(0.1, 0.1), (0.106, 0.11), (0.096, 0.1), (0.102, 0.104), (0.09, 0.092), (0.058, 0.062)]
		phase = rnd.uniform(0, 6.28)

		def folds(t, a, p, phase=phase):
			# Bunched folds above the boot and a crease behind the knee.
			k = max(0.0, 1.0 - abs(p.z - 0.36) / 0.12)
			return 1.0 + 0.055 * k * math.sin(a * 5 + phase) + 0.02 * math.sin(a * 3 + p.z * 20)

		loft(part, path, radii, sides=18, samples=3, side_ref=(1, 0, 0), cap_start=False, cap_end=True,
			radial=folds)
	return part


def build_boots():
	"""White wrapped boots: a shaft with wrap ridges and a big readable foot."""
	part = Part("boots", "boots", FEET)
	for sign in (1, -1):
		x = sign * J["leg_x"]
		shaft = [Vector((x, 0.004, 0.335)), Vector((x, 0.004, 0.25)), Vector((x, 0.006, 0.14)), Vector((x, 0.01, 0.075))]

		def wraps(t, a, p):
			# Diagonal wrap bands.
			return 1.0 + 0.035 * max(0.0, math.sin((p.z * 58.0) + a * 0.5)) * min(1.0, (0.31 - p.z) / 0.04)

		loft(part, shaft, [(0.074, 0.077), (0.066, 0.07), (0.056, 0.062), (0.06, 0.07)], sides=16, samples=4,
			side_ref=(1, 0, 0), radial=wraps, cap_start=True, cap_end=False)
		foot = [Vector((x, 0.06, 0.055)), Vector((x, 0.0, 0.06)), Vector((x * 1.04, -0.09, 0.045)),
			Vector((x * 1.06, -0.17, 0.036)), Vector((x * 1.06, -0.215, 0.032))]
		loft(part, foot, [(0.052, 0.05), (0.06, 0.062), (0.058, 0.044), (0.056, 0.034), (0.04, 0.026)],
			sides=14, samples=3, side_ref=(1, 0, 0), squareness=[2.4, 2.4, 2.8, 3.0, 2.4],
			offsets=[(0, 0), (0, 0), (0, 0.0), (0, 0.006), (0, 0.008)])
		# Flat sole so the feet plant on the ground.
	for i, v in enumerate(part.verts):
		if v.z < 0.0:
			v.z = 0.0
	return part


def build_wristbands():
	part = Part("wristbands", "navy", ["LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand"])
	for sign in (1, -1):
		_, elbow, wrist, _ = arm_points(sign)
		a = elbow.lerp(wrist, 0.68)
		b = wrist + Vector((sign * 0.004, 0, 0))
		loft(part, [a, a.lerp(b, 0.5), b], [(0.05, 0.048), (0.045, 0.043), (0.04, 0.038)], sides=12, samples=2,
			side_ref=(0, 0, 1), cap_start=False, cap_end=False)
	return part


HEAD_CENTRE = Vector((0, -0.006, 1.738))
HEAD_RADII = (0.108, 0.118, 0.142)


def _head_shape(u):
	"""Unit sphere -> anime head: round cranium, narrow pointed jaw, flatter face."""
	x, y, z = u.x, u.y, u.z
	if z < 0.15:
		k = (0.15 - z) / 1.15
		x *= 1.0 - 0.44 * k ** 1.25
		if y < 0:
			y *= 1.0 - 0.15 * k
		else:
			y *= 1.0 - 0.45 * k
		z = 0.15 + (z - 0.15) * 1.02
	if y < 0:
		# Flatten the face plane slightly.
		y *= 0.93
	if y > 0 and z > -0.2:
		y *= 1.06
	return Vector((x, y, z))


def build_head():
	"""Head and ears in skin; the front faces become the 'face' slot with planar UVs."""
	head = Part("head", "skin", ["Neck", "Head"])
	ellipsoid(head, HEAD_CENTRE, HEAD_RADII, rings=20, sides=28, shape=_head_shape)
	face = Part("face", "face", ["Head"])
	keep = []
	for f in head.faces:
		c = sum((head.verts[i] for i in f), Vector()) / len(f)
		rel = c - HEAD_CENTRE
		if rel.y < -0.045 and rel.z > -0.135 and abs(rel.x) < 0.098:
			face.faces.append(f)
		else:
			keep.append(f)
	head.faces = keep
	face.verts = head.verts  # Shared until split in Blender (see build_kael).
	for sign in (1, -1):
		ear = Part("ear", "skin", ["Head"])
		ellipsoid(ear, HEAD_CENTRE + Vector((sign * 0.104, 0.018, -0.012)), (0.016, 0.026, 0.036), rings=6, sides=8)
		head.merge(ear)
	return head, face


def face_uv(co):
	"""Planar front projection of the face; the texture covers 0.22 m x 0.22 m."""
	rel = co - HEAD_CENTRE
	return (0.5 + rel.x / 0.22, 0.5 + (rel.z + 0.02) / 0.22)


def build_hair():
	"""Navy hair cap plus tapered spikes. Weights: Head, blended into a hair bone along each spike."""
	part = Part("hair", "hair", None)
	weights = []
	cap = Part("cap", "hair", None)

	def cap_shape(u):
		return Vector((u.x, u.y, u.z * 1.0 if u.z > -0.1 else u.z))

	ellipsoid(cap, HEAD_CENTRE + Vector((0, 0.01, 0.014)), (0.117, 0.13, 0.148), rings=18, sides=28, shape=cap_shape)
	# Cut the cap open over the face, in front of the ears and at the nape.
	def cap_open(c):
		rel = c - HEAD_CENTRE
		if rel.y < -0.05 and rel.z < 0.06 + 0.25 * abs(rel.x) ** 1.5 * 10 * 0.1:
			return True
		if rel.y < 0.035 and rel.z < -0.035:
			return True
		if rel.z < -0.115 + 0.4 * max(0.0, -rel.y):
			return True
		return False
	_cut(cap, cap_open)
	part.merge(cap)
	weights += [{"Head": 1.0}] * len(cap.verts)
	rnd = random.Random(P.SEED)
	top = HEAD_CENTRE + Vector((0, 0, 0.0))
	for az, el, length, radius, sweep_up, sweep_back, curl in P.HAIR_SPIKES:
		if el >= P.HAIR_TALL_ELEVATION:
			length *= P.HAIR_TALL_SCALE
		a = math.radians(az + rnd.uniform(-3, 3))
		e = math.radians(el)
		normal = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
		base = top + Vector((normal.x * 0.105, normal.y * 0.115, normal.z * 0.13))
		direction = (normal + Vector((0, 1, 0)) * sweep_back + Vector((0, 0, 1)) * sweep_up).normalized()
		up = Vector((0, 0, 1)) if abs(direction.z) < 0.9 else Vector((0, 1, 0))
		s = Part("spike", "hair", None)
		ids = spike(s, base - direction * 0.03, direction, up, length * 1.15, radius * 1.15, curl,
			flat=0.62, sides=6, rings=6, twist=rnd.uniform(0, 1))
		bone = _hair_bone(az, el)
		w = [None] * len(s.verts)
		for vid, t in ids:
			k = min(1.0, max(0.0, (t - 0.15) / 0.6))
			w[vid] = {"Head": 1.0 - k, bone: k} if k > 0 else {"Head": 1.0}
		part.merge(s)
		weights += w
	for dx, length, radius, droop, swing in P.HAIR_BANGS:
		base = HEAD_CENTRE + Vector((dx, -0.10, 0.085))
		direction = Vector((swing * 0.5, -0.35, -droop)).normalized()
		s = Part("bang", "hair", None)
		ids = spike(s, base, direction, Vector((0, -1, 0)), length, radius, 0.25, flat=0.5, sides=6, rings=5)
		w = [None] * len(s.verts)
		for vid, t in ids:
			k = min(1.0, max(0.0, t - 0.2)) * 0.6
			w[vid] = {"Head": 1.0 - k, "HairFront": k} if k > 0 else {"Head": 1.0}
		part.merge(s)
		weights += w
	part.fixed_weights = weights
	return part


def _hair_bone(az, el):
	az = ((az + 180) % 360) - 180
	if el > 66:
		return "HairTop"
	if abs(az) > 135:
		return "HairBack"
	if az >= 0:
		return "HairLeft" if abs(az) > 45 else "HairTop"
	return "HairRight" if abs(az) > 45 else "HairTop"


def build_all():
	"""All parts of the character."""
	parts = []
	for sign in (1, -1):
		parts.append(build_body(sign))
		parts.append(build_hand(sign))
	shirt, neck = build_undershirt()
	parts += [shirt, neck]
	gi = build_gi_top()
	parts += [gi, build_trim(gi)]
	belt, ends = build_belt()
	parts += [belt, ends, build_pants(), build_boots(), build_wristbands()]
	head, face = build_head()
	parts += [head, face, build_hair()]
	return parts
