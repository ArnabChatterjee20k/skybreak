# Zone polish (branch `fix/zone-polish`)

Four fixes from the GTX 1650 zone benchmark review, on `integration/voxel-art` plus
`lookdev/zone-bench-tools` @c91116c. The approved HIGH look is kept. Every number here is real
output from this branch: lavapipe (Mesa's software Vulkan, the real Forward+ pipeline) at
1920x1080 for the stills and 480x270 for the bench. Triangle and draw counts are exact, but
lavapipe's milliseconds mean nothing, so **the GTX 1650 ms still need a run on the owner's PC**
(command at the end).

| # | Issue | Fix |
|---|---|---|
| 1 | Frozen Peaks HIGH p95 18.0 ms, all in samples 0-15 (the shadow pass) | HIGH: foothill chunks stop casting past 120 m. MEDIUM and below: a coarse 2xT2 foothill tier that still casts, past 96 m |
| 2 | Stormfall: straight-edged pale rectangles in the sky | coarse matte ground continued 1.8 km past the ground tiles |
| 3 | Verdant Falls: foam reads as a flat white slab from above | churning foam cells, per-cell value variation and a dithered, stepped foot on the falls curtain |
| 4 | Fly-through cameras clip geometry | paths fixed in 4 zones; `FlightClearance` plus a test sweeps every zone's path |

## 1. Frozen Peaks: foothill shadows

In the opening overview, Foothills (569k triangles in 53 chunks of 0.35 m T2 steps) cast
shadows from every chunk. The sun's shadows end at 180 m, so a foothill chunk past 120 m only
adds shadow detail in the 120-180 m band.

- **HIGH** keeps the authored geometry. Each foothill chunk gets a twin that shares its mesh and
  doesn't cast. The pair shares one box (`link_far_chunks`, one switch, no gap), and the twin
  takes over at 120 m.
- **MEDIUM, LOW, WEB** (where far LOD may differ) switch each chunk pair at
  `VoxelQuality.far(120)` (96 m on MEDIUM) to a 2xT2 (0.7 m) tier that still casts. The chunk
  squares match, so each pair switches at once.

The mountains' own LOD switch (240 m, as before) is untouched, so the valley keeps the mountain
shadows the stills show.

Bench, `frozen_peaks`, 48 samples, 4 voxel Kaels. "0-15" is the opening window where the
GTX 1650 missed; "path" is the whole fly-through.

| Tier | Run | Window | Visible tris p95 | Draws p95 | Shadow tris p95 | Shadow draws p95 |
|---|---|---|---|---|---|---|
| HIGH | before | 0-15 | 1,716,608 | 325 | 1,051,518 | 161 |
| HIGH | after | 0-15 | 1,716,608 | 325 | **638,274** (-39%) | **132** |
| HIGH | before | path | 1,683,424 | 317 | 1,058,664 | 174 |
| HIGH | after | path | 1,683,424 | 317 | **739,600** (-30%) | **153** |
| MEDIUM | before | 0-15 | 1,715,556 | 325 | 1,045,762 | 160 |
| MEDIUM | after | 0-15 | **1,303,194** (-24%) | 325 | **672,516** (-36%) | 160 |
| MEDIUM | before | path | 1,683,424 | 315 | 1,058,664 | 174 |
| MEDIUM | after | path | **1,298,384** (-23%) | 315 | **726,046** (-31%) | 174 |

The opening frame (sample 0) on HIGH: shadow 933,682 -> 508,040 triangles, 160 -> 122 shadow
draws. The visible count doesn't move on HIGH: the main pass draws exactly the authored look.
Reference: Heartbloom HIGH (9.9 ms on the 1650) is 1.01M visible, 882k shadow, 316 draws.
Frozen Peaks HIGH's shadow pass is now well under Heartbloom's everywhere on the path. Its
main pass is still 1.7M at the opening, where it was before. If the 1650 run still shows
HIGH over about 14 ms, the next lever is the coarse tier on HIGH too (rejected below for its
look).

Tried and rejected on HIGH (raw logs in `bench/`):

| Far tier on HIGH | Opening visible / shadow p95 | Overview still vs before (mean diff, pixels > 24/255) |
|---|---|---|
| T3 (1.4 m), casting | 1,272,016 / 754,390 | 2.86, 3.34% |
| 2xT2 (0.7 m), casting | 1,334,590 / 743,176 | 2.29, 2.62% |
| **same mesh, no shadow (kept)** | 1,716,608 / 638,274 | **0.33, 0.13%** |

Both coarse tiers visibly block up the far foothills' snow edges and strata in the opening
overview (the owner's approved look), so HIGH keeps the authored steps. The no-shadow twin
actually cuts the shadow pass more than either coarse tier.

Stills, HIGH, 1920x1080, day (`frozen_high_before_after.jpg`: before | after | difference x4):

| Shot | Mean diff (/255) | Pixels > 8/255 | Pixels > 24/255 |
|---|---|---|---|
| opening overview (fly-through u 0.0) | 0.33 | 0.63% | 0.13% |
| fly-through u 0.6 | 0.25 | 0.41% | 0.18% |
| fly-through u 1.2 | 0.57 | 1.61% | 0.31% |
| overview_day (hero) | 0.01 | 0.03% | 0.020% |
| valley_crown_day (hero) | 0.09 | 0.32% | 0.155% |
| gameplay_day (hero) | 0.06 | 0.14% | 0.080% |

Most of what's left is falling snow, which differs from run to run, plus a faint loss of
foothill self-shadow 120-180 m out. MEDIUM (`frozen_medium_before_after.jpg`) shows the 2xT2
foothills past 96 m: coarser foothill steps and snow edges on the far slopes (opening
mean diff 3.63/255, 3.56% of pixels > 24/255; u 1.2: 2.44, 2.82%). Nothing within 96 m changes,
which is MEDIUM's contract (the zone-perf pass's MEDIUM stills differ by up to 3/255 the same way).

## 2. Stormfall: rectangles in the sky

Cause: the city's ground stops at a 1000 x 1200 m rectangle (the tiles around the zone). From
the spire climb (fly-through u 8.6-9.6) the rectangle's straight edge and the cut-off faces of
the neighbours' terrain stood against the less-fogged sky as pale, straight-edged,
semi-transparent bands. Fix: `_ground_far` continues the ground 1.8 km past the tiles on a 64 m
grid (about 10k triangles, one draw, no shadow). It starts one step inside the tiles and 1 m
lower, so no seam shows. Past the heightmap's square its heights ease down to the city's
level, so there is no clamped plateau. It uses a matte material: the street shader's wet glints
showed as bright patches in the fog on the first try. See `stormfall_sky_before_after.jpg`:
the hard horizon bands become fogged ridgelines. Street level is unchanged (buildings hide
the ring).

## 3. Verdant Falls: foam

Seen from above, the curtain's bottom 14% was pure white, ending in a straight cut at the
waterline. `vf_falls.gdshader` now:

- breaks the foot's foam into churning lighter and greyer 0.7 m cells;
- varies every cell's value by up to 12%;
- thins the last 5 m cell by cell, so the foot steps and dithers into the plunge-pool spray.

All of it stays in the voxel cells. See `verdant_foam_before_after.jpg` and
`verdant_foam_detail.jpg`.

## 4. Fly-through paths

`FlightClearance` (`game/world/voxel_zone_kit/flight_clearance.gd`) sweeps a zone's
fly-through (the same Catmull-Rom as the capture and the bench, 160 samples a segment)
against:

- every opaque triangle under the zone: terrain chunks, props and their MultiMesh copies.
  See-through `blend_*` surfaces (water, mist, rain, light shafts) are skipped. Only the LOD
  tier the renderer would draw at each camera position counts.
- the visible ground (`ground_at`), except deep under floating islands.

`tools/diag/flight_clearance.gd` prints the close spots. `tests/world/test_flight_clearance.gd`
tests the sweep on a stand-in zone (box, placed copy, mist, ground). It also sweeps every
zone's path from its current HIGH bake, which is pending without bakes (VOXEL-BAKES), like the
bake test. Found on the way: the headless renderer keeps no MultiMesh data, so `VoxelProp` now
keeps each copy's transforms as `PropKit.INSTANCE_TRANSFORMS_META`, the pattern
`CameraObstacles` already reads.

| Zone | Before (closest, what) | After (closest at a 1.5 m search) |
|---|---|---|
| heartbloom_gardens | 0.19 m into a cherry canopy (u 8.41) | 1.82 m |
| skyhold_ruins | 0.08 m into a column (u 5.2), 0.04 m into a cloud puff (u 7.9) | 2.55 m |
| stormfall_city | starts 0.54 m under the rising street (u 0), 0.02 m from the noodle-bar frame (u 2.5) | 1.66 m |
| ember_rift | 0.03 m into two basalt spires (u 6.3, u 8.0) | 1.90 m |
| frozen_peaks, shattered_mesa, verdant_falls | clear (>= 1.1 m) | unchanged |

Heartbloom's path goes through the Heart Arch's opening by design and keeps 8.5 m from the
stone. The clip in the arch frames was the cherry canopy beside it. Each path moved only the
control points near the clip (2-8 m). See `flight_paths_before_after.jpg` (before | after at
the old clip points: the before frames are inside the canopy, the column, the spires and the
neon frame).

## Verification

Official Godot 4.7.2 linux x86_64 (`Godot_v4.7.2-stable_linux.x86_64.zip`, SHA-512 `9aa00f7a...4c65`
matches `SHA512-SUMS.txt`), on this branch's last code commit (`.godot` removed):

- `godot --headless --path . --import`: exit 0.
- All 28 zone bakes rebuilt with a real renderer (lavapipe, as the kit README says), and
  `tools/voxel_zone_bake.gd -- --check` reports all 28 current. So `test_voxel_zone_bake` and
  the bake-based fly-through sweep ran for real, not pending.
- Full GUT: **1715 tests, 1709 passing, 0 failing, 10 pending/risky**, exit 0, 552 s. The
  pending ones are the existing QA-11/QA-12 known issues, two renderer-only VFX tests, a
  T-KI1-b note and the skipped live Appwrite test.
- `tools/diag/det_check.gd`: `det_check total cc2d8d8a0f6c0594`, the same as main.

## Benchmark on the GTX 1650

```sh
D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe --path . --fullscreen --resolution 1920x1080 --disable-vsync -s res://tools/bench/zone_bench.gd -- --zones=frozen_peaks --tiers=high,medium --samples=100 --verbose
```

## Open

- GTX 1650 ms for Frozen Peaks HIGH and MEDIUM (target HIGH p95 under about 14 ms). If HIGH
  still misses, use the 2xT2 tier on HIGH too (measured above; it changes the far foothills).
- MEDIUM still misses the bench's 300k-triangle / 250-draw budget in every zone (as before
  this branch; see `reports/perf/README.md`).
