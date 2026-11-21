---
name: voxel-character-lookdev
description: Design and build a game character (or prop or hero asset) in Skybreak's stylised high-res voxel art style, code-built and rigged, and take it through owner-reviewed look-dev (design sheet, turntable, close-ups, moving reel). Use whenever a new character, outfit, weapon or hero prop needs to be designed or its look improved, or when someone asks for "a character like voxel Kael". Look before function: never polish placeholder primitives into final art.
---

# Voxel character look-dev

Skybreak's art style is **stylised high-res voxel art**: anime character design (big readable eyes, spiky hair, heroic silhouettes, one saturated accent) built from small voxels in code. It's lit like a miniature: crevice AO, a soft contact shadow, bright voxel edges. The quality bar is Torsten's code-built voxel Sherman tank. The proven example is voxel Kael (`docs/lookdev/kael.md`, `game/characters/kael_voxel/`, release `lookdev-kael-v1`), which the owner signed off with "loving it".

## Why this skill exists (what went wrong before)
- We built function first and tried to shader-polish capsules and boxes into "anime 3D". Primitives can't be polished into a character. A code-built style has to suit code: deliberate blocks do, imitation sculpting doesn't.
- Adjectives ("anime, chunky, crisp") instead of a reference image meant every agent pictured something different.
- There was no design sheet, so detail stayed at one scale: big shapes and nothing smaller.
- We judged it in-game at gameplay distance with HUD and VFX, where flaws hide. It was never judged alone on a turntable.
- "Done" meant tests green and the PR merged. Agents self-certified. Nobody asked "does it look good?"
- Many parallel visual lanes, nobody owning coherence, renders on GPU-less machines, and the owner only saw the end.

## Quality rules (non-negotiable, owner's order: "quality shouldn't be compromised at all")
- Every published still is 1920×1080 or larger. Every published video (moves reel, spin, idle, zone fly-through) is **1920×1080 at 30 fps or more**, and this **overrides any lower resolution or frame rate written in a task prompt**. GIF previews may be smaller.
- Never shorten a reel, skip a segment, drop the lighting stack (AO, contact shadow, bloom) or lower voxel density to save render time. If time runs out, publish only what is finished at full quality and list exactly what is missing.
- Never publish anything you haven't looked at. Every release carries an honest ranked critique.
- Software rendering (lavapipe) is fine because it's colour-correct. Slow is acceptable; degraded is not.

## Ground rules
1. **One asset at a time.** One visual lane, one owner of coherence. Nothing reaches `main` or the in-game roster until the owner approves the look.
2. **Reference first.** Attach 1–3 reference images that set the quality bar (start with Torsten's tank and voxel Kael). No adjectives without an image.
3. **Look before function.** Don't touch the sim, the gameplay clips or the netcode. Look-dev lives in `game/lookdev/` and a new character variant folder. The old model stays untouched.
4. **Render on a real GPU** (developer's Windows PC, GTX 1650). Cloud agents render with lavapipe: use them for code only, never for judging visuals.
5. **Look at every frame you publish** before reporting, and confirm the capture process really exited (Godot can hang on exit and sit there unnoticed).
6. **Honest self-critique, ranked by severity,** in every hand-off. Broken things stay visible in the reel and get listed. Never hide them.

## Step 1: Design sheet (`docs/lookdev/<name>.md`) before any code
Copy the structure of `docs/lookdev/kael.md`:
- **Who they are:** role, personality, energy colour, and a one-line "read at a glance" (for example *goggles, scarf, big gold gauntlets, chunky boots*).
- **Proportions in heads:** about 5.5 heads, stylised heroic, not chibi. Name 2–3 oversized **silhouette anchors** (gauntlets ×1.4, boots ×1.3, scarf...).
- **Detail at three scales** (the core lesson from the tank):
  - *Big forms:* the silhouette masses.
  - *Medium parts:* plates, straps, collars, belts, cuffs, soles, knots.
  - *Tiny details:* rivets (4–6 per plate), stitch lines, glints, laces, fringe, stray hair locks, eyebrows, eye highlights, an **original** emblem, and at least 4 **storytelling details** (wear, a stowed item, a personal mark).
- **Palette table:** muted base materials with one saturated accent (Kael's is the burnt-orange scarf; energy colours are the only other saturation). Every material gets a shadow tone.
- **Voxel spec:** body cell ≤ 1/64 of the height (Kael's is 1/82 = 2.2 cm), fine cell for hands, weapon and gear detail at half that (1.1 cm), and a head cell of about 8.5 mm (Kael v2) so the face and skull read smoothly.
- **Lighting stack, deliverables and acceptance** (below).

## Step 2: Build in code (reuse Kael's pipeline)
The shared code lives in `game/characters/voxel_kit/` (read its `README.md`: API, how to add a character, rules learned on Kael). Voxel Kael (`game/characters/kael_voxel/`) is the worked example. Extend the kit; don't fork it:
- `voxel_sdf.gd`: SDF primitives (box with rounding, capsule, ellipsoid, cylinder, torus, smooth_union, hash3).
- `voxel_grid.gd`: `paint(bounds, sdf, mat, tag, mode)` with FILL, ADD, CARVE and PAINT, plus `paint_surface` for decals, stitches and emblems, plus `smooth` to clean up single-voxel noise.
- `voxel_mesher.gd`: one face per open voxel side, skinned to the skeleton. It handles per-voxel colour variation, cavity AO from a blurred occupancy field, corner AO and convex-edge flags.
- `voxel_figure.gdshader`: corner AO and a bevel highlight on voxel edges. **Keep the varyings clamped**, because MSAA extrapolation on edge-on faces made HDR fireflies that bloom turned into white blobs.
- `voxel_design.gd` (`VoxelDesign`), the base class each character extends, plus `voxel_body.gd`, which swaps the built mesh onto the rig. Kael's `kael_voxel_design.gd` is the example design: with `Mat` and `Tag` enums, a `COLORS` table, parts painted in the skeleton's rest pose, and rig tags deciding the skin weights.

How to build:
- **Rig to the existing humanoid skeleton** so the current clips drive it. Give each rigid part one tag. Give each finger its own tag so a face never blends two fingers, and keep thumbs rigid with the hand unless the clips are authored for them.
- **Design in blocks, don't voxelise curves.** Big cloth and armour surfaces should be **planar panels** with crisp fold ridges, bevelled plate edges and hard hems. An ellipsoid chopped into voxels gives noisy 1-voxel terraces ("a curved shape voxelised"). Keep curves for the head, hair locks, lenses and scarf folds, at the fine cell size.
- **Colour noise:** ±2–3% value on large panels and up to ±6% on small parts. Darker voxels in recesses and folds; lighter on edges and wear spots (knuckles, toe caps, scarf tail).
- Every part has a medium and tiny layer. A plain box or cylinder is a bug unless it's deliberate.

## Step 3: Look-dev stage and captures
Use `game/lookdev/lookdev_stage.gd`. Its lighting stack is half the quality, so keep it:
1. Clearly visible crevice AO (SSAO plus the mesher's baked AO).
2. A soft key light with a soft contact shadow.
3. Fill and bounce light so the dark sides aren't black.
4. Voxel edge highlights.
5. A subtle rim light.
6. A mid-grey endless cyclorama, with the camera clamped so the edge never shows.

Capture at exactly 1920×1080 through a SubViewport, with `game/lookdev/lookdev_capture.gd --scene=...`. Stills use the small cyclorama; a huge one makes the PCSS contact shadow speckled. Only reels set `LookdevStage.large = true`. The deliverables go to a GitHub pre-release `lookdev-<name>-v<N>`:
- an 8-angle turntable (every 45°) plus a contact sheet
- close-ups of the head and the signature part (hand, weapon)
- `old | new` and `vN-1 | vN` side-by-sides
- a 6 s spin and an idle loop (mp4)
- **a moving reel** (`<name>_moves_vN.mp4`, 45–60 s at 1080p60; `game/lookdev/moves_reel.gd --scene=... --moves=...`), with a caption per move and 3–5 s per segment:
  1. idle, walk, run (3/4 follow and a side view)
  2. jump and land, take-off, hover, flight, a flight dash, descend
  3. shooting: a ki volley that travels to the target with an impact; a beam charge and fire, **framed close enough to judge the pose**
  4. combat against a grey target dummy: jab, combo, launcher, kick, dodge, guard against a string, hit react, knockdown and get-up, with hitstop, flashes and pops
  5. an idle orbit to close

**Collision in reels:** keep fighter centres at least 2 × `FighterStats.pushbox_radius` apart, with equal pushback on overlap like the sim. Test fists, forearms and boots against the target's body capsule: the first touch lands the hit (hitstop, flash, pop), and any further overlap pushes the target back. Nothing may sink in. Stage melee side-on. Report the measured silhouette (height, width, r90 per band) against the pushbox and hurtbox values; any change to those values goes in a separate tuning PR with tests, never in the art swap.

Missing clips: author look-dev-only procedural poses with `pose_override.gd` (a SkeletonModifier3D that exists only in the look-dev scene). Label them as stand-ins; they aren't final animation.

Send drafts early: put draft stills up as soon as one frame exists, then the full set.

## Step 4: Self-check, then owner review
Self-check before handing over:
- From 3 m, a viewer can list at least 10 distinct parts.
- No raw primitives, and no speckled or mossy cloth.
- AO and the contact shadow are visible in every shot.
- The palette is muted and coherent, with only the accent and the energy saturated.
- It animates with the current rig with no tearing or stretching, and the thumbs and fingers stay sane in a fist, a guard and a shot.
- **Stretch scan:** no face is stretched more than 3× in idle or guard. This catches bad skin weights, such as a side test using abs(x) that lets one side's pass overwrite the other.
- No body clipping between fighters anywhere in the reel.
- The silhouette reads in pure black.
- It holds up next to the reference images.

The owner reviews at three gates: **draft stills, then the moving reel, then the polish pass.** Relay the owner's words verbatim to the builder. Only after approval does the asset go in-game: swap the variant in, tune for camera distance, readability, fps on the GTX 1650 and the web build, then refresh the visual goldens once on `main`.

## Hand-off message template
```
<release link>
Assets: <list with sizes/durations>. Code: <commit>.
Works: <bullets>.
Weak/broken (kept in, not hidden): 1..n ranked by severity.
Next: <v+1 plan>.
```

## Applying it to a zone
Zones follow the same loop (design sheet, then build, then a stage, then owner gates). The voxel density and lighting stack match the characters'. The deliverables are hero shots, a slow fly-through, and the character standing in the zone for scale. See `docs/lookdev/heartbloom.md` once it's written.
