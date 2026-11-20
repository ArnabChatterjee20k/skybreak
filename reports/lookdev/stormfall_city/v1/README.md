# Stormfall City: voxel look-dev v1

Design sheet: `docs/lookdev/stormfall_city.md`. Code: `game/world/zones_voxel/stormfall_city/`
(`StormfallCityVoxel` on the voxel zone kit, `CityBlocks` block mesher, `city_block`, `city_street`,
`city_streak` and `city_rain` shaders). Tests: `tests/world/test_stormfall_city_voxel.gd`.
Release: `lookdev-stormfall_city-v1` (full-size stills and the fly-through).

Rendered with lavapipe (software Vulkan, colour-correct) through `zone_capture.gd`: 15 stills at
1920x1080 and `stormfall_city_flythrough_v1.mp4` at 1920x1080, 30 fps, 20 s. The task asked for 720p30;
the skill's quality rule (videos 1080p30 or more) overrides that.

```sh
export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json GALLIVM_PERF=no_aos_sampling LP_PERF=no_rast_linear
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --disable-vsync --resolution 1280x720 \
  -s res://game/world/voxel_zone_kit/zone_capture.gd -- <out> heroes \
  --zone=res://game/world/zones_voxel/stormfall_city/stormfall_city_voxel.gd
# fly-through: ... -- <out> flythrough --time=night --fps=30 --seconds=20 --zone=...
```

## The sim stays the truth
- Ground: the baked heightmap (`TerrainShape._city`) on its own 2 m grid, as a fan around each cell's
  bilinear centre. The visible street stays within 4.4 cm of `ZoneGround` (tested on the spawn plaza
  and across a canal embankment; the first, diagonal-split version was 9.5 cm off on the canal slopes).
- Every building, rubble heap, water tower, sign and car is `StormfallCityProps` run as ZoneMatch
  runs it (fresh `PropKit`, seed 4242, all spawns kept clear). The look restyles those transforms:
  489 buildings, 140 cars, 577 signs. Tested: same counts and transforms as the sim.
- Not changed: no sim, gameplay, `.tres` or shared-kit edits.
- **Sim gap found:** the Spire Tower landmark (-102, 618) has no building in the sim. Its block sits on
  the raised district's slope, so the props builder skips it. The voxel Spire stands there as a visual
  landmark only, with no collider, and is filed in `TODO.md`.

## What's built (detail at three scales)
- **Big forms:** facades with storey slabs, a T1 shop floor, setbacks (55% of buildings over 30 m),
  cornices and parapets; broken tops with exposed floor slabs and rebar; a crack line on leaning
  buildings; stone-course canal embankments and district retaining slopes; rubble heaps of tilted
  slabs; the three towers. The **Spire** is stacked setbacks with corner piers, a stepped needle and a
  pulsing magenta beacon. The **Signal** has a 46 m braced lattice mast, a white strobe and a dish.
  The **Old Tower** is laid stone with buttresses, string courses, slit windows, four warm clock faces
  and a stepped crown.
- **Medium parts:** window grid snapped to 35 cm cells (lit 28%, dark glass, broken, boarded); real
  sills and hoods on storeys 2-4; roller shutters (some up with lit shop windows), awnings with
  valances; zig-zag fire escapes with landings, rails and stairs; balconies; AC units, vents and
  antennas; water towers on stilts (staves, hoops, stepped roof); neon blades and bands (tube outline
  plus made-up glyphs on a dark backing); sodium lamps (82% dead); bins; cables across streets; six
  wrecked-car variants; sunk canal boats.
- **Tiny details:** per-cell colour noise; bevel highlights on every block's outer cell ring; rain
  streaks and sill stains; wet sheen on up-facing cells; puddles; kerb and gutter lines; worn dashes
  and crossings; **Split Bolt** manhole covers (zone emblem, also stencilled on the water towers);
  graffiti patches on shutters; rebar ends; rain rings on the canal.
- **Storytelling (6):** the noodle bar (lit magenta sign in a made-up script, a tipped stool, a bowl
  and chopsticks on the counter); the bus nosed into the collapsed embankment with its destination
  board lit; laundry lines between balconies; the Old Tower's clock stopped at about 3:50 with the
  minute hand missing on the street face; the rooftop garden (planters, bench, tarp, drum, a string of
  dead bulbs); a broken gutter pouring into a long puddle.
- **Value plan:** near is a dark wet street (asphalt `#2A2C34`) with lighter kerbs and neon/sky
  sheen; mid is dark facades with warm window pinpoints; far is a lighter slate storm sky (horizon
  `#535872`) with fog `#4A4E5E`. One accent: magenta `#FF3CA8` (about a third of the signs and the
  beacon); the other signs are warm-white tubes. The grey-block cyan, gold and violet are gone, and the
  rim is cool white `#D8E4FF`.
- **Lighting:** the kit stage (SSAO, filmic, glow, fog, one weak shadowed moon, unshadowed rim);
  four unshadowed magenta OmniLights follow the nearest magenta signs; a lightning flash (directional
  light, sky brightening, a branching bolt of glowing blocks) at fixed times at least 6 s apart; rain
  as one GPUParticles3D around the camera, faded out within 2-6 m.

## Performance
Greedy meshing comes from the blocks themselves: every box is the merged shape of its cells, at 12
triangles however many cells it covers. The cell look (noise, bevels, windows) lives in the shader.

| Tier | Contents | Range | Shadows |
|---|---|---|---|
| Near blocks | full buildings, props, signs, story props (per 48 m tile) | 0-170 m | yes |
| Far blocks | massing, cornice, parapet, crowns, sign glow | 170 m + | no |
| Ground 2 m / 8 m | heightmap grid per 48 m tile | 0-140 m / 140 m + | no |
| Cars | 6 variants, near / far | 0-70 m / 70 m + | near only |

Triangles built (all tiles; only the tiers in range draw): near blocks 1.33 M, far blocks 72 k,
ground 2 m tier 730 k, cars near 30.8 k (140 instances), streaks 1 k. Build: 5.6-6.0 s on the
cloud CPU, no disk cache needed.

Per frame (from the capture):

| Shot | Visible tris | Draws | Shadow tris | Shadow draws |
|---|---|---|---|---|
| street_key (gameplay height) | 195 k | 366 | 200 k | 45 |
| kael_gameplay | 199 k | 290 | 264 k | 56 |
| kael_noodle_bar | 223 k | 211 | 284 k | 51 |
| rooftop_garden | 226 k | 214 | 316 k | 56 |
| lightning_skyline | 157 k | 482 | 108 k | 15 |
| overview (190 m up) | 128 k | 638 | 36 k | 0 |

**Estimate, GTX 1650 at 1080p (not measured; the benchmark wasn't run, the owner's PC is off):**
about 0.4-0.55 M triangles per frame including shadows is light for the card (well under 1 ms of
vertex work). The cost is fragments and draw calls: forward+ with SSAO, glow, fog, 4 omni and one
2-split shadow. My estimate is 3.5-5 ms GPU for the world at street level, above the sheet's 3 ms.
290-640 draws are over the 250 target, and the overview is the worst. v2 fixes: 96 m ground chunks
and car tiles (about 40% fewer draws), shadow distance 180 m to 90 m, near range 170 m to 130 m.
**Web (compatibility renderer):** triangles fit under 500 k only with shadows off; draws (290-640)
are 2.5-5x over the 120 target, so the web build needs the merged tiles plus a far-only skyline
before it can hold 60 fps.

## Self-critique, ranked by severity
1. **The Spire has no collider:** the sim has no building at its landmark, so it is look-only until a
   gameplay PR adds one. The canal bridges from the sheet were left out for the same reason (no sim
   collision).
2. **Upper facades are colour, not geometry:** windows above storey 4 are shader cells with no
   recess. From 20-60 m it reads, but up close a big facade looks flat next to the tank-quality bar.
   Glass and lit shop windows show a fine per-pixel dither (specular aliasing on rough 0.08 glass
   under MSAA, visible in `street_key` and `rooftop_garden`).
3. **The street mirror is weak:** with SSR off, the wet street reflects only sky sheen, the 4 omni
   specular highlights and thin streak quads. It doesn't yet read as the "mirror full of light" the
   sheet asks for. The key image's magenta blade is an authored look-dev sign added on top of the
   sim's signs; most of the sim's magenta signs hang high and far from the street.
4. **Draw calls are over budget** (above), and the GPU budget is an estimate, not a benchmark.
5. **Day and dusk overviews are washed out by fog;** the skyline reads as flat layers, but the
   mid-ground loses contrast. The night presets are the tuned ones.
6. **Motion is partial:** lightning flashes are timed, not synced to `stormfall_thunder`; no sign
   flicker, no puddle ripples, no gutter particles (the pour is static blocks), no cable or laundry
   sway.
7. **Not done from the deliverables:** the readability strip (all four legends, the Vexa row), Kael
   on a canal bridge, a 60 s fly-through (this one is 20 s, the task's length), the render benchmark.
8. Rubble heaps are random slab piles and read as boxes from far; the bus is a plain box body.
