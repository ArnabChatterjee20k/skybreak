# Skybreak web build

- Source: `main` at `2df1bdbc731fc48895871a3e28bd62ca4432f8a0` (`2df1bdbc`, the merge of `fix/pf-zone-hang`
  into main 820ca47): everything in the previous build (3b86467c) plus the **PF-ZONE-HANG** fix. FIGHT
  froze the page when a LOW/MEDIUM/HIGH quality was saved from Settings, because the zone then built
  live on the page's only thread. The web build now always uses WEB, which also repairs profiles
  already in that state on their next visit. Every zone launch shows a loading screen, zone packs
  retry fresh and old packs are pruned, and `sw.js` drops stale build caches.
  `reports/web/pf-zone-hang/README.md` on main.
- Godot: 4.7.2.stable.official.ed1daf0bf, official `web_nothreads_release` template (export templates
  `.tpz` SHA-512 checked against SHA512-SUMS.txt by `tools/web/build_web.sh`), `Web` preset, release;
  zone bakes rebaked (7 zones x 4 tiers), `voxel_zone_bake.gd --check` clean.
- Layout as before: files in `web/`, `web/index.html` is the root, `web/zones/` next to it (one zone pack
  fetched per match). `boot_cache.js`, `sw.js`, `version.json` (build `2df1bdbc...`, 19 files). No
  `.gz`/`.br`/`.import` files. Deployed by `.github/workflows/deploy-web.yml` on push.

## Files (bytes raw)

| file | raw |
|---|---:|
| index.pck | 56899180 (sha256 `dbcf4833d0010dee274182d8857a4eea8a0f3f793c82519ed9a88eb607b13d25`) |
| index.wasm | 39514754 |
| index.js | 279815 |
| **first load total** | **92.3 MB** (gzip 53.6 MB) |
| zones/ember_rift_web.6d63678ca6c6.pck | 21043904 |
| zones/frozen_peaks_web.799495e5b4f6.pck | 33001568 |
| zones/heartbloom_gardens_web.f50cf3e46c43.pck | 22360296 |
| zones/shattered_mesa_web.48e26f22cc6a.pck | 29732164 |
| zones/skyhold_ruins_web.8f80c52e9f4e.pck | 18805124 |
| zones/stormfall_city_web.2eb8fe47699e.pck | 59911012 |
| zones/verdant_falls_web.fcf59bb2ca78.pck | 15721540 |
| **zone packs total** | **191.3 MB** |

## Tests (headless Chromium, plain static server)

- `node tools/web/match_smoke_test.js` -> **PASS**: menu -> vs AI match ran 30 s with no console errors.
- `node tools/web/cache_test.js` -> **6/6 cache scenarios passed**.
- `node tools/web/upgrade_test.js` (746036c1 -> 61925008 -> fe71e7c8 -> 9e645967 -> 3b86467c -> this build in
  one persistent profile, an update cut off halfway) -> Pure Fight by mouse and by Enter, versus and a
  cold profile all reach a running match, and only this build stays cached. The same profile state that
  froze 9e645967 (`quality=2` in IndexedDB) reaches a Pure Fight match in Verdant Falls on this build.
- Merge verify: full GUT with zone bakes and `SKYBREAK_REQUIRE_BAKES=1`: 1981 tests, 1975 passing,
  **0 failing**, 10 pending; det_check `b8bab850a4256dc7` stable over two runs.
