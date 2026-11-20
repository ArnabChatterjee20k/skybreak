# Combat test data

## `flat_floor_golden.json`

Per-tick fighter fingerprints (position, velocity, state) of two seeded
flat-floor matches, checked by `tests/combat/test_flat_floor_equivalence.gd`.
Recorded with `tests/combat/record_flat_floor_golden.gd`:

```sh
godot --headless --path . -s res://tests/combat/record_flat_floor_golden.gd
```

Re-bless only when a change is *meant* to move fighters on the flat floor, and
log it here.

### History

- **#68 (T-D13 fix)**: first recorded, from f1d2dba (before the terrain hook).
- **#69 (T-D29 pushboxes)**: re-blessed on the merge of `main` into
  `claude/T-D29-pushboxes`. Fighters now have solid capsule bodies, so both
  sequences diverge the first time two bodies touch:
  - `free_for_all` (seed 10, 4 fighters): first differs at index 29 (sim tick
    30). Fighter 1 steps into an attack while fighter 2 walks in; the
    pushboxes meet (gap 0.13 m -> 0) and stop both instead of letting them
    overlap.
  - `bot_match` (seed 4, Skyhold Ruins): first differs at index 34 (sim tick
    35). Fighter 0 drops its block into an attack while fighter 1 is already
    attacking; the stepping attacks stop at body contact (gap 0.04 m -> 0).
  Before those ticks the new sequences are identical to #68's, so the flat
  floor itself still behaves as before T-D13.
- **T-D32 (cross-platform determinism)**: re-blessed on Linux after the
  deterministic path stopped calling libm. On Windows (main 4089277) the old
  goldens diverged at FFA tick 10 (index 9): fighter 1, blocking while locked
  on, had `velocity.z` -1.7677666 on Linux and -1.7677667 on Windows (1
  float32 ulp). Its drift direction comes from `_wish_direction()`:
  `atan2()` (libm, double) and `Basis(Vector3.UP, yaw)` (libm `sinf`/`cosf`
  inside the engine), which round differently in glibc and the Windows CRT.
  The same path gave the other one-tick blips (FFA 14, 25; bot 186) and the
  drift from FFA tick 71 once a difference fed back into positions. They were
  real last-bit differences, not signed zeros.
  Now every sin, cos, atan2 and rotation in `game/combat/**` and `game/ai/**`
  goes through `DetMath` (`game/combat/det_math.gd`: fdlibm kernels on + - * /
  and sqrt only), and the sim turns -0.0 into +0.0 at the end of every tick.
  Both sequences differ from #69's from index 0, because the spawn ring and
  every facing now round through `DetMath` (1 ulp moves; no rule changed).
  `tools/diag/det_check.gd` prints a hash chain over the full state of both
  sequences; it must print the same lines on Linux, Windows and the web build
  (`tools/web/det_check_web.sh`).
- **#89 (polish batch 2) on the merge of `main` (b0754e5)**: re-blessed. Both
  sequences match main's goldens up to the first close air hit, then diverge
  from the air-knockback guard (intended): only the target's planar velocity
  changes, raised to 3 m/s away from the attacker (`air_light_knockback_min_out`).
  - `free_for_all`: first differs at index 304 (sim tick 305). Fighter 3 hits
    fighter 2, both in the air (y 5.24 and 4.54) about 1 m apart; fighter 2's
    knockback goes from (1.94, 0, 0.50) to (2.91, 0, 0.72).
  - `bot_match`: first differs at index 199 (sim tick 200). Fighter 1 hits
    fighter 0, both attacking in the air (y 6.84 and 8.63) 0.14 m apart;
    fighter 0's knockback goes from (-0.47, 1.41, -1.33) to (-1.01, 1.41, -2.83).
  `tools/diag/det_check.gd` total on Linux changes from `2bb1c571b216b165` to
  `7f2c2af91b6d870f`.
- **Polish batch 3 (media-2 #5)**: `bot_match` re-blessed; `free_for_all` (4 fighters)
  unchanged. A 1v1's sky drops now land 8-16 m from the fighters' midpoint instead of
  25-60 m (`PickupTuning.duel_spawn_distance_*`, same rng calls).
  - `bot_match`: first differs at index 241 (sim tick 242). The first drop spawns at
    tick 121 closer in, leaves its telegraph at tick 241, and the bots turn toward it.
  `tools/diag/det_check.gd` total on Linux changes from `7f2c2af91b6d870f` to
  `715c1e5b39ad708c`.

- **T-DEF2 (dodge)**: re-blessed. A tapped Shift is now a dodge (directional 4.5 m
  eased over 14 frames, 26 frames total) instead of the 8 m / 10-tick step.
  - `free_for_all` (seed 10): first differs at index 53 (sim tick 54), the tick
    fighter 2 taps Shift with a direction: a `DODGE` (DIRECTIONAL) event, where
    before it started the old step. Identical before that tick.
  - `bot_match`: unchanged (the AI only rushes, never taps a non-rush Shift).
