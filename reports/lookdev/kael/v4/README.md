# Voxel Kael v4: look-dev notes

These previews are **lavapipe** renders (software Vulkan in a cloud session).
Use them for shape and silhouette only; judge the final look on the GTX 1650.
Each image shows v3 (e1aac81) on the left or top, and v4 on the right or bottom.

| File | What it shows |
|---|---|
| `v3_vs_v4_180.jpg`, `v3_vs_v4_135.jpg` | Turntable stills from behind (idle pose) |
| `v3_vs_v4_tail_closeup.jpg` | The tail at 180°, cropped and scaled 2× |
| `v3_vs_v4_run_dash.jpg` | Reel frames: run (frame 10), a dash afterimage (630), dash recovery (688) |
| `v3_vs_v4_flight.jpg` | Reel frame from the banking flight (475) |
| `v3_vs_v4_guard.jpg` | The dummy's string landing on Kael's crossed-forearm guard |
| `test_kael_voxel_v4_scarf.gd.txt` | Proposed regression tests for `tests/characters/` (outside this lane; they pass locally) |

## Scarf tail
- **v3:** a voxelised curve with per-row offsets. Its edges were sawtoothed, and it read as torn from behind.
- **v4:** a ribbon of flat panels that sit exactly on the voxel grid:
  - The panels are joined by soft 1:2 chamfered folds that alternate out, in, out, in.
  - It is 9 fine cells wide (9.9 cm) at a constant width. Its edges run straight down the voxel columns.
  - It narrows to 7 cells over the last 11 cm. A shallow V end carries a 3–5 cm fringe only at the tip.
  - Fold valleys are darker and crests lighter. A soft tone across each panel's width alternates panel to panel, standing in for a slight twist.
  - Skinning is by rest height, blending linearly between the scarf bones' midpoints. Each row, across its full width and depth, moves as one piece.
- **Kael's `ScarfLag`:** `hang` changed from 0.65 to 0.12 and `gravity` from 3 to 1.5, set in `kael_voxel.tscn`. At 0.65 the tail hung plumb under the horizontal body in the dash, and the side camera saw it edge-on as a thin strand. It now follows the body.
- **Why not slanted panels:** a slanted panel voxelises into one-cell terraces, and posed bones turn those terraces into a sawtooth. The kit has no per-grid transform, and adding one belongs in `voxel_kit/` (outside this lane).

## Guard contact (look-dev reel only)
While the target guards, strikes are also tested against its forearm capsules: elbow to 40% past the wrist, radius 7.5 cm. The guard is pushed straight back, repeating until the overlap clears.
- Worst strike-into-guard overlap after contact: **0.099 m** with a single push, **0.003 m** with the repeated push.

## Checks
- **Stretch scan** (`stretch_scan.gd --moves=…/kael/`): exit 0, 79 poses clean, `stretched kinds 0`.
- **Move-frame scan** (`scarf_scan.gd`, new): measures every face skinned only to Scarf1–5, frame by frame, through run, take-off, flight, dash and a whip turn. Exit 0.

  | Segment | v3 longest edge | v4 longest edge | v3 shortest edge | v4 shortest edge |
  |---|---|---|---|---|
  | run | 1.17× | 1.10× | 0.78× | 0.92× |
  | flight | 1.49× | 1.35× | 0.28× | 0.61× |
  | dash | 1.53× | 1.29× | 0.67× | 0.78× |
  | reverse | 1.30× | 1.23× | 0.35× | 0.68× |

- **Full GUT:** 1535 tests, 1529 passing, 11 risky/pending (all known pendings), 0 failing.

## Weak spots (kept visible)
1. The 1:2 fold chamfers draw thin horizontal tread lines across the ribbon. They read as fold texture, but are busier than a GPU render of a soft fold would be. Judge on the GTX 1650.
2. The crest/valley tones are subtle under lavapipe. They may need more contrast on the GPU.
3. In the side-on dash the tail is still seen edge-on as a short stub below the waist. `ScarfLag` has no wind or drag term, so the tail can't stream behind at speed. A drag term belongs in `kael_chunky/scarf_lag.gd` (outside this lane).
4. The tail root still tucks under the knot. From directly behind, the top of the knot shows above the ribbon.
