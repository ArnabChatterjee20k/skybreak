"""Instruments, drums and effects for the Skybreak score, in plain numpy/scipy.

Every voice returns a mono float64 array at SR. Randomness comes from the
generator passed in, so a render is reproducible bit for bit.
"""
import numpy as np
from scipy import signal

SR = 44100


def midi_hz(note):
	return 440.0 * 2.0 ** ((note - 69) / 12.0)


# ---------------------------------------------------------------- oscillators

def _phase(freq, n, start=0.0, vibrato=0.0, vib_rate=5.5, vib_delay=0.15):
	t = np.arange(n) / SR
	f = np.full(n, float(freq))
	if vibrato > 0.0:
		ramp = np.clip((t - vib_delay) / 0.25, 0.0, 1.0)
		f = f * 2.0 ** (vibrato * ramp * np.sin(2 * np.pi * vib_rate * t) / 1200.0)
	return (start + np.cumsum(f) / SR) % 1.0, f / SR


def _blep(p, dt):
	out = np.zeros_like(p)
	lo = p < dt
	t = p[lo] / dt[lo]
	out[lo] = t + t - t * t - 1.0
	hi = p > 1.0 - dt
	t = (p[hi] - 1.0) / dt[hi]
	out[hi] = t * t + t + t + 1.0
	return out


def saw(freq, n, start=0.0, **kw):
	p, dt = _phase(freq, n, start, **kw)
	return 2.0 * p - 1.0 - _blep(p, dt)


def square(freq, n, start=0.0, width=0.5, **kw):
	p, dt = _phase(freq, n, start, **kw)
	s = np.where(p < width, 1.0, -1.0)
	s += _blep(p, dt)
	s -= _blep((p + 1.0 - width) % 1.0, dt)
	return s


def sine(freq, n, start=0.0, **kw):
	p, _ = _phase(freq, n, start, **kw)
	return np.sin(2 * np.pi * p)


def supersaw(freq, n, rng, voices=7, detune=18.0, **kw):
	out = np.zeros(n)
	for i in range(voices):
		cents = 0.0 if voices == 1 else detune * (2.0 * i / (voices - 1) - 1.0)
		out += saw(freq * 2 ** (cents / 1200.0), n, rng.random(), **kw)
	return out / np.sqrt(voices)


# ---------------------------------------------------------------- envelopes and filters

def adsr(n, a=0.005, d=0.1, s=0.7, r=0.1, gate=None):
	"""Envelope of n samples; the gate (in samples) is when release starts."""
	gate = n if gate is None else min(gate, n)
	t = np.arange(n) / SR
	env = np.where(t < a, t / max(a, 1e-6), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-6)))
	if gate < n:
		level = env[gate - 1] if gate > 0 else 0.0
		rel = level * np.exp(-(t[gate:] - t[gate]) / max(r, 1e-6))
		env[gate:] = rel
	return env


def perc(n, decay):
	return np.exp(-np.arange(n) / (SR * decay))


def lowpass(x, cutoff, order=2):
	sos = signal.butter(order, min(cutoff, SR * 0.45), "low", fs=SR, output="sos")
	return signal.sosfilt(sos, x)


def highpass(x, cutoff, order=2):
	sos = signal.butter(order, cutoff, "high", fs=SR, output="sos")
	return signal.sosfilt(sos, x)


def bandpass(x, lo, hi, order=2):
	sos = signal.butter(order, [lo, min(hi, SR * 0.45)], "band", fs=SR, output="sos")
	return signal.sosfilt(sos, x)


def swept(x, dark, bright, env):
	"""Filter envelope by blending a dark and a bright lowpassed copy."""
	return lowpass(x, dark) * (1 - env) + lowpass(x, bright) * env


def tail(n_note, release):
	return n_note + int(release * SR)


# ---------------------------------------------------------------- pitched voices

def v_supersaw_lead(f, n, vel, rng):
	m = tail(n, 0.18)
	x = supersaw(f, m, rng, voices=7, detune=14, vibrato=12) + 0.5 * square(f * 0.5, m, rng.random())
	env = adsr(m, 0.01, 0.25, 0.75, 0.15, gate=n)
	fenv = adsr(m, 0.005, 0.18, 0.45, 0.15, gate=n)
	return swept(x, 1800, 7000, fenv) * env * vel * 0.32


def v_brass(f, n, vel, rng):
	m = tail(n, 0.15)
	x = supersaw(f, m, rng, voices=5, detune=8, vibrato=8) + 0.6 * saw(f * 0.5, m, rng.random())
	env = adsr(m, 0.03, 0.2, 0.85, 0.12, gate=n)
	bright = np.clip(np.arange(m) / (0.06 * SR), 0, 1) * adsr(m, 0.0, 0.35, 0.55, 0.1, gate=n)
	return swept(x, 900, 4500, bright) * env * vel * 0.35


def v_stab(f, n, vel, rng):
	m = tail(min(n, int(0.3 * SR)), 0.12)
	x = supersaw(f, m, rng, voices=7, detune=22)
	env = perc(m, 0.16)
	return swept(x, 1200, 8000, perc(m, 0.05)) * env * vel * 0.3


def v_pad(f, n, vel, rng):
	m = tail(n, 0.8)
	x = supersaw(f, m, rng, voices=7, detune=25)
	env = adsr(m, 0.35, 0.6, 0.8, 0.7, gate=n)
	return lowpass(x, 2200) * env * vel * 0.16


def v_strings(f, n, vel, rng):
	m = tail(n, 0.5)
	x = supersaw(f, m, rng, voices=5, detune=10, vibrato=10, vib_rate=5.0)
	env = adsr(m, 0.12, 0.4, 0.85, 0.4, gate=n)
	return bandpass(x, 180, 5000) * env * vel * 0.2


def v_choir(f, n, vel, rng):
	m = tail(n, 0.7)
	x = supersaw(f, m, rng, voices=5, detune=12, vibrato=14, vib_rate=4.6)
	x = bandpass(x, 400, 900, 1) * 1.4 + bandpass(x, 1000, 1500, 1) * 0.6 + bandpass(x, 2300, 3000, 1) * 0.3
	env = adsr(m, 0.25, 0.5, 0.9, 0.6, gate=n)
	return x * env * vel * 0.28


def v_bass(f, n, vel, rng):
	m = tail(n, 0.05)
	x = saw(f, m, rng.random()) + 0.8 * sine(f, m) + 0.4 * square(f, m, rng.random())
	env = adsr(m, 0.003, 0.2, 0.7, 0.04, gate=n)
	fenv = perc(m, 0.09)
	return swept(x, 350, 2400, fenv) * env * vel * 0.4


def v_sub_bass(f, n, vel, rng):
	m = tail(n, 0.1)
	x = sine(f, m) + 0.25 * saw(f, m, rng.random())
	env = adsr(m, 0.01, 0.4, 0.9, 0.08, gate=n)
	return lowpass(x, 600) * env * vel * 0.5


def v_growl_bass(f, n, vel, rng):
	m = tail(n, 0.05)
	x = supersaw(f, m, rng, voices=3, detune=12) + sine(f * 0.5, m)
	x = np.tanh(2.5 * x)
	env = adsr(m, 0.004, 0.3, 0.8, 0.04, gate=n)
	return swept(x, 300, 1800, perc(m, 0.15)) * env * vel * 0.33


def v_pluck(f, n, vel, rng):
	"""Karplus-Strong string: a twangy guitar-like pluck."""
	m = tail(n, 0.6)
	period = max(2, int(round(SR / f)))
	buf = rng.uniform(-1, 1, period)
	buf = lowpass(np.tile(buf, 3), f * 6)[-period:]
	out = np.empty(m)
	out[:period] = buf
	# The averaging recurrence is vectorised per period.
	for start in range(period, m, period):
		prev = out[start - period:start]
		end = min(start + period, m)
		k = end - start
		nxt = 0.497 * (prev[:k] + np.roll(prev, 1)[:k])
		out[start:end] = nxt
	env = adsr(m, 0.001, 0.4, 0.6, 0.15, gate=n)
	return highpass(out, 80) * env * vel * 0.55


def v_square_pluck(f, n, vel, rng):
	m = tail(min(n, int(0.25 * SR)), 0.08)
	x = square(f, m, rng.random(), width=0.3)
	return swept(x, 900, 5000, perc(m, 0.05)) * perc(m, 0.14) * vel * 0.22


def v_bell(f, n, vel, rng):
	"""Two-operator FM bell."""
	m = tail(n, 1.6)
	t = np.arange(m) / SR
	index = 3.0 * perc(m, 0.6)
	x = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * f * 3.5 * t))
	return x * perc(m, 0.9) * vel * 0.25


def v_epiano(f, n, vel, rng):
	m = tail(n, 0.9)
	t = np.arange(m) / SR
	index = 1.8 * perc(m, 0.35) + 0.2
	x = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * f * t))
	x += 0.25 * np.sin(2 * np.pi * f * 4.0 * t) * perc(m, 0.08)
	env = adsr(m, 0.002, 1.2, 0.0, 0.3, gate=n) * 0.85 + perc(m, 2.5) * 0.15
	return x * env * vel * 0.3


def v_glock(f, n, vel, rng):
	m = tail(min(n, int(0.2 * SR)), 1.0)
	t = np.arange(m) / SR
	x = np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 2.76 * t) * perc(m, 0.2)
	return x * perc(m, 0.5) * vel * 0.2


def v_marimba(f, n, vel, rng):
	m = int(0.6 * SR)
	t = np.arange(m) / SR
	x = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 4.0 * t) * perc(m, 0.03)
	return x * perc(m, 0.22) * vel * 0.35


def v_flute(f, n, vel, rng):
	m = tail(n, 0.12)
	x = sine(f, m, vibrato=18, vib_rate=5.2) + 0.15 * sine(f * 2, m) + 0.05 * rng.standard_normal(m)
	x = lowpass(x, 5000)
	env = adsr(m, 0.06, 0.2, 0.85, 0.1, gate=n)
	return x * env * vel * 0.28


def v_soft_lead(f, n, vel, rng):
	m = tail(n, 0.2)
	x = 0.7 * square(f, m, rng.random(), width=0.5, vibrato=14, vib_rate=5.4) + 0.5 * sine(f, m, vibrato=14, vib_rate=5.4)
	env = adsr(m, 0.02, 0.3, 0.75, 0.18, gate=n)
	return lowpass(x, 2600) * env * vel * 0.25


# ---------------------------------------------------------------- drums

def d_kick(rng, vel=1.0, punch=1.0):
	n = int(0.45 * SR)
	t = np.arange(n) / SR
	f = 45 + 110 * np.exp(-t / 0.035) * punch
	body = np.sin(2 * np.pi * np.cumsum(f) / SR) * perc(n, 0.22)
	click = highpass(rng.standard_normal(n), 2000) * perc(n, 0.004) * 0.4
	return np.tanh(1.6 * (body + click)) * vel * 0.8


def d_snare(rng, vel=1.0):
	n = int(0.35 * SR)
	t = np.arange(n) / SR
	tone = np.sin(2 * np.pi * (185 + 40 * np.exp(-t / 0.02)) * t) * perc(n, 0.07)
	noise = bandpass(rng.standard_normal(n), 1200, 9000) * perc(n, 0.13)
	return (0.6 * tone + 0.8 * noise) * vel * 0.55


def d_clap(rng, vel=1.0):
	n = int(0.3 * SR)
	x = bandpass(rng.standard_normal(n), 900, 5000)
	env = np.zeros(n)
	for k, off in enumerate((0.0, 0.011, 0.022)):
		i = int(off * SR)
		env[i:] += perc(n - i, 0.006 if k < 2 else 0.12)
	return x * env * vel * 0.45


def d_hat(rng, vel=1.0, open_hat=False):
	n = int((0.3 if open_hat else 0.06) * SR)
	x = highpass(rng.standard_normal(n), 7000, 4)
	return x * perc(n, 0.12 if open_hat else 0.018) * vel * 0.28


def d_shaker(rng, vel=1.0):
	n = int(0.09 * SR)
	x = bandpass(rng.standard_normal(n), 4000, 12000)
	env = np.clip(np.arange(n) / (0.015 * SR), 0, 1) * perc(n, 0.025)
	return x * env * vel * 0.25


def d_tom(rng, vel=1.0, pitch=110.0):
	n = int(0.5 * SR)
	t = np.arange(n) / SR
	f = pitch * (1 + 0.6 * np.exp(-t / 0.04))
	x = np.sin(2 * np.pi * np.cumsum(f) / SR) * perc(n, 0.25)
	x += bandpass(rng.standard_normal(n), 200, 2000) * perc(n, 0.03) * 0.3
	return x * vel * 0.6


def d_taiko(rng, vel=1.0):
	n = int(0.9 * SR)
	t = np.arange(n) / SR
	f = 70 * (1 + 0.5 * np.exp(-t / 0.03))
	x = np.sin(2 * np.pi * np.cumsum(f) / SR) * perc(n, 0.4)
	x += lowpass(rng.standard_normal(n), 900) * perc(n, 0.05) * 0.5
	return np.tanh(1.3 * x) * vel * 0.75


def d_crash(rng, vel=1.0):
	n = int(2.2 * SR)
	x = highpass(rng.standard_normal(n), 3500, 2)
	return x * perc(n, 0.7) * vel * 0.22


def d_ride(rng, vel=1.0):
	n = int(0.5 * SR)
	t = np.arange(n) / SR
	x = highpass(rng.standard_normal(n), 6000) * 0.5 + np.sin(2 * np.pi * 5200 * t) * 0.2
	return x * perc(n, 0.2) * vel * 0.18


def d_boom(rng, vel=1.0):
	"""Sub drop for climax downbeats."""
	n = int(1.4 * SR)
	t = np.arange(n) / SR
	f = 38 + 60 * np.exp(-t / 0.08)
	return np.sin(2 * np.pi * np.cumsum(f) / SR) * perc(n, 0.5) * vel * 0.7


def d_riser(rng, seconds):
	n = int(seconds * SR)
	ramp = np.linspace(0, 1, n) ** 2
	x = rng.standard_normal(n)
	return (lowpass(x, 1500) * (1 - ramp) + highpass(x, 2500) * ramp) * ramp * 0.18


# ---------------------------------------------------------------- effects

def reverb_ir(seconds, rng, damp=6000.0):
	n = int(seconds * SR)
	irs = []
	for _ in range(2):
		x = rng.standard_normal(n) * np.exp(-np.arange(n) / (SR * seconds / 6.9))
		x = lowpass(x, damp)
		x[: int(0.012 * SR)] = 0.0
		irs.append(x / np.sqrt(np.sum(x ** 2)))
	return np.stack(irs)


def reverb(stereo, ir):
	wet = np.stack([signal.fftconvolve(stereo[c], ir[c])[: stereo.shape[1]] for c in range(2)])
	return wet


def compress(stereo, threshold_db=-18.0, ratio=3.0, attack=0.005, release=0.12, makeup_db=0.0):
	level = np.max(np.abs(stereo), axis=0)
	level = np.maximum(level, 1e-9)
	db = 20 * np.log10(level)
	over = np.maximum(db - threshold_db, 0.0)
	gr = over * (1 - 1 / ratio)
	# Attack/release smoothing of the gain reduction.
	a = np.exp(-1 / (attack * SR))
	r = np.exp(-1 / (release * SR))
	smooth = signal.lfilter([1 - r], [1, -r], gr)
	smooth = np.maximum(smooth, signal.lfilter([1 - a], [1, -a], gr))
	gain = 10 ** ((makeup_db - smooth) / 20)
	return stereo * gain


def limit(stereo, ceiling=0.89, lookahead=0.004, release=0.08):
	"""Lookahead peak limiter; treats the signal as a loop so the seam is limited too."""
	from scipy.ndimage import minimum_filter1d, uniform_filter1d
	n = stereo.shape[1]
	look = max(2, int(lookahead * SR))
	peak = np.max(np.abs(stereo), axis=0)
	need = np.minimum(1.0, ceiling / np.maximum(peak, 1e-9))
	held = minimum_filter1d(need, size=2 * look + 1, mode="wrap")
	# Instant attack (already ahead of the peak), exponential release, over two laps.
	block = 32
	rb = np.exp(-block / (release * SR))
	two = np.concatenate([held, held])
	mins = two[: two.size // block * block].reshape(-1, block).min(axis=1)
	env = np.empty_like(mins)
	prev = 1.0
	for i, target in enumerate(mins):
		prev = target if target < prev else prev * rb + target * (1 - rb)
		env[i] = prev
	g = np.repeat(env, block)
	g = np.concatenate([g, np.full(two.size - g.size, g[-1])])[n:]
	g = np.minimum(g, held)
	g = uniform_filter1d(g, size=look, mode="wrap")
	return stereo * g


def pan(mono, position):
	"""Equal-power pan, position in [-1, 1]."""
	angle = (position + 1) * np.pi / 4
	return np.stack([mono * np.cos(angle), mono * np.sin(angle)])
