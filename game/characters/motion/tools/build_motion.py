"""Builds Skybreak's starter mocap library: retarget -> trim -> (time-warp) -> exaggerate -> foot lock
-> root extraction -> loop matching, then writes motion_clips.json for build_motion_library.gd.

	python3 -P game/characters/motion/tools/build_motion.py <kael_rig.json> <cmu data dir> <bandai data dir> <out.json>
"""

import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bvh
import cleanup as cu
import retarget as rt

CMU = "CMU Graphics Lab Motion Capture Database (mocap.cs.cmu.edu), BVH conversion by Bruce Hahne"
CMU_LICENCE = "Free for research and commercial use (CMU terms in READMEFIRST.txt)"
BANDAI = "Bandai-Namco-Research-Motiondataset-1 (Bandai Namco Research Inc.)"
BANDAI_LICENCE = "CC BY-NC 4.0"

# name: (kind, source file, options). Times in source seconds (CMU files skip their T-pose frame).
CLIPS = {
	# Stance and locomotion.
	"fight_idle": ("loop", "cmu:014/14_01", dict(root="none", start=18.5, length=1.2, exaggerate=0.15)),
	"idle_breathe": ("loop", "cmu:077/77_03", dict(root="none", start=2.0, length=2.4)),
	"walk": ("loop", "bandai:dataset-1_walk_masculinity_001", dict(start=2.0, length=1.1, remove_yaw=True)),
	"run": ("loop", "bandai:dataset-1_run_masculinity_001", dict(start=2.0, length=0.7, remove_yaw=True,
		exaggerate=0.15)),
	"strafe_left": ("loop", "bandai:dataset-1_walk-left_normal_001", dict(start=2.0, length=1.1)),
	"strafe_right": ("loop", "bandai:dataset-1_walk-right_normal_001", dict(start=2.0, length=1.1)),
	"walk_back": ("loop", "bandai:dataset-1_walk-back_normal_001", dict(start=2.0, length=1.1)),
	"turn_in_place": ("oneshot", "cmu:069/69_16", dict(root="smooth", start=0.5, end=2.5)),
	"dash_start": ("oneshot", "bandai:dataset-1_dash_masculinity_001", dict(root="smooth", start=0.0, end=0.9, exaggerate=0.2)),
	"dash_stop": ("oneshot", "bandai:dataset-1_dash_masculinity_001", dict(root="smooth", start=-1.2, end=None, exaggerate=0.2)),
	"jump": ("oneshot", "cmu:016/16_01", dict(root="smooth", start=0.4, end=1.5, ground=False)),
	"land": ("oneshot", "cmu:016/16_01", dict(root="smooth", start=1.3, end=2.2, ground=False)),
	"heavy_land": ("oneshot", "cmu:082/82_02", dict(root="smooth", start=1.2, end=2.6, ground=False, exaggerate=0.25)),
	# Strikes, time-warped onto Kael's moves.
	"light_1": ("strike", "cmu:014/14_01", dict(peak=15.28, pre=0.45, post=0.5, side="Left")),
	"light_2": ("strike", "cmu:014/14_01", dict(peak=21.73, pre=0.45, post=0.55, side="Right")),
	"light_3": ("strike", "cmu:014/14_01", dict(peak=24.30, pre=0.5, post=0.55, side="Left")),
	"light_4": ("strike", "cmu:135/135_07", dict(peak=6.42, pre=0.7, post=0.8, side="Right", kick=True)),
	"smash": ("strike", "cmu:014/14_01", dict(peak=31.50, pre=0.6, post=0.7, side="Right", exaggerate=0.35)),
	"breaker": ("strike", "cmu:135/135_09", dict(peak=4.42, pre=0.9, post=0.9, side="Left", exaggerate=0.3)),
	"launcher": ("strike", "cmu:014/14_01", dict(peak=35.32, pre=0.55, post=0.7, side="Right", exaggerate=0.3)),
	"rising": ("strike", "cmu:090/90_05", dict(peak=None, pre=0.7, post=0.9, side="Right", kick=True)),
	"spike": ("strike", "cmu:135/135_04", dict(peak=3.12, pre=0.8, post=0.8, side="Right", kick=True,
		exaggerate=0.3)),
	"sweep": ("strike", "cmu:135/135_07", dict(peak=3.67, pre=0.7, post=0.8, side="Left", kick=True,
		mirror=True)),
	"charged_smash_1": ("strike", "cmu:014/14_01", dict(peak=31.50, pre=0.6, post=0.7, side="Right",
		exaggerate=0.3)),
	"charged_smash_2": ("strike", "cmu:014/14_01", dict(peak=31.50, pre=0.6, post=0.7, side="Right",
		exaggerate=0.45)),
	"charged_smash_3": ("strike", "cmu:014/14_01", dict(peak=31.50, pre=0.6, post=0.7, side="Right",
		exaggerate=0.6)),
	"push_block": ("strike", "cmu:135/135_09", dict(peak=8.33, pre=0.4, post=0.6, side="Left")),
	# Defence and damage.
	"guard": ("loop", "cmu:144/144_07", dict(root="none", start=0.6, length=1.0)),
	"block_hit": ("oneshot", "cmu:144/144_07", dict(start=1.6, end=2.4, exaggerate=0.3)),
	"hit_light": ("oneshot", "cmu:077/77_09", dict(start=1.0, end=1.8, exaggerate=0.3)),
	"hit_heavy": ("oneshot", "cmu:091/91_59", dict(start=0.2, end=1.6, exaggerate=0.2)),
	"ko_fall": ("oneshot", "cmu:090/90_18", dict(start=0.6, end=3.0, ground=False, root="smooth")),
	"fall_face": ("oneshot", "cmu:090/90_16", dict(root="smooth", start=0.4, end=2.8, ground=False)),
	"get_up": ("oneshot", "cmu:140/140_08", dict(root="smooth", start=0.5, end=4.0, ground=False)),
	"get_up_face_down": ("oneshot", "cmu:140/140_01", dict(root="smooth", start=0.5, end=4.0, ground=False)),
	"tech": ("oneshot", "cmu:140/140_08", dict(root="smooth", start=0.5, end=4.0, ground=False, speed=2.0)),
	"grab": ("oneshot", "cmu:056/56_03", dict(start=None, end=None)),
	"throw": ("oneshot", "cmu:113/113_24", dict(start=2.0, end=3.8, exaggerate=0.25)),
}
# Strike bones match tests/characters/test_kael_chunky.gd.
STRIKE_BONES = {
	"light_1": "LeftMiddleProximal", "light_2": "RightMiddleProximal", "light_3": "LeftMiddleProximal",
	"light_4": "RightToes", "smash": "RightMiddleProximal", "breaker": "LeftMiddleProximal",
	"launcher": "RightMiddleProximal", "rising": "RightToes", "spike": "RightToes", "sweep": "RightToes",
	"charged_smash_1": "RightMiddleProximal", "charged_smash_2": "RightMiddleProximal",
	"charged_smash_3": "RightMiddleProximal", "push_block": "LeftMiddleProximal",
}
OUTPUT_BONES = cu.BODY_BONES


class Sources:
	def __init__(self, cmu_dir, bandai_dir):
		self.dirs = {"cmu": cmu_dir, "bandai": bandai_dir}
		self.cache = {}

	def load(self, ref):
		if ref not in self.cache:
			rig, name = ref.split(":")
			b = bvh.load(os.path.join(self.dirs[rig], name + ".bvh"))
			p = rt.source_points(b, rig, 1.0 if rig == "cmu" else 0.01)
			if rig == "cmu":
				p = {k: v[1:] for k, v in p.items()}
			self.cache[ref] = (p, b.frame_time)
		return self.cache[ref]


def face(points, frame_index):
	"""Turns the source so the body faces +Z at frame_index."""
	r = rt.references({k: v[frame_index] for k, v in points.items()})
	fwd = r["fwd"]
	yaw = np.arctan2(fwd[0], fwd[2])
	return rt.rotate_y(points, -yaw)


def strike_yaw(skel, local, hips, bone, peak):
	"""Yaw that turns the strike (bone at the peak, from the hips) toward +Z."""
	rot, pos = skel.fk(local[peak:peak + 1], hips[peak:peak + 1])
	v = pos[0, skel.index[bone]] - pos[0, skel.index["Hips"]]
	return np.arctan2(v[0], v[2])


def apply_yaw(local, hips, skel, yaw):
	r = cu.yaw_matrix(np.full(local.shape[0], yaw))
	local = local.copy()
	local[:, skel.index["Hips"]] = r @ local[:, skel.index["Hips"]]
	return local, np.einsum("fij,fj->fi", r, hips)


def build_clip(skel, sources, name, kind, ref, o, moves):
	points, dt = sources.load(ref)
	if o.get("mirror"):
		points = rt.mirror(points)
	n_src = points["pelvis"].shape[0]
	duration = (n_src - 1) * dt
	meta = {"source": ref, "kind": kind}
	if kind == "strike":
		peak_s = o["peak"]
		if peak_s is None:
			peak_s = _auto_peak(skel, points, dt, o)
		start = max(peak_s - o["pre"], 0.0)
		end = min(peak_s + o["post"], duration)
		i0 = int(start / dt)
		points = face(points, i0)
		local, hips, scale = rt.retarget(skel, points)
		local, hips = cu.resample(local, hips, dt, start, end)
		hips[:, [0, 2]] -= hips[0, [0, 2]]  # Start on the spot; a step-in carries him forward.
		bone = STRIKE_BONES[name]
		base = ("Right" if "Right" in bone else "Left") + ("UpperLeg" if o.get("kick") else "UpperArm")
		ext, peak, _ = cu.strike_phases(skel, local, hips, bone, base)
		local, hips = apply_yaw(local, hips, skel, -strike_yaw(skel, local, hips, bone, peak))
		hips = cu.ground(skel, local, hips)
		m = moves[name]
		box = np.mean(np.array(m["hitbox_offsets"])[:m["active"]], axis=0)
		target = np.array([-box[0], box[1] + 1.0, -box[2]])  # View space -> skeleton space.
		local, hips = cu.time_warp_strike(skel, local, hips, bone, base, m["startup"], m["active"], m["recovery"],
			target)
		local, hips = cu.exaggerate(skel, local, hips, o.get("exaggerate", 0.1), sigma=3.0)
		contacts = cu.foot_contacts(skel, local, hips)
		local, hips = cu.foot_lock(skel, local, hips, contacts)
		local, hips, root = cu.extract_root(skel, local, hips, mode="none")
		meta.update(strike_bone=bone, startup=m["startup"], active=m["active"], recovery=m["recovery"],
			source_window=[round(start, 3), round(end, 3)])
		return local, hips, root, contacts, False, meta
	start = o.get("start") or 0.0
	if start < 0:
		start = duration + start
	if kind == "loop":
		start = max(min(start, duration - o["length"] - 0.3), 0.0)
		end = min(start + o["length"] + 0.5, duration)
	else:
		end = duration if o.get("end") is None else min(o["end"], duration)
	points = face(points, min(int(start / dt), n_src - 1))
	local, hips, scale = rt.retarget(skel, points)
	local, hips = cu.resample(local, hips, dt, start, end, speed=o.get("speed", 1.0))
	hips = cu.ground(skel, local, hips)
	local, hips = cu.exaggerate(skel, local, hips, o.get("exaggerate", 0.0), sigma=4.0)
	if kind == "loop":
		length = int(round(o["length"] * cu.FPS))
		loop_end = cu.best_loop(skel, local, hips, 0, min(length, local.shape[0] - 14), search=10)
		local, hips = local[:loop_end + 1], hips[:loop_end + 1]
		contacts = cu.foot_contacts(skel, local, hips)
		local, hips = cu.foot_lock(skel, local, hips, contacts)
		local, hips, root = cu.extract_root(skel, local, hips, mode=o.get("root", "linear"),
			remove_yaw=o.get("remove_yaw", False))
		local, hips = cu.close_loop(local, hips)
	else:
		contacts = cu.foot_contacts(skel, local, hips)
		if o.get("ground", True):
			local, hips = cu.foot_lock(skel, local, hips, contacts)
		local, hips, root = cu.extract_root(skel, local, hips, mode=o.get("root", "none"), sigma=14.0)
	meta["source_window"] = [round(start, 3), round(end, 3)]
	return local, hips, root, contacts, kind == "loop", meta


def _auto_peak(skel, points, dt, o):
	local, hips, _ = rt.retarget(skel, points)
	rot, pos = skel.fk(local, hips)
	foot = pos[:, skel.index[o["side"] + "Toes"]]
	return float(np.argmax(foot[:, 1] - pos[:, skel.index["Hips"], 1]) * dt)


# Flight: mocap has none, so the airborne part of a real jump (legs tucked, arms loose) is held as
# a slow ping-pong loop and the body is pitched/rolled procedurally. MotionLayers adds banking live.
FLIGHT = {"hover": (0.0, 0.0), "fly": (62.0, 0.0), "bank_left": (55.0, 38.0), "bank_right": (55.0, -38.0),
	"dive": (105.0, 0.0)}


def flight_clips(skel, sources):
	points, dt = sources.load("cmu:016/16_01")
	points = face(points, int(0.4 / dt))
	local, hips, _ = rt.retarget(skel, points)
	local, hips = cu.resample(local, hips, dt, 0.4, 1.6)
	apex = int(np.argmax(hips[:, 1]))
	a, b = max(apex - 8, 0), min(apex + 8, local.shape[0] - 1)
	idx = np.concatenate([np.linspace(a, b, 30), np.linspace(b, a, 30)])
	# Ping-pong at a quarter speed, eased so it breathes rather than bounces.
	ease = a + (b - a) * 0.5 * (1 - np.cos(np.pi * (idx - a) / max(b - a, 1)))
	base, base_hips = cu.interpolate(local, hips, ease)
	base_hips = base_hips - base_hips.mean(0) + np.array([0, skel.rest_pos[skel.index["Hips"]][1], 0])
	out = {}
	for name, (pitch, roll) in FLIGHT.items():
		n = base.shape[0]
		wobble = np.sin(np.linspace(0, 2 * np.pi, n))
		r = rt.rotvec_to_matrix(np.stack([np.radians(pitch + 3 * wobble), np.zeros(n),
			np.radians(roll + 2 * wobble)], -1))
		loc = base.copy()
		loc[:, skel.index["Hips"]] = r @ loc[:, skel.index["Hips"]]
		h = base_hips.copy()
		h[:, 1] += 0.03 * wobble
		loc, h = cu.close_loop(loc, h)
		out[name] = (loc, h, np.zeros((n, 3)), {"Left": np.zeros(n, bool), "Right": np.zeros(n, bool)}, True,
			{"source": "cmu:016/16_01", "kind": "flight", "source_window": [0.4, 1.6]})
	return out


def grab_window(skel, sources):
	"""56_03: the 'angrily grab' is the first moment both hands reach far forward together."""
	points, dt = sources.load("cmu:056/56_03")
	local, hips, _ = rt.retarget(skel, points)
	rot, pos = skel.fk(local, hips)
	reach = sum(np.linalg.norm(pos[:, skel.index[s + "Hand"]] - pos[:, skel.index[s + "UpperArm"]], axis=-1)
		for s in ("Left", "Right"))
	both = np.argmax(reach > 0.9 * reach.max())
	return max(both * dt - 0.6, 0), both * dt + 1.4


def main():
	rig_path, cmu_dir, bandai_dir, out_path = sys.argv[1:5]
	only = set(sys.argv[5:])
	rig = json.load(open(rig_path))
	skel = rt.Skeleton(rig)
	sources = Sources(cmu_dir, bandai_dir)
	moves = rig["moves"]
	CLIPS["grab"][2]["start"], CLIPS["grab"][2]["end"] = grab_window(skel, sources)
	clips = {}
	built = {name: (lambda n=name, c=spec: build_clip(skel, sources, n, c[0], c[1], c[2], moves))
		for name, spec in CLIPS.items() if not only or name in only}
	built.update({name: (lambda v=value: v) for name, value in flight_clips(skel, sources).items()})
	for name, make in built.items():
		local, hips, root, contacts, loop, meta = make()
		ref = meta["source"]
		assert np.all(np.isfinite(local)) and np.all(np.isfinite(hips)), name
		ids = [skel.index[b] for b in OUTPUT_BONES]
		quats = rt.matrix_to_quat(local[:, ids])
		# Keep neighbouring quaternions in the same hemisphere.
		for i in range(1, quats.shape[0]):
			flip = np.sum(quats[i] * quats[i - 1], axis=-1) < 0
			quats[i, flip] *= -1
		clips[name] = dict(meta, loop=loop, frames=int(quats.shape[0]),
			rotations=np.round(quats, 6).tolist(), hips=np.round(hips, 5).tolist(),
			root=np.round(root, 5).tolist(),
			contacts={k: v.astype(int).tolist() for k, v in contacts.items()})
		print("%-18s %-38s %4d frames %s" % (name, ref, quats.shape[0], "loop" if loop else ""))
	json.dump({"fps": cu.FPS, "bones": OUTPUT_BONES, "clips": clips,
		"sources": {"cmu": [CMU, CMU_LICENCE], "bandai": [BANDAI, BANDAI_LICENCE]}}, open(out_path, "w"))


if __name__ == "__main__":
	main()
