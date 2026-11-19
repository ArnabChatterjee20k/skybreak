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

- T-110 [developer] Window mode: borderless fullscreen at desktop resolution by
  default; windowed = 1600x900 centred, shrunk to fit the usable screen area;
  Fullscreen toggle in the F10 menu, saved with the graphics settings.
- T-107 [developer] Render benchmark (`game/debug/render_benchmark.gd`): GPU/CPU
  frame time per preset on a scripted locked-on flight. Baseline at 1080p on
  the GTX 1650: GPU p95 1.4 / 1.6 / 1.8 ms (low/med/high). Grey-box only;
  re-run as shaders, characters and arenas land.
- T-102b [developer] Locked camera pitch limits: at most 35° down / 25° up;
  bigger height gaps pull the camera back and widen the FOV (up to +10°).

## Backlog

### Milestone 1: flight and camera (goal: flying feels great)

- T-103 [developer] Target switching (mouse wheel) and lock-on toggle (MMB/Tab).
  Input and sim sides are done (T-001, T-D01); left: camera transition when
  the target changes, and an on-screen lock-on marker.
- T-104 [developer] Dash (tap = step, hold = sustained, toward target = rush)
  and vanish step (Shift+E) feel, tuned through `MovementTuning`.
- T-105 [developer] Camera occlusion: terrain between camera and fighters
  dithers out, no snapping, no cuts during control.
- T-106 [developer] Grey-box arena: about 600 m × 600 m, soft ceiling at 250 m,
  energy-dome boundary.
- T-109 [developer] Debug overlay text clipped at the left edge. Likely cause:
  windowed 1920x1080 is clamped to the screen (1920x991 with the taskbar), so
  the window sits partly off-screen. Fullscreen renders a true 1080p.
- T-108 [developer] Graphics presets follow-up (from PR #2): try
  `SCALING_3D_MODE_FSR` instead of bilinear when resolution scale < 1.0. The
  high preset is fine on the grey-box arena (T-107: GPU p95 1.8 ms); recheck
  once real content lands.

- T-111 [developer] HUD meter bars from the T-D02 read API (`*_display()`):
  health with grey recoverable part, ki in 4 bars, guard, burst stocks.
- T-112 [developer] Round flow in the test arena: on `round_over`, reset
  positions and call `start_round()`.

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
- T-D01 [developer, from desktop] Combat sim skeleton: input buffer, movement,
  `MovementTuning`, sim-owned lock-on, PR #6.
- T-101 [developer] Flight view: facing, lean, vanish hide, PR #7.
