# Skybreak score: source

The whole soundtrack is composed as data and synthesised offline in numpy.
No samples, soundfonts or downloaded audio are involved, so every note and
every sound is original and the licence is simply the repo's own.

## Re-render

```sh
python3 -m pip install numpy scipy soundfile pyloudnorm matplotlib   # no apt needed
python3 game/audio/music/source/render.py            # all tracks (~2 min)
python3 game/audio/music/source/render.py --only ember_rift
python3 game/audio/music/source/preview.py stormfall_city   # 60 s preview mix
python3 game/audio/music/source/analyze.py --png /tmp/music_png   # checks; exits 1 on a failure
godot --headless --path . --import                   # pick up the new OGGs
```

Same code + same seeds = the same audio. `render.py` also writes
`manifest.json`, the Godot import options (loop, tempo) and
`game/audio/music/music_catalog.gd`, so the game's bar grid always matches the
files.

## Files

| File | What |
|---|---|
| `themes.py` | The music: keys, tempi, chord progressions, melodies, bass/arp/drum patterns, per-zone instruments |
| `score.py` | Notation parser and arranger: places notes on the bar grid, builds stems, folds reverb tails for seamless loops |
| `synth.py` | Instruments (supersaw lead, synth brass, strings, choir, FM bell, e-piano, Karplus-Strong pluck, marimba, flute...), drums (kick, snare, clap, hats, toms, taiko, crash, sub boom), reverb, compressor, lookahead limiter |
| `render.py` | Renders, masters and encodes everything |
| `preview.py` | The menu → calm → combat → climax → victory preview |
| `analyze.py` | LUFS, true peak, stem lengths, loop seams, tempo and key checks |

## Notation (`themes.py`)

- Melody: one token per 8th note. A number is a scale degree (`1` tonic,
  `8` tonic an octave up, `0` the 7th below), with optional `#`/`b`; `-` holds,
  `.` rests, `|` is just a bar line for reading.
- Bass: one token per 8th: `R` root, `F` fifth, `O` octave, `T` third, `L` low octave.
- Arp: one token per 16th, a digit picks a chord tone counting upward.
- Drums: 16 characters per bar: `X` accent, `x` hit, `o` ghost, `.` rest.

To change a hook, edit its four phrases in `themes.py` and re-render that zone.

## How the stems work

Each battle theme is 32 bars of 4/4 (a 16-bar hook, then again with the
second lead and harmony). Three stems share one sample-exact loop:

- **calm**: pads, a soft bass, an arp, light percussion, the hook on a soft voice in the second half
- **combat**: full drums with fills, driving bass, the lead hook, chord stabs
- **climax**: a counter-melody a third above the hook, choir/strings, war drums, crashes, a sub boom every 8 bars and a riser into the loop point

Layers stack: calm = calm stem, combat = calm + combat, climax = all three.
Tempi are chosen so a beat is a whole number of samples (44100·60/bpm), so
every bar line falls on an exact sample. Reverb and release tails past the loop
end are added back onto the loop start, so the loop is seamless and the first
bar already carries the tail of the last.

## Mastering

Each stem gets light bus compression and a stem limiter. The gain is shared by
all stems of a theme and chosen so the **sum of all three** is −14 LUFS
integrated with true peak at or below −1.5 dBTP (−1 dBTP after Vorbis).
Calm alone sits around −19 LUFS and calm+combat around −15.5 LUFS, which is the
intended rise in energy. OGG Vorbis 44.1 kHz stereo, ~110–130 kbps.

## Why composed in code (route A)

The stems have to line up to the sample and loop on the bar grid, and the
owner wants an original IP. Curated CC0/CC-BY tracks can't give three
matching stems per zone, seven zone flavours in one musical language, or
loops cut on bar lines; and an unknown track always carries some risk of
resembling something existing. Writing it as data also means anyone can
change a melody, key or tempo and re-render in two minutes.

Trade-off: these are synthesised instruments (no real orchestra or sampled
drums), so the sound is "synth-orchestral anime action" rather than a
recorded score. A later pass could swap in a CC0 soundfont for brass/strings
without changing the composition or the game code.
