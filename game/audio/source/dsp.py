"""Small DSP kit for baking Skybreak sound effects offline (numpy + scipy)."""
import numpy as np
from scipy import signal

SR = 44100


def t(dur):
	return np.arange(int(dur * SR)) / SR


def n(dur):
	return int(dur * SR)


def noise(rng, dur):
	return rng.uniform(-1.0, 1.0, n(dur))


def pink(rng, dur):
	"""Pink-ish noise: white through the Voss-McCartney approximation filter."""
	b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
	a = [1, -2.494956002, 2.017265875, -0.522189400]
	x = signal.lfilter(b, a, rng.standard_normal(n(dur) + 2000))[2000:]
	return x / (np.max(np.abs(x)) + 1e-9)


def brown(rng, dur):
	x = np.cumsum(rng.standard_normal(n(dur) + 4000))
	x = signal.lfilter([1, -1], [1, -0.995], x)[4000:]
	return x / (np.max(np.abs(x)) + 1e-9)


def _sos(kind, f, order=2):
	nyq = SR / 2.0
	if kind == "band":
		lo, hi = max(f[0], 10.0) / nyq, min(f[1], nyq * 0.95) / nyq
		return signal.butter(order, [lo, hi], btype="band", output="sos")
	return signal.butter(order, min(f, nyq * 0.95) / nyq, btype=kind, output="sos")


def lp(x, f, order=2):
	return signal.sosfilt(_sos("low", f, order), x)


def hp(x, f, order=2):
	return signal.sosfilt(_sos("high", f, order), x)


def bp(x, lo, hi, order=2):
	return signal.sosfilt(_sos("band", (lo, hi), order), x)


def sweep_lp(x, f_start, f_end, curve=1.0):
	"""One-pole low-pass whose cutoff glides from f_start to f_end (Hz)."""
	k = np.linspace(0.0, 1.0, len(x)) ** curve
	f = f_start + (f_end - f_start) * k
	g = 1.0 - np.exp(-2.0 * np.pi * f / SR)
	y = np.empty_like(x)
	acc = 0.0
	for i in range(len(x)):
		acc += g[i] * (x[i] - acc)
		y[i] = acc
	return y


def sweep_bp(x, f_start, f_end, q=2.0, curve=1.0):
	"""State-variable band-pass with a gliding centre frequency."""
	k = np.linspace(0.0, 1.0, len(x)) ** curve
	f = f_start * (f_end / f_start) ** k
	fc = 2.0 * np.sin(np.pi * np.minimum(f, SR / 6.0) / SR)
	damp = 1.0 / q
	low = band = 0.0
	y = np.empty_like(x)
	for i in range(len(x)):
		high = x[i] - low - damp * band
		band += fc[i] * high
		low += fc[i] * band
		y[i] = band
	return y


def env_exp(dur, tau, attack=0.002):
	tt = t(dur)
	e = np.exp(-tt / tau)
	a = n(attack)
	if a > 1:
		e[:a] *= np.linspace(0.0, 1.0, a)
	return e


def env_ad(dur, attack, decay_power=2.0):
	tt = np.linspace(0.0, 1.0, n(dur))
	e = np.where(tt < attack, tt / max(attack, 1e-6), ((1 - tt) / max(1 - attack, 1e-6)) ** decay_power)
	return np.clip(e, 0.0, 1.0)


def env_swell(dur, peak=0.6, power=2.0):
	"""Rises to the peak position, then falls: a whoosh pass-by shape."""
	tt = np.linspace(0.0, 1.0, n(dur))
	up = (tt / peak) ** power
	down = ((1 - tt) / (1 - peak)) ** power
	return np.where(tt < peak, up, down)


def tone(freq, dur, phase=0.0):
	"""Sine with a constant or per-sample (array) frequency."""
	if np.isscalar(freq):
		return np.sin(2 * np.pi * freq * t(dur) + phase)
	return np.sin(2 * np.pi * np.cumsum(freq) / SR + phase)


def glide(f0, f1, dur, curve=1.0, exp=True):
	k = np.linspace(0.0, 1.0, n(dur)) ** curve
	return f0 * (f1 / f0) ** k if exp else f0 + (f1 - f0) * k


def saw(freq, dur):
	ph = (np.cumsum(np.full(n(dur), freq) if np.isscalar(freq) else freq) / SR) % 1.0
	return 2.0 * ph - 1.0


def bell(freq, dur, decay=0.6, partials=((1, 1.0), (2.76, 0.5), (5.4, 0.25), (8.93, 0.12))):
	out = np.zeros(n(dur))
	for ratio, amp in partials:
		out += amp * tone(freq * ratio, dur) * env_exp(dur, decay / ratio ** 0.6, 0.001)
	return out


def pluck(rng, freq, dur, damping=0.996):
	"""Karplus-Strong plucked string."""
	period = max(2, int(SR / freq))
	buf = rng.uniform(-1, 1, period)
	out = np.empty(n(dur))
	for i in range(len(out)):
		v = buf[i % period]
		out[i] = v
		buf[i % period] = damping * 0.5 * (v + buf[(i + 1) % period])
	return out


def mix(*parts):
	size = max(len(p) for p in parts)
	out = np.zeros(size)
	for p in parts:
		out[: len(p)] += p
	return out


def at(x, offset):
	"""Delays x by offset seconds (pads with silence)."""
	return np.concatenate([np.zeros(n(offset)), x])


def reverb_tail(rng, x, length=0.8, wet=0.25, bright=4000):
	ir = noise(rng, length) * env_exp(length, length / 5.0)
	ir = lp(ir, bright)
	wet_sig = signal.fftconvolve(x, ir)[: len(x) + n(length)]
	wet_sig /= np.max(np.abs(wet_sig)) + 1e-9
	dry = np.concatenate([x, np.zeros(len(wet_sig) - len(x))])
	return dry + wet * wet_sig * np.max(np.abs(x))


def fade(x, fade_in=0.002, fade_out=0.01):
	x = x.copy()
	a, b = n(fade_in), n(fade_out)
	if a > 0:
		x[:a] *= np.linspace(0, 1, a)
	if b > 0:
		x[-b:] *= np.linspace(1, 0, b)
	return x


def make_loop(x, loop_dur, xfade=0.5):
	"""Turns x (at least loop_dur + xfade long) into a seamless loop of loop_dur
	by crossfading its tail over its head with an equal-power curve."""
	L, X = n(loop_dur), n(xfade)
	assert x.shape[-1] >= L + X
	out = x[..., :L].copy()
	k = np.linspace(0.0, 1.0, X)
	out[..., :X] = x[..., :X] * np.sin(0.5 * np.pi * k) + x[..., L : L + X] * np.cos(0.5 * np.pi * k)
	return out


def dc_block(x):
	return signal.lfilter([1, -1], [1, -0.9995], x, axis=-1)
