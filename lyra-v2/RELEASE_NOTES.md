# Lyra voxel v2 look-dev renders (meant for pre-release `lookdev-lyra-v2`)

> **Not published as a release:** this session type gets HTTP 403 "Creating, editing, or deleting releases is not permitted". The exact asset set is on the orphan branch `lookdev/lyra-v2-media` under `lyra-v2/`; `publish_releases.sh` there creates both pre-releases in one go from a session that is allowed to.

Character: `lookdev/lyra-voxel` @ `2bb7ae50`, rendered with `lookdev/kit-fixes-dev` merged in locally (`--hide-stowed` and the `--energy`-coloured afterimage; the merge was not pushed), plus the capture framing fixes on `lookdev/render-fixes-lyra` (`117729ef` + ``d3b14606``).

**Renderer:** the GPU PC was off, so everything was rendered with **lavapipe** (software Vulkan, llvmpipe) on official Godot 4.7.2 linux x86_64, SHA-512 checked against `SHA512-SUMS.txt`, after a clean `rm -rf .godot` and `--import`. Colours and geometry are correct. The contact shadows look speckled because of PCSS on lavapipe, and SSAO is softer than on the GTX 1650.

**Stretch scan:** `captured 61`, `stretched kinds 0`, so no face stretches more than 3x in idle.

## Assets
| File | What |
|---|---|
| `lyra_moves_v2.mp4` | Moves reel, `full` mode, all 18 segments, **1920×1080 at 60 fps**, 57.9 s (3475 frames), x264 CRF 16 |
| `lyra_moves_v2_preview.gif` | 7.5 s of combat (jab, 3-hit combo, launcher), **1280×720 at 30 fps**. A 1080p GIF of this length is about 110 MB, so the GIF is smaller; the MP4 is the full-quality reel |
| `lyra_spin.mp4` / `lyra_idle_loop.mp4` | 6 s each, 1920×1080 at 30 fps (the capture script's clip rate) |
| `turntable_000…315.png` | 8 angles, 1920×1080 |
| `turntable_sheet.png` | All 8 angles, centre crops at full resolution, 3840×2160 |
| `closeup_head.png` | Hat, face, quill, petal and rings. Re-framed with the new `--head-*` options |
| `closeup_face.png` | Tighter face shot under the brim |
| `closeup_gauntlet.png` | Right hand and bracer |
| `compare_old_vs_new.png` | Old `lyra.tscn` next to voxel v2 at 0°, 35° and 180°, 3840×3240 |

## Capture fixes (game/lookdev only, character untouched): `lookdev/render-fixes-lyra`
1. **Head close-up.** The fixed Kael framing (Head + 0.17 m, yaw −28°, pitch −6°) showed mostly the top of the hat brim, and the raised idle arm crossed the face. New options `--head-yaw/-lift/-pitch/-height` keep the old values as defaults. For Lyra: `--head-yaw=20 --head-lift=0.15 --head-pitch=2 --head-height=0.74`.
2. **Flight dash and flight left the frame.** The follow camera moves 12% of the way to its target each frame, so at 26 m/s it trailed by about 3 m and Lyra left the frame on the right, leaving only her afterimages in shot. The camera target now leads by that lag in follow/side/close/dash.
3. **Ki volley and beam were shot from behind.** Lyra faced −Z, and the open-side camera, which is clamped to ±58°, only saw her back. The charge glow was hidden behind her body and the hat brim blocked the over-the-shoulder shot. Both are now staged side-on (facing +X) with the range camera, and the charge uses a front three-quarter close shot.
4. **The launcher threw the dummy out of frame for about 1.5 s.** The pair camera height was fixed at 2.3 m. It now widens when the gap opens; at pushbox distance it is unchanged.

## Critique, most severe first (everything stays in the reel, nothing is hidden)
1. **The hat brim clips through the dummy in close combat.** The brim is about 0.5 m in radius, much wider than the pushbox. It cuts through the dummy's head in guard, hit react and at the contact frames of the jab and front kick. On knockdown it stands on edge and **sinks into the floor**. This needs a design decision: a smaller brim, a brim that tilts or flexes away on contact, or a brim radius in the spacing. Pushbox and hurtbox changes go in a separate tuning PR, not in the art.
2. **The face is hard to read at gameplay camera height.** From any camera above eye level, including the reel's follow, pair and outro shots, the brim hides the eyes. Up close the cheeks and jaw step in visible terraces with dark seams, which reads like stubble or dirt rather than a smooth anime face. The neck is a thin, plain column.
3. **The beam charge pose doesn't hold the energy.** The arms spread wide while the charge orb floats at the chest between them, so the hands never cup it. The ki and beam cores read white; #7FC0FF shows only in the halo and the afterimages.
4. **The cape moves like a rigid board.** From the side (turntable 90°/270°, run) it is a flat slab with a stair-stepped hem. In flight it hangs straight down instead of trailing, and in the run it swings as one piece.
5. **The back view is busy and flat.** The hair is a uniform lilac curtain of vertical strands. At 180°/225° the astrolabe rings overlap the hair and head and read as clutter.
6. **The brim from the front.** It reads as a flat saucer with comb-like vertical ridges along the rim. The star dots and the bands help, but the rim needs a cleaner bevel.
7. **The ki volley is now small in frame.** The side-on range shot shows the full travel and impact, but Lyra is only about 25% of the frame height, so the shot pose is harder to judge than in the beam close-up.
8. **The comparison isn't pose-matched.** At 35° the voxel model is in a different idle phase (fist at the face) from the old model.
9. **Renderer, not character:** the PCSS contact shadows are speckled and a faint horizontal seam shows on the cyclorama. Re-check both on the GTX 1650 before judging the lighting.

**What works:** the silhouette (big hat, long cape, rings) reads instantly. The palette holds (navy, cream and brass with the sky-blue lining as the one accent). The cape's back emblem, the hat band and petal, the eyes and the rings all read at 3 m. The stretch scan is clean, and in the roughly 60 reel frames I looked at, no limb tears or broken poses showed. Walk, run, jump, hover, flight and dodge all read. The dash afterimage now uses the energy colour.

**Frames reviewed:** the turntable sheet, both close-ups and the comparison, plus reel frames 20, 150, 300, 520, 700, 860, 1000, 1060–1290 (flight and dash), 1420–1815 (volley and charge), 1850–2005 (beam fire), 2080–2620 (combat), 2700–3130 (guard and knockdown) and 3200–3460 (outro), first on the pre-fix render and then on the final render (12-frame check over every segment).
