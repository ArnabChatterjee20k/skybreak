# Skybreak status (2026-11-23 08:10 UTC)

## What's live

- Site: https://skybreak-web-6a113777000db893b12e.appwrite.network, built from `main` **3b86467c**
  (`version.json` build `3b86467c3c1b325b19e91b0f3f6db7aba75f45e8`, web-build 6c9d5cc6; checked by the deploy
  workflow, the cloud proxy blocks the site for me). Windows: `play-windows` 259519c1, same build.
- New in this build: **#150 move escape** (dodge, sidestep or side vanish out of, or round, the
  opponent's strings), every afterimage is now a pose ghost (#127), and the camera fix below.

## What changed

1. **Main is green again.** After #150, a dodge or air tech could leave you with your back to a wall.
   The camera was then squeezed close and lost the opponent beside or under the lens (the Verdant
   Falls test: 94.9 %, needs 95 %). Now, only in that squeezed case, it turns to keep you both in
   frame: 97.1 %. The close-combat camera is unchanged everywhere else. Camera QA is equal or better
   on every zone.
2. Full GUT with zone bakes: 1973 tests, **0 failing**, 10 pending. det_check unchanged
   (`b8bab850a4256dc7`, stable). QA quick is the same as main.
3. Tests that need zone bakes now fail, instead of skipping, when run with
   `SKYBREAK_REQUIRE_BAKES=1`. AGENTS.md tells lanes to bake first.
4. The Duo browser test clicks the right menu button again, and passes.

Details: `reports/builds/2026-11-23-3b86467c.md`.

## Still open, ranked

1. **#106 AI variety: not merged, needs your call.** It fails a ki-duel test that asks for more than
   10 ki blasts in one fixed fight. Main passes it only by luck: over 10 seeds main averages 5.5 blasts
   (only 1 seed over 10), and #106 averages 5.1. Options: make the hardest AI throw more ki, or let
   the test check several seeds. The change is ready on `fix/issue-106-ai-variety`.
2. DUO-ICE-RACE: on a busy machine, one Duo test run hit a WebRTC set-up race and logged one console
   error. The same test run alone passed. Worth a small fix in the net code.
3. Rush tailgating (from #150), and the owner playing the held-Shift air tech.
4. #109 needs the GTX 1650 PC. The Windows build is still not boot-tested on Windows.

## GitHub issues that can be closed

#150 is now live, so it can be closed. The ready comments in `reports/issues/triage.md` still apply
(#73, #75, #77, #78, #80, #92, #93, #101, #127, #128, #134, #136, and the obsolete or superseded
ones). Still open: #106 and #109.

## How to play

Same as before: Main menu -> Pure Fight, Play (Vs AI), or Duo (sign in, Host gives a 5-letter code,
partner Joins). Escapes: tap Shift with a direction during a blocked string to dodge or sidestep out.
Pure Fight keys after the next web build (no numpad): P1 A/D, W or Space, S, J/K/L, U throw,
I technique, O finisher, **Left** Shift + direction dash, hold back or E to block. P2 arrows,
`, . /` light/medium/heavy, `;` throw, `'` technique, `]` finisher, **Right** Shift + direction dash,
hold back or `[` to block. Training dummy: T. Table: `reports/controls/no-numpad/README.md`.

## Needs you

The #106 decision above. Nothing about money, accounts or public things.
