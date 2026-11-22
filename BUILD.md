# Skybreak web build

- Source: `main` at `61925008` (PR #149 camera round 3 merged: the locked opponent stays on screen
  with specials, voxel floor-aware camera; on top of WEB-CACHE 51275e98 and #141 specials).
- Godot: 4.7.2.stable.official.ed1daf0bf, official `web_nothreads_release` template (export_templates.tpz
  SHA-512 `ca4d71c4...ccb84079` checked against SHA512-SUMS.txt), `Web` preset, release, via
  `tools/web/build_web.sh`; zone bakes `voxel_zone_bake.gd --check` clean.
- Layout as before: files in `web/`, `web/index.html` is the root; host `web/zones/` next to it (one zone pack
  fetched per match, SHA-256 checked, cached). New with WEB-CACHE: `boot_cache.js`, `sw.js`,
  `version.json` (browser cache, update check). No `.gz`/`.br` copies; no COOP/COEP headers needed.
- Appwrite deploy: `cd web && tar -czf ../skybreak-web.tar.gz .` then the CLI step in `tools/web/DEPLOY.md`.

## Files (bytes raw)

| file | raw |
|---|---:|
| index.pck | 56,638,004 (sha256 `b22992e330a98eddd6f7bf9cf31e3dbd151513355276501b2ae8b41c0367d967`) |
| index.wasm | 39,514,754 |
| index.js | 279,815 |
| **first load total** | **92.0 MB** (gzip 53.4 MB) |
| zones/ember_rift_web.89435a5ad30b.pck | 21,043,872 |
| zones/frozen_peaks_web.13b49df5ee59.pck | 33,001,568 |
| zones/heartbloom_gardens_web.c942960afcbc.pck | 22,360,328 |
| zones/shattered_mesa_web.9e3037c4a5e7.pck | 29,732,164 |
| zones/skyhold_ruins_web.9d22b9872583.pck | 18,805,124 |
| zones/stormfall_city_web.7b95a2326b44.pck | 59,911,012 |
| zones/verdant_falls_web.5d568878920c.pck | 15,721,540 |
| **zone packs total** | **191.3 MB** |

## Smoke test (headless Chromium, plain static server)

`node tools/web/match_smoke_test.js build/web` -> **PASS**: menu -> Vs AI match ran 30 s with no console
errors (boot mode "updated", build 619250080bfc). Frame time here is a software renderer's, not a GPU's.
