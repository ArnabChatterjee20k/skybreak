# QA-20: voxel Brann's held weapons (fix/brann-weapon-grip)

Lavapipe stills (1920x1080 originals, previews scaled down) of voxel Brann v3 holding every weapon
in guard and at the first active tick of light_1 / shot, on the look-dev stage:
`tools/diag/brann_grip_stills.gd`. `before_after.jpg` compares origin/integration/voxel-art.

Frames from `tools/diag/weapon_clearance_counts.gd` (VisualQa runs heartbloom_gardens/1,
frozen_peaks/2, shattered_mesa/3, 3600 ticks each, Godot 4.7.2 linux):

| legend | weapon_vs_holder before | after | weapon_vs_body before | after |
|---|---|---|---|---|
| kael | 0 | 0 | 0 | 0 |
| vexa | 0 | 0 | 6 | 6 |
| lyra | 1 | 0 | 4 | 4 |
| brann | 1126 (worst 17.2 cm) | 0 | 8 | 3 |

weapon_vs_body is QaViewChecks' weapon_in_body; every remaining frame is Ki Gauntlets (two
hands, outside the clearance solver), unchanged for Vexa and Lyra.

Causes: BrannVoxelView's fist clearance wrote the upper arm with a global pose, folding the
upper chest's breath scale into the arm (up to 9% skew), so the drawn hand sat 5-7 cm from where
the clearance solver had cleared it; and the solver tested the classic weapon shapes while
the voxel ones (longer pommels and butts) were drawn.

Seen in the stills, not fixed here: with the Scatter Cannon in guard his off hand stops at his
beard instead of the fore-grip (same before and after: his arms can't reach across his girth).
