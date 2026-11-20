# Skybreak art bible (v2: anime arena)

The one visual rulebook. Every model, prop, zone, shader, effect and screen is
judged against it, by people and by the Visual & Feel Critic routine
(scorecards on issue #113). Intent comes from `docs/GAME_DESIGN.md` §4
(camera), §5.10 (juice), §6 (fighter art direction), §7 (zones) and §11 (UI).

**v2 supersedes v1** (PR #116, the flat "toy-box toon" bible). Owner decision
2026-11-20, from the look mockups (release `look-quick-32a44d5`): the flat toon
look in open 3D read as "cartoonic", so the game goes **hybrid**:

- **B, a 3D anime arena** (the feel of modern 3D anime fighters and
  anime-styled action RPGs): cel-shaded fighters with a strong rim light,
  painted-feeling worlds with real depth, a filmic grade and a close,
  cinematic over-shoulder camera.
- **D-style side-on cinematic angles** for close exchanges and beam clashes.

The camera is developer's lane; this bible sets the framing targets the look is
judged at (§9).

**The style in one line:** crisp cel-shaded legends, back-lit and
ink-outlined, fighting in painted, deep, sky-lit arenas, with bold, short,
coloured anime effects that never hide the bodies.

When in doubt: *fighters first; light from behind; colour over white; depth
from colour, not haze; one strong beat, then clear.*

---

## 1. Shape language

| Thing | Rule |
|---|---|
| Fighters | Heroic anime proportions on the current chunky bodies (big readable head, broad shoulders, oversized hands and feet). One big silhouette feature each (Kael: scarf + goggles, Vexa: eared hood, Brann: rock pauldrons, Lyra: wide hat). Must read as *who* in pure black silhouette at 10 m. |
| Weapons | Chunky, 1.2-1.5x "real" proportions, one primary shape plus one accent. Same outline and toon material as the holder. Class reads from shape (blade = wedge, hammer = block head, lance = shaft + tip, bow = curve + string). |
| Props | 3-5 large forms, bevelled, no spindly parts under ~10 cm at fight distance. Near the fight they are **dense mid-ground silhouettes** (§5). |
| Terrain | Big readable masses with clear tops and faces; every zone has 1-3 landmark silhouettes visible from spawn. |
| VFX | Graphic anime shapes: cones, stars, slashes, rings, speed lines, ribbons (§7). |
| UI | `MenuTheme` (§8). |

Forbidden: raw Godot primitives in shipping scenes unless they are part of a
designed prop with the toon material and outline.

## 2. Outline and rim

| Layer | Outline (`outline.gdshader`) | Rim |
|---|---|---|
| Fighters + held weapons | **2.5 px at 1080p for every legend** (min 0.75 px far), ink `#0F0A1A` | **Light rim on**: `toon.gdshader` `light_rim_strength` 1.1, `light_rim_width` 0.42: a crisp band where a silhouette edge faces a directional light from behind. The zone's back light (`WorldAtmosphere.rim`, fighters' layer only) drives it, so every fighter wears a coloured edge in every zone. Fresnel emission rim 0.3-0.5, tinted to the energy colour only for state. |
| Pickups | 2.5 px | gentle pulse rim |
| Props | 1.0-1.5 px | `light_rim_strength` 0 (`toon_prop.tres`); emission rim <= 0.45 |
| Terrain | none; soft ink only where ground breaks into cliff (<= 0.6 near, 0.2 far) | off |
| VFX | none (they glow) | - |

Rules: **outline thickness falls off from fighter to world**; nothing in the
environment has a heavier line or a brighter rim than a fighter. The rim light
never lights the world (`WorldAtmosphere.RIM_LAYERS`).

Back light energy per zone (`ZoneData.rim_energies`): **>= 0.5 by day**,
night and dusk may go higher; the rim light points from behind what the camera
looks at, 5-80 degrees down.

## 3. Shading model

- Fighters: `toon.gdshader`, **3 bands** (lit, mid, shadow), crisp edges
  (`band_softness` <= 0.02). Weapons and props: 2-3 bands. No PBR sheen, no
  normal-map noise.
- Shadows are tinted, never black: the zone's shadow tint (cool violet by day,
  deep blue at night, maroon in Ember Rift).
- One small specular band at most, on metal and hair.
- The key light casts real shadows from fighters onto the ground.
- Readability: **the fighters always have the highest contrast in frame**:
  outline + 3 bands + rim on them, softer values and no rim on the world.

## 4. Palette

Measured in HSV on the final, graded frame:

| Element | Saturation | Value | Note |
|---|---|---|---|
| Fighters | 0.55-0.95 | 0.2-0.95 | The full value range, plus the rim highlight. |
| Fighter energy / VFX | 0.6-1.0 | 0.85-1.0 | Coloured, not white (§7). |
| Ground near the fight | 0.25-0.6 | 0.3-0.75 | Lower saturation and narrower value range than fighters. |
| Mid-ground silhouettes | 0.3-0.7 | 0.25-0.75 | One step under fighters, darker than the sky behind them. |
| Far landmarks | shift toward the sky colour with distance (§5) | | |
| Sky | 0.2-0.6 | 0.5-0.95 | Three-stop gradient plus painted cloud bands. |

Per zone: one signature hue, one support hue, one shadow tint.

| Zone | Signature | Support | Shadow tint | Must not |
|---|---|---|---|---|
| Shattered Mesa | terracotta red-orange | sky blue | violet | go beige-grey |
| Skyhold Ruins | warm cream stone | golden sky / white cloud sea | dusty blue | wash out into pastel haze (#99) |
| Stormfall City | slate blue-grey | neon magenta + cyan | deep navy | be one flat slab of grey, or crush to black |
| Frozen Peaks | ice blue-white | deep teal | blue-violet | blow out to pure white |
| Verdant Falls | jungle green (mid-dark) | waterfall cyan, bark brown | teal | neon lime (#100) |
| Ember Rift | obsidian, warm basalt | lava orange | maroon | an unreadable black frame; big black crack lines |
| Heartbloom Gardens | blossom pink | gold sunset | plum | a pastel blur where fighters vanish |

Legends: Kael teal/gold + orange (energy orange-gold); Vexa violet + silver
(violet); Brann stone/moss + ember red (red-bronze); Lyra midnight blue + brass
(blue-white). Readability tints (GAME_DESIGN §11) unchanged. No legend colour
may match the zone's dominant ground colour at a similar value.

## 5. Lighting, atmosphere and sky

- **Lights:** one shadowed key (sun/moon) + the shadowless back/rim light on
  the fighters' layer + sky ambient. At most 2 extra shadowless accents in
  frame. No SDFGI, no volumetric fog (AGENTS.md).
- **Atmospheric perspective, not haze:** depth fog starts at 150 m
  (`WorldAtmosphere.HAZE_BEGIN`), ramps slowly (`fog_depth_curve` 1.6), and
  Forward+ adds `fog_aerial_perspective` 0.35 so distance shifts toward the sky
  colour rather than greying out. Fighters up to 25 m keep >= 90% of their
  contrast; nothing between camera and fighters is ever fogged.
- **Depth layers:** foreground (ground texture and small props), dense
  mid-ground silhouettes close to the fight (trees, rocks, ruins, spires at
  10-60 m, darker than the sky behind), then landmarks, then sky. Each layer is
  lighter and closer to the sky colour than the one in front of it.
- **Skies** (`world_sky.gdshader`): three stops (a bright band just over the
  horizon, the horizon colour, the zenith), soft wind-stretched painted cloud
  bands in the lower sky lit toward the sun (`cloud_amount` 0.55), a sun disc
  and glow; stars at night. Never a flat two-colour fill.
- Night keeps a visible key; the rim light separates the fighters.

## 6. Ground and texture

- **Painted feel, not flat fills:** every ground has a broad warm/cool and
  value drift (about 38 m), soft patches (about 17 m) and mid-frequency brush
  mottling (2-6 m), fading out before it would shimmer (`terrain_toon.gdshader`
  `detail_fade`). No stretch of ground bigger than a fighter's shadow reads as
  one flat colour at the gameplay framing.
- **Cracks and seams are a soft step darker (x0.84-0.88), about 2% of a plate
  wide, never black lines.** (Owner screenshot: the giant black crack lines on
  Ember Rift's flat brown floor are the canonical fail.)
- Small graphic details (tufts, pebbles, flowers, sastrugi) stay, with a lit
  top and a soft lower edge.
- No photo textures, no high-frequency speckle, no tiling stripes. 2K max, 1K
  for props.

## 7. VFX

- **Shapes and colour:** bold anime shapes; ki effects are **coloured with a
  coloured core** (`core_whiteness` <= 0.5 on beams and beam tips), so they
  read as the caster's energy, not as white overexposure.
- **Size limits, relative to a fighter (~2 m tall):**

  | Effect | Limit |
  |---|---|
  | Hit spark | <= 40% of the defender's body on screen; the contact stays visible (#77) |
  | Beam body | the sim radius; halo <= 1.45x the body |
  | Beam root | tapers from 30% to full width over the first 2.2 m, and fades within 1.5-4.5 m of the lens, so an over-shoulder camera still sees the caster |
  | Beam tip | orb <= 1.3x the beam's diameter; **no ring on a free tip** |
  | Beam fire / start | no shockwave ring on the caster; a small spark only |
  | Beam clash point | orb 1.2 m, star 1.5 m, ring 1.0 m; clash start/end burst x1.4, sonic ring x0.6 (about 3 m) |
  | Power-up flare | shell <= 1.5 fighter heights (`VfxCatalog.AURA_FLARE_SHELL`), intensity 0.9, floor ring 3.2 m |
  | KO burst | star 1.4 m, ring 1.5 m, 0.25 s, plus the 1-frame impact frame |
  | Push-block / dust rings | <= 1 fighter height at spawn |

- **Speed lines and screen effects** frame the action from the screen edges
  and never cross the fighters' bodies; the only full-screen effect is the
  1-frame KO impact frame.
- **Lifetime:** hits <= 0.25 s, dust rings <= 0.5 s, auras loop under 30%
  opacity on the body.
- **One strong beat:** a big moment gets exactly one dominant beat (hitstop +
  one flash/ring + one shake), then clears.
- **Bloom budget:** effects are the only things over the bloom threshold
  (§10). No frame is more than 15% blown-out white outside the KO frame; the
  caster of a beam is always visible.

## 8. UI

The HUD and menus follow `MenuTheme` (heavy rounded display font with ink
outline, skewed parallelogram panels, ink/navy fill, gold focus, cyan info, hot
orange primary). T-UI1 is restyling the HUD; this bible only constrains its
footprint: <= 12% of the screen in 1v1, <= 18% in FFA-4, nothing in the
central 50% x 50% except combat text that clears within 1 s. No debug text
unless F3 is on. Menu transitions <= 0.3 s.

## 9. Camera framing (developer's lane; the look is judged here)

- **Base (B) framing:** low over-shoulder, the player's fighter **25-35% of
  screen height**, the opponent in view past the shoulder.
- **Side-on exchange (D) shots** for close exchanges and beam clashes: long
  lens, both fighters **35-40% of screen height**, the line between them
  roughly horizontal.
- Both locked fighters on screen in >= 95% of locked frames; no fighter covers
  more than 60% of the screen (QA rules).
- Horizon roughly level; no dutch angles outside cinematics; no cuts during
  player control; shake only on received heavy hits and big impacts.
- Geometry between camera and fighters dithers out; the camera never sits in
  geometry (#114).

## 10. Grade and post-processing

Shared by all 7 zones (`game/world/world_map.tscn` Environment, driven per zone
by `WorldAtmosphere`):

| Setting | Value | Why |
|---|---|---|
| Tonemap | ACES, white 6.0 | filmic shoulder: bright effects roll off instead of clipping |
| Exposure | per zone, `ZoneData.exposures`, 0.98-1.18 (Stormfall 1.18) | ACES darkens mid-tones; snow stays under 1.0 by day |
| Glow | on, HDR threshold 1.15, scale 1.6, intensity 0.55, strength 0.9, screen blend, no bloom | only over-bright effects glow; lit ground and skin never bloom |
| Adjustments | contrast 1.08, saturation 1.06 | anime punch without crushing |
| Fog | depth, from 150 m, curve 1.6, aerial perspective 0.35 | atmospheric depth (§5) |

**Exposure targets** on the graded frame at the B framing: lit fighter skin
value 0.75-0.9; ground near the fight 0.3-0.75; the sky above the horizon
0.5-0.95; no fighter pixel clips to white outside effects.

**Web (gl_compatibility) fallback:** the same Environment resource. ACES,
glow and adjustments run there; `fog_aerial_perspective` is ignored, the depth
fog still layers the distance. Every shader change (toon light rim, sky, ground,
beam taper) is plain GLSL that runs in both renderers. The visual goldens are
rendered in gl_compatibility and must still read.

**GPU budget:** no zone slower than before the pass on the GTX 1650 render
benchmark; Skyhold (the heaviest) stays at or under 6.3 ms GPU p95.

## 11. Motion principles

Unchanged from v1: readable anticipation (4-6 frames on heavies, smashes and
specials), whole-body weight, follow-through on scarf/cape/hat, snappy squash
and stretch, feet on the ground (QA: within 5 cm), no sliding, no sinking, no
interpenetration (#73), weapons never through their holder, bone pops at most 2
per fighter-minute, hitstop per GAME_DESIGN §5.10.

## 12. Instant fails

The v1 "random drawing" list still applies: placeholder primitives;
untextured grey or default-white materials; PBR next to toon; inconsistent
outline width between legends; off-palette colours; debug lines, gizmos or
text; visuals that contradict gameplay; stray floating geometry; z-fighting;
clipping; popping; foot sliding; noise or stripe textures. New in v2:

- a frame where an effect hides the caster or the defender (the beam
  washout in every row of the look mockups);
- a white beam, ring or flare bigger than the limits in §7;
- black crack or seam lines on the ground; any big flat single-colour fill;
- a flat two-colour sky;
- a fighter without a visible rim edge against the backdrop;
- fog or haze over the fighters, or a backdrop that greys out instead of
  shifting toward the sky colour;
- the world with more contrast than the fighters.

## 13. Shot script and scoring

**Look stills** (`game/view/shaders/preview/look_capture.gd`, seed 7, Kael vs
Vexa, HUD hidden, a review-only stand-in camera at the §9 framings):

1. Heartbloom Gardens and Ember Rift, **hit**: Kael's light, frozen 3 ticks
   after contact; close (B) and side-on (D).
2. The same zones, **beam**: Kael's beam special at 10 m, 28 ticks after the
   press; close and side-on.
3. Every zone at the close framing and from the real gameplay camera.

```sh
godot --path . --rendering-driver vulkan --resolution 1280x720 --disable-vsync \
  -s res://game/view/shaders/preview/look_capture.gd -- <out dir> [moments|zones]
```

The full critic list (every legend, KO, ki, HUD, menus, a clip) is
`tools/qa/art_shots.gd` from PR #116.

**Scoring**, 1-10 per category: style cohesion, zones/environment,
fighters/models, motion feel, contact and grounding, hit feel/VFX, camera,
UI/HUD, menus, overall. 5 = playable prototype, 7 = coherent and shippable for
a personal project, 9 = would not look out of place next to the references.
