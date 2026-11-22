# Skybreak web build

- Source: `main` at `9e645967856d252c592e9c5e2b5b1eb626056f4d` (`9e645967`): everything in the previous
  build (camera round 3, WEB-CACHE, aura v2, Duo online) plus **Pure Fight** (T-PF1: 2.5D 1v1 hand-to-hand,
  vs AI, local 2P, training, online 1v1 through the Duo lobby) and the **issue sweep** fixes (#128 FFA-4
  spawns, #127 silhouette dash afterimage, #73 drawn bodies eased apart).
- Godot: 4.7.2.stable.official.ed1daf0bf, official `web_nothreads_release` template (export templates and
  editor zip SHA-512 checked against SHA512-SUMS.txt), `Web` preset, release, via `tools/web/build_web.sh`;
  zone bakes rebaked from a fresh checkout, `voxel_zone_bake.gd --check` clean.
- Layout as before: files in `web/`, `web/index.html` is the root, `web/zones/` next to it (one zone pack
  fetched per match). `boot_cache.js`, `sw.js`, `version.json` (build `9e645967...`, 19 files). No
  `.gz`/`.br` copies. Deployed by `.github/workflows/deploy-web.yml` on push.

## Files (bytes raw)

| file | raw |
|---|---:|
| index.pck | 56888744 (sha256 `7d05a400411b43c7f428285773cf65afef586f8f95eb5bbe115b136cf9aa9422`) |
| index.wasm | 39514754 |
| index.js | 279815 |
| **first load total** | **92.3 MB** (gzip 53.6 MB) |
| zones/ember_rift_web.ff0944d1bd45.pck | 21083456 |
| zones/frozen_peaks_web.bec5c6416820.pck | 33040224 |
| zones/heartbloom_gardens_web.f23f419bbda7.pck | 22960328 |
| zones/shattered_mesa_web.4cc3be8e5f7b.pck | 29872036 |
| zones/skyhold_ruins_web.62683714e665.pck | 18921860 |
| zones/stormfall_city_web.9df939dc2549.pck | 59937412 |
| zones/verdant_falls_web.828fbc2f50aa.pck | 15968868 |
| **zone packs total** | **192.4 MB** |

## Tests (headless Chromium, plain static server)

- `node tools/web/match_smoke_test.js build/web` -> **PASS**: menu -> Vs AI match ran 30 s with no console
  errors (boot mode "updated", build 9e645967).
- `node tools/web/cache_test.js build/web` -> **6/6 cache scenarios passed**.
- Verify on main 9e645967: full GUT 1956 tests, 1950 passing, **0 failing**, 10 pending; det_check
  `65ec2f54272115fd` identical on two runs.

Full evidence: `reports/builds/2026-11-22-9e645967.md` on `main`.
