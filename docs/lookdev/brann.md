# Look-dev: Brann (design sheet v1)

**Goal:** Brann alone, in the approved voxel style (`docs/lookdev/kael.md`, `.claude/skills/voxel-character-lookdev/SKILL.md`), at the voxel Kael quality bar. Look before function: nothing from this sheet reaches `main` or the in-game roster until the owner approves the look.

## Who Brann is
A **stone-forged blacksmith** and the roster's heavy grappler: a gentle giant, slow to speak, proud of his craft, terrifying when he commits. Huge damage, armoured heavies and command grabs; slowest flight. Unique mechanic: **Unstoppable** (level-3 charged smash has full armour). Signature weapons: Titan Hammer + Scatter Cannon. Energy colour: **molten ember**, red-orange with a yellow core, glowing from the cracks in his stone body (*Titan* is red-bronze).

Read at a glance: *mossy boulder shoulders, anvil fists, a braided ember-red beard, a leather apron.*

## Proportions (huge and stout, not chibi)
- **6 heads** at 2.05 m (head 0.34 m, Kael's size): the body is enormous, so the head reads small and sunk between the boulders, with almost no neck.
- Shoulders 1.15 m across the boulders (2.3× Kael). Barrel chest, belly over the belt. Long arms: knuckles hang at the knee. Short, thick legs (40% of height). Wide planted stance.

**Silhouette anchors:**
| Anchor | Size | Reads as |
|---|---|---|
| Boulder pauldrons | each 0.40 × 0.32 × 0.44 m, faceted, moss on top, rising above the ear line | a flat-topped block: the head sits in a notch between two rocks |
| Anvil fists | each 0.30 m (about his head size, ×1.8 realistic) with flat forged faces | two blocks hanging at knee height |
| Braided beard | full beard to the belly, one thick braid to the belt ending in an iron ring | a hanging weight at the centre line, breaking the chest block |

**Silhouette contrast (pure black, gameplay distance):**
- vs **Kael**: both have big hands, but Kael's are gauntlets on a narrow-waisted, 5.5-head figure; Brann's fists hang at the knee of a body twice as wide, with a flat top and no trailing scarf.
- vs **Vexa**: Vexa is tall, thin and spiky on top; Brann is a wide rectangle on short stumps with round tops.
- vs **Lyra**: Lyra is widest at the hat and the hem; Brann is widest at the shoulders, with nothing above the head.

## Detail at three scales
| Scale | Parts |
|---|---|
| **Big forms** (silhouette) | Head with a heavy brow and beard; barrel stone torso; boulder pauldrons; thick forearms and anvil fists; knee-length leather apron; short legs in rolled trousers; iron-shod boots |
| **Medium parts** | Heavy brow ridge; deep-set glowing eyes; moustache; small ears; beard braid with 3 iron rings and a heavy end ring; apron bib, side straps crossing in an X on the back, two front pockets; wide belt with an anvil-shaped iron buckle; 3 iron bands per forearm; forged knuckle plates (flat faces, bevelled edges); moss caps and lichen patches on the boulders; glowing crack seams across chest, forearms and one cheek; rolled trouser cuffs; boot iron toe caps and thick soles |
| **Tiny details** | Hobnails (6 visible per sole edge); 5 rivets per forearm band; hammer-peened dimples on the knuckle plates (1-fine-voxel dents); stitch lines on the apron hem and straps; scorch marks and 2–3 burn holes in the apron; moss tufts (1–2 voxels) and lichen dots; beard strands breaking the outline; eye glints; chisel marks on the boulder facets; the **emblem** |

**Emblem (original): the Hearth-Mark.** An anvil seen side-on with a flame of three stacked chevrons rising from its face, struck inside a square frame with notched corners. Stamped into the belt buckle and branded (darker leather) on the apron bib.

**Storytelling details:**
1. A tiny white flower growing in the moss on the left boulder: he moves carefully around it.
2. Tongs and a rasp stowed in the apron's front pockets.
3. A patched square on the apron in mismatched, lighter leather, with big stitches.
4. One forearm band is newer: brighter, unpatinated iron.
5. A small heart-shaped iron ring he forged, threaded on the beard braid above the end ring.

## Palette (muted base; ember-red is the one saturated accent)
| Material | Base | Shadow | Notes |
|---|---|---|---|
| Stone skin and torso | warm granite grey `#6E6A6C` | `#45414A` | cool shadow; lighter chips on edges |
| Boulders | basalt grey `#57545A` | `#343239` | darker than his body so the pauldrons separate |
| Moss | muted olive moss `#5E7A42` | `#3A4E2A` | darker and more olive than Heartbloom's lawn so he never melts into the grass |
| Apron, straps | oxblood-brown leather `#4A2C1E` | `#2C1A12` | patch `#6A4630`; brand mark `#2A170F` |
| Trousers | slate blue-grey cloth `#343A4C` | `#1F2330` | |
| Iron (bands, buckle, plates, toe caps) | blackened iron `#35353B` | `#1E1E22` | edge wear `#6A6A72`; the new band `#7A7A82` |
| Eyes | energy core | | dark pupil block in front |
| **Accent:** beard | ember red `#C2361C` | `#7E2010` | the one strong colour; braid rings break it into segments |
| **Energy:** crack seams, eyes, ki | molten core `#FFD9A0`, glow `#FF4A12` | glow falls off to `#9A2008` | lives in lines and seams, never as an even surface |

**Roster palette note (same in all four sheets).** Each legend owns one hue quadrant for accent and energy, and a different base value, so the four don't clash or blur:

| Legend | Accent (hue) | Energy | Base value |
|---|---|---|---|
| Brann | ember-red beard (~8°) | molten red-orange cracks, yellow core | mid-light stone grey |
| Kael | burnt-orange scarf (~22°) | orange-white, reads white | mid teal |
| Lyra | cerulean cape lining (~210°) | blue-white starlight | dark navy, light parchment |
| Vexa | electric violet (~270°) | violet-white | near-black, light silver jacket |

Brann and Kael are the two warm legends. They stay apart by value (Brann's red is dark and lives in the beard, Kael's orange is bright and lives in a ribbon), by base (grey stone vs teal), and by energy shape (crack lines vs a white aura). In team modes the rim energy becomes the team colour; the accents keep identity.

## Voxel spec
- **Body cell 2.2 cm** (1/93 of 2.05 m), the same cell as Kael so the voxels match side by side. His bulk means many more voxels: build the boulders and fists as their own grids.
- **Head cell about 8.5 mm** (Kael v2) for the face, brow and beard, so they read smoothly.
- **Fine cell 1.1 cm** on the braid, the fists and knuckle plates, and the buckle.
- **Colour noise:** ±3% value on stone and apron panels, up to ±6% on moss, iron and leather straps. Darker in cracks, the apron folds and under the boulders; lighter on wear (knuckle faces, toe caps, boulder edges, the apron's lap).

## Lighting stack
Kael's stack unchanged. Brann notes:
- Strong AO **under the boulders and the beard** is what sells his mass; check it in every turntable angle.
- Crack emission is driven by the existing pulse in `brann_view.gd` (`ember_energy`); clamp it so bloom stays a thin line glow, not white blobs.
- Rim at the Kael level; his stone is mid-grey, so he rarely needs more.

## Deliverables (to `lookdev-brann-v1`)
- 8-angle turntable at 1920×1080 plus a contact sheet; a 6 s spin; an idle loop with the crack pulse.
- Close-ups: head (brow, eyes, beard, braid rings) and one anvil fist; the boulder with the flower.
- `old | new` side-by-side (today's `brann.tscn` | voxel Brann).
- The roster **silhouette lineup** (all four in pure black at gameplay distance, idle, flight, guard).
- Moving reel `brann_moves_v1.mp4` per the skill, including a command-grab stand-in and a level-3 charged smash with the crack flare.

## Acceptance (self-check first; the owner decides)
- From 3 m a viewer lists at least 10 parts.
- No raw primitives: the boulders are faceted rock, not ellipsoids; the fists read as forged.
- AO and contact shadow visible in every shot.
- Muted and coherent: only the beard and the energy are saturated.
- Animates on the current rig: boulders don't cut the head or the arms on a raise; the fists open for grabs without tearing; the apron doesn't tear at the thighs in a stomp.
- In the silhouette lineup a viewer names him in each pose.

## Build notes (for the coder)
| Part | Build | Rig tag / skinning |
|---|---|---|
| Torso | chiselled planar facets (convex polytope SDF from 6–8 planes per section), not a smooth barrel | `TORSO` |
| Crack seams | carved 1-voxel grooves, filled with an emissive `GLOW` material | inherit the tag of the part they cut |
| Boulder pauldrons | each a convex polytope of 5–7 intersecting planes (deliberate facets, no terracing), moss as an `ADD` layer 1–2 voxels thick with noise, lichen by `paint_surface` | new `BOULDER_L/R`: rigid to Left/RightShoulder; check head clearance on a shrug and arm clearance on a raise |
| Apron | one planar slab with a slight bend at the belly, stitched hem, pockets as proud panels | `SKIRT` pattern: Hips → UpperLeg by `x`, but stiff leather (leg weight ≤ 0.3) |
| Forearm bands, knuckle plates, buckle | planar plates with bevelled edges and rivets | `ARM_L/R`; plates on the proximal finger tags |
| Fists | fine-cell hand grids; per-finger tags (`FINGER_BASE` scheme) so the hand opens for grabs; thumbs rigid with the hand | `GAUNT_L/R`, fingers, `THUMB_L/R` |
| Head, brow | fine-cell curve; brow as a planar ledge | `HEAD` |
| Beard | fine-cell curve mass | `HEAD`, the lower half blending to Neck |
| Braid | a chain of fine-cell ellipsoid beads with 3 iron rings and the end ring | new `BRAID`: a chain on `Scarf1`–`Scarf3` (driven by `scarf_lag.gd`), rooted at Head |
| Trousers, boots | profile slices; planar soles and toe caps with hobnails | `LEG_L/R` |

The hammer and cannon are pickup weapons built by the weapon layer; they show on his idle pose only.

## v2 self-review (lavapipe; values and colour still need the GPU)
Ranked, worst first. Stills: `reports/lookdev/brann/voxel_v1_lavapipe_*.png` and `voxel_v2_lavapipe_*.png`.

| # | Problem in v1 | v2 |
|---|---|---|
| 1 | Old smooth hammer and cannon stowed on him dominated every angle | Hidden: `BrannVoxelView.stow_old_weapons` (off) skips stowing; voxel weapons are their own lane |
| 2 | Braid sank into the belly in every move (spring follows the head; 18 cm deep) and was invisible at rest | `_keep_braid_clear` turns it in front of the bib each frame; braid moved forward, root up in the beard. Still swings off the body in profile: a GPU-reel call |
| 3 | Boulders cut into the head on a chin tuck (10 cm in guard) | Re-cut boulder with a deep inner-top notch, moved out 2 cm: boulder-vs-head clipping gone except sweep (7 cm, head leans into it) |
| 4 | Fists cocked by the ear went 10–15 cm into the boulders | `_keep_fist_clear` swings the upper arm out; fists and forearms mostly clear. Raised upper-arm roots still enter the boulder underside 5–10 cm, and grab/knockdown/light_2 keep deep spots: needs Brann's clips retimed for the boulders (outside this lane) |
| 5 | Torso and boulders were lumpy terraces from arbitrary facet slopes | Only axis faces and 45° chamfers (narrow on the torso): flat carved planes. The 45° chamfers still show as step stripes up close |
| 6 | Speckled chisel marks and lichen noise on the boulders | Halved and clumped |
| 7 | Ember cracks read as blobs (wide white core) | Core narrowed to a short hot stretch; flat faces keep the seams one cell wide. Glow strength: GPU |

Kept as is: fist size (about 0.28 m across, the sheet's 0.30 m), the apron (stitched hem, pockets, patch, burns read as leather), three-scale detail.
Checks: `game/lookdev/move_scan.gd` (stretch + clipping over every move) and `game/lookdev/review_capture.gd` (angles, close-ups, guard and move poses).

## v3 fixes (owner's note on the v2 reel, ~0:09 walk, side view; lavapipe)
| # | Problem in v2 | v3 |
|---|---|---|
| 1 | Beard braid: one rigid stick on the `BeardBraid` spring, hung 8–10 cm in front of the bib and pushed further out by `_keep_braid_clear`; it jutted out horizontally in walk, run, flight and dash | A chain of three bones (`Braid1`–`Braid3`, under `Head`, added by `BrannBraidBones` before the mesh is skinned). The braid is skinned along the chain and blended at the joints, which sit between the iron rings so the rings stay rigid. `BrannVoxelView._swing_braid` runs verlet joints under gravity with a weak pull toward the head's hang and drag from his movement. Each segment stays within 32° of the chest's down axis and in front of the chest and belly. The root rides in the beard's bottom lobe (head/neck blend like the beard). It now hangs a bead's width in front of the bib |
| 2 | Fist floated in front of the forearm with a see-through slit at the cuff: the palm pivots at the wrist and the cuff was only 3 cm deep | A hand-rigid stone wrist plug on its own grid, hidden inside the forearm and palm at rest, fills the cuff's mouth when the hand bends. The cuff is deeper (5.4 cm, bevelled). `_clamp_wrist` limits the hand's swing off the forearm to 24° and leaves twist free. Checked by `gap_checks()` in `move_scan.gd` and a GUT test over every move |
| 3 | Salt-and-pepper speckle on the stone torso and the denim | Two causes. **Design (fixed):** light "chips" lightened 12% of exposed stone voxels, and on the torso's stepped 45° chamfers every step is an edge, so they read as salt. Chisel dashes broke into dots on the chamfers, and the trouser side seam was dashed. Chips are now on the boulders only (clumped, 8%), chisel marks only on flat facets, the seam is solid, and value noise is ~2% on the torso and denim, with hue drift scaled to match. **Renderer (not design):** the per-pixel grain is PCSS soft-shadow sampling. It lives only in the key light's soft-shadow term. With the same build, pose and camera: SSAO and SSIL off keeps it, hard shadows (no PCSS) remove it, and it is absent in lavapipe frames where the key's self-shadow on the body isn't drawn at all, which is probably why some v2 stills looked clean (`reports/lookdev/brann_v3/speckle_proof.png`). On the GTX 1650, check whether PCSS grain shows without TAA. If it does, the fix belongs in the stage (TAA, or a smaller `light_angular_distance`), not in the voxels |
| 4 | Reel: the dummy sank into his back and boulders (3-hit combo) and its arm into his beard (hit react). Only fists and boots were tested against a capsule | `moves_reel.gd` also keeps the two posed meshes' sampled surfaces 4 cm apart, pushing both back equally along the line between them (like the pushboxes, with the real silhouettes). Pushbox and hurtbox values are unchanged |
| 5 | Beam and ki read pale peach | The reel's glow material was unshaded, so its emission never showed and only the peach albedo did. It's now lit, with black albedo and emission in the energy colour at ~1.2, which keeps #FF4A12 through the filmic tonemap, plus a thin #FFD9A0 core in the beam |
