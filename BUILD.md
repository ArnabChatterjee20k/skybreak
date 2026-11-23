# Skybreak web build

- Source: `main` at `6a731815730379892a6a8c2e806d16087872a36a` (`6a731815`, the merge of `fix/no-numpad`
  into main bbc45d0f): everything in the previous build (2df1bdbc, PF-ZONE-HANG) plus **no numpad keys
  anywhere**: Pure Fight's P2 plays on the arrows + `, . /` `; ' ]` `[` + Right Shift dash, P1 dashes on
  Left Shift. `reports/controls/no-numpad/README.md` on main.
- Godot: 4.7.2.stable.official.ed1daf0bf, official `web_nothreads_release` template (export templates
  `.tpz` SHA-512 checked against SHA512-SUMS.txt by `tools/web/build_web.sh`), `Web` preset, release;
  zone bakes rebaked (7 zones x 4 tiers), `voxel_zone_bake.gd --check` clean.
- Layout as before: files in `web/`, `web/index.html` is the root, `web/zones/` next to it (one zone pack
  fetched per match). `boot_cache.js`, `sw.js`, `version.json` (build `6a731815...`). No
  `.gz`/`.br`/`.import` files. Deployed by `.github/workflows/deploy-web.yml` on push.

## Files (bytes raw)

| file | raw |
|---|---:|
| index.pck | 56900524 (sha256 `24d2af226b996666df61036ef894c902ab8be9c8fe9e7fb52bf2209522db39be`) |
| index.wasm | 39514754 |
| index.js | 279815 |
| **first load total** | **92.3 MB** (gzip 53.6 MB) |
| zones/ember_rift_web.98d72d121f37.pck | 21083456 |
| zones/frozen_peaks_web.a2d6727f2104.pck | 33040224 |
| zones/heartbloom_gardens_web.2f5588f32087.pck | 22960328 |
| zones/shattered_mesa_web.5d002254c2ad.pck | 29872068 |
| zones/skyhold_ruins_web.ff5ce21efc4f.pck | 18921860 |
| zones/stormfall_city_web.b13878d9a85a.pck | 59937412 |
| zones/verdant_falls_web.6b6d7a4b9e95.pck | 15968868 |
| **zone packs total** | **201.8 MB** |

## Tests (headless Chromium, plain static server)

- `node tools/web/match_smoke_test.js` -> **PASS**: menu -> vs AI match ran 30 s with no console errors.
- `node tools/web/cache_test.js` -> **6/6 cache scenarios passed**.
- `node tools/web/upgrade_test.js` (3b86467c -> 2df1bdbc -> this build in one persistent profile, HIGH
  saved, an update cut off halfway) -> **PASS: 5 checks**: Pure Fight by mouse and by Enter, versus and a
  cold profile all reach a running match, and only this build stays cached.
- Merge verify: full GUT with zone bakes and `SKYBREAK_REQUIRE_BAKES=1`: 1993 tests, 1987 passing,
  **0 failing**, 10 pending; det_check `b8bab850a4256dc7` stable over two runs; QA quick equal to main.
