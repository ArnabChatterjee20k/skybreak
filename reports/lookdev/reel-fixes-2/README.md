# Reel fixes 2: Lyra's brim in the melee, Kael's dash framing

These are lavapipe renders (llvmpipe, Godot 4.7.2 official linux x86_64) at 1920x1080 and 30 fps, downscaled. They're for checking staging and framing only; colour and light still need the GTX 1650 (skill rule 4). At 30 fps the frame numbers are half the GPU check's 60 fps ones: GPU f2286 is about f1143 here, f2974 about f1487, f3010 about f1505, and travel f620 about f310.

## 1. Lyra's hat in the 3-hit combo and hit react
**Cause.** Body contact sampled every n-th vertex (6000 per fighter). On Lyra (192k vertices) that left holes in the thin brim, and the low-poly dummy (9k vertices) has head triangles wider than the 4 cm contact gap, so the brim passed between the two point sets. Step-in also moved the attacker by the fist's gap alone, so the contact pass then had to push back after the brim was already inside the dummy.

**Fix** (`game/lookdev/moves_reel.gd` only):
- Both surfaces are sampled from every triangle (corners, plus a stratified fill of big triangles), keeping one point per 1.5 cm rest-space cell per bone. On a low-poly mesh no hole is wider than the gap.
- Step-in never goes past the bodies' touch point, measured from the posed surfaces (brim, crown, shoulders). The fist still steps in by its own gap whenever there's room.
- Head check: head, hair and hat vertices on a 6 mm grid must stay 2 cm clear of the dummy's surface along the line between them. The reel prints any frame where they don't, and the test asserts it.
- Measured head reach (brim radius from the neck, posed): Lyra **0.472 m**, Kael 0.274 m.

**Result.** The full Lyra reel printed no head contact. In the test run (combo plus hit react, headless) the head clearance is >= 0, every strike of the combo lands (3 hits or more), and the dummy's hits on her land (2 or more). Before this fix, the v3 notes measured 112-118 brim-contact frames on this staging. I didn't re-measure the old code with the new check: patching the old sampling back in for a one-off run didn't parse, and I dropped it to save time.

## 2. Kael's flight dash framing
**Cause.** The dash camera followed a target smoothed at 0.12 per tick. At 26 m/s it fell about 3 m behind, so he ran off the right edge.

**Fix.** The camera tracks the hero directly with a lead of 12% of the frame width in the dash direction, so he sits left of centre with room ahead and the afterimages trail behind him. Each frame, the hero's projected posed surface is then kept inside a 10% safe area by sliding the camera parallel to its image plane.

**Result.** Worst margin to the 10% safe area over all 120 dash frames: Kael travel reel **+0.129**, Lyra full reel +0.077 (fractions of the frame; >= 0 is inside).

## Also fixed
- The merge with Lyra v4 broke the head close-up: the hat is now on its own `Hat` bone, which `LookdevCapture.is_head_bone` didn't count. Now it does.
- Afterimages aren't baked on the headless dummy renderer, which has no skinning (this showed up as engine errors in the test).

## Grabs
Lyra's full reel: 1730 frames (3459 ticks), exit 0. Kael's travel reel: 350 frames (700 ticks), exit 0.
- `kael_travel_dash_f288-348_every6.jpg`, `kael_travel_dash_f310.jpg`: the dash. Kael stays between about 25% and 52% of the width, with room ahead and the afterimages behind.
- `lyra_combo_f1100-1220_every8.jpg`, `lyra_combo_f1143_f1148_crop.jpg` (GPU f2286): the combo. The brim stays clear of the dummy's head and the strikes land (flash at f1148). At f1143 the brim's front edge comes within a few pixels of the dummy's hair and ear on screen. It's measured >= 2 cm clear along the line between them, but it reads tight.
- `lyra_guard_hit_react_f1440-1530_every6.jpg`, `lyra_hit_react_f1482_f1488_crop.jpg` (GPU f2974 and f3010): hit react. At f1482 the dummy's spiky hair overlaps the brim edge on screen. The dummy is nearer the camera (the pair camera sits 18° off side-on), and the check measured no contact, but from this single view it can't be told apart from contact. Check it on the GPU.
- `lyra_launcher_f1180-1240_every4_camera_loses_dummy.jpg`: an issue that was already there, not fixed (see the critique).

## Ranked critique (most severe first)
1. **The launcher's pair camera loses the dummy** (f1196-1240): the "pair" camera locks its framed height at 2.3 m and its target at 0.95 m, so the launched dummy leaves through the top of the frame and Lyra drifts to the left edge. This was already in the reel (the camera code is unchanged), but it's the worst shot in it. Fix: frame both fighters' measured bounds in pair mode, like the dash.
2. **Contact is judged along the line between the fighters only.** `step_to_touch` checks overlap along that line with 4 cm lateral bins. A part that sweeps in sideways is caught, but only as a push along the line. The head check uses the same measure, so the test and the fix share an assumption. f1143 and f1482 read tight on screen.
3. **Lavapipe only.** Colour, AO and PCSS still need the GTX 1650 run. In particular, the brim-to-hair spacing at f1143 and f1482 should be looked at with GPU shadows.
4. **The dash camera is a rigid tracking shot.** At 26 m/s the backdrop whips past, and the hero creeps right as the dash slows (still inside the safe area). A small ease on the lead would read smoother.
5. **The reel is slower per tick.** The dense contact samples (1.5 cm cells) and the head check (6 mm cells) add CPU time each tick in the melee segments. Lavapipe rendering still dominates, so wall-clock time barely changed.
6. **No before-and-after on the old code with the new check.** The "before" is the v3 notes' 112-118 brim-contact frames, not a re-measurement.

## Tests
`tests/lookdev/test_moves_reel_staging.gd` (new; drives the reel headless through `setup()`, `combo_check()` and `dash_check()`):
- Lyra's head and brim stay out of the dummy through the combo and hit react (clearance >= 0), and the hits still land
- Kael stays inside the 10% safe area on every dash frame (120 frames)
- screen-box projection, safe-area shift, and a hat counted as part of the head
