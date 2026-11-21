# Look-dev: Lyra (design sheet v1)

**Goal:** Lyra alone, in the approved voxel style (`docs/lookdev/kael.md`, `.claude/skills/voxel-character-lookdev/SKILL.md`), at the voxel Kael quality bar. Look before function: nothing from this sheet reaches `main` or the in-game roster until the owner approves the look.

## Who Lyra is
A **star-cartographer mage** and the roster's zoner and trapper: calm, precise, a little dreamy, always measuring the sky. Best ki blasts and beams; her unique mechanic is **Seal mines** (up to 3 floating mines). Weak up close, low guard. Signature weapons: Ki Bow + Sky Lance. Energy colour: **blue-white starlight** (*Starlight* form).

Read at a glance: *huge bent-tip hat with star lights, ankle-long star-map cape, three floating brass rings, a light parchment stole.*

## Proportions (tall and slender, not chibi)
- **5.5 heads** to the crown (1.70 m); the hat adds 0.45 m (2.15 m to the bent tip).
- Narrow shoulders (0.42 m), a long robe coat to the knee with a bell skirt, slim knee-high boots. Upright, composed stance; weight on the back foot.
- Hands near realistic (×1.1); boots ×1.0. Her mass is at the **top (hat) and the bottom (cape hem)**.

**Silhouette anchors:**
| Anchor | Size | Reads as |
|---|---|---|
| Wide-brimmed hat | brim 0.92 m across (≈ 3 head widths); crown 0.40 m tall, bending 0.24 m back to a hanging star charm | a mushroom cap with a hook: widest point at the top |
| Star-map cape | ankle-length; 0.42 m wide at the clasp, 0.90 m at the hem | an A-line triangle under the brim; a broad panel (not a ribbon) in flight |
| Floating astrolabe rings | three nested rings (0.30, 0.24, 0.18 m) behind her left shoulder, 0.25 m off the body | circles with sky through them: the only detached shape in the roster |

**Silhouette contrast (pure black, gameplay distance):**
- vs **Kael**: both have something trailing in flight, but Kael's is a narrow scarf from the neck and Lyra's a wide cape from the shoulders; Kael's hair tufts are small, Lyra's brim is wider than her shoulders.
- vs **Brann**: Brann is widest at the shoulders and flat-topped; Lyra is widest at the hat and the hem, narrow at the shoulders.
- vs **Vexa**: Vexa's top is two thin spikes; Lyra's is one wide disc with a hook. Vexa shows daylight between her legs; Lyra's cape and skirt close the space.

## Detail at three scales
| Scale | Parts |
|---|---|
| **Big forms** (silhouette) | Hat (brim and bent crown); head with long straight hair; knee-length robe coat with a bell skirt; star-map cape; slim knee-high boots; the three floating rings |
| **Medium parts** | Hat band with a small buckle; the brim's upturned edge (2 voxels proud); 8–12 star lights set in the brim and crown; the hanging star charm on the crown tip; standing collar open in a V; parchment stole hanging in two strips down the front; belt with three scroll cases on the right hip; leather bracers with brass stylus clips; fingerless gloves; cape clasp (two brass discs and a short chain); cape lining (accent) with a constellation map; boot cuffs and soles; ring spokes and a sighting bar on the largest ring |
| **Tiny details** | Constellation dots and joining lines on the cape lining (1-voxel paint, pale energy colour); latitude lines and a compass rose inked on the stole; degree ticks on every ring (24 per ring, 1 fine voxel); 4 rivets on each clasp disc; stitch lines on the robe hem and bracers; a quill in the hat band; eyelashes, eyes with two highlights each (deep blue iris), a small mouth; 2–3 loose hair strands over the brim's shadow; the **emblem** |

**Emblem (original): the Wayfinder Star.** An eight-point star whose lower point stretches into a long plumb line, set inside a broken circle with its gap at the upper right. Embroidered in pale parchment on the cape's outer back, and engraved on the largest ring's sighting bar.

**Storytelling details:**
1. An ink stain on the right index fingertip and on that glove's cuff.
2. A quill tucked into the hat band, and beside it a pressed Heartbloom petal (one pink voxel cluster, her personal mark).
3. One scroll case is dented and re-tied with string.
4. An unfinished corner of the cape map: blank lining with only a pencil grid.
5. The smallest ring has one missing degree tick, filed flat (a calibration mark).

## Palette (muted base; cerulean is the one saturated accent)
| Material | Base | Shadow | Notes |
|---|---|---|---|
| Hat, robe coat | midnight blue `#1E2546` | `#11152B` | darker band in the skirt folds |
| Cape outer | night navy `#161A33` | `#0B0D1C` | darker than the coat, so the coat reads in front of it |
| Parchment stole, scroll cases | warm parchment `#CDB892` | `#9A8564` | her main light value at distance |
| Brass rings, clasps, buckle | pale aged brass `#B49A64` | `#7A6540` | cooler and paler than Kael's gold; desaturated so it never reads as the gold item family |
| Leather (belt, bracers, boots) | cool grey-brown `#4A3E3A` | `#2D2523` | sole `#1E1918` |
| Hair | soft dusk lavender-grey `#9C93B4` | `#625A7E` | muted; cool shadow |
| Skin | warm light `#F0C8AE` | `#BE9580` | |
| **Accent:** hat band | cerulean `#1E7FD8` | `#12509A` | the one strong colour |
| Cape lining | muted cerulean `#44709F` (v4) | `#2A496B` | authored at sat 0.57: the GPU stage key light lifts it about 0.1, to about 0.67 on screen (v3's `#3A6FB0` rendered `#24579B`, sat 0.77). Its shadow tone edges the facing and pipes the hem, so the stole stays the brightest accent. Flashes big when the cape opens in flight |
| **Energy:** star lights, ki, constellation dots | blue-white core `#EAF4FF`, glow `#7FC0FF` | glow falls off to `#3E7FD0` | |

**Roster palette note (same in all four sheets).** Each legend owns one hue quadrant for accent and energy, and a different base value, so the four don't clash or blur:

| Legend | Accent (hue) | Energy | Base value |
|---|---|---|---|
| Brann | ember-red beard (~8°) | molten red-orange cracks, yellow core | mid-light stone grey |
| Kael | burnt-orange scarf (~22°) | orange-white, reads white | mid teal |
| Lyra | cerulean cape lining (~210°) | blue-white starlight | dark navy, light parchment |
| Vexa | electric violet (~270°) | violet-white | near-black, light silver jacket |

Lyra's navy (~230°, low saturation, dark) and Kael's teal coat (~185°, mid value) stay apart by hue and value; her cerulean is the only saturated blue on the roster. In team modes the rim energy becomes the team colour; the accents keep identity.

## Voxel spec
- **Body cell 2.2 cm** (1/77 of 1.70 m), the same cell as Kael.
- **Head cell about 8.5 mm** (Kael v2) for the face, skull and hair, so they read smoothly.
- **Fine cell 1.1 cm** on the hat (brim, crown, charm, star lights), hands and bracers, the rings and the clasp.
- **Colour noise:** ±2–3% value on the robe, cape and brim; up to ±6% on leather, brass and the stole. Darker in the brim's underside and the cape folds; lighter on wear (stole edges, boot toes, ring edges, scroll-case caps).

## Lighting stack
Kael's stack unchanged. Lyra notes:
- The brim throws a big shadow on her face: the **fill must keep the eyes readable** (check the head close-up at 3 angles).
- Star lights and constellation dots are emissive: clamp them; a dot should bloom to a 2–3 px glow, never merge into a smear.
- AO under the brim and inside the cape is the signature crevice; make it visible.

## Deliverables (to `lookdev-lyra-v1`)
- 8-angle turntable at 1920×1080 plus a contact sheet; a 6 s spin; an idle loop with the rings turning.
- Close-ups: head under the brim (face, hair, quill, petal) and the rings; the right hand with the ink stain.
- `old | new` side-by-side (today's `lyra.tscn` | voxel Lyra).
- The roster **silhouette lineup** (all four in pure black at gameplay distance, idle, flight, guard).
- Moving reel `lyra_moves_v1.mp4` per the skill, including a seal-mine placement stand-in and a beam framed close enough to judge the pose.

## Acceptance (self-check first; the owner decides)
- From 3 m a viewer lists at least 10 parts.
- No raw primitives: the brim has its upturned edge, the scroll cases have caps and straps.
- AO and contact shadow visible in every shot; the face reads under the brim.
- Muted and coherent: only cerulean and the energy are saturated.
- Animates on the current rig: cape doesn't cut through the legs in a run or a kick; the brim doesn't cut the shoulders on a head turn; the bell skirt doesn't tear at the knees.
- In the silhouette lineup a viewer names her in each pose.

## Knockdown: the hat stays off the floor (v4)
The hat is skinned to its own `Hat` bone (a child of `Head`, added at runtime by `LyraHatClearance`). When she lies down, that modifier (the last one on the skeleton) rocks the hat on the top edge of her skull by the smallest tilt that keeps its lowest point (brim rim, crown, hook and charm) 2 cm above the floor. It eases in from 0.45 m above the floor, so the hat tips over a few frames rather than popping. The approved brim (0.36 m, front up 13°, back droop 6°) is unchanged. `tests/characters/test_lyra_voxel.gd` plays KNOCKDOWN and KO_DOWN and checks the lowest real hat vertex against the floor.

## Build notes (for the coder)
| Part | Build | Rig tag / skinning |
|---|---|---|
| Robe coat body, collar | planar panels with seam ridges, hard hem | `TORSO` |
| Bell skirt | Kael's `_skirt` pattern, wider; a front split to the knee | `SKIRT`: Hips → UpperLeg by `x`, stronger leg weight at the hem (up to 0.6) so knees don't punch through |
| Cape | one planar panel, 2 voxels thick, with 4–5 vertical fold ridges and a hard hem; lining painted with the map | new `CAPE`: a chain on the existing `Scarf1`–`Scarf5` bones (driven by `scarf_lag.gd`) down the spine; the outer columns blend 30% to UpperLeg L/R near the hem |
| Stole strips | two planar strips with inked lines | `TORSO` with the tips 20% UpperLeg |
| Hat brim | a flat fine-cell annulus 2 voxels thick with the edge raised 2 voxels; no ellipsoid | new `HAT`: rigid on its own `Hat` bone under `Head` (tips off the floor, v4) |
| Hat crown | capsule chain at the fine cell bending back, the charm on 2 chain links | `HAT` (charm rigid with it in v1) |
| Hair | straight sheet locks (`_lock`), back sheet ends at the shoulder blades | `HEAD`; the back sheet blends Head → Neck → UpperChest |
| Astrolabe rings | three fine-cell tori with spokes, their own grids | **not skinned**: separate `MeshInstance3D`s under an UpperChest attachment, turned by the view at a slow constant rate (view-only, no sim) |
| Scroll cases | cylinders with caps and straps (deliberate shapes) | `TORSO` (Hips) |
| Hands, bracers | fine-cell hand grids, per-finger tags, thumbs rigid | `GAUNT_L/R`, fingers, `THUMB_L/R` |
| Boots | planar upper and sole, folded cuff | `LEG_L/R` |

The bow and lance are pickup weapons built by the weapon layer, not part of this figure; they show on her idle pose only.
