"""Builds chunky Kael's body, outfit, face, hair, goggles and scarf as Parts (see kael_geometry)."""

import math
import random

from mathutils import Vector

import kael_params as P
from kael_geometry import Part, ellipsoid, loft, spike

J = P.J
HEAD_C = Vector(P.HEAD_CENTRE)
HR = P.HEAD_RADII

TORSO = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "LeftShoulder", "RightShoulder"]
LEGS = ["Hips", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"]
FEET = ["LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot", "LeftToes", "RightToes"]
FINGERS = ["Index", "Middle", "Ring", "Little"]
FINGER_LENGTHS = [0.10, 0.108, 0.102, 0.088]
FINGER_RADIUS = 0.025
FINGER_SPACING = 0.035
# The face texture covers FACE_SIZE x FACE_SIZE metres, centred FACE_DROP below the head centre.
FACE_SIZE = 0.36
FACE_DROP = 0.03
COAT_HEM = 0.80
SKIRT_TOP = 0.86


def side(name, sign):
	return name.replace("Left", "Right") if sign < 0 else name


def arm_points(sign):
	"""Shoulder, elbow, wrist and knuckle positions of one arm in the T-pose."""
	z = J["arm_z"]
	x0 = J["upper_arm_x"]
	elbow = x0 + J["upper_arm_len"]
	wrist = elbow + J["lower_arm_len"]
	return (Vector((sign * x0, 0, z)), Vector((sign * elbow, 0.006, z)),
		Vector((sign * wrist, 0, z)), Vector((sign * (wrist + J["hand_len"]), 0, z)))


def finger_root(sign, i):
	_, _, _, knuckles = arm_points(sign)
	return knuckles + Vector((-sign * 0.01, -1.5 * FINGER_SPACING + i * FINGER_SPACING, 0.004))


def thumb_points(sign):
	_, _, wrist, knuckles = arm_points(sign)
	root = wrist.lerp(knuckles, 0.35) + Vector((0, -0.068, -0.012))
	tip = root + Vector((sign * 0.075, -0.035, -0.012))
	return wrist + Vector((sign * 0.015, -0.03, -0.006)), root, tip


# --- Arms --------------------------------------------------------------------------------------

def build_sleeve(sign):
	"""Teal coat sleeve from the shoulder to just past the elbow."""
	shoulder, elbow, wrist, _ = arm_points(sign)
	part = Part("sleeve", "coat", TORSO + [side(b, sign) for b in ["LeftUpperArm", "LeftLowerArm"]])
	start = Vector((sign * (J["upper_arm_x"] - 0.08), 0, J["arm_z"]))
	path = [start, shoulder, shoulder.lerp(elbow, 0.5), elbow, elbow + Vector((sign * 0.05, 0, 0))]
	radii = [(0.095, 0.09), (0.092, 0.088), (0.082, 0.08), (0.074, 0.072), (0.07, 0.068)]
	loft(part, path, radii, sides=14, samples=3, side_ref=(0, 0, 1))
	return part


def build_gauntlet(sign):
	"""Oversized gold gauntlet: a flared cuff over the forearm and a big mitt with chunky fingers."""
	_, elbow, wrist, knuckles = arm_points(sign)
	hand = side("LeftHand", sign)
	fingers = [side("Left%s%s" % (f, s), sign) for f in FINGERS + ["Thumb"]
		for s in (["Metacarpal", "Proximal", "Distal"] if f == "Thumb" else ["Proximal", "Intermediate", "Distal"])]
	cuff = Part("gauntlet_cuff", "gold", [side("LeftUpperArm", sign), side("LeftLowerArm", sign), hand])
	path = [elbow + Vector((sign * 0.035, 0, 0)), elbow + Vector((sign * 0.09, 0, 0)), elbow.lerp(wrist, 0.6),
		wrist + Vector((sign * 0.01, 0, 0))]
	loft(cuff, path, [(0.112, 0.112), (0.1, 0.1), (0.08, 0.08), (0.075, 0.075)], sides=16, samples=3,
		side_ref=(0, 0, 1))
	mitt = Part("gauntlet_hand", "gold", [side("LeftLowerArm", sign), hand] + fingers)
	palm = [wrist - Vector((sign * 0.01, 0, 0)), wrist.lerp(knuckles, 0.55), knuckles + Vector((sign * 0.01, 0, 0))]
	loft(mitt, palm, [(0.05, 0.07), (0.052, 0.08), (0.046, 0.08)], sides=12, samples=2, side_ref=(0, 0, 1),
		squareness=[2.4, 3.0, 3.0])
	for i, length in enumerate(FINGER_LENGTHS):
		root = finger_root(sign, i)
		tip = root + Vector((sign * length, 0, -0.004))
		pts = [root - Vector((sign * 0.02, 0, 0)), root.lerp(tip, 0.42), root.lerp(tip, 0.72), tip]
		r = FINGER_RADIUS * (0.9 if i == 3 else 1.0)
		loft(mitt, pts, [(r, r), (r, r), (r * 0.95, r * 0.95), (r * 0.88, r * 0.88)], sides=8, samples=2,
			side_ref=(0, 0, 1))
	base, root, tip = thumb_points(sign)
	loft(mitt, [base, root, root.lerp(tip, 0.5), tip], [(0.03, 0.03), (0.029, 0.029), (0.027, 0.027),
		(0.024, 0.024)], sides=8, samples=2, side_ref=(0, 0, 1))
	return cuff, mitt


def build_pauldron(sign):
	"""Rounded teal shoulder plate with a gold rim; follows the shoulder and half the upper arm."""
	centre = Vector((sign * 0.27, 0.0, J["arm_z"] + 0.035))
	part = Part("pauldron", "coat", None)

	def dome(u):
		return Vector((u.x, u.y, u.z if u.z > 0 else u.z * 0.35))

	ellipsoid(part, centre, (0.14, 0.135, 0.105), rings=8, sides=16, shape=dome)
	rim = Part("pauldron_rim", "gold", None)
	ring = []
	for k in range(16):
		a = 2 * math.pi * k / 16
		ring.append(centre + Vector((math.sin(a) * 0.142, -math.cos(a) * 0.137, -0.006)))
	loft(rim, ring, [(0.022, 0.016)], sides=6, samples=2, side_ref=(0, 0, 1), closed=True)
	part.merge(rim)
	w = {side("LeftShoulder", sign): 0.5, side("LeftUpperArm", sign): 0.5}
	part.fixed_weights = [dict(w) for _ in part.verts]
	return part


# --- Torso and coat ----------------------------------------------------------------------------

TORSO_ROWS = [
	# (z, rx, ry, forward offset (+ = back), squareness)
	(0.74, 0.19, 0.145, 0.0, 2.2),
	(0.84, 0.198, 0.148, 0.0, 2.2),
	(0.94, 0.212, 0.152, -0.004, 2.3),
	(1.04, 0.238, 0.16, -0.01, 2.5),
	(1.14, 0.258, 0.162, -0.012, 2.7),
	(1.22, 0.262, 0.152, -0.008, 2.8),
	(1.29, 0.22, 0.13, 0.0, 2.5),
	(1.34, 0.12, 0.1, 0.004, 2.0),
]


def build_tunic():
	"""The charcoal tunic: the torso itself, seen in the coat's front opening."""
	part = Part("tunic", "tunic", TORSO + ["LeftUpperArm", "RightUpperArm"])
	path = [Vector((0, 0, r[0])) for r in TORSO_ROWS]
	loft(part, path, [(r[1], r[2]) for r in TORSO_ROWS], sides=24, samples=2, side_ref=(1, 0, 0),
		squareness=[r[4] for r in TORSO_ROWS], offsets=[(0.0, r[3]) for r in TORSO_ROWS], cap_end=False)
	neck = Part("neck", "skin", ["UpperChest", "Neck", "Head"])
	loft(neck, [Vector((0, 0.0, 1.26)), Vector((0, 0.0, 1.36)), Vector((0, -0.005, 1.46))],
		[(0.08, 0.075), (0.078, 0.074), (0.07, 0.068)], sides=12, samples=2, side_ref=(1, 0, 0),
		cap_start=False, cap_end=False)
	return part, neck


def _coat_open(c):
	"""True where the coat is open: front opening, neck, armholes, and the skirt except the back tails."""
	if c.z > 1.335:
		return True
	if c.y < 0 and c.z > COAT_HEM - 0.04 and abs(c.x) < 0.05 + max(0.0, c.z - 1.02) * 0.55:
		return True
	if c.z < SKIRT_TOP and (c.y < 0.02 or abs(c.x) < 0.028):
		return True
	return False


def build_coat():
	"""Short armoured coat over the tunic: open at the front, two tails at the back to the knees."""
	part = Part("coat", "coat", None)
	part.keep_winding = True
	rows = [(0.42, 0.25, 0.215, 0.06, 2.2), (0.6, 0.235, 0.2, 0.035, 2.2), (SKIRT_TOP, 0.222, 0.172, 0.0, 2.2)]
	rows += [(z, rx + 0.022, ry + 0.022, fy, e) for z, rx, ry, fy, e in TORSO_ROWS[2:]]
	path = [Vector((0, 0, r[0])) for r in rows]
	loft(part, path, [(r[1], r[2]) for r in rows], sides=36, samples=3, side_ref=(1, 0, 0),
		squareness=[r[4] for r in rows], offsets=[(0.0, r[3]) for r in rows], cap_start=False, cap_end=False)
	_cut(part, _coat_open)
	_add_inner_shell(part, 0.008)
	part.weight_fn = _coat_weights
	return part


def _add_inner_shell(part, inset):
	"""Gives an open shell a back face: a copy pushed inward with flipped winding, so the
	inside of the coat shades like cloth instead of showing the outline hull."""
	count = len(part.verts)
	part.outer_verts = count
	normals = [Vector() for _ in range(count)]
	for f in part.faces:
		a, b, c = (part.verts[i] for i in f[:3])
		n = (b - a).cross(c - a)
		for i in f:
			normals[i] += n
	for i in range(count):
		part.verts.append(part.verts[i] - normals[i].normalized() * inset)
	part.faces += [[i + count for i in reversed(f)] for f in list(part.faces)]


def _coat_weights(v, distance_weights):
	"""Upper coat: distance weights. Tails: hips, with a little of the nearest thigh lower down."""
	if v.z >= SKIRT_TOP:
		return distance_weights(v, TORSO + ["LeftUpperArm", "RightUpperArm"])
	k = min(1.0, (SKIRT_TOP - v.z) / (SKIRT_TOP - 0.42)) * 0.4
	leg = "LeftUpperLeg" if v.x > 0 else "RightUpperLeg"
	return {"Hips": 1.0 - k, leg: k} if k > 0.02 else {"Hips": 1.0}


def build_coat_trim(coat):
	"""Gold trim along every edge of the coat."""
	part = Part("coat_trim", "gold", None)
	part.weight_fn = _coat_weights
	for loop in boundary_loops(coat):
		if loop[0] >= coat.outer_verts:
			continue
		pts = [coat.verts[i] for i in loop]
		for _ in range(4):
			pts = [(pts[i - 1] + pts[i] * 2 + pts[(i + 1) % len(pts)]) / 4 for i in range(len(pts))]
		step = max(1, len(pts) // 64)
		pts = pts[::step]
		loft(part, pts, [(0.02, 0.012)], sides=6, samples=2, side_ref=(0, 0, 1), closed=True)
	return part


def build_belt():
	"""Leather belt over the coat with a big gold buckle."""
	part = Part("belt", "leather", ["Hips", "Spine"])
	z0, z1 = 0.79, 0.87
	loft(part, [Vector((0, 0, z0)), Vector((0, 0, z1))], [(0.235, 0.182), (0.232, 0.18)], sides=28, samples=2,
		side_ref=(1, 0, 0), squareness=[2.4, 2.4], offsets=[(0, 0.0), (0, -0.002)], cap_start=False, cap_end=False)
	buckle = Part("buckle", "gold", ["Hips", "Spine"])
	ellipsoid(buckle, (0.0, -0.185, 0.83), (0.06, 0.022, 0.05), rings=6, sides=12,
		shape=lambda u: Vector((math.copysign(abs(u.x) ** 0.6, u.x), u.y, math.copysign(abs(u.z) ** 0.6, u.z))))
	return part, buckle


# --- Legs --------------------------------------------------------------------------------------

def build_pants():
	part = Part("pants", "pants", LEGS + ["Spine"])
	loft(part, [Vector((0, 0, 0.86)), Vector((0, 0, 0.78)), Vector((0, 0.0, 0.68))],
		[(0.205, 0.15), (0.215, 0.155), (0.17, 0.125)], sides=24, samples=2, side_ref=(1, 0, 0), cap_start=False,
		cap_end=True)
	for sign in (1, -1):
		x = sign * J["leg_x"]
		path = [Vector((x * 0.8, 0.0, 0.78)), Vector((x, 0.0, 0.66)), Vector((x * 1.02, -0.004, J["knee"])),
			Vector((x, 0.0, 0.3))]
		loft(part, path, [(0.11, 0.115), (0.112, 0.115), (0.095, 0.1), (0.085, 0.09)], sides=16, samples=3,
			side_ref=(1, 0, 0), cap_start=False, cap_end=True)
	return part


def build_boots():
	"""Chunky orange boots: a flared cuff, a fat shaft and a big round toe on a dark sole."""
	part = Part("boots", "boots", FEET)
	for sign in (1, -1):
		x = sign * J["leg_x"]
		shaft = [Vector((x, 0.0, 0.42)), Vector((x, 0.0, 0.37)), Vector((x, 0.004, 0.24)),
			Vector((x, 0.012, 0.11))]
		loft(part, shaft, [(0.122, 0.125), (0.108, 0.112), (0.095, 0.1), (0.098, 0.11)], sides=16, samples=3,
			side_ref=(1, 0, 0), cap_start=True, cap_end=False)
		foot = [Vector((x, 0.085, 0.07)), Vector((x, 0.01, 0.085)), Vector((x * 1.03, -0.1, 0.07)),
			Vector((x * 1.05, -0.2, 0.06)), Vector((x * 1.05, -0.275, 0.055))]
		loft(part, foot, [(0.085, 0.07), (0.098, 0.09), (0.098, 0.07), (0.092, 0.062), (0.06, 0.05)],
			sides=14, samples=3, side_ref=(1, 0, 0), squareness=[2.4, 2.4, 2.6, 2.6, 2.2],
			offsets=[(0, 0), (0, 0), (0, 0.004), (0, 0.008), (0, 0.01)])
	for v in part.verts:
		if v.z < 0.0:
			v.z = 0.0
	for i, f in enumerate(part.faces):
		if max(part.verts[k].z for k in f) < 0.032:
			part.face_materials[i] = "leather"
	return part


# --- Head --------------------------------------------------------------------------------------

def _head_shape(u):
	"""Unit sphere -> a toy-like head: round cranium, full cheeks, a small rounded chin."""
	x, y, z = u.x, u.y, u.z
	if z < 0.0:
		k = -z
		x *= 1.0 - 0.22 * k ** 1.6
		y *= 1.0 - (0.12 if y < 0 else 0.3) * k ** 1.4
	if y < 0:
		y *= 0.94
	return Vector((x, y, z))


def build_head():
	"""Head, ears and a small nose in skin; the front faces use the 'face' slot with planar UVs."""
	head = Part("head", "skin", None)
	ellipsoid(head, HEAD_C, HR, rings=18, sides=28, shape=_head_shape)
	for i, f in enumerate(head.faces):
		uvs = [face_uv(head.verts[k]) for k in f]
		c = sum((head.verts[k] for k in f), Vector()) / len(f) - HEAD_C
		if c.y < -0.11 and abs(c.x) < 0.15 and all(0.0 <= u <= 1.0 and 0.0 <= v <= 1.0 for u, v in uvs):
			head.face_materials[i] = "face"
	for sign in (1, -1):
		ear = Part("ear", "skin")
		ellipsoid(ear, HEAD_C + Vector((sign * 0.198, 0.02, -0.03)), (0.03, 0.045, 0.058), rings=6, sides=8)
		head.merge(ear)
	nose = Part("nose", "skin")
	ellipsoid(nose, HEAD_C + Vector((0, -0.178, -0.058)), (0.024, 0.024, 0.022), rings=5, sides=8)
	head.merge(nose)
	head.fixed_weights = [{"Head": 1.0}] * len(head.verts)
	return head


def face_uv(co):
	rel = co - HEAD_C
	return (0.5 + rel.x / FACE_SIZE, 0.5 + (rel.z + FACE_DROP) / FACE_SIZE)


def build_hair():
	"""Silver-white hair: a cap over the skull, fat windswept tufts and a fringe under the goggles."""
	part = Part("hair", "hair")
	cap = Part("cap", "hair")
	ellipsoid(cap, HEAD_C + Vector((0, 0.012, 0.022)), (HR[0] * 1.06, HR[1] * 1.07, HR[2] * 1.03), rings=16,
		sides=28)

	def cap_open(c):
		rel = c - HEAD_C
		if rel.y < -0.04 and rel.z < 0.115 - 0.25 * abs(rel.x):
			return True
		if rel.y < 0.04 and rel.z < -0.02:
			return True
		return rel.z < -0.14 + 0.5 * max(0.0, -rel.y)

	_cut(cap, cap_open)
	part.merge(cap)
	rnd = random.Random(P.SEED)
	for az, el, length, radius, bend in P.HAIR_TUFTS:
		a = math.radians(az + rnd.uniform(-4, 4))
		e = math.radians(el)
		normal = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
		base = HEAD_C + Vector((normal.x * HR[0] * 0.9, normal.y * HR[1] * 0.9 + 0.012, normal.z * HR[2] * 0.9 + 0.02))
		# Windswept: every tuft leans back and a little to his right.
		# Windswept: back and a little to his right; side and back tufts also fan outward.
		direction = (normal + Vector((normal.x * 0.7 - 0.1, 0.7, -0.1))).normalized()
		up = Vector((0, 0, 1)) if abs(direction.z) < 0.9 else Vector((0, 1, 0))
		s = Part("tuft", "hair")
		spike(s, base - direction * 0.05, direction, up, length + 0.05, radius, bend, flat=0.72, sides=7, rings=5,
			twist=rnd.uniform(0, 1), fullness=0.7)
		part.merge(s)
	for dx, length, radius, swing in P.HAIR_FRINGE:
		base = HEAD_C + Vector((dx, -0.155 + abs(dx) * 0.35, 0.12))
		direction = Vector((swing * 0.6, -0.45, -1.0)).normalized()
		s = Part("fringe", "hair")
		spike(s, base, direction, Vector((0, -1, 0)), length, radius, 0.3, flat=0.55, sides=6, rings=4, fullness=0.6)
		part.merge(s)
	part.fixed_weights = [{"Head": 1.0}] * len(part.verts)
	return part


GOGGLE_Z = 0.135  # Strap height above the head centre, at the front.


def build_goggles():
	"""Brass flight goggles pushed up on the hair: a strap round the head and two big round lenses."""
	strap = Part("strap", "leather")
	ring = []
	for k in range(24):
		a = 2 * math.pi * k / 24
		front = -math.cos(a)  # 1 at the front, -1 at the back.
		z = HEAD_C.z + GOGGLE_Z - 0.06 * (1 - front) * 0.5
		r = 1.0 + 0.02 * (1 - front)
		ring.append(Vector((math.sin(a) * HR[0] * 1.02 * r, -math.cos(a) * HR[1] * 0.98 * r + 0.01, z)))
	loft(strap, ring, [(0.032, 0.014)], sides=6, samples=2, side_ref=(0, 0, 1), closed=True)
	parts = Part("goggles", "gold")
	glass = Part("lenses", "lens")
	tilt = Vector((0, -math.cos(math.radians(32)), math.sin(math.radians(32))))
	for sign in (1, -1):
		centre = HEAD_C + Vector((sign * 0.085, -0.168, GOGGLE_Z + 0.018))
		loft(parts, [centre - tilt * 0.02, centre + tilt * 0.035], [(0.068, 0.068), (0.068, 0.068)], sides=16,
			samples=1, side_ref=(1, 0, 0))
		ellipsoid(glass, centre + tilt * 0.04, (0.054, 0.054, 0.054), rings=6, sides=16,
			shape=lambda u, t=tilt: _lens(u, t))
	bridge = HEAD_C + Vector((0, -0.19, GOGGLE_Z + 0.02))
	loft(parts, [bridge + Vector((-0.03, 0, 0)), bridge + Vector((0.03, 0, 0))], [(0.016, 0.016), (0.016, 0.016)],
		sides=8, samples=1, side_ref=(0, 0, 1))
	strap.merge(parts).merge(glass)
	strap.fixed_weights = [{"Head": 1.0}] * len(strap.verts)
	return strap


def _lens(u, tilt):
	"""Flattened dome facing along tilt."""
	d = u.dot(tilt)
	flat = u - tilt * d
	return flat + tilt * (d * 0.32)


# --- Scarf -------------------------------------------------------------------------------------

def scarf_chain():
	"""Scarf tail bone joints from the back of the neck down: SCARF_BONES + 1 points."""
	top = Vector((0.07, 0.15, 1.31))
	n = P.SCARF_BONES
	pts = []
	for i in range(n + 1):
		t = i / n
		# Hangs down his back, swinging out behind the coat tails.
		pts.append(top + Vector((0.04 * t + 0.02 * math.sin(t * 5.0), 0.05 + 0.1 * t ** 1.2, -P.SCARF_LENGTH * t)))
	return pts


def build_scarf():
	"""A thick wrap round the neck, a long tail down the back and a short end on his chest."""
	wrap = Part("scarf", "scarf")
	ring = []
	for k in range(20):
		a = 2 * math.pi * k / 20
		ring.append(Vector((math.sin(a) * 0.13, -math.cos(a) * 0.12 + 0.012, 1.33 - 0.02 * math.cos(a))))
	loft(wrap, ring, [(0.06, 0.05)], sides=10, samples=2, side_ref=(0, 0, 1), closed=True)
	n_wrap = len(wrap.verts)
	weights = [{"UpperChest": 0.5, "Neck": 0.5}] * n_wrap
	# Short end on his left chest.
	end = Part("scarf_end", "scarf")
	top = Vector((0.08, -0.15, 1.3))
	loft(end, [top, top + Vector((0.03, -0.05, -0.1)), top + Vector((0.05, -0.06, -0.2))],
		[(0.06, 0.018), (0.065, 0.018), (0.07, 0.018)], sides=8, samples=2, side_ref=(1, 0, 0))
	wrap.merge(end)
	weights += [{"UpperChest": 1.0}] * len(end.verts)
	# Long tail weighted along the chain.
	chain = scarf_chain()
	tail = Part("scarf_tail", "scarf")
	path = [chain[0] + Vector((0, -0.04, 0.02))] + chain[1:]
	radii = [(0.08, 0.022)] + [(0.095 + 0.015 * i / len(chain), 0.022) for i in range(1, len(chain))]
	loft(tail, path, radii, sides=8, samples=3, side_ref=(1, 0, 0))
	for v in tail.verts:
		weights.append(_chain_weights(v, chain))
	wrap.merge(tail)
	wrap.fixed_weights = weights
	return wrap


def _chain_weights(v, chain):
	"""Blend between the two nearest scarf bones by the vertex's position along the tail."""
	best, best_d = 0.0, 1e9
	for i in range(len(chain) - 1):
		a, b = chain[i], chain[i + 1]
		ab = b - a
		t = max(0.0, min(1.0, (v - a).dot(ab) / ab.length_squared))
		d = (a + ab * t - v).length
		if d < best_d:
			best, best_d = i + t, d
	if best < 0.35:
		k = best / 0.35
		return {"UpperChest": 1.0 - k, "Scarf1": k} if k > 0.02 else {"UpperChest": 1.0}
	i = min(int(best - 0.5), len(chain) - 3) if best > 0.5 else 0
	t = max(0.0, min(1.0, best - 0.5 - i))
	a, b = "Scarf%d" % (i + 1), "Scarf%d" % (i + 2)
	return {a: 1.0 - t, b: t}


# --- Shared mesh helpers -----------------------------------------------------------------------

def boundary_loops(part):
	"""Closed loops of boundary edges, as ordered vertex index lists."""
	count = {}
	for f in part.faces:
		for k in range(len(f)):
			key = tuple(sorted((f[k], f[(k + 1) % len(f)])))
			count[key] = count.get(key, 0) + 1
	nbrs = {}
	for (a, b), c in count.items():
		if c == 1:
			nbrs.setdefault(a, []).append(b)
			nbrs.setdefault(b, []).append(a)
	loops, seen = [], set()
	for start in sorted(nbrs):
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


def _cut(part, is_open):
	"""Deletes faces whose centre is open, then drops unused vertices."""
	keep = [f for f in part.faces if not is_open(sum((part.verts[i] for i in f), Vector()) / len(f))]
	used = sorted({i for f in keep for i in f})
	remap = {old: new for new, old in enumerate(used)}
	part.verts = [part.verts[i] for i in used]
	part.faces = [[remap[i] for i in f] for f in keep]


def build_all():
	parts = []
	for sign in (1, -1):
		parts.append(build_sleeve(sign))
		parts.extend(build_gauntlet(sign))
		parts.append(build_pauldron(sign))
	tunic, neck = build_tunic()
	coat = build_coat()
	belt, buckle = build_belt()
	parts += [tunic, neck, coat, build_coat_trim(coat), belt, buckle, build_pants(), build_boots()]
	parts += [build_head(), build_hair(), build_goggles(), build_scarf()]
	return parts
