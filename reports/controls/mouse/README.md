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
- Pure Fight shows a one-line mouse-first hint along the bottom for the first 12 seconds of fight
  time when a human plays P1 (vs AI, training, Duo). It counts sim ticks: the first version counted
  frame time (0cdc970e fixed that). The main build's screenshot then showed the real problem: the
  Pure Fight HUD was laid out in 1920x1080 pixels **without scaling**, so in a 1280x720 (or MacBook)
  browser window the hint sat below the window and **P2's health bar was cut off at the right
  edge**. The HUD now scales the 1920x1080 design to the window like the 3D HUD does (1080p is
  unchanged), in 88dff379. The 3D hint strip reads light / heavy from the bindings.
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

Cloud container, 4 cores, lavapipe / swiftshader; Godot `4.7.2.stable.official.ed1daf0bf`
(zip SHA-512 OK against `SHA512-SUMS.txt`), web templates `.tpz` SHA-512 OK.

- **Zone bakes**: 7 zones x 4 tiers baked (xvfb + lavapipe, 3 jobs, 7/7 exit 0);
  `voxel_zone_bake.gd --check` exit 0 (28 current).
- **New tests** `tests/input/test_mouse_controls.gd`, 20 tests / 293 asserts, all pass. They cover:
  LMB light / RMB heavy / MMB lock-on in the 3D reader; every 3D action reachable from each of its
  default events and the keyboard-only J / L / U / I / O / Tab; the wheel is only target switch; a
  held click stays one press while W / E / Shift change; a trackpad tap shorter than a tick still
  attacks (3D and Pure Fight) and a stale tap never fires later; a left click starts a move in the
  3D sim; Pure Fight P1's mouse scheme drives every button (LMB light, MMB medium, RMB heavy, F
  throw, R technique, C finisher, E block, Q medium, Left Shift dash) and leaves P2 idle; P1's
  J / K / L / U / I / O and A / D / W / Space / S still work; mouse buttons never reach P2; no key
  clashes between P1 and P2 or with the dummy toggle; in a real Pure Fight sim LMB = J, MMB = K =
  Q, RMB = L, F throws, R + down = 623, I + down still works, C finishes, 236 + LMB = Iron Lunge;
  a clicked input survives the Duo wire unchanged and RMB sends the same bytes as L; Pure Fight
  never captures the pointer while a 3D level does; mouse buttons are bindable (and move off other
  actions, persist, reset), the controls screen binds a click; hints lead with the mouse; Pure
  Fight's hint shows then fades; no numpad key in any default.
- **Full GUT on the merge with main 6a731815 (be1d1763)**, bakes required
  (`SKYBREAK_REQUIRE_BAKES=1`): **2013 tests, 2007 passing, 0 failing, 10 pending** (the known
  QA-11 / QA-12 / renderer / T-KI1-b pendings), exit 0 (`gut_merge_be1d1763.txt`).
- **det_check** on the merge: two runs identical, `det_check total b8bab850a4256dc7` (= main;
  input mapping does not touch the sim) (`det_check_merge.txt`).
- **Camera QA** (`voxel_camera_qa.gd -- 1200 7`): every zone identical to main's last log
  (Verdant Falls 97.1 %, the other six 100 %, clip frames 0) (`camera_qa_branch.log`). No camera
  file changed.
- **QA quick, main vs merge, same machine, 3 jobs**: main (bbc45d0f; 6a731815 only adds Pure Fight
  keys, not on the soak's path) and the merge be1d1763 give the same sections (sim PASS, view FAIL
  with the same hits: foot_ground 4/21, camera_on_screen 1/21, pop 1/21; scenarios, golden replays
  and the feel trend PASS; visual goldens not run on either) and **all 32 gameplay metrics
  identical**. Only wall-clock ms differ between those two runs: sim 1.18 vs 1.44 ms/tick, view
  1.33 vs 1.58 ms/frame. Main's own runs on these containers spread 1.16-1.37 / 1.28-1.56
  (`reports/qa/*/metrics.json`), and the harness's trend check against the newest main-code run
  (68eb50d1: 1.33 / 1.50) passes. A paired re-run of just the soak, alternating main 6a731815 and the merge (3 shards
  each, nothing else running), settles it: **main 1.417 / 1.405 ms per tick, merge 1.353 /
  1.476** (means 1.411 vs 1.415; view 1.572 vs 1.569 ms per frame) (`soak_ab_ms.txt`). No worse.
  Reports: `reports/qa/2026-11-23-be1d1763-quick.md`, main's `qa_quick_main_bbc45d0f_3jobs.md`.
- **Browser, real web export** (`node tools/web/controls_web.js mouse build/web`), headless
  Chromium with swiftshader WebGL, branch builds b6559e2e (Pure Fight) and 0f5da979 (3D):
  **every check PASS** (`web/mouse_branch_pf_run1.txt`, `web/mouse_branch_3d_run2.txt`).
  - Pure Fight vs AI on Verdant Falls, real clicks on the canvas: left click started 5L, right
    click 5H, middle click 5M, Q 5M, F the throw, J 5L, L 5H, and a left click held while D walks
    5L; keyboard focus stayed on the canvas after every click; `pointerLockElement` stayed null;
    the right click's `contextmenu` event was suppressed (no menu).
  - Versus AI (3D) on Ember Rift: left click started light_1, right click smash, J light_1; the
    first click took pointer lock for the mouse look, under which the browser shows no context
    menu at all (0 contextmenu events). The first three right clicks landed while the AI had Kael
    in hitstun (state 9), where no attack can start; the test now retries up to 6 times and logs
    each try's state.
- **Main's own web build 388564ab** (the first merge): the same mouse test, **every check PASS**
  (`web/mouse_main_388564ab.txt`): Pure Fight 5L / 5H / 5M / 5M / throw / 5L / 5H / 5L, no pointer
  lock, the context menu suppressed; 3D light_1, smash (buffered through hitstun), light_1, pointer
  lock on the canvas and no menu. HINT_WEB_PLACEHOLDER
- **Not tested here**: a real mouse and a real MacBook trackpad (headless Chromium sends real DOM
  mouse events, but no hardware); the trackpad tap is covered by the latch test in GUT.
