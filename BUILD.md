# Skybreak web build

- Source: `main` at `3b86467c3c1b325b19e91b0f3f6db7aba75f45e8` (`3b86467c`): everything in the previous
  build (9e645967: Pure Fight, Duo online, aura v2, camera round 3, issue sweep fixes) plus the **#150 move
  escape** (dodges, sidesteps and side vanish get you out of, or round, the opponent's strings), the rest
  of **#127** (every afterimage is a pose ghost) and **MOVE-ESCAPE-CAM** (the camera keeps both fighters
  framed when an escape leaves your back to a wall).
- Godot: 4.7.2.stable.official.ed1daf0bf, official `web_nothreads_release` template (export templates and
  editor zip SHA-512 checked against SHA512-SUMS.txt), `Web` preset, release, via `tools/web/build_web.sh`;
  zone bakes rebaked from a fresh checkout, `voxel_zone_bake.gd --check` clean.
- Layout as before: files in `web/`, `web/index.html` is the root, `web/zones/` next to it (one zone pack
  fetched per match). `boot_cache.js`, `sw.js`, `version.json` (build `3b86467c...`, 19 files). No
  `.gz`/`.br` copies. Deployed by `.github/workflows/deploy-web.yml` on push.

## Files (bytes raw)

| file | raw |
|---|---:|
| index.pck | 56897132 (sha256 `13cfed008b777edb4b67d0de71b214184c0407d1fdb774a121e710b71680abc5`) |
| index.wasm | 39514754 |
| index.js | 279815 |
| **first load total** | **92.3 MB** (gzip 53.6 MB) |
| zones/ember_rift_web.de5fb78aa9a9.pck | 21083456 |
| zones/frozen_peaks_web.b6cf4ccbd89e.pck | 33040224 |
| zones/heartbloom_gardens_web.bd00b17c157b.pck | 22960296 |
| zones/shattered_mesa_web.acb82eceb699.pck | 29872036 |
| zones/skyhold_ruins_web.0f6d99b6be17.pck | 18921860 |
| zones/stormfall_city_web.1f08800e004b.pck | 59937412 |
| zones/verdant_falls_web.226d1a15548d.pck | 15968868 |
| **zone packs total** | **192.4 MB** |

## Tests (headless Chromium, plain static server)

- `node tools/web/match_smoke_test.js build/web` -> **PASS**: menu -> Vs AI match ran 30 s with no console
  errors (boot mode "updated", build 3b86467c).
- `node tools/web/cache_test.js build/web` -> **6/6 cache scenarios passed**.
- `tools/net/duo_browser_test.js` (debug export, two pages over WebRTC, 3 min) -> **PASS**: 155 s of match,
  309 common state hashes, 0 mismatched, 0 console errors.
- Verify of the change merged as 3b86467c (origin/main had not moved): full GUT with zone bakes and
  `SKYBREAK_REQUIRE_BAKES=1`: 1973 tests, 1967 passing, **0 failing**, 10 pending; det_check
  `b8bab850a4256dc7` identical on two runs.

Full evidence: `reports/builds/2026-11-23-3b86467c.md` on `main`.
