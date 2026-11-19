"""Clean-up on retargeted clips (60 fps): resampling, foot contacts and locking, pelvis drop, root
extraction, loop matching, exaggeration and attack time-warping. Rotations are (F, B, 3, 3) local
matrices on Kael's skeleton; hips is (F, 3) in skeleton space (metres, +Y up, facing +Z)."""

import numpy as np

from retarget import matrix_to_rotvec, normalize, rotvec_to_matrix

FPS = 60
BODY_BONES = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"] + [s + b for s in ("Left", "Right")
	for b in ("Shoulder", "UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot", "Toes")]
LEGS = {"Left": ("LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes"),
	"Right": ("RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes")}


def T(m):
	return np.swapaxes(m, -1, -2)


def interpolate(local, hips, times):
	"""Samples at fractional frame indices (geodesic per bone, linear hips)."""
	times = np.clip(np.asarray(times, float), 0, local.shape[0] - 1)
	i0 = np.floor(times).astype(int)
	i1 = np.minimum(i0 + 1, local.shape[0] - 1)
	t = (times - i0)[:, None, None]
	rel = matrix_to_rotvec(T(local[i0]) @ local[i1])
	out = local[i0] @ rotvec_to_matrix(rel * t)
	h = hips[i0] + (hips[i1] - hips[i0]) * t[:, :, 0]
	return out, h


def resample(local, hips, src_dt, start_s=0.0, end_s=None, speed=1.0):
	"""Source rate -> 60 fps between start_s and end_s (seconds of the source)."""
	duration = (local.shape[0] - 1) * src_dt
	end_s = duration if end_s is None else min(end_s, duration)
	n = int(round((end_s - start_s) * FPS / speed)) + 1
	times = (start_s + np.arange(n) * speed / FPS) / src_dt
	return interpolate(local, hips, times)


def gaussian(x, sigma, axis=0):
	"""Gaussian low-pass along axis with edge padding."""
	if sigma <= 0:
		return x.copy()
	r = int(3 * sigma)
	k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
	k /= k.sum()
	x = np.moveaxis(x, axis, 0)
	pad = np.concatenate([np.repeat(x[:1], r, 0), x, np.repeat(x[-1:], r, 0)], 0)
	out = np.zeros_like(x)
	for j, w in enumerate(k):
		out += w * pad[j:j + x.shape[0]]
	return np.moveaxis(out, 0, axis)


def smooth_rotations(local, sigma):
	"""Low-passed rotations: each frame averaged in its own tangent space."""
	if sigma <= 0:
		return local.copy()
	r = int(3 * sigma)
	n = local.shape[0]
	out = np.empty_like(local)
	weights = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
	for i in range(n):
		idx = np.clip(np.arange(i - r, i + r + 1), 0, n - 1)
		rel = matrix_to_rotvec(T(local[i])[None] @ local[idx])
		mean = np.tensordot(weights / weights.sum(), rel, axes=(0, 0))
		out[i] = local[i] @ rotvec_to_matrix(mean)
	return out


def exaggerate(skel, local, hips, amount, sigma=4.0, pose_amount=0.0):
	"""Anime overshoot and snap: amplifies each rotation's deviation from its low-passed self
	(temporal unsharp mask), and optionally the deviation from the clip's mean pose."""
	if amount <= 0 and pose_amount <= 0:
		return local, hips
	out = local.copy()
	ids = [skel.index[b] for b in BODY_BONES if b != "Hips"]
	smooth = smooth_rotations(local[:, ids], sigma)
	rel = matrix_to_rotvec(T(smooth) @ local[:, ids])
	out[:, ids] = smooth @ rotvec_to_matrix(rel * (1 + amount))
	if pose_amount > 0:
		mean = smooth_rotations(out[:, ids], 60.0)
		rel = matrix_to_rotvec(T(mean) @ out[:, ids])
		out[:, ids] = mean @ rotvec_to_matrix(rel * (1 + pose_amount))
	h_smooth = gaussian(hips, sigma)
	return out, h_smooth + (hips - h_smooth) * (1 + amount * 0.5)


def ground(skel, local, hips, percentile=5.0):
	"""Shifts hips vertically so the planted feet sit at their rest height."""
	rot, pos = skel.fk(local, hips)
	lows = []
	for side in ("Left", "Right"):
		a = pos[:, skel.index[side + "Foot"], 1] - skel.rest_world_pos[skel.index[side + "Foot"], 1]
		b = pos[:, skel.index[side + "Toes"], 1] - skel.rest_world_pos[skel.index[side + "Toes"], 1]
		lows.append(np.minimum(a, b))
	low = np.percentile(np.minimum(*lows), percentile)
	out = hips.copy()
	out[:, 1] -= low
	return out


def foot_contacts(skel, local, hips, height=0.05, speed=0.6, min_frames=4):
	"""Per foot (F,) bool: the ankle or ball is near its rest height and nearly still."""
	rot, pos = skel.fk(local, hips)
	out = {}
	for side in ("Left", "Right"):
		fa, fb = skel.index[side + "Foot"], skel.index[side + "Toes"]
		low = np.minimum(pos[:, fa, 1] - skel.rest_world_pos[fa, 1], pos[:, fb, 1] - skel.rest_world_pos[fb, 1])
		v = np.gradient(pos[:, fa, [0, 2]], axis=0) * FPS
		still = np.linalg.norm(v, axis=-1) < speed
		c = (low < height) & still
		out[side] = _clean_runs(c, min_frames)
	return out


def _clean_runs(c, min_frames):
	c = c.copy()
	n = len(c)
	# Fill short gaps, then drop short runs.
	i = 0
	while i < n:
		if not c[i]:
			j = i
			while j < n and not c[j]:
				j += 1
			if 0 < i and j < n and j - i <= 2:
				c[i:j] = True
			i = j
		else:
			i += 1
	i = 0
	while i < n:
		if c[i]:
			j = i
			while j < n and c[j]:
				j += 1
			if j - i < min_frames:
				c[i:j] = False
			i = j
		else:
			i += 1
	return c


def runs(c):
	out, i, n = [], 0, len(c)
	while i < n:
		if c[i]:
			j = i
			while j < n and c[j]:
				j += 1
			out.append((i, j))
			i = j
		else:
			i += 1
	return out


def _min_rotation(a, b):
	"""(F, 3) unit vectors -> rotations taking a onto b."""
	axis = np.cross(a, b)
	s = np.linalg.norm(axis, axis=-1, keepdims=True)
	c = np.sum(a * b, axis=-1, keepdims=True)
	angle = np.arctan2(s, c)
	return rotvec_to_matrix(axis / np.maximum(s, 1e-12) * angle)


def foot_lock(skel, local, hips, contacts, blend=4):
	"""Pins each planted foot to its mean position over the contact (world space, before root
	extraction) with two-bone IK; drops the pelvis when a leg cannot reach."""
	local = local.copy()
	hips = hips.copy()
	n = local.shape[0]
	rot, pos = skel.fk(local, hips)
	targets, weights = {}, {}
	for side, (up, lo, ft, _) in LEGS.items():
		fa = skel.index[ft]
		target = pos[:, fa].copy()
		w = np.zeros(n)
		for a, b in runs(contacts[side]):
			pin = pos[a:b, fa].mean(0)
			pin[1] = max(pin[1], skel.rest_world_pos[fa, 1])
			target[a:b] = pin
			w[a:b] = 1.0
			for k in range(1, blend + 1):
				f = 1.0 - k / (blend + 1)
				if a - k >= 0 and w[a - k] < f:
					w[a - k] = f
					target[a - k] = pin
				if b - 1 + k < n and w[b - 1 + k] < f:
					w[b - 1 + k] = f
					target[b - 1 + k] = pin
		targets[side] = pos[:, fa] + (target - pos[:, fa]) * w[:, None]
		weights[side] = w
	# Pelvis drop so both legs can reach.
	drop = np.zeros(n)
	for side, (up, lo, ft, _) in LEGS.items():
		h, k, a = skel.index[up], skel.index[lo], skel.index[ft]
		reach = (np.linalg.norm(skel.rest_pos[k]) + np.linalg.norm(skel.rest_pos[a])) * 0.995
		d = targets[side] - pos[:, h]
		horiz = np.linalg.norm(d[:, [0, 2]], axis=-1)
		need = np.sqrt(np.maximum(reach ** 2 - horiz ** 2, 0.0))
		excess = np.maximum(-d[:, 1] - need, 0.0)
		drop = np.maximum(drop, excess * (weights[side] > 0))
	drop = np.maximum(gaussian(drop, 2.0), drop)
	hips[:, 1] -= drop
	rot, pos = skel.fk(local, hips)
	for side, (up, lo, ft, _) in LEGS.items():
		h, k, a = skel.index[up], skel.index[lo], skel.index[ft]
		l1, l2 = np.linalg.norm(skel.rest_pos[k]), np.linalg.norm(skel.rest_pos[a])
		H, K, A = pos[:, h], pos[:, k], pos[:, a]
		tgt = targets[side]
		d_vec = tgt - H
		d = np.clip(np.linalg.norm(d_vec, axis=-1), abs(l1 - l2) + 1e-3, (l1 + l2) * 0.9999)
		u = normalize(d_vec)
		perp = (K - H) - np.sum((K - H) * u, axis=-1, keepdims=True) * u
		v = normalize(perp)
		cos_a = np.clip((l1 ** 2 + d ** 2 - l2 ** 2) / (2 * l1 * d), -1, 1)
		knee = H + l1 * (cos_a[:, None] * u + np.sqrt(1 - cos_a ** 2)[:, None] * v)
		ankle = H + u * d[:, None]
		r_thigh = _min_rotation(normalize(K - H), normalize(knee - H))
		w_thigh = r_thigh @ rot[:, h]
		r_shin = _min_rotation(normalize(np.einsum("fij,fj->fi", r_thigh, A - K)), normalize(ankle - knee))
		w_shin = r_shin @ r_thigh @ rot[:, k]
		parent = rot[:, skel.parents[h]]
		local[:, h] = T(parent) @ w_thigh
		local[:, k] = T(w_thigh) @ w_shin
		local[:, a] = T(w_shin) @ rot[:, a]
	return local, hips


def facing_yaw(skel, local, hips):
	rot, pos = skel.fk(local, hips)
	left = pos[:, skel.index["LeftUpperLeg"]] - pos[:, skel.index["RightUpperLeg"]]
	fwd = np.cross(left, np.array([0, 1, 0]))
	return np.unwrap(np.arctan2(fwd[:, 0], fwd[:, 2]))


def yaw_matrix(yaw):
	c, s = np.cos(yaw), np.sin(yaw)
	m = np.zeros(np.shape(yaw) + (3, 3))
	m[..., 0, 0], m[..., 0, 2], m[..., 1, 1], m[..., 2, 0], m[..., 2, 2] = c, s, 1, -s, c
	return m


def extract_root(skel, local, hips, mode="smooth", sigma=14.0, remove_yaw=False):
	"""Splits travel into a root curve (x, z, yaw per frame) and an in-place clip. mode "linear"
	(loops) fits constant velocity, "smooth" low-passes, "none" keeps only the first position."""
	n = hips.shape[0]
	frames = np.arange(n)
	xz = hips[:, [0, 2]]
	if mode == "linear":
		root_xz = np.stack([np.polyval(np.polyfit(frames, xz[:, i], 1), frames) for i in range(2)], -1)
	elif mode == "smooth":
		root_xz = gaussian(xz, sigma)
	else:
		root_xz = np.repeat(xz[:1], n, 0)
	yaw = np.zeros(n)
	if remove_yaw:
		raw = facing_yaw(skel, local, hips)
		yaw = np.polyval(np.polyfit(frames, raw, 1), frames) if mode == "linear" else gaussian(raw, sigma)
	local = local.copy()
	hips = hips.copy()
	hips[:, 0] -= root_xz[:, 0]
	hips[:, 2] -= root_xz[:, 1]
	if remove_yaw:
		r = yaw_matrix(-yaw)
		local[:, skel.index["Hips"]] = r @ local[:, skel.index["Hips"]]
		hips = np.einsum("fij,fj->fi", r, hips)
	root = np.stack([root_xz[:, 0] - root_xz[0, 0], root_xz[:, 1] - root_xz[0, 1], yaw - yaw[0]], -1)
	return local, hips, root


def best_loop(skel, local, hips, start, length, search=12):
	"""Loop end near start + length whose pose and velocity best match the start."""
	ids = [skel.index[b] for b in BODY_BONES]
	best, best_end = np.inf, start + length
	for end in range(start + length - search, start + length + search + 1):
		if end + 1 >= local.shape[0]:
			break
		d = np.linalg.norm(matrix_to_rotvec(T(local[start, ids]) @ local[end, ids]), axis=-1).sum()
		dv = np.linalg.norm(matrix_to_rotvec(T(local[start + 1, ids]) @ local[start, ids])
			- matrix_to_rotvec(T(local[end + 1, ids]) @ local[end, ids]), axis=-1).sum()
		score = d + 4 * dv + 10 * abs(hips[start, 1] - hips[end, 1])
		if score < best:
			best, best_end = score, end
	return best_end


def close_loop(local, hips):
	"""Spreads the end-to-start residual over the clip so the last frame equals the first."""
	n = local.shape[0] - 1
	alpha = (np.arange(n + 1) / n)[:, None, None]
	residual = matrix_to_rotvec(T(local[-1]) @ local[0])
	out = local @ rotvec_to_matrix(residual[None] * alpha)
	h = hips.copy()
	h[:, 1] += (hips[0, 1] - hips[-1, 1]) * alpha[:, 0, 0]
	h[:, [0, 2]] += (hips[0, [0, 2]] - hips[-1, [0, 2]]) * alpha[:, 0]
	return out, h


def pchip(x, y, xs):
	"""Monotone cubic interpolation (Fritsch-Carlson)."""
	x, y = np.asarray(x, float), np.asarray(y, float)
	h = np.diff(x)
	delta = np.diff(y) / h
	m = np.zeros_like(y)
	for i in range(1, len(y) - 1):
		if delta[i - 1] * delta[i] > 0:
			w1, w2 = 2 * h[i] + h[i - 1], h[i] + 2 * h[i - 1]
			m[i] = (w1 + w2) / (w1 / delta[i - 1] + w2 / delta[i])
	m[0], m[-1] = delta[0], delta[-1]
	out = np.empty_like(np.asarray(xs, float))
	for j, v in enumerate(xs):
		i = min(max(np.searchsorted(x, v) - 1, 0), len(h) - 1)
		t = (v - x[i]) / h[i]
		h00, h10 = 2 * t ** 3 - 3 * t ** 2 + 1, t ** 3 - 2 * t ** 2 + t
		h01, h11 = -2 * t ** 3 + 3 * t ** 2, t ** 3 - t ** 2
		out[j] = h00 * y[i] + h10 * h[i] * m[i] + h01 * y[i + 1] + h11 * h[i] * m[i + 1]
	return out


def strike_phases(skel, local, hips, bone, base_bone, target=None):
	"""(start of the fast extension, peak) frames of a strike: the peak is the striking bone's
	furthest reach from base_bone, the extension starts where its speed first passes 35% of max."""
	rot, pos = skel.fk(local, hips)
	p = pos[:, skel.index[bone]]
	reach = np.linalg.norm(p - pos[:, skel.index[base_bone]], axis=-1)
	speed = np.linalg.norm(np.gradient(p, axis=0), axis=-1)
	peak = int(np.argmax(reach))
	if target is not None:
		# The hit lands where the strike point comes closest to the hitbox.
		peak = int(np.argmin(np.linalg.norm(p - target, axis=-1)))
	before = speed[:peak + 1]
	thresh = 0.35 * before.max() if peak > 0 else 0
	ext = int(np.argmax(before)) if peak > 0 else 0
	while ext > 0 and speed[ext - 1] > thresh:
		ext -= 1
	return ext, peak, reach


def time_warp_strike(skel, local, hips, bone, base_bone, startup, active, recovery, target=None):
	"""Retimes a strike to the move: anticipation fills startup, the extension peaks in the middle of
	the active ticks, the follow-through fills recovery. Returns total + 1 frames (length = total/60)."""
	ext, peak, _ = strike_phases(skel, local, hips, bone, base_bone, target)
	total = startup + active + recovery
	n = local.shape[0] - 1
	peak_tick = startup + (active - 1) / 2.0
	ext_tick = max(startup - 1.0 - min(2.0, (startup - 1) * 0.3), 0.5)
	ext = min(max(ext, 1), peak - 1) if peak > 1 else ext
	knots_t = [0.0, ext_tick, peak_tick, float(total)]
	knots_s = [0.0, float(ext), float(peak), float(n)]
	if peak_tick <= ext_tick:
		knots_t, knots_s = [0.0, peak_tick, float(total)], [0.0, float(peak), float(n)]
	times = pchip(knots_t, knots_s, np.arange(total + 1))
	return interpolate(local, hips, times)
