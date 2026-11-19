"""BVH reading and forward kinematics: world joint positions per frame (numpy)."""

import numpy as np


class Bvh:
	def __init__(self, names, parents, offsets, channels, frames, frame_time):
		self.names = names  # Joints, then end sites named "<parent>_end".
		self.parents = parents
		self.offsets = np.array(offsets, dtype=float)
		self.channels = channels  # Per joint: list of channel names ([] for end sites).
		self.frames = frames  # (F, C) raw channel values.
		self.frame_time = frame_time

	def index(self, name):
		return self.names.index(name)

	def world_positions(self):
		"""(F, J, 3) joint positions in the file's units and axes."""
		n_frames = self.frames.shape[0]
		n = len(self.names)
		rot = np.zeros((n_frames, n, 3, 3))
		pos = np.zeros((n_frames, n, 3))
		col = 0
		local_t = np.tile(self.offsets[None], (n_frames, 1, 1))
		local_r = np.tile(np.eye(3), (n_frames, n, 1, 1))
		for j in range(n):
			chans = self.channels[j]
			if not chans:
				continue
			values = self.frames[:, col:col + len(chans)]
			col += len(chans)
			r = np.tile(np.eye(3), (n_frames, 1, 1))
			for k, ch in enumerate(chans):
				if ch.endswith("position"):
					local_t[:, j, "XYZ".index(ch[0])] = values[:, k]
				else:
					r = r @ axis_matrix(ch[0], np.radians(values[:, k]))
			local_r[:, j] = r
		for j in range(n):
			p = self.parents[j]
			if p < 0:
				rot[:, j] = local_r[:, j]
				pos[:, j] = local_t[:, j]
			else:
				rot[:, j] = rot[:, p] @ local_r[:, j]
				pos[:, j] = pos[:, p] + np.einsum("fij,fj->fi", rot[:, p], local_t[:, j])
		return pos


def axis_matrix(axis, angle):
	c, s = np.cos(angle), np.sin(angle)
	m = np.zeros(angle.shape + (3, 3))
	if axis == "X":
		m[..., 0, 0] = 1
		m[..., 1, 1], m[..., 1, 2], m[..., 2, 1], m[..., 2, 2] = c, -s, s, c
	elif axis == "Y":
		m[..., 1, 1] = 1
		m[..., 0, 0], m[..., 0, 2], m[..., 2, 0], m[..., 2, 2] = c, s, -s, c
	else:
		m[..., 2, 2] = 1
		m[..., 0, 0], m[..., 0, 1], m[..., 1, 0], m[..., 1, 1] = c, -s, s, c
	return m


def load(path):
	with open(path) as f:
		tokens = f.read().split()
	names, parents, offsets, channels = [], [], [], []
	stack = []
	i = 0
	while tokens[i] != "MOTION":
		t = tokens[i]
		if t in ("ROOT", "JOINT"):
			names.append(tokens[i + 1])
			parents.append(stack[-1] if stack else -1)
			channels.append([])
			offsets.append([0, 0, 0])
			i += 2
		elif t == "End":
			names.append(names[stack[-1]] + "_end")
			parents.append(stack[-1])
			channels.append([])
			offsets.append([0, 0, 0])
			i += 2
		elif t == "{":
			stack.append(len(names) - 1)
			i += 1
		elif t == "}":
			stack.pop()
			i += 1
		elif t == "OFFSET":
			offsets[stack[-1]] = [float(x) for x in tokens[i + 1:i + 4]]
			i += 4
		elif t == "CHANNELS":
			n = int(tokens[i + 1])
			channels[stack[-1]] = tokens[i + 2:i + 2 + n]
			i += 2 + n
		else:
			i += 1
	n_frames = int(tokens[i + 2])
	frame_time = float(tokens[i + 5])
	data = np.array(tokens[i + 6:], dtype=float)
	data = data[:n_frames * (data.size // n_frames)].reshape(n_frames, -1)
	return Bvh(names, parents, offsets, channels, data, frame_time)
