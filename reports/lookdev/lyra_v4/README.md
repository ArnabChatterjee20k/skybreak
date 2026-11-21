# Lyra voxel v4: hat off the floor, muted lining, darker lining edge

These are lavapipe renders at 1920x1080 (llvmpipe, Godot 4.7.2 official), downscaled to 960x540. Use them to review the code only, not to judge colour (skill rule 4). The GTX 1650 check is still to do.

## Changes (from the owner's GPU review of v3)
1. **Hat on knockdown.** The hat (brim, crown, hook, charm, band, quill) is now skinned to its own `Hat` bone, a child of `Head` that `LyraHatClearance` adds at runtime. When the hat's lowest point would go under the floor, that modifier rocks the hat on the top edge of her skull, lifting the low side of the brim by the smallest tilt that keeps it 2 cm clear. It eases in: from 0.45 m above the floor it already takes half the tilt that height would need, so the hat tips over a few frames rather than popping as she lands. It runs as the skeleton's last modifier and is a pure function of the pose. The brim is unchanged (0.36 m, front up 13°, back droop 6°). Standing, the hat bone's pose is exactly its rest pose.
   - Measured lowest hat point in the game's KNOCKDOWN (stun 90): v3 **0.187 m below** the floor, v4 **0.030 m above** it. In KO_DOWN: v3 0.188 m below, v4 above (asserted by the test).
   - The tilt per frame through the knockdown and get-up: 0, 20, 40, 40, 52, 57, 63 ... 61, 44, 40, 40, 15, 1, 0 degrees. The largest step is 25° (38.6° before the ease-in), in the same frames where her whole body lands.
   - In v3 the lowest point was the crown's hook and charm, which lay along the floor behind her head, not only the brim. To clear them the hat has to tip a long way: lying on her back, it stands up behind her head like a pushed-back hood, with her face visible under the brim.
2. **Lining** `#3a6fb0` -> **`#44709f`** (HSV sat 0.67 -> 0.57, hue 211°). On lavapipe the lit lining at 45° went from a median of `#153768` (sat 0.80) to `#1f3d62` (sat 0.68). On the GTX 1650, v3 rendered at sat 0.77, so v4 should land near 0.67 there.
3. **Cape lining edge.** The stripe at 45° was the pale starline piping (`#9fcaf2`) along the facing's inner edge, plus the lining-blue hem piping. Both now use a new lining shadow tone, `LINING_SHADE` `#2a496b`. The constellation dots and lines on the lining are unchanged.

## Bake
There is no `tools/voxel_bake.gd` and no baked mesh on this branch: `VoxelBody` builds the mesh from the design when the scene loads, and caches it per process. So there was nothing to rebake and there's no stale-bake test; every render and test here builds from the current design.

## Previews
- `v4_turntable_000/045/090/180.jpg`: turntable.
- `v4_closeup_head.jpg`: head under the brim (eyes still read).
- `v4_knockdown_090.jpg`, `v4_knockdown_035.jpg`: lying on the floor at the knockdown's tick 30 (`lookdev_capture.gd ... knockdown`).
- `v3_vs_v4_knockdown_side.jpg`: on the left, v3's crown and hook lie in the floor; on the right, v4's hat is tipped up clear of it.
- `v3_vs_v4_cape_edge_45.jpg`: 1:1 crop at 45°. v3 has the pale stripe down her left side; v4 doesn't.

## Tests
`tests/characters/test_lyra_voxel.gd` (new, 9 tests):
- the Hat bone exists under Head and carries the hat
- standing, there's no tilt
- KNOCKDOWN and KO_DOWN: the lowest real hat vertex stays above the floor, checked over every frame. Both tests also check that she really lies down. With the modifier turned off, both fail at -0.185 / -0.188.
- through a knockdown and get-up the tilt never changes by more than 30° in one frame, and it ends at 0
- the brim is kept at 0.36 m / 13° / 6°
- the lining value (`#44709f`, sat 0.57 ± 0.02, hue 211°)
- the edge tone is darker than both the lining and the stole
- no pale piping on the cape's facing edge
