# Heartbloom Gardens: look-dev v2

Design sheet: `docs/lookdev/heartbloom.md` (the "v2 look decisions" section overrides the v1 palette). Kit: `game/world/voxel_zone_kit/README.md`. Code: branch `lookdev/heartbloom-zone`.

Rendered with official Godot 4.7.2 (linux x86_64, SHA-512 checked against `SHA512-SUMS.txt`) on **lavapipe** (software Vulkan, colour-correct, slow) under xvfb, at 1920×1080 with MSAA 4×. The lighting stack is the kit's: SSAO plus baked AO, soft sun shadow, glow, fog and rim. Every still and every fly-through checkpoint was looked at before publishing. **Not yet seen on a real GPU.**

```sh
godot --path . --disable-vsync -s res://game/world/voxel_zone_kit/zone_capture.gd -- <out> heroes
godot --path . --disable-vsync -s res://game/world/voxel_zone_kit/zone_capture.gd -- <out> flythrough --fps=30 --seconds=20
```

## Assets

- 20 stills, 1920×1080 (`heartbloom_v2_<shot>_<time>.jpg`) plus `heartbloom_v2_contact_sheet.jpg`:
  - the arch, the overview and Kael at gameplay scale, each at dusk, day and night
  - the arch's foot with the love locks, the keystone and Kael
  - the fountain (dusk, day) with Kael at the rim
  - Kael on a bridge (dusk, night)
  - the shrine, the picnic blanket with Kael, Lantern Rise (dusk, night)
  - the sunset with the sun disc
  - the strata underside over the cloud sea
- `heartbloom_flythrough_v2.mp4`: 1920×1080, 30 fps, 20 s (600 frames), H.264 at CRF 21 so it fits in git (37 MB; the CRF 18 master was 61 MB). It flies in from the south, through the Heart Arch, past and under Blossom Crown, over the Wishing Fountain, low across Heart Isle past Kael, and rises to a wide shot. The task asked for 720p; the skill's quality rule (1080p30 minimum) overrides that.

## Perf

### Mesh budget (from the build's `stats`)

| Part | v1 draft | v2 |
|---|---|---|
| Terrain (all islands, tops + undersides) | 725 k quads | **215 k quads**: greedy 2D merge, quadtree smooth lawns, strata slabs, ~32 m chunks |
| Blossom tree, per instance | 37 k quads at every distance | **38 k** (T1, < 32 m) / **9.2 k** (2×T1, < 110 m) / **2.1 k** (T2, beyond). Only the first two tiers cast shadows |
| Paper lantern | ~9 k quads at every distance | T0 < 22 m, 4×T0 (~0.6 k) beyond |
| Scatter (10.6 k tufts, 2.2 k flowers, 840 stones, 1.6 k rim lips, 550 roots, 3 k rope links, 527 planks) | one zone-wide MultiMesh each, so the visibility range never switched | 16 m tiles for short-range scatter (26–30 m, no shadows), 48 m tiles with a coarse tier for everything else |
| Shadows | 4 splits, 8192 atlas | 2 blended splits to 180 m, 4096 atlas, soft medium. Lawn tops cast none (their undersides do) |

### Per shot (Godot's own counters, 1080p)

Godot's primitive counters may count both the depth pre-pass and the colour pass for opaque meshes, so unique geometry can be lower.

| Shot | Visible tris | Draw calls | Shadow tris | Shadow draws |
|---|---|---|---|---|
| arch (dusk / day / night) | 1.22 M | 237 | 0.51–0.67 M | 58–64 |
| overview | 1.50 M | 336 | 0.22–0.60 M | 34–64 |
| Kael, gameplay camera | 1.55 M | 298 | 0.61–1.19 M | 78–151 |
| arch detail | 1.47 M | 274 | 0.69 M | 89 |
| fountain | 1.50 M | 249 | 1.34–1.59 M | 92–137 |
| bridge | 1.34 M | 207 | 0.40 M | 52 |
| shrine | 1.48 M | 226 | 1.18 M | 126 |
| picnic | 1.29 M | 217 | 0.84 M | 91 |
| Lantern Rise | 0.98 M | 251 | 0.26–0.31 M | 41–47 |
| sunset | 1.53 M | 288 | 0.69 M | 75 |
| underside | 1.36 M | 308 | 0.60 M | 90 |

Before the LOD and tiling work, the same v2 content measured 2.4–5.8 M visible tris, 350–1500 draws and up to 8.7 M shadow tris.

### Estimated budget (an estimate, not a measurement)

**GTX 1650 at 1080p60, medium.** The sheet targets ≤ 1.2 M visible tris and ≤ 250 draws for the stage.
- **Now:** 1.0–1.55 M tris, 210–340 draws, and up to 1.6 M shadow tris near the fountain and shrine. That is about 25% over on triangles and up to 35% over on draws.
- **Vertex cost:** about 1.5–2.5 ms for the main and shadow passes together.
- **Pixel cost:** about 1–1.5 ms for SSAO, 0.3 ms for glow and 0.5–1 ms for terrain and props.
- **Total:** the world probably lands at **4–6 ms GPU**. That fits comfortably in a 16.6 ms frame, but it is **over the zone's 3 ms budget**.
- **To close the gap:** pull the T1 tree tier in to 20 m, cut tufts to 20 m, and stop the 2×T1 tree tier casting shadows. These are tuning values in `TREE_RANGES` and the `_place` calls.
- **The real check** is the render benchmark on the dev PC (AGENTS.md). Lavapipe frame times (2–3 s a frame) say nothing about a GPU.

**Web build (Compatibility, WebGL2).** The target is ≤ 500 k tris and ≤ 120 draws. The current scene is about **3× over on triangles and 2–3× over on draws**, so it needs a web preset that does not exist yet:
- no T1 tree tier (start at 2×T1)
- scatter off or under 15 m
- lanterns coarse only
- prop shadows off
- one shadow split
- SSAO off (Compatibility has none anyway)
- the GPU petal particles halved

At a rough guess that preset lands at about 450 k tris and 110 draws.

## Self-critique, ranked by severity

1. **Unproven on hardware.** Everything above is software rendering. The perf numbers are counts plus estimates, and the GPU budget (3 ms) is probably missed by 1.5–2×. Nothing has run on the GTX 1650 or in a browser.
2. **The web build has no preset** and is roughly 3× over its triangle target.
3. **The Heart Arch still reads as a tube with camouflage patches**, not as laid blocks:
   - The tint regions are cut along the curve per course, so from the front they make diagonal blotches rather than voussoirs with joints.
   - The arch is T2 (35 cm), coarser than the sheet's "T1 shell over a T2 core".
   - The keystone's gold heart is small and lumpy, and the diamond keystone's top is buried in the lobes.
4. **Undersides read as finely striped pots.** The strata slabs are there, but the per-cell crack and noise lines dominate. The slabs need a bigger tone contrast and fewer vertical cracks, and there are no overhanging ledges or hanging rocks.
5. **Dusk is soft and hazy.** The sun disc only shows in the sunset shot, and the key image (the arch) is lit from behind the camera, so canopy rims barely glow. Overall contrast is low; the day preset is better.
6. **Lanterns and posts are small** at gameplay distance. The lantern-post crossbars sit oddly short above the hanging pairs.
7. **Trees are one design in 4 variants** with similar silhouettes. There are no visible forks at T1 distance in most shots, and the "falling petals" are GPU particles that are barely visible in stills.
8. **Missing from the sheet:** the stream and Blossom Falls water, the petal whirlwinds, fireflies at night, wishing coins visible in the fountain (painted, but too small to see), and real OmniLights for the 4 nearest lanterns.
9. **The fly-through brushes one canopy** at about 16.8 s, on the low pass over Heart Isle.
10. **Visual polish:**
   - The lawn's flagstone walk is painted into the colour texture (flat), while the edging stones are 3D.
   - The tufts are bright yellow-green and slightly busy at the camera's feet.
   - One scatter stone sits right at Kael's feet in the gameplay shot.

## Next (v3)
Rebuild the arch as true voussoirs (per-block boxes along the curve at T1 on the faces), with a bigger keystone heart. Strata contrast and ledges. A web preset and benchmark numbers from the dev PC. Water (stream, falls, fountain jets), whirlwinds, fireflies. A key-light pass so dusk rims the canopies in the hero shot.
