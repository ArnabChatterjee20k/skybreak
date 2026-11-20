# Look-dev: Shattered Mesa (zone design sheet v1)

**Goal:** Shattered Mesa in the approved voxel style, at the characters' voxel density and with their lighting stack (`docs/lookdev/kael.md`, `.claude/skills/voxel-character-lookdev/SKILL.md`, template `docs/lookdev/heartbloom.md`). Same loop as a character: this sheet, then a build, then a stage, then the owner's three gates. Look before function: the terrain (`TerrainShape._mesa`, `MESAS`), zone data (`shattered_mesa.tres`) and props layout (`ShatteredMesaProps`, `PropKit` seed 4242) stay the truth; this is a visual pass over them.

## Identity and mood
**Red desert at high noon:** banded sandstone mesas standing in a pale sand flat, a natural stone arch, hoodoo pillars like a crowd of stone giants, all under a hard white sun and a deep cobalt sky. Bold, open, sunlit; the place for long-range duels and big silhouettes. Read at a glance: *striped red mesas, the Red Arch, hoodoo field, pale sand, a cobalt sky.*

Mood comes with its image: the tank's diorama craft, lit like a miniature on a sunny windowsill: hard shadows, warm bounce. Music *Red Horizon* (147 bpm) and the `amb_shattered_mesa` bed (dry wind, a far hawk-like cry): big open space and drive.

**Lesson applied:** the grey-block is orange everywhere (ground 0.93/0.92, rock 0.84, fog sand-coloured). The voxel pass separates **pale cream sand** (floor), **banded red rock** (mesas and hoodoos, with light and dark bands) and a **deep cobalt sky** (the complement), and keeps the haze cool and thin.

## Layout at gameplay scale
From `TerrainShape._mesa`, `shattered_mesa.tres` and `ShatteredMesaProps` (zone centre (650, 500), extent 340 × 470, arena box ±300 m, ceiling 380 m):

| Part | Shape (local to the centre) | Role in a fight |
|---|---|---|
| **Desert floor** | 16 ± 5 m, gentle | the main stage; spawns at (490/530, 490), local (−160/−120, −10), between the mesas |
| **Plateau** (outer, south-east side) | rises to ~78 m where `lx + 0.6·lz` passes ~40–110, in 13 m terraces, cut by noise **canyons** back to the floor | the **Canyon Maze** landmark (850, 70, 750): tight canyons for close play, shelves for zoners |
| **Free mesas** (7) | r 30–70 m, 62–104 m tall, 11 m terraces; the **Great Mesa** (400, 96, 540; r 70, h 96) west and the **Anvil Mesa** (690, 104, 460; r 46, h 104) at the centre | flat tops to land on, walls to splat into, the big silhouettes |
| **Red Arch** | a 90 × 70 × 40 m natural arch at (590, 330), yaw 0.6 | the hero landmark and a fly-through gap |
| **Hoodoo Field** | landmark (560, 20, 640); 46 hoodoo pillars 28–72 m tall, r 3.5–8 m, on floor below 30 m | cover and line-of-sight breaks on an otherwise open floor |
| Boulders | 220 boulders 2–7 m | low cover and floor texture |

- **Fighting space:** open floor with long sight lines (fog 0.08: fog ends ~1.1 km), broken by mesas and the hoodoo field; it favours zoning. Keep the **open lines**: no new tall props on the floor outside the hoodoo field.
- **Verticality:** floor 16 m, plateau 78 m, mesas to 104 m, arch top ~66 m above its base, ceiling 380 m.
- **Edges:** the plateau and canyons climb to the zone edge; neighbours blend over 100 m.
- **Landmarks are navigation:** the Red Arch (a hole in the sky), the Anvil Mesa (a tall flat block at the centre), the Great Mesa (the widest), the Hoodoo Field (a forest of pillars), the Canyon Maze (a broken plateau). Five distinct shapes.

## Detail at three scales
| Scale | Parts |
|---|---|
| **Big forms** | Mesas as stacked planar **strata slabs**, each 11–13 m terrace split into 3–5 thinner bands of alternating light and dark sandstone, with a talus apron of fallen blocks at the foot; the caprock (a harder, darker grey-brown band) on every mesa top with an overhanging lip; the plateau's canyon walls; the Red Arch as laid strata (not a smooth extruded C); the sand flat with dunes on the lee side of mesas |
| **Medium parts** | Hoodoos (6 variants: stacked bulging drums with a flat dark caprock "hat", narrow necks); boulders and talus blocks (planar, chipped); dry washes on the floor (shallow channels with pebble beds); desert scrub (sage bushes as clustered T1 blobs, 4 variants); dead trees (bleached forked trunks); slot-canyon narrows with wedged chockstones; a **surveyor's camp** (canvas lean-to, a theodolite on a tripod, a water barrel); a **stone-lined well** on the floor; cairns on mesa tops |
| **Tiny details** | **Chartreuse lichen** crusts on north faces and boulder tops (the accent); desert varnish streaks (dark vertical stains down cliff faces); cross-bedding lines in the sandstone; ripple marks in sand; pebbles; animal tracks; cracked mud polygons in dry washes; chipped strata edges; spiral petroglyphs pecked into a boulder; wind-polished caprock edges |

**Storytelling details (at least 5):**
1. **Petroglyphs** pecked into a boulder face near the Red Arch: an arch shape, a sun, and two small figures (original, simple spirals and lines).
2. The **surveyor's camp** on the Anvil Mesa's top: a lean-to, a theodolite pointed at the Red Arch, a ledger weighed down by a stone.
3. A **stone-lined well** in the floor with a frayed rope and a dented bucket on the rim, sand drifted against one side.
4. A **fallen hoodoo** broken into drums across a wash, its cap lying upside down a few metres away (the destructible's "after" state).
5. A **cairn line** across the mesa tops, one cairn per mesa, guiding someone from the Great Mesa to the arch.
6. A **chockstone** wedged high in a slot canyon with an old rope tied around it.

**Zone emblem (original): the Banded Sun.** A circle split by three horizontal bars (strata), with four short rays above. Pecked among the petroglyphs and stencilled on the surveyor's barrel.

## Voxel density (the characters' relationship, scaled)
| Tier | Cell | Used for | Note |
|---|---|---|---|
| T0 | 2.2 cm | ≤ 1 m: lichen crusts on props, pebbles, rope, bucket, theodolite, ledger, petroglyph pecks, tracks | same pixel scale as a fighter |
| T1 | 8.8 cm | 1–15 m: boulders, talus, scrub, dead trees, hoodoo bases (lower 12 m), the well, the camp, chockstones, wash beds; **the walkable sand floor** and mesa-top caprock (top 1 m shell) | what fighters stand on and fight against |
| T2 | 35 cm | mesa walls, hoodoo upper bodies, canyon walls, the arch's legs and span | never at a fighter's feet |
| T3 | 1.4 m | far mesas and the plateau beyond 250 m | far only |

- **Feet rule:** floor and mesa tops round to T1; the visible top stays within ±4.4 cm of the `ZoneGround` floor. Mesa tops are flat caprock at T1, so landings read clean.
- **Colour noise:** ±2–3% on sand and big strata faces, up to ±6% on lichen, scrub, boulders and talus. Darker in band seams, under the caprock lip and at boulder feet; lighter on band edges, wind-polished corners and wash centres.
- **Design in blocks:** strata are planar slabs with a 1-cell setback per band; hoodoos are stacked drums with flat faces (an octagon in plan at T2), never a smooth cylinder or a voxelised cone.

## Palette and value plan (pale floor, banded walls, cobalt sky)
| Material | Base | Shadow | Notes |
|---|---|---|---|
| Sand floor | pale cream `#E2D2B4` | `#A8927A` (warm) | the lightest large surface |
| Dune crests, wash centres | `#EADCC2` | `#B09C84` | |
| Sandstone, light band | dusty salmon `#C88C70` | `#8A5A4A` | sat ≤ 45% |
| Sandstone, dark band | brick rust `#9A5440` | `#663428` | sat ≤ 50% |
| Caprock | grey-brown `#6E5E54` | `#463A34` | a dark hat on every mesa and hoodoo |
| Talus, boulders | mixed salmon and rust, jittered | | |
| Desert varnish | dark umber streaks `#4A3428` | | vertical stains |
| Sage scrub | dusty sage `#8A9470` | `#5A6248` | |
| Dead wood | bleached grey `#B8B0A4` | `#7A7268` | |
| Surveyor canvas, rope | `#B4A488`, `#9A8466` | `#7A6C58`, `#64563E` | |
| **Accent: lichen** | chartreuse `#B4D23C` | `#7A9426` | the one saturated colour; north faces, boulder tops, never > 3% of the screen |
| Sky (day, hero) | deep cobalt `#2A50B0` top, pale cool `#BACCE4` horizon | | the complement of the rock |

**Value plan (L\*):**
| Plane | What | Value |
|---|---|---|
| Near (0–40 m) | sand floor, boulders, scrub | **L\* 70–85** |
| Mid (40–250 m) | mesa walls, hoodoos, the arch | **L\* 35–60** (bands alternate ~15 apart), caprock 30 |
| Far (250 m+) | far mesas in haze, sky | far mesas lifted to L\* 60–70 by cool haze; sky **L\* 35–45 at the zenith**, 80 at the horizon |

**Readability rules (the fighters must always win):**
1. **Value split:** fighters' main masses (≤ L\* 45) read dark-on-light against the sand from the gameplay camera; against the mid-value mesa walls, their light elements and the rim (dusk 0.45) separate them.
2. **Warm-legend guard:** Kael's burnt-orange scarf (22°) and Brann's ember-red beard (8°) share this zone's rock hue. Rules: rock saturation ≤ 50% (the grey-block `rock` 0.84, 0.44, 0.30 is ~64% and moves down to `#B07058`-ish); no orange or red **saturated** surfaces anywhere; the strongest red is only in dark bands far from the floor. The scarf (sat ~75%) and beard (dark, saturated) must out-saturate every rock in the readability strip.
3. **Cerulean guard:** the sky is cobalt and saturated only near the zenith; within 25° of the horizon (where Lyra's cape flashes in gameplay framing) it fades to a pale, desaturated `#BACCE4`. Lyra's dark navy reads against the pale horizon by value.
4. **Hue exclusions:** no violet; no saturated gold (items): the sand stays cream, never yellow. Lichen is greener than gold (~75°).
5. **Busy-ness falls off:** scrub and pebbles thin out within 10 m of the spawns; dust motes sparse.

## Lighting and time of day
`shattered_mesa.tres` presets, with the miniature stack on top:

| Preset | Sun | Ambient | Rim | Look |
|---|---|---|---|---|
| **Day** (hero, *high noon*) | hard white, high (1.08, ~58° up) | warm neutral | warm, 0.3 | crisp short shadows, strong warm bounce off the sand into the shadows, cobalt sky |
| Dusk | low, deep orange (0.8) | rose | warm, 0.45 | mesas glow red on one side, long purple shadows (the alternate key image) |
| Night | cool moonlight (0.28) | violet-blue | cool, 0.55 | stars over silhouettes; the surveyor's lantern is the only warm light |

- **Preset notes:** the day horizon (0.76, 0.80, 0.88) is good; deepen `sky_top` slightly toward `#2A50B0` so the contrast with the sand is unmistakable. The day fog (0.88, 0.76, 0.62) is sand-coloured, which repeats the floor; move it to a cool pale `#C8D0DC` so distance turns the mesas cooler, not oranger. The night ambient (0.16, 0.15, 0.26) is fine; keep the night fog off violet.
- **Stack:** baked per-vertex AO (band seams, under caprock lips, hoodoo necks, talus, arch underside) on every tier; one directional shadow (hard-ish at noon, the miniature's crisp contact); **warm ground bounce** as fill (the sand lights the undersides of the arch and caprocks: this is the zone's signature); the voxel edge highlight; the zone's rim on fighters.
- **Lanterns:** one at the surveyor's camp, emissive only.

## Atmosphere and sky
- **Sky:** cobalt zenith fading to a pale cool horizon; a few high flat voxel clouds (T3, thin, white) for scale; a small hot sun disc at noon, a big orange one at dusk.
- **Haze:** thin and cool, so far mesas step back in three planes of lighter, bluer values (aerial perspective is the depth cue in an open zone).
- **Heat shimmer:** a faint band over the sand far from the camera only (off on web).
- **Dust:** occasional dust devils (thin spiral of sand flecks, ~3 m wide, 15 m tall) drifting across the floor; small sand gusts off mesa tops.

## Motion
| Element | Motion | Rule |
|---|---|---|
| Dust devils | 1–2 at a time, slow wander, 20 s life | see-through, never across the spawns at round start |
| Sand drift | thin streams off dune crests in gusts | rigid flecks |
| Scrub | slow rigid sway of each bush cluster | clusters move whole |
| Surveyor's canvas, well rope | slight flap and sway | rigid blocks |
| Birds | 2–3 distant gliding specks circling a mesa | far only |
| Breakables | hoodoos and pillars break into stacked drums; mesa tops shear off along a strata line (existing destructibles) | fragments are strata slabs with caprock on top |

## Performance (GTX 1650 at 1080p60, plus the web build)
- Budget: world ≤ **3 ms GPU p95 at medium** on this zone with the render benchmark. Web: 60 fps in Chrome on the same PC.
- **Long sight lines are the risk:** fog ends ~1.1 km, so LOD carries this zone. Mesas past 250 m are T3 chunks; past 600 m, merged silhouette meshes.
- **Chunk meshing** per tier with the per-chunk colour texture (strata bands are colour, not geometry, beyond the 1-cell setback per band).
- **Instancing:** hoodoos (6 variants), boulders and talus (8), scrub (4), dead trees (3), cairns (2) as MultiMesh with per-instance tint; the arch, well and camp are unique.
- **Shadows:** one directional; at noon the cascade split can be tighter (short shadows).
- **Particles:** dust devils and sand drift as GPUParticles3D; halve on web; shimmer off on web.
- **LOD:** T0 fades past 40 m; hoodoos to T2 past 80 m, impostors past 250 m.
- Targets: ≤ 1.2 M visible triangles, ≤ 250 draw calls desktop; ≤ 500 k and ≤ 120 web. Paste the benchmark before and after.

## Deliverables (to `lookdev-shattered-mesa-v1`)
- **Hero shots** at 1920×1080: the Red Arch at noon (the key image), the hoodoo field from the floor, the Anvil Mesa's top with the surveyor's camp, a slot canyon in the Canyon Maze, a wide overview with the Great Mesa; the key image and the overview at all three times of day. Contact sheet.
- **`shattered_mesa_flythrough_v1.mp4`:** 60 s at 1080p60: low across the sand through the hoodoo field, up and **through the Red Arch**, over the Anvil Mesa's camp, down into a slot canyon of the maze, out over the Great Mesa (pattern of `world_flythrough.gd`).
- **Kael for scale:** voxel Kael under the Red Arch, beside a hoodoo and on a mesa top, plus gameplay-camera shots of Kael on the sand against a mesa wall at each time of day.
- **Readability strip:** all four legends over sand, banded walls and sky; **Kael and Brann against the red bands** as their own row.
- Render benchmark output before and after.

## Acceptance (self-check first; the owner decides)
- From the gameplay camera at the spawns, a viewer lists at least 10 distinct zone parts.
- The sky clearly contrasts the ground in every shot; the rock shows light and dark bands, never one flat orange.
- Kael's scarf and Brann's beard out-saturate every rock; Lyra's cerulean isn't lost against the sky.
- AO in band seams, under caprocks and the arch. No smooth-shaded or raw primitive props; the arch reads as stacked stone.
- Feet on the visible ground (QA foot check passes), on the floor and on mesa tops.
- Within the GPU budget; the web build holds its target.

## Build notes (for the coder)
| Part | Build | Kit or zone |
|---|---|---|
| Floor, plateau, mesas, canyons | terrain columns from the baked heightmap; T1 floor and tops, T2 walls, T3 far; strata band colour by height (band table per zone), 1-cell setback per band, caprock on top faces | **shared kit:** terrain columns, chunk meshing, baked AO, strata band painter (also used by Ember basalt and Frozen slate); **zone:** the band table and caprock rule |
| Red Arch | laid strata slabs following the existing arch's footprint (two legs and a span), each band a planar slab with setback, caprock on the span, a talus apron | **zone-specific** |
| Hoodoos | stacked-drum builder (octagonal drums, narrow necks, flat cap), instanced with `ShatteredMesaProps` transforms | **shared kit:** instanced props; **zone:** hoodoo builder |
| Boulders, talus, scrub, dead trees, cairns | small `VoxelDesign` builds, instanced; lichen as a cap pass on north- and top-facing cells | **shared kit:** instanced props, cap pass |
| Well, camp, chockstones, petroglyph boulder | unique zone builds | **zone-specific** |
| Dust devils, clouds | particles; T3 flat clouds | **shared kit:** puff clouds |
| Ground bounce | sky-plus-ground fill: a baked up-facing bounce term from the sand's albedo | **shared kit:** bounce bake |
| Placement | keep `ShatteredMesaProps` positions and the 4242 seed; storytelling props at authored spots, none on the open floor lines | |
| Code home | look-dev in `game/lookdev/` plus a zone variant folder; the existing world code stays untouched until the owner approves | |
