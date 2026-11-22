# Skybreak status (2026-11-22 16:10 UTC)

building: 61b47407 2026-11-22T17:51Z

## What's live

- Site: https://skybreak-web-6a113777000db893b12e.appwrite.network
- Built from `main` **9e645967**. The deploy's live check reads `version.json` build
  `9e645967856d252c592e9c5e2b5b1eb626056f4d` (Appwrite deployment 6b030ffc13acdcd9b423, workflow run 45040720624).
- Windows: branch `play-windows` (8 zip parts; README has the `copy /b` join and the sha256).
- Checks on this commit: full GUT 1956 tests, 0 failing; det_check the same on two runs; web match smoke PASS;
  cache test 6/6; Duo two-browser WebRTC test PASS (once its menu click was corrected, see below).
  Details: `reports/builds/2026-11-22-9e645967.md`.

## What's in it

- **Pure Fight** (new): side-on 1v1 hand-to-hand in any zone. Vs AI, two players on one keyboard,
  training dummy, move list, and online 1v1 through the Duo lobby.
- **Duo online**: you and your partner against AI legends, each on your own device.
- **Aura v2**: flame layers, voxel motes, ki gather, lightning.
- **Camera round 3**, faster loading on later visits (browser cache).
- **Issue fixes**: FFA-4 fighters no longer spawn on top of each other (#128), the dash afterimage is
  the fighter's silhouette, not an orange capsule (#127), fighters are no longer drawn inside each other or
  standing on heads (#73).

## How to play

- **Pure Fight**: Main menu -> Pure Fight. Pick legends; P2 can be AI or HUMAN (same keyboard).
  P1: A/D move, W or Space jump, S crouch, J/K/L light/medium/heavy, U throw, I technique, O finisher
  (full meter), Shift+direction dash, hold back to block. P2: arrows, Num1-6, Num0 dash.
  **TRAINING** on the same screen for a dummy with frame data.
- **Duo** (both of you, web or Windows): Main menu -> Duo -> sign in (owner `skybreak-player-1@example.com`,
  partner `skybreak-player-2@example.com`, the passwords you set) -> owner presses **Host**, reads the 5-letter
  code to the partner -> partner types it, **Join** -> host's **Game** picks Duo vs AI or Pure Fight 1v1 ->
  legends, zone -> both **Ready**, host **Start**. If it can't connect, try a phone hotspot on one side.

## Lanes

- **Pure Fight**: finished and merged (599ab6aa). Open: never played between two real devices yet;
  Lyra's robe hides her kicks; no gamepad.
- **Issue sweep**: finished and merged (677ce5c8). Open: #106 (AI repeats strings; fix waits on
  `fix/issue-106-ai-variety`), #109 (needs the GTX 1650 PC).
- **Move escape (#150)**: not merged. The branch is still working: it fixes getting out of blocked strings
  (dodges and side vanish now work mid-string) but its QA run shows more camera/foot violations than main,
  and it hasn't posted a full test run on current main. Not in this build.
- **Build tooling**: the Duo browser test clicks the old menu slot (Pure Fight moved Duo down one).
  Game is fine; the test needs a one-line fix (BUILD-DUO-TEST).

## GitHub issues that can be closed

Closing comments are ready in `reports/issues/triage.md`:
#73, #75, #77, #78, #80, #92, #93, #101, #127, #128, #134, #136 (fixed); #100, #114, #118, #119, #120
(obsolete with the voxel art); #13, #113, #144, #147 (tracking logs, superseded).
Still open: #106, #109, #150.

## Needs you

Nothing about money or accounts this time. If web Duo sign-in says "Invalid Origin", add the site as a
Web platform in Appwrite (steps in `reports/net/duo-online/README.md`).
