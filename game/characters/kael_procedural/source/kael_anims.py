"""Kael's clips, authored as key poses in code and baked at 60 fps.

Attack clips are timed from the sim's frame data (kael_moves): clip frame f = move_tick f, so
startup covers the anticipation, the strike peaks inside the active ticks, and recovery is the
follow-through. Every clip keeps the Root bone still: no root motion.
"""

import math
import random
import zlib

import bpy
from mathutils import Quaternion, Vector

import kael_moves
import kael_rig
from kael_pose import Pose, Rig, arm, ease, elbow, fist, foot, knee, leg, open_hand, reach, spine, wrist

G = 0.085  # Ankle height with the foot flat on the ground.
FPS = 60

# Bone whose head is the striking point of each attack, and the moves the clips are timed to.
STRIKE_BONES = {
	"light_1": "LeftMiddleProximal",
	"light_2": "RightMiddleProximal",
	"light_3": "LeftMiddleProximal",
	"light_4": "RightToes",
	"smash": "RightMiddleProximal",
	"breaker": "LeftMiddleProximal",
	"launcher": "RightMiddleProximal",
	"rising": "RightToes",
	"spike": "RightToes",
	"sweep": "RightToes",
	"charged_smash_1": "RightMiddleProximal",
	"charged_smash_2": "RightMiddleProximal",
	"charged_smash_3": "RightMiddleProximal",
	"push_block": "LeftMiddleProximal",
}


def _feet(lf=(0.13, -0.17), rf=(-0.15, 0.2), lyaw=12, ryaw=-30, lz=G, rz=G, lpitch=0.0, rpitch=0.0):
	return {
		"LeftFoot": ((lf[0], lf[1], lz), (0.35, -1, 0), lyaw, lpitch),
		"RightFoot": ((rf[0], rf[1], rz), (-0.4, -1, 0), ryaw, rpitch),
	}


def _guard(lh=(0.11, -0.38, 1.33), rh=(-0.13, -0.26, 1.27)):
	return {
		"LeftHand": (lh, (0.5, 0.4, -1)),
		"RightHand": (rh, (-0.5, 0.5, -1)),
	}


def stance():
	rot = {
		"Hips": spine(turn=-22),
		"Spine": spine(fwd=4, turn=6),
		"Chest": spine(fwd=4, turn=6),
		"UpperChest": spine(turn=4),
		"Neck": spine(fwd=-5, turn=3),
		"Head": spine(fwd=-6, turn=3),
		"LeftHand": wrist(up=-5),
	}
	rot.update(fist())
	ik = _feet()
	ik.update(_guard())
	return Pose(rot, ik, hips=(0, 0.02, -0.07))


STANCE = stance()


def with_hands(p, lh=None, rh=None, lpole=(0.6, 0.4, -1), rpole=(-0.6, 0.5, -1)):
	ik = {}
	if lh is not None:
		ik["LeftHand"] = (lh, lpole)
	if rh is not None:
		ik["RightHand"] = (rh, rpole)
	return p.but(ik=ik)


def torso(p, hips_turn=None, fwd=None, side=0.0, hips_fwd=0.0, head_fwd=None, head_turn=None):
	"""Re-aims the torso; the head turns back toward the front so he keeps looking at the target."""
	rot = {}
	ht = -22 if hips_turn is None else hips_turn
	rot["Hips"] = spine(fwd=hips_fwd, side=side * 0.4, turn=ht)
	f = 4 if fwd is None else fwd
	rot["Spine"] = spine(fwd=f, side=side * 0.3, turn=6)
	rot["Chest"] = spine(fwd=f, side=side * 0.3, turn=6)
	total = ht + 16
	look = -total if head_turn is None else head_turn
	rot["Neck"] = spine(fwd=-5 - hips_fwd * 0.3 - f * 0.6, turn=look * 0.5)
	rot["Head"] = spine(fwd=(-6 if head_fwd is None else head_fwd) - hips_fwd * 0.3 - f * 0.6, turn=look * 0.5)
	return p.but(rot=rot)


class Clip:
	def __init__(self, name, length, loop=False, jitter=0.0, hair_lift=0.0):
		self.name = name
		self.length = length  # Last frame index; a loop's last frame equals its first.
		self.loop = loop
		self.keys = []  # (frame, Pose, ease into this key)
		self.jitter = jitter
		self.hair_lift = hair_lift

	def key(self, frame, pose, kind="io"):
		self.keys.append((int(round(frame)), pose, kind))
		return self


def _attack(moves, mid):
	m = moves[mid]
	return m["startup"], m["active"], m["recovery"]


# --- Locomotion and states ---------------------------------------------------------------------

def clip_idle():
	c = Clip("idle", 72, loop=True)
	inhale = STANCE.but(hips=STANCE.hips + Vector((0, 0, 0.008)), rot={
		"Chest": spine(fwd=1, turn=6), "UpperChest": spine(fwd=-2, turn=4),
		"LeftShoulder": spine(side=-3), "Head": spine(fwd=4, turn=3)})
	inhale = inhale.but(rot={"Head": spine(fwd=-8, turn=3)})
	inhale = with_hands(inhale, lh=(0.11, -0.38, 1.345), rh=(-0.13, -0.26, 1.285))
	c.key(0, STANCE).key(36, inhale).key(72, STANCE)
	return c


def clip_run():
	c = Clip("run", 36, loop=True)
	base_rot = {
		"Hips": spine(fwd=8),
		"Spine": spine(fwd=6),
		"Chest": spine(fwd=4),
		"Neck": spine(fwd=-8),
		"Head": spine(fwd=-4),
	}
	base_rot.update(fist(0.9))

	def foot_at(phase):
		# phase 0 = front contact; ground contact until 0.42, then a high swing back to the front.
		if phase < 0.42:
			t = phase / 0.42
			return Vector((0, -0.32 + 0.66 * t, G)), -5 + 25 * t
		t = (phase - 0.42) / 0.58
		y = 0.34 - 0.70 * (0.5 - 0.5 * math.cos(math.pi * t))
		z = G + 0.30 * math.sin(math.pi * min(1.0, t * 1.15)) ** 1.2
		return Vector((0, y, z)), 30 - 60 * t

	for f in range(0, 37, 3):
		ph = f / 36.0
		lpos, lp = foot_at(ph % 1.0)
		rpos, rp = foot_at((ph + 0.5) % 1.0)
		swing = math.sin(2 * math.pi * ph)
		bob = -0.035 + 0.025 * math.cos(4 * math.pi * (ph - 0.12))
		rot = dict(base_rot)
		rot["Hips"] = spine(fwd=8, turn=10 * swing)
		rot["Chest"] = spine(fwd=4, turn=-16 * swing)
		rot["Head"] = spine(fwd=-4, turn=6 * swing)
		rot["LeftUpperArm"] = arm(down=72, fwd=-45 * swing + 10)
		rot["RightUpperArm"] = arm(down=72, fwd=45 * swing + 10)
		rot["LeftLowerArm"] = elbow(95 + 15 * swing)
		rot["RightLowerArm"] = elbow(95 - 15 * swing)
		ik = {
			"LeftFoot": ((0.1, lpos.y, lpos.z), (0.1, -1, 0), 4, lp),
			"RightFoot": ((-0.1, rpos.y, rpos.z), (-0.1, -1, 0), -4, rp),
		}
		c.key(f, Pose(rot, ik, hips=(0, 0.0, bob)), "lin")
	return c


def _air_base():
	rot = {
		"Hips": spine(fwd=4),
		"Spine": spine(fwd=3),
		"Chest": spine(fwd=2),
		"Head": spine(fwd=2),
		"LeftUpperLeg": leg(fwd=28, out=4),
		"LeftLowerLeg": knee(55),
		"LeftFoot": foot(-25),
		"RightUpperLeg": leg(fwd=6, out=6),
		"RightLowerLeg": knee(28),
		"RightFoot": foot(-35),
		"LeftUpperArm": arm(down=58, fwd=18),
		"LeftLowerArm": elbow(38),
		"RightUpperArm": arm(down=62, fwd=8),
		"RightLowerArm": elbow(30),
	}
	rot.update(fist(0.75))
	return Pose(rot)


def clip_fly_hover():
	c = Clip("fly_hover", 90, loop=True)
	a = _air_base()
	b = a.but(hips=(0, 0, 0.03), rot={
		"LeftUpperLeg": leg(fwd=34, out=4), "LeftLowerLeg": knee(62),
		"RightUpperLeg": leg(fwd=2, out=6), "RightLowerLeg": knee(22),
		"LeftUpperArm": arm(down=52, fwd=20), "RightUpperArm": arm(down=56, fwd=10),
		"Chest": spine(fwd=0), "Head": spine(fwd=0)})
	c.key(0, a).key(45, b).key(90, a)
	return c


def clip_fly_forward():
	c = Clip("fly_forward", 60, loop=True)
	rot = {
		"Hips": spine(fwd=62),
		"Spine": spine(fwd=4),
		"Chest": spine(fwd=2),
		"Neck": spine(fwd=-28),
		"Head": spine(fwd=-30),
		"RightUpperArm": reach(fwd=165, down=0),
		"RightLowerArm": elbow(4),
		"LeftUpperArm": arm(down=78, back=18),
		"LeftLowerArm": elbow(12),
		"LeftUpperLeg": leg(fwd=-6, out=3),
		"LeftLowerLeg": knee(12),
		"LeftFoot": foot(-40),
		"RightUpperLeg": leg(fwd=-2, out=3),
		"RightLowerLeg": knee(38),
		"RightFoot": foot(-40),
	}
	rot.update(fist(1.0))
	a = Pose(rot)
	b = a.but(hips=(0, 0, 0.015), rot={"RightLowerLeg": knee(30), "LeftLowerLeg": knee(18),
		"Hips": spine(fwd=60), "LeftUpperArm": arm(down=76, back=22)})
	c.key(0, a).key(30, b).key(60, a)
	c.jitter = 0.002
	return c


def clip_dash():
	c = Clip("dash", 24, loop=True, jitter=0.003)
	rot = {
		"Hips": spine(fwd=36),
		"Spine": spine(fwd=6),
		"Chest": spine(fwd=4),
		"Neck": spine(fwd=-18),
		"Head": spine(fwd=-14),
		"LeftUpperArm": arm(down=58, back=55),
		"RightUpperArm": arm(down=58, back=55),
		"LeftLowerArm": elbow(12),
		"LeftUpperLeg": leg(fwd=34),
		"LeftLowerLeg": knee(70),
		"LeftFoot": foot(-30),
		"RightUpperLeg": leg(fwd=-18),
		"RightLowerLeg": knee(45),
		"RightFoot": foot(-40),
	}
	rot.update(fist(1.0))
	a = Pose(rot)
	b = a.but(rot={"Hips": spine(fwd=38), "RightLowerLeg": knee(52), "LeftUpperLeg": leg(fwd=30)})
	c.key(0, a).key(12, b).key(24, a)
	return c


def clip_charge_ki():
	c = Clip("charge_ki", 60, loop=True, jitter=0.004, hair_lift=1.0)
	rot = {
		"Hips": spine(fwd=8),
		"Spine": spine(fwd=8),
		"Chest": spine(fwd=4),
		"UpperChest": spine(fwd=-4),
		"Neck": spine(fwd=-6),
		"Head": spine(fwd=-4),
		"LeftShoulder": spine(side=-8),
		"LeftHand": wrist(up=10),
	}
	rot.update(fist(1.0))
	ik = {
		"LeftFoot": ((0.27, -0.04, G), (0.6, -1, 0), 25, 0),
		"RightFoot": ((-0.27, 0.04, G), (-0.6, -1, 0), -25, 0),
		"LeftHand": ((0.33, -0.06, 0.93), (0.6, 1, 0.2)),
		"RightHand": ((-0.33, -0.06, 0.93), (-0.6, 1, 0.2)),
	}
	a = Pose(rot, ik, hips=(0, 0.02, -0.17))
	b = a.but(hips=(0, 0.02, -0.185), rot={"Head": spine(fwd=-12), "Chest": spine(fwd=0)})
	c.key(0, a).key(30, b).key(60, a)
	return c


def clip_fall():
	c = Clip("fall", 40, loop=True)
	rot = {
		"Hips": spine(fwd=-6),
		"Spine": spine(fwd=-6),
		"Head": spine(fwd=8),
		"LeftUpperArm": arm(down=-20, fwd=25),
		"RightUpperArm": arm(down=-10, fwd=10),
		"LeftLowerArm": elbow(35),
		"RightLowerArm": elbow(45),
		"LeftUpperLeg": leg(fwd=30),
		"LeftLowerLeg": knee(50),
		"RightUpperLeg": leg(fwd=10),
		"RightLowerLeg": knee(30),
		"LeftFoot": foot(-20),
		"RightFoot": foot(-20),
	}
	rot.update(open_hand(10))
	a = Pose(rot)
	b = a.but(rot={"LeftUpperArm": arm(down=-8, fwd=12), "RightUpperArm": arm(down=-24, fwd=26),
		"LeftUpperLeg": leg(fwd=12), "LeftLowerLeg": knee(32), "RightUpperLeg": leg(fwd=30),
		"RightLowerLeg": knee(52)})
	c.key(0, a).key(20, b).key(40, a)
	return c


def _block_pose():
	p = torso(STANCE, hips_turn=-10, fwd=12, head_fwd=12)
	p = p.but(hips=(0, 0.04, -0.11), rot={"LeftHand": wrist(up=10), "RightHand": wrist(up=10)})
	return with_hands(p, lh=(-0.08, -0.3, 1.56), rh=(0.09, -0.27, 1.5),
		lpole=(0.8, 0.2, -1), rpole=(-0.8, 0.2, -1))


def clip_block():
	c = Clip("block", 30, loop=True)
	a = _block_pose()
	b = a.but(hips=a.hips + Vector((0, 0, -0.005)))
	c.key(0, a).key(15, b).key(30, a)
	return c


def clip_blockstun():
	c = Clip("blockstun", 16)
	a = _block_pose()
	pushed = torso(a, hips_turn=-14, fwd=4, head_fwd=0).but(hips=(0, 0.1, -0.13))
	pushed = with_hands(pushed, lh=(-0.06, -0.24, 1.58), rh=(0.1, -0.21, 1.52), lpole=(0.8, 0.2, -1),
		rpole=(-0.8, 0.2, -1))
	c.key(0, a).key(3, pushed, "out3").key(16, a, "io")
	return c


def clip_hitstun_light():
	c = Clip("hitstun_light", 20)
	hit = torso(STANCE, hips_turn=-15, fwd=-10, head_fwd=-22).but(hips=(0, 0.08, -0.06),
		rot={"Neck": spine(fwd=-14, turn=8)})
	hit = with_hands(hit, lh=(0.16, -0.24, 1.32), rh=(-0.17, -0.12, 1.3))
	c.key(0, STANCE).key(3, hit, "out3").key(8, hit.but(hips=(0, 0.07, -0.07)), "lin").key(20, STANCE, "io")
	return c


def clip_hitstun_heavy():
	c = Clip("hitstun_heavy", 36)
	fold = torso(STANCE, hips_turn=-8, fwd=26, head_fwd=22, hips_fwd=12).but(hips=(0, 0.14, -0.13),
		rot={"LeftUpperArm": arm(down=62, fwd=40), "RightUpperArm": arm(down=58, fwd=46),
			"LeftLowerArm": elbow(35), "RightLowerArm": elbow(25)}, drop_ik=("LeftHand", "RightHand"))
	fold = fold.but(rot=open_hand(6))
	c.key(0, STANCE).key(4, fold, "out3").key(16, fold.but(hips=(0, 0.13, -0.14)), "lin").key(36, STANCE, "io")
	return c


def clip_guard_broken():
	c = Clip("guard_broken", 60, loop=True)
	base = torso(STANCE, hips_turn=-10, fwd=-14, head_fwd=-20).but(hips=(0, 0.05, -0.1),
		rot={"LeftUpperArm": arm(down=20, back=25), "RightUpperArm": arm(down=28, back=20),
			"LeftLowerArm": elbow(30), "RightLowerArm": elbow(40)},
		drop_ik=("LeftHand", "RightHand"))
	base = base.but(rot=open_hand(15))
	left = torso(base, hips_turn=-14, fwd=-12, side=10, head_fwd=-14).but(hips=(0.03, 0.05, -0.11),
		rot={"LeftUpperArm": arm(down=12, back=30), "RightUpperArm": arm(down=34, back=14)})
	right = torso(base, hips_turn=-6, fwd=-16, side=-10, head_fwd=-24).but(hips=(-0.03, 0.05, -0.1),
		rot={"LeftUpperArm": arm(down=26, back=18), "RightUpperArm": arm(down=16, back=30)})
	c.key(0, base).key(15, left).key(30, base).key(45, right).key(60, base)
	return c


def _lying():
	rot = {
		"Hips": spine(fwd=-86),
		"Spine": spine(fwd=4),
		"Chest": spine(fwd=4),
		"Neck": spine(fwd=10),
		"Head": spine(fwd=12, turn=10),
		"LeftUpperArm": arm(down=20, fwd=-10),
		"RightUpperArm": arm(down=35, fwd=-5),
		"LeftLowerArm": elbow(20),
		"RightLowerArm": elbow(30),
		"LeftUpperLeg": leg(fwd=18, out=8),
		"LeftLowerLeg": knee(30),
		"RightUpperLeg": leg(fwd=6, out=5),
		"RightLowerLeg": knee(10),
		"LeftFoot": foot(-20),
		"RightFoot": foot(-30),
	}
	rot.update(open_hand(10))
	return Pose(rot, hips=(0, 0.3, -0.84))


def clip_knockdown():
	c = Clip("knockdown", 40)
	airborne = Pose(dict(_lying().rot, **{"Hips": spine(fwd=-40), "LeftUpperLeg": leg(fwd=40),
		"LeftLowerLeg": knee(60), "RightUpperLeg": leg(fwd=30), "RightLowerLeg": knee(45),
		"Head": spine(fwd=20), "LeftUpperArm": arm(down=-10, fwd=30), "RightUpperArm": arm(down=0, fwd=20)}),
		hips=(0, 0.2, -0.32))
	down = _lying()
	bounce = down.but(hips=(0, 0.31, -0.78), rot={"LeftUpperLeg": leg(fwd=30, out=8),
		"LeftLowerLeg": knee(45)})
	c.key(0, STANCE).key(6, airborne, "out").key(14, down, "in").key(20, bounce, "out").key(28, down, "in")
	c.key(39, down, "io")
	return c


def clip_get_up():
	c = Clip("get_up", 40)
	down = _lying()
	sit = Pose(dict(down.rot, **{"Hips": spine(fwd=-30), "Spine": spine(fwd=25), "Chest": spine(fwd=10),
		"Head": spine(fwd=-5), "LeftUpperLeg": leg(fwd=80, out=10), "LeftLowerLeg": knee(120),
		"RightUpperLeg": leg(fwd=40), "RightLowerLeg": knee(40)}), hips=(0, 0.2, -0.74))
	kneel = torso(STANCE, hips_turn=-15, fwd=20, head_fwd=0).but(hips=(0, 0.06, -0.42))
	kneel = kneel.but(ik={
		"LeftFoot": ((0.13, -0.25, G), (0.35, -1, 0), 12, 0),
		"RightFoot": ((-0.15, 0.32, 0.06), (-0.3, -1, 0.0), -20, -60),
		"LeftHand": ((0.2, -0.3, 1.0), (0.6, 0.4, -1)),
		"RightHand": ((-0.2, -0.15, 1.05), (-0.6, 0.5, -1)),
	})
	c.key(0, down).key(10, sit, "io").key(22, kneel, "io").key(39, STANCE, "back")
	return c


def clip_victory():
	c = Clip("victory", 90)
	stand = torso(STANCE, hips_turn=-8, fwd=-2, head_fwd=-6).but(hips=(0, 0.0, -0.02))
	stand = stand.but(ik=_feet(lf=(0.13, -0.08), rf=(-0.14, 0.08), lyaw=12, ryaw=-12))
	raise_ = with_hands(stand, lh=(0.24, 0.02, 1.02), rh=(-0.16, -0.06, 2.0), lpole=(1, 0.4, 0),
		rpole=(-1, 0.3, 0))
	raise_ = raise_.but(rot={"Head": spine(fwd=-14, turn=-8), "Chest": spine(fwd=-6, turn=4),
		"LeftHand": wrist(up=0)})
	settle = raise_.but(hips=(0, 0, -0.015), rot={"Head": spine(fwd=-10, turn=-8)})
	c.key(0, STANCE).key(14, stand, "io").key(26, raise_.but(hips=(0, 0, 0.01)), "out3").key(36, raise_, "io")
	c.key(60, settle, "io").key(89, raise_, "io")
	return c


def clip_defeat():
	c = Clip("defeat", 60)
	hurt = torso(STANCE, hips_turn=-10, fwd=18, head_fwd=10).but(hips=(0, 0.05, -0.16),
		drop_ik=("LeftHand", "RightHand"), rot={"LeftUpperArm": arm(down=70, fwd=25),
			"RightUpperArm": arm(down=72, fwd=15), "LeftLowerArm": elbow(40), "RightLowerArm": elbow(30)})
	hurt = hurt.but(rot=open_hand(5))
	kneel = torso(hurt, hips_turn=0, fwd=30, head_fwd=26).but(hips=(0, 0.1, -0.5), rot={
		"LeftUpperArm": arm(down=84, fwd=18), "RightUpperArm": arm(down=84, fwd=14),
		"LeftLowerArm": elbow(10), "RightLowerArm": elbow(12)})
	kneel = kneel.but(ik={
		"LeftFoot": ((0.13, 0.36, 0.05), (0.3, -1, -0.2), 5, -70),
		"RightFoot": ((-0.13, 0.36, 0.05), (-0.3, -1, -0.2), -5, -70),
	})
	c.key(0, STANCE).key(14, hurt, "out").key(34, kneel, "in").key(42, kneel.shifted(dz=0.015), "out")
	c.key(59, kneel, "io")
	return c


# --- Attacks -----------------------------------------------------------------------------------

def hands(left, right):
	"""Finger poses with a different shape per hand, e.g. hands(open_hand(5), fist())."""
	out = dict(left)
	out.update({"Right" + k[4:]: v for k, v in right.items()})
	return out


def clip_light_1(moves):
	s, a, r = _attack(moves, "light_1")
	c = Clip("light_1", s + a + r - 1)
	cock = torso(STANCE, hips_turn=-16, fwd=2)
	cock = with_hands(cock, lh=(0.08, -0.28, 1.39))
	hit = torso(STANCE, hips_turn=-34, fwd=8).but(hips=(0, -0.05, -0.09))
	ext = with_hands(hit, lh=(0.04, -0.6, 1.42), lpole=(1, 0.3, -0.5)).but(scale={"LeftLowerArm": 1.22})
	peak = with_hands(torso(hit, hips_turn=-38, fwd=9), lh=(0.0, -0.78, 1.43), lpole=(1, 0.3, -0.5)).but(
		scale={"LeftLowerArm": 1.1})
	back = with_hands(hit, lh=(0.05, -0.55, 1.42), lpole=(1, 0.3, -0.5))
	c.key(0, STANCE).key(s - 3, cock, "io").key(s, ext, "in").key(s + a // 2, peak, "out")
	c.key(s + a, back, "io").key(s + a + 4, with_hands(STANCE, lh=(0.06, -0.42, 1.41)), "out")
	c.key(s + a + r - 1, STANCE, "io")
	return c


def clip_light_2(moves):
	s, a, r = _attack(moves, "light_2")
	c = Clip("light_2", s + a + r - 1)
	coil = with_hands(torso(STANCE, hips_turn=-32, fwd=2), rh=(-0.1, -0.18, 1.35))
	hit = torso(STANCE, hips_turn=18, fwd=10).but(hips=(0, -0.07, -0.1))
	hit = hit.but(ik=_feet(rf=(-0.15, 0.2), ryaw=-10, rpitch=20, rz=G + 0.02))
	ext = with_hands(hit, lh=(0.1, -0.2, 1.4), rh=(-0.04, -0.6, 1.4), rpole=(-1, 0.3, -0.5)).but(
		scale={"RightLowerArm": 1.25})
	peak = with_hands(torso(hit, hips_turn=24, fwd=11), lh=(0.1, -0.2, 1.4), rh=(-0.02, -0.8, 1.4),
		rpole=(-1, 0.3, -0.5)).but(scale={"RightLowerArm": 1.1})
	back = with_hands(hit, lh=(0.08, -0.25, 1.4), rh=(-0.04, -0.56, 1.39), rpole=(-1, 0.3, -0.5))
	c.key(0, STANCE).key(s - 4, coil, "io").key(s, ext, "in").key(s + a // 2, peak, "out")
	c.key(s + a, back, "io").key(s + a + 5, with_hands(STANCE, rh=(-0.07, -0.36, 1.37)), "out")
	c.key(s + a + r - 1, STANCE, "io")
	return c


def clip_light_3(moves):
	s, a, r = _attack(moves, "light_3")
	c = Clip("light_3", s + a + r - 1)
	up = (0.4, 0.5, 0.75)
	wind = with_hands(torso(STANCE, hips_turn=-44, fwd=4), lh=(0.34, -0.12, 1.37), lpole=(1, 0.6, 0.2))
	start = with_hands(torso(STANCE, hips_turn=-8, fwd=8).but(hips=(0, -0.04, -0.09)), lh=(0.26, -0.5, 1.42),
		lpole=up).but(scale={"LeftUpperArm": 1.12})
	peak = with_hands(torso(STANCE, hips_turn=10, fwd=10).but(hips=(0, -0.05, -0.1)), lh=(0.06, -0.6, 1.42),
		lpole=(0.2, 0.6, 0.8))
	thru = with_hands(torso(STANCE, hips_turn=22, fwd=10).but(hips=(0, -0.05, -0.1)), lh=(-0.12, -0.5, 1.41),
		lpole=(0.1, 0.6, 0.8))
	follow = with_hands(torso(STANCE, hips_turn=30, fwd=8).but(hips=(0, -0.04, -0.1)), lh=(-0.2, -0.38, 1.39),
		lpole=(0.2, 0.7, 0.7))
	c.key(0, STANCE).key(s - 4, wind, "io").key(s, start, "in").key(s + 1, peak, "lin").key(s + 2, thru, "lin")
	c.key(s + a, follow, "out").key(s + a + 6, with_hands(torso(STANCE, hips_turn=0), lh=(0.0, -0.4, 1.4)), "io")
	c.key(s + a + r - 1, STANCE, "io")
	return c


def _airborne_legs(tuck=1.0):
	return {
		"LeftUpperLeg": leg(fwd=50 * tuck, out=5),
		"LeftLowerLeg": knee(95 * tuck),
		"LeftFoot": foot(-25),
	}


def clip_light_4(moves):
	"""Jumping spin heel kick with the right leg."""
	s, a, r = _attack(moves, "light_4")
	c = Clip("light_4", s + a + r - 1)
	crouch = torso(STANCE, hips_turn=-60, fwd=10).but(hips=(0, 0.02, -0.15))
	crouch = with_hands(crouch, lh=(0.12, -0.3, 1.3), rh=(-0.12, -0.2, 1.3))

	def spin(yaw, kick, hips_z, lean=22):
		rot = {
			"Hips": spine(turn=yaw, side=lean * 0.5),
			"Spine": spine(fwd=-4, side=lean * 0.6),
			"Chest": spine(side=lean * 0.4),
			"Head": spine(turn=0),
			"LeftUpperArm": arm(down=40, fwd=30),
			"LeftLowerArm": elbow(80),
			"RightUpperArm": arm(down=55, back=20),
			"RightLowerArm": elbow(70),
			"RightUpperLeg": leg(out=78 * kick + 10, fwd=12 * kick),
			"RightLowerLeg": knee(110 * (1 - kick) + 4),
			"RightFoot": foot(-25),
		}
		rot.update(_airborne_legs(0.9))
		rot.update(fist())
		# Head keeps facing the front while the body turns.
		rot["Neck"] = spine(turn=-yaw * 0.25)
		rot["Head"] = spine(turn=-yaw * 0.25)
		return Pose(rot, hips=(0, 0, hips_z))

	land = torso(STANCE, hips_turn=-22 - 360, fwd=12).but(hips=(0, 0.02, -0.16))
	land = with_hands(land, lh=(0.14, -0.32, 1.25), rh=(-0.14, -0.22, 1.22))
	c.key(0, STANCE).key(2, crouch, "io")
	c.key(5, spin(-130, 0.0, 0.08), "out")
	c.key(8, spin(-200, 0.55, 0.13), "lin")
	c.key(s, spin(-232, 0.95, 0.15).but(scale={"RightLowerLeg": 1.12}), "lin")
	c.key(s + 1, spin(-272, 1.0, 0.15), "out")
	c.key(s + 2, spin(-306, 0.95, 0.14), "lin")
	c.key(s + a + 2, spin(-345, 0.4, 0.08), "out")
	c.key(s + a + 7, land, "in")
	c.key(s + a + r - 1, torso(STANCE, hips_turn=-22 - 360), "io")
	return c


def _big_windup():
	p = torso(STANCE, hips_turn=-55, fwd=-8, head_turn=40).but(hips=(0, 0.06, -0.12))
	p = with_hands(p, lh=(0.16, -0.45, 1.42), rh=(-0.24, 0.16, 1.16), lpole=(0.8, 0.2, -1),
		rpole=(-0.5, 1, -0.3))
	return p.but(rot=dict(hands(open_hand(5), fist()), LeftHand=wrist(up=20)))


def _lunge(extra=0.0, turn=30):
	p = torso(STANCE, hips_turn=turn, fwd=14 + extra * 20).but(hips=(0, -0.12 - extra * 0.12, -0.13 - extra * 0.05))
	p = p.but(ik=_feet(lf=(0.13, -0.32 - extra * 0.2), rf=(-0.15, 0.24), ryaw=-5, rpitch=25, rz=G + 0.03))
	return p


def _straight(moves, mid, extra, lunge_turn=30):
	"""Shared straight-punch poses: first active tick, peak, held reach, retract and settle."""
	s, a, r = _attack(moves, mid)
	c = Clip(mid, s + a + r - 1)
	lunge = _lunge(extra, lunge_turn)
	ext = with_hands(lunge, lh=(0.14, -0.14, 1.36), rh=(-0.03, -0.64, 1.38), rpole=(-1, 0.4, -0.6)).but(
		scale={"RightLowerArm": 1.35, "RightUpperArm": 1.15})
	peak_lunge = torso(lunge, hips_turn=lunge_turn + 5, fwd=15 + extra * 20)
	peak = with_hands(peak_lunge, lh=(0.14, -0.12, 1.36), rh=(-0.0, -0.9, 1.38), rpole=(-1, 0.4, -0.6)).but(
		scale={"RightLowerArm": 1.12})
	hold = with_hands(peak_lunge, lh=(0.14, -0.12, 1.36), rh=(-0.01, -0.82, 1.38), rpole=(-1, 0.4, -0.6))
	back = with_hands(lunge, lh=(0.12, -0.18, 1.37), rh=(-0.03, -0.7, 1.37), rpole=(-1, 0.4, -0.6))
	settle = with_hands(torso(STANCE, hips_turn=0, fwd=8).but(hips=(0, -0.04, -0.1)), lh=(0.08, -0.3, 1.38),
		rh=(-0.06, -0.48, 1.36))
	return c, (s, a, r), ext, peak, hold, back, settle


def clip_smash(moves):
	windup = _big_windup()
	c, (s, a, r), ext, peak, hold, back, settle = _straight(moves, "smash", 0.0)
	c.key(0, STANCE).key(5, windup, "out").key(s - 2, windup.shifted(dz=-0.012), "io")
	c.key(s, ext, "in3").key(s + a // 2, peak, "out").key(s + a - 1, hold, "lin").key(s + a, back, "io")
	c.key(s + a + 9, settle, "out").key(s + a + r - 1, STANCE, "io")
	return c


def _hold_pose(level=0.0):
	p = torso(STANCE, hips_turn=-62 - level * 8, fwd=-6, side=-6, head_turn=44).but(
		hips=(0, 0.08, -0.13 - level * 0.03))
	p = with_hands(p, lh=(0.18, -0.42, 1.38), rh=(-0.26, 0.24, 1.2), lpole=(0.8, 0.2, -1),
		rpole=(-0.4, 1, -0.2))
	return p.but(rot=dict(hands(open_hand(8), fist()), LeftHand=wrist(up=25)))


def clip_charged_smash_hold():
	c = Clip("charged_smash_hold", 40, loop=True, jitter=0.005, hair_lift=0.6)
	a = _hold_pose()
	b = a.shifted(dz=-0.01)
	c.key(0, a).key(20, b).key(40, a)
	return c


def clip_charged_smash(moves, level):
	mid = "charged_smash_%d" % level
	windup = _hold_pose(level / 3.0)
	extra = 0.3 + level * 0.25
	c, (s, a, r), ext, peak, hold, back, settle = _straight(moves, mid, extra, 30 + level * 4)
	if level == 3:
		# Level 3 adds the left palm, a two-handed burst.
		ext = ext.but(ik={"LeftHand": ((0.1, -0.56, 1.3), (1, 0.3, -0.6))})
		palm = hands(open_hand(10), fist())
		peak = peak.but(ik={"LeftHand": ((0.08, -0.7, 1.28), (1, 0.3, -0.6))}, rot=palm)
		hold = hold.but(ik={"LeftHand": ((0.09, -0.66, 1.28), (1, 0.3, -0.6))}, rot=palm)
	c.key(0, windup).key(s - 3, windup.shifted(dy=0.03, dz=-0.02), "io")
	c.key(s, ext, "in3").key(s + a // 2, peak, "out").key(s + a - 1, hold, "lin").key(s + a, back, "io")
	c.key(s + a + 10, settle, "out").key(s + a + r - 1, STANCE, "io")
	return c


def clip_breaker(moves):
	s, a, r = _attack(moves, "breaker")
	c = Clip("breaker", s + a + r - 1)
	up_pose = torso(STANCE, hips_turn=-10, fwd=-14).but(hips=(0, 0.04, -0.03), rot={
		"Head": spine(fwd=-8), "UpperChest": spine(fwd=-8)})
	up_pose = up_pose.but(ik={
		"LeftHand": ((0.035, 0.06, 1.98), (1, 0.2, 0.1)),
		"RightHand": ((-0.035, 0.06, 1.98), (-1, 0.2, 0.1)),
	})
	up_hold = up_pose.but(hips=(0, 0.05, -0.02), rot={"Spine": spine(fwd=-18, turn=6)})
	swing = torso(STANCE, hips_turn=-6, fwd=22, hips_fwd=8).but(hips=(0, -0.08, -0.14))
	swing = swing.but(ik=_feet(lf=(0.13, -0.32), rf=(-0.15, 0.22), rpitch=20, rz=G + 0.02))

	def hands(y, z, pole_z=-0.3):
		return {"LeftHand": ((0.035, y, z), (1, 0.4, pole_z)), "RightHand": ((-0.035, y, z), (-1, 0.4, pole_z))}

	ext = swing.but(ik=hands(-0.58, 1.5), scale={"LeftLowerArm": 1.2, "RightLowerArm": 1.2})
	peak = torso(swing, hips_turn=-6, fwd=28, hips_fwd=10).but(ik=hands(-0.66, 1.24))
	low = torso(swing, hips_turn=-6, fwd=32, hips_fwd=12).but(ik=hands(-0.58, 1.02))
	follow = torso(swing, hips_turn=-6, fwd=34, hips_fwd=12).but(ik=hands(-0.48, 0.86), hips=(0, -0.08, -0.17))
	c.key(0, STANCE).key(9, up_pose, "out").key(s - 2, up_hold, "io")
	c.key(s, ext, "in3").key(s + 1, peak, "lin").key(s + 2, peak.but(ik=hands(-0.65, 1.18)), "lin")
	c.key(s + a - 1, low, "lin").key(s + a, follow, "out").key(s + a + 8, follow, "lin")
	c.key(s + a + r - 1, STANCE, "io")
	return c


def clip_launcher(moves):
	s, a, r = _attack(moves, "launcher")
	c = Clip("launcher", s + a + r - 1)
	crouch = torso(STANCE, hips_turn=-38, fwd=18).but(hips=(0, 0.02, -0.25))
	crouch = crouch.but(ik=_feet(lf=(0.15, -0.2), rf=(-0.17, 0.22)))
	crouch = with_hands(crouch, lh=(0.12, -0.34, 1.2), rh=(-0.16, -0.16, 0.86), rpole=(-0.6, 0.6, -0.4))
	rise0 = torso(STANCE, hips_turn=0, fwd=10).but(hips=(0, -0.04, -0.15))
	rise0 = with_hands(rise0, lh=(0.12, -0.22, 1.3), rh=(-0.06, -0.46, 0.92), rpole=(-0.6, 0.6, -0.8)).but(
		scale={"RightLowerArm": 1.2})
	rise1 = torso(STANCE, hips_turn=14, fwd=4).but(hips=(0, -0.05, -0.06))
	rise1 = with_hands(rise1, lh=(0.13, -0.18, 1.32), rh=(-0.02, -0.6, 1.08), rpole=(-0.5, 0.6, -1))
	rise2 = torso(STANCE, hips_turn=20, fwd=-4).but(hips=(0, -0.05, 0.02))
	rise2 = with_hands(rise2, lh=(0.14, -0.14, 1.32), rh=(-0.02, -0.46, 1.45), rpole=(-0.5, 0.8, -1))
	top = torso(STANCE, hips_turn=24, fwd=-10, head_fwd=-14).but(hips=(0, -0.04, 0.05))
	top = top.but(ik=_feet(lf=(0.13, -0.2), rf=(-0.15, 0.2), lpitch=20, rpitch=25, lz=G + 0.03, rz=G + 0.04))
	top = with_hands(top, lh=(0.16, -0.12, 1.28), rh=(-0.06, -0.26, 1.98), rpole=(-1, 0.6, -0.2))
	c.key(0, STANCE).key(6, crouch, "out").key(s - 2, crouch.shifted(dz=-0.01), "io")
	c.key(s, rise0, "in").key(s + 1, rise1, "lin").key(s + 2, rise2, "lin").key(s + a + 1, top, "out")
	c.key(s + a + 9, top.shifted(dz=-0.01), "io").key(s + a + r - 1, STANCE, "io")
	return c


def clip_rising(moves):
	"""Anti-air flip kick: jump, the right leg kicks up through the hitbox, then a backflip to land."""
	s, a, r = _attack(moves, "rising")
	c = Clip("rising", s + a + r - 1)
	crouch = torso(STANCE, hips_turn=-10, fwd=20).but(hips=(0, 0.02, -0.2))
	crouch = with_hands(crouch, lh=(0.2, 0.0, 1.15), rh=(-0.2, 0.05, 1.12), lpole=(1, 0.5, 0), rpole=(-1, 0.5, 0))

	def air(pitch, kick, hips_z, tuck=0.0):
		rot = {
			"Hips": spine(fwd=pitch),
			"Spine": spine(fwd=6),
			"Chest": spine(fwd=4),
			"Neck": spine(fwd=10),
			"Head": spine(fwd=8),
			"LeftUpperArm": arm(down=35, back=30),
			"RightUpperArm": arm(down=35, back=30),
			"LeftLowerArm": elbow(40),
			"RightLowerArm": elbow(40),
			"RightUpperLeg": leg(fwd=kick + tuck * 40),
			"RightLowerLeg": knee(4 + tuck * 100),
			"RightFoot": foot(-30),
			"LeftUpperLeg": leg(fwd=40 + tuck * 50, out=4),
			"LeftLowerLeg": knee(95 + tuck * 30),
			"LeftFoot": foot(-30),
		}
		rot.update(fist())
		return Pose(rot, hips=(0, 0.0, hips_z))

	land = torso(STANCE, hips_turn=-22, fwd=22).but(hips=(0, 0.04, -0.22))
	land = with_hands(land, lh=(0.22, -0.2, 1.1), rh=(-0.24, -0.1, 1.08))
	c.key(0, STANCE).key(5, crouch, "out")
	c.key(s - 1, air(-20, 70, 0.1), "in")
	c.key(s, air(-45, 100, 0.18).but(scale={"RightLowerLeg": 1.15}), "lin")
	c.key(s + 1, air(-62, 92, 0.24), "out")
	c.key(s + 2, air(-80, 90, 0.27), "lin")
	c.key(s + 3, air(-104, 80, 0.28, 0.2), "lin")
	c.key(s + a + 3, air(-170, 40, 0.26, 0.9), "lin")
	c.key(s + a + 8, air(-250, 30, 0.12, 1.0), "lin")
	c.key(s + a + 13, air(-330, 20, -0.08, 0.6), "lin")
	c.key(s + a + 15, Pose(dict(land.rot, Hips=spine(fwd=22 - 360 + 360)), land.ik, land.hips), "out")
	c.key(s + a + r - 1, STANCE, "io")
	return c


def clip_spike(moves):
	"""Axe kick: the right leg rises straight up, then chops down through the hitbox."""
	s, a, r = _attack(moves, "spike")
	c = Clip("spike", s + a + r - 1)
	prep = torso(STANCE, hips_turn=-10, fwd=8).but(hips=(0, 0.02, -0.12))

	def kick(raise_deg, hips_z, lean, knee_bend=4):
		p = torso(STANCE, hips_turn=-4, fwd=lean, head_fwd=10).but(hips=(0, 0.04, hips_z),
			drop_ik=("RightFoot",))
		p = p.but(rot={"RightUpperLeg": leg(fwd=raise_deg), "RightLowerLeg": knee(knee_bend),
			"RightFoot": foot(-30)})
		p = p.but(ik={"LeftFoot": ((0.11, -0.05, G + max(0.0, hips_z + 0.02)), (0.2, -1, 0), 10,
			-30 if hips_z > 0 else 0)})
		return with_hands(p, lh=(0.3, -0.1, 1.3), rh=(-0.3, 0.0, 1.32), lpole=(1, 0.5, -0.5),
			rpole=(-1, 0.5, -0.5))

	c.key(0, STANCE).key(5, prep, "out")
	c.key(11, kick(150, 0.08, -18, 30), "out").key(s - 1, kick(172, 0.1, -20), "io")
	c.key(s, kick(142, 0.08, -6).but(scale={"RightUpperLeg": 1.08}), "in3")
	c.key(s + 1, kick(108, 0.05, 6), "lin").key(s + 2, kick(74, 0.0, 12), "lin")
	slam = torso(STANCE, hips_turn=-10, fwd=18).but(hips=(0, -0.04, -0.18))
	slam = slam.but(ik=_feet(lf=(0.12, -0.05), rf=(-0.13, -0.42), ryaw=-5))
	slam = with_hands(slam, lh=(0.28, -0.2, 1.15), rh=(-0.3, -0.05, 1.2))
	c.key(s + a + 3, slam, "in").key(s + a + 12, slam.shifted(dz=-0.01), "io")
	c.key(s + a + r - 1, STANCE, "io")
	return c


def clip_sweep(moves):
	"""Low spinning sweep with the right leg; the leg passes straight ahead mid-active."""
	s, a, r = _attack(moves, "sweep")
	c = Clip("sweep", s + a + r - 1)

	def low(yaw, ext, hips_z=-0.6):
		rot = {
			"Hips": spine(turn=yaw, fwd=10),
			"Spine": spine(fwd=22),
			"Chest": spine(fwd=8),
			"Neck": spine(fwd=-20, turn=-yaw * 0.2),
			"Head": spine(fwd=-14, turn=-yaw * 0.2),
			"LeftUpperLeg": leg(fwd=78, out=25),
			"LeftLowerLeg": knee(145),
			"LeftFoot": foot(-10),
			"RightUpperLeg": leg(out=60 * ext + 15, fwd=8 * ext),
			"RightLowerLeg": knee(90 * (1 - ext) + 3),
			"RightFoot": foot(-20),
			"LeftUpperArm": arm(down=70, fwd=50),
			"LeftLowerArm": elbow(20),
			"RightUpperArm": arm(down=50, fwd=10),
			"RightLowerArm": elbow(20),
		}
		rot.update(open_hand(10))
		return Pose(rot, hips=(0, 0, hips_z))

	land = torso(STANCE, hips_turn=-22 + 360, fwd=14).but(hips=(0, 0.02, -0.18))
	c.key(0, STANCE).key(4, low(-55, 0.2, -0.4), "out").key(8, low(-15, 0.75), "io")
	c.key(s, low(42, 1.0).but(scale={"RightLowerLeg": 1.1}), "in").key(s + 1, low(66, 1.0), "lin")
	c.key(s + 2, low(90, 1.0), "lin").key(s + 3, low(114, 1.0), "lin").key(s + 4, low(138, 1.0), "lin")
	c.key(s + a + 3, low(200, 0.7), "out").key(s + a + 9, low(270, 0.3, -0.45), "io")
	c.key(s + a + r - 1, Pose(land.rot, STANCE.ik, land.hips), "io")
	return c


def clip_push_block(moves):
	s, a, r = _attack(moves, "push_block")
	c = Clip("push_block", s + a + r - 1)
	base = _block_pose()
	push = torso(STANCE, hips_turn=-6, fwd=10).but(hips=(0, -0.05, -0.1), rot=dict(open_hand(4), **{
		"LeftHand": wrist(up=55), "RightHand": wrist(up=55)}))

	def palms(y):
		return {"LeftHand": ((0.09, y, 1.36), (1, 0.4, -0.6)), "RightHand": ((-0.09, y, 1.36), (-1, 0.4, -0.6))}

	c.key(0, base).key(s, push.but(ik=palms(-0.5)), "in").key(s + 1, push.but(ik=palms(-0.6)), "out")
	c.key(s + a, push.but(ik=palms(-0.52)), "io").key(s + a + r - 1, STANCE, "io")
	return c


def all_clips(moves):
	clips = [clip_idle(), clip_run(), clip_fly_hover(), clip_fly_forward(), clip_dash(), clip_charge_ki(),
		clip_fall(), clip_block(), clip_blockstun(), clip_hitstun_light(), clip_hitstun_heavy(),
		clip_guard_broken(), clip_knockdown(), clip_get_up(), clip_victory(), clip_defeat(),
		clip_light_1(moves), clip_light_2(moves), clip_light_3(moves), clip_light_4(moves),
		clip_smash(moves), clip_breaker(moves), clip_launcher(moves), clip_rising(moves),
		clip_spike(moves), clip_sweep(moves), clip_charged_smash_hold(), clip_push_block(moves)]
	clips += [clip_charged_smash(moves, n) for n in (1, 2, 3)]
	return clips


# --- Baking --------------------------------------------------------------------------------------

def _slerp(a, b, t):
	"""Shortest-path slerp that also extrapolates (t outside 0..1) for overshoot easing."""
	if a.dot(b) < 0:
		b = -b
	diff = a.inverted() @ b
	axis, angle = diff.to_axis_angle()
	return a @ Quaternion(axis, angle * t)


def _align(q, ref):
	return -q if q.dot(ref) < 0 else q


def sample_clip(rig, clip):
	"""Per-frame (local D rotations, hips offset, scales) for frames 0..length."""
	keys = sorted(clip.keys, key=lambda k: k[0])
	solved = []
	for frame, pose, kind in keys:
		solved.append(rig.solve(pose))
	# Keep each key's quaternions on the same hemisphere as the previous key, so spins go the long way.
	frames = []
	rnd = random.Random(zlib.crc32(clip.name.encode()))
	for f in range(clip.length + 1):
		i = 0
		while i < len(keys) - 1 and keys[i + 1][0] < f:
			i += 1
		if f <= keys[0][0]:
			i, t = 0, 0.0
			j = 0
		elif f >= keys[-1][0]:
			i = j = len(keys) - 1
			t = 0.0
		else:
			j = i + 1
			span = keys[j][0] - keys[i][0]
			t = ease(keys[j][2], (f - keys[i][0]) / span)
		pa, pb = keys[i][1], keys[j][1]
		la, lb = solved[i], solved[j]
		local = {name: _slerp(la[name], lb[name], t) for name in la}
		hips = pa.hips.lerp(pb.hips, t)
		scale = {}
		for name in sorted(set(pa.scale) | set(pb.scale)):
			scale[name] = pa.scale.get(name, 1.0) * (1 - t) + pb.scale.get(name, 1.0) * t
		ik = {}
		for end in sorted(set(pa.ik) & set(pb.ik)):
			ga, gb = pa.ik[end], pb.ik[end]
			goal = [Vector(ga[0]).lerp(Vector(gb[0]), t), Vector(ga[1]).lerp(Vector(gb[1]), t)]
			if len(ga) > 2 or len(gb) > 2:
				ya = ga[2] if len(ga) > 2 else 0.0
				yb = gb[2] if len(gb) > 2 else 0.0
				pa_ = ga[3] if len(ga) > 3 else 0.0
				pb_ = gb[3] if len(gb) > 3 else 0.0
				goal += [ya + (yb - ya) * t, pa_ + (pb_ - pa_) * t]
			ik[end] = goal
		if clip.jitter and 0 < f < clip.length:
			j_amp = clip.jitter
			for end in ik:
				if end.endswith("Hand"):
					ik[end][0] = ik[end][0] + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1),
						rnd.uniform(-1, 1))) * j_amp
			hips = hips + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * j_amp * 0.6
		pose = Pose(hips=hips)
		local = rig.solve(pose, local, ik)
		frames.append((local, hips, scale))
	return frames


def add_hair(rig, clip, frames):
	"""Secondary motion: hair bones trail the head's motion and rotation, plus an optional upward flare."""
	heads = []
	for local, hips, _ in frames:
		world, pos = rig.fk(local, hips)
		heads.append((world["Head"], pos["Head"]))
	n = len(frames)
	hair = ["HairTop", "HairBack", "HairLeft", "HairRight", "HairFront"]
	for f in range(n):
		def at(k):
			if clip.loop:
				return heads[(f - k) % (n - 1)]
			return heads[max(0, f - k)]
		w_now, p_now = heads[f]
		w_old, p_old = at(4)
		vel = (p_now - at(2)[1]) * (FPS / 2.0)
		axis = vel.cross(Vector((0, 0, 1)))
		ang = min(math.radians(28), vel.length * 0.09)
		q_move = Quaternion(axis.normalized(), ang) if axis.length > 1e-6 else Quaternion()
		q_turn = Quaternion().slerp(w_old @ w_now.inverted(), 0.55)
		q_world = q_turn @ q_move
		local = frames[f][0]
		for i, h in enumerate(hair):
			lift = Quaternion()
			if clip.hair_lift:
				phase = math.sin(f * 0.9 + i * 1.7)
				lift = Quaternion((1, 0, 0), math.radians(-clip.hair_lift * (8 + 4 * phase)))
			sway = Quaternion((0, 1, 0), math.radians(1.5 * math.sin(2 * math.pi * f / max(n - 1, 1) + i)))
			local[h] = w_now.inverted() @ q_world @ w_now @ lift @ sway


def strike_frames(rig, clip, frames, moves):
	"""(argmin frame, distances) of the strike bone to the move's mean active hitbox centre."""
	target = moves[clip.name]["hitbox"]
	bone = STRIKE_BONES[clip.name]
	dists = []
	for local, hips, _ in frames:
		_, pos = rig.fk(local, hips)
		dists.append((pos[bone] - target).length)
	best = min(range(len(dists)), key=lambda k: dists[k])
	return best, dists


def write_action(arm_obj, rig, clip, frames):
	action = bpy.data.actions.new(clip.name)
	action.use_fake_user = True
	arm_obj.animation_data_create()
	arm_obj.animation_data.action = action
	rest = {b.name: b.matrix_local.to_quaternion() for b in arm_obj.data.bones}
	scaled = set()
	for _, _, scale in frames:
		scaled |= set(scale)
	channels = {}
	prev = {}
	for f, (local, hips, scale) in enumerate(frames):
		bone_q = rig.to_bone_space(rest, local)
		for name, q in bone_q.items():
			if name == "Root":
				continue
			q = _align(q, prev.get(name, Quaternion()))
			prev[name] = q
			for i in range(4):
				channels.setdefault(('pose.bones["%s"].rotation_quaternion' % name, i, name), []).append((f, q[i]))
		loc = rest["Hips"].inverted() @ hips
		for i in range(3):
			channels.setdefault(('pose.bones["Hips"].location', i, "Hips"), []).append((f, loc[i]))
		for name in sorted(scaled):
			s = scale.get(name, 1.0)
			side = 1.0 / math.sqrt(s)
			for i, v in enumerate((side, s, side)):
				channels.setdefault(('pose.bones["%s"].scale' % name, i, name), []).append((f, v))
	for (path, index, group), keys in channels.items():
		fc = action.fcurve_ensure_for_datablock(arm_obj, path, index=index, group_name=group)
		fc.keyframe_points.add(len(keys))
		flat = [c for k in keys for c in k]
		fc.keyframe_points.foreach_set("co", flat)
		for kp in fc.keyframe_points:
			kp.interpolation = "LINEAR"
		fc.update()
	action.frame_range = (0, clip.length)
	return action


def build_all(arm_obj):
	"""Bakes every clip into an action on the armature; returns the strike timing table."""
	rig = Rig(kael_rig.bone_layout())
	moves = kael_moves.load_moves()
	table = []
	for clip in all_clips(moves):
		frames = sample_clip(rig, clip)
		add_hair(rig, clip, frames)
		write_action(arm_obj, rig, clip, frames)
		if clip.name in STRIKE_BONES:
			m = moves[clip.name]
			best, _ = strike_frames(rig, clip, frames, moves)
			s, a = m["startup"], m["active"]
			ok = s - 1 <= best <= s + a
			table.append((clip.name, s, a, m["recovery"], best, ok))
	arm_obj.animation_data.action = None
	print("strike timing (move, startup, active, recovery, peak frame, inside active +-1):")
	for row in table:
		print("  %-16s S=%2d A=%d R=%2d peak=%2d %s" % (row[0], row[1], row[2], row[3], row[4],
			"ok" if row[5] else "OUTSIDE"))
	return table
