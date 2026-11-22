# Skybreak web build

- Source: `main` at `746036c1` (PR #141 specials merged onto the voxel art main 364f4b8: Kael and Vexa
  special kits, Momentum, Afterimage, hand glow on the voxel rigs).
- Godot: 4.7.2.stable.official.ed1daf0bf, official `web_nothreads_release` template (export_templates.tpz
  SHA-512 `ca4d71c4...ccb84079` checked against SHA512-SUMS.txt), `Web` preset, release, via
  `tools/web/build_web.sh`; zone bakes `voxel_zone_bake.gd --check` clean on 746036c1.
- Layout as before: files in `web/`, `web/index.html` is the root; host `web/zones/` next to it (one zone pack
  fetched per match, SHA-256 checked, cached). No `.gz`/`.br` copies; no COOP/COEP headers needed.
- Appwrite deploy: `cd web && tar -czf ../skybreak-web.tar.gz .` then the CLI step in `tools/web/DEPLOY.md`
  (the tarball is about 250 MB with the zone packs; check the site's upload limit).

## Files (bytes raw)

| file | raw |
|---|---:|
| index.pck | 56,594,896 (sha256 `9509a72c50851b4c96f686fa41f229ebb4cff3a974c819b5ee7ef02ab682f150`) |
| index.wasm | 39,514,754 |
| index.js | 279,815 |
| **first load total** | **92.0 MB** (gzip 53.4 MB) |
| zones/ember_rift_web.f3be2800599b.pck | 21,083,456 |
| zones/frozen_peaks_web.cf7ab2f5857c.pck | 33,040,224 |
| zones/heartbloom_gardens_web.f3d79a902dab.pck | 22,960,328 |
| zones/shattered_mesa_web.1cda098cf292.pck | 29,872,036 |
| zones/skyhold_ruins_web.49c6fdae53b2.pck | 18,921,892 |
| zones/stormfall_city_web.fcacbdee817c.pck | 59,937,476 |
| zones/verdant_falls_web.42dabaaa7580.pck | 15,968,868 |
| **zone packs total** | **192.4 MB** |

## Smoke test (headless Chromium, SwiftShader WebGL2, plain static server)

`node tools/web/match_smoke_test.js build/web` -> **PASS**: menu -> Vs AI -> zone -> Fight, 30 s of input,
no console errors. Load: start click -> engine running in 22.1 s from localhost. Frame time is not
meaningful here (SwiftShader, 0.5-1.7 fps); measure on a real GPU.
