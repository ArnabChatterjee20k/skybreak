"""Builds the ~60 s preview: menu -> a battle going calm -> combat -> climax -> victory.

It follows MusicDirector's rules: switches land on bar lines, the next track
crossfades over one bar, layers fade in over one beat, the stinger cuts the
loop with a 60 ms fade. Reads the committed OGGs.
Usage: python3 game/audio/music/source/preview.py [zone_id]
"""
import json
import os
import sys

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MUSIC = os.path.dirname(HERE)
SR = 44100


def load(name):
	data, _ = sf.read(os.path.join(MUSIC, "tracks", name), always_2d=True)
	return data.T


def ramp(n, start, length):
	"""0 before start, smoothstep up over length samples, 1 after."""
	t = np.clip((np.arange(n) - start) / max(1, length), 0, 1)
	return t * t * (3 - 2 * t)


def main():
	zone = sys.argv[1] if len(sys.argv) > 1 else "stormfall_city"
	manifest = json.load(open(os.path.join(HERE, "manifest.json")))
	menu_info, battle_info = manifest["menu"], manifest[zone]
	menu = load("menu.ogg")
	calm, combat, climax = (load(f) for f in battle_info["files"])
	victory = load("victory.ogg")

	menu_bar = int(round(60 / menu_info["bpm"] * 4 * SR))
	bar = 60 / battle_info["bpm"] * 4 * SR
	beat = bar / 4
	switch = 6 * menu_bar  # the battle starts on menu bar 7
	battle_len = battle_info["loop_samples"]
	total = switch + battle_len + victory.shape[1]
	out = np.zeros((2, total))

	# Menu, fading out over one menu bar from the switch.
	m = np.tile(menu, 2)[:, : switch + menu_bar]
	m = m * (1 - ramp(m.shape[1], switch, menu_bar))
	out[:, : m.shape[1]] += m

	# Battle: calm from bar 1, combat from bar 9, climax from bar 21; it fades in over one menu bar.
	n = battle_len
	combat_gain = ramp(n, int(8 * bar), int(beat))
	climax_gain = ramp(n, int(20 * bar), int(beat))
	b = calm + combat * combat_gain + climax * climax_gain
	b = b * ramp(n, 0, menu_bar)
	cut = int(0.06 * SR)
	b[:, -cut:] *= np.linspace(1, 0, cut)
	out[:, switch: switch + n] += b

	# Victory right on the loop's last bar line.
	out[:, switch + n:] += victory
	out = render.master_full(out)
	path = os.path.join(MUSIC, "preview", f"preview_{zone}.ogg")
	os.makedirs(os.path.dirname(path), exist_ok=True)
	frames = np.ascontiguousarray(np.clip(out, -1, 1).T, dtype=np.float32)
	with sf.SoundFile(path, "w", SR, 2, format="OGG", subtype="VORBIS", compression_level=render.VORBIS_LEVEL) as f:
		for i in range(0, frames.shape[0], 4096):
			f.write(frames[i:i + 4096])
	print(path, f"{total / SR:.1f} s", f"LUFS {render.lufs(out):.1f}", f"TP {render.true_peak_db(out):.2f}")


if __name__ == "__main__":
	main()
