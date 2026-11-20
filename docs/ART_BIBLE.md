# Skybreak art bible

The one visual rulebook. Every model, prop, zone, shader, effect and screen is
judged against it, by people and by the Visual & Feel Critic routine
(scorecards on issue #113). Source of truth for intent: `docs/GAME_DESIGN.md`
§4 (camera), §5.10 (juice), §6 (fighter art direction), §7 (zones), §11 (UI).

**The style in one line:** a *toy-box platform-fighter* look (in the spirit of
Brawlhalla, not of any anime): chunky, bright, ink-outlined legends with 2-3
flat cel bands, standing in simple, bold, slightly lower-contrast worlds, with
punchy, short-lived graphic effects. **Not** DBZ realism, not painterly, not
pastel, not photographic.

When in doubt: *fewer, bigger shapes; flatter colour; darker outline; shorter effect.*

---

## 1. Shape language

| Thing | Rule |
|---|---|
| Fighters | ~4.5 heads tall. Big head, broad shoulders, oversized hands and feet, compact torso, short legs. One big silhouette feature each (Kael: scarf + goggles, Vexa: eared hood, Brann: rock pauldrons, Lyra: wide hat). Must read as *who* in pure black silhouette at 10 m. |
| Weapons | Chunky and oversized (1.2-1.5x "real" proportions), simple primary shape plus one accent shape. Same outline and toon material as the holder. A weapon's gameplay class must read from its shape: blade = flat wedge, hammer = block head, lance = long shaft with a clear tip, bow = curve + string. |
| Props | Bevelled blocks and tapered cylinders, rounded-off corners, 3-5 large forms per prop. No thin spindly parts under ~10 cm at fight distance. |
| Terrain | Big readable masses: plateaus, ledges, pillars, cliffs with clear tops and faces. Faceting is fine if it is *intentional* (large flat facets, consistent size); random lumpy "blob" noise is not. Every zone has 1-3 landmark silhouettes visible from spawn. |
| VFX | Graphic shapes: discs, rings, stars, slashes, cones, ribbons. Hard edges or one clean soft falloff, never smoke-noise. |
| UI | Skewed parallelogram panels (`MenuTheme.SKEW`), heavy rounded sans display font with ink outline. |

Forbidden: unbevelled default primitives (raw `BoxMesh`, `SphereMesh`,
`CylinderMesh` straight from Godot) left in shipping scenes, unless they are
part of a deliberately designed prop with toon material and outline.

## 2. Outline and rim

| Layer | Outline width (`outline.gdshader`) | Colour | Rim |
|---|---|---|---|
| Fighters + held weapons | 2.0 px at 1080p, min 0.75 px when far | ink `#0F0A1A` (0.06, 0.04, 0.10) | toon rim on, strength 0.3-0.5, blends to the legend's energy colour only for state (charging, transformed) |
| Pickups (dropped weapons, gadgets) | 2.0 px | ink | gentle pulse rim so they read as interactive |
| Props | 1.0-1.5 px | ink, or the zone's darkest palette colour | off or very weak |
| Terrain | none, or a 1 px edge only on silhouette edges | zone's darkest colour | off |
| VFX | none (they glow instead) | - | - |
| UI | text outline 8-10 px, panel border 4-5 px | `MenuTheme.INK` | - |

Rule: **outline thickness falls off from fighter to world.** Nothing in the
environment may have a heavier line than a fighter. Never mix outlined and
un-outlined assets in the same category.

## 3. Shading model

- Toon shader (`toon.gdshader`) for every fighter, weapon, prop and pickup.
  Fighters: 3 bands (lit, mid, shadow). Props: 2-3 bands. Terrain: 2 bands or
  flat vertex colour plus the zone light.
- Band edges are crisp (`band_softness` <= 0.02). **No muddy gradients**, no
  PBR roughness/metal sheen, no normal-mapped surface noise.
- Shadows are tinted, never black: shadow band = the base colour shifted
  toward the zone's shadow tint (cool violet by day, deep blue at night, warm
  maroon in Ember Rift).
- One specular band at most, small, on metal and hair only.
- Real-time shadow from the key light: fighters cast; terrain receives; small
  props may skip casting.

## 4. Palette

Value and saturation, measured in HSV on the final frame:

| Element | Saturation | Value | Note |
|---|---|---|---|
| Fighters | 0.55-0.95 on main colours | 0.25-0.95, full range | **Always the highest contrast in frame.** 2-3 main colours + 1 accent. |
| Fighter energy / VFX | 0.6-1.0 | 0.85-1.0 | Brightest elements on screen, for less than a second at a time. |
| Terrain (ground plane) | 0.25-0.6 | 0.35-0.75 | Lower saturation **and** narrower value range than fighters. |
| Props / landmarks | 0.3-0.7 | 0.3-0.8 | One step under fighters. |
| Sky | 0.2-0.6 | 0.5-0.95 | Simple 2-3 stop gradient; may carry the zone's signature hue. |
| UI panels | ink/navy panels, gold/cyan/hot accents (`MenuTheme`) | - | Shared across menus and HUD. |

Per zone (each zone has one *signature hue*, one *support hue*, one *shadow tint*):

| Zone | Signature | Support | Shadow tint | Must not |
|---|---|---|---|---|
| Shattered Mesa | terracotta red-orange | sky blue | violet | go beige-grey |
| Skyhold Ruins | warm cream stone | golden sky / white cloud sea | dusty blue | wash out into pastel haze (#99) |
| Stormfall City | slate blue-grey | neon magenta + cyan accents | deep navy | be one flat slab of grey |
| Frozen Peaks | ice blue-white | deep teal | blue-violet | blow out to pure white |
| Verdant Falls | jungle green (mid-dark) | waterfall cyan, bark brown | teal | neon lime (#100) |
| Ember Rift | obsidian near-black | lava orange | maroon | turn into an unreadable black frame |
| Heartbloom Gardens | blossom pink | gold sunset | plum | become a pastel blur where fighters vanish |

Per legend: Kael teal/gold + orange accent (energy orange-white); Vexa violet +
silver (energy violet); Brann stone grey/moss + ember red (energy red-bronze);
Lyra midnight blue + brass (energy blue-white). Readability tints
(GAME_DESIGN §11): your attacks warm, the opponent's cool; perfect block blue,
guard break and counter red.

No colour may appear on a fighter that is also the zone's dominant ground
colour at similar value (e.g. no lime legend on Verdant Falls ground).

## 5. Lighting and fog

- One key directional light (shadowed) + ambient from the sky. At most 2 extra
  shadowless accent lights in frame. No SDFGI, no volumetric fog (AGENTS.md).
- Fog: depth fog only for distance; **fog density must leave fighters at
  25 m with at least 70% of their unfogged contrast.** Fog colour = the zone's
  sky horizon colour, never a flat pastel wash over the whole frame.
- Ambient never so high that the toon shadow band disappears: on any fighter,
  the lit band and the shadow band differ by at least 0.2 in value.
- Night variants keep a visible moon/key light; fighters still separate from
  the background (rim does that work).

## 6. Texture density

- Stylised flat colour, vertex colour, or hand-painted-style textures with
  large shapes. 2K max, 1K for props (AGENTS.md budget).
- **No noise textures, no photo textures, no procedural speckle** on surfaces
  the camera sees at fight distance. Detail comes from geometry and colour
  blocking, not texture noise.
- Consistent texel density: a rock and a fighter at the same distance show
  details at the same scale. Stripes or banding from tiling (stretched UVs,
  repeating bands) are bugs.

## 7. VFX

- **Shapes:** graphic (see §1). Light hit: small white star, 4-6 frames.
  Heavy hit: orange star + one impact ring, 8-12 frames. Block: blue
  hex/shield flash. Ki: core-white with an energy-coloured rim.
- **Size:** a hit spark never covers more than ~40% of the defender's body on
  screen; the contact must stay visible (#77).
- **Lifetime:** hits <= 0.25 s, ki projectiles live while they fly, dust rings
  <= 0.5 s, auras loop but stay under 30% opacity on the body.
- **One strong beat:** a big moment (heavy finisher, guard break, KO, beam
  clash, transformation) gets exactly **one** dominant beat: hitstop + one
  flash/ring + one camera shake, then it clears. No stacking of five effects at
  once; no full-screen recolour except the 1-frame KO impact frame.
- Colour coding follows the palette table and §11 readability tints.
- Additive glow is capped: no frame may be more than 15% blown-out white
  outside the KO impact frame.

## 8. UI

- **Font:** the heavy rounded display font used by `MenuTheme`, uppercase for
  headers and buttons, ink outline. Body text in the same family, sentence case.
- **Panels:** skewed parallelograms, ink/navy fill, 4-5 px borders, gold for
  focus, cyan for info chips, hot orange for the primary action (FIGHT!).
- **Colour coding:** team colours from `MenuTheme.TEAM_COLORS` everywhere
  (HUD bars, name tags, character select seats, off-screen arrows).
- **HUD footprint:** at most ~12% of the screen area in 1v1, ~18% in FFA-4;
  nothing in the central 50% x 50% except transient combat text (combo, damage,
  COUNTER) which disappears within 1 s of the event.
- No debug text, fps counters or build strings in gameplay or menus unless
  the F3 overlay is on (a small build tag in a menu corner is allowed).
- Menu transitions <= 0.3 s (GAME_DESIGN §11).

## 9. Camera framing

- Both locked fighters on screen in >= 95% of locked frames (QA rule); in FFA,
  the target plus the player always, others shown by edge arrows.
- Player fighter in the lower-left or lower-right third (over the shoulder),
  occupying 15-35% of screen height at mid range; never more than 60% of the
  screen (QA rule).
- Horizon roughly level; no dutch angles outside cinematics.
- Terrain or props between camera and fighters dither out; the camera never
  sits inside geometry (#114).
- No cuts during player control; shake only on received heavy hits and big
  impacts (GAME_DESIGN §4).

## 10. Motion principles

- **Anticipation:** every heavy, smash and special has a readable wind-up pose
  held for at least 4-6 frames.
- **Weight:** heavies commit the whole body (hips and shoulders turn); Brann is
  visibly slower and heavier than Vexa.
- **Follow-through:** limbs, scarf, cape and hat lag and settle; recovery poses
  are visible.
- **Squash and stretch** on impact and landing, snappy not rubbery.
- **Contact:** feet on the ground while standing (QA: within 5 cm); no sliding
  feet while idle; no sinking. Bodies never interpenetrate (#73); weapons never
  pass through their holder (QA weapon rules).
- **No floating, no sliding, no popping:** bone pops > 1.2 rad/frame at most 2
  per fighter-minute (QA rule); no T-poses, no frozen statues for > 1 s outside
  idle.
- Hitstop values per GAME_DESIGN §5.10.

## 11. "Random drawing" offenders (instant fails)

Placeholder primitives; untextured grey or default-white materials; mismatched
material styles (PBR next to toon); inconsistent outline thickness; off-palette
colours; debug lines, gizmos or text; visuals that contradict gameplay (a
"blade" that looks like a cone); stray floating geometry; z-fighting; clipping;
popping; foot sliding; noise or stripe textures.

## 12. How the critic scores

Categories, 1-10 each: style cohesion, zones/environment, fighters/models,
motion/animation feel, contact and grounding, hit feel/VFX, camera, UI/HUD,
menus, overall. 5 = playable prototype, 7 = coherent and shippable for a
personal project, 9 = would not look out of place next to the reference.
Shot list: `tools/qa/art_shots.gd` (fixed seeds and cameras), so runs compare.
