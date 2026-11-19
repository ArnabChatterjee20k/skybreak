"""Pose maths for authoring clips in code: joint helpers, forward kinematics, two-bone IK.

Conventions (Blender armature space, +Z up, the character faces -Y, his left is +X):
- Every bone rotation is a "delta" D, an armature-space rotation applied in the parent's posed frame,
  so the posed orientation of a bone is D_root @ ... @ D_parent @ D_bone @ Rest_bone.
- Side bones are authored with left-side meaning; Right* bones are mirrored automatically.
- Positions for IK targets are absolute armature-space points (metres).
"""

import math

from mathutils import Matrix, Quaternion, Vector

ID = Quaternion()


def _rx(deg):
	return Quaternion((1, 0, 0), math.radians(deg))


def _ry(deg):
	return Quaternion((0, 1, 0), math.radians(deg))


def _rz(deg):
	return Quaternion((0, 0, 1), math.radians(deg))


# Joint helpers. All angles in degrees, all with left-side meaning.

def spine(fwd=0.0, side=0.0, turn=0.0):
	"""Bend forward (+), lean to his left (+), turn to his left (+)."""
	return _rz(turn) @ _ry(side) @ _rx(fwd)


def arm(down=0.0, fwd=0.0, twist=0.0, back=0.0):
	"""Upper arm from the T-pose: lower it (+down), then swing it forward (+fwd); back swings it behind."""
	return _rx(-fwd + back) @ _ry(down) @ _rx(twist)


def reach(fwd=0.0, down=0.0, twist=0.0):
	"""Upper arm pointing forward first (fwd = 90 points straight ahead), then down (+) or up (-)."""
	return _rx(down) @ _rz(-fwd) @ _rx(twist)


def elbow(bend):
	"""Forearm bend toward the front of the arm."""
	return _rz(-bend)


def wrist(up=0.0, side=0.0):
	return _rz(-side) @ _ry(-up)


def leg(fwd=0.0, out=0.0, twist=0.0):
	"""Upper leg: raise forward (+), spread outward (+), turn the knee outward (+)."""
	return _rz(twist) @ _ry(-out) @ _rx(-fwd)


def knee(bend):
	return _rx(bend)


def foot(up=0.0):
	"""Ankle: toes up (+) or pointed (-)."""
	return _rx(-up)


def fist(k=1.0):
	"""Finger and thumb curls for a clenched fist (k = 1) or a relaxed hand (k ~ 0.3)."""
	out = {}
	for f in ("Index", "Middle", "Ring", "Little"):
		out["Left%sProximal" % f] = _ry(85 * k)
		out["Left%sIntermediate" % f] = _ry(100 * k)
		out["Left%sDistal" % f] = _ry(70 * k)
	out["LeftThumbMetacarpal"] = _rz(-25 * k) @ _rx(-20 * k)
	out["LeftThumbProximal"] = _ry(35 * k) @ _rz(-30 * k)
	out["LeftThumbDistal"] = _ry(45 * k)
	return out


def open_hand(spread=0.0):
	out = {}
	for i, f in enumerate(("Index", "Middle", "Ring", "Little")):
		out["Left%sProximal" % f] = _rz((i - 1.5) * spread) @ _ry(8)
		out["Left%sIntermediate" % f] = _ry(10)
		out["Left%sDistal" % f] = _ry(6)
	out["LeftThumbMetacarpal"] = _rz(-10)
	return out


def mirror(q):
	"""Left-side rotation -> the same motion on the right side (mirror across the x = 0 plane)."""
	return Quaternion((q.w, q.x, -q.y, -q.z))


class Pose:
	"""A key pose: rotations (left-side meaning for side bones), IK goals, hips offset and smear scales.

	ik: {"LeftHand"|"RightHand"|"LeftFoot"|"RightFoot": (target, pole[, foot yaw deg, foot pitch deg])}
	"""

	def __init__(self, rot=None, ik=None, hips=(0, 0, 0), scale=None):
		self.rot = dict(rot or {})
		self.ik = dict(ik or {})
		self.hips = Vector(hips)
		self.scale = dict(scale or {})

	def but(self, rot=None, ik=None, hips=None, scale=None, drop_ik=()):
		p = Pose(self.rot, self.ik, self.hips, self.scale)
		p.rot.update(rot or {})
		p.ik.update(ik or {})
		for k in drop_ik:
			p.ik.pop(k, None)
		if hips is not None:
			p.hips = Vector(hips)
		if scale is not None:
			p.scale = dict(scale)
		return p

	def shifted(self, dx=0.0, dy=0.0, dz=0.0):
		"""Same pose with the hips moved; foot goals stay where they are."""
		return self.but(hips=self.hips + Vector((dx, dy, dz)))


class Rig:
	"""Rest data of the armature plus FK and IK in the D convention."""

	def __init__(self, layout):
		self.order = [name for name, _, _, _ in layout]
		self.parent = {name: parent for name, parent, _, _ in layout}
		self.head = {name: Vector(h) for name, _, h, _ in layout}
		self.tail = {name: Vector(t) for name, _, _, t in layout}

	def actual(self, pose):
		"""Local D rotations in real (unmirrored) terms, IK not yet applied."""
		out = {}
		for name in self.order:
			q = pose.rot.get(name)
			if name.startswith("Right"):
				if q is None:
					q = pose.rot.get("Left" + name[5:])
				q = mirror(q) if q is not None else None
			out[name] = q.copy() if q is not None else ID.copy()
		return out

	def fk(self, local, hips):
		"""World D per bone and posed head positions."""
		world, pos = {}, {}
		for name in self.order:
			parent = self.parent[name]
			if parent is None:
				world[name] = local[name]
				pos[name] = self.head[name].copy()
				continue
			world[name] = world[parent] @ local[name]
			pos[name] = pos[parent] + world[parent] @ (self.head[name] - self.head[parent])
			if name == "Hips":
				pos[name] = pos[name] + hips
		return world, pos

	def point(self, world, pos, bone, rest_point):
		"""Posed position of a rest-space point rigidly attached to bone."""
		return pos[bone] + world[bone] @ (Vector(rest_point) - self.head[bone])

	def solve(self, pose, local=None, ik=None):
		"""Final local D rotations with the IK goals applied."""
		local = local if local is not None else self.actual(pose)
		ik = pose.ik if ik is None else ik
		for end in ("LeftFoot", "RightFoot", "LeftHand", "RightHand"):
			if end not in ik:
				continue
			goal = ik[end]
			side = end[:-4]
			if end.endswith("Hand"):
				upper, lower = side + "UpperArm", side + "LowerArm"
				rest_pole = Vector((0, 1, 0))
			else:
				upper, lower = side + "UpperLeg", side + "LowerLeg"
				rest_pole = Vector((0, -1, 0))
			world, pos = self.fk(local, pose.hips)
			self._two_bone(local, world, pos, upper, lower, end, Vector(goal[0]), Vector(goal[1]), rest_pole)
			if end.endswith("Foot"):
				world, pos = self.fk(local, pose.hips)
				yaw = goal[2] if len(goal) > 2 else 0.0
				pitch = goal[3] if len(goal) > 3 else 0.0
				want = _rz(yaw) @ _rx(-pitch)
				local[end] = world[lower].inverted() @ want
		return local

	def _two_bone(self, local, world, pos, upper, lower, end, target, pole, rest_pole):
		s = pos[upper]
		a = (self.head[lower] - self.head[upper]).length
		b = (self.head[end] - self.head[lower]).length
		to = target - s
		d = max(min(to.length, a + b - 1e-4), abs(a - b) + 1e-4)
		e = to.normalized()
		p = pole - e * pole.dot(e)
		if p.length < 1e-6:
			p = rest_pole - e * rest_pole.dot(e)
		p.normalize()
		cos_a = (a * a + d * d - b * b) / (2 * a * d)
		sin_a = math.sqrt(max(0.0, 1 - cos_a * cos_a))
		joint = s + e * (a * cos_a) + p * (a * sin_a)
		end_pos = s + e * d
		u = (joint - s).normalized()
		v = (end_pos - joint).normalized()
		pu = (p - u * p.dot(u)).normalized()
		n = u.cross(pu).normalized()
		r_u = (self.head[lower] - self.head[upper]).normalized()
		rp = (rest_pole - r_u * rest_pole.dot(r_u)).normalized()
		rn = r_u.cross(rp).normalized()
		r_v = (self.head[end] - self.head[lower]).normalized()
		w_upper = _frame(u, pu, n) @ _frame(r_u, rp, rn).inverted()
		w_lower = _frame(v, n.cross(v), n) @ _frame(r_v, rn.cross(r_v), rn).inverted()
		parent = self.parent[upper]
		local[upper] = world[parent].inverted() @ w_upper.to_quaternion()
		local[lower] = w_upper.to_quaternion().inverted() @ w_lower.to_quaternion()

	def to_bone_space(self, rest_quats, local):
		"""D (armature-aligned) -> Blender pose-bone quaternions: B^-1 D B."""
		return {name: rest_quats[name].inverted() @ q @ rest_quats[name] for name, q in local.items()}


def _frame(x, y, z):
	m = Matrix((x, y, z)).transposed()
	return m


def ease(kind, t):
	if kind == "lin":
		return t
	if kind == "in":
		return t * t
	if kind == "in3":
		return t * t * t
	if kind == "out":
		return 1 - (1 - t) ** 2
	if kind == "out3":
		return 1 - (1 - t) ** 3
	if kind == "io":
		return t * t * (3 - 2 * t)
	if kind == "step":
		return 0.0 if t < 1.0 else 1.0
	if kind == "back":
		# Overshoot then settle.
		c = 1.7
		return 1 + (c + 1) * (t - 1) ** 3 + c * (t - 1) ** 2
	raise ValueError(kind)
