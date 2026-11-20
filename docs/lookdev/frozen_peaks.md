# Look-dev: Frozen Peaks (zone design sheet v1)

**Goal:** Frozen Peaks in the approved voxel style, at the characters' voxel density and with their lighting stack (`docs/lookdev/kael.md`, `.claude/skills/voxel-character-lookdev/SKILL.md`, template `docs/lookdev/heartbloom.md`). Same loop as a character: this sheet, then a build, then a stage, then the owner's three gates. Look before function: the terrain (`TerrainShape._peaks`), zone data (`frozen_peaks.tres`) and props layout (`FrozenPeaksProps`, `PropKit` seed 4242) stay the truth; this is a visual pass over them.

## Identity and mood
**A glacier valley under the aurora:** a winding river of blue-white ice between terraced slate mountains, moonlit snow brighter than the sky, a green aurora ribbon over the Ice Crown, and an abandoned expedition camp half buried in drift. Quiet, vast, crystalline; the cold you can hear. Read at a glance: *moonlit snow valley, slate cliffs with ice shelves, glassy ice spires, an aurora over a crowned peak.*

Mood comes with its image: the tank's diorama craft, lit like a miniature on a light table. Music *Glass Summit* (140 bpm) and the `amb_frozen_peaks` bed (wind, creaking ice): sparse and bright, with the wind as the rhythm.

**Lesson applied:** the grey-block is pale grey-blue everywhere (snow 0.80–0.84 grey, fog pale blue, sky pale blue): no contrast. The voxel pass makes **snow the brightest thing in the world**, the rock a **dark slate**, the ice a **mid cyan-grey with depth**, and the sky a **deep indigo** that the snow glows against.

## Layout at gameplay scale
From `TerrainShape._peaks`, `frozen_peaks.tres` and `FrozenPeaksProps` (zone centre (−650, −560), extent 340 × 420, arena box ±300 m, ceiling 395 m):

| Part | Shape (local to the centre) | Role in a fight |
|---|---|---|
| **Glacier Valley** | a sinuous floor at 72 ± 6 m along `lz = 70·sin(lx/140) + 30`, flat for ~55 m either side, rising into the mountains by ~150 m; landmark (−650, 72, −530) | the main stage; the spawns stand on the valley line at (−670/−630, −530) |
| **Mountain walls** | ridged noise 95–295 m, 40% blended with 22 m terraces | vertical cliffs to fight along; terraces read as rock bands |
| **Ice Crown Peak** | the highest summit, landmark (−800, 250, −750) north-west | the compass and the aurora's anchor |
| **Shelf Cliffs** | steep faces above 100 m with ice shelves, landmark (−500, 150, −700) north-east | ledges for zoners; avalanche slabs |
| Ice spires | 60 spires, 22–62 m tall, r 4–10 m, tilted ±0.2 rad, on ground below 140 m | cover in the valley; shatter when hit |
| Ice shelves | 26 slabs 26–44 × 4 × 16–26 m jutting downhill from cliffs (grade > 1, above 100 m) | perches and the avalanche destructible |
| Boulders | 120 ice boulders 2.5–8 m | low cover, texture of the valley floor |

- **Fighting space:** the valley is a 110 m wide, ~600 m long winding lane with 25–220 m walls: favours vertical play along cliffs and line-of-sight breaks around bends. Keep a **15 m clear lane** down the valley centre so the duel always has a flat floor.
- **Verticality:** valley 72 m, shelves 100–200 m, summits to ~295 m, ceiling 395 m. The Ice Crown's summit is the only thing near the ceiling.
- **Edges:** the outer ridges blend into neighbours over 100 m; at the zone edge the terraced ridges stay as silhouettes in fog.
- **Landmarks are navigation:** the valley (a bright S-curve seen from above), the Ice Crown (a tall peak with a ring of ice teeth), the Shelf Cliffs (horizontal ice ledges). Shapes: line, spike, stack.

## Detail at three scales
| Scale | Parts |
|---|---|
| **Big forms** | The valley glacier as a planar ice sheet with crevasse bands crossing it; snowfields on the lower slopes as smooth terraced drifts; slate mountains in **planar strata slabs** stepping back (the 22 m terraces become rock bands with snow on every ledge); the Ice Crown's ring of ice teeth; cornices overhanging ridges; distant ranges as silhouettes |
| **Medium parts** | Ice spires (6 variants: hexagonal prisms with stepped facets, clustered in 2–4, a cloudy core and a clear edge); ice shelves (stratified slabs, blue layers, icicle fringe); ice boulders and slate boulders; crevasses (cut channels 1–3 m wide with blue depth); the **expedition camp** (two A-frame tents, a crate stack, a sledge, a tripod flagpole); a **stone waymarker** line along the valley (stacked slate cairns every 60 m); a frozen waterfall on one cliff; a rope bridge across a crevasse; wind-carved sastrugi ridges |
| **Tiny details** | Sastrugi ripples in the snow (T1 ridges, the existing `sastrugi` pattern as voxel relief); frost sparkle (single bright voxels on snow, rare); icicles (T0); bubbles and cracks frozen inside ice (darker voxels in the clear layer); rope knots and frayed ends; boot prints along the cairn line; snow caps on every boulder, crate and cairn; lichen spots on slate (dull ochre-grey); frozen tent guy-lines |

**Storytelling details (at least 5):**
1. The **expedition camp**: one tent collapsed under snow, the other still standing with its flap tied open; a mug on a crate.
2. A **sledge** half buried with three crates still lashed on, one split open showing coiled rope.
3. **Boot prints** along the cairn line that stop at a crevasse; the rope bridge beside it is newer than the cairns.
4. An **ice axe** frozen into the side of an ice spire at head height.
5. The **flagpole tripod** at the camp with a torn pennant, frozen stiff mid-flap.
6. The **first cairn** in the line is taller than the rest, with a flat stone on top scratched with tally marks (days at the camp).

**Zone emblem (original): the Crown Star.** A six-point frost star whose top three points are longer, so it reads as a crown. Painted on the crates and carved on the first cairn.

## Voxel density (the characters' relationship, scaled)
| Tier | Cell | Used for | Note |
|---|---|---|---|
| T0 | 2.2 cm | ≤ 1 m: icicles, rope, mug, ice axe, pennant, boot prints, tally marks, frost sparkle | same pixel scale as a fighter |
| T1 | 8.8 cm | 1–15 m: tents, crates, sledge, cairns, boulders, ice spire bases (lower 12 m), shelf edges and icicle fringes, crevasse lips; **the walkable valley floor** (top 1 m shell) | what fighters stand on and fight against |
| T2 | 35 cm | spire upper bodies, shelf slabs, lower cliffs, snowfields | never at a fighter's feet |
| T3 | 1.4 m | high cliffs, summits, the Ice Crown, far ranges, snow-storm puffs | far or in haze |

- **Feet rule:** valley floor rounds to T1; the visible top stays within ±4.4 cm of the `ZoneGround` floor. Snow caps on props are part of the prop, never a separate layer that floats.
- **Colour noise:** ±2% on snow (more makes it dirty), ±3% on slate, up to ±6% on ice (layers) and gear. Darker in crevasses, under shelves and at boulder feet; lighter on windward snow crests and ice edges.
- **Design in blocks:** cliffs are planar strata, spires are faceted prisms, snow drifts are terraced contours. No round snowballs, no smooth domes.

## Palette and value plan (bright ground, dark rock, deep sky)
| Material | Base | Shadow | Notes |
|---|---|---|---|
| Snow | blue-white `#E4E8EE` | `#9AA6BC` (blue) | the brightest large surface; exposure keeps it off pure white |
| Wind-packed snow, sastrugi crests | `#F0F2F5` | `#A8B2C6` | |
| Glacier ice | cyan-grey `#9CB4C4` | `#5A7488` | sat ≤ 20%; depth inside crevasses `#3E5A70` |
| Clear ice edges (spires) | `#C8DAE4` | `#7890A4` | edge highlight |
| Slate rock | blue-grey slate `#4A505E` | `#2C303A` | darker than every fighter's light element |
| Lichen on slate | dull ochre-grey `#7A7458` | `#4E4A38` | tiny spots only |
| Tent canvas, crates, sledge | oiled canvas `#8A7E68`, wood `#6A5440` | `#5A5040`, `#42342A` | |
| Rope | hemp `#A08A68` | `#6A5A44` | |
| **Accent: aurora** | aurora green `#5CE0A0` core, fading to `#2A8A70` | | the one saturated colour, in the sky only, plus faint green glints in the clearest ice edges |
| Sky (night, hero) | deep indigo `#0E1428` top, slate blue `#2A3450` horizon | | contrasts the snow by 50+ L\* |

**Value plan (L\*):**
| Plane | What | Value |
|---|---|---|
| Near (0–40 m) | snow floor, boulders, spire feet | **L\* 70–88** by day, **55–68** at night (moonlit) |
| Mid (40–250 m) | slate cliffs, spire bodies, shelves | **L\* 25–40** (slate), shelves 50–60 |
| Far (250 m+) | summits (snow-capped), sky | summits 55–70 in fog; sky **L\* 8–25** at night, 55–70 by day |

Day flips the sky (mid-blue, darker than the snow); night is the hero: **snow glows, rock is dark, sky is darkest**.

**Readability rules (the fighters must always win):**
1. **Value split:** every fighter's main mass (Vexa 10, Lyra 16, Kael ~38, Brann 36–45) is far darker than the snow; they read dark-on-light from the gameplay camera, which mostly frames the valley floor. In flight against slate cliffs, their light elements (Vexa's jacket 59, Lyra's parchment 75, Kael's silver hair, Brann's moss and beard) and the rim take over.
2. **Cerulean and teal guard:** ice stays at ≤ 20% saturation and grey-cyan (~200°), never Lyra's cerulean; no teal surfaces near Kael's coat value. Snow shadows lean blue but at ≤ 15% saturation.
3. **Accent in the sky:** the aurora sits high (above 250 m) and moves slowly; it's never behind fighters at the gameplay camera's usual pitch, and never brighter than L\* 70. Its green (~150°) stays far from every legend's hue and from the team colours' green (≈120°) by brightness and position: team rims live on fighters, the aurora lives in the sky.
4. **Saturation ceiling:** nothing on the ground exceeds ~30% saturation. Gear stays muted (no orange tents: that's Kael's scarf; no gold: the item family).
5. **Busy-ness falls off:** frost sparkle ≤ 1 per 4 m² and never animated near the camera; snowfall flakes small (2–3 cm) and sparse near the camera; the storm's visibility drop happens in the far plane, not in front of the fighters.

## Lighting and time of day
`frozen_peaks.tres` presets, with the miniature stack on top:

| Preset | Sun | Ambient | Rim | Look |
|---|---|---|---|---|
| Day | cold white, low (0.92, 37° up) | blue-grey | warm, 0.2 | crisp morning: warm-lit snow faces, blue shadows, deep blue sky |
| Dusk | pink-gold (0.68) | mauve | warm, 0.3 | alpenglow on the summits; kept secondary so it doesn't copy Heartbloom's pink |
| **Night** (hero, *aurora night*) | moonlight, cool (0.32) | deep blue | cool, 0.45 | moonlit snow, dark slate, indigo sky, green aurora over the Ice Crown |

- **Preset notes for the voxel pass:** keep `exposures` (0.9 / 0.95 / 1.0) so snow stays off clipping. Raise the night rim to 0.6 so Vexa's and Lyra's dark masses separate from the dark slate when they fly against it. The dusk fog (0.85, 0.70, 0.75) leans pink like Heartbloom's; shift it to a colder lilac-grey `#B8B0C0` so the two zones never share a dusk.
- **Stack:** baked per-vertex AO (under shelves, at boulder and spire feet, in crevasses, between strata) on every tier; one directional shadow (soft); fill from the sky (blue); the voxel edge highlight; the zone's rim on fighters.
- **Aurora light:** a faint green term in the night ambient (≤ 10%) on up-facing snow, so the aurora feels present without tinting fighters.
- **Camp lantern:** one dim warm lantern in the standing tent (emissive only, no light).

## Atmosphere and sky
- **Sky:** deep indigo zenith, slate-blue horizon at night with a dense star field (1-pixel stars, a few brighter), the aurora as 2–3 slowly folding ribbons of voxel-stepped light anchored over the Ice Crown. By day, a deep blue (`sky_top` 0.4, 0.55, 0.8) clearly darker than the snow.
- **Haze:** cold blue-white fog thickening with distance; far ranges as three layered silhouettes. Spindrift plumes blow off ridges (T3 puffs, see-through).
- **Snowstorm** (the `snow` weather, the visibility drop from GAME_DESIGN §7.2): fog density rises and the far plane whites out; flakes thicken in the mid plane; near the camera they stay sparse so the fight reads.

## Motion
| Element | Motion | Rule |
|---|---|---|
| Aurora | slow folding ribbons, 20–40 s cycles, gentle brightness pulse | voxel-stepped edges; never flashes |
| Snowfall | slow drifting flakes; gusts every ~12 s push them sideways | rigid 2–3 cm flecks; sparse within 4 m of the camera |
| Spindrift | plumes off ridges and cornices | see-through T3 puffs |
| Pennant | stiff flap, ±4° at 0.5 Hz | rigid block |
| Tent flap | slow sway | rigid |
| Frost sparkle | static glints that catch the view angle (shader) | no blinking |
| Breakables | ice spires shatter into faceted shards; shelves drop as avalanche slabs (existing destructibles) | shards are T1 ice cells; slabs break along strata lines |

## Performance (GTX 1650 at 1080p60, plus the web build)
- Budget: world ≤ **3 ms GPU p95 at medium** on this zone with the render benchmark. Web: 60 fps in Chrome on the same PC.
- **Chunk meshing** per tier with the per-chunk colour texture; the mountain walls are the largest mesh, so they're T2/T3 except the first 6 m above the valley floor.
- **Instancing:** spires (6 variants, clustered), shelves (4), boulders (6: ice and slate), cairns (3), crates (2) as MultiMesh with per-instance tint. The camp, the sledge, the frozen waterfall and the rope bridge are unique meshes.
- **Ice:** no refraction or transparency in the base pass; depth is painted (darker voxels inside), with a cheap fresnel edge highlight. Transparent ice only on the spire edge band if the budget allows, never on web.
- **Sky:** aurora as a sky-shader term (no geometry, no particles).
- **Particles:** snowfall and spindrift as GPUParticles3D; halve on web; the storm is mostly fog.
- **LOD:** T0 fades past 40 m; spires to T2 past 80 m, impostors past 250 m; summits always T3.
- Targets: ≤ 1.2 M visible triangles, ≤ 250 draw calls desktop; ≤ 500 k and ≤ 120 web. Paste the benchmark before and after.

## Deliverables (to `lookdev-frozen-peaks-v1`)
- **Hero shots** at 1920×1080: the valley under the aurora with the Ice Crown (the key image), the expedition camp, an ice spire cluster close up, the Shelf Cliffs with icicle fringes, a snowstorm rolling in, a wide overview; the key image and the overview at all three times of day. Contact sheet.
- **`frozen_peaks_flythrough_v1.mp4`:** 60 s at 1080p60: low along the valley's S-curve through a spire cluster, past the camp, up the Shelf Cliffs over the shelves, a climb to circle the Ice Crown under the aurora (pattern of `world_flythrough.gd`).
- **Kael for scale:** voxel Kael by the camp, under an ice shelf and beside a spire cluster, plus gameplay-camera shots of Kael on the valley floor at each time of day.
- **Readability strip:** all four legends over snow, slate and the night sky; **Vexa and Lyra against slate at night** as their own row.
- Render benchmark output before and after.

## Acceptance (self-check first; the owner decides)
- From the gameplay camera at the spawns, a viewer lists at least 10 distinct zone parts.
- Snow, slate and sky sit in three separate value bands in every hero shot; ice never reads as cerulean.
- Every legend reads against snow and against slate at every time of day.
- AO visible under shelves, at spire feet and in crevasses. No smooth-shaded or raw primitive props.
- Feet on the visible snow (QA foot check passes).
- Within the GPU budget; the web build holds its target.

## Build notes (for the coder)
| Part | Build | Kit or zone |
|---|---|---|
| Valley floor, snowfields, mountains | terrain columns from the baked heightmap; T1 floor, T2/T3 walls; material by slope (snow on ledges < 35°, slate above) and by terrace band (strata lines on the 22 m steps) | **shared kit:** terrain columns, chunk meshing, baked AO, slope/band material rule; **zone:** snow-on-ledge thresholds, sastrugi relief |
| Glacier and crevasses | a painted ice band along the valley line with carved crevasse channels (CARVE) | **zone-specific** |
| Ice spires and shelves | faceted prism and stratified slab builders in `VoxelGrid`, instanced with `FrozenPeaksProps` transforms | **shared kit:** instanced props; **zone:** spire/shelf builders, icicle fringe |
| Boulders, cairns, crates | small `VoxelDesign` builds with snow caps (a "cap" pass: top-facing cells painted snow) | **shared kit:** instanced props, snow/moss/ash cap pass (also used by Verdant moss and Ember ash) |
| Camp, sledge, frozen waterfall, rope bridge | unique zone builds, planar | **zone-specific** |
| Aurora, stars | sky shader terms | **zone-specific** (in the shared sky shader as a per-zone uniform) |
| Snow, spindrift | particles and T3 puffs | **shared kit:** puff clouds |
| Placement | keep `FrozenPeaksProps` positions and the 4242 seed; camp and cairns at authored spots outside the 15 m valley lane | |
| Code home | look-dev in `game/lookdev/` plus a zone variant folder; the existing world code stays untouched until the owner approves | |
