# PF-ZONE-HANG: "the screen is stuck" on the Pure Fight zone select

Owner's report, live build 9e645967, desktop Chrome on a Mac: Pure Fight -> zone select ->
Verdant Falls -> FIGHT, and the game never moves on. The same steps work in an incognito tab.

## Cause, in plain words

The web Settings screen showed all four quality buttons: LOW, MEDIUM, HIGH and WEB. The
browser build only ships zones prebuilt for **WEB**. When any other quality was picked, it was
saved in the browser's own storage (`user://settings.cfg`, kept in IndexedDB). From then on,
pressing FIGHT found no prebuilt zone for that quality. So the game skipped the loading screen
and built the whole voxel zone from scratch, right there in the menu's frame, on the page's only
thread. That build takes **1 to 6 minutes natively** (Verdant Falls WEB: 377 s on one core here)
and longer in WebAssembly. The page stops drawing and stops answering, so it looks frozen on the
zone select with FIGHT highlighted, which is the owner's screenshot.

Incognito starts with empty storage, so its quality is the default, WEB, and the match loads.

The browser cache was **not** the cause. Replaying the real past builds in order in one persistent
profile (746036c1 before the service worker, then 61925008, fe71e7c8, 9e645967, with a versus
match on each and Pure Fight on 9e645967) reaches every match normally. The service worker serves
each build's own `zones/manifest.json` from that build's cache, so the manifest and the packs
can't mix across builds. The freeze appears only once a non-WEB quality is saved.

## Reproduction (real output)

`node scratchpad/visit.js` (exploratory script, not committed) in headless Chromium with a
persistent profile:

- Cold profile, 9e645967, Pure Fight -> FIGHT: zone pack downloads, match runs.
- Same build, `settings.cfg` with `quality=2` (HIGH) written to `/userfs/godot/app_userdata/Skybreak/`,
  Pure Fight -> FIGHT: the console prints
  `WARNING: VoxelZoneView: building shattered_mesa live (no bake at res://game/world/voxel_zone_kit/baked/shattered_mesa_high.scn)`
  and then `page.screenshot: Timeout 30000ms exceeded`: the page stopped answering.
- The upgrade path (4 builds in one profile, no settings change): every visit boots
  (`updated` / `reload` / `cached` as expected) and reaches the match.

## Fix (branch `fix/pf-zone-hang`)

1. **The web build always uses the WEB tier.** `GraphicsSettings.tiers(is_web)` lists the tiers
   a build offers; on the web that is only WEB. `load_saved` ignores any other saved tier, so a
   profile that is already broken, like the owner's, is repaired on its next visit without
   clearing anything. The web Settings screen shows only the WEB button. The desktop is unchanged.
2. **FIGHT always shows a loading screen.** `MatchConfig.loading_screen()` puts every zone level
   (versus and Pure Fight) behind `LoadingScreen`, even when there's no bake to load. When a zone
   really has to be built live (any other missing bake), the screen says
   "BUILDING THE ZONE, THIS CAN TAKE A MOMENT" and draws that text for a few frames before the
   build starts, so it never looks frozen.
3. **Zone packs fail loudly and retry.** `ZoneBakeDownload` retries any failure once, fresh from the
   network: a `?sbv=` query that the service worker never answers from its cache, with the cached
   pack dropped. If that also fails, the loading screen says "ZONE DOWNLOAD FAILED" and builds the
   zone live as before. Packs in `user://zone_bakes/` that the current manifest doesn't name
   (older builds) are deleted.
4. **The service worker cleans up after any update.** On activate, `sw.js` deletes every
   `skybreak-<build>` cache except the current pointer's and an update in progress
   (`pending.json`, written by `boot_cache.js`). It still uses `skipWaiting` + `clients.claim`.
   `boot_cache.js` registers with `updateViaCache: 'none'` and calls `reg.update()` on every boot,
   so a newer worker takes over from an older one on the same visit.
5. `MatchConfig` sets `window.skybreakMatch = {scene, zone, mode}` on the web once a match scene
   is in, so browser tests can tell a running match from a frozen page.

Regression tests (GUT): a saved LOW/MEDIUM/HIGH loads as WEB on the web and loads back unchanged on
desktop; the web Settings screen has no LOW/MEDIUM/HIGH; a zone level with no bake still gets a
loading screen that says it is building; a live build's note is drawn before `done`; a pack damaged
once is fetched again with `?sbv=` and mounts; a half-written cached pack is replaced; packs of
older builds are pruned.

Browser regression: `tools/web/upgrade_test.js` (in the `tools/web/DEPLOY.md` checklist).

## Evidence

See "Results" below (filled from the runs).
