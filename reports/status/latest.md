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

## Also on main, not live yet: mouse controls (MOUSE-CONTROLS lane, merged 13:20 UTC as 388564ab)

- Another lane merged **WASD + mouse in every mode** while this run was shipping: Pure Fight P1 left
  click light, middle click or Q medium, right click heavy, F throw, R technique, C finisher (J/K/L/U/I/O
  still work). P2's keys are unchanged and there is still no numpad key anywhere. Its evidence:
  `reports/controls/mouse/README.md`. **It is not in the live build**: the web build here is 6a731815,
  made and tested before that merge. The next ship run should build main and deploy it.

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
