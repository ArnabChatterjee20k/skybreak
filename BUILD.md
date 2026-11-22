# Skybreak web build

- Source: `main` at `fe71e7c81b574d59edefb1f662e66fe85414c540` (`fe71e7c8`): camera round 3 (#149),
  WEB-CACHE, aura v2 (flame layers, voxel motes, ki gather, lightning, aura light) and Duo online
  (T-D15b: sign in, host/join with a room code, WebRTC rollback vs AI) all merged.
- Godot: 4.7.2.stable.official.ed1daf0bf, official `web_nothreads_release` template (export_templates.tpz
  SHA-512 `ca4d71c4...ccb84079` checked against SHA512-SUMS.txt), `Web` preset, release, via
  `tools/web/build_web.sh`; zone bakes rebaked from a fresh checkout, `voxel_zone_bake.gd --check` clean.
- Layout as before: files in `web/`, `web/index.html` is the root; host `web/zones/` next to it (one zone pack
  fetched per match). `boot_cache.js`, `sw.js`, `version.json` (build `fe71e7c8...`, 19 files) for the
  browser cache. No `.gz`/`.br` copies; no COOP/COEP headers needed.
- Appwrite deploy: `cd web && tar -czf ../skybreak-web.tar.gz .` then the step in `tools/web/DEPLOY.md`.
  Not deployed by this build run (`SKYBREAK_SITES_KEY` was not set in the build environment).

## Files (bytes raw)

| file | raw |
|---|---:|
| index.pck | 56,704,864 (sha256 `514c88b9a985e9273bd918989304719cb66ec2f837983c72e4d344c9c40414b3`) |
| index.wasm | 39,514,754 |
| index.js | 279,815 |
| **first load total** | **92.1 MB** (gzip 53.5 MB) |
| zones/ember_rift_web.f3b8b7f18f42.pck | 21,083,456 |
| zones/frozen_peaks_web.13e3b580f73e.pck | 33,040,224 |
| zones/heartbloom_gardens_web.5836a39ae163.pck | 22,960,328 |
| zones/shattered_mesa_web.fe5195a147bd.pck | 29,872,036 |
| zones/skyhold_ruins_web.433e6d726f33.pck | 18,921,860 |
| zones/stormfall_city_web.5d2f09dc9eeb.pck | 59,937,412 |
| zones/verdant_falls_web.69b7c854ac69.pck | 15,968,868 |
| **zone packs total** | **192.4 MB** |

## Tests (headless Chromium, plain static server)

- `node tools/web/match_smoke_test.js build/web` -> **PASS**: menu -> Vs AI match ran 30 s with no console
  errors (boot mode "updated", build fe71e7c8). Frame time here is a software renderer's, not a GPU's.
- `node tools/web/cache_test.js build/web` -> **6/6 cache scenarios passed**.
- `node tools/net/duo_browser_test.js` on a debug export of the same commit -> **PASS**: two pages over
  real WebRTC with forced lag/loss, 7378 frames, 245 state hashes compared, 0 mismatched, no desync,
  0 console errors.

Full evidence: `reports/builds/2026-11-22-fe71e7c8.md` on `main`.
