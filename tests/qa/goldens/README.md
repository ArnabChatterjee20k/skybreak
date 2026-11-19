# QA goldens

Golden replays (`replays/`) and visual goldens (`visual/`) for the QA harness
(T-D31). Re-record with `tools/qa/bless_goldens.sh --replays|--visual|--all`
only in the PR that intends the change, and log it below.

## Re-baseline after #87 DetMath (from 525efd1)

### Golden replays

#87 replaced libm `sin`/`cos`/`atan2` in the sim and AI with `DetMath` and
canonicalised `-0.0`, so floats move by ulps. #86's AI-spacing code had four
libm calls left in `fighter_ai.gd` (a merge race that failed the determinism
lint); they now use `DetMath` too. The goldens keep only a 1-byte digest per
field, so the old values come from replaying the same inputs on 5399ac1
(before #87). Every replay's first drift is after tick 0 (hash index 1), with
the same events on both sides at that tick:

| Replay | Slot / field | Old | New | Size |
|---|---|---|---|---|
| duel_kael_mirror | f0 position.x | 0.006051136 | 0.0060511352 | 2 ulp |
| duel_kael_mirror | f0 facing_yaw | 0.0005052825994681568 | 0.000505282521700776 | 1 ulp (double) |
| duel_vexa_vs_lyra | f0 position.x | -0.006051136 | -0.0060511352 | 2 ulp |
| duel_vexa_vs_lyra | f0 facing_yaw | -0.0005052825994681568 | -0.000505282521700776 | 1 ulp (double) |
| duel_brann_vs_kael | f0 position.x | -0.006051136 | -0.0060511352 | 2 ulp |
| duel_brann_vs_kael | f0 facing_yaw | -0.0005052825994681568 | -0.000505282521700776 | 1 ulp (double) |
| duel_lyra_vs_brann_airborne | f1 facing_yaw | -3.141592653589793 | 3.141592653589793 | same angle: atan2(-0.0, -1) gave -pi, now +pi after `-0.0` canonicalisation |
| duel_low_level_mirror | f0 position.x | 0.006051136 | 0.0060511352 | 2 ulp |
| duel_low_level_mirror | f0 facing_yaw | 0.0005052825994681568 | 0.000505282521700776 | 1 ulp (double) |
| combos_level5 | f0 position.x | -0.006051136 | -0.0060511352 | 2 ulp |
| combos_level5 | f0 facing_yaw | -0.0005052825994681568 | -0.000505282521700776 | 1 ulp (double) |
| ffa4_all_legends | f3 velocity.x | 0.7763313 | 0.77633137 | 1 ulp |
| teams_2v2 | f2 velocity.x | 0.36233106 | 0.3623312 | 5 ulp |
| ko_and_second_round | f0 position.x | -0.006051136 | -0.0060511352 | 2 ulp |
| ko_and_second_round | f0 facing_yaw | -0.0005052825994681568 | -0.000505282521700776 | 1 ulp (double) |
| pickups_heartbloom | f0 position.x | -0.006051136 | -0.0060511352 | 2 ulp |
| pickups_heartbloom | f0 facing_yaw | -0.0005052825994681568 | -0.000505282521700776 | 1 ulp (double) |

All ten re-blessed. `tools/diag/det_check.gd` still ends `det_check total 2bb1c571b216b165`.

## Re-baseline after #69 pushboxes and #72 motion pass 2 (from bc9aa29)

### Golden replays

#69 added `pushback_velocity`, `pushback_ticks` and `pushback_from` to the
hashed fighter fields, so every stored hash differs from tick 0. To find the
real first drift, each replay was played on the new sim and compared field by
field on the fields the old goldens hashed. Every first drift lands on a
pushbox contact (the bodies' gap reaches 0 that tick) or on the first tick of a
hit/block pushback slide (the slide waits out hitstop, then moves the target).

| Replay | Old first-drift hash index (after tick) | Fields | Cause |
|---|---|---|---|
| duel_kael_mirror | 37 (36) | f0, f1 position, velocity | first pushbox contact 0-1 (#69) |
| duel_vexa_vs_lyra | 41 (40) | f0 position | block at tick 38, first pushback slide step (#69) |
| duel_brann_vs_kael | 36 (35) | f0, f1 position, velocity | first pushbox contact 0-1 (#69) |
| duel_lyra_vs_brann_airborne | 30 (29) | f1 position | hit pushback started at tick 21, first slide step after hitstop (#69) |
| duel_low_level_mirror | 39 (38) | f1 position | hit at tick 34, first pushback slide step (#69) |
| combos_level5 | 42 (41) | f0, f1 position, velocity | pushbox contact 0-1 (gap 0.002 m at 41, resolved at 42) (#69) |
| ffa4_all_legends | 33 (32) | f0, f2 position, velocity | first pushbox contact 0-2 (#69) |
| teams_2v2 | 35 (34) | f1, f3 position, velocity | first pushbox contact 1-3 (#69) |
| ko_and_second_round | 68 (67) | f1 position | hit pushback started at tick 57, first slide step after hitstop (#69) |
| pickups_heartbloom | 40 (39) | f1 position | block at tick 37, first pushback slide step (#69) |

### Visual goldens

Re-blessed: the eight `heartbloom_<legend>_{idle,light}` shots. Their diffs sit
only on the fighters and their shadows: the new mocap poses from #72 (Brann's
idle fails the tile threshold, 5.4%; the rest pass but have moved).

Kept: the six `zone_*` shots. They pass, and none of their diffs comes from an
intended change. `zone_skyhold_ruins` scores SSIM 0.944 / 4.2% tiles against
the golden, and the same 0.944 between two renders of this commit: its cloud
sea is not deterministic across renders (filed as QA-10 in `TODO.md`).
