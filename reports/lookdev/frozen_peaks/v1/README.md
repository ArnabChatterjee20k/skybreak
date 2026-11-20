# Frozen Peaks: look-dev v1

Design sheet: `docs/lookdev/frozen_peaks.md`. Kit: `game/world/voxel_zone_kit/README.md` (from `lookdev/heartbloom-zone`). Code: `game/world/zones_voxel/frozen_peaks/` on branch `lookdev/zone-frozen_peaks`.

Rendered with official Godot 4.7.2 (linux x86_64, SHA-512 checked against `SHA512-SUMS.txt`, fresh `.godot` import) on **lavapipe** under xvfb, 1920×1080, MSAA 4×, the kit's stack (SSAO + baked AO, soft 2-split sun shadow, glow, fog, rim). Every published still and the fly-through contact sheet were looked at. **Not yet seen on a real GPU.**

```sh
godot --path . --disable-vsync -s res://game/world/voxel_zone_kit/zone_capture.gd -- <out> heroes \
    --zone=res://game/world/zones_voxel/frozen_peaks/frozen_peaks_voxel.gd
godot --path . --disable-vsync -s res://game/world/voxel_zone_kit/zone_capture.gd -- <out> flythrough \
    --time=night --fps=30 --seconds=20 --zone=res://game/world/zones_voxel/frozen_peaks/frozen_peaks_voxel.gd
```

## The sim stays the truth

- **Ground:** the baked `TerrainHeightmap` (`TerrainShape._peaks`). The valley floor is a smooth top on a 1 m lattice aligned with the 2 m sim grid, so the visible floor stays within 4.4 cm of `ZoneGround` (tested: `tests/world/test_frozen_peaks_voxel.gd`). The first pass used the kit's 1.4 m quadtree blocks and the new test caught it 7.9 cm off; fixed before rendering.
- **Props:** `FrozenPeaksProps.build` runs exactly as `ZoneMatch` runs it (fresh `PropKit`, seed 4242, every ground zone's spawns kept clear), and the voxel spires, shelves and boulders take its 60 / 26 / 120 transforms. Spires pick the closest of 6 variants and keep the sim's base and height exactly (footprint within ±15%); shelves keep the sim box's centre, jut and width exactly; boulders keep centre and size. Tested.
- No sim, gameplay, `.tres` or kit change. Everything new is under `game/world/zones_voxel/frozen_peaks/`.

## What's built (sheet → build)

| Scale | Built |
|---|---|
| Big forms | glacier band (cyan-grey ice with flow streaks, clear margins) down the valley's S-curve; snow floor; T2 foothill terraces; T3 slate mountains with strata walls and snow on every ledge (slope + coherent noise rule); the Ice Crown as a ring of 11 faceted ice teeth around the highest summit near the landmark; a stand-in range beyond the zone box |
| Medium | 6 spire-cluster variants (hex prisms with stepped tips, 2–4 tilted satellites, snow on every up face); 4 stratified shelf variants (ice / blue / old-snow layers, drifted top, cornice, jagged outer edge, icicle fringe); 6 faceted boulders (3 ice, 3 slate with tilted strata); the hero crevasse plus short crevasses along both glacier margins, with raised clear-ice lips; 10 slate cairns every 60 m; the frozen waterfall on the north cliff; the camp; the rope bridge; sastrugi ridges |
| Tiny | sastrugi colour ripples, frost sparkle cells, trapped bubbles in the glacier, icicles, rope lashings and guy-lines, crate seams and iron corners, lichen spots, the mug, the lantern, the tally marks, boot prints, drift against every windward foot |

**Storytelling (6):** the standing tent with its flap tied open and a lantern glowing inside, beside the collapsed tent under a drift; the crate stack with a mug on top; the half-buried sledge with three lashed crates, one split open on coiled rope; boot prints along the cairn line that stop at a crevasse, the fresh-planked rope bridge beside it; an ice axe frozen into the spire nearest the camp at head height; the flag tripod with a torn pennant (±4° stiff flap); the first cairn, taller, with a tally-marked capstone and the Crown Star carved on its biggest slab. **Emblem:** the Crown Star (six points, the top three longer) on the crates and the first cairn.

**Value plan:** night (hero) is bright snow / dark slate / darkest indigo sky with the aurora as the only saturated colour, high over the Ice Crown, voxel-stepped curtains in a zone sky shader (`frozen_sky.gdshader`). Day flips the sky to a mid blue darker than the snow. Dusk uses the sheet's colder lilac fog.

## Assets

- 20 stills, 1920×1080 (`frozen_peaks_v1_<shot>_<time>.jpg`) plus `frozen_peaks_v1_contact_sheet.jpg`:
  - **valley_crown** (key image, night / day / dusk): low in the valley up the S-curve, spire clusters, Kael at the west spawn
  - **overview** (night / day / dusk), **gameplay** camera behind Kael at the spawn (night / day / dusk)
  - **camp** with Kael for scale (night / day): standing tent with its lantern, crates, tripod and pennant, sledge
  - **spire_axe** with Kael beside the cluster nearest the camp (day / night); **waterfall** with Kael (night / day)
  - **cairn_crevasse** (the first cairn, boot prints, crevasse and bridge), **shelf_cliffs** (day / night), **ice_crown** (night / dusk)
- `frozen_peaks_flythrough_v1.mp4`: 1920×1080, 30 fps, 20 s, night. High in from the east, down past the camp, low along the glacier, then a climb to circle the Ice Crown under the aurora. The task asked for 720p; the skill's quality rule (1080p30 minimum) overrides that.

## Perf

### Mesh budget (build `stats`)

| Part | Quads | Notes |
|---|---|---|
| Valley floor (smooth, 1 m lattice, T1 colour around the spawns, T2 elsewhere) | 73 k | ~32 m chunks, casts no shadow |
| Foothills (T2 steps beside the spawns) | 310 k | greedy tops, walls merged in runs; the second-largest cost |
| Mountains (T3) | 650 k | greedy; chunks end at 240 m |
| Mountains far tier (2×T3) | 165 k | from 240 m, no shadow |
| Stand-in range (5.6 m near ring, 22 m beyond) | 259 k | look-dev framing only |
| Spires, 6 variants at T2 (instanced, 60 + 11 crown teeth) | 101 k for the 6 meshes | tiers T2 < 70 m, 2×T2 < 200 m, T3 beyond; only T2 casts |
| Shelves (4 variants), boulders (6), cairns, camp, lips, sastrugi | small | MultiMesh tiles; scatter has no shadow and ends at 45–90 m |

Prop meshes come from the character kit's `VoxelMesher`, which emits one quad per open voxel face (not greedy). Terrain is greedy.

### Per shot (Godot's counters at 1080p; may count the depth pre-pass too)

| Shot | Visible tris | Draws | Shadow tris |
|---|---|---|---|
| valley_crown | 1.83 M | ~445 | 0.86 M |
| overview | 2.12 M | ~555 | 0.10 M |
| gameplay | 1.78 M | ~420 | 0.8–1.2 M |
| camp | 1.82 M | ~455 | 1.0–1.2 M |
| spire_axe | 1.34 M | ~320 | 0.5 M |
| waterfall | 1.68 M | ~385 | 0.7–0.9 M |
| ice_crown | 0.64 M | ~155 | 0.2 M |
| shelf_cliffs | 0.67 M | 182 | 0.38 M |

(The shadow draw-call counter read 0 in the final run and 50–180 in earlier ones; treat it as unreliable.)

### Budget estimate (not measured: no GPU here, and the render benchmark needs the dev PC)

- **GTX 1650 at 1080p:** about 1.8 M visible + 1 M shadow triangles and ~450 draws in the busiest valley shots. My estimate is **5–7 ms GPU** for the world. That is over the sheet's 3 ms budget and over its 1.2 M tris / 250 draws target, though the whole frame should still fit 60 fps. Run `render_benchmark.gd` on the dev PC before trusting any of this.
- **Web build:** about 3.5× over its 500 k tris and 120 draws target. It needs its own preset: T3 foothills, a 120 m mountain LOD, one 22 m far tier, spire T3 from 40 m, no terrain shadows, no sastrugi or lips.
- The cheapest wins, in order: greedy face merging in `VoxelMesher` for static props (spires are flat hex faces, so about 4–6× fewer quads), foothills at T3 past 120 m, the mountain chunk LOD at 160 m, fewer floor chunks (merge chunks so the floor isn't ~100 draws).

## Self-critique, ranked by severity (kept visible in the renders)

1. **Over budget.** Estimated 5–7 ms on the GTX 1650 against 3 ms; ~1.8 M tris and ~450 draws against 1.2 M / 250; the web build is about 3.5× over. Nothing measured on real hardware yet.
2. **The Ice Crown doesn't read as a landmark.** Its ring of teeth is lost among the T3 summits and the spire field (`ice_crown_*`, the end of the fly-through). It needs a taller crowned summit and a lighter, cleaner silhouette against the aurora.
3. **The spires are huge, many and uniform.** That's the sim's layout (60 spires, 22–62 m), but at this size the 6 variants repeat, and their flat hex faces read as "skyscrapers" in the key image. They need more facet and value breakup (clear edges, cloudy cores) and maybe a crowd-only smaller variant.
4. **Mountains at T3 are coarse and blotchy.** From the valley the snow/slate patches read as camouflage, not strata ledges, and the foothill terraces look like bleachers (`camp_*`, `waterfall_*`). The sheet's planar strata slabs and cornices aren't built.
5. **Floor faceting.** The 1 m lattice uses flat quad normals; under the low dusk and day sun, big faint facets show on the snow (`valley_crown_dusk`, `gameplay_dusk`). Fix: smooth vertex normals from the heightmap.
6. **Camp props are readable but rough.** The sledge's stepped drift reads as stairs; the collapsed tent is just a snow slab; the mug and ice axe are too small to see in any shot; the flap and lantern only read from the front.
7. **Crevasses are painted, not carved,** because the sim floor is continuous (carving would float the fighters). The raised lips help, but they read as dark strokes from height.
8. **Dusk still leans warm and pink** on the snow despite the lilac fog: too close to Heartbloom's hero time.
9. **Missing from the sheet:** the snowstorm shot, the spindrift plumes, the readability strip (4 legends over snow, slate and the night sky), and the render benchmark before and after. The stand-in range beyond the zone box replaces the real neighbouring zones (look-dev framing only).
10. **One hack:** the zone swaps `VoxelStage._sky_mat`'s shader (a private member) to add the aurora. The kit should get a per-zone sky shader hook. No kit file was edited.

## Verification

- Official Godot 4.7.2 linux x86_64, SHA-512 verified, `rm -rf .godot`, `--headless --import`.
- Full GUT: 135 scripts, 1545 tests, 1539 passing, 0 failing, 11 risky/pending as GUT reports them (all pre-existing: renderer-only, known-issue QA and live-service tests). New: `tests/world/test_frozen_peaks_voxel.gd` (floor within 4.4 cm of `ZoneGround` at the spawns, the 1 m lattice, sim placements and sizes kept, the fly-through clears every spire and the ground, the Crown Star emblem).
