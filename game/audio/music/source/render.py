"""Renders the whole Skybreak score to mastered OGG Vorbis files.

Usage (from the repo root):
	python3 game/audio/music/source/render.py [--only zone_id] [--preview]

Writes game/audio/music/tracks/*.ogg, game/audio/music/music_catalog.gd and
game/audio/music/source/manifest.json. Same code + same seeds = same audio.
"""
import argparse
import json
import os
import sys

import numpy as np
import pyloudnorm
import soundfile as sf
from scipy import signal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import score  # noqa: E402
import synth  # noqa: E402
import themes  # noqa: E402
from synth import SR  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MUSIC = os.path.dirname(HERE)
TRACKS = os.path.join(MUSIC, "tracks")
TARGET_LUFS = -14.0
TARGET_TP = -1.5  # Headroom for the encoder; the decoded file must stay at or below -1 dBTP.
VORBIS_LEVEL = 0.62  # libsndfile compression level, about 112-128 kbps for these mixes.
METER = pyloudnorm.Meter(SR)


def true_peak_db(stereo):
	up = signal.resample_poly(stereo, 4, 1, axis=1)
	return 20 * np.log10(max(np.max(np.abs(up)), 1e-9))


def lufs(stereo):
	return METER.integrated_loudness(stereo.T)


# ------------------------------------------------------------------ battle themes

def harmony(text, up=2):
	"""Diatonic harmony: every degree moved up (a third for up=2)."""
	out = []
	for tok in text.split():
		if tok in ("-", ".", "|"):
			out.append(tok)
		else:
			out.append(str(int(tok.rstrip("#b")) + up))
	return " ".join(out)


def stabs(song, stem, voice, progression, pattern, bars, octave=1, vel=0.7, gain=1.0, send=0.25):
	tokens = [t for t in pattern.split() if t != "|"]
	for b in range(bars):
		tones = song.chord_tones(progression[b % len(progression)], octave)
		i = 0
		while i < 8:
			if tokens[i % len(tokens)] == "x":
				length = 1
				while i + length < 8 and tokens[(i + length) % len(tokens)] == "-":
					length += 1
				for k, m in enumerate(tones):
					n = int(length * 0.5 * song.beat_samples * 0.9)
					stem.add(voice(synth.midi_hz(m), n, vel, song.rng),
							song.at(b * 4 + i * 0.5), gain / np.sqrt(len(tones)), 0.5 * (2 * k / max(1, len(tones) - 1) - 1), send)
				i += length
			else:
				i += 1


def battle(theme):
	t = theme
	bars = 32
	song = score.Song(t["bpm"], bars, t["root"], t["scale"], t["seed"])
	prog = t["progression"]
	mel = " ".join(t["melody"])
	calm_t, combat_t, climax_t = t["calm"], t["combat"], t["climax"]
	lead_oct = combat_t.get("lead_octave", 1)

	calm = score.Stem(song)
	song.pads(calm, calm_t["pad"], prog, 0, bars, beats=calm_t.get("pad_beats"), vel=0.75, gain=1.0)
	song.bass(calm, calm_t["bass"], prog, calm_t["bass_pat"], -1, bars, vel=0.8, gain=0.9)
	song.arp(calm, calm_t["arp"], prog, calm_t["arp_pat"], 1, bars, vel=0.55, gain=0.55, position=0.35)
	song.melody(calm, calm_t["lead"], mel, lead_oct, start_bar=16, vel=0.6, gain=0.6, position=-0.2, send=0.35)
	if calm_t["perc"]:
		song.drums(calm, calm_t["perc"], bars, gain=0.6, pans={"shaker": 0.4, "hat": 0.3, "ride": -0.3})

	combat = score.Stem(song, reverb_seconds=1.8)
	fills = {b: combat_t.get("fill", themes.FILL) for b in (7, 15, 23, 31)}
	song.drums(combat, combat_t["drums"], bars, gain=0.95, fills=fills, pans={"hat": 0.25, "tom_hi": 0.4, "tom_lo": -0.4, "shaker": 0.35})
	for b in (0, 16):
		song.hit(combat, "crash", b * 4, 0.9, gain=0.8)
	song.bass(combat, combat_t["bass"], prog, combat_t["bass_pat"], -1, bars, vel=0.9, gain=0.8)
	song.melody(combat, combat_t["lead"], mel, lead_oct, start_bar=0, vel=0.95, gain=0.9, send=0.25)
	song.melody(combat, combat_t["lead2"], mel, lead_oct, start_bar=16, vel=0.9, gain=0.85, send=0.25)
	stabs(song, combat, combat_t["stab"], prog, combat_t["stab_pat"], bars, vel=0.7, gain=0.45)

	climax = score.Stem(song, reverb_seconds=2.4)
	song.melody(climax, climax_t["counter"], harmony(mel), lead_oct, start_bar=0, vel=0.85, gain=0.6, position=0.3, send=0.3)
	song.melody(climax, climax_t["counter"], harmony(mel), lead_oct, start_bar=16, vel=0.85, gain=0.6, position=0.3, send=0.3)
	song.pads(climax, climax_t["choir"], prog, 1, bars, vel=0.7, gain=0.7, spread=0.8, send=0.5)
	song.drums(climax, climax_t["perc"], bars, gain=0.75, pans={"hat": -0.3, "tom_lo": -0.4, "tom_hi": 0.4})
	for b in range(0, bars, 8):
		song.hit(climax, "boom", b * 4, 0.9, gain=0.8, send=0.1)
	for b in range(0, bars, 4):
		song.hit(climax, "crash", b * 4, 0.7, gain=0.6)
	riser = synth.d_riser(song.rng, 2 * 4 * 60.0 / song.bpm)
	climax.add(riser, song.loop_samples - riser.size, 1.0, 0.0, 0.3)

	comp = dict(threshold_db=-20, ratio=2.5, attack=0.004, release=0.1, makeup_db=0)
	rendered = []
	for stem in (calm, combat, climax):
		rendered.append(stem.render(song.rng, comp))
	return song, master_stems(rendered)


def master_stems(stems, ceiling=0.6):
	"""Gains so the full sum sits at -14 LUFS with true peak <= TARGET_TP; stems share the gain."""
	g = 1.0
	best = None
	for _ in range(6):
		trial = [synth.limit(s * g, ceiling=ceiling) for s in stems]
		total = sum(trial)
		scale = min(1.0, 10 ** ((TARGET_TP - true_peak_db(total)) / 20))
		loud = lufs(total * scale)
		best = [s * scale for s in trial]
		if abs(loud - TARGET_LUFS) < 0.3:
			break
		g *= 10 ** ((TARGET_LUFS - loud) / 20)
	return best


def master_full(mix):
	return master_stems([mix])[0]


# ------------------------------------------------------------------ menu, select, stingers

def menu():
	t = themes.MENU
	bars = 16
	song = score.Song(t["bpm"], bars, t["root"], t["scale"], t["seed"])
	prog = t["progression"]
	mel = " ".join(t["melody"])
	st = score.Stem(song, reverb_seconds=2.6)
	song.pads(st, synth.v_pad, prog, 0, bars, vel=0.8)
	song.pads(st, synth.v_strings, prog, 1, bars, beats=2, vel=0.5, gain=0.5)
	song.bass(st, synth.v_bass, prog, "R . R R O . R R", -1, bars, vel=0.85, gain=0.75)
	song.melody(st, synth.v_brass, mel, 1, 0, vel=0.9, gain=0.9)
	song.melody(st, synth.v_supersaw_lead, mel, 1, 8, vel=0.9, gain=0.8)
	song.melody(st, synth.v_brass, harmony(mel), 1, 8, vel=0.7, gain=0.45, position=0.35)
	song.arp(st, synth.v_square_pluck, prog, "0 1 2 3 2 1 2 3 0 1 2 3 4 3 2 1", 1, bars, vel=0.5, gain=0.4, position=-0.35)
	half = {"kick": ["X.......X.x....."], "snare": ["........X......."], "hat": ["x.x.x.x.x.x.x.x."]}
	song.drums(st, half, 8, gain=0.85)
	drums8 = {k: v for k, v in themes.ROCK.items()}
	tmp = score.Stem(song)
	for b in range(8, 16):
		for name, pats in drums8.items():
			pat = pats[b % len(pats)]
			if b == 15:
				pat = themes.FILL.get(name, [pat])[0]
			for i, ch in enumerate(pat):
				if ch in score.VEL:
					tmp.add(score.DRUMS[name](song.rng, score.VEL[ch]), song.at(b * 4 + i / 4), 0.9, 0.2 if name == "hat" else 0.0, 0.1)
	song.hit(st, "crash", 0, 0.9, 0.8)
	song.hit(st, "crash", 32, 0.9, 0.8)
	mix = st.render(song.rng, dict(threshold_db=-20, ratio=2.5)) + tmp.render(song.rng)
	return song, master_full(mix)


def select():
	t = themes.SELECT
	bars = 16
	song = score.Song(t["bpm"], bars, t["root"], t["scale"], t["seed"])
	prog = t["progression"]
	st = score.Stem(song, reverb_seconds=1.6)
	song.drums(st, {"kick": ["X..x..X...X..x.."], "clap": ["....X.......X..."], "hat": ["x.xxx.xxx.xxx.xo"]}, bars, gain=0.85,
			fills={7: {"clap": ["....X.......XXXX"]}, 15: themes.FILL})
	song.bass(st, synth.v_bass, prog, "R . R O . R F O", -1, bars, vel=0.9, gain=0.8)
	stabs(song, st, synth.v_epiano, prog, ". x . x . x - .", bars, vel=0.8, gain=0.6)
	song.arp(st, synth.v_glock, prog, "0 . 2 . 4 . 3 . 0 . 2 . 5 . 4 .", 1, bars, vel=0.5, gain=0.45, position=0.4)
	hook = "5 - 4 5 . 7 - 8 | . . 5 4 3 - 1 - | 5 - 4 5 . 7 - 8 | 9 - 8 - 7 - 5 -"
	song.melody(st, synth.v_soft_lead, hook + " | " + hook, 1, 8, vel=0.8, gain=0.6, position=-0.2)
	song.hit(st, "crash", 0, 0.8, 0.6)
	mix = st.render(song.rng, dict(threshold_db=-20, ratio=2.5))
	return song, master_full(mix)


def one_shot(build, seconds, bpm, root, scale, seed):
	song = score.Song(bpm, 64, root, scale, seed)
	st = score.Stem(song, reverb_seconds=2.4)
	build(song, st)
	n = int(seconds * SR)
	ir = synth.reverb_ir(st.reverb_seconds, song.rng)
	mix = (st.dry + synth.reverb(st.send, ir) * 0.55)[:, :n]
	fade = int(0.4 * SR)
	mix[:, -fade:] *= np.linspace(1, 0, fade) ** 2
	mix[:, :32] *= np.linspace(0, 1, 32)
	return song, master_full(mix)


def victory():
	def build(song, st):
		# The main theme's opening, turned major and broadened into a fanfare.
		line = "1 - 5 - 4 3 4 5 | 8 - - - - - - - | - - - - - - - -"
		song.melody(st, synth.v_brass, line, 1, 0, vel=1.0, gain=1.0)
		song.melody(st, synth.v_brass, harmony(line), 1, 0, vel=0.8, gain=0.6, position=0.3)
		song.melody(st, synth.v_supersaw_lead, line, 2, 0, vel=0.7, gain=0.4, position=-0.3)
		for beat, chord in ((0, (0, "M")), (2, (5, "M")), (4, (0, "M"))):
			n = int((8 if beat == 4 else 2) * song.beat_samples)
			for k, m in enumerate(song.chord_tones(chord, 0) + [song.root + 12 + chord[0]]):
				st.add(synth.v_strings(synth.midi_hz(m), n, 0.8, song.rng), song.at(beat), 0.35, 0.5 * (k / 2 - 0.75), 0.5)
		for b in (0, 1.5, 2, 3, 3.5):
			song.hit(st, "taiko", b, 0.9)
		song.hit(st, "crash", 4, 1.0)
		song.hit(st, "boom", 4, 1.0)
		for i in range(8):
			song.hit(st, "snare", 3 + i / 8, 0.4 + i * 0.07, gain=0.7)
		song.bass(st, synth.v_sub_bass, [(0, "M")], "R - - - - - - -", -1, 3, vel=0.9)
	return one_shot(build, 5.2, 140, 57 + 3, "major", 21)


def defeat():
	def build(song, st):
		line = "5 - 4 - 3 - 2 - | 1 - - - - - - -"
		song.melody(st, synth.v_brass, line, 0, 0, vel=0.9, gain=0.9)
		song.melody(st, synth.v_brass, harmony(line, -2), 0, 0, vel=0.8, gain=0.7, position=0.3)
		for k, m in enumerate(song.chord_tones((0, "m"), -1) + [song.root - 12 + 12 + 7]):
			st.add(synth.v_choir(synth.midi_hz(m + 12), int(4 * song.beat_samples), 0.8, song.rng), song.at(4), 0.4, k / 2 - 0.5, 0.6)
		song.hit(st, "boom", 0, 1.0)
		song.hit(st, "taiko", 0, 1.0)
		song.hit(st, "taiko", 4, 0.9)
		song.hit(st, "crash", 0, 0.8)
	return one_shot(build, 3.8, 100, 57, "minor", 22)


# ------------------------------------------------------------------ output

def write_ogg(name, stereo):
	os.makedirs(TRACKS, exist_ok=True)
	path = os.path.join(TRACKS, name + ".ogg")
	frames = np.ascontiguousarray(np.clip(stereo, -1, 1).T, dtype=np.float32)
	# Written in blocks: libsndfile's Vorbis writer can crash on one huge write.
	with sf.SoundFile(path, "w", SR, 2, format="OGG", subtype="VORBIS", compression_level=VORBIS_LEVEL) as out:
		for i in range(0, frames.shape[0], 4096):
			out.write(frames[i:i + 4096])
	return path


def write_import_params(ogg_path, loop, bpm, beats):
	"""Sets Godot's import options (loop, tempo) next to the OGG, keeping the rest of the file."""
	path = ogg_path + ".import"
	params = f"[params]\n\nloop={'true' if loop else 'false'}\nloop_offset=0\nbpm={bpm}\nbeat_count={beats}\nbar_beats=4\n"
	if os.path.exists(path):
		text = open(path).read()
		text = text[: text.index("[params]")] + params if "[params]" in text else text + "\n" + params
	else:
		text = '[remap]\n\nimporter="oggvorbisstr"\ntype="AudioStreamOggVorbis"\n\n' + params
	open(path, "w").write(text)


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--only", default="")
	ap.add_argument("--wav-dir", default="", help="also keep float WAVs here (for analysis/preview)")
	args = ap.parse_args()
	manifest_path = os.path.join(HERE, "manifest.json")
	manifest = json.load(open(manifest_path)) if os.path.exists(manifest_path) else {}

	def emit(key, song, stereo_list, names, meta):
		files = []
		for stereo, name in zip(stereo_list, names):
			write_ogg(name, stereo)
			if args.wav_dir:
				os.makedirs(args.wav_dir, exist_ok=True)
				sf.write(os.path.join(args.wav_dir, name + ".wav"), stereo.T, SR, subtype="FLOAT")
			files.append(name + ".ogg")
			write_import_params(os.path.join(TRACKS, name + ".ogg"), meta["loop"], song.bpm,
					song.bars * song.beats_per_bar if meta["loop"] else 0)
		manifest[key] = dict(meta, files=files, bpm=song.bpm, beats_per_bar=song.beats_per_bar,
				bars=song.bars, loop_samples=int(stereo_list[0].shape[1]), sample_rate=SR)
		print("rendered", key, files, flush=True)

	for zone in themes.ZONE_ORDER:
		if args.only and args.only != zone:
			continue
		t = themes.THEMES[zone]
		song, stems = battle(t)
		names = [f"battle_{zone}_{layer}" for layer in ("calm", "combat", "climax")]
		key = midi_name(t["root"]) + " " + t["scale"].replace("_", " ")
		emit(zone, song, stems, names, dict(kind="battle", title=t["title"], mood=t["mood"], key=key, loop=True))

	for key, fn, kind, loop in (("menu", menu, "menu", True), ("character_select", select, "menu", True),
			("victory", victory, "stinger", False), ("defeat", defeat, "stinger", False)):
		if args.only and args.only != key:
			continue
		song, stereo = fn()
		src = {"menu": themes.MENU, "character_select": themes.SELECT}.get(key)
		title = src["title"] if src else {"victory": "Victory Fanfare", "defeat": "Fallen"}[key]
		mood = src["mood"] if src else {"victory": "Triumphant brass fanfare (~5 s)", "defeat": "Falling brass and choir KO stinger (~4 s)"}[key]
		tonic = src["root"] if src else (60 if key == "victory" else 57)
		scale = src["scale"] if src else ("major" if key == "victory" else "minor")
		emit(key, song, [stereo], [key], dict(kind=kind, title=title, mood=mood,
				key=midi_name(tonic) + " " + scale.replace("_", " "), loop=loop))

	json.dump(manifest, open(manifest_path, "w"), indent=1, sort_keys=True)
	write_catalog(manifest)


NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def midi_name(m):
	return NOTE_NAMES[m % 12]


def write_catalog(manifest):
	lines = [
		"class_name MusicCatalog",
		"extends RefCounted",
		"## Every music track and its bar grid. Generated by source/render.py: re-render, don't hand-edit.",
		"",
		"const DIR := \"res://game/audio/music/tracks/\"",
		"const LAYERS: Array[StringName] = [&\"calm\", &\"combat\", &\"climax\"]",
		"",
		"## Zone id -> battle theme: three stems that loop on the same bar grid.",
		"const BATTLE := {",
	]
	for zone in themes.ZONE_ORDER:
		if zone not in manifest:
			continue
		m = manifest[zone]
		lines.append(f"\t&\"{zone}\": {{\"title\": \"{m['title']}\", \"bpm\": {m['bpm']}, \"beats_per_bar\": {m['beats_per_bar']}, "
				f"\"bars\": {m['bars']}, \"loop_samples\": {m['loop_samples']}, \"stems\": {json.dumps([DIR_PREFIX + f for f in m['files']])}}},")
	lines.append("}")
	lines.append("")
	lines.append("## Non-layered tracks: menus loop, stingers play once.")
	lines.append("const SINGLE := {")
	for key in ("menu", "character_select", "victory", "defeat"):
		if key not in manifest:
			continue
		m = manifest[key]
		lines.append(f"\t&\"{key}\": {{\"title\": \"{m['title']}\", \"bpm\": {m['bpm']}, \"beats_per_bar\": {m['beats_per_bar']}, "
				f"\"loop\": {str(m['loop']).lower()}, \"samples\": {m['loop_samples']}, \"path\": \"{DIR_PREFIX + m['files'][0]}\"}},")
	lines.append("}")
	lines.append("")
	path = os.path.join(MUSIC, "music_catalog.gd")
	open(path, "w").write("\n".join(lines))


DIR_PREFIX = "res://game/audio/music/tracks/"

if __name__ == "__main__":
	main()
