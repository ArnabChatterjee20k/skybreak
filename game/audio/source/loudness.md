# Loudness report (written by bake.py)

Measured on the shipped OGG files: ITU-R BS.1770 integrated loudness with 100 ms blocks (pyloudnorm), true peak at 4x oversampling. Short transient cues sit below their category target when the -2 dBTP pre-encode ceiling caps them. Loop seam = wrap-around step / 99.9th percentile sample step (< 1 means no click).

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
