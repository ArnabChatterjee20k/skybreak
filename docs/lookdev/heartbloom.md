# Look-dev: Heartbloom Gardens (zone design sheet v1)

**Goal:** Heartbloom Gardens in the approved voxel style, matching the characters' voxel density and lighting stack (`docs/lookdev/kael.md`, `.claude/skills/voxel-character-lookdev/SKILL.md`). Same loop as a character: this sheet, then a build, then a stage, then the owner's three gates. Look before function: the sim's island geometry (`IslandField.HEARTBLOOM`), zone data (`heartbloom_gardens.tres`) and props layout (`HeartbloomProps`, seed 5151) stay the truth; this is a visual pass over them.

## Identity and mood
The special zone, made for the owner and their partner: **floating cherry-blossom islands at a pink-gold sunset**, joined by lantern bridges, with a heart-shaped stone arch at the centre. Romantic and playful, never sugary: an old, loved garden that someone still tends. Read at a glance: *blossom islands over a cloud sea, the Heart Arch, lanterns on rope bridges, a slow river of petals.*

Mood words come with their image: the tank's diorama craft (every stone placed), lit like a miniature at golden hour.

## Layout at gameplay scale
From `IslandField.HEARTBLOOM` and `heartbloom_gardens.tres` (zone about 660 × 460 m):

| Ring | Islands (top height, radius) | Role in a fight |
|---|---|---|
| Centre | **Heart Isle** (285 m, r 64) with the **Heart Arch** (46 m tall, 26 m north of centre) | the main stage: open lawn for ground play, the arch as a fly-through gap and a wall-splat surface |
| Inner ring (~170 m out) | **Wishing Isle** (276, r 44, Wishing Fountain heals), **Lantern Rise** (280, r 42), **Blossom Crown** (298, r 48, Blossom Falls), **Picnic Meadow** (272, r 54, spawns) | four distinct landings, each with one landmark; mid-range space between them |
| Outer petals | West/East/South/North Petal (264–310, r 22–26), Dew Drop (258, r 17), Twin Drop (268, r 18) | small perches for zoners (Lyra) and escape hops (Vexa) |

- **Fighting space:** open sky between islands is the point; bridges (rope-plank, 8 links) are low obstacles, never walls. Keep a **30 m clear radius** of open air around every island rim except where a bridge lands.
- **Verticality for flight:** tops span 258–310 m (52 m); undersides hang 22–74 m below as rocky cones you can fight around and under; three **petal whirlwinds** (r 9 m, 80 m tall) are lift columns; Blossom Falls drops off Blossom Crown into the clouds.
- **Edges:** the world's energy dome is the wall. Below the islands, the cloud sea is a soft floor of fog and voxel puff clouds; the ground far beneath is never seen.
- **Landmarks are navigation:** each visible from Heart Isle, each a different shape (arch, fountain plume, lantern tower, waterfall).

## Detail at three scales
| Scale | Parts |
|---|---|
| **Big forms** (islands and terrain) | Domed lawn tops terraced in clean voxel contour steps; rocky underside cones with strata; cliff lips (1.6 m) with overhangs; the Heart Arch; the cloud sea; distant island silhouettes |
| **Medium parts** | Blossom trees (6 variants: trunk, 3–5 limbs, canopy as 4–7 clustered blossom masses); stone lanterns along paths and paper lanterns hung on bridges; the Heart Arch's blocks, keystone and moss line; stepping-stone paths and a flagstone walk; rope-plank bridges with posts; the Wishing Fountain (basin, tiered spout, rim); ruins (broken pillar stubs, a toppled column, a half-buried gate); the stream and Blossom Falls; picnic stones and a low wall on Picnic Meadow |
| **Tiny details** | Fallen petals on lawn and stone (1-voxel pink flecks); moss in cracks and on the north sides of stones; hairline cracks and chipped corners; carved marks (initials in hearts on the arch's inner face, tally marks on a lantern, a worn sun-dial ring on the fountain rim); wishing coins in the basin; rope knots and frayed ends; paper lantern ribs; clover and tiny white flowers in the lawn; fireflies at night |

**Storytelling details:**
1. Pairs of initials carved inside small hearts on the arch's inner face, some fresh, some mossed over.
2. Wishing coins in the fountain basin, more near the rim, one balanced on the spout.
3. A picnic blanket folded on a stone on Picnic Meadow, with a basket beside it.
4. One bridge plank replaced with lighter, newer wood.
5. A single lantern on Lantern Rise is a different colour (pale blue paper): someone's replacement.

**Zone emblem (original): the Twin Bloom.** Two five-petal blossoms sharing one stem that curls into a heart. Carved into the arch's keystone and stamped on the lantern caps.

## Voxel density (the characters' relationship, scaled)
Each object's cell is about 1/64–1/128 of its size, like the characters, on a ladder of ×4 steps from the character body cell (2.2 cm):

| Tier | Cell | Used for | Note |
|---|---|---|---|
| T0 | 2.2 cm | hand-scale props ≤ 1 m: paper lanterns, coins, rope knots, flowers, the picnic basket, carved initials | same cell as a fighter's body; reads at the same pixel size next to them |
| T1 | 8.8 cm | props 1–15 m: tree trunks and canopies, stone lanterns, bridge planks, path stones, fountain, ruins, the arch's outer shell; **the walkable lawn top** (top 1 m shell) | the scale fighters stand on and fight against |
| T2 | 35 cm | cliff lips, upper undersides, the arch core | never at a fighter's feet |
| T3 | 1.4 m | deep underside cones, distant islands, voxel puff clouds | only ever seen far away or through fog |

- **Feet rule:** the T1 lawn terraces round to the nearest cell, so the visible top is within ±4.4 cm of `IslandField.surface_at` (the QA foot check allows 5 cm).
- **Colour noise:** ±2–3% on lawn and stone, up to ±6% on bark, petals and moss; darker in cracks and under canopies; lighter on worn path centres, step edges and arch corners.
- **Design in blocks:** island tops are terraced contours, cliffs are planar strata slabs, the arch is laid stone blocks. Don't voxelise smooth curves into noisy 1-voxel steps.

## Palette (soft, high-key world; fighters own the saturation)
| Material | Base | Shadow | Notes |
|---|---|---|---|
| Lawn | light yellow-green `#7FA85A` | `#4E6E3A` | lighter and yellower than Brann's moss |
| Lawn moss, path moss | sage `#6F8A58` | `#455A38` | |
| Stone (paths, lanterns, ruins) | warm pale grey `#B8AEA6` | `#7C736E` | |
| Heart Arch, cliffs | rose sandstone `#C9998F` | `#8A625C` | from the zone's `rock` colour, desaturated |
| Underside rock | dusky mauve-grey `#6E5A62` | `#43363D` | fades into fog |
| Bark | warm grey-brown `#5C4A44` | `#3A2E2A` | |
| Blossoms | pale pink `#F2B8C8`, petal flecks `#F7CCD8` | `#C7849A` | saturation capped at ~30% |
| Bridge wood, posts | weathered tan `#9C8468`, posts muted brick `#8A4A40` | `#6A5640`, `#5A2E28` | no glossy lacquer red |
| Paper lanterns | warm paper `#F0D2B0` (lit: soft peach glow) | `#B0907A` | low intensity, diffuse |
| Water | pale aqua `#9CCBCB` | `#5E8E96` | sparkle highlights only |

**Readability rules (the fighters must always win):**
1. **Value split:** the world's mid-ground sits at L* 55–80 (lawn, stone, blossoms, day and dusk sky). Each fighter has a main mass at L* ≤ 45 (Vexa's bodysuit, Lyra's navy, Kael's teal, Brann's basalt) plus one light element, so they read dark-on-light by day and rim-lit at night.
2. **Saturation ceiling:** nothing in the zone exceeds ~45% saturation except small water sparkles. Accents and energy own the saturated range.
3. **Hue exclusions:** no saturated violet or cerulean anywhere (Vexa, Lyra). Warm lanterns stay soft peach at low emission (≤ 1.5), diffuse paper shapes, never white-hot (Kael's energy) or thin glowing lines (Brann's cracks).
4. **Busy-ness falls off:** the tiny-detail layer thins out in the fighting air; petals in the air stay small (1–3 cm) and sparse near the camera.

## Lighting and time of day
The zone's three presets (`heartbloom_gardens.tres`), with the miniature stack on top:

| Preset | Sun | Ambient | Rim | Look |
|---|---|---|---|---|
| Day | warm white, high (energy 0.92) | soft lilac-grey | warm white, 0.30 | clear, bright pastel |
| **Dusk** (hero) | low pink-gold (0.84) | rose | peach, 0.45 | the defining look: long shadows, glowing canopy edges |
| Night | cool moonlight (0.42) | deep violet-blue | cool, 0.55 | lanterns and fireflies carry the scene |

- **Stack:** baked per-vertex AO (crevices, under canopies, under bridges, in path joints) on every tier; one directional shadow with a soft contact feel; fill from the sky colour; the same voxel edge highlight shader as the characters; the zone's rim light on fighters.
- **Lanterns:** emissive everywhere; at most 4 real OmniLights (nearest to the fight), no shadows.

## Atmosphere and sky
- Sky gradient from the zone's `sky_top` to `sky_horizon` colours; a large, soft sun disc at dusk.
- **Cloud sea** below: height fog in the zone's fog colours plus T3 voxel puff clouds drifting slowly; distant islands fade into it.
- Height fog keeps the far islands as layered silhouettes (three depth planes) so the near island always reads.

## Motion
| Element | Motion | Rule |
|---|---|---|
| Falling petals | a slow "river" drifting from Blossom Crown over Heart Isle; sparse elsewhere | petals are rigid 1–3 cm voxel flecks that tumble; thin out within 4 m of the camera |
| Petal whirlwinds | 3 columns, r 9 m, 80 m tall, spiralling up | they telegraph a lift zone; keep them see-through |
| Paper lanterns | pendulum sway ±6° at ~0.3 Hz, phase hashed per lantern | the lantern moves as a rigid block, never wobbles |
| Blossom canopies | slow rigid sway of each blossom cluster (±2 cm) | move clusters whole; never vertex-wobble single voxels (it breaks the grid) |
| Bridge ropes | slight sag sway | |
| Water | Blossom Falls and the fountain spray | sparkle on the voxel water surface |
| Fireflies (night) | slow wandering points near grass and lanterns | emissive particles, no lights |
| Breakables | lanterns and branches burst into petals (existing) | burst petals use the same voxel flecks |

## Performance (GTX 1650 at 1080p60, plus the web build)
- Budget: the world costs **≤ 3 ms GPU p95 at medium** (GAME_DESIGN §7.3), measured with the render benchmark on the zone. Web: the same scene at the web preset holds 60 fps on the same PC in Chrome.
- **Chunk meshing:** 32³-cell chunks per tier, faces merged across coplanar voxels; per-voxel colour (noise, AO) goes into a small per-chunk colour texture (one texel per cell face), so merging faces doesn't lose the variation. Frustum-cull per chunk.
- **Instancing:** trees (6 variants), stone lanterns (3), paper lanterns (4), rocks and ruins (8), path stones (6) as MultiMesh variants with per-instance tint. No unique prop meshes outside the landmarks.
- **Baked AO:** computed once at build time into vertex colour or the chunk colour texture; no SSAO on the web build (Compatibility), optional on desktop.
- **LOD:** T0 props fade out past 40 m; T1 props swap to a T2 re-voxelised LOD past 80 m and to impostor cards past 250 m; islands past 250 m use T3.
- **Particles:** petals and fireflies as GPUParticles3D; halve counts on web.
- **Caches:** the code-built meshes are generated once and cached as resources, not rebuilt every launch.
- Targets for the stage: ≤ 1.2 M visible triangles and ≤ 250 draw calls on desktop; ≤ 500 k and ≤ 120 on web.
- Perf-affecting: paste the render benchmark output before and after (AGENTS.md).

## Deliverables (to `lookdev-heartbloom-v1`)
- **Hero shots** at 1920×1080: Heart Arch at dusk (the key image), Wishing Fountain, Lantern Rise at night, Blossom Falls, and a wide overview; the arch and the overview at all three times of day. Contact sheet.
- **A slow fly-through:** 60 s at 1080p60 along a path through the arch, past each landmark, under one island and up a whirlwind (pattern of `world_flythrough.gd`).
- **Kael for scale:** voxel Kael standing at the arch's foot, on a bridge and at the fountain rim, plus a gameplay-camera shot of Kael against the lawn, the blossoms and the sky at each time of day.
- **Readability strip:** all four legends' silhouettes and colour models composited over the zone's busiest backgrounds.
- Render benchmark output before and after.

## Acceptance (self-check first; the owner decides)
- From the gameplay camera, a viewer lists at least 10 distinct zone parts on Heart Isle.
- The voxels read as one world with Kael: no smooth-shaded or raw primitive props; cell tiers agree with the ladder.
- AO is visible in every hero shot (under canopies, bridges, path joints).
- Kael reads against the zone in every shot at every time of day; nothing in the zone out-saturates his scarf.
- Feet stay on the visible ground (QA foot check passes on the new mesh).
- Within the GPU budget on the GTX 1650; the web build holds its target.

## Build notes (for the coder)
| Part | Build |
|---|---|
| Island tops | generated from `IslandField.top_profile`, rounded to T1 terraces; contour steps 1 cell high with bevelled edges; the lawn shader's patches, petals and the stone walk become painted voxel colour |
| Island undersides | `IslandField.underside_profile` at T2 near the lip, T3 below; strata as planar slabs stepping in |
| Heart Arch | laid stone blocks (planar, bevelled, 1-cell mortar gaps), keystone with the Twin Bloom; T1 shell over a T2 core |
| Trees | trunk and limbs as tapered capsule chains at T1; canopy as clustered blobs of blossom voxels (curves allowed here, at T1) |
| Lanterns, bridges, fountain, ruins | planar parts with bevelled edges; ropes as T0 chains |
| Placement | reuse `HeartbloomProps` positions and seed so the layout and the sim stay as they are |
| Code home | look-dev in `game/lookdev/` plus a zone variant folder; the existing world code stays untouched until the owner approves |

## v2 look decisions (after the v1 review)
The v1 draft read as one pink. v2 overrides the palette and lighting tables above where they disagree:
- **Pink is the accent only:** blossoms, petals, ribbons, the picnic blanket and a few love locks. The sky runs lavender-blue to gold (`VoxelStage.PRESETS`). The fog is light and neutral, the cloud sea white, and the undersides grey-brown strata rock.
- **Lawn:** a smooth T1 top (no contour rings) that lies exactly on `IslandField.surface_at`, with four grass tones in patches, clover, white and yellow flower flecks, petal drifts under the canopies and flagstone walks. On top of that: 3D grass tufts, flowers, weathered stones, edging stones, rim turf lips with dangling roots, and hanging roots under the islands.
- **Heart Arch:** laid voussoirs in three sandstone tints, mortar joints with moss low down, a blossom vine, ribbons at the feet, a darker keystone with a gold heart in relief, two lanterns in the lobes and a love-lock chain in front.
- **Story props:** lantern bridges (one new plank), the fountain with coins, a bench, a swing, a wayside shrine, a stone carved with initials in a heart, a well, and a picnic blanket with a basket.
- **Code:** the shared kit is `game/world/voxel_zone_kit/` (README). Heartbloom lives in `game/world/voxel_zones/heartbloom/`.
