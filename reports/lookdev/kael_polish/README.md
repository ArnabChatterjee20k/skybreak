# Voxel Kael polish: scarf joints

These previews are **lavapipe** renders (software Vulkan in a cloud session). Use them for shape only; judge the look on the GTX 1650.
Frames come from `moves_reel.gd … combat`: frame 44–48 of that run is the 3-hit combo's `light_2` swing, about reel frame 2200 in the full reel.

| File | What it shows |
|---|---|
| `scarf_edge_on_combo_f44-48.jpg` | The tail swinging out edge-on in `light_2`, before (top, 1500c62) and after (bottom), crop scaled 3× |
| `scarf_edge_on_swing_f100-104.jpg` | The tail whipping out sideways after the combo, before (top) and after (bottom), crop scaled 2× |
| `combo_f46_before_960.jpg`, `combo_f46_after_960.jpg` | The whole frame for context |

## What changed
- **Cause:** ScarfLag bends the Scarf1–Scarf2 joint by up to **93°** in the combo (measured). Linear blend skinning pinches the depth two rows share at a joint by cos(bend/2). On the 1:2 fold chamfers, neighbouring rows shared only **one** cell, and the 1.13 m fold sits on that joint, so the overlap fell to **0.71 cells** and the silhouette notched.
- **Fix** (`scarf_tail_sdf`): each row also covers the depth of the row below. Neighbouring rows now share the full 2-cell thickness at every fold and joint. The chamfers become 3 cells thick, and flat panels stay 2. Edges, width, fringe, fold shading, hang 0.12 and gravity 1.5 are unchanged.

## Checks
- **`scarf_scan.gd`**, extended: it now adds the 3-hit combo twice and reports the largest bend at each joint and the thinnest **edge-on joint overlap**. That overlap is the depth two rows share on the side faces, which the silhouette passes through. The scan exits 1 below 1 cell.
  - Largest bend per joint: 93°, 35°, 17°, 9° (Scarf1→2 … Scarf4→5).
  - Thinnest overlap: **0.71 → 1.43 cells** (worst at combo `light_2`).
  - Longest face edge: 1.59× (combo `light_2`; it was the same before), limit 1.6×.

  | Segment | before | after |
  |---|---|---|
  | run | 1.00 | 1.99 |
  | flight | 0.98 | 1.96 |
  | dash | 0.91 | 1.82 |
  | reverse | 0.96 | 1.92 |
  | combo light_1 | 0.92 | 1.84 |
  | combo light_2 | 0.71 | 1.43 |
  | combo light_3 | 0.97 | 1.93 |
- **`tests/characters/test_kael_voxel_scarf_joints.gd`**, new:
  - Every pair of neighbouring rows shares 2 cells at rest.
  - Bent edge-on at 100° (all joints the same way, alternating, or only the top joint), every joint keeps at least 1 cell of overlap.
  - On 1500c62 it fails: 144 single-cell junctions, and 0.64 cells at y 1.114.

## Weak spots (kept visible)
1. When the top segment swings out to about 60°, its edge-on outline is still a 1-cell staircase, because axis-aligned voxel rows are seen rotated. That is voxel aliasing, not a joint notch, and only a per-grid transform in `voxel_kit/` would remove it.
2. The fold chamfers are now 3 cells thick, so edge-on folds look a touch heavier. From behind nothing changes.
3. The fold tread lines (v4 weak spot 1) are unchanged.
4. In combo `light_2` the convex side still stretches faces to 1.59×, just under the scan's 1.6× limit, and the concave side compresses them to 0.27×. That comes from the 93° bend itself. A bend limit in `ScarfLag` (`kael_chunky/`, outside this lane) would cap it.
