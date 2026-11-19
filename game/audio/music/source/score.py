"""Turns written music (chords, melodies, patterns) into rendered stereo stems.

Notation used by themes.py:
- Melody: one token per step (an 8th note by default). A number is a scale
  degree (1 = tonic, 8 = tonic an octave up, 0 = the 7th below), with an
  optional '#' or 'b'. '-' holds the previous note, '.' is a rest, '|' is
  ignored (bar lines for reading).
- Bass: one token per 8th: R root, F fifth, O octave, T third, L low octave,
  '-' hold, '.' rest.
- Arp: one token per 16th: a digit indexes the chord tones upward, '.' rest.
- Drums: 16 characters per bar: X accent, x hit, o ghost, '.' rest.
"""
import numpy as np

import synth
from synth import SR

CHORDS = {
	"M": [0, 4, 7], "m": [0, 3, 7], "dim": [0, 3, 6], "aug": [0, 4, 8],
	"sus2": [0, 2, 7], "sus4": [0, 5, 7], "M7": [0, 4, 7, 11], "m7": [0, 3, 7, 10],
	"7": [0, 4, 7, 10], "add9": [0, 4, 7, 14], "m9": [0, 3, 7, 10, 14], "5": [0, 7],
}

SCALES = {
	"major": [0, 2, 4, 5, 7, 9, 11],
	"minor": [0, 2, 3, 5, 7, 8, 10],
	"dorian": [0, 2, 3, 5, 7, 9, 10],
	"mixolydian": [0, 2, 4, 5, 7, 9, 10],
	"lydian": [0, 2, 4, 6, 7, 9, 11],
	"harmonic_minor": [0, 2, 3, 5, 7, 8, 11],
	"phrygian_dominant": [0, 1, 4, 5, 7, 8, 10],
}

DRUMS = {
	"kick": lambda rng, v: synth.d_kick(rng, v),
	"snare": lambda rng, v: synth.d_snare(rng, v),
	"clap": lambda rng, v: synth.d_clap(rng, v),
	"hat": lambda rng, v: synth.d_hat(rng, v),
	"ohat": lambda rng, v: synth.d_hat(rng, v, open_hat=True),
	"shaker": lambda rng, v: synth.d_shaker(rng, v),
	"tom_hi": lambda rng, v: synth.d_tom(rng, v, 190.0),
	"tom_mid": lambda rng, v: synth.d_tom(rng, v, 140.0),
	"tom_lo": lambda rng, v: synth.d_tom(rng, v, 95.0),
	"taiko": lambda rng, v: synth.d_taiko(rng, v),
	"crash": lambda rng, v: synth.d_crash(rng, v),
	"ride": lambda rng, v: synth.d_ride(rng, v),
	"boom": lambda rng, v: synth.d_boom(rng, v),
}

VEL = {"X": 1.0, "x": 0.78, "o": 0.4}


class Stem:
	"""A stereo buffer one loop long plus a tail that folds back onto the start."""

	def __init__(self, song, reverb_seconds=2.2, tail_seconds=4.0):
		self.song = song
		self.n = song.loop_samples
		self.total = self.n + int(tail_seconds * SR)
		self.dry = np.zeros((2, self.total))
		self.send = np.zeros((2, self.total))
		self.reverb_seconds = reverb_seconds

	def add(self, mono, start_sample, gain=1.0, position=0.0, send=0.2):
		start = int(start_sample) % self.n
		stereo = synth.pan(mono * gain, position)
		end = start + stereo.shape[1]
		if end > self.total:
			# Wraps past the tail: the rest goes onto the loop start.
			cut = self.total - start
			self.add(mono[cut:], 0, gain, position, send)
			stereo = stereo[:, :cut]
			end = self.total
		self.dry[:, start:end] += stereo
		self.send[:, start:end] += stereo * send

	def render(self, rng, comp=None):
		ir = synth.reverb_ir(self.reverb_seconds, rng)
		mix = self.dry + synth.reverb(self.send, ir) * 0.55
		# Fold the tail onto the start so the loop is seamless.
		loop = mix[:, : self.n].copy()
		rest = mix[:, self.n:]
		while rest.shape[1] > 0:
			k = min(self.n, rest.shape[1])
			loop[:, :k] += rest[:, :k]
			rest = rest[:, k:]
		loop = synth.highpass(loop, 28, 2)
		if comp:
			loop = synth.compress(loop, **comp)
		return loop


class Song:
	def __init__(self, bpm, bars, root, scale, seed, beats_per_bar=4):
		self.bpm = bpm
		self.bars = bars
		self.root = root
		self.scale = SCALES[scale]
		self.scale_name = scale
		self.beats_per_bar = beats_per_bar
		self.rng = np.random.default_rng(seed)
		self.beat_samples = 60.0 / bpm * SR
		# Loop length is rounded once; bar positions stay fractional inside it.
		self.loop_samples = int(round(bars * beats_per_bar * self.beat_samples))

	def at(self, beat):
		return beat * self.beat_samples

	def degree(self, token):
		accidental = 0
		while token and token[-1] in "#b":
			accidental += 1 if token[-1] == "#" else -1
			token = token[:-1]
		d = int(token) - 1
		return self.scale[d % 7] + 12 * (d // 7) + accidental

	# ------------------------------------------------------------ writers

	def melody(self, stem, voice, text, octave, start_bar=0, step=0.5, vel=0.9,
			position=0.0, send=0.25, gain=1.0, transpose=0):
		tokens = [t for t in text.split() if t != "|"]
		notes = []
		for i, tok in enumerate(tokens):
			if tok == "-":
				if notes:
					notes[-1][2] += step
			elif tok == ".":
				continue
			else:
				notes.append([self.degree(tok), start_bar * self.beats_per_bar + i * step, step])
		for semis, beat, length in notes:
			midi = self.root + 12 * octave + semis + transpose
			f = synth.midi_hz(midi)
			n = int(length * self.beat_samples * 0.95)
			v = vel * (1.0 if (beat % 1.0) == 0 else 0.88)
			stem.add(voice(f, n, v, self.rng), self.at(beat), gain, position, send)
		return len(tokens) * step

	def chord_tones(self, chord, octave):
		offset, quality = chord
		return [self.root + 12 * octave + offset + s for s in CHORDS[quality]]

	def pads(self, stem, voice, progression, octave, bars, beats=None, vel=0.8,
			spread=0.6, send=0.4, gain=1.0, top=False):
		beats = beats or self.beats_per_bar
		for b in range(bars):
			chord = progression[b % len(progression)]
			tones = self.chord_tones(chord, octave)
			if top:
				tones = tones + [tones[0] + 12]
			for k in range(0, self.beats_per_bar, beats):
				for i, m in enumerate(tones):
					p = spread * (2 * i / max(1, len(tones) - 1) - 1)
					n = int(beats * self.beat_samples * 0.98)
					stem.add(voice(synth.midi_hz(m), n, vel, self.rng),
							self.at(b * self.beats_per_bar + k), gain / np.sqrt(len(tones)), p, send)

	def bass(self, stem, voice, progression, pattern, octave, bars, vel=0.9, gain=1.0, send=0.05):
		tokens = [t for t in pattern.split() if t != "|"]
		per_bar = self.beats_per_bar * 2
		for b in range(bars):
			chord = progression[b % len(progression)]
			root = self.root + 12 * octave + chord[0]
			third = CHORDS[chord[1]][1] if len(CHORDS[chord[1]]) > 2 else 7
			notes = []
			for i in range(per_bar):
				tok = tokens[(b * per_bar + i) % len(tokens)]
				if tok == "-" and notes:
					notes[-1][2] += 0.5
				elif tok in "RFOTL":
					semis = {"R": 0, "F": 7, "O": 12, "T": third, "L": -12}[tok]
					notes.append([root + semis, b * self.beats_per_bar + i * 0.5, 0.5])
			for m, beat, length in notes:
				n = int(length * self.beat_samples * 0.9)
				stem.add(voice(synth.midi_hz(m), n, vel, self.rng), self.at(beat), gain, 0.0, send)

	def arp(self, stem, voice, progression, pattern, octave, bars, vel=0.7, gain=1.0,
			position=0.0, send=0.3, step=0.25):
		tokens = [t for t in pattern.split() if t != "|"]
		per_bar = int(self.beats_per_bar / step)
		for b in range(bars):
			tones = self.chord_tones(progression[b % len(progression)], octave)
			ladder = tones + [t + 12 for t in tones] + [t + 24 for t in tones]
			for i in range(per_bar):
				tok = tokens[(b * per_bar + i) % len(tokens)]
				if tok == ".":
					continue
				m = ladder[int(tok)]
				n = int(step * self.beat_samples * 0.9)
				stem.add(voice(synth.midi_hz(m), n, vel, self.rng),
						self.at(b * self.beats_per_bar + i * step), gain, position, send)

	def drums(self, stem, patterns, bars, gain=1.0, fills=None, send=0.12, pans=None):
		"""patterns: name -> list of 16-step bar strings (cycled). fills: bar -> patterns."""
		pans = pans or {}
		for b in range(bars):
			use = dict(patterns)
			if fills and b in fills:
				use.update(fills[b])
			for name, bar_list in use.items():
				bar = bar_list[b % len(bar_list)] if isinstance(bar_list, list) else bar_list
				steps = len(bar)
				for i, ch in enumerate(bar):
					if ch not in VEL:
						continue
					hit = DRUMS[name](self.rng, VEL[ch] * (0.95 + 0.1 * self.rng.random()))
					beat = b * self.beats_per_bar + i * self.beats_per_bar / steps
					stem.add(hit, self.at(beat), gain, pans.get(name, 0.0),
							send * (0.3 if name in ("kick", "boom") else 1.0))

	def hit(self, stem, name, beat, vel=1.0, gain=1.0, send=0.2):
		stem.add(DRUMS[name](self.rng, vel), self.at(beat), gain, 0.0, send)

	def pump(self, loop, depth=0.5, every=1.0, release=0.22):
		"""Sidechain-style duck on each beat, for pads inside a stem."""
		n = loop.shape[1]
		t = (np.arange(n) % (every * self.beat_samples)) / SR
		env = 1.0 - depth * np.exp(-t / (release / 3))
		return loop * env
