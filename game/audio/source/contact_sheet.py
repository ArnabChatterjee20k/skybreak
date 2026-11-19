"""Renders waveform + spectrogram contact sheets of the baked sounds, for review by eye.

Usage: python3 game/audio/source/contact_sheet.py <out dir> [category ...]
Write the PNGs outside the repo.
"""
import glob
import os
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import soundfile  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))


def sheet(paths, out_png, cols=4):
	rows = (len(paths) + cols - 1) // cols
	fig, axes = plt.subplots(rows * 2, cols, figsize=(cols * 4, rows * 3.2), squeeze=False)
	for k, path in enumerate(paths):
		data, rate = soundfile.read(path, always_2d=True)
		x = data.mean(axis=1)
		r, c = divmod(k, cols)
		wave, spec = axes[r * 2][c], axes[r * 2 + 1][c]
		tt = np.arange(len(x)) / rate
		wave.plot(tt, x, linewidth=0.4)
		wave.set_ylim(-1, 1)
		wave.set_title(os.path.basename(path), fontsize=8)
		wave.tick_params(labelsize=6)
		spec.specgram(x, NFFT=1024, Fs=rate, noverlap=768, cmap="magma", vmin=-120)
		spec.set_ylim(0, 16000)
		spec.tick_params(labelsize=6)
	for k in range(len(paths), rows * cols):
		r, c = divmod(k, cols)
		axes[r * 2][c].axis("off")
		axes[r * 2 + 1][c].axis("off")
	fig.tight_layout()
	fig.savefig(out_png, dpi=80)
	plt.close(fig)


def main():
	out = sys.argv[1]
	os.makedirs(out, exist_ok=True)
	categories = sys.argv[2:] or sorted(os.listdir(os.path.join(ROOT, "game", "audio", "sfx")))
	for category in categories:
		paths = sorted(glob.glob(os.path.join(ROOT, "game", "audio", "sfx", category, "*.ogg")))
		for start in range(0, len(paths), 16):
			png = os.path.join(out, "%s_%d.png" % (category, start // 16 + 1))
			sheet(paths[start:start + 16], png)
			print(png)


if __name__ == "__main__":
	main()
