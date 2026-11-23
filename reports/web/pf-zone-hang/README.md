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

## Evidence (real runs, 2026-11-23, cloud container, 4 cores, headless Chromium + SwiftShader)

**The bug, end to end through the real UI** (build 9e645967, one persistent profile):
Settings -> Graphics -> HIGH, browser closed and reopened (IndexedDB `/userfs` then holds
`settings.cfg` with `quality=2`), Pure Fight -> Verdant Falls -> FIGHT. Console:
`WARNING: VoxelZoneView: building verdant_falls live (no bake at res://game/world/voxel_zone_kit/baked/verdant_falls_high.scn)`,
then `page.screenshot: Timeout 30000ms exceeded`: the page stopped answering on the zone select.

**The same broken profile on the fix** (main 2df1bdbc build, IndexedDB still holding `quality=2`):
the boot updates to 2df1bdbc (`reload`, then `cached`), FIGHT shows the loading screen
("DOWNLOADING ZONE 52%"), and 33 s later a Pure Fight match is running in Verdant Falls. Nothing
had to be cleared by hand.

**Upgrade test** `tools/web/upgrade_test.js` on main 2df1bdbc's build, replaying
746036c1 -> 61925008 -> fe71e7c8 -> 9e645967 -> 3b86467c (the live build) -> 2df1bdbc in one profile,
with an update cut off halfway (index.pck dropped at 50 %):

| check | result |
|---|---|
| Pure Fight -> Verdant Falls -> FIGHT (mouse) | PASS: match in 8.8 s, longest stall 1.8 s |
| Pure Fight -> FIGHT (Enter, Heartbloom Gardens) | PASS: match in 12.4 s, longest stall 4.0 s |
| Versus -> Ember Rift -> FIGHT | PASS: match in 14.8 s, longest stall 6.9 s |
| Only the new build is cached afterwards | PASS: `skybreak-meta` + `skybreak-2df1bdbc...`, no `pending.json` |
| Cold profile (like incognito), Pure Fight | PASS: match in 8.7 s |
| Control: old build with HIGH saved stalls >= 20 s | not shown in this run (see below) |

Known gap in the harness: in the scripted run, the "pick HIGH" visit didn't leave `settings.cfg` in
IndexedDB by the time the next visit started (read back afterwards: none), so the control didn't
freeze. Run alone, the same steps do persist `quality=2`, and the hand-driven runs above prove both
the freeze and the repair on such a profile. Filed as UPGRADE-TEST-SEED in TODO.md.

**Other checks on the merge with origin/main** (3b86467c, later 820ca47: reports only):

- Full GUT with all 28 zone bakes and `SKYBREAK_REQUIRE_BAKES=1`: 1981 tests, 1975 passing,
  **0 failing**, 10 pending (exit 0). Before the merge, on the branch alone: 1976 / 1969 / 1 failing,
  the MOVE-ESCAPE-CAM camera test that main fixed in 3b86467c.
- det_check: `det_check total b8bab850a4256dc7` on two runs, identical (same as main).
- `node tools/web/cache_test.js`: 6/6 scenarios PASS (first load, offline, slow version.json, one
  changed file, interrupted update, small quota).
- `node tools/web/match_smoke_test.js`: PASS (menu -> vs AI, 30 s, no console errors).
- Web build: index.pck 56,899,180 bytes (54.3 MB, under 60 MB), 7 zone packs 191.3 MB.

## Not fixed here

- LOADING-SCREEN-LAYOUT: the loading screen's bar and label draw clipped in the top-left corner
  instead of centred (old builds too). It still shows progress, so FIGHT no longer looks frozen.
- Live check from this session: the cloud proxy blocks the site's host (HTTP 403), so the live
  `version.json` and the live upgrade test can only be checked by the deploy workflow's
  "Check the live site" step or from another machine.

## Shipped

main `2df1bdbc` built and pushed to `web-build` 39c8784 at 08:37 UTC. Deploy workflow run 6 succeeded,
and its "Check the live site" step read the live `version.json` build `2df1bdbc731fc48895871a3e28bd62ca4432f8a0`
and a live index.pck of 56899180 bytes. The live upgrade test (`--live ... --phase verify`) could not
run from this session because the proxy blocks the site's host.
