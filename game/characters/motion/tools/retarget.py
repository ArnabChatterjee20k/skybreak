"""Retargets BVH joint positions onto Kael's humanoid skeleton.

Each driven bone is rotated so its direction to the next joint, and a second reference axis (body
left for the torso, the limb's bend normal for arms and legs), match the source. Working from
positions makes rest-pose, axis and joint-orient differences between rigs irrelevant.
"""

import numpy as np

# Semantic points: source joint names per rig.
POINTS = {
	"cmu": {
		"pelvis": "Hips", "spine": "Spine", "chest": "Spine1", "neck": "Neck1", "head": "Head",
		"head_top": "Head_end",
		"l_hip": "LeftUpLeg", "l_knee": "LeftLeg", "l_ankle": "LeftFoot", "l_ball": "LeftToeBase",
		"l_toe": "LeftToeBase_end",
		"r_hip": "RightUpLeg", "r_knee": "RightLeg", "r_ankle": "RightFoot", "r_ball": "RightToeBase",
		"r_toe": "RightToeBase_end",
		"l_clav": "LeftShoulder", "l_shoulder": "LeftArm", "l_elbow": "LeftForeArm", "l_wrist": "LeftHand",
		"l_finger": "LeftHandIndex1",
		"r_clav": "RightShoulder", "r_shoulder": "RightArm", "r_elbow": "RightForeArm", "r_wrist": "RightHand",
		"r_finger": "RightHandIndex1",
	},
	"bandai": {
		"pelvis": "Hips", "spine": "Spine", "chest": "Chest", "neck": "Neck", "head": "Head",
		"head_top": "Head_end",
		"l_hip": "UpperLeg_L", "l_knee": "LowerLeg_L", "l_ankle": "Foot_L", "l_ball": "Toes_L",
		"l_toe": "Toes_L_end",
		"r_hip": "UpperLeg_R", "r_knee": "LowerLeg_R", "r_ankle": "Foot_R", "r_ball": "Toes_R",
		"r_toe": "Toes_R_end",
		"l_clav": "Shoulder_L", "l_shoulder": "UpperArm_L", "l_elbow": "LowerArm_L", "l_wrist": "Hand_L",
		"l_finger": "Hand_L_end",
		"r_clav": "Shoulder_R", "r_shoulder": "UpperArm_R", "r_elbow": "LowerArm_R", "r_wrist": "Hand_R",
		"r_finger": "Hand_R_end",
	},
}

# Target bone -> (from point, to point, reference): the bone points from -> to.
DRIVEN = {
	"Hips": ("pelvis", "spine", "hips_left"),
	"Spine": ("spine", "chest", "waist_left"),
	"Chest": ("chest", "neck", "shoulder_left"),
	"UpperChest": ("chest", "neck", "shoulder_left"),
	"Neck": ("neck", "head", "shoulder_left"),
	"Head": ("head", "head_top", "shoulder_left"),
}
for s in "lr":
	side = "Left" if s == "l" else "Right"
	DRIVEN.update({
		side + "Shoulder": (s + "_clav", s + "_shoulder", "up"),
		side + "UpperArm": (s + "_shoulder", s + "_elbow", s + "_arm_normal"),
		side + "LowerArm": (s + "_elbow", s + "_wrist", s + "_arm_normal"),
		side + "Hand": (s + "_wrist", s + "_finger", s + "_arm_normal"),
		side + "UpperLeg": (s + "_hip", s + "_knee", s + "_leg_normal"),
		side + "LowerLeg": (s + "_knee", s + "_ankle", s + "_leg_normal"),
		side + "Foot": (s + "_ankle", s + "_ball", s + "_leg_normal"),
		side + "Toes": (s + "_ball", s + "_toe", s + "_leg_normal"),
	})

# Where each semantic point sits on Kael's skeleton (bone heads; *_end = an offset from a bone).
TARGET_POINTS = {
	"pelvis": "Hips", "spine": "Spine", "chest": "Chest", "neck": "Neck", "head": "Head",
	"head_top": ("Head", (0, 0.25, 0)),
	"l_hip": "LeftUpperLeg", "l_knee": "LeftLowerLeg", "l_ankle": "LeftFoot", "l_ball": "LeftToes",
	"l_toe": ("LeftToes", (0, 0.08, 0)),
	"r_hip": "RightUpperLeg", "r_knee": "RightLowerLeg", "r_ankle": "RightFoot", "r_ball": "RightToes",
	"r_toe": ("RightToes", (0, 0.08, 0)),
	"l_clav": "LeftShoulder", "l_shoulder": "LeftUpperArm", "l_elbow": "LeftLowerArm", "l_wrist": "LeftHand",
	"l_finger": "LeftMiddleProximal",
	"r_clav": "RightShoulder", "r_shoulder": "RightUpperArm", "r_elbow": "RightLowerArm", "r_wrist": "RightHand",
	"r_finger": "RightMiddleProximal",
}

MIRROR_SWAP = {"l_": "r_", "r_": "l_"}


def normalize(v):
	n = np.linalg.norm(v, axis=-1, keepdims=True)
	return v / np.maximum(n, 1e-9)


def frame(direction, ref):
	"""Rotation matrices (..., 3, 3) whose columns are the bone axis, the reference and their cross."""
	x = normalize(direction)
	y = ref - np.sum(ref * x, axis=-1, keepdims=True) * x
	y = normalize(y)
	z = np.cross(x, y)
	return np.stack([x, y, z], axis=-1)


def references(p):
	"""Reference axes from semantic points (each (F, 3) or (3,))."""
	hips_left = normalize(p["l_hip"] - p["r_hip"])
	shoulder_left = normalize(p["l_shoulder"] - p["r_shoulder"])
	left = normalize(hips_left + shoulder_left)
	up = normalize(p["neck"] - p["pelvis"])
	fwd = normalize(np.cross(left, up))
	refs = {"hips_left": hips_left, "shoulder_left": shoulder_left,
		"waist_left": normalize(hips_left * 0.6 + shoulder_left * 0.4), "up": up, "fwd": fwd, "left": left}
	for s in "lr":
		upper = normalize(p[s + "_elbow"] - p[s + "_shoulder"])
		lower = normalize(p[s + "_wrist"] - p[s + "_elbow"])
		refs[s + "_arm_normal"] = normalize(np.cross(upper, lower + 0.35 * fwd - 0.15 * up))
		thigh = normalize(p[s + "_knee"] - p[s + "_hip"])
		shin = normalize(p[s + "_ankle"] - p[s + "_knee"])
		refs[s + "_leg_normal"] = normalize(np.cross(thigh, shin - 0.35 * fwd))
	return refs


def source_points(bvh, rig, scale_to_m):
	"""Semantic points (F, 3) in metres, Y up, from a BVH."""
	world = bvh.world_positions() * scale_to_m
	p = {k: world[:, bvh.index(v)] for k, v in POINTS[rig].items()}
	# Zero-length end sites (Bandai): extend the parent bone instead.
	for end, base, parent, k in [("head_top", "head", "neck", 1.6)] + [(s + e, s + b, s + q, f) for s in "lr"
			for e, b, q, f in [("_finger", "_wrist", "_elbow", 0.45), ("_toe", "_ball", "_ankle", 0.5)]]:
		short = np.linalg.norm(p[end] - p[base], axis=-1) < 1e-4
		if np.any(short):
			p[end] = np.where(short[:, None], p[base] + (p[base] - p[parent]) * k, p[end])
	return p


def mirror(points):
	out = {}
	for k, v in points.items():
		key = MIRROR_SWAP[k[:2]] + k[2:] if k[:2] in MIRROR_SWAP else k
		m = v.copy()
		m[..., 0] *= -1
		out[key] = m
	return out


def rotate_y(points, yaw):
	c, s = np.cos(yaw), np.sin(yaw)
	r = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
	return {k: v @ r.T for k, v in points.items()}


class Skeleton:
	"""Kael's skeleton from export_rig.gd: rest locals, FK and quaternion helpers."""

	def __init__(self, rig):
		self.names = [b["name"] for b in rig["bones"]]
		self.parents = [b["parent"] for b in rig["bones"]]
		self.rest_pos = np.array([b["position"] for b in rig["bones"]])
		self.rest_rot = np.array([quat_to_matrix(np.array(b["rotation"])) for b in rig["bones"]])
		self.fingers = {k: quat_to_matrix(np.array(v)) for k, v in rig["fingers"].items()}
		self.index = {n: i for i, n in enumerate(self.names)}
		rot, pos = self.fk(self.rest_rot[None], self.rest_pos[1][None])
		self.rest_world_rot = rot[0]
		self.rest_world_pos = pos[0]

	def fk(self, local_rot, hips_pos):
		"""local_rot (F, B, 3, 3), hips_pos (F, 3) -> world rotations and positions."""
		n_frames = local_rot.shape[0]
		rot = np.zeros_like(local_rot)
		pos = np.zeros((n_frames, len(self.names), 3))
		for b, parent in enumerate(self.parents):
			offset = hips_pos if self.names[b] == "Hips" else np.tile(self.rest_pos[b], (n_frames, 1))
			if parent < 0:
				rot[:, b] = local_rot[:, b]
				pos[:, b] = offset
			else:
				rot[:, b] = rot[:, parent] @ local_rot[:, b]
				pos[:, b] = pos[:, parent] + np.einsum("fij,fj->fi", rot[:, parent], offset)
		return rot, pos

	def point(self, world_rot, world_pos, spec):
		if isinstance(spec, tuple):
			b = self.index[spec[0]]
			return world_pos[..., b, :] + np.einsum("...ij,j->...i", world_rot[..., b, :, :], np.array(spec[1]))
		return world_pos[..., self.index[spec], :]

	def rest_points(self):
		return {k: self.point(self.rest_world_rot, self.rest_world_pos, v) for k, v in TARGET_POINTS.items()}


def retarget(skel, points, ankle_lift=0.0):
	"""Source semantic points (metres, facing +Z) -> Kael local rotations (F, B, 3, 3) and hips (F, 3)."""
	n_frames = points["pelvis"].shape[0]
	rest_p = skel.rest_points()
	rest_ref = references(rest_p)
	src_ref = references(points)
	world = np.tile(skel.rest_world_rot, (n_frames, 1, 1, 1))
	# Bones in parent order: driven bones get a world rotation, the rest follow their parent.
	local = np.tile(skel.rest_rot, (n_frames, 1, 1, 1))
	for name, m in skel.fingers.items():
		local[:, skel.index[name]] = m
	for b, name in enumerate(skel.names):
		parent = skel.parents[b]
		if name in DRIVEN:
			a, c, ref = DRIVEN[name]
			f_src = frame(points[c] - points[a], src_ref[ref])
			f_rest = frame(rest_p[c] - rest_p[a], rest_ref[ref])
			delta = f_src @ np.swapaxes(f_rest, -1, -2)
			world[:, b] = delta @ skel.rest_world_rot[b]
			if parent >= 0:
				local[:, b] = np.swapaxes(world[:, parent], -1, -2) @ world[:, b]
			else:
				local[:, b] = world[:, b]
		elif parent >= 0:
			world[:, b] = world[:, parent] @ local[:, b]
	# Hips height scaled by leg length.
	src_leg = np.median(np.linalg.norm(points["l_knee"] - points["l_hip"], axis=-1)
		+ np.linalg.norm(points["l_ankle"] - points["l_knee"], axis=-1))
	dst_leg = np.linalg.norm(rest_p["l_knee"] - rest_p["l_hip"]) + np.linalg.norm(rest_p["l_ankle"] - rest_p["l_knee"])
	scale = dst_leg / src_leg
	hips = points["pelvis"] * scale
	return local, hips, scale


# --- Quaternions ([x, y, z, w], Godot order) -----------------------------------------------------

def quat_to_matrix(q):
	x, y, z, w = q
	return np.array([
		[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
		[2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
		[2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
	])


def matrix_to_quat(m):
	"""(..., 3, 3) -> (..., 4) [x, y, z, w]."""
	m = np.asarray(m)
	shape = m.shape[:-2]
	m = m.reshape(-1, 3, 3)
	q = np.zeros((m.shape[0], 4))
	for i, r in enumerate(m):
		t = r[0, 0] + r[1, 1] + r[2, 2]
		if t > 0:
			s = np.sqrt(t + 1.0) * 2
			q[i] = [(r[2, 1] - r[1, 2]) / s, (r[0, 2] - r[2, 0]) / s, (r[1, 0] - r[0, 1]) / s, 0.25 * s]
		elif r[0, 0] > r[1, 1] and r[0, 0] > r[2, 2]:
			s = np.sqrt(1.0 + r[0, 0] - r[1, 1] - r[2, 2]) * 2
			q[i] = [0.25 * s, (r[0, 1] + r[1, 0]) / s, (r[0, 2] + r[2, 0]) / s, (r[2, 1] - r[1, 2]) / s]
		elif r[1, 1] > r[2, 2]:
			s = np.sqrt(1.0 + r[1, 1] - r[0, 0] - r[2, 2]) * 2
			q[i] = [(r[0, 1] + r[1, 0]) / s, 0.25 * s, (r[1, 2] + r[2, 1]) / s, (r[0, 2] - r[2, 0]) / s]
		else:
			s = np.sqrt(1.0 + r[2, 2] - r[0, 0] - r[1, 1]) * 2
			q[i] = [(r[0, 2] + r[2, 0]) / s, (r[1, 2] + r[2, 1]) / s, 0.25 * s, (r[1, 0] - r[0, 1]) / s]
	q /= np.linalg.norm(q, axis=-1, keepdims=True)
	return q.reshape(shape + (4,))


def rotvec_to_matrix(v):
	"""Axis-angle vectors (..., 3) -> matrices (Rodrigues)."""
	theta = np.linalg.norm(v, axis=-1, keepdims=True)
	k = v / np.maximum(theta, 1e-12)
	kx, ky, kz = k[..., 0], k[..., 1], k[..., 2]
	zero = np.zeros_like(kx)
	K = np.stack([np.stack([zero, -kz, ky], -1), np.stack([kz, zero, -kx], -1), np.stack([-ky, kx, zero], -1)], -2)
	t = theta[..., None]
	eye = np.broadcast_to(np.eye(3), K.shape)
	return eye + np.sin(t) * K + (1 - np.cos(t)) * (K @ K)


def matrix_to_rotvec(m):
	cos = np.clip((np.trace(m, axis1=-2, axis2=-1) - 1) / 2, -1, 1)
	theta = np.arccos(cos)
	w = np.stack([m[..., 2, 1] - m[..., 1, 2], m[..., 0, 2] - m[..., 2, 0], m[..., 1, 0] - m[..., 0, 1]], -1)
	s = np.sin(theta)[..., None]
	small = s < 1e-6
	axis = np.where(small, w / 2, w / np.maximum(2 * s, 1e-12) * theta[..., None])
	# Near pi: fall back on the diagonal.
	near_pi = (theta > np.pi - 1e-3)[..., None]
	if np.any(near_pi):
		d = np.sqrt(np.maximum((np.diagonal(m, axis1=-2, axis2=-1) + 1) / 2, 0))
		axis = np.where(near_pi, d * np.pi, axis)
	return axis
