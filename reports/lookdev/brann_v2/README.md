# Brann voxel v2 renders (lookdev-brann-v2)

The release could not be created from the cloud render session (creating releases is blocked for that session type), so the renders live on this branch.

Rejoin the full reel losslessly (1920x1080, 60 fps, 59.3 s):

```sh
printf "file brann_moves_v2_part0.mp4\nfile brann_moves_v2_part1.mp4\n" > parts.txt
ffmpeg -f concat -i parts.txt -c copy brann_moves_v2.mp4
```

**Brann, voxel v2: look-dev renders** (pre-release; not in-game).

Character: `lookdev/brann-voxel` @ `db73177` (v2 self-review fixes on top of 67f7fcb). Rendered with `lookdev/kit-fixes-dev` merged in locally (`--hide-stowed`, afterimage in the energy colour #FF4A12) plus the capture fixes on `lookdev/render-fixes-brann` (below). Official Godot 4.7.2 linux x86_64 (SHA-512 checked), fresh `--import`, **lavapipe** (software Vulkan): the colours are right, but this isn't a GPU render. Judge the final look on the GTX 1650.

**Stretch scan:** `captured 58`, **`stretched kinds 0`** (clean: no face stretched more than 3x in idle).

### Assets
| Asset | Spec |
|---|---|
| `brann_moves_v2.mp4` | 1920x1080, **60 fps, 59.3 s (3559 frames)**, every segment: idle, walk, run, jump and land, take-off and hover, flight, flight dash, descend, ki volley, beam charge and fire, jab, 3-hit combo, heavy launcher, front kick, dodge, guard, hit react, knockdown and get-up, idle orbit |
| `brann_moves_v2_preview.gif` | 1920x1080, 30 fps, 7.5 s: 3-hit combo, then the heavy launcher, into the kick |
| `brann_spin.mp4`, `brann_idle_loop.mp4` | 1920x1080, 30 fps, 6 s each |
| `turntable_000…315.png` + `turntable_sheet.png` | 8 angles, 1920x1080 each; sheet 3840x1080 |
| `closeup_head.png`, `closeup_gauntlet.png` | 1920x1080 (gauntlet = `LeftHand`) |
| `compare_old_vs_new.png` | old smooth Brann (top) and voxel v2 (bottom) at 0°, 35° and 180°, at the same idle tick |
| `extra_voxel_weapons_*` | Extra set: the `lookdev/voxel-weapons` hook-up (VoxelArmory node, as `docs/lookdev/weapons.md` documents), held Titan Hammer and Scatter Cannon (3/4, 3/4 back, close-up) and the stowed pair on a turntable. For that set only, `stow_old_weapons = true` is set locally, because v2 turns stowing off. Not pushed. |

All main renders use `--hide-stowed`, so the old smooth weapons don't show.

### Capture fixes (pushed to `lookdev/render-fixes-brann`, look-dev scripts only, character untouched)
1. **Reel follow camera lag** cut Brann's head and fists at the top of the frame at the jump apex, and his boots at the bottom on landing. The smoothed target is now held within 0.5 m (flat) and 0.3 m (vertical) of the hero.
2. **Compare stills** shot the voxel model after the 12 s of spin and idle clips, so it sat at a different idle phase from the old one: on Brann, a fist covered his face. It now respawns first.
3. **Shoulder camera (ki volley and beam fire)** was tuned for a 0.5 m pushbox. Brann (0.62 m, boulders) filled two thirds of the frame and hid the beam. The eye now moves out, back and up with the pushbox radius, so Kael-sized heroes frame exactly as before. A new `shots` mode re-renders only those two segments with the same frame count. **Disclosure:** reel frames 1451–2046 (ki volley and beam) come from that `shots` run, spliced into the full run. The frame counts matched exactly: the next segment starts at 2047 in both runs.

### Critique (ranked, worst first; nothing hidden)
1. **Body clipping in the 3-hit combo (about 0:36–0:37) and in hit react (about 0:50).** On the third hit Brann turns his back into the dummy and the flinching dummy's head and torso pass into his back and shoulder boulder. In hit react the dummy's arm crosses into his beard and shoulder. The reel only tests fists and boots against the capsule. Brann's boulders and back are wider than the capsule the reel assumes.
2. **The braid is a rigid stick.** In flight, in the dash and in the closing idle orbit it juts straight out sideways, clear of the body, and reads as a detached rod rather than hanging hair. On the turntable it floats off the chest at 90° and 270°.
3. **Beam charge is shot from behind.** The beam fires toward the back wall and the camera may not swing past ±58° (the cyclorama edge), so the charge pose and orb are hidden behind his back. Fixing it means restaging the segment (hero facing the open side), which is a reel design change, not done here.
4. **Energy reads pale.** Ki balls and the beam core bloom to peach-white. #FF4A12 shows only on the rims, the floor glow and the body cracks.
5. **Dodge afterimage is blue/cyan**, not the energy colour (the `--energy` afterimage covers the flight dash only).
6. **Gauntlet close-up is busy.** At the default hand yaw the anvil fist shows its side as a jumble of plates and finger slabs. The knuckle face and the emblem don't read. Try `--hand-yaw` around -35, or calmer finger plates.
7. **Face and silhouette.** The head is small and boxy between two huge boulders. In the 3/4 head close-up the right boulder covers the side of his face, and the mouth is a 1-voxel line hidden in the beard. Big shapes read well; the face carries little expression.
8. **Stage.** A soft horizon band shows across the backdrop in some reel shots (top-left in walk and run). The reel's large cyclorama makes the PCSS contact shadow speckled; that's a known lavapipe and large-stage artifact.
9. **Take-off and flight dash framing.** He drifts toward the top-left of the frame during the climb and the dash, but he's never cut off.
10. Extra weapons set: the stowed hammer head and the cannon sit right against the right shoulder boulder at 90°. They may touch it in motion; it hasn't been checked in a reel.

**Works:** a strong, readable silhouette (boulder shoulders, anvil fists, beard and braid, apron), clean planar torso plates with ember cracks, crisp AO and edge highlights, a clean stretch scan, and readable punches with hit flashes and hitstop. Since the camera fix, the jump stays in frame. The beam now visibly connects with the dummy, and the held voxel hammer and cannon fit his scale.
