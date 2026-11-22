# Issue sweep: triage of the 23 open issues

Run 2026-11-22 from 11:15 UTC, cloud container (4 cores, llvmpipe/lavapipe only). Godot official 4.7.2
linux x86_64 (`Godot_v4.7.2-stable_linux.x86_64.zip: OK` against `SHA512-SUMS.txt`,
`4.7.2.stable.official.ed1daf0bf`), fresh `origin/main` **1b790d0**, `rm -rf .godot`, `--headless --import`.
HIGH zone bakes for all 7 zones built here (`tools/voxel_zone_bake.gd -- --tier=high`); the other tiers were not
baked (only `test_voxel_zone_bake`'s VOXEL-BAKES pending note depends on them).

Fixes live on `fix/issue-sweep`. Verdicts are against main 1b790d0 unless a row says otherwise.

## Baseline on main 1b790d0

- **Full GUT** (`gut_cmdln.gd`, before all HIGH bakes existed): 1868 tests, 1857 passing, **1 failing**, 15
  risky/pending. The failure is `test_voxel_zone_camera.gd` "some zones have a tall prop on level ground"
  (10 > 10) while Skyhold's bake was still missing; with all 7 HIGH bakes the same file passes 2/2.
- **det_check**: `det_check total 65ec2f54272115fd`, equal to `reports/gameplay/det_check_746036c1.txt`.
- **Probe** (`tools/diag/issue_probe.gd`, new): all-AI `ZoneMatch` runs, classic look, headless.
- **Camera**: `game/debug/camera_qa.gd` (the #75 tool), `game/debug/camera_repro.gd` (the #134/#136 tool),
  `test_voxel_zone_camera.gd`.
- **Stills**: `tools/diag/issue_stills.gd` (new), Forward+ on lavapipe under xvfb, 1280x720, voxel zones from
  their bakes, in `reports/issues/stills/`. Looked at by eye.

## Verdicts

| # | Title (short) | Verdict | Evidence |
|---|---|---|---|
| 147 | Look-dev status | **TRACKING** | Voxel look shipped on main (PR #148, 62cd986), visual goldens re-blessed for it (46da3b2); open look-dev items are on the board (`TODO.md` LOOKDEV-*). |
| 144 | Look direction mockups | **TRACKING** | Voxel was chosen and shipped (PR #148); the art style setting defaults to voxel (`game/settings/art_style.gd`). |
| 113 | Critic scorecards | **TRACKING** | Log-only issue; nothing to fix in code. |
| 13 | E2E status | **TRACKING** | Log-only issue; the E2E regressions it filed (#92, #93) are fixed (below). |
| 75 | Camera loses the fight | **FIXED** (PR #97 T-131, PR #126 T-132, PR #149 camera round 3) | `camera_qa.gd` on main: `ffa4_frozen` 2251 frames, both on **100.0%**, blank **0**, inside geometry **0**; `1v1_stormfall` 2101 frames, both on **99.7%**, blank 0, inside 0, player height median 27.4%; `1v1_heartbloom` both on 100%, blank 0, inside 0. Voxel camera fight (`test_voxel_zone_camera`) passes on all 7 zones. |
| 134 | Camera behind the Mesa cliff | **FIXED** (9cf82cc terrain-wall push, PR #149) | `camera_repro.gd -- all` on main: mesa close shots (kael, vexa, lyra) terrain cover **0%** (was 35-40%), player 31.7% of screen height, cam-player 5.2 m. |
| 136 | Duel fighters at ~8% height | **FIXED** (PR #126 T-132 range bands, PR #149 base framing) | `camera_repro.gd` clip: player height median **32.3%** (was 7-8%; bible 15-35%), terrain cover median 0% (p90 8%). `camera_qa.gd`: median 27-30% in every config. |
| 114 | Camera inside tree canopies | **OBSOLETE** | The classic MultiMesh canopy boxes are gone; zones are voxel (PR #148). `CameraClearance` (camera inside a closed voxel prop, under the ground) reports **0** clip frames on all 7 voxel zones in `test_voxel_zone_camera` (Heartbloom included), and `camera_qa.gd` reports inside **0**. Tall voxel props as camera obstacles are filed as T-135-a. |
| 73 | Fighters interpenetrate, stand on heads | **FIXED on `fix/issue-sweep`** (52a2a0c0, 3fee3b0e, ef7e728b; residue filed as ISSUE-SWEEP-b) | Sim: pushboxes (T-D29, PR #104 QA-11) keep roots apart, probe found **0** ticks with pushboxes overlapping > 10 cm in 4 matches x 3600 ticks. Drawn bodies: VisualQa `fighter_vs_fighter` on main **473/2719** (heartbloom), **661/3429** (frozen), **451/3816** (mesa) close frames overlapping, worst **0.76-0.83 m**. `tools/diag/body_overlap.gd`: almost all are striker vs victim in hitstun (attack clips lunge the chest and head past the pushbox; Brann's core reaches 0.91 m median vs his 0.62 m pushbox). Hovering 1.4 m above a fighter 0.9 m to the side also passes the pushboxes (rounded ends) and reads as standing on the head. |
| 128 | FFA-4 spawns touching; hat close-up intro | **FIXED on `fix/issue-sweep`** (230129d7) | Every zone has exactly 2 `spawn_points` and `ZoneMatch.spawn_positions` used `side % points.size()`, so FFA-4 put two legends on each point. Probe `spawns` on main: closest fighter centres **0.92 m** apart in all 7 zones. |
| 101 | Bow string through the face | **FIXED** (PR #102/#110 T-D30e: 881e4c7, 5f296d5) | GUT `test_visual_qa` on main: `bow_vs_head` **0** violations in 398 (heartbloom), 543 (frozen), 474 (mesa) samples, worst -0.03 m (3 cm clear). The last QA quick (`reports/qa/2026-11-22-e6bf7d31-quick.md`) has no bow-string violations in its view soak. Brann's flying Ki Bow draw is filed as QA-19. |
| 93 | QA feel metrics worse (pops, foot slide) | **FIXED** (PR #95 T-D22e, PR #96, QA-21/QA-23 fixes) | Last committed QA quick (`reports/qa/2026-11-22-e6bf7d31-quick.md`, camera round 3, main minus aura v2): pops **0.036**/fighter-min (was 73.23), finger pops 0.036 (was 46.0), foot slide **0.032** cm/frame (was 1.257). |
| 92 | test_ai_spacing FFA-4 7.05 > 7.0 | **FIXED** (PR #94 T-D33, QA-15) | GUT on main: `test_ai_spacing` 7/7 passed, FFA-4 stacked **2.27%** against a tightened 3.0% limit (1v1 1.37% < 2.0%). |
| 109 | Weapon-hold CPU cost, 1-frame VisualQa diff | **STILL OPEN** | GUT on main (cloud CPU): MotionLayers 4 fighters unarmed **0.640 ms**, armed **2.642 ms**, ratio 4.13 (target armed <= 1.5 ms on the GTX 1650, can't be measured here). `tests/qa/test_visual_qa.gd` still carries `PLATFORM_TOLERANCE` 1 frame for weapon_vs_holder / bow_vs_head. Needs the Windows PC. |
| 127 | Dash afterimage = giant orange capsule | **FIXED on `fix/issue-sweep`** (b70445e0, ee4b47db) | The afterimage is still a body-sized capsule shell (`VfxCatalog` `&"afterimage"`: `VfxKit.capsule()`, additive fresnel), spawned at the previous position with no near-camera guard, so a dash toward the lens fills the frame. |
| 78 | HUD weapon slot always UNARMED | **FIXED** (PR #88 T-127: cf7b72b, then b8336ad) | `MatchHud.weapon_label()` reads `fighter.held_weapon()` (`game/ui/match_hud.gd:541`); `tests/ui/test_match_hud.gd:177-191` asserts UNARMED / STORM BLADE / ARC REVOLVER 12 / RELOAD. Lyra's "UNARMED" after 12 arrows is the design's auto-throw (polish batch 3). |
| 80 | Combo counter lingers | **FIXED** (cc54e86 in PR #88; restyle PR #143) | `game/ui/combo_counter.gd`: shows on a landed 2nd hit, holds 0.5 s after the last landed hit, fades 0.25 s, never counts down (a lower count only shows once the old one has gone). |
| 77 | Hit sparks hide the contact | **FIXED** (PR #83 bece700, PR #105 ede948d) | `tests/view/vfx/test_vfx_occlusion.gd` under xvfb + gl_compatibility on main: 3/3 passed (ordinary beats wash out <= 15% of a head/torso; the K.O. <= 30% and keeps the loser visible). `test_match_vfx.gd`: a heavy counter leaves the screen untouched (only K.O.s and guard breaks get screen effects). |
| 118 | Stripe banding on cliffs | **OBSOLETE** | The classic `world_terrain.gd` strata are not drawn in the voxel zones (PR #148). Stills: `stills/shattered_mesa_t420.jpg`, `stills/frozen_peaks_duel_t420.jpg`. No stripes. |
| 119 | Frozen Peaks blown to white | **OBSOLETE** | Voxel Frozen Peaks (c3086fd, PR #148) replaced the classic snow. `stills/frozen_peaks_duel_t420.jpg`: blue-grey snow with dark ice and rock, fighters read clearly. |
| 120 | Stormfall not a neon night city | **OBSOLETE** | Voxel Stormfall City (124e5ae) is a night city with lit windows, neon signs and rain: `stills/stormfall_city_t700.jpg`. |
| 100 | Verdant ground a flat neon plane | **OBSOLETE** | Voxel Verdant Falls (4142741) has a stepped voxel lawn with value variation, cliffs and trees: `stills/verdant_falls_t700.jpg`. |
| 106 | AI loops the same 5-hit string | **STILL OPEN** (fix ready on `fix/issue-106-ai-variety` 7ca0dd67, not merged) | `FighterAI._start_string` picks one route per level (`_ender_route()`) and goal 3 every time. Probe on main, 5 seeds x 4 matchups, 2400 ticks: **60 of 267** strings of 3+ hits repeat the previous one exactly (22.5%); e.g. heartbloom FFA-4 lv4 seed 7: `light_1-light_2-light_3-launcher` three times in a row. |

Stills note: the first zone stills were taken without drawing a frame per tick, so VFX lifetimes never advanced
and dash shells piled up; the stills committed here are from frames where that does not show. The script now
draws every tick.

## Ready-to-post closing comments

- **#147**: Closing as superseded: the voxel look shipped on main in PR #148 (visual goldens re-blessed in
  46da3b2). The open look-dev follow-ups are tracked on the board (`TODO.md`, LOOKDEV-*), and per-zone status is in
  `reports/lookdev/`.
- **#144**: Closing: voxel was the chosen direction and shipped in PR #148. It is the default art style
  (`ArtStyle.VOXEL`), with the classic look kept as a setting.
- **#113**: Closing as superseded. The critic scorecards were a run log. Later art and feel findings are filed as
  their own issues, and the pre-voxel ones are closed against the voxel art (#100, #118, #119, #120).
- **#13**: Closing as superseded. The E2E regressions this log filed are fixed (#92: FFA-4 stacking 2.27% under a
  3% limit; #93: pops 0.036/fighter-min, foot slide 0.032 cm/frame). Current status is in `reports/issues/triage.md`
  and the QA reports.
- **#75**: Fixed by PR #97 (T-131), PR #126 (T-132) and PR #149 (camera round 3). `camera_qa.gd` on main 1b790d0:
  FFA-4 Frozen Peaks both fighters on screen 100%, 0 blank frames, 0 frames inside geometry; 1v1 Stormfall 99.7%,
  0 blank, 0 inside. The voxel camera test passes on all 7 zones.
- **#134**: Fixed by the terrain-wall push (9cf82cc) in camera round 3 (PR #149). `camera_repro.gd` on main: the
  Mesa close shots now have 0% terrain in front of the action (was 35-40%), with the player at 32% of screen
  height.
- **#136**: Fixed by the range-band framing (PR #126) and round 3's base framing (PR #149). `camera_repro.gd` clip
  on main: player height median 32.3% of the screen (was 7-8%; the bible asks 15-35%).
- **#114**: Closing as obsolete: the MultiMesh canopy boxes went with the classic zones. On the voxel zones
  `CameraClearance` finds 0 frames with the lens inside solid geometry (Heartbloom included), and `camera_qa`
  finds 0 inside frames. Tall voxel props as camera obstacles are T-135-a on the board.
- **#101**: Fixed by the T-D30e bow holds (PR #102/#110). VisualQa on main: 0 bow-string-in-head frames in 1415
  samples over three zones, worst 3 cm clear. Brann's flying Ki Bow draw is tracked as QA-19.
- **#93**: Fixed. Latest QA quick (e6bf7d31): pops 0.036/fighter-min (was 73.2), finger pops 0.036 (was 46.0), foot slide
  0.032 cm/frame (was 1.257), after T-D22e foot grounding (PR #95) and the QA-21/QA-23 pop fixes.
- **#92**: Fixed in PR #94 (T-D33, QA-15). `test_ai_spacing` passes on main: FFA-4 stacked 2.27% against a
  tightened 3.0% limit.
- **#78**: Fixed in PR #88: `MatchHud.weapon_label()` reads `FighterState.held_weapon()`, and
  `tests/ui/test_match_hud.gd` covers UNARMED, melee and ranged with ammo/RELOAD.
- **#80**: Fixed in cc54e86 (PR #88): the counter holds 0.5 s after the last landed hit, fades in 0.25 s, and
  never counts down.
- **#77**: Fixed in PR #83 and PR #105: only K.O.s and guard breaks get screen-wide effects, and
  `test_vfx_occlusion` (rendered) holds ordinary beats to at most 15% of a head or torso washed out.
- **#118**: Closing as obsolete: the classic terrain strata are not drawn in the voxel zones (PR #148). See
  `reports/issues/stills/shattered_mesa_t420.jpg`.
- **#119**: Closing as obsolete: voxel Frozen Peaks replaced the classic snow; it no longer blows out (see
  `reports/issues/stills/frozen_peaks_duel_t420.jpg`).
- **#120**: Closing as obsolete: voxel Stormfall City is a rainy neon night city (see
  `reports/issues/stills/stormfall_city_t700.jpg`).
- **#100**: Closing as obsolete: voxel Verdant Falls has a detailed stepped voxel lawn (see
  `reports/issues/stills/verdant_falls_t700.jpg`).

## Fixes (branch `fix/issue-sweep`)

| # | Commits | What changed | Evidence after |
|---|---|---|---|
| 128 | 230129d7 | `ZoneMatch.side_points`: sides beyond the zone's spawn points sit evenly on a 12 m ring around the points' middle (1v1/2v2 keep the zone points). | Probe `spawns`: closest centres **16.97 m** in all 7 zones (were 0.92 m). `test_free_for_all_fighters_spawn_apart_in_every_zone`: every pair > 8 m apart, surface to surface. |
| 127 | b70445e0, ee4b47db | Dash/dodge/vanish afterimage is a `PoseGhost`: the fighter's skinned body redrawn from a frozen copy of its bone poses (GPU skinned, shared mesh), faint additive fresnel rim, gone in 0.16 s, max 3 per fighter. Sonic ring 5.5 m -> 2.8 m, 0.3 s. Trails don't start within 3.5 m (rings 5 m) of the lens; every additive energy layer fades out over 2.5-0.6 m of view depth. | Forward+ stills (Ember Rift seed 7, the issue's opening dash): a translucent silhouette instead of a capsule, ring inside the lower-left quarter: `stills/127_after_ember_t196.jpg`. Tests `test_pose_ghost.gd`, `test_no_afterimage_or_sonic_ring_starts_in_front_of_the_lens`. A CPU bake of the pose was measured at 26-51 ms per ghost and not used. |
| 73 | 52a2a0c0, 3fee3b0e, ef7e728b | `BodySeparation` (view only): each frame measures the core capsules as last drawn and eases overlapping views apart (the striker 75%); a flier stacked 0.6-2.4 m over another and closer than their pushbox radii + 0.35 m eases out across the view. The sim is untouched. | VisualQa `fighter_vs_fighter`, `tools/diag/body_overlap.gd`: Frozen Peaks seed 2 **410/1679 -> 53/1745** close frames, worst **0.76 -> 0.26 m**; Heartbloom seed 1 **70/870 -> 17/1280**, worst **0.73 -> 0.21 m**. Verdant seed 7 (Brann hovering over Lyra's head): eased to her side, `stills/73_after_verdant_t420.jpg`. Test `test_body_separation.gd` (< 5% of close frames, < 0.30 m). |
| 106 | 7ca0dd67 on `fix/issue-106-ai-variety` (reverted from this batch in 859c6bad) | Level 3+ AI never opens the same string (route + length) twice in a row. | Probe, 5 seeds x 4 matchups: back-to-back repeats of 3+ hit strings **60/267 (22.5%) -> 17/226 (7.5%)**. Not merged: it reshuffles the seeded AI fights and fails `test_a_ki_heavy_ai_duel_is_deterministic_and_uses_blasts_and_beams` on the merge (7 blasts vs > 10; main clears 10 only on seed 2026 of 2026-2035), and the golden replays would need re-recording. Board: ISSUE-SWEEP-c. |

det_check on the merge with main 599ab6aa: `det_check total 65ec2f54272115fd`, identical line for line to main
(the merged fixes don't touch the sim). With the #106 AI change it was `cdb4c7ed36eeb25b`: only the AI-driven
`ki` and `specials` duel lines differ, from t1200.

Still open: #106 (above), #109 (needs the GTX 1650 PC).
