class_name VoxelSdf
extends RefCounted
## Signed-distance helpers for building voxel parts (approximate where noted;
## voxel fills only use the sign).


static func sphere(p: Vector3, c: Vector3, r: float) -> float:
	return p.distance_to(c) - r


## Approximate: exact on the axes, sign-correct everywhere.
static func ellipsoid(p: Vector3, c: Vector3, r: Vector3) -> float:
	return (((p - c) / r).length() - 1.0) * minf(r.x, minf(r.y, r.z))


## Segment a->b with a radius tapering ra -> rb.
static func capsule(p: Vector3, a: Vector3, b: Vector3, ra: float, rb: float) -> float:
	var ab := b - a
	var h := clampf((p - a).dot(ab) / ab.dot(ab), 0.0, 1.0)
	return p.distance_to(a + ab * h) - lerpf(ra, rb, h)


## Box of half extents, edges rounded by r.
static func box(p: Vector3, c: Vector3, half: Vector3, r := 0.0) -> float:
	var q := (p - c).abs() - half + Vector3(r, r, r)
	return Vector3(maxf(q.x, 0.0), maxf(q.y, 0.0), maxf(q.z, 0.0)).length() \
		+ minf(maxf(q.x, maxf(q.y, q.z)), 0.0) - r


## Flat-capped cylinder a->b with a radius tapering ra -> rb.
static func cylinder(p: Vector3, a: Vector3, b: Vector3, ra: float, rb: float) -> float:
	var ab := b - a
	var length := ab.length()
	var axis := ab / length
	var t := (p - a).dot(axis)
	var radial := ((p - a) - axis * t).length() - lerpf(ra, rb, clampf(t / length, 0.0, 1.0))
	var along := absf(t - length * 0.5) - length * 0.5
	return minf(maxf(radial, along), 0.0) + Vector2(maxf(radial, 0.0), maxf(along, 0.0)).length()


## Torus around axis through c.
static func torus(p: Vector3, c: Vector3, axis: Vector3, major: float, minor: float) -> float:
	var q := p - c
	var h := q.dot(axis)
	var radial := (q - axis * h).length() - major
	return Vector2(radial, h).length() - minor


## Superellipse slice distance in xz (approximate): e = 2 is an ellipse,
## higher is boxier.
static func slice(dx: float, dz: float, rx: float, rz: float, e := 2.0) -> float:
	var v := pow(pow(absf(dx) / rx, e) + pow(absf(dz) / rz, e), 1.0 / e)
	return (v - 1.0) * minf(rx, rz)


static func smooth_union(a: float, b: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)


## A hash in [0, 1) per integer cell (stable across runs).
static func hash3(c: Vector3i, salt := 0) -> float:
	var h := (c.x * 73856093) ^ (c.y * 19349663) ^ (c.z * 83492791) ^ (salt * 2654435761)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777216.0
