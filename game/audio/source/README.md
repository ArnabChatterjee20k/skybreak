# Sound effect source

Every sound effect in `game/audio/sfx/` is synthesised by the Python in this folder:
no recordings, samples or third-party packs, so everything is CC0 (see
`game/audio/LICENSES.md`). Godot ignores this folder (`.gdignore`).

- `dsp.py`: noise, filters, gliding band-pass, envelopes, bells, Karplus-Strong
  pluck, reverb tail, and `make_loop` (equal-power tail-over-head crossfade).
- `sounds.py`: one recipe per cue plus its playback settings (voices, priority,
  bus, cooldown, pitch range, 3D attenuation, layers, duck). The single source of
  truth for the banks.
- `bake.py`: renders every variation (seeded per file), removes DC (25 Hz
  high-pass), trims trailing silence, levels each category to its loudness target,
  soft-saturates transient peaks, caps true peak at -2 dBTP, encodes Ogg Vorbis
  44.1 kHz with ffmpeg, then re-measures the shipped files. Writes
  `game/audio/banks/*_bank.tres`, `LICENSES.md` and `loudness.md`, and exits 1
  if any file breaks a mix rule (true peak > -1 dBTP, silent, DC > 0.002, loop
  seam click, wrong rate).
- `contact_sheet.py`: waveform + spectrogram PNGs for review by eye.

## Re-bake

```sh
python3 -m pip install numpy scipy soundfile pyloudnorm matplotlib   # ffmpeg with libvorbis on PATH
python3 game/audio/source/bake.py              # everything
python3 game/audio/source/bake.py ko hit_heavy # only these cues (banks are rewritten too)
python3 game/audio/source/contact_sheet.py /some/dir/outside/the/repo
godot --headless --path . --import
```

New loop files need `loop=true` in their `.ogg.import` (the AudioDirector also
sets it at runtime).

## Cues

| Category | Cue ids (×variations) |
|---|---|
| combat | `hit_light` ×4, `hit_medium` ×4, `hit_heavy` ×3, `impact_thump` ×3, `impact_tail` ×2, `launcher` ×2, `spike_bounce` ×2, `wall_splat` ×2, `armor_hit` ×2, `block` ×3, `perfect_block` ×2, `guard_break` ×2, `push_block` ×2, `grab` ×2, `throw` ×2, `tech` ×2, `counter_hit` ×2, `ko`, `ko_tail`, `combo_tick`, `whoosh_light` ×4, `whoosh_heavy` ×3 |
| movement | `dash` ×3, `air_dash` ×3, `rush_whoosh` ×2, `vanish_out` ×2, `vanish_in` ×2, `lock_on`, `lock_switch`, `land_light` ×3, `land_heavy` ×2, `flight_start` ×2, `flight_stop` ×2, `flight_wind_loop` |
| ki | `ki_charge_loop`, `aura_loop`, `power_up_burst` ×2, `ki_blast_fire` ×3, `ki_blast_impact` ×3, `beam_charge_loop`, `beam_fire`, `beam_loop`, `beam_clash` |
| weapons | `gauntlets_swing` ×3, `blade_swing` ×3, `lance_thrust` ×3, `hammer_swing` ×2, `chakram_throw` ×2, `scythe_swing` ×3, `bow_draw`, `bow_release` ×3, `revolver_fire` ×3, `revolver_reload`, `repeater_fire` ×4, `repeater_overheat`, `scatter_fire` ×2, `heartstring_draw`, `heartstring_release` ×3, `heartstring_tether` |
| pickups | `pickup_spawn`, `sky_drop_whistle`, `pickup` ×2, `weapon_switch` ×2, `weapon_throw` ×2 |
| ui | `ui_move` ×3, `ui_confirm`, `ui_back`, `round_count_3`, `round_count_2`, `round_count_1`, `round_fight`, `round_end`, `victory` |
| ambience | `amb_shattered_mesa`, `amb_skyhold_ruins`, `amb_stormfall_city`, `amb_frozen_peaks`, `amb_verdant_falls`, `amb_ember_rift`, `amb_heartbloom_gardens`, `stormfall_thunder` ×3 |

## Loudness (shipped files)

Integrated loudness (ITU-R BS.1770, 100 ms blocks, pyloudnorm) and 4x-oversampled
true peak, measured on the decoded Ogg files. Transient-heavy cues (hits, guns) sit
under their target where the peak ceiling caps them. Loop seam = wrap-around step
divided by the file's 99.9th-percentile sample step; under 1 means no click.

| Category | Files | Target LUFS | LUFS min / mean / max | Max true peak (dBTP) | Max DC | Worst loop seam |
|---|---|---|---|---|---|---|
| combat | 51 | -14 | -19.2 / -15.8 / -13.9 | -1.41 | 0.0015 | - |
| movement | 24 | -18 | -18.4 / -18.2 / -17.9 | -1.91 | 0.0004 | 0.34 |
| ki | 14 | -16 | -16.4 / -16.1 / -15.8 | -1.52 | 0.0003 | 0.33 |
| weapons | 36 | -16 | -21.1 / -17.3 / -16.0 | -1.52 | 0.0005 | - |
| pickups | 8 | -17 | -17.2 / -17.1 / -17.0 | -2.42 | 0.0001 | - |
| ui | 11 | -18 | -18.2 / -18.0 / -17.9 | -2.66 | 0.0003 | - |
| ambience | 10 | -24 | -24.6 / -24.2 / -24.0 | -5.07 | 0.0002 | 0.69 |

154 files, 2.82 MB of OGG Vorbis at 44.1 kHz.
