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
- `kael_travel_dash_f288-348_every6.jpg`, `kael_travel_dash_f310.jpg`
- `lyra_combo_*.jpg`, `lyra_hit_react_*.jpg` (see below)

## Tests
`tests/lookdev/test_moves_reel_staging.gd` (new; drives the reel headless through `setup()`, `combo_check()` and `dash_check()`):
- Lyra's head and brim stay out of the dummy through the combo and hit react (clearance >= 0), and the hits still land
- Kael stays inside the 10% safe area on every dash frame (120 frames)
- screen-box projection, safe-area shift, and a hat counted as part of the head
