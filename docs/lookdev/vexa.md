# Look-dev: Vexa (design sheet v1)

**Goal:** Vexa alone, in the approved voxel style (`docs/lookdev/kael.md`, `.claude/skills/voxel-character-lookdev/SKILL.md`), at the voxel Kael quality bar. Look before function: nothing from this sheet reaches `main` or the in-game roster until the owner approves the look.

## Who Vexa is
A **shadow rogue** and the roster's trickster: quick, cocky, playful, always half a step to the side of where you aimed. Speed fighter with the cheapest vanishes; the **Afterimage** decoy is her unique mechanic. Signature weapons: Ki Gauntlets + Orbit Chakram (the chakram rides on her back at idle). Energy colour: **violet-white** (*Phase Form* is violet).

Read at a glance: *tall hood with two swept-back ear points, a black visor with two glowing slits, a jagged shoulder mantle, long thin legs.*

## Proportions (lean, long-limbed, not chibi)
- **6 heads** to the crown (1.72 m; 1.98 m to the ear tips). The smallest head in the roster (0.29 m), but the hood makes it read big.
- The narrowest figure: shoulders 0.40 m (Kael 0.49), waist 0.22 m. Legs are 52% of height. A low, coiled stance: knees bent, weight forward on the balls of the feet.
- Hands and feet stay **near realistic** (×1.05). This is the inverse of Kael: her mass is at the top, not at the extremities.

**Silhouette anchors:**
| Anchor | Size | Reads as |
|---|---|---|
| Hood ear points | 2 × 0.9 head long, rising 0.26 m above the crown, swept back 35°, splayed 20° | two vertical spikes: the only roster member with spikes on top |
| Tattered mantle | 3 pointed tatters per side; shoulder line 1.3× her shoulder width, tips down to mid-chest | a sawtooth shoulder edge (Brann's is round boulders, Lyra's a hat brim) |
| Long thin legs + split-toe soft boots | legs 52% of height, pointed toe | a narrow "Y" or dagger: wide spiky top, thin long stem |

**Silhouette contrast (pure black, gameplay distance):**
- vs **Kael**: Kael's mass sits in his hands and feet and his scarf trails as a ribbon; Vexa has no big hands or boots, no long trailing ribbon, and two spikes above the head.
- vs **Brann**: Brann is a wide flat-topped block on short legs; Vexa is the tallest thin shape with pointed tips.
- vs **Lyra**: Lyra is a mushroom-and-triangle (wide brim on top, ankle-length cape flaring below); Vexa is wide-and-spiky on top, narrow below, with daylight between her legs.

## Detail at three scales
| Scale | Parts |
|---|---|
| **Big forms** (silhouette) | Hood with ear points; head and visor; tattered mantle; cropped jacket over a fitted bodysuit; long legs in leggings; split-toe soft boots; wrapped forearms |
| **Medium parts** | Visor-mask: one curved smoked plate across the eyes with two slanted eye slits and hinge tabs at the temples; hood rim (a lining band 2 voxels wide, accent colour); ear-point seams (one fold ridge each); mantle tatters (3 per side, each with a centre fold); jacket high collar with an off-centre clasp; jacket cuffs and hem band; short waist sash with a knot on the left hip and two tails to mid-thigh (≤ 0.25 m, so it never reads as Kael's scarf); thigh holster strap with 3 throwing-pin slots; knee pads; shin wraps; boot soles and the toe split; forearm wraps ending in knuckle wraps; the Orbit Chakram ring on its back mount (4 blade teeth, a grip bar) |
| **Tiny details** | Wrap bands in a diagonal lattice (1-voxel step ridges, 4–6 per forearm and shin); stitch lines on the jacket seams and collar; 4 rivets on each visor hinge tab; 3 pins in the holster with ring ends; eye-slit glow with one hot glint voxel each; a smirk visible below the visor; a lilac-streaked fringe lock escaping the hood on the right; zip teeth on the jacket front; the chakram's blade-edge bevel (lighter edge voxels); the **emblem** |

**Emblem (original): the Crescent Eye.** A crescent cupped around a single diamond pupil, with three short rays fanning from the crescent's open side. Painted in accent violet on the back of the jacket (between the shoulder blades, under the chakram) and engraved small on the chakram's grip bar.

**Storytelling details:**
1. A hairline crack across the left visor slit, stapled shut with two silver wire stitches.
2. A coin from another zone tucked into the sash knot: her lucky, stolen coin (one warm-bronze voxel cluster, the only warm metal on her).
3. One right-side mantle tatter is shorter than its siblings and re-tied at the tip.
4. Chalk tally marks on the left shin wrap: seven strokes, one crossed through (escapes counted).
5. A tiny bell on the left ear-point tip, silenced with a wrap of thread.

## Palette (muted base; violet is the one saturated accent)
| Material | Base | Shadow | Notes |
|---|---|---|---|
| Hood, mantle | muted plum-violet `#3A2650` | `#22162F` | darker band in the tatters' folds |
| Bodysuit, leggings | blue-black `#1A1C24` | `#0E0F14` | never pure black: the rim light needs something to catch |
| Jacket | gunmetal silver `#8A8F9C` | `#565A66` | lighter edge voxels `#A9AEB9` on the collar and hem: her main light value |
| Wraps | ash-lilac grey `#7A7484` | `#4C4756` | step ridges a touch lighter |
| Boots, holster | charcoal leather `#2C2A30` | `#18171B` | sole `#141316` |
| Visor | smoked glass `#18141F` | `#0C0A10` | one specular glint row |
| Skin | cool light `#E9C9B8` | `#B8958A` | |
| Hair | ash-black `#2B2830` | `#18161C` | one lilac streak `#9A86B8` |
| **Accent:** hood lining, sash, emblem | electric violet `#8A3CF0` | `#5A22A8` | the one strong colour |
| **Energy:** eye slits, ki | violet-white core `#F2E6FF`, glow `#B070FF` | glow falls off to `#6A30C0` | the eye slits use the energy colour |

**Roster palette note (same in all four sheets).** Each legend owns one hue quadrant for accent and energy, and a different base value, so the four don't clash or blur:

| Legend | Accent (hue) | Energy | Base value |
|---|---|---|---|
| Brann | ember-red beard (~8°) | molten red-orange cracks, yellow core | mid-light stone grey |
| Kael | burnt-orange scarf (~22°) | orange-white, reads white | mid teal |
| Lyra | cerulean cape lining (~210°) | blue-white starlight | dark navy, light parchment |
| Vexa | electric violet (~270°) | violet-white | near-black, light silver jacket |

No two accents are within 40° except Brann and Kael, who are split by value (Brann's red is dark and lives in a beard; Kael's orange is bright and lives in a ribbon) and by energy shape (Brann's glows in crack lines, Kael's as a white aura). In team modes `zone_match.gd` swaps the rim energy for team colours; the accents keep identity. Items stay in the gold family, which no legend uses as an accent.

## Voxel spec
- **Body cell 2.2 cm** (1/78 of 1.72 m), the same cell as Kael so voxels read the same size side by side.
- **Head cell about 8.5 mm** (Kael v2) for the face, skull and fringe, so they read smoothly.
- **Fine cell 1.1 cm** on the hood and ear points, visor, hands and knuckle wraps, and the chakram.
- **Colour noise:** ±2–3% value on the jacket and hood panels, up to ±6% on wraps, boots and the chakram. Darker in the hood interior and tatter folds; lighter on worn spots (knee pads, knuckle wraps, toe split, the chakram edge).

## Lighting stack
Kael's stack unchanged (crevice AO, soft key and contact shadow, fill/bounce, voxel edge highlight, rim, mid-grey cyclorama). Vexa notes:
- She is the darkest legend: the **rim light is her outline**. Keep rim on at the Kael level, and check it catches the hood ears and mantle tips.
- Fill must lift the bodysuit off black: shadow side reads `#0E0F14` or lighter, never 0.
- Eye slits are emissive: clamp them so bloom gives a thin glow, not a blob (the MSAA firefly lesson).

## Deliverables (to `lookdev-vexa-v1`)
- 8-angle turntable at 1920×1080 plus a contact sheet; a 6 s spin; an idle loop.
- Close-ups: head (visor, hood, ears, fringe) and the right hand with knuckle wraps; the chakram on its mount.
- `old | new` side-by-side (today's `vexa.tscn` | voxel Vexa).
- The roster **silhouette lineup**: all four legends in pure black at gameplay distance (fighter ~180 px tall at 1080p) in idle, flight and guard.
- Moving reel `vexa_moves_v1.mp4` per the skill (45–60 s), including an Afterimage decoy stand-in and a dash.

## Acceptance (self-check first; the owner decides)
- From 3 m a viewer lists at least 10 parts.
- No raw primitives; wraps read as wraps, not stripes.
- AO and contact shadow visible in every shot, including under the hood.
- Muted and coherent: only violet and the energy are saturated.
- Animates on the current rig: hood doesn't tear on head turns; ears don't clip the shoulders in a guard; fingers sane in a fist, guard and shot.
- In the silhouette lineup a viewer names her in each pose.

## Build notes (for the coder)
| Part | Build | Rig tag / skinning |
|---|---|---|
| Jacket front and back, collar | planar panels with a fold ridge at the side seams, hard hem | `TORSO` (Hips → Chest → UpperChest by height, like Kael) |
| Bodysuit, leggings | profile slices (like `coat_profile`) per limb | `TORSO`, `LEG_L/R` |
| Mantle tatters | 6 planar triangles, each 2 voxels thick with a centre fold ridge; bevelled tips | new `MANTLE`: UpperChest, blended to Left/RightShoulder by `x` (outer tatters 60% shoulder) so a raised arm lifts them |
| Hood dome | curve at the fine cell (its own grid around the head grid) | `HEAD`; the back panel and rim blend Head → Neck → UpperChest so head turns don't open a gap |
| Ear points | tapered capsule chains at the fine cell, one fold ridge | new `EARS`: rigid `Head` in v1 (a spring offset in the view is a later option) |
| Visor | curved plate at the fine cell, slits carved, hinge tabs as boxes with rivets | `HEAD` |
| Fringe lock | 3 bent locks (`_lock` pattern) | `HEAD` |
| Forearm and shin wraps | stepped bands painted as 1-voxel ridges on the limb slices | `ARM_L/R`, `LEG_L/R` |
| Hands | fine-cell hand grids like Kael's gauntlets but slimmer; per-finger tags (`FINGER_BASE` scheme); thumbs rigid with the hand | `GAUNT_L/R` (forearm → hand), fingers, `THUMB_L/R` |
| Sash tails | two short ribbons (`_ribbon`) | new `SASH`: Hips, tail tips 30% UpperLeg of their side; short enough to need no chain |
| Boots | planar sole and upper, carved toe split | `LEG_L/R` (foot part to Left/RightFoot, toes to Toes bones if present) |
| Chakram on back | fine-cell torus with 4 teeth, its own grid | rigid `UpperChest`; hidden while the chakram weapon is held (the weapon layer shows the held copy) |

Grid bounds: body about `AABB(-0.55, -0.01, -0.35) + (1.10, 1.50, 0.70)`; the head grid tall enough for the ears (to y ≈ 2.0).
