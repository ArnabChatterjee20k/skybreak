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
be two non-modifier keys from the same row; tell me which and I'll move that action.

## Evidence

(filled in below after the merge run)
