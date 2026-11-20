# Look-dev: Ember Rift (zone design sheet v1)

**Goal:** Ember Rift in the approved voxel style, at the characters' voxel density and with their lighting stack (`docs/lookdev/kael.md`, `.claude/skills/voxel-character-lookdev/SKILL.md`, template `docs/lookdev/heartbloom.md`). Same loop as a character: this sheet, then a build, then a stage, then the owner's three gates. Look before function: the terrain (`TerrainShape._ember`), zone data (`ember_rift.tres`), the lava plane (`world_map.gd`, y 31) and the props layout (`EmberRiftProps`, `PropKit` seed 4242) stay the truth; this is a visual pass over them.

## Identity and mood
**A living volcano's crater at last light:** a pale ash floor inside a ring of black glassy cliffs, amber lava running in channels to a central vent, obsidian spires leaning like broken spears. Hot, heavy, dangerous, but beautiful: the crater glows from below while the sky goes dark. Read at a glance: *ash-white floor, black spires, amber lava rivers, a smoking vent under a bruised sky.*

Mood comes with its image: the tank's diorama craft, lit like a miniature forge. Music *Magma Heart* (150 bpm) and the `amb_ember_rift` bed (rumble, hiss, crackle): slow pressure with sudden bursts, which is exactly how the geysers should feel.

**Lesson applied:** the grey-block crater is reddish-brown everywhere (ground, rock, fog, sky all in the same 0.3–0.6 red band). The voxel pass splits it into three materials that never share a value: **pale ash** (floor), **black obsidian** (walls, spires) and **amber lava** (light).

## Layout at gameplay scale
From `TerrainShape._ember`, `ember_rift.tres` and `EmberRiftProps` (zone centre (660, −520), extent 340 × 430, arena box ±300 m, ceiling 380 m):

| Ring | Shape (local to the centre) | Role in a fight |
|---|---|---|
| **Caldera Vent** (centre) | the floor sinks 10 m into a lava pool inside r 25 m, channels fan out; landmark at (660, 26, −520) | the visual anchor and a no-stand zone: lava below 31 m knocks fighters up |
| **Crater floor** (r 25–180 m) | flat ash at 36 ± 3 m, cut by noise lava channels (10 m deep, ~4–8 m wide) | the main stage; the spawns sit 90 m south of the vent at (640/680, −430) |
| **Fissure field** (around the spawns) | 7 fissure chains × 6 strips (6.5 × 2.4 m), 9–38 m from the spawns' midpoint | makes the duel floor read volcanic; never within 1.5 m of a spawn |
| **Geyser ring** (60–180 m) | 10 vents (9 m wide, 3.5 m tall cones) | the hazard: lava geysers knock up; telegraph them |
| **Inner wall** (r 180–270 m) | rises steeply (`pow(smooth, 1.5)`) to the rim | wall-splat surface; fight along it in flight |
| **Rim** (r 270 ± 20, three lobes) | 150 ± 25 m high; **Crater Rim** landmark north at (660, 150, −790) | the skyline; perches for zoners |
| **Rim Breach** (south-west, angle ≈ 2.3 rad) | the rim drops by up to 90 m to ~60 m; landmark (480, 70, −319) | where the lava pours out of the crater: the second landmark and the exit to the next zone |
| Outer slopes | fall from the rim to 34 m over 170 m | only seen when flying out |

- **Spires:** 55 obsidian spires, 24–70 m tall, r 3–8 m, tilted up to ±0.15 rad, on floor above 33 m and slope < 10 m over 5 m. They are the cover and the line-of-sight breakers; keep their placement exactly.
- **Fighting space:** the crater bowl is ~540 m across and ~115 m deep from rim to floor: a big open arena with a strong vertical edge. Keep a **20 m clear radius** around each geyser vent free of new props so the telegraph is always visible.
- **Verticality:** floor 36 m, spires to ~105 m, rim to 175 m, ceiling 380 m. Geyser columns (visual) reach 25 m. A tall **smoke plume** from the vent rises to the ceiling and drifts north-east; it is the compass.
- **Landmarks are navigation:** vent (centre, glow + plume), Crater Rim (the highest wall, north), Rim Breach (a notch with a lava fall, south-west). Each a different shape: column, wall, gap.

## Detail at three scales
| Scale | Parts |
|---|---|
| **Big forms** | Crater floor as planar ash terraces (1 cell steps); the inner wall as stacked **columnar basalt** (hex-ish columns stepped in plan, 2–4 m wide) under a glassy obsidian cap band; the rim's three lobes with jagged crowns; lava channels as cut trenches with crusted banks; the vent cone; the Breach lava fall; the smoke plume |
| **Medium parts** | Obsidian spires (6 variants: faceted prisms with conchoidal chip scars, split tips, a crack band); geyser vents (sulphur-crusted cone, cracked rim, a vent throat glowing inside); fissure strips (crust plates with a molten seam); pumice boulders and ash drifts; lava-crust rafts floating in the pool; collapsed lava tubes (half-pipes on the floor); a **shattered forge-shrine** near the Breach (anvil block, two stone braziers, a stair); a rope-and-plank **survey bridge** over a channel, half burnt; scattered obsidian shards near spires |
| **Tiny details** | Sulphur crystals (pale yellow clusters, T0) at vent rims; glowing pinprick cracks in crust; ash ripples on the floor (wind lines); flow lines on crust; heat-glazed sheen on obsidian edges; scorch rings around vents; tiny pumice pebbles; drips of cooled glass on spire tips; ember sparks; charred rope fibres; tool marks on the shrine blocks |

**Storytelling details (at least 5):**
1. The **forge-shrine** at the Breach: a cracked anvil block, a hammer-shaped notch worn into the stone step where someone knelt; an original nod that this is where hammers like Brann's were tempered (no lore text, just the props).
2. A **survey bridge** of rope and planks across a lava channel, its middle third burnt away; one charred plank still hangs.
3. **Survey stakes** with weathered cloth tags hammered in a line across the floor towards the vent, the last few melted halfway.
4. A **fossil of a fallen spire** lying in the floor, split into three pieces with lava cooled between them (shows the spires do fall: the destructible state).
5. **Offering stones**: a small cairn of stacked pumice on the rim with a ring of obsidian shards around it.
6. A geyser vent whose rim is **cracked open on one side**, with a fan of sulphur staining the floor in the direction it always blows.

**Zone emblem (original): the Rising Ember.** A teardrop flame standing on three short horizontal bars (stone strata). Carved into the forge-shrine's anvil block and on the survey stakes' tags.

## Voxel density (the characters' relationship, scaled)
The ladder from Heartbloom, ×4 steps from the character body cell (2.2 cm):

| Tier | Cell | Used for | Note |
|---|---|---|---|
| T0 | 2.2 cm | ≤ 1 m: sulphur crystals, survey stakes and tags, rope, shards, offering stones, the hammer notch | same pixel scale as a fighter |
| T1 | 8.8 cm | 1–15 m: vents, fissure crust, boulders, the shrine, the bridge, lava-crust rafts, spire bases (lower 12 m); **the walkable ash floor** (top 1 m shell) and channel banks | what fighters stand on and fight against |
| T2 | 35 cm | spire upper bodies, inner wall columns, the vent cone | never at a fighter's feet |
| T3 | 1.4 m | rim crowns, outer slopes, the smoke plume's voxel puffs | far or in haze |

- **Feet rule:** floor terraces round to T1 so the visible top stays within ±4.4 cm of the `ZoneGround` floor (QA foot check: 5 cm). Fissure strips sit 4 cm proud (`FISSURE_LIFT`): build their crust as part of the T1 shell, not as a floating plane.
- **Colour noise:** ±2–3% on ash and obsidian faces, up to ±6% on crust, sulphur and pumice. Darker in cracks and at the foot of spires; lighter on ash ridges, obsidian edge glints and worn shrine steps.
- **Design in blocks:** basalt as stepped columns, obsidian as flat facets with sharp edges, never a smooth cone; the lava surface is flat cells with a crust pattern, never a smooth glowing plane.

## Palette and value plan (dark frame, pale stage, amber light)
| Material | Base | Shadow | Notes |
|---|---|---|---|
| Ash floor | pale warm grey `#A8A09C` | `#6E6668` (violet-grey) | the stage: the lightest large surface in the zone |
| Ash drift ridges | `#BDB6B0` | `#857C7C` | wind lines |
| Columnar basalt (inner wall) | cool charcoal `#3E3A40` | `#24212A` | |
| Obsidian (spires, rim cap) | black-plum `#2A2128` | `#160F15` | edge glint `#7A6A78`; lava-lit faces pick up `#6A3A2A` |
| Crust (channel banks, rafts, fissures) | burnt umber `#4A3028` | `#2A1A16` | |
| Sulphur | pale lemon `#D8CC7A` | `#9A8E48` | sat ≤ 45%; only at vent rims and stains |
| Pumice boulders | warm grey-tan `#8C8078` | `#5A504C` | |
| Shrine stone, survey wood | weathered sandstone `#9A8878`, charred wood `#3A302A` | `#665848`, `#201A16` | |
| **Accent: lava** | amber core `#FFB040` (lit), glow falling off to `#E8701C` | crust `#4A3028` | the one saturated colour; emission ≤ 3 in pools, ≤ 2 in fissures |
| Sky (night, hero) | bruised slate `#2A2230` top, ash-plum `#5A3A3A` at the horizon, lit amber from below near the plume | | contrasts the pale floor |

**Value plan (L\*):**
| Plane | What | Value |
|---|---|---|
| Near (0–40 m) | ash floor, fissure crust, vents | **L\* 45–62** (ash), crust 20–30, lava seams emissive |
| Mid (40–250 m) | spires, inner wall, channel banks | **L\* 10–25** (obsidian and basalt, a dark frame) |
| Far (250 m+) | rim crown silhouettes, plume, sky | **L\* 25–45** (sky lit by lava glow and haze; rim as a dark notch against it) |

The fight happens on a **pale stage in front of a dark frame**, with the sky a middle value so spires and the rim cut clean silhouettes.

**Readability rules (the fighters must always win):**
1. **Value split:** every fighter's main mass is ≤ L\* 45 (Vexa 10, Lyra 16, Kael ~38, Brann's basalt 36) and reads dark-on-pale against the ash floor from the gameplay camera, which looks down on the floor most of the time. In flight against the dark wall, the zone's strong rim (night 1.0, dusk 1.3) carries them.
2. **Brann is the risk zone.** His energy (molten cracks, `#FF4A12` glow, yellow core) shares the lava's hue. Rules: lava lives in **broad flat pools, channels and geyser columns**, never thin glowing lines on vertical surfaces; fissures are 2.4 m wide crust strips with a molten seam ≤ 30% of the width and no branching hairlines; lava hue leans **amber-yellow (35–40°)**, Brann's glow leans red (15°). Obsidian spires keep the thin lava rim the grey-block has (#138) at ≤ 0.18 strength. His granite (L\* 45) sits 10+ below the lit ash and well above the obsidian.
3. **Kael's scarf (22°)**: no saturated orange on any surface material; orange only appears as lava light falloff, at low saturation, on ash.
4. **Hue exclusions:** no violet (Vexa) or cerulean (Lyra) anywhere; the ash shadow leans violet-grey at ≤ 10% saturation only. No saturated gold (the item family): sulphur stays pale and greenish.
5. **Saturation ceiling:** nothing but lava and sparks exceeds ~45%. Lava covers < 8% of the screen from the gameplay camera at the spawns.
6. **Busy-ness falls off:** ember sparks stay sparse (≤ 1 per m³ near the camera) and small (2–4 cm).

## Lighting and time of day
`ember_rift.tres` presets, with the miniature stack on top:

| Preset | Sun | Ambient | Rim | Look |
|---|---|---|---|---|
| Day | warm hazy (0.84), high | dusty rose-grey | warm, 1.6 | smoke-filtered daylight; the lava reads only as colour, not light |
| Dusk | low, red-orange (0.72) | smoky rose | warm, 1.3 | long spire shadows across the ash, the plume backlit |
| **Night** (hero, *eruption night*) | dim red (0.24) | deep oxblood | warm, 1.0 | the lava is the key light: the floor glows amber from the channels, the spires are black against a lava-lit plume |

- **Preset fixes for the voxel pass:** the night ambient (0.25, 0.10, 0.08) is too red and will turn the pale ash into the same red as everything else; move it to a cooler `#2A2430` so the lava's amber has something to contrast with. The day and dusk fog (0.55, 0.40, 0.35 / 0.6, 0.32, 0.22) moves to a neutral ash grey `#7A7070` / `#8A6A5A` so the sky stops matching the rock.
- **Stack:** baked per-vertex AO (spire feet, column joints, under crust rafts, vent throats) on every tier; one directional shadow; fill from the sky; the voxel edge highlight shader; the zone's rim on fighters.
- **Lava light:** lava is emissive; at most 4 real OmniLights (nearest pool, nearest two geysers when erupting, the vent), amber, no shadows. A baked **lava bounce** term (vertex colour, falloff 12 m from any lava cell) warms the ash and the lower spire faces, which is what sells the night.

## Atmosphere and sky
- **Sky:** slate-plum top, ash-plum horizon; at night, a soft amber glow band low in the sky above the vent and the Breach (the lava lighting the smoke from below). No stars through the smoke except a few near the zenith.
- **Smoke plume:** a column of T3 voxel puffs rising from the vent, drifting north-east, lit amber from below and grey on top; its silhouette is the zone's skyline landmark.
- **Haze:** height fog thicker on the crater floor (heat shimmer band 0–8 m above lava only); distance fog keeps the rim one plane lighter than the inner wall.
- **Ash fall** (the existing `embers` weather): a mix of grey ash flakes (most) and a few glowing sparks (few).

## Motion
| Element | Motion | Rule |
|---|---|---|
| Lava | crust plates drift slowly along channels (scrolling cell pattern, ~0.3 m/s); pool surface churns in the centre | crust moves as whole cells; no smooth UV smear |
| Geysers | telegraph: vent throat brightens and spits sparks for 1 s, then a 25 m column of voxel lava blobs, then falling droplets | the telegraph is the gameplay read; keep it identical every time |
| Smoke plume | slow rise and drift | puffs as rigid T3 blobs |
| Ash and sparks | drifting down, sparks rising near lava | sparse near the camera |
| Heat shimmer | screen-space distortion only right above lava | off on web |
| Lava fall at the Breach | a stepped cascade of glowing cells | |
| Breakables | obsidian spires shatter into faceted shards (existing destructible) | shards use T1 obsidian cells with an edge glint |

## Performance (GTX 1650 at 1080p60, plus the web build)
- Budget: world ≤ **3 ms GPU p95 at medium** (GAME_DESIGN §7.3) on this zone with the render benchmark. Web: 60 fps in Chrome on the same PC at the web preset.
- **Chunk meshing** per tier (32³ cells, coplanar faces merged, per-chunk colour texture for noise and AO), frustum culled; the inner wall is the biggest mesh, so build it at T2 with a T1 band only within 6 m of the floor.
- **Instancing:** spires (6 variants), vents (2), boulders (6), shards (4), stakes (2) as MultiMesh with per-instance tint; the shrine and bridge are the only unique meshes.
- **Lava** stays one shader plane (plus the fissure strips as instances, as today) with a voxel-cell crust pattern; no geometry per lava cell.
- **Lights:** ≤ 4 omni, no shadows; lava bounce baked.
- **Particles:** ash, sparks and geyser droplets as GPUParticles3D; halve on web; heat shimmer off on web.
- **LOD:** T0 fades past 40 m; spires swap to T2 past 80 m and impostors past 250 m; the rim crown is T3 always.
- Targets: ≤ 1.2 M visible triangles, ≤ 250 draw calls desktop; ≤ 500 k and ≤ 120 web. Paste the benchmark before and after.

## Deliverables (to `lookdev-ember-rift-v1`)
- **Hero shots** at 1920×1080: the vent and plume at night (the key image), a geyser erupting beside the spawns, the Rim Breach lava fall, the forge-shrine, the spire forest from the floor looking up, a wide overview from the north rim; the key image and the overview at all three times of day. Contact sheet.
- **`ember_rift_flythrough_v1.mp4`:** 60 s at 1080p60: down over the north rim, through the spire forest, low over a lava channel to the vent, around the plume, past an erupting geyser, out through the Breach (pattern of `world_flythrough.gd`).
- **Kael for scale:** voxel Kael beside a vent, at a spire's foot and on the survey bridge, plus gameplay-camera shots of Kael on the ash floor at each time of day.
- **Readability strip:** all four legends over the busiest backgrounds (lava pool, spire forest, plume), with **Brann against the lava** as its own row.
- Render benchmark output before and after.

## Acceptance (self-check first; the owner decides)
- From the gameplay camera at the spawns, a viewer lists at least 10 distinct zone parts.
- Three clear value bands (ash, obsidian, lava) in every hero shot; the sky is never the same colour as the rock.
- Brann's cracks are never mistaken for lava in the readability strip; Kael's scarf out-saturates everything but lava.
- AO visible at spire feet, vent throats, column joints. No smooth-shaded or raw primitive props.
- Feet on the visible ground (QA foot check passes), including on fissure crust.
- Within the GPU budget; the web build holds its target.

## Build notes (for the coder)
| Part | Build | Kit or zone |
|---|---|---|
| Crater floor, inner wall, rim | terrain columns from the baked heightmap, rounded to T1 near the floor and T2/T3 above; columnar basalt as a stepped column pattern on steep faces (hash per 3 m cell), obsidian cap band by height | **shared kit:** terrain columns, chunk meshing, baked AO; **zone:** the basalt column pattern and cap band rule |
| Lava channels and pool | existing lava plane and fissure instances; voxel crust pattern in the lava shader; banks as T1 crust cells | **zone:** crust shader, bank painter |
| Spires | 6 faceted prism variants built in `VoxelGrid` (CARVE chip scars, a split tip), T1 base / T2 body | **shared kit:** instanced props; **zone:** spire builder |
| Vents, boulders, shards, stakes | small `VoxelDesign` builds, instanced | **shared kit** (instanced props) |
| Forge-shrine, survey bridge, fallen spire, cairn | unique zone builds, planar blocks with bevelled edges | **zone-specific** |
| Plume, ash, geysers | T3 puff instancer (shared with Heartbloom's cloud sea and Skyhold's clouds), particles | **shared kit:** puff clouds; **zone:** geyser telegraph timing |
| Lava bounce | a baked vertex-colour term from distance to lava cells | **shared kit:** "emitter bounce" bake (reused by Stormfall neon and Heartbloom lanterns) |
| Placement | keep `EmberRiftProps` positions and the 4242 seed; new storytelling props at fixed authored spots, clear of spawns and vents | |
| Code home | look-dev in `game/lookdev/` plus a zone variant folder; the existing world code stays untouched until the owner approves | |
