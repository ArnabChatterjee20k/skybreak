# Skybreak status (2026-11-22 19:00 UTC)

## What's live

- Site: https://skybreak-web-6a113777000db893b12e.appwrite.network, **unchanged since 16:10**: built
  from `main` **9e645967**, `version.json` build `9e645967856d252c592e9c5e2b5b1eb626056f4d`
  (web-build bb2ea27a). Windows: `play-windows` 40f85810, same build.
- **Main moved to 61b47407 (the #150 move-escape fix) but it is red, so I didn't build or deploy it.**
  Details: `reports/builds/2026-11-22-61b47407.md`.

## Why main is red

Full GUT on 61b47407 (fresh checkout, zones baked): 1968 tests, 1961 passing, **1 failing**, 10 pending.
`test_voxel_zone_camera`: in the scripted Verdant Falls fight the camera keeps both fighters on screen
94.9 % of the time, and the test needs 95 %. The same failure happened on a second full run. On 6b618350,
the main just before the merge, it passes. So the **#150 merge (61b47407)** broke it: its new combat
timing and AI change how that fight plays out. The lane missed it because this test skips itself when the
zone bakes are missing, and the lane ran without them. det_check is stable (`b8bab850a4256dc7` on two
runs, the change the lane wrote up). Filed as MOVE-ESCAPE-CAM on the board.

## What's in the live build

Pure Fight, Duo online, aura v2, camera round 3, faster later loads, and the #128 / #127 / #73 fixes (as
in the 16:10 report). Waiting on main (not live): #150 move escape, and the rest of #127 (every
afterimage is now a pose ghost: specials, decoy, perfect dodge, tech).

## Lanes

- **Pure Fight**: finished and merged (599ab6aa). Open: never played on two real devices; Lyra's robe
  hides her kicks; no gamepad.
- **Issue sweep**: finished and merged (677ce5c8, follow-up c8257e91). Open: #106 (fix ready on
  `fix/issue-106-ai-variety`, not merged), #109 (needs the GTX 1650 PC).
- **Move escape (#150)**: merged (61b47407). Dodges, sidesteps and side vanish now get you out of
  blocked strings (112/112 required escapes vs 79 before). It broke the camera test above.

Next steps, ranked:
1. MOVE-ESCAPE-CAM: make the Verdant Falls camera test pass again (don't loosen the 95 %), then the next
   coordinator run builds and deploys.
2. Merge `fix/issue-106-ai-variety` (#106) with fresh evidence.
3. BUILD-DUO-TEST: the Duo browser test clicks the old menu slot (one-line fix in `tools/net/`).
4. Rush tailgating (from #150), plus an owner play of the held-Shift air tech.

## GitHub issues that can be closed

Closing comments are ready in `reports/issues/triage.md`:
#73, #75, #77, #78, #80, #92, #93, #101, #127, #128, #134, #136 (fixed); #100, #114, #118, #119, #120
(obsolete with the voxel art); #13, #113, #144, #147 (tracking logs, superseded).
#150 is fixed on main but not live yet: close it once the next build is deployed.
Still open: #106, #109.

## How to play

- **Pure Fight**: Main menu -> Pure Fight. Pick legends; P2 can be AI or HUMAN (same keyboard).
  P1: A/D move, W or Space jump, S crouch, J/K/L light/medium/heavy, U throw, I technique, O finisher
  (full meter), Shift+direction dash, hold back to block. P2: arrows, Num1-6, Num0 dash.
  **TRAINING** on the same screen gives a dummy with frame data.
- **Duo** (web or Windows): Main menu -> Duo -> sign in (owner `skybreak-player-1@example.com`,
  partner `skybreak-player-2@example.com`, the passwords you set) -> owner presses **Host** and reads the
  5-letter code to the partner -> partner types it and presses **Join** -> host's **Game** picks Duo vs AI
  or Pure Fight 1v1 -> legends, zone -> both **Ready**, host **Start**. If it can't connect, try a phone
  hotspot on one side.

## Needs you

Nothing about money, accounts or public things.
