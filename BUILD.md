# Skybreak web build

- Source: `main` at `012ec23d6b1937347fdb3f22e3910651bdb718b4` (voxel art merge PR #148 at 62cd986, golden
  refresh 46da3b2, zone-bake embed fix 012ec23).
- Godot: 4.7.2.stable.official.ed1daf0bf, official `web_nothreads_release` template (export_templates.tpz
  SHA-512 checked against SHA512-SUMS.txt), `Web` preset, release, via `tools/web/build_web.sh`, zone bakes
  rebaked on 012ec23 and `voxel_zone_bake.gd --check` clean.
- Layout changed: the build is now committed as files in `web/` instead of one `skybreak-web.tar.gz`, because
  the voxel zone packs push an archive over GitHub's 100 MB file limit. `web/index.html` is the root; host
  `web/zones/` next to it (the game fetches one zone pack per match, checks its SHA-256 and caches it).
  No `.gz`/`.br` copies; no COOP/COEP headers needed (single-threaded).
- Appwrite deploy: `cd web && tar -czf ../skybreak-web.tar.gz .` then the CLI step in `tools/web/DEPLOY.md`
  (check the site's upload size limit: the tarball is about 250 MB with the zone packs).

## Files (bytes raw)

| file | raw |
|---|---:|
| index.pck | 56,542,000 (sha256 `9f696d3b4bbf0dfa22ba778491616a387b2e7b5ec3247a8f47b8f09635b8945a`) |
| index.wasm | 39,514,754 |
| index.js | 279,815 |
| index.html + worklets + icons | 48,247 |
| **first load total** | **91.9 MB** (gzip 53.3 MB) |
| zones/ember_rift_web.f5587f7e69c6.pck | 21,083,456 |
| zones/frozen_peaks_web.648f84d41fec.pck | 33,040,224 |
| zones/heartbloom_gardens_web.9bbe9aebc2e8.pck | 22,960,232 |
| zones/shattered_mesa_web.a730ace0566a.pck | 29,872,036 |
| zones/skyhold_ruins_web.402894a24d1d.pck | 18,921,892 |
| zones/stormfall_city_web.e806a8c1a5ba.pck | 59,937,476 |
| zones/verdant_falls_web.3198b0aa2543.pck | 15,968,868 |
| **zone packs total** | **192.4 MB** (one fetched per match) |

## Smoke test (headless Chromium, SwiftShader WebGL2, plain static server, no special headers)

- `node tools/web/match_smoke_test.js build/web` -> **PASS**: menu -> Vs AI -> Shattered Mesa (voxel, its zone
  pack fetched and mounted) -> Kael vs Vexa ran 30 s, no console errors. Load: click-to-start -> engine
  running in 23.0 s from localhost.
- The same test on 46da3b2 (before the embed fix) FAILED with 16 console errors: Mesa's WEB bake linked the
  baking machine's `user://voxel_prop_cache`, so it did not load in a fresh browser.
- Frame time is not meaningful here (SwiftShader, about 1-2 fps); measure on a real GPU.
