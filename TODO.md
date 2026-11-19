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

- T-D01 [developer, from desktop] Sim skeleton: 6-frame input buffer, sim-side
  movement (ground, flight, falling, dash step/sustained/rush, vanish step),
  `MovementTuning`, `FighterState` state machine, sim-owned lock-on (toggle,
  target switch, 1v1 starts mutually locked), determinism test over all of it.

## Backlog

### Milestone 1: flight and camera (goal: flying feels great)

- T-101 [developer] Free flight and ground movement in the view/controller on
  top of sim movement: ascend/descend, camera-relative move.
- T-103 [developer] Target switching (mouse wheel) and lock-on toggle (MMB/Tab).
  Input and sim sides are done (T-001, T-D01); left: camera transition when
  the target changes, and an on-screen lock-on marker.
- T-104 [developer] Dash (tap = step, hold = sustained, toward target = rush)
  and vanish step (Shift+E) feel, tuned through `MovementTuning`.
- T-105 [developer] Camera occlusion: terrain between camera and fighters
  dithers out, no snapping, no cuts during control.
- T-106 [developer] Grey-box arena: about 600 m × 600 m, soft ceiling at 250 m,
  energy-dome boundary.
- T-107 [developer] Performance check on the GTX 1650 with two fighters flying;
  record fps and frame time. Includes outline-pass cost and the noisy ground
  shadow edges seen in the PR #3 check.
- T-109 [developer] Debug overlay text is clipped at the left edge in a
  1280x720 movie-writer capture; check anchoring at other window sizes.
- T-108 [developer] Graphics presets follow-up (from PR #2): try
  `SCALING_3D_MODE_FSR` instead of bilinear when resolution scale < 1.0, and
  lower the high preset (4096 shadows, MSAA 4x) if it misses 60 fps in T-107.

### Combat sim (desktop)

- T-D02 [desktop] Meters: health with grey recoverable damage, ki, guard, burst.
- T-D03 [desktop] `MoveData` Resource + light string + cancels.
- T-D04 [desktop] Hitbox/hurtbox collision + hitstun, blockstun, hitstop,
  damage scaling, hitstun decay.
- T-D05 [desktop] Defense: block, perfect block + lockout, grab and tech,
  push-block.
- T-D06 [desktop] Vanish rules: direction guess, Sense, max 2, then Clash.
- T-D07 [desktop] Chase/tech and wall-splat.
- T-D08b [desktop] Outline on hard-edged props: bake smoothed normals into
  vertex colour/UV2, or use bevelled prop meshes (box outline nearly invisible
  in the PR #3 check).
- T-D09 [desktop] Aura and impact VFX shaders. Make `rim_energy_*` per fighter
  (instance uniforms or a duplicated material).

### Milestone 2–3 (developer side)

- T-201 [developer] Training dummy scene and combat debug view (hitboxes,
  frame data, input history) wired to sim state.
- T-301 [developer] Playtest milestone 3 depth on Windows and report feel notes.

## Done

- T-D00 [desktop] Game design document (`docs/GAME_DESIGN.md`), PR #1.
- T-002 [developer] Graphics presets + resolution scale + vsync, F10 menu, PR #2.
- T-003 [developer] Windows export preset (single exe), PR #4.
- T-D08 [desktop] Toon + outline + rim shaders, PR #3.
- T-102 [developer] Fight camera: free orbit + lock-on framing, PR #5.
