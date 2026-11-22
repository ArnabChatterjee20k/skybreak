# WEB-CACHE: the web build cached in the browser

Owner request: cache the web build in the browser, check the server's version on launch
with a 3 s timeout, and fall back to the cached build if nothing answers.

## How it works

- **`version.json`** sits next to `index.html` on the same Appwrite Site. `tools/web/build_web.sh`
  writes it (`tools/web/write_version.sh`):
  `{"build": "<git sha>", "files": {path: sha256}, "sizes": {path: bytes}}`. It lists every
  deployed file, including `zones/manifest.json` and the zone packs. A dirty tree adds
  `-dirty-<content hash>` to the build id, so two different builds never share an id.
- **`sw.js`** (service worker) only reads. It looks up a pointer (`pointer.json` in the
  `skybreak-meta` cache) to the current build cache `skybreak-<build>` and serves those files
  from it. Anything else goes to the network. It never serves `sw.js`, the updater's downloads
  (`?sbv=`) or `version.json` from the cache. When offline, `version.json` gets an empty `{}`
  answer, so the page boots without a console error. A zone pack the game fetches during a
  match is stored in the current build cache. Zone pack names contain their content hash, so
  a stored pack never goes stale.
- **`boot_cache.js`** runs in the page before the engine script is loaded (the custom shell
  now injects `index.js` only after this step). It registers the worker, waits for it to take
  control, then fetches `version.json?t=<now>` with `cache: no-store` and an AbortController
  set to **3 s**:
  - No answer, an error or offline: **boot the cached build immediately**. With no cache at
    all, it loads from the network.
  - Same build, with every file present: boot the cache.
  - New build: it downloads only the files whose SHA-256 differs from the cached build's
    `version.json`, into a new `skybreak-<new build>` cache. The boot screen shows
    `Updating x / y MB`. Unchanged files are copied over from the old cache, and so are zone
    packs the new build still lists. Every download is checked against its SHA-256. Writing
    the pointer is the **atomic swap**, and only after it are the old caches deleted.
    - If `index.html` changed, the page reloads once so the new shell, with its new engine
      config, runs.
    - If the update fails or is cut off, the pointer still names the old cache, which nothing
      has touched, so the old build boots. A partly filled new cache is reused on the next
      launch (resume) and deleted after the next successful swap.
  - First visit: the same path with an empty old cache. Each file is downloaded once, into
    the cache, and the engine then reads it from there.
- **Storage:** before an update the page calls `navigator.storage.persist()` and checks
  `navigator.storage.estimate()` against the bytes it needs plus 8 MB. If that doesn't fit,
  it deletes stale build caches and checks again. If it still doesn't fit, or a write throws
  `QuotaExceededError`, it drops the cache and loads from the network. It never fails because
  of storage.
- The page exposes the result as `window.skybreakBootResult` and logs it to the console
  (`Skybreak boot: {...}`), with mode `cached`, `updated`, `reload` or `network`, the build,
  what was fetched and the time to decide.

## Tests: `tools/web/cache_test.js`

```sh
tools/web/build_web.sh
node tools/web/cache_test.js build/web reports/web/cache
```

The test runs headless Chromium (swiftshader) with one persistent profile on one origin. The
browser is closed and relaunched between visits. A local server can be stopped, can delay
`version.json`, can cut a download halfway, and logs every request. Builds B and C are hard-linked
copies of the real build, each with one file changed and its own `version.json`. Each scenario
fails on any console error.

Result on the build from `a3991ba` (official Godot 4.7.2, nothreads template, index.pck
56,594,896 bytes): **6/6 PASS**. Full output is in `cache_test_output.txt`, numbers in
`results.json`.

| | Scenario | Result | Timing |
|---|---|---|---|
| a | First load caches everything | PASS: mode `updated`, 11/11 build files cached, each downloaded exactly once by the updater and never again by the engine; the match's zone pack (`shattered_mesa_web.52357664e6b5.pck`) cached on demand | update done at 616 ms (worker + version.json + 96.45 MB download, local server); 120.4 MiB served incl. the 28.4 MiB zone pack, start click -> engine running 19.8 s, match reached |
| b | Server stopped, browser relaunched | PASS: mode `cached` ("no version.json"), reaches a match (`b_offline_match.png`) | decided at 11 ms, start button at 371 ms, engine 19.7 s |
| c | `version.json` delayed 6 s | PASS: mode `cached` at **3014 ms**, 0 build downloads, match reached | start button at 3482 ms |
| d | New build B, one changed file (`index.html`) | PASS: only `index.html` downloaded (6,864 B), 10 files copied, page reloaded once into B (marker checked), one cache left, zone pack carried over, match reached | update decided in 143 ms |
| e | Update to C interrupted halfway | PASS. e1: the connection drops at 50% of `index.pck`; the update fails, the pointer stays on B and B boots into a match. e2: the browser is killed at 50% of `index.pck`, then relaunched offline; B boots (pointer B; the partial `skybreak-C` waits to be resumed) | e1 decided in 168 ms |
| f | Quota 20 MB (CDP `Storage.overrideQuotaForOrigin`) | PASS: mode `network` ("not enough storage"), no caches left, the engine starts from the network | |

Screenshots: `a_first_load_match.png`, `b_offline_match.png`, `c_slow_version_match.png`,
`d_new_build_match.png`, `e_interrupted_match.png`, `e_after_browser_kill_menu.png`,
`f_small_quota_menu.png`.

Engine and match times are swiftshader (software WebGL) numbers, not player numbers.

## Verification

- Godot 4.7.2 linux x86_64 official (`4.7.2.stable.official.ed1daf0bf`), zip SHA-512 checked
  against `SHA512-SUMS.txt`. Export templates `.tpz` SHA-512 checked too.
  `rm -rf .godot && --headless --import`.
- Zone bakes are not in git: all 7 WEB bakes were baked here with `tools/voxel_zone_bake.gd
  --tier=web` before `build_web.sh` (7 zone packs, 191.5 MB).
- Full GUT (run on 5f357bf and again on a3991ba): 1826 tests, 1818 passing, 12 risky/pending, **0 failures** (main before: the same
  1826 / 1818 / 12).
- det_check: `det_check total 65ec2f54272115fd`, run twice, unchanged from main.
- `match_smoke_test.js build/web`: PASS ("menu -> vs AI match ran 30 s with no console errors";
  load 22.3 s, 92.0 MB served).

## Found and fixed on the way

- `rm -rf .godot && --import` imported `build/web/*.png` and wrote `.import` files into the
  build, which then appeared in `version.json`. `build_web.sh` now writes `build/.gdignore`.

## Open

- WEB-CACHE-1: zone packs are stored twice, in the worker's cache and in the game's own user://
  copy in IndexedDB (`ZoneBakeDownload`, 15-57 MB each). Drop one once this is live.
  `game/world/` belongs to the other team.
- WEB-CACHE-2: Appwrite's CDN headers for `version.json` are unverified on the live site. The
  page asks with `no-store` and a `?t=` query.
- In scenario f, Chromium's `estimate()` still reported the default quota under the CDP
  override, so the fallback came from the `QuotaExceededError` path, not from the estimate
  pre-check. Both lead to the same network boot.
- Scenario d changes `index.html` (the reload path). An `index.pck` download is covered by e
  (the cut) but not by a full successful swap of a different pck. The diff logic does not
  depend on which file changed.
- Two tabs updating at the same time are not coordinated. Both write the same files to the
  same new cache, so the result is the same, only downloaded twice.
- Not deployed: the BUILD-DEPLOY lane picks up `version.json`, `sw.js` and `boot_cache.js` from
  `build_web.sh` (also listed in `tools/web/DEPLOY.md`).
