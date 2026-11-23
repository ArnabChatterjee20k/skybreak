# Skybreak status (2026-11-23 13:52 UTC, ship lane)

## What's live

- Site: https://skybreak-web-6a113777000db893b12e.appwrite.network, built from `main` **6a731815**
  (`web-build` de63342c). **Live**: deploy workflow run 7
  succeeded at 13:48 UTC; its live check matched `index.pck` at 56900524 bytes (previous build 56899180).
  The live-profile seed/verify step in DEPLOY.md was not run: this cloud session cannot reach the site.
- New in this build: **no numpad keys anywhere** (owner: "also dont use any numpad keys for any fight
  techniques"). Pure Fight's second player now plays on the arrows and the keys under the right hand.
  Everything from the PF-ZONE-HANG build (2df1bdbc) is still in: FIGHT never freezes, every match
  starts behind a loading screen.
- Windows (`play-windows` 259519c1) is still the 3b86467c build: DEPLOY.md doesn't cover it, so it
  was not rebuilt. It has the old numpad P2 keys.

## On main, not live yet: mouse controls (MOUSE-CONTROLS lane) -> **main needs a web build**

- Owner: "we can use the mouse as well right? lmb and rmb???" **Yes, in every mode**, on main
  **d788fdc2**: left click light, right click heavy (MacBook trackpad: two-finger click), WASD moves;
  Pure Fight middle click or Q medium, F throw, R technique, C finisher; 3D unchanged (it already had
  the mouse) plus J/L/U/I/O keyboard keys. Every old key still works. Also fixed: the Pure Fight HUD
  did not scale, so in a 1280x720 or MacBook browser window P2's health bar was cut off; it now fits.
- Evidence: full GUT 2014 tests 0 failing, det_check `b8bab850a4256dc7`, QA quick and camera QA equal
  to main, the browser mouse test clicks LMB/RMB in a real build and sees 5L / 5H / light_1 / smash.
  `reports/controls/mouse/README.md`.
- **Not deployed**: a web build of d788fdc2 was made and mouse-tested here, but the DEPLOY.md gate
  (smoke test, and the upgrade test's cold-profile check) did not finish inside this run's time.
  Next ship run: build main d788fdc2 (or later) per `tools/web/DEPLOY.md` and push `web-build`.

## How to play: WASD + mouse, one player per laptop (after the next web build)

| Action | Pure Fight | 3D (vs AI, FFA, Training, Duo) |
|---|---|---|
| Move | A / D walk, W or Space jump, S crouch | W A S D, Space / C fly up / down |
| Light / heavy | **Left click / right click** | **Left click / right click** (hold to charge) |
| Medium | Middle click or Q | - |
| Throw / grab | F | F |
| Technique / specials | R + direction | 1 2 3 (ultimate 4) |
| Finisher | C (full meter) | - |
| Dash / block | Left Shift + direction / hold back or E | Shift / E |
| Camera | - | mouse (click once to grab, Esc lets go) |

Keyboard-only keys still work: J/K/L, U, I, O. Full table: `reports/controls/mouse/README.md`.

## Pure Fight keys (two players, one laptop)

| Action | P1 | P2 |
|---|---|---|
| Walk back / forward | A / D | Left / Right arrow |
| Jump | W or Space | Up arrow |
| Crouch | S | Down arrow |
| Light / medium / heavy | J / K / L | `,` / `.` / `/` |
| Throw | U | `;` |
| Technique key | I | `'` |
| Finisher (full meter) | O | `]` |
| Dash | **Left** Shift + direction, or tap twice | **Right** Shift + direction, or tap twice |
| Block | hold back (down-back for lows), or E | hold back (down-back for lows), or `[` |

Motions (236, 623, 214) are directions on the arrows for P2, not keypad keys. Training dummy: T.
The pause menu's move list and the character select name the same keys. The loading screen shows
only the zone name and a bar, so there was nothing to change there. A grep for
`kp_|numpad|num[0-9]` over `game/` and the docs finds only the numpad guard itself, comments about
"numpad notation" for directions, and the tutorial's keypad Enter (menu only, Return works).

## What changed this run

1. **`fix/no-numpad` merged** (main 6a731815, `--no-ff`) after main's PF-ZONE-HANG work was merged
   in (no conflicts). Evidence on the merge: zone bakes 7 x 4 fresh, `--check` clean; full GUT
   with `SKYBREAK_REQUIRE_BAKES=1`: **1993 tests, 1987 passing, 0 failing, 10 pending**; det_check
   `b8bab850a4256dc7` on two runs, identical (same as before); QA quick the same as main bbc45d0f,
   run back to back (same violations, every gameplay metric equal, ms +6 %).
2. **#106 AI variety: still not merged.** The ki-duel test now checks 10 seeds (every seed must
   throw ki blasts, mean >= 4.0, set from main's 5.5 average). #106 gives 5.1 and passes it
   honestly. But on the merge with the new main, QA quick is **worse than main**: feet off the
   ground in 8 of 21 matches, 16 frames (main: 4 matches, 5 frames; worst, Vexa's foot 1.1 m
   under the ground strafing on Ember Rift), and foot slide +22 %. The changed fights also show
   Brann's Heartstring Bow poking into his arm (filed as QA-25). So it stays on its branch with
   the evidence (`fix/issue-106-ai-variety`).
3. Web build of 6a731815: match smoke PASS, cache test 6/6, upgrade test PASS (5 checks: 3b86467c -> 2df1bdbc -> this build in one profile, HIGH saved, update cut off halfway; Pure Fight by mouse and Enter, versus and a cold profile reach a match). Evidence: `reports/web/no-numpad-ship/`.

## Still open, ranked

1. **#106 AI variety**, above: needs the foot grounding looked at before it can merge. The GitHub
   issue was already closed on 22 Nov; the change itself is not live.
2. DUO-ICE-RACE: on a busy machine, one Duo test run hit a WebRTC set-up race and logged a console
   error. Alone it passes. Small fix in the net code.
3. Rush tailgating (from #150), and the owner playing the held-Shift air tech.
4. #109 needs the GTX 1650 PC. The Windows build is still not tested on Windows.
5. No-numpad: real keyboard ghosting on your laptops can't be tested in the cloud. If a 3-4 key
   combo drops a key for one of you, say which. The combat training room still uses F1-F7.

## How to play

Main menu -> Pure Fight, Play (Vs AI), or Duo (sign in, Host gives a 5-letter code, partner Joins).
Pure Fight on one laptop: the key table above. Escapes: tap Shift with a direction during a blocked
string to dodge or sidestep out.

## Needs you

Nothing urgent. Try two-player Pure Fight on your laptops and say if any key combo drops.
