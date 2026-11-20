"""Every Skybreak sound effect: a recipe per cue plus its playback settings.

Each Cue bakes `variations` files from `recipe(rng, v)`; rng is seeded per file,
so a re-bake gives the same samples (the Ogg
encoder's stream serials may still differ). Recipes return mono arrays, or (2, n)
stereo for ambience beds.
"""
from dataclasses import dataclass, field

import numpy as np

from dsp import (SR, at, bell, bp, brown, dc_block, env_ad, env_exp, env_swell, fade, glide,
	hp, lp, make_loop, mix, n, noise, pink, pluck, reverb_tail, saw, sweep_bp, sweep_lp, t, tone)


@dataclass
class Cue:
	id: str
	category: str
	recipe: object
	variations: int = 1
	bus: str = "SFX"
	volume_db: float = 0.0
	pitch: tuple = (0.95, 1.05)
	volume_jitter_db: float = 1.0
	max_voices: int = 4
	priority: int = 50
	cooldown: float = 0.03
	positional: bool = True
	unit_size: float = 12.0
	max_distance: float = 250.0
	loop: bool = False
	layers: list = field(default_factory=list)
	duck_db: float = 0.0
	duck_seconds: float = 0.0


# ---------------------------------------------------------------- impacts

def thump(rng, v, dur=0.45, f0=140.0, f1=42.0):
	f = glide(f0 * (1 + 0.06 * v), f1, dur, 0.5)
	body = tone(f, dur) * env_exp(dur, dur / 4.0, 0.001)
	click = lp(noise(rng, 0.012), 2500) * env_exp(0.012, 0.003)
	return fade(mix(body, 0.6 * click))


def crack(rng, v, dur=0.18, lo=1400.0, hi=7000.0):
	burst = bp(noise(rng, dur), lo * (1 + 0.1 * v), hi) * env_exp(dur, dur / 7.0, 0.0005)
	snap = tone(glide(2600 + 300 * v, 900, 0.03), 0.03) * env_exp(0.03, 0.008)
	return fade(mix(burst, 0.4 * snap))


def tail(rng, v, dur=0.9):
	x = lp(brown(rng, dur) + 0.3 * pink(rng, dur), 900 + 150 * v) * env_exp(dur, dur / 3.5, 0.01)
	return fade(x, 0.01, 0.1)


def hit(rng, v, weight):
	"""weight 0 light .. 1 medium .. 2 heavy: thud body, slap and a short whoosh tail."""
	dur = 0.18 + 0.12 * weight
	body = thump(rng, v, dur, 220 - 50 * weight, 70 - 15 * weight)
	slap = bp(noise(rng, 0.06), 900 - 200 * weight, 5000) * env_exp(0.06, 0.012 + 0.006 * weight)
	swish = sweep_bp(noise(rng, dur), 3000, 600, 1.5) * env_exp(dur, dur / 3.0, 0.004)
	return fade(mix(body * (0.8 + 0.2 * weight), 0.9 * slap, 0.25 * swish))


def heavy_crack(rng, v):
	return fade(mix(crack(rng, v, 0.22, 900, 6500), 0.7 * hit(rng, v, 2)))


def launcher(rng, v):
	rise = sweep_bp(noise(rng, 0.5), 300, 3500, 2.5, 0.7) * env_swell(0.5, 0.75)
	return fade(mix(hit(rng, v, 1.4), 0.6 * at(rise, 0.03)))


def ground_bounce(rng, v):
	boom = thump(rng, v, 0.6, 110, 35)
	debris = lp(noise(rng, 0.5), 1800) * env_exp(0.5, 0.12)
	rattle = mix(*[at(bp(noise(rng, 0.03), 1500, 5000) * env_exp(0.03, 0.006), 0.05 + 0.04 * k + 0.02 * rng.random()) for k in range(6)])
	return fade(mix(boom, 0.5 * debris, 0.3 * rattle))


def wall_splat(rng, v):
	slam = mix(thump(rng, v, 0.5, 160, 50), 0.8 * crack(rng, v, 0.25, 600, 4000))
	crumble = mix(*[at(bp(noise(rng, 0.05), 400 + 300 * rng.random(), 3000) * env_exp(0.05, 0.015), 0.08 + 0.05 * k * rng.random()) for k in range(10)])
	return fade(reverb_tail(rng, mix(slam, 0.45 * crumble), 0.5, 0.2))


def block(rng, v):
	knock = thump(rng, v, 0.14, 300, 160) * 0.8
	scuff = bp(noise(rng, 0.12), 700, 2400) * env_exp(0.12, 0.025)
	return fade(mix(knock, 0.7 * scuff))


def perfect_block(rng, v):
	f = 2093.0 * (1.0 + 0.03 * v)
	ting = bell(f, 0.9, 0.5, ((1, 1.0), (2.0, 0.35), (2.76, 0.25), (5.4, 0.12)))
	shimmer = hp(noise(rng, 0.15), 6000) * env_exp(0.15, 0.03)
	return fade(mix(ting, 0.25 * shimmer, 0.2 * block(rng, v)), 0.0005, 0.05)


def guard_break(rng, v):
	shards = mix(*[at(bell(1800 + 3500 * rng.random(), 0.35, 0.08), 0.01 + 0.18 * rng.random() ** 2) for _ in range(18)])
	burst = hp(noise(rng, 0.5), 2500) * env_exp(0.5, 0.09)
	drop = tone(glide(400, 80, 0.5), 0.5) * env_exp(0.5, 0.15)
	return fade(mix(0.5 * shards, 0.6 * burst, 0.5 * drop, thump(rng, v, 0.3, 180, 60)))


def push_block(rng, v):
	shove = sweep_bp(noise(rng, 0.35), 250, 1600, 1.8) * env_ad(0.35, 0.15)
	energy = tone(glide(180, 360, 0.3), 0.3) * env_ad(0.3, 0.1) * 0.4
	return fade(mix(shove, energy, 0.5 * block(rng, v)))


def grab(rng, v):
	clutch = bp(noise(rng, 0.12), 300, 1800) * env_exp(0.12, 0.03)
	cloth = bp(noise(rng, 0.25), 2000, 6000) * env_ad(0.25, 0.2) * 0.3
	return fade(mix(thump(rng, v, 0.16, 180, 90) * 0.6, clutch, cloth))


def throw(rng, v):
	spin = sweep_bp(noise(rng, 0.45), 500, 2500, 2.0) * env_swell(0.45, 0.4) * (0.7 + 0.3 * tone(9, 0.45))
	return fade(mix(spin, at(hit(rng, v, 1.6), 0.25)))


def tech(rng, v):
	clap = bp(noise(rng, 0.08), 1000, 5000) * env_exp(0.08, 0.015)
	zing = tone(glide(900, 1800, 0.18), 0.18) * env_exp(0.18, 0.06) * 0.35
	return fade(mix(clap, zing, at(clap * 0.6, 0.05)))


def combo_breaker(rng, v):
	# T-DEF3: a short inhale, then a sub boom, a bright energy ring and a shockwave whoosh outward.
	dur = 1.1
	inhale = sweep_bp(noise(rng, 0.12), 3000, 600, 2.0) * env_swell(0.12, 0.95, 1.2) * 0.4
	boom = thump(rng, v, 0.9, 110, 30)
	ring = bell(1046.5 * (1.0 + 0.02 * v), 0.9, 0.35, ((1, 1.0), (1.5, 0.5), (2.0, 0.35), (3.0, 0.15)))
	wave = sweep_bp(noise(rng, 0.7), 200, 4000, 1.6, 0.7) * env_exp(0.7, 0.22)
	shards = mix(*[at(bell(2400 + 2400 * rng.random(), 0.25, 0.06), 0.02 + 0.12 * rng.random()) for _ in range(8)])
	body = mix(boom, 0.45 * ring, 0.7 * wave, 0.25 * shards)
	return fade(reverb_tail(rng, mix(inhale, at(body, 0.1)), 0.7, 0.25)[: int(SR * dur)], 0.002, 0.15)


def air_tech(rng, v):
	# T-DEF3: an air tech or tech roll: a tight clap and a rising zip, then an air flip.
	clap = bp(noise(rng, 0.06), 1500, 7000) * env_exp(0.06, 0.012)
	zip_ = tone(glide(700 + 60 * v, 2400, 0.16, 1.4), 0.16) * env_exp(0.16, 0.05) * 0.3
	flip = sweep_bp(noise(rng, 0.28), 900, 5000, 2.4, 0.6) * env_swell(0.28, 0.35) * 0.6
	return fade(mix(clap, zip_, at(flip, 0.03)))


def counter_hit(rng, v):
	sting = mix(tone(1320, 0.4), 0.6 * tone(1980, 0.4), 0.3 * tone(2640, 0.4)) * env_exp(0.4, 0.09)
	sizzle = hp(noise(rng, 0.25), 4000) * env_exp(0.25, 0.05)
	return fade(mix(0.5 * sting, 0.3 * sizzle, 0.6 * crack(rng, v, 0.12)))


def armor_hit(rng, v):
	clank = bell(620 + 40 * v, 0.4, 0.15, ((1, 1.0), (2.3, 0.6), (3.9, 0.4), (6.1, 0.2)))
	return fade(mix(0.6 * clank, 0.7 * thump(rng, v, 0.2, 200, 90)))


def ko_boom(rng, v):
	boom = thump(rng, v, 1.2, 90, 28)
	blast = lp(noise(rng, 1.0), 2500) * env_exp(1.0, 0.18, 0.003)
	ring = tone(glide(880, 440, 1.0), 1.0) * env_exp(1.0, 0.3) * 0.15
	return fade(reverb_tail(rng, mix(boom, 0.6 * blast, ring, 0.8 * crack(rng, v, 0.3, 700, 6000)), 1.2, 0.35, 2500), 0.001, 0.2)


def ko_tail(rng, v):
	dur = 3.2
	rumble = lp(brown(rng, dur), 260) * env_exp(dur, 1.0, 0.2)
	air = bp(pink(rng, dur), 300, 1500) * env_exp(dur, 0.7, 0.4) * 0.3
	return fade(mix(rumble, air), 0.05, 0.6)


def combo_tick(rng, v):
	return fade(mix(tone(1567.98, 0.12), 0.5 * tone(3135.96, 0.12)) * env_exp(0.12, 0.03), 0.001, 0.02)


def swing(rng, v, dur=0.22, f0=900.0, f1=3200.0):
	x = sweep_bp(noise(rng, dur), f0 * (1 + 0.08 * v), f1, 2.2, 0.8) * env_swell(dur, 0.55)
	return fade(x)


# ---------------------------------------------------------------- movement

def dash(rng, v):
	x = sweep_bp(noise(rng, 0.32), 500, 3000, 1.8, 0.6) * env_swell(0.32, 0.3, 1.5)
	puff = lp(noise(rng, 0.1), 900) * env_exp(0.1, 0.03)
	return fade(mix(x, 0.5 * puff))


def air_dash(rng, v):
	x = sweep_bp(noise(rng, 0.38), 800, 4500, 2.5, 0.5) * env_swell(0.38, 0.25, 1.5)
	zip_ = tone(glide(300, 900, 0.2), 0.2) * env_ad(0.2, 0.05) * 0.15
	return fade(mix(x, zip_))


def rush_whoosh(rng, v):
	x = sweep_bp(noise(rng, 0.7), 300, 2200, 1.5, 1.0) * env_swell(0.7, 0.65, 1.6)
	return fade(mix(x, 0.4 * lp(noise(rng, 0.7), 400) * env_swell(0.7, 0.65)))


def vanish_out(rng, v):
	dur = 0.3
	zip_ = tone(glide(400, 3200, dur, 1.5), dur) * env_ad(dur, 0.1) * 0.5
	air = sweep_bp(noise(rng, dur), 1000, 7000, 3.0) * env_ad(dur, 0.05)
	return fade(mix(zip_, air, 0.3 * hp(noise(rng, 0.04), 5000) * env_exp(0.04, 0.01)))


def vanish_in(rng, v):
	dur = 0.28
	zip_ = tone(glide(3600, 500, dur, 0.7), dur) * env_ad(dur, 0.6) * 0.5
	air = sweep_bp(noise(rng, dur), 6000, 900, 3.0) * env_ad(dur, 0.7)
	pop = thump(rng, v, 0.12, 300, 120) * 0.5
	return fade(mix(zip_, air, at(pop, dur - 0.04)))


def ui_ping(f0, f1, dur=0.12, amp=1.0):
	return fade(mix(tone(glide(f0, f1, dur), dur), 0.3 * tone(glide(f0 * 2, f1 * 2, dur), dur)) * env_exp(dur, dur / 3.0) * amp, 0.001, 0.02)


def lock_on(rng, v):
	return mix(ui_ping(880, 880, 0.08), at(ui_ping(1320, 1320, 0.14), 0.06))


def lock_switch(rng, v):
	return ui_ping(1100, 1500, 0.1)


def land(rng, v, heavy):
	dur = 0.35 if heavy else 0.18
	body = thump(rng, v, dur, 120 if heavy else 200, 40 if heavy else 80)
	grit = lp(noise(rng, dur), 2500 if heavy else 4000) * env_exp(dur, dur / 5.0)
	return fade(mix(body, (0.6 if heavy else 0.4) * grit))


def flight_start(rng, v):
	dur = 0.6
	lift = sweep_bp(noise(rng, dur), 200, 1800, 1.4, 0.7) * env_ad(dur, 0.35)
	hum = tone(glide(90, 180, dur), dur) * env_ad(dur, 0.3) * 0.4
	return fade(mix(lift, hum))


def flight_stop(rng, v):
	dur = 0.45
	settle = sweep_bp(noise(rng, dur), 1500, 250, 1.4) * env_ad(dur, 0.1)
	hum = tone(glide(180, 80, dur), dur) * env_ad(dur, 0.1) * 0.35
	return fade(mix(settle, hum))


def wind_loop(rng, v):
	dur, xf = 6.0, 1.0
	base = pink(rng, dur + xf)
	gust = 0.6 + 0.4 * np.sin(2 * np.pi * (1 / 3.0) * t(dur + xf)) ** 2
	howl = sweep_bp(noise(rng, dur + xf), 500, 900, 4.0) * 0.3
	x = dc_block(lp(base, 1600) * gust + howl * gust)
	return make_loop(x, dur, xf)


# ---------------------------------------------------------------- ki

def ki_charge_loop(rng, v):
	dur, xf = 4.0, 0.5
	tt = t(dur + xf)
	f = 110.0 * (1 + 0.004 * np.sin(2 * np.pi * 0.75 * tt))
	buzz = lp(saw(f, dur + xf) + 0.6 * saw(f * 1.5, dur + xf), 1800)
	trem = 0.75 + 0.25 * np.sin(2 * np.pi * 8.0 * tt)
	sizzle = bp(noise(rng, dur + xf), 3000, 9000) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 3.0 * tt)))
	x = dc_block(0.6 * buzz * trem + 0.25 * sizzle + 0.3 * lp(brown(rng, dur + xf), 200))
	return make_loop(x, dur, xf)


def aura_loop(rng, v):
	dur, xf = 4.0, 0.5
	tt = t(dur + xf)
	hum = sum(a * tone(55.0 * k, dur + xf) for k, a in ((1, 1.0), (2, 0.6), (3, 0.35), (4, 0.2), (6, 0.1)))
	breath = 0.8 + 0.2 * np.sin(2 * np.pi * 0.5 * tt)
	flicker = bp(pink(rng, dur + xf), 800, 3000) * (0.4 + 0.3 * np.sin(2 * np.pi * 5.0 * tt) ** 2)
	x = dc_block(0.6 * hum * breath + 0.3 * flicker)
	return make_loop(x, dur, xf)


def power_up_burst(rng, v):
	dur = 1.2
	rise = tone(glide(120, 480, 0.4, 0.6), 0.4) * env_ad(0.4, 0.8) * 0.5
	blast = lp(noise(rng, dur), 3000) * env_exp(dur, 0.25)
	return fade(reverb_tail(rng, mix(rise, at(mix(thump(rng, v, 0.8, 100, 35), 0.7 * blast), 0.35)), 0.8, 0.25), 0.002, 0.2)


def ki_blast_fire(rng, v):
	dur = 0.28
	zap = tone(glide(1800 + 200 * v, 300, dur, 0.5), dur) * env_exp(dur, 0.08) * 0.6
	fizz = bp(noise(rng, dur), 2000, 8000) * env_exp(dur, 0.05)
	return fade(mix(zap, 0.5 * fizz, 0.4 * thump(rng, v, 0.15, 260, 120)))


def ki_blast_impact(rng, v):
	dur = 0.6
	pop = lp(noise(rng, dur), 3500) * env_exp(dur, 0.1)
	return fade(mix(thump(rng, v, 0.5, 150, 45), 0.7 * pop, 0.4 * crack(rng, v, 0.12)))


def beam_charge_loop(rng, v):
	dur, xf = 3.0, 0.5
	tt = t(dur + xf)
	whine = sum(a * tone(440.0 * k, dur + xf) for k, a in ((1, 0.5), (1.5, 0.4), (2.0, 0.3), (3.0, 0.15)))
	wobble = 0.7 + 0.3 * np.sin(2 * np.pi * 12.0 * tt)
	sizzle = hp(noise(rng, dur + xf), 5000) * 0.3
	x = dc_block(whine * wobble * 0.5 + sizzle + 0.3 * lp(brown(rng, dur + xf), 300))
	return make_loop(x, dur, xf)


def beam_fire(rng, v):
	dur = 1.0
	blast = lp(noise(rng, dur), 5000) * env_exp(dur, 0.3)
	tone_ = (saw(glide(220, 160, dur), dur) * 0.4) * env_exp(dur, 0.35)
	return fade(mix(thump(rng, v, 0.9, 120, 40), 0.7 * blast, lp(tone_, 2500)), 0.001, 0.15)


def beam_loop(rng, v):
	dur, xf = 3.0, 0.5
	tt = t(dur + xf)
	roar = bp(pink(rng, dur + xf), 200, 4000)
	drone = lp(saw(110.0, dur + xf) + saw(110.0 * 1.01, dur + xf), 1500) * 0.4
	crackle = hp(noise(rng, dur + xf), 6000) * (rng.random(n(dur + xf)) > 0.995) * 3.0
	x = dc_block(roar * (0.85 + 0.15 * np.sin(2 * np.pi * 6.0 * tt)) + drone + 0.2 * crackle)
	return make_loop(x, dur, xf)


def beam_clash(rng, v):
	dur = 2.0
	tt = t(dur)
	roar = bp(pink(rng, dur), 150, 5000) * env_ad(dur, 0.1, 1.2)
	grind = lp(saw(70.0 * (1 + 0.05 * np.sin(2 * np.pi * 4 * tt)), dur), 1200) * env_ad(dur, 0.1, 1.2)
	zaps = mix(*[at(tone(glide(3000 * rng.random() + 1000, 400, 0.08), 0.08) * env_exp(0.08, 0.02), 1.8 * rng.random()) for _ in range(14)])
	return fade(mix(roar, 0.5 * grind, 0.3 * zaps, thump(rng, v, 0.6, 100, 30)), 0.003, 0.2)


# ---------------------------------------------------------------- weapons

def gauntlets_swing(rng, v):
	return fade(mix(swing(rng, v, 0.16, 1500, 4500), 0.25 * tone(glide(600, 1200, 0.1), 0.1) * env_exp(0.1, 0.03)))


def blade_swing(rng, v):
	ring = bell(3200 + 200 * v, 0.35, 0.12, ((1, 1.0), (1.48, 0.5), (2.3, 0.3))) * env_swell(0.35, 0.3)
	return fade(mix(swing(rng, v, 0.3, 700, 5000), 0.18 * ring))


def lance_thrust(rng, v):
	x = sweep_bp(noise(rng, 0.25), 400, 5000, 2.8, 0.4) * env_ad(0.25, 0.25, 2.5)
	return fade(mix(x, 0.2 * bell(2500, 0.2, 0.06)))


def hammer_swing(rng, v):
	x = sweep_bp(noise(rng, 0.55), 150, 900, 1.6, 1.0) * env_swell(0.55, 0.65)
	return fade(mix(x, 0.5 * lp(noise(rng, 0.55), 300) * env_swell(0.55, 0.65)))


def chakram_throw(rng, v):
	dur = 0.6
	spin = swing(rng, v, dur, 900, 3000) * (0.55 + 0.45 * np.sin(2 * np.pi * 14 * t(dur)))
	return fade(mix(spin, 0.15 * bell(2800, dur, 0.3)))


def scythe_swing(rng, v):
	x = sweep_bp(noise(rng, 0.5), 300, 4000, 2.0, 1.4) * env_swell(0.5, 0.7)
	shimmer = hp(noise(rng, 0.5), 7000) * env_swell(0.5, 0.75) * 0.3
	return fade(mix(x, shimmer))


def bow_draw(rng, v):
	dur = 0.9
	creak = bp(noise(rng, dur), 300, 1500) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * glide(18, 40, dur) * t(dur)))) * env_ad(dur, 0.9, 0.5)
	hum = tone(glide(220, 440, dur), dur) * env_ad(dur, 0.95, 0.5) * 0.2
	return fade(mix(creak * 0.7, hum), 0.02, 0.03)


def bow_release(rng, v):
	twang = pluck(rng, 110 + 10 * v, 0.5, 0.993) * env_exp(0.5, 0.15)
	return fade(mix(lp(twang, 3000), 0.6 * at(swing(rng, v, 0.25, 1500, 5000), 0.01)))


def gunshot(rng, v, size=1.0, bright=1.0):
	dur = 0.45 * size
	snap = hp(noise(rng, 0.03), 1500 * bright) * env_exp(0.03, 0.006)
	body = thump(rng, v, 0.25 * size, 300 / size, 80 / size)
	zap = tone(glide(2400 * bright, 500, 0.12), 0.12) * env_exp(0.12, 0.03) * 0.3
	return fade(reverb_tail(rng, mix(snap, body, zap), dur, 0.3, 3000 * bright), 0.0005, 0.05)


def revolver_fire(rng, v):
	return gunshot(rng, v, 1.0, 1.0)


def revolver_reload(rng, v):
	clicks = [at(bp(noise(rng, 0.02), 2000, 7000) * env_exp(0.02, 0.004), o) for o in (0.0, 0.12, 0.25, 0.37, 0.5, 0.62, 0.95)]
	spin = bp(noise(rng, 0.3), 3000, 8000) * env_ad(0.3, 0.2) * 0.3
	return fade(mix(*clicks, at(spin, 0.65), at(thump(rng, v, 0.08, 500, 300) * 0.5, 1.0)))


def repeater_fire(rng, v):
	return gunshot(rng, v, 0.5, 1.4)


def repeater_overheat(rng, v):
	dur = 1.3
	hiss = hp(noise(rng, dur), 3000) * env_ad(dur, 0.05, 1.5)
	ping = bell(1400, 0.6, 0.2) * 0.3
	return fade(mix(hiss, ping, 0.3 * tone(glide(900, 300, dur), dur) * env_ad(dur, 0.05)))


def scatter_fire(rng, v):
	boom = gunshot(rng, v, 1.8, 0.7)
	pellets = mix(*[at(hp(noise(rng, 0.03), 3000) * env_exp(0.03, 0.006), 0.02 + 0.05 * rng.random()) for _ in range(8)])
	return fade(mix(boom, 0.3 * pellets))


HEART_NOTES = [659.25, 783.99, 987.77, 1318.51, 1567.98]  # E5 G5 B5 E6 G6: a soft major-seventh shimmer


def sparkle(rng, dur, count=10, lo=3000, hi=8000):
	return mix(*[at(bell(lo + (hi - lo) * rng.random(), 0.25, 0.05, ((1, 1.0), (2.0, 0.3))), dur * rng.random() ** 1.5) for _ in range(count)])


def heartstring_draw(rng, v):
	dur = 1.0
	arp = mix(*[at(bell(f, 0.6, 0.25, ((1, 1.0), (2.0, 0.25), (3.0, 0.1))), 0.18 * k) for k, f in enumerate(HEART_NOTES[:4])])
	glow = tone(glide(330, 660, dur), dur) * env_ad(dur, 0.9, 0.6) * 0.15
	return fade(mix(0.4 * arp, glow, 0.25 * sparkle(rng, dur, 8)), 0.01, 0.1)


def heartstring_release(rng, v):
	harp = pluck(rng, HEART_NOTES[v % 3] / 2, 0.9, 0.997) * env_exp(0.9, 0.4)
	chime = mix(bell(HEART_NOTES[2 + v % 3], 0.9, 0.35), at(bell(HEART_NOTES[(v + 1) % 5] * 2, 0.7, 0.3), 0.07))
	return fade(mix(0.5 * lp(harp, 4000), 0.35 * chime, 0.35 * sparkle(rng, 0.6, 12), 0.4 * swing(rng, v, 0.25, 2000, 6000)), 0.001, 0.15)


def heartstring_tether(rng, v):
	dur = 1.4
	pad = sum(tone(f, dur) * a for f, a in zip(HEART_NOTES[:3], (0.5, 0.35, 0.25))) * env_ad(dur, 0.15, 1.5)
	return fade(mix(pad * (0.8 + 0.2 * tone(6, dur)), 0.3 * sparkle(rng, dur, 16, 2500, 7000)), 0.01, 0.2)


# ---------------------------------------------------------------- pickups

def pickup_spawn(rng, v):
	dur = 1.4
	rise = tone(glide(400, 1600, dur, 0.8), dur) * env_ad(dur, 0.85, 0.7) * 0.3
	shim = hp(noise(rng, dur), 5000) * env_ad(dur, 0.8) * 0.2
	return fade(mix(rise, shim, 0.3 * sparkle(rng, dur, 10), at(bell(1046.5, 0.6, 0.3) * 0.4, 1.1)), 0.02, 0.1)


def sky_drop_whistle(rng, v):
	dur = 2.0
	f = glide(2400, 700, dur, 1.3)
	whistle = tone(f * (1 + 0.006 * np.sin(2 * np.pi * 7 * t(dur))), dur) * env_ad(dur, 0.6, 0.8) * 0.4
	air = sweep_bp(noise(rng, dur), 3000, 900, 6.0, 1.3) * env_ad(dur, 0.7, 0.8) * 0.4
	return fade(mix(whistle, air, at(thump(rng, v, 0.4, 130, 45), dur - 0.15)), 0.05, 0.1)


def pickup(rng, v):
	return fade(mix(ui_ping(1046.5, 1046.5, 0.1), at(ui_ping(1567.98, 1567.98, 0.25), 0.07), 0.2 * sparkle(rng, 0.3, 5)))


def weapon_switch(rng, v):
	click = bp(noise(rng, 0.03), 2000, 7000) * env_exp(0.03, 0.006)
	slide = bp(noise(rng, 0.15), 1500 + 300 * v, 6000) * env_ad(0.15, 0.3) * 0.5
	return fade(mix(slide, at(click, 0.12), 0.3 * at(bell(1800, 0.15, 0.04), 0.12)))


def weapon_throw(rng, v):
	dur = 0.5
	spin = swing(rng, v, dur, 600, 2800) * (0.6 + 0.4 * np.sin(2 * np.pi * 11 * t(dur)))
	return fade(spin)


# ---------------------------------------------------------------- ui

def ui_move(rng, v):
	return ui_ping(1200 + 80 * v, 1200 + 80 * v, 0.05, 0.7)


def ui_confirm(rng, v):
	return mix(ui_ping(880, 880, 0.08), at(ui_ping(1318.5, 1318.5, 0.18), 0.07))


def ui_back(rng, v):
	return mix(ui_ping(988, 988, 0.08), at(ui_ping(659.25, 659.25, 0.16), 0.07))


def count_beep(freq):
	def recipe(rng, v):
		dur = 0.45
		return fade(mix(tone(freq, dur), 0.4 * tone(freq * 2, dur), 0.2 * saw(freq, dur)) * env_exp(dur, 0.14), 0.002, 0.05)
	return recipe


def round_fight(rng, v):
	dur = 1.4
	chord = sum(lp(saw(f, dur), 3000) * a for f, a in ((261.63, 0.5), (329.63, 0.4), (392.0, 0.4), (523.25, 0.3))) * env_exp(dur, 0.4, 0.004)
	hit = mix(thump(rng, v, 0.6, 120, 40), 0.6 * crack(rng, v, 0.2))
	return fade(reverb_tail(rng, mix(0.5 * chord, hit, 0.5 * rush_whoosh(rng, v)), 1.0, 0.3), 0.002, 0.2)


def round_end(rng, v):
	dur = 1.6
	notes = (523.25, 392.0, 261.63)
	return fade(reverb_tail(rng, mix(*[at(lp(saw(f, 0.6), 2500) * env_exp(0.6, 0.2, 0.005) * 0.5, 0.16 * k) for k, f in enumerate(notes)], 0.4 * tone(130.81, dur) * env_exp(dur, 0.5)), 0.8, 0.3), 0.002, 0.2)


def victory(rng, v):
	notes = (523.25, 659.25, 783.99, 1046.5)
	arp = mix(*[at(mix(tone(f, 0.5), 0.3 * lp(saw(f, 0.5), 3000)) * env_exp(0.5, 0.18, 0.004), 0.12 * k) for k, f in enumerate(notes)])
	chord = sum(lp(saw(f, 1.6), 2800) * 0.25 for f in (523.25, 659.25, 783.99)) * env_exp(1.6, 0.6, 0.01)
	return fade(reverb_tail(rng, mix(0.6 * arp, at(chord, 0.5), 0.3 * at(sparkle(rng, 1.2, 10), 0.5)), 1.0, 0.3), 0.002, 0.3)


# ---------------------------------------------------------------- ambience (stereo loops)

AMB_LEN, AMB_XF = 16.0, 2.0


def _stereo(rng, make):
	left, right = make(rng), make(rng)
	return np.stack([left, right])


def _bed(left, right):
	x = dc_block(np.stack([left, right]))
	return make_loop(x, AMB_LEN, AMB_XF)


def _wind_bed(rng, cutoff, gust_rate, howl=None):
	d = AMB_LEN + AMB_XF
	def one(r):
		g = 0.55 + 0.45 * np.sin(2 * np.pi * gust_rate * t(d) + r.random() * 6.28) ** 2
		w = lp(pink(r, d), cutoff) * g
		if howl:
			w = w + 0.25 * sweep_bp(noise(r, d), howl[0], howl[1], 6.0) * g
		return w
	return one(rng), one(rng)


def _events(rng, d, count, make):
	out = np.zeros(n(d))
	for _ in range(count):
		ev = make(rng)
		start = int(rng.random() * (len(out) - len(ev) - n(AMB_XF)))
		out[start : start + len(ev)] += ev
	return out


def amb_shattered_mesa(rng, v):
	l, r = _wind_bed(rng, 900, 1 / 8)
	d = AMB_LEN + AMB_XF
	grit = _events(rng, d, 12, lambda r_: bp(noise(r_, 0.6), 2000, 6000) * env_ad(0.6, 0.5) * 0.15)
	return _bed(l + grit, r + np.roll(grit, 9000))


def amb_skyhold_ruins(rng, v):
	l, r = _wind_bed(rng, 2200, 1 / 6)
	d = AMB_LEN + AMB_XF
	drone = 0.12 * (tone(98.0, d) + 0.5 * tone(146.83, d)) * (0.7 + 0.3 * tone(1 / 9, d))
	return _bed(0.8 * l + drone, 0.8 * r + drone)


def amb_stormfall_city(rng, v):
	d = AMB_LEN + AMB_XF
	def rain(r):
		hiss = hp(noise(r, d), 2500) * 0.35 + bp(pink(r, d), 600, 3000) * 0.4
		drops = _events(r, d, 160, lambda q: bp(noise(q, 0.015), 2000, 8000) * env_exp(0.015, 0.003) * (0.3 + 0.7 * q.random()))
		return hiss + 0.4 * drops
	hum = 0.08 * lp(saw(60.0, d), 400)
	rumble = 0.3 * lp(brown(rng, d), 120)
	return _bed(rain(rng) + hum + rumble, rain(rng) + hum + rumble)


def thunder(rng, v):
	dur = 4.0
	cr = crack(rng, v, 0.35, 300, 5000) * 0.8
	roll = lp(brown(rng, dur), 400 + 100 * v) * env_ad(dur, 0.08, 1.8) * (0.8 + 0.2 * np.sin(2 * np.pi * 1.3 * t(dur)))
	return fade(mix(at(cr, 0.05 * v), roll), 0.01, 0.4)


def amb_frozen_peaks(rng, v):
	l, r = _wind_bed(rng, 1400, 1 / 5, (400, 1100))
	return _bed(l, r)


def amb_verdant_falls(rng, v):
	d = AMB_LEN + AMB_XF
	falls_l = lp(pink(rng, d), 3000) * 0.6
	falls_r = lp(pink(rng, d), 3000) * 0.6
	birds = _events(rng, d, 10, _bird)
	return _bed(falls_l + 0.5 * birds, falls_r + 0.5 * np.roll(birds, 7000))


def _bird(rng):
	out = []
	base = 2500 + 2000 * rng.random()
	for _ in range(2 + int(rng.random() * 4)):
		dur = 0.06 + 0.06 * rng.random()
		f = glide(base, base * (1.2 + 0.4 * rng.random()), dur, 0.7) * (1 + 0.05 * np.sin(2 * np.pi * 40 * t(dur)))
		out.append(tone(f, dur) * env_ad(dur, 0.2, 1.5))
		out.append(np.zeros(n(0.04 + 0.05 * rng.random())))
	return np.concatenate(out) * 0.35


def amb_ember_rift(rng, v):
	d = AMB_LEN + AMB_XF
	rumble = lp(brown(rng, d), 150) * 0.7
	def crackles(r):
		pops = _events(r, d, 90, lambda q: bp(noise(q, 0.01), 1500, 7000) * env_exp(0.01, 0.002) * q.random())
		bubbles = _events(r, d, 24, lambda q: tone(glide(120 + 200 * q.random(), 300 + 300 * q.random(), 0.08), 0.08) * env_ad(0.08, 0.3) * 0.3)
		return 0.5 * pops + bubbles
	return _bed(rumble + crackles(rng), rumble + crackles(rng))


def amb_heartbloom_gardens(rng, v):
	d = AMB_LEN + AMB_XF
	l, r = _wind_bed(rng, 1200, 1 / 7)
	notes = (523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.66)  # C major pentatonic-ish chimes
	def chimes(q):
		return bell(notes[int(q.random() * len(notes))] * 2, 2.5, 1.0, ((1, 1.0), (2.76, 0.3), (5.4, 0.1))) * (0.15 + 0.15 * q.random())
	ch_l = _events(rng, d, 14, chimes)
	ch_r = _events(rng, d, 14, chimes)
	birds = _events(rng, d, 6, _bird)
	return _bed(0.45 * l + ch_l + 0.4 * birds, 0.45 * r + ch_r + 0.4 * np.roll(birds, 11000))


# ---------------------------------------------------------------- cue table

def _weighted(weight):
	return lambda rng, v: hit(rng, v, weight)


AMB = dict(category="ambience", bus="Ambience", positional=False, loop=True, max_voices=2, priority=10,
	pitch=(1.0, 1.0), volume_jitter_db=0.0, cooldown=0.0)
UI = dict(category="ui", bus="UI", positional=False, pitch=(1.0, 1.0), volume_jitter_db=0.0, priority=90)
LOOP = dict(loop=True, max_voices=8, volume_jitter_db=0.0, cooldown=0.0)

CUES = [
	# combat
	Cue("hit_light", "combat", _weighted(0.0), 4, max_voices=4, priority=55),
	Cue("hit_medium", "combat", _weighted(1.0), 4, max_voices=4, priority=60),
	Cue("hit_heavy", "combat", heavy_crack, 3, max_voices=3, priority=75, layers=["impact_thump", "impact_tail"], duck_db=-6.0, duck_seconds=0.35),
	Cue("impact_thump", "combat", lambda r, v: thump(r, v, 0.5, 120, 34), 3, max_voices=2, priority=70, pitch=(0.9, 1.0)),
	Cue("impact_tail", "combat", tail, 2, max_voices=2, priority=40),
	Cue("launcher", "combat", launcher, 2, max_voices=2, priority=70),
	Cue("spike_bounce", "combat", ground_bounce, 2, max_voices=2, priority=70),
	Cue("wall_splat", "combat", wall_splat, 2, max_voices=2, priority=75, duck_db=-6.0, duck_seconds=0.4),
	Cue("armor_hit", "combat", armor_hit, 2, max_voices=2, priority=60),
	Cue("block", "combat", block, 3, max_voices=4, priority=55),
	Cue("perfect_block", "combat", perfect_block, 2, max_voices=2, priority=85, pitch=(0.99, 1.01), duck_db=-4.0, duck_seconds=0.2),
	Cue("guard_break", "combat", guard_break, 2, max_voices=1, priority=85, duck_db=-6.0, duck_seconds=0.4),
	Cue("push_block", "combat", push_block, 2, max_voices=2, priority=60),
	Cue("grab", "combat", grab, 2, max_voices=2, priority=60),
	Cue("throw", "combat", throw, 2, max_voices=2, priority=70),
	Cue("tech", "combat", tech, 2, max_voices=2, priority=65),
	Cue("counter_hit", "combat", counter_hit, 2, max_voices=2, priority=80),
	Cue("combo_breaker", "combat", combo_breaker, 2, max_voices=1, priority=90, pitch=(0.98, 1.02), duck_db=-6.0, duck_seconds=0.5),
	Cue("air_tech", "combat", air_tech, 3, max_voices=2, priority=65),
	Cue("ko", "combat", ko_boom, 1, max_voices=1, priority=100, cooldown=0.5, layers=["ko_tail"], duck_db=-12.0, duck_seconds=1.6),
	Cue("ko_tail", "combat", ko_tail, 1, max_voices=1, priority=95, positional=False),
	Cue("combo_tick", "combat", combo_tick, 1, bus="UI", positional=False, max_voices=2, priority=50, pitch=(1.0, 1.0), volume_jitter_db=0.0),
	Cue("whoosh_light", "combat", lambda r, v: swing(r, v, 0.16, 1200, 4000), 4, max_voices=4, priority=30, volume_db=-5.0),
	Cue("whoosh_heavy", "combat", lambda r, v: swing(r, v, 0.32, 500, 2500), 3, max_voices=3, priority=35, volume_db=-4.0),
	# movement
	Cue("dash", "movement", dash, 3, max_voices=3, priority=45),
	Cue("air_dash", "movement", air_dash, 3, max_voices=3, priority=45),
	Cue("rush_whoosh", "movement", rush_whoosh, 2, max_voices=2, priority=45),
	Cue("vanish_out", "movement", vanish_out, 2, max_voices=2, priority=70, cooldown=0.05),
	Cue("vanish_in", "movement", vanish_in, 2, max_voices=2, priority=70, cooldown=0.05),
	Cue("lock_on", "movement", lock_on, 1, bus="UI", positional=False, priority=60, max_voices=1, pitch=(1.0, 1.0), volume_jitter_db=0.0, cooldown=0.1),
	Cue("lock_switch", "movement", lock_switch, 1, bus="UI", positional=False, priority=60, max_voices=1, pitch=(1.0, 1.0), volume_jitter_db=0.0, cooldown=0.08),
	Cue("land_light", "movement", lambda r, v: land(r, v, False), 3, max_voices=2, priority=35, cooldown=0.1),
	Cue("land_heavy", "movement", lambda r, v: land(r, v, True), 2, max_voices=2, priority=55, cooldown=0.1),
	Cue("flight_start", "movement", flight_start, 2, max_voices=2, priority=40, cooldown=0.2),
	Cue("flight_stop", "movement", flight_stop, 2, max_voices=2, priority=35, cooldown=0.2),
	Cue("flight_wind_loop", "movement", wind_loop, 1, **LOOP, priority=20, pitch=(0.7, 1.35)),
	# ki
	Cue("ki_charge_loop", "ki", ki_charge_loop, 1, **LOOP, priority=60, pitch=(0.8, 1.6)),
	Cue("aura_loop", "ki", aura_loop, 1, **LOOP, priority=40, pitch=(0.95, 1.1)),
	Cue("power_up_burst", "ki", power_up_burst, 2, max_voices=2, priority=75, cooldown=0.3, duck_db=-4.0, duck_seconds=0.5),
	Cue("ki_blast_fire", "ki", ki_blast_fire, 3, max_voices=6, priority=50),
	Cue("ki_blast_impact", "ki", ki_blast_impact, 3, max_voices=6, priority=55),
	Cue("beam_charge_loop", "ki", beam_charge_loop, 1, **LOOP, priority=70, pitch=(0.8, 1.6)),
	Cue("beam_fire", "ki", beam_fire, 1, max_voices=2, priority=85, duck_db=-6.0, duck_seconds=0.6),
	Cue("beam_loop", "ki", beam_loop, 1, **LOOP, priority=80, pitch=(0.95, 1.05)),
	Cue("beam_clash", "ki", beam_clash, 1, max_voices=1, priority=90, duck_db=-8.0, duck_seconds=1.5),
	# weapons
	Cue("gauntlets_swing", "weapons", gauntlets_swing, 3, max_voices=4, priority=40),
	Cue("blade_swing", "weapons", blade_swing, 3, max_voices=3, priority=40),
	Cue("lance_thrust", "weapons", lance_thrust, 3, max_voices=3, priority=40),
	Cue("hammer_swing", "weapons", hammer_swing, 2, max_voices=2, priority=45),
	Cue("chakram_throw", "weapons", chakram_throw, 2, max_voices=2, priority=40),
	Cue("scythe_swing", "weapons", scythe_swing, 3, max_voices=3, priority=40),
	Cue("bow_draw", "weapons", bow_draw, 1, max_voices=2, priority=45),
	Cue("bow_release", "weapons", bow_release, 3, max_voices=3, priority=50),
	Cue("revolver_fire", "weapons", revolver_fire, 3, max_voices=4, priority=55),
	Cue("revolver_reload", "weapons", revolver_reload, 1, max_voices=2, priority=45),
	Cue("repeater_fire", "weapons", repeater_fire, 4, max_voices=6, priority=45, cooldown=0.04),
	Cue("repeater_overheat", "weapons", repeater_overheat, 1, max_voices=2, priority=55),
	Cue("scatter_fire", "weapons", scatter_fire, 2, max_voices=2, priority=60),
	Cue("heartstring_draw", "weapons", heartstring_draw, 1, max_voices=2, priority=50, pitch=(1.0, 1.0)),
	Cue("heartstring_release", "weapons", heartstring_release, 3, max_voices=3, priority=55, pitch=(1.0, 1.0)),
	Cue("heartstring_tether", "weapons", heartstring_tether, 1, max_voices=2, priority=60, pitch=(1.0, 1.0)),
	# pickups
	Cue("pickup_spawn", "pickups", pickup_spawn, 1, max_voices=3, priority=60, unit_size=25.0, max_distance=400.0),
	Cue("sky_drop_whistle", "pickups", sky_drop_whistle, 1, max_voices=3, priority=60, unit_size=25.0, max_distance=400.0),
	Cue("pickup", "pickups", pickup, 2, max_voices=2, priority=65),
	Cue("weapon_switch", "pickups", weapon_switch, 2, max_voices=2, priority=50),
	Cue("weapon_throw", "pickups", weapon_throw, 2, max_voices=2, priority=50),
	# ui
	Cue("ui_move", recipe=ui_move, variations=3, **UI, cooldown=0.03),
	Cue("ui_confirm", recipe=ui_confirm, **UI),
	Cue("ui_back", recipe=ui_back, **UI),
	Cue("round_count_3", recipe=count_beep(523.25), **UI),
	Cue("round_count_2", recipe=count_beep(523.25), **UI),
	Cue("round_count_1", recipe=count_beep(587.33), **UI),
	Cue("round_fight", recipe=round_fight, **UI, duck_db=-6.0, duck_seconds=0.8),
	Cue("round_end", recipe=round_end, **UI),
	Cue("victory", recipe=victory, **UI),
	# ambience
	Cue("amb_shattered_mesa", recipe=amb_shattered_mesa, **AMB),
	Cue("amb_skyhold_ruins", recipe=amb_skyhold_ruins, **AMB),
	Cue("amb_stormfall_city", recipe=amb_stormfall_city, **AMB),
	Cue("amb_frozen_peaks", recipe=amb_frozen_peaks, **AMB),
	Cue("amb_verdant_falls", recipe=amb_verdant_falls, **AMB),
	Cue("amb_ember_rift", recipe=amb_ember_rift, **AMB),
	Cue("amb_heartbloom_gardens", recipe=amb_heartbloom_gardens, **AMB),
	Cue("stormfall_thunder", "ambience", thunder, 3, bus="Ambience", positional=False, max_voices=1, priority=20, cooldown=4.0),
]

# Target loudness (LUFS, short-block meter) per category, then capped by true peak.
CATEGORY_LUFS = {
	"combat": -14.0, "movement": -18.0, "ki": -16.0, "weapons": -16.0,
	"pickups": -17.0, "ui": -18.0, "ambience": -24.0,
}
