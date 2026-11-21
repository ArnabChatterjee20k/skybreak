# Gauntlet close-up: the whole fist in frame, off the boulders

These are lavapipe renders (llvmpipe, Godot 4.7.2 official linux x86_64) at 1920x1080, downscaled to 960x540. Use them to check framing only. Colour and light still need the GTX 1650 (skill rule 4).

## Cause
The GPU check at reel-fixes@cf1de58 found Brann's `_hand` close-up cropping the fist and putting it over the boulder. The old shot had three problems:
- It framed the hand, the fingers and the **whole forearm**, with a 14% pad and a fixed pitch -8 / yaw 0 front view. The forearm stretched the frame, so the fist ended up in a corner, at the very edge of the padding.
- It ignored the shoulder boulder and the body behind the fist.
- It measured vertices with `bake_mesh_from_current_skeleton_pose()`. That call fails on the headless dummy renderer, so nothing could test the shot.

`brann_gauntlet_before.jpg` is the old code at d3a75e4, rendered on lavapipe. Here the fist stays just inside the frame. The GPU frame cropped it, and I couldn't reproduce that crop on lavapipe.

## Fix (`game/lookdev/` only)
- **The fist is the subject.** That means every hand and finger vertex, plus the forearm within 12 cm of the wrist (the gauntlet cuff). Brann's gauntlet plates are skinned to the hand.
- **Safe area.** The camera is fitted with a 24% pad of each half-extent. The fist's projected box then sits at least 2% of the frame inside a 10% safe area on every side. It's measured again after the still settles.
- **Angle search.** Yaw runs over 0, ±15, ±30 and ±45 (wider yaws run the frame off the cyclorama's side edge), and pitch over -30 to +10. Candidates are scored in this order:
  1. The eye stays at least 15 cm from every other part of the body. This rejects a camera inside the head, which Vexa's first pass hit at yaw 75.
  2. No shoulder-piece vertex (Brann's boulders) lands inside the fist's screen box.
  3. As little of the rest of the body as possible lies behind or in front of the fist, so it reads against the backdrop.
  4. The angle nearest the front at a gentle tilt.
- **Measuring.** `LookdevFraming.skinned_points` now skins on the CPU from a pose snapshot taken on `skeleton_updated`. That snapshot has the SkeletonModifier3Ds applied. Outside that signal the skeleton reports the pose without them, which was off by up to 11 cm on Vexa's guard. Checked against the GPU bake: worst difference 0.00004 m on Kael (116k vertices) and 0 on Vexa. The head close-up uses the same path.
- `LookdevFraming.screen_box` moved over from `moves_reel.gd`, which still calls it.

## Results (capture log, lavapipe)
| Hero | Pitch / yaw | Fist points | Safe-area margin | Boulder or shoulder vertices in the fist box | Body clutter in the fist box | Eye clearance |
|---|---|---|---|---|---|---|
| Kael | -10 / 15 | 7172 | +0.020 | 0 | 0.00 | 0.69 m |
| Vexa | +10 / 45 | 642 | +0.020 | 0 | 0.03 | 0.82 m |
| Lyra | -10 / 0 | 4424 | +0.020 | 0 | 0.00 | 0.38 m |
| Brann | -10 / 0 | 15708 | +0.020 | 0 | 0.00 | 0.74 m |

`tests/lookdev/test_hand_closeup.gd` runs headless for all four heroes. Each one passes these checks:
- The fist's box is inside the 10% safe area, both when placed and after the settle frames.
- The fist fills at least 40% of the frame height.
- No shoulder-piece vertex falls inside the fist's screen box, or inside its 3D bounds.
- The eye stays outside the body.
- Yaw is within ±45.

## Grabs
- `contact_sheet_gauntlets.jpg`: Kael and Vexa on top, Lyra and Brann below.
- `<hero>_gauntlet.jpg`: each hand close-up.
- `<hero>_head.jpg`: the head close-ups from the same run, with framing unchanged.
