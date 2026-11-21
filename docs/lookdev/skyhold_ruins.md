# Look-dev: Skyhold Ruins (zone design sheet v1)

**Goal:** Skyhold Ruins in the approved voxel style, at the characters' voxel density and with their lighting stack (`docs/lookdev/kael.md`, `.claude/skills/voxel-character-lookdev/SKILL.md`, template `docs/lookdev/heartbloom.md`). Same loop as a character: this sheet, then a build, then a stage, then the owner's three gates. Look before function: the terrain (`TerrainShape._skyhold`, `SKY_FANGS`), zone data (`skyhold_ruins.tres`), the cloud-sea plane (`world_map.gd`, y 40) and the props layout (`SkyholdRuinsProps`, `PropKit` seed 4242) stay the truth; this is a visual pass over them.

## Identity and mood
**A shattered sky-temple city at golden hour:** dozens of broken stone islands hang over a white cloud sea, each carrying the paved floor and colonnade of an old temple district; bronze statues gone green, honey-coloured stone lit low and warm, a deep blue sky above. Ancient, grand, a little melancholy; the fights are fast and close among walls and gaps. Read at a glance: *broken marble islands, ruined colonnades and arches, verdigris bronze, a white cloud sea, rock fangs.*

Mood comes with its image: the tank's diorama craft, lit like a museum model of a ruin at the end of the afternoon. Music *Islands of Gold* (168 bpm, the fastest theme) and the `amb_skyhold_ruins` bed (high wind, distant bells): speed and altitude.

**Not Heartbloom.** Both zones float, so the difference is designed in: Skyhold's islands are **angular fractured slabs with paved tops** (not domed lawns), the palette is **ivory, honey and blue** (not pink and green), the time is **golden hour with the sun still up** (not sunset), the gaps are **tight (14–40 m)** (not 30 m+ open air), and the mood is **ruin and grandeur** (not a tended garden).

**Lesson applied:** the grey-block uses warm cream for stone, marble, fog and the horizon alike (fog 0.92, 0.76, 0.52 matches the horizon and the stone). The voxel pass keeps the **stone warm and light**, puts a **cool blue sky** behind it, makes the **undersides dark**, and lets the **cloud sea be the brightest thing** below.

## Layout at gameplay scale
From `TerrainShape._skyhold`, `skyhold_ruins.tres` and `SkyholdRuinsProps` (zone centre (40, −600), extent 330 × 420, arena box ±300 m, ceiling 380 m):

| Part | Shape | Role in a fight |
|---|---|---|
| **Crown Island** | r 55 m, top 190 m, landmark (60, 190, −780) north; the largest island with a full ring colonnade and the **Crown Gate** arch | the signature landmark: the old temple's sanctum |
| **Watch Island** | r 55 m, top 150 m, landmark (−130, 150, −460) south-west; a watchtower stump | the second big landing |
| **Island field** | up to 32 more islands, r 12–42 m, tops 80–230 m, at least 14 m apart sideways unless stacked well apart vertically; inverted-cone bodies 1.2–1.7 r deep; a ring of columns at 0.72 r (one per 5 m of radius, 16 m tall or broken to 4–10 m); an 18 × 20 m arch on every island over r 26 | rushdown territory: tight gaps, walls everywhere, many corners |
| **Fang Rocks** | 4 rock fangs from the basin floor, r 22–30 m, 100–135 m tall; landmark (−120, 120, −640) | pierce the cloud sea; vertical walls to fight around |
| **Cloud sea** | a plane at 40 m over a basin at −18 ± 9 m | the soft floor; the ground beneath is never seen |
| Spawns | (20/60, 150, −560) | in the air amid the island field |

- **Sim caveat (not a look-dev fix):** the floating stones are props only (T-106 in `TODO.md`), so fighters hover over the basin terrain and pass through islands. The art pass is built so that, once islands get a sim floor (an `IslandField` entry per island, like Heartbloom), the **paved top at T1 is the floor**; until then, keep tops flat and clear so nothing changes when it lands.
- **Fighting space:** gaps of 14–40 m make Skyhold the tightest zone; keep columns and arches on rims and island centres, and **never bridge a gap** with new geometry.
- **Verticality:** cloud sea 40 m, fangs to 135 m, island tops 80–230 m, ceiling 380 m; island undersides hang up to 70 m below their tops.
- **Landmarks are navigation:** the Crown Gate (a tall arch on the biggest island), the Watch stump (a broken tower), the Fang Rocks (dark spikes out of the clouds). Shapes: gate, stump, spikes.

## Detail at three scales
| Scale | Parts |
|---|---|
| **Big forms** | Island tops as **paved plazas** of large flagstones with the outline broken into fractured straight edges (a polygon, not a circle: cut along 5–8 chord lines); undersides as stacked, fractured rock strata stepping inward, with hanging roots and broken foundations; the Crown Gate (a monumental arch of laid blocks); the Watch tower stump; the Fang Rocks as dark weathered spikes; the cloud sea |
| **Medium parts** | Colonnades (fluted columns with base, shaft drums and capital; broken ones show the drum joints and a jagged top; a fallen column across a plaza); lintels and entablature fragments; small arches; stairs that end in the air at a broken rim; **verdigris bronze statues** (a robed figure with a raised arm, a winged lion, both original, 3–5 m); bronze braziers on tripods; terraced garden beds gone wild; collapsed walls with window openings; hanging chains between columns; altar blocks |
| **Tiny details** | Flagstone joints with moss lines; chipped column flutes; inscriptions (original glyph bands) on lintels; bronze patina streaks running down stone below statues; cracks and missing paving cells; ivy tendrils on columns (T0); wildflowers in cracks (white and pale yellow); bird nests on capitals; chain links; worn steps (dished centres); offering bowls; small loose rubble cells |

**Storytelling details (at least 5):**
1. A **fallen bronze statue** lying face-down across a plaza on Watch Island, its raised arm snapped off and lying at the rim.
2. **Stairs to nowhere:** a grand stair on Crown Island ending at a fractured edge, its top three steps hanging over the cloud sea.
3. **Hanging chains** between two columns on adjacent islands, snapped in the middle, the ends dangling over the gap (shows the islands were once joined).
4. A **lit brazier**: on one small island, one bronze brazier still burns faintly (someone still tends this place).
5. **Bird nests** on broken capitals, with a few feathers on the plaza below.
6. A **sundial plaza** on one island with its gnomon pointing at the Crown Gate.

**Zone emblem (original): the Winged Keystone.** A trapezoid keystone with two short swept wings. Carved on the Crown Gate's keystone and on altar blocks; cast on the statues' plinths.

## Voxel density (the characters' relationship, scaled)
| Tier | Cell | Used for | Note |
|---|---|---|---|
| T0 | 2.2 cm | ≤ 1 m: ivy, wildflowers, chain links, inscriptions, offering bowls, feathers, nests, small rubble | same pixel scale as a fighter |
| T1 | 8.8 cm | 1–15 m: columns, capitals, statues, braziers, stairs, altars, walls, small arches, rim fractures; **the walkable paved top** (top 1 m shell) | what fighters stand on and fight against |
| T2 | 35 cm | upper undersides, the Crown Gate core, large arches' cores, the Watch stump | never at a fighter's feet |
| T3 | 1.4 m | deep undersides, Fang Rocks above the clouds, far islands, cloud puffs | far or in haze |

- **Feet rule:** paved tops at T1 so they're ready as a sim floor (see the caveat); when islands get a floor, the visible top must be within ±4.4 cm of it.
- **Colour noise:** ±2–3% on flagstones and marble, up to ±6% on rough rock, bronze and moss. Darker in joints, under capitals, inside arches and down the underside strata; lighter on worn steps, column edges and the sunward rim.
- **Design in blocks:** islands are fractured slabs (planar breaks), columns are stacked drums with flutes as 1-cell grooves, arches are laid voussoirs; never a smooth cylinder or cone.

## Palette and value plan (warm light stone, dark undersides, blue sky, white clouds)
| Material | Base | Shadow | Notes |
|---|---|---|---|
| Paving, temple stone | honey limestone `#D4BE96` | `#9A8466` | sat ≤ 35% |
| Marble (columns, gate, statues' plinths) | ivory `#E6DCC8` | `#A89C88` | lightest stone |
| Underside rock | warm umber-grey `#6A5A4E` | `#3E342E` | dark, so islands read as floating masses |
| Fang Rocks | cool dark grey `#4E5058` | `#2E3036` | |
| Moss, wild garden | olive-sage `#7A8A58` | `#4E5A38` | in joints and beds only |
| Ivy | deep green `#4E6A3E` | `#30442A` | T0 tendrils |
| Wildflowers | white `#ECE8DC`, pale butter `#E4D89A` | | tiny |
| Chains, bronze shadows | dark bronze `#5A4A34` | `#362C20` | |
| **Accent: verdigris** | verdigris `#4AB49A` | `#2A7466` | the one saturated colour: bronze statues, braziers, patina streaks |
| Brazier flame | soft amber, low emission | | one only |
| Cloud sea | warm white `#F4EEE4` lit, `#B8B4C4` shade | | the brightest surface below |
| Sky (day, hero) | deep blue `#3058B0` top, pale warm `#E8D8B8` horizon | | the stone's cool complement |

**Value plan (L\*):**
| Plane | What | Value |
|---|---|---|
| Near (0–40 m) | paved tops, columns, rims | **L\* 68–82** (stone in sun), 45–55 in shade |
| Mid (40–250 m) | other islands: tops light, **undersides L\* 25–40** | the dark undersides frame the light tops |
| Far (250 m+) | cloud sea **L\* 85–92**, fangs 30–45 in haze, sky **L\* 40–55 high**, 80+ at the horizon | |

Islands read as **light lid, dark body** over a **bright cloud floor**, under a **mid-dark blue sky**.

**Readability rules (the fighters must always win):**
1. **Value split:** fighters' main masses (≤ L\* 45) read dark against the paved tops and the cloud sea (most of what the camera sees behind them here, since fights are close and often look down). Against dark undersides, their light elements and the rim (day 0.15 is too low: raise to 0.35) separate them.
2. **Teal guard (Kael):** verdigris (~165°, light, saturated) sits near Kael's coat hue (~185°, mid, muted). Rules: verdigris appears **only** on bronze objects (statues, braziers, plinth rings, streaks), never on large surfaces, ≤ 3% of the screen; it's lighter and more saturated than his coat, so they read as different materials.
3. **Cerulean guard (Lyra):** the sky is saturated only above ~30° elevation; at the gameplay camera's usual pitch the sky band behind fighters is the pale warm horizon. Lyra's navy reads dark on it.
4. **Parchment vs ivory (Lyra):** her stole (L\* 75) and the marble (L\* 85) are close; her navy coat and hat carry her silhouette, so marble behind her is fine, but no parchment-coloured cloth props in the zone.
5. **Hue exclusions:** no violet, no saturated gold (items): the stone is honey at ≤ 35% saturation and the brazier flame is soft amber, low emission. "Islands of Gold" is a mood, not a material.
6. **Busy-ness falls off:** ivy and flowers thin out on plaza centres; floating dust and leaves sparse near the camera.

## Lighting and time of day
`skyhold_ruins.tres` presets, with the miniature stack on top:

| Preset | Sun | Ambient | Rim | Look |
|---|---|---|---|---|
| **Day** (hero, *golden hour*) | warm gold, low but up (1.0, ~34° up) | warm grey | warm, 0.15 → **0.35** | long raking light across paving, glowing column edges, blue sky, white clouds |
| Dusk | deep orange, very low (0.84) | warm rose | warm, 0.4 | the cloud sea turns orange; kept secondary, it's Heartbloom's hour |
| Night | cool moon (0.32) | blue | cool, 0.6 | moonlit marble, the one brazier, stars over the cloud sea |

- **Preset notes for the voxel pass:** day fog (0.92, 0.76, 0.52) and the day horizon (0.92, 0.76, 0.52) are the same colour as the stone; make the fog a lighter, cooler `#E4DCD0` and keep the horizon warm-pale, so distant islands go **lighter and cooler** instead of melting into the stone. Raise the day rim to 0.35.
- **Stack:** baked per-vertex AO (column bases, under capitals and lintels, inside arches, flagstone joints, under island rims) on every tier; one directional shadow (long at golden hour: columns cast striped shadows across plazas, the signature look); fill from the sky; **cloud-sea bounce** (a soft warm-white up-light on undersides near the clouds); the voxel edge highlight; the zone's rim on fighters.
- **Brazier:** emissive, one OmniLight at most, no shadow.

## Atmosphere and sky
- **Sky:** deep blue zenith to a pale warm horizon; a large soft sun disc low in the west; high thin cirrus.
- **Cloud sea:** the existing cloud-sea plane at 40 m, with T3 voxel puff clouds rising from it in slow towers around the fangs; distant islands sit in a light haze above it in three depth planes.
- **Haze:** light and cool; it lifts far islands' values so the near island always reads.
- **Birds:** small flocks wheeling around the Crown Gate.

## Motion
| Element | Motion | Rule |
|---|---|---|
| Cloud sea and puffs | slow drift and rising towers | rigid T3 puffs; deterministic time in QA shots (QA-10) |
| Islands | very slow bob (±0.3 m, 30–60 s period, phase hashed) | **view only and off until islands get a sim floor**; then only if the sim moves them too |
| Hanging chains | gentle swing | rigid links |
| Dust and leaves | drift across plazas | sparse |
| Birds | flocks circling | far only |
| Brazier | small flicker | emission only |
| Breakables | columns topple into drums, arches break into voussoirs, island chunks break off a rim and fall into the clouds (existing destructibles) | fragments are T1 stone with fracture faces darker |

## Performance (GTX 1650 at 1080p60, plus the web build)
- Budget: world ≤ **3 ms GPU p95 at medium** on this zone with the render benchmark. Web: 60 fps in Chrome on the same PC.
- **Many small islands:** each island is a few chunks; frustum-cull per chunk; undersides are T2/T3 except 3 m under the rim.
- **Instancing:** columns (5 variants: whole, three broken heights, fallen), capitals (2), arches (2), statues (2), braziers (1), rubble (6), ivy clumps (4) as MultiMesh with per-instance tint. Island bodies are unique meshes but built from one fractured-slab builder; the Crown Gate and the Watch stump are unique.
- **Clouds:** one cloud-sea plane plus instanced T3 puffs; no volumetrics.
- **Shadows:** one directional; long golden-hour shadows widen the cascade, so keep `shadow_max_distance` tight (the fights are close here).
- **LOD:** T0 fades past 40 m; columns to T2 past 80 m, impostors past 250 m; far islands as T3 silhouettes.
- Targets: ≤ 1.2 M visible triangles, ≤ 250 draw calls desktop; ≤ 500 k and ≤ 120 web. Paste the benchmark before and after.

## Deliverables (to `lookdev-skyhold-ruins-v1`)
- **Hero shots** at 1920×1080: the Crown Gate at golden hour with striped column shadows (the key image), the fallen statue on Watch Island, the stairs to nowhere over the cloud sea, the Fang Rocks piercing the clouds, a dense island cluster, a wide overview; the key image and the overview at all three times of day. Contact sheet.
- **`skyhold_ruins_flythrough_v1.mp4`:** 60 s at 1080p60: weave through a tight island cluster, under an island's underside, through the Crown Gate, around a Fang Rock down to the cloud sea, up past the snapped chains to Watch Island (pattern of `world_flythrough.gd`).
- **Kael for scale:** voxel Kael on a plaza beside a column, under the Crown Gate and next to the fallen statue, plus gameplay-camera shots of Kael against paving, an underside and the sky at each time of day.
- **Readability strip:** all four legends over paving, an underside, the cloud sea and the sky; **Kael beside verdigris bronze** and **Lyra against the sky** as their own rows.
- Render benchmark output before and after.

## Acceptance (self-check first; the owner decides)
- From the gameplay camera at the spawns, a viewer lists at least 10 distinct zone parts.
- Islands read as light tops on dark bodies over a bright cloud sea under a blue sky; nobody could mistake it for Heartbloom in a thumbnail.
- Every legend reads against paving, undersides and the cloud sea; verdigris never competes with Kael's coat.
- AO visible at column bases, under capitals, in joints and under rims. No smooth-shaded or raw primitive props; columns show drums and flutes.
- Within the GPU budget; the web build holds its target.

## Build notes (for the coder)
| Part | Build | Kit or zone |
|---|---|---|
| Basin, fangs | terrain columns from the baked heightmap; fangs at T2/T3 with strata | **shared kit:** terrain columns, chunk meshing, baked AO |
| Island bodies | a **fractured-slab island builder**: a polygon outline (5–8 chords) inside each island's radius, paved T1 top, stepped strata underside to the existing depth, hanging roots | **shared kit candidate:** the island mesher (Heartbloom builds from `IslandField` profiles; Skyhold uses the same column/terrace mesher with a polygon outline and a paving painter); **zone:** paving and fracture rules |
| Columns, arches, Crown Gate, Watch stump | drum-stack column builder and voussoir arch builder; gate and stump unique | **shared kit:** instanced props; **zone:** column/arch builders (reusable by Stormfall's old stone towers) |
| Statues, braziers, altars, chains | `VoxelDesign` builds; verdigris patina as a paint pass with downward streaks | **zone-specific** |
| Moss, ivy, flowers | cap pass in joints and beds; T0 instanced clumps | **shared kit:** cap pass, instanced props |
| Cloud sea, puffs | existing cloud-sea plane, T3 puff instancer | **shared kit:** puff clouds |
| Placement | keep `SkyholdRuinsProps` islands (positions, radii, depths, yaws) and the 4242 seed; columns at the same ring positions; storytelling props at authored spots on named islands | |
| Code home | look-dev in `game/lookdev/` plus a zone variant folder; the existing world code stays untouched until the owner approves | |
