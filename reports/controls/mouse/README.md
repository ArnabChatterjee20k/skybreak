# Mouse controls: WASD + mouse in every mode

Owner, verbatim: "we can use the mouse as well right? lmb and rmb???" and "two person always on
duo mode online and not on the same laptop".

So the real setup is one player per laptop (Duo online, vs AI, Pure Fight, training), left hand on
WASD and right hand on the mouse. Branch `fix/mouse-controls`. Yes: **left click is light, right
click is heavy, in every mode**, and every keyboard key that worked before still works.

## The controls

### Pure Fight (side-on 1v1, Pure Fight training, Duo Pure Fight)

| Action | Mouse scheme (default) | Keyboard only (still works) |
|---|---|---|
| Walk back / forward | A / D | A / D |
| Jump / crouch | W or Space / S | W or Space / S |
| **Light attack** | **Left click** | J |
| Medium attack | Middle click (wheel button) or **Q** | K |
| **Heavy attack** | **Right click** | L |
| Throw | **F** | U |
| Technique key (+ direction) | **R** | I |
| Finisher key (full meter) | **C** | O |
| Dash | Left Shift + direction, or tap forward/back twice | same |
| Block | hold back (down-back for lows), or E | same |
| Training: cycle the dummy | T (or F4) | same |
| Pause / move list | Esc | Esc |

Techniques: a motion then a click, e.g. S, S+D, D + left click = quarter circle forward (when
facing right). Or the technique key + a direction. The mouse wheel does nothing in Pure Fight.

Every mouse action has a key next to WASD (Q medium, F throw, R technique, C finisher), so a
trackpad without a middle click loses nothing.

### 3D arena (Play vs AI, Free-for-All, Training, Duo)

| Action | Mouse scheme (default) | Keyboard only (still works) |
|---|---|---|
| Move | W A S D | same |
| Fly up / fly down | Space / C (tap C twice: dive to land) | same |
| **Light attack** | **Left click** | J (new) |
| **Heavy attack** (hold to charge) | **Right click** | L (new) |
| Lock on | Middle click or Tab | Tab |
| Switch target | Mouse wheel | (none needed in 1v1) |
| Camera | Move the mouse (click the game once to grab the pointer, Esc lets go) | follows the lock-on |
| Block / dodge-dash / vanish | E / Shift / Shift+E | same |
| Grab | F | F or U (new) |
| Ki blast / charge ki | Q / R | same |
| Specials 1 2 3 / ultimate | 1 2 3 / 4 | 1 (or I, new) 2 3 / 4 (or O, new) |
| Transform / combo breaker | T / X | same |
| Weapons: pick up, throw, next, previous, quick swap | G, V, B, Z, Y | same |
| Control hints on/off | H | H |
| Pause | Esc | Esc |

The 3D mode already had left/right/middle click and mouse look; it was not changed except for the
new keyboard-only keys. The close-combat side-on camera and its smoothing are untouched (no camera
file changed).

### Mac trackpad

A two-finger click arrives as a right click, so heavy works on a MacBook trackpad as it is. A
trackpad tap-to-click sends press and release a few milliseconds apart, shorter than one game tick
(16.7 ms); the game now remembers such a press until the next tick, so a tap is never lost. A
trackpad has no middle click: medium is also on Q in Pure Fight, lock-on also on Tab in 3D.

### Clashes checked

- Pure Fight P1's new keys Q / F / R / C are not used by P2 (arrows + `, . / ; ' ] [` + Right
  Shift), by the training dummy toggle (T / F4) or by Esc. The mouse never drives P2.
- 3D: the new J / L / U / I / O are not bound to anything else (flight up/down Space / C, ki charge
  R, lock-on Tab / middle click, hints H, weapons G V B Z Y). No key or button does two things
  (`test_default_keys_never_share_a_key_between_actions`, `test_mouse_and_keyboard_bindings_never_overlap_in_the_3d_defaults`).
- The wheel only switches target in 3D (non-critical); no fighter action is on it.
- No numpad key anywhere (`test_no_default_binding_anywhere_is_a_numpad_key`).

## What changed

- `game/input/pure_fight_keys.gd`: P1 gets left / middle / right click and Q / F / R / C next to
  J / K / L / U / I / O; mouse buttons are P1-only. Hint and move-list text lead with the mouse.
- `game/input/input_bindings.gd`: 3D keyboard-only keys J (light), L (heavy), U (grab), I (special
  1), O (ultimate).
- Both readers (`KeyboardMouseInput`, `PureFightKeys`) latch a press that starts and ends between
  two ticks (trackpad taps, very quick clicks) for one tick; a latch older than 2 physics frames
  (a menu or round intro in between) is dropped, so an old click never fires later.
- Pure Fight never captures the pointer (no mouse look there): resuming from pause no longer asks
  the browser for pointer lock (`MatchSession.uses_mouse_look()`). The 3D modes keep mouse look:
  the first click grabs the pointer, Esc or any menu releases it (unchanged).
- Rebinding (Settings -> Controls): light attack, heavy attack and lock-on are now on the screen,
  and any action can take a mouse button (left, right, middle, side buttons; not the wheel). A
  mouse button bound to one action moves off the other; keys stay. Saved in `user://settings.cfg`.
  Pure Fight keys are still not on that screen (they never were).
- Pure Fight shows a one-line mouse-first hint along the bottom for the first 12 seconds when a
  human plays P1 (vs AI, training, Duo). The 3D hint strip reads light / heavy from the bindings.
- Browser: the engine already cancels the right-click menu, middle-click autoscroll and wheel
  scroll on the canvas, and clicks keep the keyboard focus on the canvas; the new browser test
  proves both on a real build.
- Duo: mouse buttons map to the same action bits as keys, so they ride the same rollback input
  stream (a right click and L send identical bytes; `test_a_clicked_input_survives_the_wire_unchanged`).
- `game/input/web_input_probe.gd` (web only): logs the local player's presses and the moves they
  start in `window.skybreakInputs` for the browser test.
- `tools/web/controls_web.js mouse`: clicks in a real web build and reads the sim's moves.
- README, GAME_DESIGN §3 and §16.2, the Pure Fight report and the status how-to-play lead with the
  mouse scheme.

## Evidence

EVIDENCE_PLACEHOLDER
