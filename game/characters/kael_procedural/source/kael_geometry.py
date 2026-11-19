"""Small geometry toolkit: lofted tubes, closed rings and tapered spikes as vertex/face lists.

Everything is plain Python plus mathutils, so the shapes stay readable and tweakable.
"""

import math

from mathutils import Vector


class Part:
	"""A mesh piece: vertices, quad/tri faces, a material slot and the bones allowed to move it."""

	def __init__(self, name, material, bones=None):
		self.name = name
		self.material = material
		self.bones = bones  # None = any bone; else a list of allowed bone names.
		self.verts = []
		self.faces = []
		self.uvs = {}  # Face-corner UVs: face index -> list of (u, v).
		self.fixed_weights = None  # Optional per-vertex dict {bone: weight}.

	def add_vert(self, co):
		self.verts.append(Vector(co))
		return len(self.verts) - 1

	def merge(self, other):
		offset = len(self.verts)
		self.verts.extend(other.verts)
		for f in other.faces:
			self.faces.append([i + offset for i in f])
		if other.fixed_weights is not None or self.fixed_weights is not None:
			mine = self.fixed_weights or [None] * offset
			theirs = other.fixed_weights or [None] * len(other.verts)
			self.fixed_weights = mine + theirs
		return self


def catmull(points, samples):
	"""Resamples a polyline through its points with a Catmull-Rom spline."""
	if len(points) < 3:
		out = []
		for i in range(len(points) - 1):
			for s in range(samples):
				out.append(points[i].lerp(points[i + 1], s / samples))
		out.append(points[-1])
		return out
	pts = [points[0] * 2 - points[1]] + list(points) + [points[-1] * 2 - points[-2]]
	out = []
	for i in range(1, len(pts) - 2):
		p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
		for s in range(samples):
			t = s / samples
			t2, t3 = t * t, t * t * t
			out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
				+ (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
	out.append(points[-1].copy())
	return out


def _lerp_list(values, samples):
	out = []
	for i in range(len(values) - 1):
		a, b = values[i], values[i + 1]
		for s in range(samples):
			t = s / samples
			t = t * t * (3 - 2 * t)
			out.append(tuple(x + (y - x) * t for x, y in zip(a, b)))
	out.append(tuple(values[-1]))
	return out


def loft(part, path, radii, sides=12, samples=3, side_ref=(1, 0, 0), cap_start=True, cap_end=True,
		squareness=None, offsets=None, radial=None, closed=False):
	"""Sweeps elliptical rings along a path and appends them to part.

	radii: per path point (rx, ry); rx lies along side_ref (made perpendicular), ry along the third axis.
	squareness: optional per-point exponent (2 = ellipse, higher = boxier).
	offsets: optional per-point (dx_side, dy_front) shift of the ring centre.
	radial: optional f(ring_t, angle, point) -> radius multiplier, for folds and wraps.
	closed: the path is a loop (no caps), e.g. a trim around an opening.
	Returns the list of ring vertex index lists.
	"""
	path = [Vector(p) for p in path]
	n = len(path)
	sq = squareness or [2.0] * n
	off = offsets or [(0.0, 0.0)] * n
	if closed:
		pts = catmull(path + path[:3], samples)[samples: -samples * 2] if n > 3 else path
		rad = [radii[0]] * len(pts)
		sqs = [sq[0]] * len(pts)
		offs = [off[0]] * len(pts)
	else:
		pts = catmull(path, samples)
		rad = _lerp_list(radii, samples)
		sqs = [s[0] for s in _lerp_list([(s,) for s in sq], samples)]
		offs = _lerp_list(off, samples)
	ref = Vector(side_ref).normalized()
	rings = []
	count = len(pts)
	prev_side = None
	for i, p in enumerate(pts):
		if closed:
			tangent = (pts[(i + 1) % count] - pts[i - 1]).normalized()
		elif i == 0:
			tangent = (pts[1] - pts[0]).normalized()
		elif i == count - 1:
			tangent = (pts[-1] - pts[-2]).normalized()
		else:
			tangent = (pts[i + 1] - pts[i - 1]).normalized()
		base = prev_side if prev_side is not None else ref
		side = (base - tangent * base.dot(tangent))
		if side.length < 1e-5:
			side = Vector((0, 0, 1)).cross(tangent)
		side.normalize()
		prev_side = side if closed else None
		front = tangent.cross(side).normalized()
		rx, ry = rad[i]
		e = sqs[i]
		centre = p + side * offs[i][0] + front * offs[i][1]
		ring = []
		t = i / max(count - 1, 1)
		for k in range(sides):
			a = 2 * math.pi * k / sides
			c, s = math.cos(a), math.sin(a)
			# Superellipse: boxier sections for the chest and boots.
			cx = math.copysign(abs(c) ** (2.0 / e), c)
			sy = math.copysign(abs(s) ** (2.0 / e), s)
			m = radial(t, a, p) if radial else 1.0
			ring.append(part.add_vert(centre + side * (cx * rx * m) + front * (sy * ry * m)))
		rings.append(ring)
	for i in range(len(rings) - (0 if closed else 1)):
		r0, r1 = rings[i], rings[(i + 1) % len(rings)]
		for k in range(sides):
			k1 = (k + 1) % sides
			part.faces.append([r0[k], r0[k1], r1[k1], r1[k]])
	if not closed:
		if cap_start:
			_cap(part, rings[0], pts[0] - (pts[1] - pts[0]).normalized() * min(rad[0]) * 0.55, flip=True)
		if cap_end:
			_cap(part, rings[-1], pts[-1] + (pts[-1] - pts[-2]).normalized() * min(rad[-1]) * 0.55, flip=False)
	return rings


def _cap(part, ring, tip, flip):
	"""Rounded cap: one shrunken ring, then a fan to the tip."""
	centre = sum((part.verts[i] for i in ring), Vector()) / len(ring)
	inner = []
	for i in ring:
		v = part.verts[i]
		inner.append(part.add_vert(centre.lerp(v, 0.62).lerp(tip, 0.45)))
	sides = len(ring)
	for k in range(sides):
		k1 = (k + 1) % sides
		f = [ring[k], ring[k1], inner[k1], inner[k]]
		part.faces.append(f[::-1] if flip else f)
	t = part.add_vert(tip)
	for k in range(sides):
		k1 = (k + 1) % sides
		f = [inner[k], inner[k1], t]
		part.faces.append(f[::-1] if flip else f)


def spike(part, base, direction, up_hint, length, radius, bend, flat=0.65, sides=6, rings=6, twist=0.0):
	"""A tapered, bent cone from base along direction; bend curls the tip toward up_hint.

	Returns the vertex indices with their distance-along fraction, for weighting.
	"""
	d = Vector(direction).normalized()
	u = Vector(up_hint)
	u = (u - d * u.dot(d)).normalized()
	side = d.cross(u).normalized()
	mid = base + d * (length * 0.5) + u * (length * bend * 0.5)
	tip = base + d * length + u * (length * bend)
	out = []
	ring_ids = []
	for r in range(rings):
		t = r / rings
		# Quadratic Bezier centre line.
		p = base * (1 - t) ** 2 + mid * (2 * (1 - t) * t) + tip * t * t
		tangent = ((mid - base) * (2 * (1 - t)) + (tip - mid) * (2 * t)).normalized()
		s = (side - tangent * side.dot(tangent)).normalized()
		f = tangent.cross(s).normalized()
		rad = radius * (1 - t) ** 0.9
		ring = []
		for k in range(sides):
			a = 2 * math.pi * k / sides + twist
			ring.append(part.add_vert(p + s * (math.cos(a) * rad) + f * (math.sin(a) * rad * flat)))
			out.append((ring[-1], t))
		ring_ids.append(ring)
	tip_id = part.add_vert(tip)
	out.append((tip_id, 1.0))
	for r in range(rings - 1):
		for k in range(sides):
			k1 = (k + 1) % sides
			part.faces.append([ring_ids[r][k], ring_ids[r][k1], ring_ids[r + 1][k1], ring_ids[r + 1][k]])
	for k in range(sides):
		k1 = (k + 1) % sides
		part.faces.append([ring_ids[-1][k], ring_ids[-1][k1], tip_id])
	# Close the base so the outline hull has no hole.
	centre = part.add_vert(base - d * radius * 0.3)
	out.append((centre, 0.0))
	for k in range(sides):
		k1 = (k + 1) % sides
		part.faces.append([ring_ids[0][k1], ring_ids[0][k], centre])
	return out


def ellipsoid(part, centre, radii, rings=10, sides=16, shape=None):
	"""A UV ellipsoid; shape(x, y, z) -> Vector may deform each unit-sphere point first."""
	c = Vector(centre)
	top = part.add_vert(c + _shaped(shape, Vector((0, 0, 1)), radii))
	ids = []
	for r in range(1, rings):
		phi = math.pi * r / rings
		row = []
		for k in range(sides):
			th = 2 * math.pi * k / sides
			unit = Vector((math.sin(phi) * math.sin(th), -math.sin(phi) * math.cos(th), math.cos(phi)))
			row.append(part.add_vert(c + _shaped(shape, unit, radii)))
		ids.append(row)
	bottom = part.add_vert(c + _shaped(shape, Vector((0, 0, -1)), radii))
	for k in range(sides):
		k1 = (k + 1) % sides
		part.faces.append([top, ids[0][k1], ids[0][k]])
		part.faces.append([bottom, ids[-1][k], ids[-1][k1]])
	for r in range(len(ids) - 1):
		for k in range(sides):
			k1 = (k + 1) % sides
			part.faces.append([ids[r][k], ids[r][k1], ids[r + 1][k1], ids[r + 1][k]])
	return ids


def _shaped(shape, unit, radii):
	p = shape(unit) if shape else unit
	return Vector((p.x * radii[0], p.y * radii[1], p.z * radii[2]))
