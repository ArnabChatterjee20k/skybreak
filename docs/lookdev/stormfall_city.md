# Look-dev: Stormfall City (zone design sheet v1)

**Goal:** Stormfall City in the approved voxel style, at the characters' voxel density and with their lighting stack (`docs/lookdev/kael.md`, `.claude/skills/voxel-character-lookdev/SKILL.md`, template `docs/lookdev/heartbloom.md`). Same loop as a character: this sheet, then a build, then a stage, then the owner's three gates. Look before function: the terrain (`TerrainShape._city`), zone data (`stormfall_city.tres`) and props layout (`StormfallCityProps`, `PropKit` seed 4242, the 48 m block / 12 m street grid) stay the truth; this is a visual pass over them.

## Identity and mood
**A drowned, abandoned city in a midnight thunderstorm:** rain-black streets that mirror magenta neon, broken concrete blocks with lit windows nobody stands behind, a canal running through, three towers that catch the lightning. Moody, electric, cinematic; the zone for ambushes, cover and line-of-sight breaks. Read at a glance: *wet streets, magenta neon, leaning blocks, three towers, lightning over a canal.*

Mood comes with its image: the tank's diorama craft, lit like a miniature photographed at night in the rain. Music *Neon Downpour* (175 bpm) and the `amb_stormfall_city` bed with `stormfall_thunder` rolls (`AudioDirector.THUNDER_ZONE`): tension broken by thunder, and every thunder roll gets a lightning flash.

**Lesson applied:** the grey-block city is one blue-grey (ground 0.52–0.60, rock 0.56, buildings 0.5) under a violet fog, with neon in four hues (magenta, cyan, gold, violet), which gives both no contrast and too many accents. The voxel pass makes the **streets the mirror** (dark but reflective), the **buildings a dark mid-value frame with warm windows**, the **sky a lighter storm glow** behind them, and **one accent: magenta neon**.

## Layout at gameplay scale
From `TerrainShape._city`, `stormfall_city.tres` and `StormfallCityProps` (zone centre (−10, 480), extent 320 × 460, arena box ±300 m, ceiling 380 m):

| Part | Shape | Role in a fight |
|---|---|---|
| **Street grid** | 48 m blocks, 12 m streets, ground at 12 m | the main stage; spawns at (−42/−2, 402) on a street |
| **Blocks** | per block: one building 24–64 m tall (45%), four 14–42 m buildings (43%) or a collapsed rubble block (12%); 15% of buildings lean ±0.12 rad | cover, corners, line-of-sight breaks; building corners are destructible |
| **Raised districts** | east-north: +16 m (local (170, −160), ~240 × 180 m); west-south: +8 m (local (−190, 140), ~200 × 220 m) | elevation changes: plazas on terraces with stair-cut retaining walls |
| **The Canal** | a 13 m half-width channel cut 7 m deep, meandering east–west (`lz = 20 + 25·sin(lx·0.012)`); landmark (−10, 6, 500) | the zone's spine: a long open lane through the grid, with bridges |
| **Spire Tower** | 26 × 26 m, 130–170 m, landmark (−102, 150, 618) | the tallest, with a needle spire: the compass |
| **Signal Tower** | landmark (138, 150, 330) | a tower crowned with a lattice radio mast |
| **Old Tower** | landmark (−198, 140, 282) | an older stone clock tower among concrete |
| Skyline ring | 70–150 m towers on the outer blocks (zone weight 0.45–0.8) | hides the neighbouring zones (#137) |
| Water towers, cars | water towers on 12% of roofs; 140 wrecked cars on the streets | destructibles and street clutter |

- **Fighting space:** 12 m streets and rooftops at 14–64 m make a 3D maze; flying above ~70 m opens it up. Keep **streets clear down their middle 6 m** (cars stay at the kerbs, as now).
- **Verticality:** streets 12 m, canal 5 m, roofs to 64 m, towers to 170 m, ceiling 380 m.
- **Landmarks are navigation:** each tower has a different crown (needle, mast, clock) and a different light (the needle's magenta beacon, the mast's white strobe, the clock face's warm glow), visible from every street.

## Detail at three scales
| Scale | Parts |
|---|---|
| **Big forms** | Buildings as stacked floor slabs (3.5 m storeys) with setbacks, cornices and roof parapets; broken tops (missing corners, exposed floor plates, rebar); leaning buildings with a crack line at their base; the canal with stone embankment walls; bridges (an arched stone footbridge, a steel road bridge); the three towers; collapsed blocks as rubble mounds with slabs at angles |
| **Medium parts** | Window grids (recessed 1 cell, frames, some lit, some broken, some boarded); fire escapes (zig-zag stairs and landings); balconies; shop fronts with roller shutters and awnings; **neon signs** (vertical blade signs and horizontal bands, built as tube outlines on a dark backing); water towers on stilts; rooftop AC units, vents and antennas; street lamps (sodium, most dead); wrecked cars (6 body variants, smashed windscreens); bus stop; billboards; overturned bins; puddles; canal boats sunk at the moorings; cables strung across streets |
| **Tiny details** | Rain streaks on facades (darker vertical stains); puddle ripples; graffiti tags (original shapes, muted); posters peeling; cracked kerbs; drain grates with water pouring in; broken glass glints; rust drips under rails; flickering tubes; pigeons on ledges; litter; wet-sheen highlights on every up-facing surface; rebar ends; numbered doors |

**Storytelling details (at least 5):**
1. A **noodle-bar sign** (original name in a made-up script) still lit in magenta, with a stool tipped over under its awning and a bowl on the counter.
2. A **bus half-sunk** into a collapsed road at the canal's edge, its destination board still showing a stop name.
3. **Laundry lines** strung between two balconies, the clothes soaked and still.
4. The **Old Tower's clock** stopped at a fixed time, one hand missing; its face is the only warm big light in the skyline.
5. A **rooftop garden** on one mid-height building: planters, a bench and a tarp shelter, where someone lived after the city emptied.
6. **Water pouring** off a broken roof gutter into a street, making a long puddle that reflects the neon.

**Zone emblem (original): the Split Bolt.** A lightning bolt splitting into two branches inside a hexagon (like a manhole cover). Cast into the drain and manhole covers and stencilled on water towers.

## Voxel density (the characters' relationship, scaled)
| Tier | Cell | Used for | Note |
|---|---|---|---|
| T0 | 2.2 cm | ≤ 1 m: neon tubes, window frames' fine bars, cables, posters, glass, bowls, signs' lettering, pigeons, rebar ends | same pixel scale as a fighter |
| T1 | 8.8 cm | 1–15 m: cars, shop fronts, shutters, fire escapes, balconies, AC units, lamps, water towers, rubble slabs, bridge parapets, the bus; **the walkable street, kerb and canal-walk surfaces** and the first 2 storeys of every facade | what fighters stand on and fight against |
| T2 | 35 cm | upper facades, roofs, towers' bodies | never at a fighter's feet |
| T3 | 1.4 m | the skyline ring, tower crowns at distance | far only |

- **Feet rule:** streets and kerbs at T1; the visible top stays within ±4.4 cm of the `ZoneGround` floor. Puddles are painted into the street cells (a wet material flag), never a raised plane.
- **Colour noise:** ±2–3% on concrete and asphalt, up to ±6% on rust, brick, posters and rubble. Darker under cornices, in window recesses, under awnings and at building feet; lighter on kerb edges, parapet tops and wet up-facing highlights.
- **Design in blocks:** everything here is already rectilinear: storeys, windows and parapets are planar steps. Broken edges are stepped breaks, not noise.

## Palette and value plan (dark frame, mirror streets, glowing sky)
| Material | Base | Shadow | Notes |
|---|---|---|---|
| Asphalt (wet) | blue-black `#2A2C34` | `#18191F` | reflection carries it: mirror of signs and sky, roughness 0.15 |
| Kerbs, pavement | grey `#5E606A` | `#383A42` | lighter than asphalt so streets have edges |
| Concrete facades | cool grey `#5A5C66`, jittered warm/cool | `#34363E` | |
| Brick (older blocks) | muted brown-red `#6A4A40` | `#3E2C26` | sat ≤ 30% |
| Old Tower stone | warm grey `#7A7266` | `#4A443C` | |
| Steel (fire escapes, bridges, water towers) | dark rust-grey `#4A4442` | `#2A2624` | rust streaks `#6A4A38` |
| Lit windows | warm `#E8C890`, emission ≤ 1.2 | | 20–35% lit; never saturated |
| Sodium lamps | soft amber `#E0A860`, emission ≤ 1.0 | | few, desaturated |
| Cars | muted body colours (sat ≤ 35%) | | the grey-block's random HSV 0.5 sat cars become muted |
| **Accent: magenta neon** | hot magenta `#FF3CA8`, emission ≤ 2.5 | glow `#A02070` | the one saturated colour: signs, tower beacon, their reflections |
| Lightning | blue-white flash | | brief |
| Sky and fog (night, hero) | storm-lit slate `#3A3E50` lower sky, `#14161E` zenith; fog `#4A4E5E` | | lighter than the buildings |

**Value plan (L\*):**
| Plane | What | Value |
|---|---|---|
| Near (0–40 m) | wet street, kerbs, cars | **L\* 15–30** base, with **neon and sky reflections up to 60–75** |
| Mid (40–250 m) | facades | **L\* 15–30** with window pinpoints and neon |
| Far (250 m+) | skyline silhouettes against the storm glow | sky and fog **L\* 30–45** (city glow on low cloud), lightning to 90 |

The fight reads as **dark figures against a lighter, glowing sky and against mirror streets full of light**. Lightning flashes flip the whole frame for 2–3 frames: big silhouettes.

**Readability rules (the fighters must always win):**
1. **Vexa is the risk.** Her near-black bodysuit (L\* 10) disappears on L\* 15–30 streets and facades. Rules: (a) the zone's rim stays strong (1.6 / 1.2 / 0.9) and its colour **cool white**, not cyan; (b) the street reflections and the lighter sky give her a light ground behind her from the gameplay camera's pitch; (c) her silver jacket (L\* 59) must read in every readability frame. Check her in the strip first.
2. **Violet out:** the grey-block day fog and horizon are violet (0.44, 0.27, 0.52), Vexa's hue; the voxel pass moves fog and sky to **slate** (~230°, ≤ 15% saturation). The violet neon colour goes.
3. **One accent:** neon is magenta (~325°). The grey-block's **cyan** (Lyra's energy and Kael's coat hue), **gold** (the item family) and **violet** (Vexa) sign colours are dropped; secondary signs become warm white tubes. Window light stays warm and low.
4. **Team colours:** team rims (orange, cyan, green, violet) are fighter-only; the zone uses none of them as saturated light.
5. **Saturation ceiling:** besides magenta neon and lightning, nothing exceeds ~35%.
6. **Busy-ness falls off:** rain streaks thin and short within 4 m of the camera; no neon signs within 6 m of street centres at fighter height (they hang on facades above 3 m).

## Lighting and time of day
`stormfall_city.tres` presets. The city reads as night whatever the clock (windows and signs always lit, #120); the presets change the storm's sky.

| Preset | Sun | Ambient | Rim | Look |
|---|---|---|---|---|
| Day (*storm day*) | cold blue (0.6) | blue-grey | 1.6, now cool white | a dark daytime storm: grey-green sky, signs still on |
| Dusk (*after the storm*) | low pink-grey (0.56) | mauve | warm, 1.2 | clearing clouds with a band of light at the horizon, wet streets catching it |
| **Night** (hero, *thunderstorm midnight*) | moonless (0.24) | deep blue | cool, 0.9 | full storm: neon reflections, lightning, rain |

- **Preset notes for the voxel pass:** day sky top (0.03, 0.04, 0.13) and fog (0.44, 0.27, 0.52) → slate storm sky `#3A3E50` with fog `#4A4E5E`; day rim colour (0.5, 0.92, 1.0) cyan → cool white `#D8E4FF`.
- **Stack:** baked per-vertex AO (window recesses, under cornices, awnings and balconies, street–wall joints, under cars) on every tier; one directional shadow (weak, from the moon or storm light); fill from the sky; **baked neon bounce** (magenta falloff onto nearby facades and pavement, 8 m); the voxel edge highlight; wet-sheen specular on up-facing cells; the zone's rim on fighters.
- **Lights:** neon and windows are emissive; at most 4 OmniLights (nearest signs), no shadows. **Lightning:** a directional flash (2–3 frames, intensity 3, random 6–20 s, synced to `stormfall_thunder` with a 0.5–2 s delay), plus a flash in the sky shader; never more often than every 6 s (photosensitivity), and a setting to soften it.
- **Reflections:** screen-space reflections are off by budget; streets fake them with a planar-ish reflection probe per district plus emissive streaks under each sign (a stretched vertical reflection quad on the wet street), which is cheap and reads.

## Atmosphere and sky
- **Sky:** low storm clouds lit from below by the city (slate, a faint warm glow over the centre); lightning illuminates cloud shapes from inside.
- **Rain** (the `rain` weather): slanted streaks, splashes on streets and roofs, drips from awnings; mist of spray at street level far away.
- **Fog:** slate, density 0.45 (fog ends ~450 m): the skyline ring stands as flat silhouettes in three planes; tower beacons pierce it.

## Motion
| Element | Motion | Rule |
|---|---|---|
| Rain | streaks, splashes, ripples in puddles | sparse near the camera |
| Lightning | flash, branching bolt in the sky (not on fighters) | ≥ 6 s apart, synced to thunder |
| Neon | steady; 2–3 signs flicker on a hashed schedule | flicker never on the closest sign |
| Gutter water | falling streams of voxel droplets | |
| Canal | slow current, rain rings | |
| Cables, laundry | slight sway | rigid blocks |
| Spire beacon | slow magenta pulse | |
| Breakables | building corners crumble into slabs; water towers burst (water + wood staves); cars crumple and flip (existing destructibles) | fragments are T1 concrete with rebar |

## Performance (GTX 1650 at 1080p60, plus the web build)
- Budget: world ≤ **3 ms GPU p95 at medium** on this zone with the render benchmark. Web: 60 fps in Chrome on the same PC.
- **The heaviest zone by object count:** hundreds of buildings, windows and signs. Facade detail is mostly colour (window texels in the chunk colour texture plus a 1-cell recess), not geometry, beyond the first two storeys.
- **Chunk meshing** per building (a building is 1–4 chunks), frustum- and occlusion-culled (streets are natural occluders).
- **Instancing:** cars (6), water towers (2), AC units (4), lamps (2), fire escapes (3 heights), rubble (6), signs (8 shapes, tinted) as MultiMesh.
- **Lights:** ≤ 4 omni, no shadows; neon bounce baked; reflections faked (no SSR).
- **Particles:** rain as one GPUParticles3D around the camera; splashes as a cheap decal flipbook; halve on web.
- **LOD:** T0 fades past 40 m; facades to T2 past 80 m, the skyline ring as T3 boxes with a window texture.
- Targets: ≤ 1.2 M visible triangles, ≤ 250 draw calls desktop; ≤ 500 k and ≤ 120 web. Paste the benchmark before and after.

## Deliverables (to `lookdev-stormfall-city-v1`)
- **Hero shots** at 1920×1080: a street at midnight with neon reflections and the Spire Tower behind (the key image), the canal with the half-sunk bus, the Old Tower's stopped clock, a lightning flash over the skyline, a rooftop garden, a wide overview; the key image and the overview at all three presets. Contact sheet.
- **`stormfall_city_flythrough_v1.mp4`:** 60 s at 1080p60: low down a neon street, a turn over the canal past the bus, up a fire escape to the rooftop garden, through a gap between leaning blocks, a climb around the Spire Tower's needle during a lightning flash (pattern of `world_flythrough.gd`).
- **Kael for scale:** voxel Kael beside a car, under a neon sign and on a canal bridge, plus gameplay-camera shots of Kael on a street at each preset.
- **Readability strip:** all four legends over wet street, facade, sky and neon; **Vexa on a street and against a facade** as its own row.
- Render benchmark output before and after.

## Acceptance (self-check first; the owner decides)
- From the gameplay camera at the spawns, a viewer lists at least 10 distinct zone parts.
- The sky is lighter than the buildings in every hero shot; streets mirror the neon; magenta is the only saturated colour.
- Vexa reads on a street and against a facade at every preset.
- AO visible in window recesses, under awnings and at building feet. No smooth-shaded or raw primitive props.
- Feet on the visible street (QA foot check passes).
- Within the GPU budget; the web build holds its target.

## Build notes (for the coder)
| Part | Build | Kit or zone |
|---|---|---|
| Street ground, raised districts, canal | terrain columns from the baked heightmap at T1; street/kerb/pavement painted from the 48 m grid; retaining walls on district edges; canal embankments | **shared kit:** terrain columns, chunk meshing, baked AO; **zone:** the street painter (the grid already in the terrain shader) |
| Buildings | a **facade builder**: storey slabs, setbacks, window grid (recess + per-window lit/broken/boarded state hashed), cornice, parapet, broken-top CARVE, lean; uses each existing building transform (size, height, lean, tint) | **zone-specific** (the largest builder in any zone) |
| Towers | Spire (needle + beacon), Signal (lattice mast), Old Tower (stone, clock face; reuse Skyhold's block/column builders) | **zone-specific**, Old Tower shares Skyhold's stone kit |
| Cars, water towers, AC, lamps, fire escapes, rubble | `VoxelDesign` builds, instanced with the existing transforms and tints (desaturated) | **shared kit:** instanced props |
| Neon signs | tube-outline builder on dark backings, magenta and warm white only; emissive | **zone-specific** |
| Neon bounce, wet sheen | baked emitter bounce; a wet flag in the chunk material | **shared kit:** emitter bounce bake (Ember lava, Heartbloom lanterns) |
| Rain, lightning, reflections | particles, sky-shader flash, reflection probes and streak quads | **zone-specific** |
| Placement | keep `StormfallCityProps` grid, transforms and the 4242 seed; the skyline ring as is; storytelling props at authored spots off street centres | |
| Code home | look-dev in `game/lookdev/` plus a zone variant folder; the existing world code stays untouched until the owner approves | |
