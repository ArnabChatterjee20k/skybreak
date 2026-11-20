# Look-dev: Verdant Falls (zone design sheet v1)

**Goal:** Verdant Falls in the approved voxel style, at the characters' voxel density and with their lighting stack (`docs/lookdev/kael.md`, `.claude/skills/voxel-character-lookdev/SKILL.md`, template `docs/lookdev/heartbloom.md`). Same loop as a character: this sheet, then a build, then a stage, then the owner's three gates. Look before function: the terrain (`TerrainShape._verdant`), zone data (`verdant_falls.tres`), the lake plane (`world_map.gd`, y 0) and the props layout (`VerdantFallsProps`, `PropKit` seed 4242) stay the truth; this is a visual pass over them.

## Identity and mood
**A jungle valley at sunrise:** a white waterfall thundering off a mossy basalt cliff into a still mirror lake, giant trees with buttress roots and layered canopies, mist hanging in shafts of early light, an overgrown shrine half swallowed by roots. Lush, fresh, alive; mixed cover and big natural scale. Read at a glance: *a huge white waterfall, a mirror lake, giant trees, mist and sunbeams.*

Mood comes with its image: the tank's diorama craft, lit like a miniature terrarium in morning sun. Music *Canopy Run* (144 bpm) and the `amb_verdant_falls` bed (water roar, birds, insects): rushing water and a chase through trees.

**Lesson applied:** the grey-block is mid-green everywhere (ground 0.5–0.64 green, canopies 0.3–0.62 green, fog mint) with a brown trunk: one hue, one value. The voxel pass gives Verdant **three greens at three values** (dark canopy undersides, mid moss, light sunlit leaf tops), a **dark wet basalt** cliff, **white water and pale mist** as the brightest values, and a **warm pale morning sky**.

## Layout at gameplay scale
From `TerrainShape._verdant`, `verdant_falls.tres` and `VerdantFallsProps` (zone centre (−640, 470), extent 330 × 460, arena box ±300 m, ceiling 380 m):

| Part | Shape (local to the centre) | Role in a fight |
|---|---|---|
| **Mirror Lake** | an elliptical basin centred at local (0, −20), floor −12 m, water at 0; ~260–380 m across east–west and ~190–280 m north–south; landmark (−640, 0, 450) | open, flat mid-ground over water: beams and ki duels |
| **Valley floor** | 7 ± 6 m around the lake | the main stage; spawns at (−660/−620, 620), local (∓20, 150), on the south shore |
| **North cliff** | at lz ≈ −150 (± 15), a 16 m wide edge rising to a **plateau** at 118 ± 8 m | wall-splat surface; the waterfall wall |
| **The river** | a 9 m groove on the plateau winding to the cliff lip at lx ≈ 0 | feeds the falls |
| **Great Falls** | a 60 m wide curtain from the lip to the lake (72 m wide at the bottom), spray puffs at its foot; landmark (−660, 118, 290) | the hero landmark; the curtain is destructible and its spray hides fighters briefly |
| **Giant trees** | 40 giants, trunk r 4.5–8 m, 50–120 m tall, two canopy layers 36–88 m wide; **Giant Grove** landmark (−520, 40, 650) south-east | cover, vertical play, snap-able trunks |
| Small trees | 110 trees, r 1.5–3 m | low cover |

- **Fighting space:** open air over the lake; dense trunks and canopies south and east; a 110 m wall north. Keep a **25 m clear ring** around the spawns and the lake surface clear of new props.
- **Verticality:** lake 0, floor ~7, canopies 40–110 m, plateau 118 m, ceiling 380 m. Flying under the canopy layer (15–40 m) is the "jungle run"; above it, the open sky.
- **Landmarks are navigation:** the falls (a white vertical sheet, always visible), the lake (a mirror), the Giant Grove (the tallest crowns). Shapes: sheet, disc, crowns.

## Detail at three scales
| Scale | Parts |
|---|---|
| **Big forms** | The north cliff as **stacked basalt columns and ledges** (dark, wet, moss on every ledge); the plateau's edge with a lip of boulders where the river pours over; the lake as a flat mirror with a shallow shelf (sandy, lighter) along the shore; the valley floor terraced in soft T1 steps; giant trees (buttress roots, trunk, limbs, canopy layers as clustered leaf masses); the falls; mist banks |
| **Medium parts** | Buttress roots (planar fins, 3–5 per giant); hanging lianas and vines; ferns (fronds as stepped blades, 4 variants); giant leaves (elephant-ear plants); fallen logs with shelf fungus; mossy boulders; stepping stones across a stream; the **overgrown shrine** (a stone platform, two guardian statues, a stair, roots growing through); a rope-plank **canopy walkway** between two giants; a stone **water channel** with a broken sluice; reeds and lily pads at the shore; rocks in the falls' plunge pool |
| **Tiny details** | Moss on the north and top faces of everything (cap pass); dew drops (rare glints on leaves); leaf litter on the floor; **orchids** on trunks and cliff ledges (the accent); mushrooms in clusters; bark furrows; root tips; frog on a lily pad; butterflies; water droplets and foam lines at the falls' foot; wet-dark rock near water; spider webs between ferns catching the light |

**Storytelling details (at least 5):**
1. The **overgrown shrine**: two guardian statues (original, a frog-like and a heron-like figure), one toppled into the lake shallows; fresh orchids laid on the altar.
2. A **canopy walkway** between two giants, a few planks missing, a lantern hook with no lantern.
3. A **broken sluice** in the stone channel: someone once diverted the river for the shrine's basin; it now spills over the edge in a little second fall.
4. A **fallen giant** across a stream, its root plate standing up like a wall, the trunk hollowed and carpeted in moss (the "snapped trunk" destructible's after state).
5. **Stepping stones** to a tiny island in the lake with a single flat stone and a cairn on it.
6. **Carved height marks** on a giant's trunk, from knee height up to above a fighter's head, the highest one fresh.

**Zone emblem (original): the Falling Leaf.** A single leaf whose central vein becomes a falling-water line, inside a broken circle. Carved on the shrine's altar and the sluice gate.

## Voxel density (the characters' relationship, scaled)
| Tier | Cell | Used for | Note |
|---|---|---|---|
| T0 | 2.2 cm | ≤ 1 m: orchids, mushrooms, frog, dew, webs, height marks, lily pads, butterflies, liana tips | same pixel scale as a fighter |
| T1 | 8.8 cm | 1–15 m: ferns, giant leaves, buttress roots, trunk bases (lower 12 m), logs, boulders, the shrine and statues, the walkway, the sluice, stepping stones, reeds; **the walkable floor and shore** (top 1 m shell) | what fighters stand on and fight against |
| T2 | 35 cm | trunks above 12 m, limbs, canopy masses, the lower cliff | never at a fighter's feet |
| T3 | 1.4 m | the upper cliff and plateau seen from below, far canopies, mist puffs | far or in haze |

- **Feet rule:** floor and shore at T1; the visible top stays within ±4.4 cm of the `ZoneGround` floor. The lake is a plane at 0 with the shallow shelf as T1 cells under it.
- **Colour noise:** ±2–3% on rock and water banks, up to ±6% on leaves, moss, bark and orchids. Darker under canopies, in root crevices and in the cliff's column joints; lighter on sunlit leaf tops, moss crowns and foam.
- **Design in blocks:** canopies are **clusters of flat-topped leaf masses** (stepped layers, like terraced shelves), not round spheres; trunks are faceted (8 sides at T2), roots are planar fins, the cliff is columns.

## Palette and value plan (three greens, dark rock, white water)
| Material | Base | Shadow | Notes |
|---|---|---|---|
| Canopy, sunlit tops | fresh leaf `#7AA850` | `#4A6E34` | the light green |
| Canopy, undersides | deep jungle `#2E4A2C` | `#1A2C1C` | the dark green, frames the floor |
| Moss (floor, ledges, caps) | moss `#6E9048` | `#3A5228` | the mid green; lighter and yellower than Brann's olive moss `#5E7A42`, so he never melts into the floor |
| Ferns, understory | blue-green `#4E7A54` | `#30503A` | cool counterpoint |
| Bark | grey-brown `#5A4C40` | `#382E26` | lighter grey on buttress ridges `#7A6C5E` |
| Basalt cliff (wet) | dark slate-green `#3A4040` | `#1E2424` | |
| Shore sand, shelf | pale khaki `#B8AC88` | `#7E7458` | the light floor near the lake |
| Shrine stone | weathered grey `#8A8A7E` | `#5A5A50` | moss-capped |
| Water (lake) | reflective, dark teal-green `#2A4A48` base | | mirrors sky and falls |
| Falls, foam, spray | white `#F0F4F2` | `#A8B8B8` | the brightest values in the zone |
| **Accent: orchids** | orchid pink-magenta `#E05AC8` | `#9A3A88` | the one saturated colour; small clusters on trunks and ledges above head height |
| Sky (morning, hero) | warm pale `#E8E0C8` near the sun, soft blue `#8AB0D8` above | | lighter than the canopy |

**Value plan (L\*):**
| Plane | What | Value |
|---|---|---|
| Near (0–40 m) | floor moss, shore sand, ferns, roots | **L\* 40–60** (moss 45–55, sand 70), sunbeam pools to 75 |
| Mid (40–250 m) | trunks and canopy undersides | **L\* 15–30** (the dark frame) |
| Far (250 m+) | the falls, mist, sky | **L\* 80–95** (white water and sunlit mist), the cliff a dark band 20–30 beside the falls |

The frame is **dark green around a mid-value floor, with white water and mist as the light behind**.

**Readability rules (the fighters must always win):**
1. **Value split:** fighters' main masses (≤ L\* 45) read against the light falls, mist and lake reflections when framed toward the north, and against the mid moss floor from above. In the dark mid-ground under canopies, light elements and the rim carry them; raise the day rim from 0.3 to 0.45 here.
2. **Brann's moss:** his shoulder moss (`#5E7A42`, olive) sits right in this zone's greens. Rules: floor moss near the spawns is **lighter and yellower** (`#6E9048`, L\* ~55) than his; his granite and red beard carry him. Check him first in the strip.
3. **Kael's teal:** fern blue-greens stay ≤ 30% saturation and darker than his coat; no teal-saturated water (the lake mirrors, it isn't turquoise).
4. **Orchid guard (Vexa):** orchid magenta-pink (~310°) is 40° from Vexa's violet and much lighter (L\* ~60 vs her accent ~40); orchids are tiny and never at fighter height near the spawns.
5. **Hue exclusions:** no cerulean (the sky is soft and pale), no saturated gold (items): sunbeams are warm white, not yellow.
6. **Saturation ceiling:** besides orchids, nothing exceeds ~45%; leaf greens ≤ 45%.
7. **Busy-ness falls off:** ferns and leaf litter thin out in the 25 m spawn ring; floating pollen and butterflies sparse near the camera.

## Lighting and time of day
`verdant_falls.tres` presets, with the miniature stack on top:

| Preset | Sun | Ambient | Rim | Look |
|---|---|---|---|---|
| **Day** (hero, *sunrise mist*) | warm white, from the east (1.0); for the key image, tilt to ~25° up | soft green-grey | warm, 0.3 → **0.45** | god-rays through mist and canopy gaps, the falls lit white, dew glints |
| Dusk | warm orange (0.76) | warm rose | warm, 0.45 | the falls turn gold-pink, the canopy goes dark; secondary (close to Skyhold's hour) |
| Night | cool moon (0.28) | deep teal-blue | cool, 0.55 | fireflies over the lake, moonlit falls, glowing fungus on logs (pale green, low) |

- **Preset notes for the voxel pass:** day fog (0.70, 0.85, 0.80) is mint, the same hue as the foliage; make it a warm pale `#E4E4D8` so mist reads as light, not green. The day ambient (0.52, 0.62, 0.55) stays green-tinted but at lower saturation.
- **Stack:** baked per-vertex AO (root crevices, under canopies, between ferns, cliff joints, under logs) on every tier; one directional shadow with **canopy shadow dapples** (cheap: a projected canopy shadow texture rather than casting every leaf mass); fill from the sky; the voxel edge highlight; the zone's rim on fighters.
- **God-rays:** view-space light shafts through mist from the sun direction (desktop only), plus static mist-shaft meshes (see-through cards of voxel-stepped light) in canopy gaps as the web fallback.

## Atmosphere and sky
- **Sky:** warm pale near the sun, soft blue above; low clouds over the plateau.
- **Mist:** low mist banks over the lake and in the valley (height fog 0–20 m, densest at dawn), spray clouds at the falls' foot (T3 puffs), mist shafts in sunbeams.
- **Haze:** warm, light; far canopies step back in three planes.
- **Rainbow:** a faint arc in the falls' spray when the sun is behind the camera (sky shader term, very low saturation).

## Motion
| Element | Motion | Rule |
|---|---|---|
| Waterfall | falling water bands (scrolling voxel-stepped streaks), foam at the foot | the existing waterfall shader with a stepped cell pattern |
| Spray | rising puffs at the foot, drifting | T3 puffs, see-through |
| Lake | still mirror; ripples near the falls and around lily pads | |
| Canopies | slow rigid sway of each leaf mass (±3 cm) | clusters move whole |
| Lianas | gentle swing | rigid segments |
| Butterflies, birds | flutter near flowers; birds flying across the falls | sparse |
| Fireflies (night) | slow wander over the lake | emissive particles |
| Breakables | giant trunks snap at the base and fall; the waterfall curtain parts (existing destructibles) | the trunk splits along T2 cells with a pale inner wood |

## Performance (GTX 1650 at 1080p60, plus the web build)
- Budget: world ≤ **3 ms GPU p95 at medium** on this zone with the render benchmark. Web: 60 fps in Chrome on the same PC.
- **Foliage is the risk:** 150 trees with big canopies; canopy masses are instanced leaf-mass variants (6), not unique; ferns and understory as instanced clumps with distance fade.
- **Chunk meshing** per tier for the floor, shore and cliff; trunks are instanced (4 giant variants, 3 small) and scaled.
- **Water:** the existing lake plane with a reflection term (sky and falls via a reflection probe; no SSR); the falls stay one shader quad with stepped bands.
- **Shadows:** canopy dapple as a projected texture; only trunks and big props cast real shadows.
- **Particles:** spray, mist, butterflies and fireflies as GPUParticles3D; halve on web; god-rays off on web (mist cards instead).
- **LOD:** T0 fades past 40 m; trees to T2 past 80 m, impostors past 250 m.
- Targets: ≤ 1.2 M visible triangles, ≤ 250 draw calls desktop; ≤ 500 k and ≤ 120 web. Paste the benchmark before and after.

## Deliverables (to `lookdev-verdant-falls-v1`)
- **Hero shots** at 1920×1080: the Great Falls at sunrise across the mirror lake (the key image), the overgrown shrine, the canopy walkway in the Giant Grove, god-rays on the valley floor, the fallen giant, a wide overview; the key image and the overview at all three times of day. Contact sheet.
- **`verdant_falls_flythrough_v1.mp4`:** 60 s at 1080p60: low over the mirror lake toward the falls, up the curtain to the lip, along the plateau river, a dive back down through the spray, a jungle run under the canopy through the Giant Grove past the walkway and the shrine (pattern of `world_flythrough.gd`).
- **Kael for scale:** voxel Kael at a giant's buttress roots, on the shrine's stair and on the shore with the falls behind, plus gameplay-camera shots of Kael on the moss floor at each time of day.
- **Readability strip:** all four legends over moss, canopy shadow, the falls and the lake; **Brann on moss** and **Kael against ferns** as their own rows.
- Render benchmark output before and after.

## Acceptance (self-check first; the owner decides)
- From the gameplay camera at the spawns, a viewer lists at least 10 distinct zone parts.
- At least three distinct green values in every hero shot; the falls and mist are the lightest values; no "cotton-ball" trees (canopies read as stepped leaf masses).
- Every legend reads on the floor, against the falls and under the canopy; Brann never melts into moss.
- AO visible at roots, under canopies and in the cliff. No smooth-shaded or raw primitive props.
- Feet on the visible ground (QA foot check passes), shore included.
- Within the GPU budget; the web build holds its target.

## Build notes (for the coder)
| Part | Build | Kit or zone |
|---|---|---|
| Floor, shore, cliff, plateau | terrain columns from the baked heightmap; T1 floor/shore, T2/T3 cliff with a basalt column pattern on steep faces (shared with Ember's inner wall), moss cap pass on ledges | **shared kit:** terrain columns, chunk meshing, baked AO, column pattern, cap pass |
| Giant and small trees | a tree builder: faceted trunk, planar buttress fins, limbs as tapered chains, **canopy as stepped flat-topped leaf masses** (no spheres); instanced with `VerdantFallsProps` transforms | **shared kit:** instanced props, tree builder (Heartbloom's blossom trees use the same builder with a blossom canopy); **zone:** buttress and leaf-mass variants |
| Ferns, giant leaves, reeds, lily pads, orchids, mushrooms | small `VoxelDesign` builds, instanced clumps with fade | **shared kit:** instanced props |
| Falls, lake | existing waterfall shader with stepped bands; lake plane with reflection probe; foam ring at the foot | **zone-specific** |
| Shrine, walkway, sluice, fallen giant, stepping stones | unique zone builds | **zone-specific** |
| Mist, spray, god-rays | T3 puffs, height fog, mist cards, light shafts | **shared kit:** puff clouds; **zone:** god-ray setup |
| Placement | keep `VerdantFallsProps` trees and falls positions and the 4242 seed; storytelling props at authored spots outside the spawn ring | |
| Code home | look-dev in `game/lookdev/` plus a zone variant folder; the existing world code stays untouched until the owner approves | |

## v1 build (look-dev lane `lookdev/zone-verdant_falls`)
- **Code:** `game/world/zones_voxel/verdant_falls/` (`VerdantFallsVoxel` on the shared kit, plus the water, falls, mist and god-ray shaders). The shared kit is unchanged. Tests: `tests/world/test_verdant_falls_voxel.gd`.
- **Sim truth:** the floor is a smooth top on `TerrainHeightmap.ground_height_at` (the same samples `ZoneGround` bakes; the test checks within 4.4 cm). Trees, canopies, the falls curtain and its spray come from `VerdantFallsProps` run as a zone match runs it (`PropKit` seed 4242, every ground zone's spawns kept clear). The lake is the plane at y 0. No sim or gameplay files changed.
- **Tiers:** T1 floor and shore around the spawns (195 × 150 m), T2 valley, T3 the rest of the box; coarser tiers run 5–20 cm under the finer ones so seams never open. Cliff face: 1.4 m basalt prisms of T2 cells, standing proud by up to 4.5 m; plateau at T3; backdrop hills at 4 × T3.
- **Story props:** overgrown shrine (frog guardian, empty heron plinth, Falling Leaf altar, fresh orchids, roots through the blocks) and the toppled heron in the shallows; canopy walkway (two planks missing, empty lantern hook); broken sluice (Falling Leaf on the lintel, spill at the broken end); fallen giant (root plate, hollow heartwood end); stepping stones to an islet with a cairn; carved height marks on the giant nearest the shrine (highest one fresh).
- **Report:** `reports/lookdev/verdant_falls/README.md`.
