# No numpad: two players on one laptop

Owner, verbatim: "also dont use any numpad keys for any fight techniques."

Branch `fix/no-numpad`. Pure Fight's second player used to play on Num1-6 and Num0, which a laptop
(a MacBook among them) does not have. Now no default key in the game is on the numpad, and the
two-player layout uses no F-keys, Ctrl/Cmd/Alt, Tab, Backspace, Insert/Home/End/PageUp/PageDown or
Enter either.

## Keys (Pure Fight, P1 and P2 on one keyboard)

| Action | P1 (left hand + right hand) | P2 (arrows + right-hand cluster) |
|---|---|---|
| Walk back / forward | A / D | Left / Right arrow |
| Jump | W or Space | Up arrow |
| Crouch | S | Down arrow |
| Light attack | J | `,` (comma) |
| Medium attack | K | `.` (full stop) |
| Heavy attack | L | `/` (slash) |
| Throw | U | `;` (semicolon) |
| Technique key | I | `'` (apostrophe) |
| Finisher key (full meter) | O | `]` |
| Dash | Left Shift + direction, or tap forward/back twice | Right Shift + direction, or tap twice |
| Block | hold back (down-back for lows), or E | hold back (down-back for lows), or `[` |

Motion techniques work the same for both: P2 does them on the arrows, with "forward" meaning toward
the opponent. Quarter circle forward (236) = Down, Down+forward, forward + attack; 623 = forward,
Down, Down+forward + attack; 214 = Down, Down+back, back + attack. Or the technique key + a
direction (forward/neutral, down, back). The finisher is 236236 + attack or the finisher key.

Pure Fight training: **T** (or F4) cycles the dummy (F4 alone needs Fn on a Mac).

On a MacBook the P2 cluster sits under the right hand's fingers: `, . /` on the bottom row,
`; '` above them, `[ ]` above those, Right Shift right next to `/`, and the arrows just below.

## Every numpad binding found (before)

| Where | What | Now |
|---|---|---|
| `game/input/pure_fight_keys.gd` `DEFAULTS[1]` | P2 light/medium/heavy Num1/2/3, throw Num4, technique Num5, finisher Num6, dash Num0, block Num. (with `, . / ; ' ] \` as extras) | arrows + `, . / ; ' ] [` + Right Shift; numpad and `\` removed |
| `game/input/pure_fight_keys.gd` `button_text()` | "Num1 2 3 / Num4 throw / Num5 technique / Num6 finisher" | built from the new key labels |
| `game/modes/pure_fight/pure_fight_match.gd` `move_list_text()` (pause menu) | "P2: arrows, Num1/2/3 attacks, Num4 throw, Num5 technique, Num6 finisher, Num0 dash." | both players' keys from `PureFightKeys.controls_text()`, plus a line saying 236 etc. are directions, not keypad keys |
| `game/ui/menus/character_select.gd` | "P2: AI OR SECOND PLAYER (ARROWS + NUMPAD)" | "(ARROWS + , . / ; ' ] [ + RIGHT SHIFT)" |
| `docs/GAME_DESIGN.md` §16.2 | P2 column Num1-6, Num0 | new table |
| `reports/pure-fight/README.md` Controls | Num1 2 3, Num4/5/6, Num0 | new table |
| `reports/status/latest.md` How to play | "P2: arrows, Num1-6, Num0 dash." | new keys |
| `game/modes/tutorial/tutorial_room.gd` | Enter **or keypad Enter** confirms a menu step | kept: menu only, not a fight key, and Return works |

Checked and clean: `project.godot` (no `[input]` numpad events), `game/input/input_bindings.gd` and
`game/app/control_settings.gd` (flight modes: versus, FFA, training room, Duo; no numpad defaults),
Duo online (each side plays with P1's keys), `tools/web/*` (no key lists besides the probes),
`README.md` (had no controls; now has the table). Godot's own `ui_*` menu actions keep their engine
defaults (they include keypad Enter); they are not fight keys.

Rebinding: the controls screen rebinds the flight game's actions only (Pure Fight keys are not on
it). Its defaults have no numpad keys; a player can still bind a numpad key there by choice.

## What changed

- `PureFightKeys`: the new P2 defaults; P1's dash pinned to **Left** Shift and P2's to **Right**
  Shift (`InputEventKey.location`, which Godot 4.7 reads on desktop and from the DOM `code` on the
  web), so neither Shift dashes the other player. `NUMPAD_KEYS` / `is_numpad_key()`,
  `default_events()`, `LABELS`, `controls_text()`.
- Move list, character select, training hint text and docs name the new keys.
- Pure Fight training: T cycles the dummy as well as F4.
- `tools/web/controls_web.js`: the `conflicts` probes now include every P2 key (arrows scroll,
  `/` and `'` open Firefox's quick find); new `rollover` mode for the two-player key matrix.

## Keyboard rollover

What was tested: headless Chromium (Playwright) holds every P1 chord (5 directions incl. diagonals
x no, one or two of 9 buttons) together with a sample of P2's busiest 3-4-key chords, and the
other way round: 2860 chords, up to 8 keys held at once. For each, every keydown and keyup must
reach the focused canvas with the right `code` (and Shift side), be suppressed (no scrolling or
quick find), and focus must stay on the canvas.

What can't be tested here: hardware ghosting. A laptop keyboard is a key matrix, and which
3-key-plus combinations ghost depends on the model; there is no physical keyboard in the cloud.
The layout is chosen to keep the risk low:

- Dash is on Shift for both players. Modifiers have their own lines in laptop matrices and are
  outside USB's 6-key limit, so dash never blocks or ghosts another key.
- P1's keys are all on the left half plus J-O; P2's are the arrows and the far-right
  punctuation, so the two players' keys share as few matrix rows and columns as possible.
- The usual busy moment (each player holding a diagonal + one button = 6 normal keys) fits in a
  6-key-rollover keyboard; Apple's built-in keyboards handle more than that.

Ghosting-safe set (by design, and passed in Chromium): any direction or diagonal + up to two
buttons per player, with dash (Shift) on top. If a combo drops a key on the owner's laptop, it will
be two non-modifier keys from the same matrix line; note the combo in `TODO.md` (NO-NUMPAD) and
the next controls run moves that action.

## Evidence

Cloud container, 4 cores, lavapipe; Godot `4.7.2.stable.official.ed1daf0bf`, web templates `.tpz`
SHA-512 OK. Branch first on main fe18f894, then merged with main 3b86467c (75f08248).

- **Zone bakes**: 7 zones x 4 tiers baked (xvfb + lavapipe, 3 jobs); `voxel_zone_bake.gd --check`
  exit 0.
- **New tests** `tests/input/test_pure_fight_keys.gd`: 12/12 pass (with `test_pure_fight_menu.gd`:
  17 tests, 642 asserts, 0 failing). They cover: no default binding (Pure Fight, flight game on web
  and desktop, every non-`ui_*` InputMap action) is a numpad key; no F-key, Ctrl/Cmd/Alt, Tab,
  Backspace, Insert/Home/End/PageUp/PageDown, Delete, Esc or Enter in the two-player layout; no key
  drives both players; Left Shift dashes only P1, Right Shift only P2; every P2 key sets its action
  and leaves P1 idle; both players holding a diagonal + two buttons at once; P2's 236 / 623 / 214
  on the arrows, technique key + down, light/medium/heavy, throw, finisher, Right Shift dash
  forward/back, double-tap dash, holding back guards, `[` block key; hints name no numpad key.
- **Full GUT, bakes present** (branch = main fe18f894 + this change): 1980 tests, 1973 passing,
  **1 failing**, 10 pending. The failure is main's known red, unchanged:
  `test_voxel_zone_camera` `verdant_falls: both on screen 926/976` (0.949 < 0.95), the same
  numbers as main 61b47407 in `reports/builds/2026-11-22-61b47407.md` (MOVE-ESCAPE-CAM, the
  GREEN-AND-SHIP lane's job). Main has 1968 tests; the 12 new ones all pass.
- **det_check**: two runs identical, `det_check total b8bab850a4256dc7`, the same as main
  (input mapping does not touch the sim).
- **Browser, real web export of this branch** (`controls_web.js conflicts`): PASS. Every P2 key
  (arrows, `, . / ; ' [ ]`, Right Shift + arrow, Right Shift + `/`) and Left Shift + D is
  suppressed on the focused canvas, focus never leaves the canvas, page scroll stays 0.
- **Browser rollover matrix** (`controls_web.js rollover --stub`, a page with the engine's own
  canvas key listeners): PASS, `2860 chords (P1 x P2, up to 8 keys held at once), 0 with a
  dropped, leaked or misrouted key`, `numpad keys in the layout: none`.
  The same matrix against the running build did not finish: a sample of 286, then 29 chords timed
  out (1500-1700 s) because the running game (swiftshader) stops answering Playwright's key calls
  after a few chords, most likely the held keys driving the main menu into a match load. Open.
- **QA quick, branch vs main** (QA_JOBS=3): main fe18f894 and the branch 202f6c30 give the same
  result: sim PASS, view FAIL with the same violations (foot_ground 4/21, camera_on_screen 1/21,
  pop 1/21), scenarios PASS, golden replays PASS, every feel metric identical; the branch's trend
  PASSes against main (`reports/qa/2026-11-23-202f6c30-quick.md`). Main's run showed
  +75 % sim/view ms only because Chromium was running beside it. Visual goldens were not run
  (run_qa's python had no numpy), the same on both.

### On the merge with main 3b86467c (75f08248)

- Full GUT, bakes required (`SKYBREAK_REQUIRE_BAKES=1`): **1985 tests, 1979 passing, 0 failing,
  10 pending** (main's 1973 + the 12 new ones).
- det_check: two runs identical, `det_check total b8bab850a4256dc7` (= main).
- QA quick (QA_JOBS=4, `reports/qa/2026-11-23-75f08248-quick.md`): sim PASS, view FAIL with the
  same violations as main d270c6ad (foot_ground 4/21, camera_on_screen 1/21, pop 1/21), scenarios
  and golden replays PASS; hitstop, pops, foot, camera jerk (0.0094) and on-screen share (0.9875)
  equal to main's d270c6ad run. Only wall-clock ms differ: sim 1.37 vs 1.16 ms/tick (+18 %), view
  1.56 vs 1.28 ms/frame (+21 %), over the 15 % line. This change adds no code to the soak's path
  (ZoneMatch never builds PureFightKeys) and every gameplay metric is identical, so this reads as
  4 jobs on 4 cores, but by the rule it is not proven "no worse": re-run at main's job count.

### On the merge with main bbc45d0f (PF-ZONE-HANG; 0090f427, evidence at 68eb50d1)

- Merge: no conflicts. PF-ZONE-HANG's new `LoadingScreen` shows only the zone name, a bar and
  "LOADING" (no key hints), so it needed no change. `grep -rniE 'kp_|numpad|num[0-9]'` over `game/`,
  `docs/`, `README.md` and `tools/web/*.js`: only `NUMPAD_KEYS` / `is_numpad_key()` (the guard),
  "numpad notation" comments for motion directions, the probe in `controls_web.js`, the "No numpad"
  lines in docs, and the tutorial's menu-only keypad Enter (above).
- Zone bakes: 7 zones x 4 tiers baked fresh (xvfb + lavapipe), `voxel_zone_bake.gd --check` exit 0.
- Full GUT, `SKYBREAK_REQUIRE_BAKES=1`: **1993 tests, 1987 passing, 0 failing, 10 pending**, exit 0
  (`gut_totals_merge_bbc45d0f.txt`).
- det_check: two runs identical, `det_check total b8bab850a4256dc7` (= main;
  `det_check_merge_bbc45d0f.txt`).
- QA quick, QA_JOBS=3, run back to back with nothing else on the box: main bbc45d0f
  (`reports/qa/2026-11-23-bbc45d0f-quick.md`) and this merge (`reports/qa/2026-11-23-68eb50d1-quick.md`)
  give the same result: sim PASS, view FAIL with the same pre-existing violations (foot_ground 4/21,
  camera_on_screen 1/21, pop 1/21), scenarios PASS, golden replays PASS, trend PASS. Every gameplay
  metric identical; sim 1.33 vs 1.255 ms/tick (+6 %), view 1.499 vs 1.418 ms/frame (+6 %), under the
  15 % line. Visual goldens not run on either.

## Status

**Merged into main** (`--no-ff`) after the evidence above.
