# QA goldens

Golden replays (`replays/`) and visual goldens (`visual/`) for the QA harness
(T-D31). Re-record with `tools/qa/bless_goldens.sh --replays|--visual|--all`
only in the PR that intends the change, and log it below.

## Re-bless after #87 DetMath and #89 polish batch 2 (merge of main into `claude/polish-batch-2`)

### Golden replays

Two causes, checked by playing every old golden's recorded inputs on three sims
(#86 = 5399ac1, main = b0754e5, and the merge) and comparing every hashed field
per tick (`ko_origin`, new in #89, left out so the old field set compares):

1. **#87 DetMath (ulp-level).** Main never re-blessed the replays after #87, so
   all ten already drifted on main after tick 0 (#86's sim still matches them on
   every tick). The first-drift values are the spawn facings and the first
   velocity step: at most 6 float32 ulps on positions and velocities, at most
   1.6e-10 rad on `facing_yaw`, and in `duel_lyra_vs_brann_airborne` Brann's yaw
   -pi on #86 vs +pi on main (the same angle; atan2 of a -0.0 that #87 now
   canonicalises). No rule changed.
2. **#89 close-air knockback guard (intended).** Against main, each replay first
   drifts on a hit or counter with one fighter off the floor and the pair under
   `air_knockback_separation` (1.5 m) apart: only the target's planar velocity
   changes, raised to `air_light_knockback_min_out` (3 m/s) away from the
   attacker; vertical speed is unchanged. No replay drifts first on a KO tick
   (the KO cap acts later, inside an already drifted match).

| Replay | First drift (tick) | Event that tick | Changed field | Planar knockback speed main -> merged | Fighter heights (m) / ground |
|---|---|---|---|---|---|
| combos_level5 | 185 | HIT 1->0 | f0.velocity | f0: 2.42 -> 3.06 (vy 0.63 = 0.63) | f0 1.45, f1 1.00 |
| duel_brann_vs_kael | 114 | HIT 1->0 | f0.velocity | f0: 1.60 -> 3.00 (vy 1.20 = 1.20) | f0 6.39, f1 4.39 |
| duel_kael_mirror | 336 | COUNTER 0->1 | f1.velocity | f1: 2.00 -> 3.04 (vy 0.12 = 0.12) | f0 8.82, f1 8.91 |
| duel_low_level_mirror | 116 | COUNTER 0->1 | f1.velocity | f1: 1.48 -> 3.00 (vy 0.24 = 0.24) | f0 1.00, f1 1.29 |
| duel_lyra_vs_brann_airborne | 21 | COUNTER 0->1 | f1.velocity | f1: 1.44 -> 3.00 (vy 0.43 = 0.43) | f0 11.78, f1 12.38 |
| duel_vexa_vs_lyra | 122 | HIT 0->1 | f1.velocity | f1: 1.44 -> 3.00 (vy 0.43 = 0.43) | f0 5.15, f1 5.76 |
| ffa4_all_legends | 93 | HIT 3->0 | f0.velocity | f0: 1.46 -> 3.00 (vy 0.34 = 0.34) | f0 1.45, f1 1.00, f2 1.29, f3 1.00 |
| ko_and_second_round | 166 | HIT 0->1, HIT 1->0 | f0.velocity, f1.velocity | f0: 1.45 -> 3.00 (vy -0.40 = -0.40); f1: 2.43 -> 3.00 (vy 0.57 = 0.57) | f0 1.00, f1 1.52 |
| pickups_heartbloom | 122 | HIT 0->1 | f1.velocity | f1: 1.47 -> 3.00 (vy 0.28 = 0.28) | f0 5.15, f1 6.53 |
| teams_2v2 | 127 | HIT 2->0 | f0.velocity | f0: 1.12 -> 3.00 (vy 0.99 = 0.99) | f0 6.53, f1 1.00, f2 4.76, f3 1.00 |

Heights are capsule centres the tick before; standing on the floor reads 1.00.
The planar gap between attacker and target at those hits is 0.74-1.48 m.
Nothing drifted at any other kind of tick, so every replay was re-recorded on
the merge (new AI inputs too: the merge also routes four `fighter_ai.gd` calls
through `DetMath`).

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
