# AGENTS.md

How to work in this repo. Read this before changing anything. Owner-level rules
live in `docs/handoff.md`; game rules in `docs/GAME_DESIGN.md` (once merged).

## Project

Skybreak is a full-3D anime arena fighter with free flight. Personal,
non-commercial, original IP only: no characters, names, designs, attacks or
music from existing games or shows.

- Engine: **Godot 4.7.2** (Forward+), GDScript only.
- Tests: **GUT 9.7.1**, vendored in `addons/gut/`.
- Target PC: GTX 1650 4 GB laptop, 16 GB RAM. See "Performance budget".

## Folder ownership

Two teams work in parallel. Stay inside your folders; if you need a change in
someone else's, ask on the MisterMime bus first.

| Owner | Paths |
|---|---|
| `desktop` (cloud agents) | `game/combat/**`, `game/view/shaders/**`, `game/audio/music/**`, `tests/combat/**`, `tests/shaders/**`, `tests/audio/music/**`, `docs/GAME_DESIGN.md` |
| `desktop` (cloud agents) | `game/combat/**`, `game/view/shaders/**`, `tests/combat/**`, `tests/shaders/**`, `docs/GAME_DESIGN.md` |
| `desktop` (cloud agents), audio (T-D20) | `game/audio/**` (sound effects, banks, `AudioDirector`, bus layout; `game/audio/music/**` is T-D21's), `tests/audio/**` |
| `desktop` (cloud agents), characters (T-D10) | `game/characters/**` (models, materials, animation libraries, `CharacterView`), `tests/characters/**`, their entries in `docs/asset-licences.md` |
| `developer` (Windows PC) | everything else: `game/input/**` (incl. `FighterInput`), camera, flight feel, arenas, UI, `.github/`, `project.godot`, `addons/` |

`CharacterView` is a pure animation node that `FighterView` (developer's) places
under its body node: no root motion, no own position/rotation, origin at the
capsule centre, facing -Z, about 2 m tall; `apply_state(fighter, delta)` each
frame. Characters prefer glTF/GLB; adding anything under `addons/` goes through
developer.

`MovementTuning` (in `game/combat/`, when added) is the exception: `developer`
may edit its values freely to tune feel.

## Architecture: the sim seam

- `CombatSim` (`game/combat/combat_sim.gd`) is the whole game state, advanced
  by `tick(inputs: Array[FighterInput])` exactly 60 times a second
  (`CombatSim.TICKS_PER_SECOND`), from `_physics_process`.
- The sim is **pure data**: no `Node`, `Input`, scene tree, `delta` or
  wall-clock access. Durations are counted in ticks. All randomness comes from
  the sim's seeded `rng`. Same seed + same inputs = same match, guarded by the
  10k-tick determinism test.
- Flight and movement physics live in the sim too, so they are deterministic.
- `FighterInput` (`game/input/fighter_input.gd`) is the only thing the sim
  reads from the outside. Keyboard, AI, replays and a future second local
  player all produce it. It carries held/pressed/released action bitmasks,
  camera-relative `move`, `vertical`, `view_yaw`, `camera_offset` and
  `target_switch`.
- The view (scenes, camera, VFX) only **reads** sim state and interpolates
  between the last two ticks with `Engine.get_physics_interpolation_fraction()`.

## Input

Keyboard and mouse first; gamepad later through the same `FighterInput`.
Default bindings live in `game/input/input_bindings.gd` and are installed at
runtime, so everything stays rebindable. Vanish = DASH + BLOCK (Shift+E).

## Performance budget

- 1080p at a locked 60 fps; sim at 60 Hz regardless of render fps.
- Forward+. No SDFGI or volumetric fog; SSAO/SSR off or optional.
- VRAM under 3 GB: textures 2K max (1K for props), VRAM-compressed; few
  shadowed lights.
- The debug overlay (F3) shows fps and frame time; keep it working.
- Measure render cost with the benchmark, not with fps: windows started from
  an agent session are vsync-throttled to about 5 fps on the dev PC.
  ```sh
  godot --path . --fullscreen --resolution 1920x1080 --disable-vsync -s res://game/debug/render_benchmark.gd
  ```
  It prints GPU/CPU avg, p95 and max per preset, and exits 1 if medium misses
  GPU p95 < 12 ms or CPU p95 < 8 ms. **Perf-affecting PRs (VFX, characters,
  arenas, shaders, lighting) paste the benchmark output before and after.**

## Workflow

- Track work in `TODO.md` (the board). One task = one PR. Move tasks between
  sections as they progress, and tag the owner (`[desktop]` / `[developer]`).
- Always branch; never commit straight to `main`. Small focused commits, no
  force-push on pushed branches.
- PR description: Issue (link the `T-` id), Solution, Tests.
- Every change ships with tests; every bug fix with a regression test.
- Done = CI green + self-review of the diff, every open point fixed or filed in
  `TODO.md`. Merging to `main` needs the owner's OK.

## Commands

```sh
# Import (first run, or after adding assets)
godot --headless --path . --import
# Run all tests (exits non-zero on failure). Includes the scripted playtest
# (tests/playtest/): bot flights through the real arena with camera asserts.
godot --headless --path . -s res://addons/gut/gut_cmdln.gd
# Only the scripted playtest
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/playtest
# Render the scripted flights for review by eye (contact sheets, key frames,
# telemetry); write them outside the repo
godot --path . --fullscreen --resolution 1920x1080 --disable-vsync -s res://game/debug/playtest_capture.gd -- <out dir>
```

Scripted flights live in `game/debug/flight_scenarios.gd`; `FlightPlaytest`
steps the real test arena (`step_tick()` / `present_frame()`) faster than real
time and records camera metrics per frame. New movement or camera rules get a
scenario there and an assert in `tests/playtest/`.

On the Windows dev PC, `godot` is
`D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe` (self-contained mode,
editor data stays in `D:\Tools\Godot\editor_data`).

## QA

The gameplay QA harness (T-D31) plays the game like e2e tests. One command:

```sh
tools/qa/run_qa.sh --quick   # 21 AI matches (every zone x mode, all legends), ~10 min
tools/qa/run_qa.sh --full    # 252 matches (4 legends x 7 zones x 1v1/FFA-4/2v2, 3 seeds)
tools/qa/run_qa.sh --repro '<seed:zone:mode:legends:levels>' --tick T   # one violation's frames + clip
```

It writes `reports/qa/<date>-<sha>-<mode>.md` (PASS/FAIL per section, top 10
violations with frames, 2 s clips and repro commands) and `report.json` /
`metrics.json` in the run folder; exit 1 on any FAIL. Linux, needs Godot
4.7.2 (`$GODOT`), `xvfb-run`, python3 with numpy + Pillow, ffmpeg optional.

- **Invariant soak** (`game/debug/qa/`): the real `ZoneMatch` level with
  `AIDriver` (levels 2-5) on every slot, weapons and powers on, one tick per
  frame, headless (dummy renderer: animation, skeletons and camera still run).
  Sim (`QaSimChecks`, every tick): finite state, meters in range, no state
  stuck past its limit (`STUCK_SECONDS`), inside the arena box (5 cm slack),
  capsules overlapping < 10 cm (pending until T-D29 pushboxes), at most 96
  projectiles / 12 pickups / 12 gadgets, KO -> new round resets health, spawns
  and entities. View (`QaViewChecks`, every frame): lowest sole within 5 cm of
  the visible ground while standing (IDLE/BLOCKING/CHARGING; MOVING only may not
  sink), < 25% of a held weapon inside a 10 cm torso capsule, bow string > 10 cm
  from the head centre, finite bones, pops (a non-finger bone turning > 1.2 rad
  in one frame) at most 2 per fighter-minute, both locked fighters on screen in
  >= 95% of locked frames, no fighter covering > 60% of the screen.
- **Scenarios** (`tests/qa/scenarios/`): scripted-input checks, part of the
  normal GUT run. A scenario blocked by a filed bug or missing lane calls
  `known_issue(id, why)`: pending in CI, FAIL under `run_qa.sh`
  (`SKYBREAK_QA_STRICT=1`). Ids live in `QaKnownIssues.ISSUES` and `TODO.md`.
- **Golden replays** (`tests/qa/goldens/replays/`): recorded AI inputs plus a
  per-tick `state_hash`; any drift fails `tests/qa/test_golden_replays.gd` and
  names the first tick and field.
- **Visual goldens** (`tests/qa/goldens/visual/`, shots in `QaShots`): 960x540
  gl_compatibility renders compared by SSIM (>= 0.90) and 32 px tiles (fail when
  > 5% change by > 12/255), side-by-side diffs in the run folder.
- **Feel metrics**: hitstop consistency, press-to-active latency per legend and
  attack, camera jerk, foot slide, pops, sim and view ms per tick. Compared with
  the newest `reports/qa/*/metrics.json`; worse by > 15% is a regression.

Intended sim, animation, camera or art changes re-bless in the same PR, with a
line in the PR on why: `tools/qa/bless_goldens.sh --replays|--visual|--all`.
Never loosen a threshold to make a run pass; file the bug in `TODO.md` instead.

## Conventions

- GDScript style guide: tabs, `snake_case` files and functions, `PascalCase`
  `class_name`, static types everywhere.
- Name things for what they are, not how they work. No `Helper`, `Utils`,
  `Manager`, `Data`, `Info`. Don't shadow built-in class names (e.g. `Button`).
- Comments: one short plain line. Longer reasoning goes in the PR.
- Test files: `tests/<area>/test_<thing>.gd`, test names read as sentences.
- Commit the `*.gd.uid` files Godot generates; never commit `.godot/`.
- Assets: free licences that allow personal use and modification; record each
  source and licence in `docs/asset-licences.md` when adding one.
