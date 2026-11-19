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
| `desktop` (cloud agents) | `game/combat/**`, `game/view/shaders/**`, `tests/combat/**`, `tests/shaders/**`, `docs/GAME_DESIGN.md` |
| `developer` (Windows PC) | everything else: `game/input/**` (incl. `FighterInput`), camera, flight feel, arenas, UI, `.github/`, `project.godot`, `addons/` |

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
# Run all tests (exits non-zero on failure)
godot --headless --path . -s res://addons/gut/gut_cmdln.gd
```

On the Windows dev PC, `godot` is
`D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe` (self-contained mode,
editor data stays in `D:\Tools\Godot\editor_data`).

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
