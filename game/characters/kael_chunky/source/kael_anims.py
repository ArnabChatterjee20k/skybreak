"""Chunky Kael's own clips: key poses in code, baked at 60 fps. Snappy and exaggerated: big
anticipation, squash on the wind-up, stretch on the hit (scale tracks on Hips and Chest).

Attack clips follow the sim's frame data (kael_moves): clip frame f = move_tick f, the strike peaks
inside the active ticks. The hips never move horizontally and the Root is never keyed, so there is
no root motion. Shared humanoid clips (tools/build_kael_chunky_clips.gd) cover the other states.
"""

import math
import random
import zlib

import bpy
from mathutils import Quaternion, Vector

import kael_moves
import kael_rig
from kael_pose import Pose, Rig, arm, ease, elbow, fist, foot, knee, leg, open_hand, spine

G = 0.13  # Ankle height with the foot flat on the ground.
FPS = 60
HIPS_Z = 0.80

# Striking point of each attack (a bone head) for the timing check.
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
	"grab": "LeftMiddleProximal",
}


def feet(lf=(0.2, -0.16), rf=(-0.18, 0.2), lyaw=12, ryaw=-35, lz=G, rz=G, lpitch=0.0, rpitch=0.0):
	return {
		"LeftFoot": ((lf[0], lf[1], lz), (0.4, -1, 0), lyaw, lpitch),
		"RightFoot": ((rf[0], rf[1], rz), (-0.4, -1, 0), ryaw, rpitch),
	}


LPOLE = (0.8, 0.3, -1)
RPOLE = (-0.8, 0.4, -1)
GUARD_L = (0.21, -0.38, 1.07)
GUARD_R = (-0.05, -0.33, 1.01)


def body(turn=-25.0, lean=6.0, side=0.0, hz=-0.07, head_pitch=0.0, head_turn=0.0, lh=GUARD_L, rh=GUARD_R,
		lpole=LPOLE, rpole=RPOLE, legs=None, scale=None, fingers=None, extra=None):
	"""A full pose: the torso turned (+ = to his left) and leaned forward, the head kept on the
	target, hands by IK (None = FK from extra), feet by IK (legs, or the stance)."""
	wraps = 360.0 * round(turn / 360.0)  # Whole turns (after a spin) go on the hips only.
	turn -= wraps
	rot = {
		"Hips": spine(fwd=lean * 0.2, side=side * 0.3, turn=wraps + turn * 0.5),
		"Spine": spine(fwd=lean * 0.4, side=side * 0.35, turn=turn * 0.25),
		"Chest": spine(fwd=lean * 0.4, side=side * 0.35, turn=turn * 0.25),
		"Neck": spine(fwd=-lean * 0.45 + head_pitch * 0.5, side=-side * 0.4, turn=-turn * 0.45 + head_turn * 0.5),
		"Head": spine(fwd=-lean * 0.45 + head_pitch * 0.5, side=-side * 0.4, turn=-turn * 0.45 + head_turn * 0.5),
	}
	rot.update(fingers if fingers is not None else fist())
	rot.update(extra or {})
	ik = dict(feet() if legs is None else legs)
	if lh is not None:
		ik["LeftHand"] = (lh, lpole)
	if rh is not None:
		ik["RightHand"] = (rh, rpole)
	return Pose(rot, ik, hips=(0, 0.02, hz), scale=scale)


STANCE = body()


def hands(left, right):
	"""Finger poses with a different shape per hand, e.g. hands(open_hand(8), fist())."""
	out = dict(left)
	out.update({"Right" + k[4:]: v for k, v in right.items()})
	return out


class Clip:
	def __init__(self, name, length, loop=False, jitter=0.0):
		self.name = name
		self.length = length  # Last frame index; a loop's last frame equals its first.
		self.loop = loop
		self.keys = []  # (frame, Pose, ease into this key)
		self.jitter = jitter

	def key(self, frame, pose, kind="io"):
		self.keys.append((int(round(frame)), pose, kind))
		return self


def _sar(moves, mid):
	m = moves[mid]
	return m["startup"], m["active"], m["recovery"]


def _attack_clip(moves, mid):
	s, a, r = _sar(moves, mid)
	return Clip(mid, s + a + r), s, a, r


# --- Stance, power-up and flight -----------------------------------------------------------------

def clip_idle():
	"""Bouncy fighting stance: a springy bob with a little squash at the bottom."""
	c = Clip("idle", 48, loop=True)
	down = body(hz=-0.1, lean=8, lh=(0.21, -0.38, 1.04), rh=(-0.05, -0.33, 0.985), head_pitch=3,
		scale={"Chest": 0.96, "Hips": 0.98})
	up = body(hz=-0.06, lean=5, lh=(0.21, -0.38, 1.085), rh=(-0.05, -0.33, 1.025), scale={"Chest": 1.02})
	c.key(0, up).key(24, down, "io").key(48, up, "io")
	return c


def _power_pose(k):
	"""Horse stance, chest out, fists driven down and out, head thrown back."""
	return body(turn=0, lean=-10 - 4 * k, hz=-0.17, lh=None, rh=None, head_pitch=-14 - 6 * k,
		legs=feet(lf=(0.3, -0.04), rf=(-0.3, -0.04), lyaw=25, ryaw=-25),
		scale={"Chest": 1.0 + 0.06 * k, "Hips": 0.97},
		extra={"LeftShoulder": spine(side=-6 - 4 * k), "LeftUpperArm": arm(down=52 - 6 * k, fwd=12),
			"LeftLowerArm": elbow(35 + 10 * k), "LeftHand": spine(side=-15)})


def clip_power_up():
	"""Charging ki: a trembling power-up that swells and settles."""
	c = Clip("power_up", 40, loop=True, jitter=0.006)
	c.key(0, _power_pose(0.0)).key(20, _power_pose(1.0), "io").key(40, _power_pose(0.0), "io")
	return c


def _hover_pose(k):
	return Pose({
		"Hips": spine(fwd=4 + 2 * k, side=2 * k),
		"Spine": spine(fwd=4), "Chest": spine(fwd=2 - 3 * k), "Neck": spine(fwd=-4), "Head": spine(fwd=-4 + 2 * k),
		"LeftUpperLeg": leg(fwd=34 + 6 * k, out=6), "LeftLowerLeg": knee(70 + 8 * k), "LeftFoot": foot(-30),
		"RightUpperLeg": leg(fwd=8 - 4 * k, out=4), "RightLowerLeg": knee(28 + 6 * k), "RightFoot": foot(-40),
		"LeftUpperArm": arm(down=58 - 5 * k, fwd=22), "LeftLowerArm": elbow(70),
		"RightUpperArm": arm(down=62 - 5 * k, fwd=14), "RightLowerArm": elbow(60),
		**fist(0.85),
	}, hips=(0, 0.0, 0.03 * k))


def clip_hover():
	c = Clip("hover", 60, loop=True)
	c.key(0, _hover_pose(0.0)).key(30, _hover_pose(1.0), "io").key(60, _hover_pose(0.0), "io")
	return c


def _fly_pose(k):
	"""Fast flight: diving forward, chest leading, fists swept back, legs trailing."""
	return Pose({
		"Hips": spine(fwd=52 + 3 * k),
		"Spine": spine(fwd=6), "Chest": spine(fwd=4, side=2 * k), "Neck": spine(fwd=-32), "Head": spine(fwd=-26),
		"LeftUpperLeg": leg(fwd=-6 + 4 * k, out=3), "LeftLowerLeg": knee(30 - 8 * k), "LeftFoot": foot(-45),
		"RightUpperLeg": leg(fwd=6 - 4 * k, out=3), "RightLowerLeg": knee(48 + 8 * k), "RightFoot": foot(-45),
		"LeftShoulder": spine(side=-6),
		"LeftUpperArm": arm(down=62, back=34 + 4 * k), "LeftLowerArm": elbow(18),
		"RightUpperArm": arm(down=62, back=36 - 4 * k), "RightLowerArm": elbow(22),
		**fist(),
	}, hips=(0, 0.0, 0.0), scale={"Chest": 1.03})


def clip_fly():
	c = Clip("fly", 40, loop=True)
	c.key(0, _fly_pose(0.0)).key(20, _fly_pose(1.0), "io").key(40, _fly_pose(0.0), "io")
	return c


def _smash_cock(k=1.0):
	"""Big wind-up: torso coiled to his right, right fist cocked by the ear, front hand reaching."""
	return body(turn=-62 * k - 25 * (1 - k), lean=-4, hz=-0.13, lh=(0.3, -0.42, 1.2), rh=(-0.34, 0.22, 1.2),
		rpole=(-0.5, 0.4, -1), scale={"Chest": 0.88, "Hips": 0.95}, head_turn=8,
		fingers=hands(open_hand(10), fist()))


def clip_smash_hold():
	"""Holding a charged smash: the wind-up, trembling."""
	c = Clip("smash_hold", 30, loop=True, jitter=0.007)
	c.key(0, _smash_cock()).key(15, _smash_cock().but(scale={"Chest": 0.85, "Hips": 0.94}), "io")
	c.key(30, _smash_cock(), "io")
	return c


# --- Attacks -------------------------------------------------------------------------------------

def clip_light_1(moves):
	"""Jab: a quick left, the chest stretching into it."""
	c, s, a, r = _attack_clip(moves, "light_1")
	cock = body(turn=-30, lean=4, lh=(0.17, -0.27, 1.18), scale={"Chest": 0.93})
	ext = body(turn=-42, lean=11, lh=(0.06, -0.72, 1.3), lpole=(1, 0.3, -0.4),
		scale={"Chest": 1.07, "LeftLowerArm": 1.14}, legs=feet(lf=(0.2, -0.22)))
	peak = body(turn=-46, lean=12, lh=(0.03, -0.82, 1.3), lpole=(1, 0.3, -0.4),
		scale={"Chest": 1.05, "LeftLowerArm": 1.06}, legs=feet(lf=(0.2, -0.22)))
	back = body(turn=-38, lean=9, lh=(0.06, -0.62, 1.28), lpole=(1, 0.3, -0.4), legs=feet(lf=(0.2, -0.22)))
	c.key(0, STANCE).key(s - 3, cock, "out").key(s, ext, "in").key(s + 1, peak, "out").key(s + a, back, "io")
	c.key(s + a + 4, body(lh=(0.13, -0.45, 1.2)), "out").key(c.length, STANCE, "io")
	return c


def clip_light_2(moves):
	"""Cross: the hips whip round and the right fist fires straight through."""
	c, s, a, r = _attack_clip(moves, "light_2")
	coil = body(turn=-42, lean=3, rh=(-0.14, -0.18, 1.14), scale={"Chest": 0.92})
	legs = feet(rf=(-0.18, 0.2), ryaw=-8, rpitch=25, rz=G + 0.03)
	ext = body(turn=22, lean=13, lh=(0.14, -0.22, 1.17), rh=(-0.12, -0.72, 1.3), rpole=(-1, 0.3, -0.4),
		legs=legs, scale={"Chest": 1.08, "RightLowerArm": 1.15})
	peak = body(turn=28, lean=14, lh=(0.14, -0.22, 1.17), rh=(-0.12, -0.82, 1.3), rpole=(-1, 0.3, -0.4),
		legs=legs, scale={"Chest": 1.05, "RightLowerArm": 1.05})
	back = body(turn=20, lean=11, lh=(0.13, -0.25, 1.17), rh=(-0.12, -0.6, 1.27), rpole=(-1, 0.3, -0.4), legs=legs)
	c.key(0, STANCE).key(s - 4, coil, "out").key(s, ext, "in").key(s + 1, peak, "out").key(s + a, back, "io")
	c.key(s + a + 5, body(turn=-5, rh=(-0.1, -0.42, 1.16)), "out").key(c.length, STANCE, "io")
	return c


def clip_light_3(moves):
	"""Hook: a wide left swing, the elbow up, the whole torso rotating through."""
	c, s, a, r = _attack_clip(moves, "light_3")
	up = (0.5, 0.5, 0.8)
	wind = body(turn=-58, lean=5, lh=(0.46, -0.12, 1.2), lpole=(1, 0.6, 0.2), scale={"Chest": 0.9})
	start = body(turn=-20, lean=10, lh=(0.32, -0.56, 1.25), lpole=up, scale={"Chest": 1.06, "LeftUpperArm": 1.1})
	peak = body(turn=4, lean=12, lh=(0.06, -0.72, 1.25), lpole=(0.2, 0.6, 0.8), scale={"Chest": 1.06})
	thru = body(turn=20, lean=12, lh=(-0.14, -0.6, 1.23), lpole=(0.1, 0.6, 0.8), scale={"Chest": 1.03})
	follow = body(turn=32, lean=9, lh=(-0.24, -0.42, 1.2), lpole=(0.2, 0.7, 0.7))
	c.key(0, STANCE).key(s - 4, wind, "out").key(s, start, "in").key(s + 1, peak, "lin").key(s + 2, thru, "lin")
	c.key(s + a, follow, "out").key(s + a + 7, body(turn=-10, lh=(0.08, -0.42, 1.18)), "io")
	c.key(c.length, STANCE, "io")
	return c


def _wrapped(yaw):
	return (yaw + 180.0) % 360.0 - 180.0


def _spin_kick(yaw, kick, hz, lean=26, scale=None):
	"""Airborne spin with the right leg swinging out as a heel kick; the head keeps the target."""
	look = -_wrapped(yaw) * 0.42
	rot = {
		"Hips": spine(turn=yaw, side=lean * 0.5),
		"Spine": spine(fwd=-4, side=lean * 0.6),
		"Chest": spine(side=lean * 0.4),
		"Neck": spine(turn=look, side=-lean * 0.5),
		"Head": spine(turn=look, side=-lean * 0.4),
		"LeftUpperArm": arm(down=35, fwd=35), "LeftLowerArm": elbow(85),
		"RightUpperArm": arm(down=50, back=25), "RightLowerArm": elbow(70),
		"LeftUpperLeg": leg(fwd=55, out=5), "LeftLowerLeg": knee(100), "LeftFoot": foot(-25),
		"RightUpperLeg": leg(out=82 * kick + 8, fwd=10 * kick), "RightLowerLeg": knee(115 * (1 - kick) + 3),
		"RightFoot": foot(-20),
	}
	rot.update(fist())
	return Pose(rot, hips=(0, 0.02, hz), scale=scale)


def clip_light_4(moves):
	"""Jumping spin heel kick with the right leg."""
	c, s, a, r = _attack_clip(moves, "light_4")
	crouch = body(turn=-60, lean=14, hz=-0.17, lh=(0.16, -0.32, 1.08), rh=(-0.14, -0.22, 1.05),
		scale={"Chest": 0.86, "Hips": 0.93})
	c.key(0, STANCE).key(3, crouch, "out")
	c.key(6, _spin_kick(-140, 0.0, 0.1, scale={"Chest": 1.06, "Hips": 1.04}), "out")
	c.key(8, _spin_kick(-200, 0.5, 0.17), "lin")
	c.key(s, _spin_kick(-238, 0.95, 0.2, scale={"RightLowerLeg": 1.12}), "lin")
	c.key(s + 1, _spin_kick(-272, 1.0, 0.2), "out")
	c.key(s + 2, _spin_kick(-305, 0.95, 0.19), "lin")
	c.key(s + a + 3, _spin_kick(-345, 0.4, 0.1), "out")
	land = body(turn=-25 - 360, lean=16, hz=-0.16, lh=(0.17, -0.33, 1.06), rh=(-0.12, -0.24, 1.02),
		scale={"Chest": 0.9, "Hips": 0.93})
	c.key(s + a + 8, land, "in").key(c.length, body(turn=-25 - 360), "io")
	return c


def _straight_smash(c, s, a, cock_at, lunge=0.0, both=False, hop=0.0, overshoot=1.0):
	"""Wind-up, then a lunging right straight; the front foot steps in."""
	step = feet(lf=(0.2, -0.36 - lunge), rf=(-0.18, 0.24), ryaw=-10, rpitch=30, rz=G + 0.04)
	lh_hit = (0.08, -0.8, 1.27) if both else (0.2, -0.2, 1.15)
	ext = body(turn=30, lean=18 + lunge * 20, hz=-0.1 + hop, lh=lh_hit, rh=(-0.06, -0.82, 1.28),
		rpole=(-1, 0.3, -0.4), legs=step, scale={"Chest": 1.1, "Hips": 1.03, "RightLowerArm": 1.2})
	peak = body(turn=36, lean=20 + lunge * 20, hz=-0.1 + hop, lh=(0.06, -0.9, 1.27) if both else lh_hit,
		rh=(-0.04, -0.94, 1.27), rpole=(-1, 0.3, -0.4), legs=step,
		scale={"Chest": 1.06, "RightLowerArm": 1.08})
	hold = body(turn=32, lean=17 + lunge * 20, hz=-0.11, lh=(0.07, -0.78, 1.25) if both else lh_hit,
		rh=(-0.05, -0.8, 1.26), rpole=(-1, 0.3, -0.4), legs=step)
	settle = body(turn=8, lean=10, hz=-0.1, rh=(-0.1, -0.5, 1.18), legs=step, scale={"Chest": 0.96})
	c.key(0, STANCE).key(cock_at, _smash_cock(), "out").key(s - 1, _smash_cock().but(scale={"Chest": 0.86}), "io")
	c.key(s, ext, "in").key(s + 2, peak, "out").key(s + a, hold, "io")
	c.key(s + a + 8, settle, "back").key(c.length, STANCE, "io")
	return c


def clip_smash(moves):
	c, s, a, r = _attack_clip(moves, "smash")
	return _straight_smash(c, s, a, cock_at=9)


def clip_charged_smash(moves, level):
	mid = "charged_smash_%d" % level
	c, s, a, r = _attack_clip(moves, mid)
	return _straight_smash(c, s, a, cock_at=4, lunge=0.06 * level, both=level == 2, hop=0.05 if level == 3 else 0.0)


def clip_breaker(moves):
	"""Guard breaker: both fists clasped high overhead, then a hammer blow straight down."""
	c, s, a, r = _attack_clip(moves, "breaker")
	two = hands(fist(), fist())
	raise_ = body(turn=-5, lean=-8, hz=-0.04, lh=(0.1, 0.3, 1.66), rh=(-0.1, 0.3, 1.66), lpole=(1, -0.3, 0.3),
		rpole=(-1, -0.3, 0.3), head_pitch=-4, scale={"Chest": 1.1, "Hips": 1.03}, fingers=two)
	slam = body(turn=0, lean=32, hz=-0.16, lh=(0.05, -0.8, 1.22), rh=(-0.05, -0.8, 1.22), lpole=(1, 0.2, 0.2),
		rpole=(-1, 0.2, 0.2), legs=feet(lf=(0.2, -0.32)), scale={"Chest": 0.86, "Hips": 0.93}, fingers=two)
	peak = body(turn=0, lean=36, hz=-0.17, lh=(0.05, -0.86, 1.12), rh=(-0.05, -0.86, 1.12), lpole=(1, 0.2, 0.2),
		rpole=(-1, 0.2, 0.2), legs=feet(lf=(0.2, -0.32)), scale={"Chest": 0.88, "Hips": 0.93}, fingers=two)
	low = body(turn=0, lean=34, hz=-0.16, lh=(0.05, -0.78, 1.02), rh=(-0.05, -0.78, 1.02), lpole=(1, 0.2, 0.2),
		rpole=(-1, 0.2, 0.2), legs=feet(lf=(0.2, -0.32)), fingers=two)
	c.key(0, STANCE).key(s - 7, raise_, "out").key(s - 2, raise_.but(scale={"Chest": 1.12}), "io")
	c.key(s, slam, "in3").key(s + 2, peak, "out").key(s + a, low, "io")
	c.key(s + a + 10, body(lean=14, hz=-0.1, legs=feet(lf=(0.2, -0.3))), "back").key(c.length, STANCE, "io")
	return c


def clip_launcher(moves):
	"""Launcher: a deep crouch, then a rising right uppercut that lifts him onto his toes."""
	c, s, a, r = _attack_clip(moves, "launcher")
	crouch = body(turn=-40, lean=24, hz=-0.24, rh=(-0.16, -0.3, 0.78), rpole=(-1, 0.4, -0.2),
		scale={"Chest": 0.86, "Hips": 0.92})
	toes = feet(lf=(0.2, -0.2), rf=(-0.18, 0.16), lz=G + 0.04, rz=G + 0.06, lpitch=-25, rpitch=-30)
	start = body(turn=0, lean=12, hz=-0.12, rh=(-0.08, -0.62, 0.88), rpole=(-1, 0.4, -0.6),
		scale={"Chest": 1.04})
	peak = body(turn=18, lean=2, hz=-0.02, rh=(-0.05, -0.76, 1.08), rpole=(-1, 0.5, -0.8), legs=toes,
		scale={"Chest": 1.1, "Hips": 1.04, "RightLowerArm": 1.12})
	high = body(turn=24, lean=-8, hz=0.0, rh=(-0.04, -0.52, 1.66), rpole=(-1, 0.5, -0.8), legs=toes,
		head_pitch=-16, scale={"Chest": 1.08, "Hips": 1.03})
	c.key(0, STANCE).key(s - 5, crouch, "out").key(s - 1, crouch.but(scale={"Chest": 0.84, "Hips": 0.91}), "io")
	c.key(s, start, "in").key(s + 1, peak, "lin").key(s + a, high, "out")
	c.key(s + a + 9, high.but(scale={}), "io").key(c.length, STANCE, "io")
	return c


def _flip(pitch, kick, hz, scale=None):
	"""Rising flip kick: the body tips back (pitch < 0) while the right leg swings up."""
	rot = {
		"Hips": spine(fwd=pitch),
		"Spine": spine(fwd=-6), "Chest": spine(fwd=-4),
		"Neck": spine(fwd=8), "Head": spine(fwd=8),
		"LeftUpperArm": arm(down=20, back=30), "LeftLowerArm": elbow(40),
		"RightUpperArm": arm(down=25, back=40), "RightLowerArm": elbow(35),
		"LeftUpperLeg": leg(fwd=40), "LeftLowerLeg": knee(110), "LeftFoot": foot(-30),
		"RightUpperLeg": leg(fwd=40 + 125 * kick), "RightLowerLeg": knee(90 * (1 - kick) + 2),
		"RightFoot": foot(-30),
	}
	rot.update(fist())
	return Pose(rot, hips=(0, 0.02, hz), scale=scale)


def clip_rising(moves):
	"""Rising kick into a backflip."""
	c, s, a, r = _attack_clip(moves, "rising")
	crouch = body(turn=-10, lean=20, hz=-0.24, lh=(0.2, -0.3, 0.98), rh=(-0.16, -0.26, 0.96),
		scale={"Chest": 0.86, "Hips": 0.92})
	c.key(0, STANCE).key(s - 5, crouch, "out")
	c.key(s - 1, _flip(-8, 0.4, 0.12, scale={"Chest": 1.06, "Hips": 1.05}), "in")
	c.key(s, _flip(-22, 0.85, 0.26, scale={"RightLowerLeg": 1.1}), "lin")
	c.key(s + 2, _flip(-38, 1.0, 0.32), "out")
	c.key(s + a, _flip(-80, 0.9, 0.34), "lin")
	c.key(s + a + 5, _flip(-180, 0.5, 0.3), "lin")
	c.key(s + a + 10, _flip(-280, 0.1, 0.18), "lin")
	land = body(turn=-25, lean=18, hz=-0.18, lh=(0.17, -0.33, 1.06), rh=(-0.12, -0.24, 1.02),
		scale={"Chest": 0.9, "Hips": 0.93})
	c.key(s + a + 15, land, "in").key(c.length, STANCE, "io")
	return c


def _axe(raise_k, hz, lean, scale=None):
	"""Axe kick: the straight right leg lifted (raise_k = 1 is overhead) with the body leaning back."""
	rot = {
		"Hips": spine(fwd=-lean * 0.5, turn=-10),
		"Spine": spine(fwd=-lean * 0.3), "Chest": spine(fwd=-lean * 0.2),
		"Neck": spine(fwd=lean * 0.5), "Head": spine(fwd=lean * 0.4),
		"LeftUpperArm": arm(down=30, fwd=25), "LeftLowerArm": elbow(60),
		"RightUpperArm": arm(down=40, back=20), "RightLowerArm": elbow(50),
		"LeftUpperLeg": leg(fwd=25), "LeftLowerLeg": knee(55), "LeftFoot": foot(-20),
		"RightUpperLeg": leg(fwd=40 + 140 * raise_k), "RightLowerLeg": knee(4), "RightFoot": foot(-35),
	}
	rot.update(fist())
	return Pose(rot, hips=(0, 0.02, hz), scale=scale)


def clip_spike(moves):
	"""Spike: a hopping axe kick that chops the heel straight down."""
	c, s, a, r = _attack_clip(moves, "spike")
	c.key(0, STANCE).key(4, body(turn=-15, lean=14, hz=-0.2, scale={"Chest": 0.88, "Hips": 0.93}), "out")
	c.key(9, _axe(0.75, 0.2, 20, scale={"Chest": 1.08, "Hips": 1.04}), "out")
	c.key(s - 1, _axe(0.95, 0.28, 28), "io")
	c.key(s, _axe(0.72, 0.28, 18, scale={"RightLowerLeg": 1.1}), "in3")
	c.key(s + 1, _axe(0.55, 0.26, 10), "lin")
	c.key(s + a, _axe(0.2, 0.2, 0, scale={"Chest": 0.92}), "lin")
	land = body(turn=-15, lean=20, hz=-0.2, legs=feet(rf=(-0.16, -0.25), ryaw=-5),
		scale={"Chest": 0.88, "Hips": 0.92})
	c.key(s + a + 6, land, "in").key(s + a + 14, land.but(scale={}), "out").key(c.length, STANCE, "io")
	return c


def _sweep(yaw, ext, scale=None):
	"""Low spinning sweep: crouched on the left leg, hands down, the right leg sweeping round."""
	rot = {
		"Hips": spine(fwd=20, turn=yaw),
		"Spine": spine(fwd=22), "Chest": spine(fwd=16),
		"Neck": spine(fwd=-30, turn=-_wrapped(yaw) * 0.4), "Head": spine(fwd=-24, turn=-_wrapped(yaw) * 0.4),
		"LeftUpperArm": arm(down=70, fwd=50), "LeftLowerArm": elbow(25),
		"RightUpperArm": arm(down=65, fwd=40), "RightLowerArm": elbow(30),
		"LeftUpperLeg": leg(fwd=95, out=20), "LeftLowerLeg": knee(140), "LeftFoot": foot(30),
		"RightUpperLeg": leg(out=78 * ext + 10, fwd=12 * ext + 30 * (1 - ext)),
		"RightLowerLeg": knee(100 * (1 - ext) + 3), "RightFoot": foot(-10),
	}
	rot.update(open_hand(10))
	return Pose(rot, hips=(0, 0.02, -0.42), scale=scale)


def clip_sweep(moves):
	c, s, a, r = _attack_clip(moves, "sweep")
	drop = body(turn=-40, lean=24, hz=-0.3, scale={"Chest": 0.88, "Hips": 0.93})
	c.key(0, STANCE).key(4, drop, "out").key(8, _sweep(-120, 0.4, scale={"Chest": 0.92}), "in")
	c.key(s, _sweep(-220, 0.95, scale={"RightLowerLeg": 1.08}), "lin")
	c.key(s + 2, _sweep(-268, 1.0), "lin")
	c.key(s + a - 1, _sweep(-320, 0.95), "lin")
	c.key(s + a + 4, _sweep(-370, 0.6), "out")
	c.key(s + a + 11, body(turn=-25 - 360, lean=18, hz=-0.2, scale={"Hips": 0.95}), "io")
	c.key(c.length, body(turn=-25 - 360), "io")
	return c


def clip_push_block(moves):
	"""Push block: both palms shove forward from the guard."""
	c, s, a, r = _attack_clip(moves, "push_block")
	palms = hands(open_hand(6), open_hand(6))
	push = body(turn=0, lean=12, lh=(0.12, -0.7, 1.2), rh=(-0.12, -0.7, 1.2), lpole=(1, 0.4, -0.6),
		rpole=(-1, 0.4, -0.6), fingers=palms, scale={"Chest": 1.08, "Hips": 1.02},
		legs=feet(lf=(0.2, -0.26)))
	peak = body(turn=0, lean=16, lh=(0.12, -0.8, 1.2), rh=(-0.12, -0.8, 1.2), lpole=(1, 0.4, -0.6),
		rpole=(-1, 0.4, -0.6), fingers=palms, scale={"Chest": 1.05}, legs=feet(lf=(0.2, -0.26)))
	c.key(0, STANCE).key(s - 2, body(turn=-15, lean=2, lh=(0.13, -0.3, 1.16), rh=(-0.11, -0.28, 1.14),
		fingers=palms, scale={"Chest": 0.92}), "out")
	c.key(s, push, "in").key(s + 1, peak, "out").key(s + a, push.but(scale={}), "io")
	c.key(s + a + 3, body(turn=0, lean=6, lh=(0.13, -0.5, 1.15), rh=(-0.11, -0.48, 1.12), fingers=palms), "io")
	c.key(s + a + 8, body(lean=8), "out").key(c.length, STANCE, "io")
	return c


def clip_grab(moves):
	"""Grab: a lunging two-handed snatch with open hands that clamp shut on contact."""
	c, s, a, r = _attack_clip(moves, "grab")
	palms = hands(open_hand(14), open_hand(14))
	reach = body(turn=0, lean=20, hz=-0.12, lh=(0.16, -0.78, 1.0), rh=(-0.16, -0.78, 1.0), lpole=(1, 0.3, -0.5),
		rpole=(-1, 0.3, -0.5), fingers=palms, legs=feet(lf=(0.2, -0.32)), scale={"Chest": 1.08})
	clamp = body(turn=0, lean=24, hz=-0.13, lh=(0.05, -0.9, 1.0), rh=(-0.05, -0.9, 1.0), lpole=(1, 0.3, -0.5),
		rpole=(-1, 0.3, -0.5), legs=feet(lf=(0.2, -0.32)), scale={"Chest": 1.04})
	c.key(0, STANCE).key(s - 3, body(turn=-12, lean=2, lh=(0.3, -0.3, 1.1), rh=(-0.26, -0.26, 1.08), fingers=palms,
		scale={"Chest": 0.9}), "out")
	pull = body(turn=0, lean=12, hz=-0.12, lh=(0.12, -0.55, 1.05), rh=(-0.12, -0.55, 1.05), legs=feet(lf=(0.2, -0.3)))
	c.key(s, reach, "in").key(s + 1, clamp, "out").key(s + a + 4, pull, "io")
	c.key(s + a + 14, body(lean=10, lh=(0.14, -0.5, 1.05), rh=(-0.12, -0.48, 1.03)), "io").key(c.length, STANCE, "io")
	return c


def clip_throw():
	"""Throwing: heaving the held opponent up and over to his right."""
	c = Clip("throw", 36)
	hold = body(turn=0, lean=14, hz=-0.12, lh=(0.12, -0.6, 1.05), rh=(-0.12, -0.6, 1.05), legs=feet(lf=(0.2, -0.28)))
	heave = body(turn=-50, lean=-8, hz=-0.06, lh=(0.0, -0.3, 1.6), rh=(-0.3, -0.15, 1.6), lpole=(1, 0.3, 0.3),
		rpole=(-1, 0.3, 0.3), scale={"Chest": 1.1, "Hips": 1.03}, legs=feet(lf=(0.2, -0.28)))
	toss = body(turn=40, lean=26, hz=-0.16, lh=(-0.2, -0.62, 0.95), rh=(-0.42, -0.4, 0.9), legs=feet(lf=(0.2, -0.28)),
		scale={"Chest": 0.88, "Hips": 0.94})
	c.key(0, hold).key(12, hold.but(scale={"Chest": 0.9}), "io").key(20, heave, "out").key(26, toss, "in3")
	c.key(36, toss.but(scale={}), "out")
	return c


def all_clips(moves):
	clips = [clip_idle(), clip_power_up(), clip_hover(), clip_fly(), clip_smash_hold(),
		clip_light_1(moves), clip_light_2(moves), clip_light_3(moves), clip_light_4(moves), clip_smash(moves),
		clip_breaker(moves), clip_launcher(moves), clip_rising(moves), clip_spike(moves), clip_sweep(moves),
		clip_push_block(moves), clip_grab(moves), clip_throw()]
	clips += [clip_charged_smash(moves, n) for n in (1, 2, 3)]
	return clips


# --- Baking --------------------------------------------------------------------------------------

def _slerp(a, b, t):
	"""Shortest-path slerp that also extrapolates (t outside 0..1) for overshoot easing."""
	if a.dot(b) < 0:
		b = -b
	axis, angle = (a.inverted() @ b).to_axis_angle()
	return a @ Quaternion(axis, angle * t)


def _align(q, ref):
	return -q if q.dot(ref) < 0 else q


def _lerp_goal(ga, gb, t):
	goal = [Vector(ga[0]).lerp(Vector(gb[0]), t), Vector(ga[1]).lerp(Vector(gb[1]), t)]
	if len(ga) > 2 or len(gb) > 2:
		ya, yb = (ga[2] if len(ga) > 2 else 0.0), (gb[2] if len(gb) > 2 else 0.0)
		pa, pb = (ga[3] if len(ga) > 3 else 0.0), (gb[3] if len(gb) > 3 else 0.0)
		goal += [ya + (yb - ya) * t, pa + (pb - pa) * t]
	return goal


def _squash_feet(ik, hips, s):
	"""Moves the foot goals so the feet stay planted once the Hips are scaled by s (Y) and
	1/sqrt(s) (sideways)."""
	hip = Vector((hips.x, hips.y, HIPS_Z + hips.z))
	side = 1.0 / math.sqrt(s)
	for end in ("LeftFoot", "RightFoot"):
		if end in ik:
			g = ik[end][0]
			ik[end][0] = Vector((hip.x + (g.x - hip.x) / side, hip.y + (g.y - hip.y) / side, hip.z - (hip.z - g.z) / s))


def sample_clip(rig, clip):
	"""Per-frame (local D rotations, hips offset, scales) for frames 0..length."""
	keys = sorted(clip.keys, key=lambda k: k[0])
	solved = [rig.solve(pose) for _, pose, _ in keys]
	frames = []
	rnd = random.Random(zlib.crc32(clip.name.encode()))
	pin = keys[0][1].hips
	for f in range(clip.length + 1):
		i = 0
		while i < len(keys) - 1 and keys[i + 1][0] < f:
			i += 1
		if f <= keys[0][0]:
			i = j = 0
			t = 0.0
		elif f >= keys[-1][0]:
			i = j = len(keys) - 1
			t = 0.0
		else:
			j = i + 1
			t = ease(keys[j][2], (f - keys[i][0]) / (keys[j][0] - keys[i][0]))
		pa, pb = keys[i][1], keys[j][1]
		local = {name: _slerp(solved[i][name], solved[j][name], t) for name in solved[i]}
		hips = pa.hips.lerp(pb.hips, t)
		# No root motion: the hips keep the clip's first horizontal position.
		hips = Vector((pin.x, pin.y, hips.z))
		scale = {}
		for name in sorted(set(pa.scale) | set(pb.scale)):
			scale[name] = pa.scale.get(name, 1.0) * (1 - t) + pb.scale.get(name, 1.0) * t
		ik = {end: _lerp_goal(pa.ik[end], pb.ik[end], t) for end in sorted(set(pa.ik) & set(pb.ik))}
		if clip.jitter and 0 < f < clip.length:
			for end in ik:
				if end.endswith("Hand"):
					ik[end][0] = ik[end][0] + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1),
						rnd.uniform(-1, 1))) * clip.jitter
			hips = hips + Vector((0, 0, rnd.uniform(-1, 1) * clip.jitter * 0.6))
		if scale.get("Hips", 1.0) != 1.0:
			_squash_feet(ik, hips, scale["Hips"])
		local = rig.solve(Pose(hips=hips), local, ik)
		frames.append((local, hips, scale))
	return frames


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
			if name == "Root" or name in kael_rig.SCARF_BONES:
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
		fc.keyframe_points.foreach_set("co", [c for k in keys for c in k])
		for kp in fc.keyframe_points:
			kp.interpolation = "LINEAR"
		fc.update()
	action.frame_range = (0, clip.length)
	return action


def build_all(arm_obj):
	"""Bakes every clip into an action on the armature; prints the strike timing table."""
	rig = Rig(kael_rig.bone_layout())
	moves = kael_moves.load_moves()
	table = []
	for clip in all_clips(moves):
		frames = sample_clip(rig, clip)
		write_action(arm_obj, rig, clip, frames)
		if clip.name in STRIKE_BONES:
			m = moves[clip.name]
			best, dists = strike_frames(rig, clip, frames, moves)
			s, a = m["startup"], m["active"]
			table.append((clip.name, s, a, m["recovery"], best, dists[best], s - 2 <= best <= s + a + 1))
	arm_obj.animation_data.action = None
	print("strike timing (move, startup, active, recovery, peak frame, distance, inside active +-2):")
	for row in table:
		print("  %-16s S=%2d A=%d R=%2d peak=%2d d=%.2f %s" % (row[0], row[1], row[2], row[3], row[4], row[5],
			"ok" if row[6] else "OUTSIDE"))
	return table
