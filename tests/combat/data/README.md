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
