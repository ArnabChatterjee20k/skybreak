# Brann voxel v3 renders (lavapipe, not a GPU render)

Character: `lookdev/brann-voxel` @ `f669350` (v3: 99fb1f3, 7385924, 6c49ceb, f669350 on top of v2's db73177).
Rendered with `origin/lookdev/render-fixes-brann` merged in locally (it contains `lookdev/kit-fixes-dev`, so `--hide-stowed` and the follow and shoulder camera fixes). The merge isn't pushed.
Official Godot 4.7.2 linux x86_64 (SHA-512 checked against SHA512-SUMS.txt), `rm -rf .godot`, fresh `--headless --import`, **lavapipe** (software Vulkan). Judge the final look on the GTX 1650.

Reel command:
```
godot --path . --disable-vsync -s res://game/lookdev/moves_reel.gd -- <out> full \
  --scene=res://game/characters/brann_voxel/brann_voxel.tscn --moves=res://game/combat/moves/brann/ \
  --stats=res://game/combat/moves/brann/brann_fighter_stats.tres --energy=#FF4A12 --hide-stowed --fps=30
```
`--fps=30` records every second sim tick, so timing matches the 60 fps v2 reel: v2 at t s and v3 at t s show the same moment.

## Assets
| File | What |
|---|---|
| `brann_moves_v3.mp4` | 1920x1080, 30 fps, 56.2 s (1686 frames), the v2 reel's segments. **The knockdown and get-up don't happen** (critique 1), so it runs 3.1 s shorter than v2 (3372 ticks vs 3559) and drifts from v2 after ~49 s |
| `turntable_000…315.png`, `turntable_sheet.png` | 8 angles at 1920x1080; the sheet is 3840x1080 |
| `closeup_head.png`, `closeup_gauntlet.png` | 1920x1080 (gauntlet = `LeftHand`, as in v2) |
| `v2_vs_v3_turntable_045.png`, `v2_vs_v3_turntable_090.png`, `v2_vs_v3_gauntlet.png` | v2 vs v3 stills |
| `reel_v2_vs_v3_<t>s.png` | v2 vs v3 reel frames at the same timestamps (walk and run 5.5–9 s, beam 32 s, 3-hit combo 36–37 s, hit react 50 s; the 50 s pair isn't the same moment, see above) |
| `speckle_proof.png` | where the per-pixel grain comes from (below) |

## Checks (on f669350)
- `stretch_scan.gd`: `captured 61`, `stretched kinds 0`, exit 0.
- `move_scan.gd --fail-on=stretch,gaps`: 55572 probes, `stretched faces 0`, wrist seams `widest gap 0.000 m, gapped moves 0`, exit 0. The same scan on v2 with the same wrist metric: widest gap **0.070 m** in **19** moves. Clipping, which `--fail-on` leaves out and which was already there: still 20 moves, as in v2.
- Full GUT: 1546 tests, 1540 passing, **0 failing**, 11 risky/pending (all pending existed before), exit 0.

## Before / after
- **Braid (owner's 0:09 note).** In v2 it was a rigid orange stick floating 8–10 cm in front of the bib, jutting out in run and walk (`reel_v2_vs_v3_6.0s`, `8.5s`, `9.0s`; `v2_vs_v3_turntable_090` shows it detached in the air). In v3 it hangs from the bottom of the beard down the bib as a three-segment chain, follows the head with lag, and swings with his sway. In the 90° turntable it lies against the body.
- **Wrist.** In v2 a light slit opened between the cuff and the fist when the hand bent (the 6 s walk frame). In v3 the cuff is deeper and a stone wrist plug fills its mouth. The scan's widest gap over every move went from 0.070 m to 0.000 m.
- **Speckle.** Design side: no more light chips on the torso's stepped chamfers, chisel dashes only on flat facets, a solid trouser seam (compare the legs in `v2_vs_v3_turntable_090`). Renderer side: the per-pixel grain is still in the lavapipe reel wherever the key's PCSS soft shadow lands, as `speckle_proof.png` shows: SSAO/SSIL off keeps it, hard shadows remove it.
- **Combo clipping (~36 s).** In v2 the dummy sinks into his back and boulder; in v3 the two stay apart (`reel_v2_vs_v3_36.5s`).
- **Beam (32 s).** v2: pale peach, pixel `#E3D3C2`. v3: energy colour with a thin hot core, pixel `#E8590B` (target `#FF4A12`; the filmic tonemap darkens and warms it a little). The ki orbs read red-orange too.

## Critique (ranked, worst first; nothing hidden)
1. **The reel lost the knockdown and get-up (regression).** The new body contact keeps the fighters' surfaces 4 cm apart. In "Hit react / knockdown" that leaves the dummy beyond the reel's 1.5 m whiff reach, so its heavy hit whiffs and Brann goes straight back to idle. Fix: let the strike fallback measure the surface gap instead of the centre distance (or step the attacker in), then re-render. I found it after the render and it didn't fit in the time left.
2. **The braid still overlaps the belly in heavy moves.** The move scan measures bead surfaces up to 3.8 cm into the rigid belly hull in knockdown, and about 2 cm in light_2, rising and launcher; the bib hides part of that. The braid also swings up to ~30° sideways with his idle chest roll and can show past the side silhouette at 135°. It reads as hanging, but it's lively.
3. **Per-pixel grain** (PCSS shadow noise) is still in the lavapipe reel in shadowed areas. I proved it lives in the renderer, not the voxels, but haven't checked it on the GTX 1650. If it shows there, fix it in the stage (TAA or a smaller `light_angular_distance`).
4. **The wrist clamp (24°) deepens some old clips** of fists into boulders or the head by 0.6–1.2 cm (light_1, push_block, smash, grab, rising). The total number of clipping moves is unchanged at 20; that's Brann's clips against the boulders, outside this lane.
5. **The bodies now stand visibly apart in combat.** Punches land through the capsule test, but with the wider spacing some hits look short of the dummy. The pushbox value (0.62) is untouched; the measured silhouette is wider than the pushbox.
6. **Unchanged from v2:** the beam charge is shot from behind, the dodge afterimage is blue, the gauntlet close-up is busy, the face reads small and boxy, and there's a horizon band in some reel shots.
