# Look-dev: Kael (design sheet v1)

**Goal:** Kael alone, with no fight, at the quality bar of the owner's reference: a code-built voxel model that reads as a crafted object. This is the reference from Torsten's voxel Sherman tank (see "Why the reference works" below). The owner judges each step. Nothing from this branch goes to `main` until the owner approves the look.

## Who Kael is
A young **sky-knight adventurer**: the all-rounder, brave and a little reckless. Signature weapons: Storm Blade and Arc Revolver (not part of this step). Energy colour: orange-white. Read at a glance: *goggles, scarf, big gold gauntlets, chunky boots.*

## Proportions (stylised heroic, not chibi)
- About **5.5 heads tall** (today's chunky Kael is closer to 4). The head is still large enough to read the face at gameplay distance.
- Broad shoulders, a narrow waist and a slight forward lean (an adventurer's stance).
- Hands and gauntlets about 1.4× realistic size; boots about 1.3×. They're the silhouette anchors.
- The scarf is long: at rest it reaches mid-thigh, and it trails in flight.

## Detail at three scales (the core lesson from the reference)
| Scale | Parts |
|---|---|
| **Big forms** (silhouette) | Head with a tufted hair mass; torso in a short coat; the scarf; gauntlets; boots |
| **Medium parts** | Flight goggles (two lenses, rims, a strap around the head); coat collar and lapels; gold coat trim; shoulder plates (2 layers); a belt with a buckle; a tunic hem showing below the coat; gauntlet cuffs and finger plates; boot cuffs, soles, a toe cap; scarf knot and tail |
| **Tiny details** | Rivets on the shoulder plates and gauntlets (4–6 each); stitch lines on the coat seams; goggle-lens glints; a buckle prong; boot laces or straps; scarf fringe; 2–3 hair strands breaking the silhouette; eyebrows, eyes with highlights, a small mouth; a small emblem on the coat (an original winged-sky sigil, not copied from anything) |

## Voxel spec
- **Density:** voxel size about **1/64 of body height** (~2.8 cm for a 1.8 m figure) on the body, with finer voxels (~1/128) allowed on the face, goggles and gauntlet detail. Curves (head, goggles, scarf folds) must read as curves, with blockiness as texture rather than shape.
- **Construction:** code-built (the FigureKit/voxel approach Torsten describes: blocks and math in raw code, including animation). Each part is its own voxel volume, rigged to the existing skeleton so the current animations still drive it.
- **Per-voxel colour variation:** ±3–6% value noise and a slight hue drift within a material. Darker voxels in recesses; lighter on edges and wear spots (gauntlet knuckles, boot toes, the scarf tail).

## Palette (restrained; saturation is saved for the energy colour)
| Material | Base | Notes |
|---|---|---|
| Coat | deep teal | muted, not neon; the darker band is in folds |
| Trim, gauntlets | warm brass-gold | slightly desaturated, with brighter edge voxels |
| Tunic | charcoal | near-neutral |
| Scarf | burnt orange | the one strong colour; a slight gradient toward the tail |
| Boots | orange-brown leather | darker sole |
| Hair | silver-white | with a cool shadow tone |
| Skin | warm light | soft |
| Goggle lenses | amber glass | with a specular glint |

## Lighting stack (half the quality comes from here)
1. **Ambient occlusion** that is clearly visible in crevices: under the collar, between the fingers, under the scarf, between the boots and the ground (SSAO, or baked per-voxel AO, which is cheaper and works on the web).
2. **Soft key light plus a soft contact shadow** on the ground.
3. **Bounce/fill light** from below and the side, so dark sides aren't black.
4. **Edge or bevel highlight** on voxel edges (a subtle lighter rim per voxel), so it reads as tactile.
5. **Rim light** from behind (the anime-arena bible v2), kept subtle on Kael.
6. A neutral backdrop for the turntable, like the reference: a mid-grey gradient with a ground plane.

## Deliverables for owner review (step 1)
- A **turntable**: 8 angles (every 45°) at 1920×1080, plus a 6 s rotating clip (GPU render).
- A **close-up** of the head (face, goggles, hair) and of one gauntlet.
- An **idle pose** using the existing idle animation (looping clip).
- A side-by-side: **today's Kael | new Kael**.

## Acceptance (the owner decides; these are our self-checks first)
- From 3 m, a viewer can list at least 10 distinct parts.
- No part looks like a raw primitive (box or cylinder) unless it's intentional.
- AO and contact shadow are visible in every shot.
- Colours are muted and coherent; only the scarf and energy are saturated.
- It still animates with the current rig without visible tearing between parts.

## Why the reference works (Torsten's tank)
1. **Three scales of detail:** hull → wheels and hatches → rivets and decals.
2. **High voxel density:** curves read as curves.
3. **Lighting:** strong AO in crevices, a soft contact shadow, edge highlights, so it looks tactile.
4. **A restrained palette with subtle per-voxel variation and wear.**
5. **A real reference** for proportions.
6. **Storytelling details:** stowed logs, exhaust smoke, a unit number.
