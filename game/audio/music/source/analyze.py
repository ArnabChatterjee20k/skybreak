"""Objective checks of the rendered score: loudness, peaks, stem sync, loop seams, tempo, key.

Usage: python3 game/audio/music/source/analyze.py [--png <out dir outside the repo>]
Prints a Markdown table and exits 1 if a hard rule fails.
"""
import argparse
import json
import os
import sys

import numpy as np
import pyloudnorm
import soundfile as sf
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
TRACKS = os.path.join(os.path.dirname(HERE), "tracks")
SR = 44100
METER = pyloudnorm.Meter(SR)
KRUMHANSL_MAJOR = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
KRUMHANSL_MINOR = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])
NOTES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def load(name):
	data, sr = sf.read(os.path.join(TRACKS, name), always_2d=True)
	assert sr == SR, name
	return data.T


def true_peak_db(x):
	return 20 * np.log10(max(np.max(np.abs(signal.resample_poly(x, 4, 1, axis=1))), 1e-9))


def lufs(x):
	return METER.integrated_loudness(x.T)


def seam_ratio(x):
	"""Sample jump across the loop seam relative to the largest jump inside the file (<= 1: no click)."""
	mono = x.mean(axis=0)
	return abs(mono[0] - mono[-1]) / max(np.max(np.abs(np.diff(mono))), 1e-9)


def _spec(seg):
	return np.abs(np.fft.rfft(seg * np.hanning(seg.size)))


def seam_flux(x, bars):
	"""Spectral change across the seam relative to the median change across the other bar lines (~1: seamless)."""
	mono = x.mean(axis=0)
	frame = int(0.02 * SR)
	bar = mono.size / bars
	def flux_at(i):
		i = int(round(i))
		seg = np.take(mono, np.arange(i - frame, i + frame), mode="wrap")
		return np.sum(np.abs(_spec(seg[frame:]) - _spec(seg[:frame])))
	others = [flux_at(b * bar) for b in range(1, bars)]
	return flux_at(0) / max(np.median(others), 1e-9)


def _onset(x, hop):
	mono = x.mean(axis=0)
	env = np.sqrt(np.convolve(mono ** 2, np.ones(hop) / hop, "same")[::hop])
	onset = np.maximum(np.diff(np.log(env + 1e-4)), 0)
	return onset - onset.mean()


def tempo_best(x, bpm):
	"""Onset autocorrelation (circular: the files loop) at one and two bars of the written tempo,
	against the best value at lags 3-12% away. A track that follows its tempo peaks at its own lags."""
	hop = 220
	onset = _onset(x, hop)
	spec = np.fft.rfft(onset)
	ac = np.fft.irfft(spec * np.conj(spec), onset.size)
	ac /= ac[0]
	fps = SR / hop
	def at(seconds):
		return float(ac[int(round(seconds * fps))])
	beat = 60.0 / bpm
	own = at(beat * 4) + at(beat * 8)
	others = max(at(beat * 4 * f) + at(beat * 8 * f) for f in (0.88, 0.91, 0.94, 0.97, 1.03, 1.06, 1.09, 1.12))
	return own, others


def key(x):
	mono = x.mean(axis=0)
	f, _, z = signal.stft(mono, SR, nperseg=8192)
	mag = np.abs(z).mean(axis=1)
	chroma = np.zeros(12)
	for fi, m in zip(f, mag):
		if 60 < fi < 2000:
			chroma[int(round(12 * np.log2(fi / 440.0) + 69)) % 12] += m
	best = (-2, "")
	for tonic in range(12):
		for prof, mode in ((KRUMHANSL_MAJOR, "major"), (KRUMHANSL_MINOR, "minor")):
			r = np.corrcoef(np.roll(prof, tonic), chroma)[0, 1]
			if r > best[0]:
				best = (r, f"{NOTES[tonic]} {mode}")
	return best[1]


def png(out, name, x):
	import matplotlib
	matplotlib.use("Agg")
	import matplotlib.pyplot as plt
	mono = x.mean(axis=0)
	fig, ax = plt.subplots(2, 1, figsize=(14, 6))
	t = np.arange(mono.size) / SR
	ax[0].plot(t[::20], mono[::20], lw=0.3)
	ax[0].set_xlim(0, t[-1])
	ax[0].set_ylim(-1, 1)
	ax[0].set_title(name)
	ax[1].specgram(mono, NFFT=2048, Fs=SR, noverlap=1024, cmap="magma", vmin=-120)
	ax[1].set_ylim(0, 12000)
	fig.tight_layout()
	fig.savefig(os.path.join(out, name.replace(".ogg", ".png")), dpi=80)
	plt.close(fig)


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--png", default="")
	args = ap.parse_args()
	manifest = json.load(open(os.path.join(HERE, "manifest.json")))
	failures = []
	total_bytes = 0
	print("| Track | File | LUFS | True peak dBTP | Samples | Seam jump | Seam flux | Tempo: onset autocorr at 1+2 bars of written bpm vs best 3-12% off | Key (estimated / written) |")
	print("|---|---|---|---|---|---|---|---|---|")
	for key_name, m in manifest.items():
		datas = [load(f) for f in m["files"]]
		for f, x in zip(m["files"], datas):
			total_bytes += os.path.getsize(os.path.join(TRACKS, f))
			lu, tp = lufs(x), true_peak_db(x)
			seam = f"{seam_ratio(x):.2f}" if m["loop"] else "n/a"
			flux = f"{seam_flux(x, m['bars']):.2f}" if m["loop"] else "n/a"
			if tp > -1.0:
				failures.append(f"{f}: true peak {tp:.2f} dBTP")
			if x.shape[1] != m["loop_samples"]:
				failures.append(f"{f}: {x.shape[1]} samples, expected {m['loop_samples']}")
			if m["loop"] and seam_ratio(x) > 1.0:
				failures.append(f"{f}: loop seam jump {seam_ratio(x):.2f}")
			own, other = tempo_best(x, m["bpm"]) if m["loop"] else (0.0, 0.0)
			if m["loop"] and m["kind"] != "battle" and own <= other:
				failures.append(f"{f}: onsets do not follow {m['bpm']} bpm")
			tempo_cell = f"{m['bpm']}: {own:.2f} vs {other:.2f}" if m["loop"] else f"{m['bpm']} (one-shot)"
			print(f"| {m['title']} | {f} | {lu:.1f} | {tp:.2f} | {x.shape[1]} | {seam} | {flux} | {tempo_cell} | {key(x)} / {m['key']} |")
			if args.png:
				os.makedirs(args.png, exist_ok=True)
				png(args.png, f, x)
		if m["kind"] == "battle":
			lengths = {x.shape[1] for x in datas}
			if len(lengths) != 1:
				failures.append(f"{key_name}: stem lengths differ {lengths}")
			calm, combat, climax = datas
			for label, mix in (("calm+combat", calm + combat), ("all stems", calm + combat + climax)):
				lu, tp = lufs(mix), true_peak_db(mix)
				own, other = tempo_best(mix, m["bpm"])
				print(f"| {m['title']} | sum: {label} | {lu:.1f} | {tp:.2f} | {mix.shape[1]} | {seam_ratio(mix):.2f} | "
						f"{seam_flux(mix, m['bars']):.2f} | {m['bpm']}: {own:.2f} vs {other:.2f} | {key(mix)} / {m['key']} |")
				if own <= other:
					failures.append(f"{key_name} {label}: onsets do not follow {m['bpm']} bpm")
				if tp > -1.0:
					failures.append(f"{key_name} {label}: true peak {tp:.2f}")
				if label == "all stems" and abs(lu - (-14.0)) > 1.0:
					failures.append(f"{key_name}: full mix {lu:.1f} LUFS")
	print(f"\nTotal music size: {total_bytes / 1e6:.2f} MB")
	if total_bytes > 40e6:
		failures.append("music over 40 MB")
	for f in failures:
		print("FAIL:", f)
	sys.exit(1 if failures else 0)


if __name__ == "__main__":
	main()
