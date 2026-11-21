# Lyra voxel v3: brim and lining (from the owner's GPU review of v2)

Lavapipe renders: code review only, not for judging colour (skill rule 4). Left = v2, right = v3.

## Changes
- **Hat brim:** radius 0.46 m -> **0.36 m**, with a wave measured from the crown's edge: the front lifts 13°, the back droops 6°, and the sides sit about level. It is still built from fine-cell planar tiers (the slope makes 1-voxel steps). The turned-up rim, stitch ring, crease, 7 star lights, band, buckle, quill, petal and charm are unchanged.
- **Cape lining:** `#1e7fd8` -> **`#3a6fb0`** (HSV saturation 0.86 -> 0.67, about 22% lower). The constellation dots and lines, and the hem piping, keep their colours.
- No other changes: the navy coat and hat values, the cream stole, the planar pleated cape, the emblem and the cerulean hat band are as in v2.

## Previews
- `v2_vs_v3_high34_bust_20deg.jpg`, `..._30deg.jpg`: 3/4 view, camera 20° / 30° above eye level. In v2 the brim hides her whole face; in v3 her eyes read.
- `v2_vs_v3_high34_full.jpg`: full figure, high 3/4 view.
- `v2_vs_v3_back34_full.jpg`: back 3/4 view, showing the back droop.
- `v2_vs_v3_lining_crop.jpg`: 1:1 crop of the lining.
- `v3_reel_brim_still_intersects_dummy.jpg`: reel frames 2286, 2974, 2809 and 3010, where the brim still meets the dummy (see below).

## Scans (Godot 4.7.2 official, fresh import)
- `stretch_scan.gd`: `stretched kinds 0`, exit 0.
- `move_frame_scan.gd`: exit 1. This was already failing in v2 with identical numbers: cape-in-leg on `push_block` (0.040 m, RightLowerLeg) and on `sweep` (0.028 m, LeftUpperLeg). Every other segment passes, and no face is stretched.
- Brim vs dummy (a scratch probe over the whole reel, using the kit-fixes-dev reel locally). It tests brim sample points against bone capsules fitted to the dummy's own vertices, and the dummy's skinned vertices against the brim slab:

| Segment | v2 frames | v3 frames | v2 worst | v3 worst |
|---|---|---|---|---|
| Jab | 32 | 19 | 0.079 | 0.000 (vertex touches only) |
| 3-hit combo | 51 | 37 | 0.162 | 0.109 |
| Heavy / launcher | 13 | 9 | 0.155 | 0.110 |
| Front kick | 20 | 16 | 0.150 | 0.042 |
| Guard | 25 | 16 | 0.084 | 0.083 |
| Hit react / knockdown | 35 | 25 | 0.189 | 0.219 |
| **Total** | **176** | **122** | | |

**Not fixed: the brim still meets the dummy.** The remaining hits come from how the reel stages the fight, not from the brim's size. Fighter centres are 1.0 m apart, but in strikes and flinches the two heads come within 0.41-0.8 m. The dummy's spiky hair reaches about 0.3 m from its head, and its jabs into her guard stop 0.31 m from her head axis. A parameter sweep showed that no brim inside the owner's 0.34-0.38 m range clears it:

| Brim | Frames |
|---|---|
| 0.34 m, 15° lift | 112 |
| 0.32 m front / 0.38 m back | 103 |
| 0.36 m, 22° lift | 118 |
| 0.30 m front / 0.38 m back | 87 |

The fix belongs in the reel staging (`game/lookdev/moves_reel.gd`, outside this lane): push the pair apart on head-to-head distance, including the hat, as well as on pushboxes. The same applies to strikes against the hat. On knockdown, the brim also goes 0.19 m into the floor (0.29 m in v2).
