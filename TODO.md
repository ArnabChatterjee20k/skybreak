# TODO (project board)

One task = one PR. Move a task between sections as it progresses and keep its
`T-` id in the branch name and PR title. Owner tags: `[developer]` (Windows PC)
and `[desktop]` (cloud agents). See `AGENTS.md` for folder ownership.

## In progress

- T-001 [developer] Milestone 0 skeleton: Godot 4.7.2 project, combat seam
  (`FighterInput`, `CombatSim` fixed 60 Hz tick, seeded RNG, determinism
  test), keyboard/mouse bindings, debug overlay (fps, frame time), GUT, CI,
  `AGENTS.md`. Remaining: CI green on GitHub.

## In review

- T-D08 [desktop] Toon + outline + rim shaders. PR #3.

## Backlog

### Milestone 0: setup

- T-002 [developer] Graphics settings: low/med/high presets + resolution scale,
  saved to user settings.
- T-003 [developer] Export preset for a Windows .exe build (export templates in
  `D:\Tools\Godot\editor_data`).

### Milestone 1: flight and camera (goal: flying feels great)

- T-101 [developer] Free flight and ground movement in the view/controller on
  top of sim movement: ascend/descend, camera-relative move.
- T-102 [developer] Lock-on camera: both fighters on screen, over the shoulder
  with smooth shoulder switch, distance by range band, mouse orbit ±35° yaw /
  ±20° pitch that springs back, fast position lerp, slower rotation.
- T-103 [developer] Target switching (mouse wheel) and lock-on toggle (MMB/Tab).
- T-104 [developer] Dash (tap = step, hold = sustained, toward target = rush)
  and vanish step (Shift+E) feel, tuned through `MovementTuning`.
- T-105 [developer] Camera occlusion: terrain between camera and fighters
  dithers out, no snapping, no cuts during control.
- T-106 [developer] Grey-box arena: about 600 m × 600 m, soft ceiling at 250 m,
  energy-dome boundary.
- T-107 [developer] Performance check on the GTX 1650 with two fighters flying;
  record fps and frame time.

### Combat sim (desktop)

- T-D01 [desktop] Sim skeleton: fixed tick, state, seeded RNG, determinism test.
  Started in T-001 (`game/combat/combat_sim.gd`); extend from there, including
  the 6-frame input buffer, sim-side movement physics and `MovementTuning`.
- T-D02 [desktop] Meters: health with grey recoverable damage, ki, guard, burst.
- T-D03 [desktop] `MoveData` Resource + light string + cancels.
- T-D04 [desktop] Hitbox/hurtbox collision + hitstun, blockstun, hitstop,
  damage scaling, hitstun decay.
- T-D05 [desktop] Defense: block, perfect block + lockout, grab and tech,
  push-block.
- T-D06 [desktop] Vanish rules: direction guess, Sense, max 2, then Clash.
- T-D07 [desktop] Chase/tech and wall-splat.
- T-D09 [desktop] Aura and impact VFX shaders.

### Milestone 2–3 (developer side)

- T-201 [developer] Training dummy scene and combat debug view (hitboxes,
  frame data, input history) wired to sim state.
- T-301 [developer] Playtest milestone 3 depth on Windows and report feel notes.

## Done
