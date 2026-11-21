# Voxel zone perf pass (branch `lookdev/zone-perf`)

All seven voxel zones (Heartbloom plus the six `lookdev/zone-*` builders) on one branch, with the
kit changes that cut their cost without changing how they look, a zone benchmark, and before/after
stills.

**Numbers here are lavapipe counts** (Mesa's software Vulkan, the real Forward+ pipeline). Triangle
and draw counts are exact; lavapipe's milliseconds mean nothing for a GPU. The GTX 1650 ms come from
running the benchmark on the owner's PC (command below).

## What changed

Kit level (`game/world/voxel_zone_kit/`), so every zone gets it:

1. **Lossless greedy merge of prop faces** (`VoxelFaceMerge`, `voxel_merged_prop.gdshader`). The
   character kit's mesher writes one quad per voxel face, with colour, corner AO and bevel flags per
   vertex, so no two faces can share a quad. The merge moves those per-face values into a small face
   texture (4 texels per face) and merges coplanar faces into rectangles; the shader finds the voxel
   face under each pixel and shades it exactly as before: the same two-triangle colour interpolation,
   the same bilinear AO and bevel ramps. The material type (matte, metal, glow...) is per face too,
   so a merged prop is one surface: one draw per copy, whatever its materials. Props drop to
   about a fifth of their triangles in both the main and the shadow pass, and the face texture is
   16 bytes per face against 256 for the per-face vertices.
2. **HLOD far regions** (`VoxelProp.place`). Each 4 x 4 block of placement tiles also gets one node
   with the last LOD tier of all its copies. It shows only from far enough away that every tile in
   the block would show its last tier anyway (its begin plus the farthest tile centre), and the tiles
   take it as their `visibility_parent`, so they hide while it shows. Same picture, one draw per block.
3. **Occluders**: Stormfall's buildings each get one box occluder inside the building's body, and
   the zone turns occlusion culling on. The kit can also give every heightfield chunk a
   conservative occluder (4 m boxes that stay inside the solid), but that is opt-in
   (`build(..., occluders = true)`): with terrain occluders and culling on, Frozen Peaks and Ember
   Rift hung under lavapipe twice (every thread parked on a futex), and I didn't have time to find
   out why. The numbers below are without terrain occluders.
4. **Quality tiers** (`VoxelQuality`, `GraphicsSettings.Quality`): HIGH, the GTX 1650's 1080p60
   default, draws exactly the authored look. MEDIUM keeps HIGH's sun (180 m, same splits) and
   everything at gameplay distance, pulls far prop LOD switches in (0.8x) and drops shadows from props
   under 0.5 m. LOW and WEB shorten ranges further, cast from the first LOD tier only, use bigger
   terrain chunks and a shorter sun (WEB: one split, no SSAO). `VoxelQuality.tier` defaults to the
   player's saved quality, and to WEB in a web build.
5. Zone fixes: Stormfall's outer ground ring (8 m tier only) merges 4 x 4 tiles into one mesh.
   Skyhold's islands get a 2 x T2 far tier below HIGH: each island switches as a whole (one box
   for all its chunks, so no seams) at 300 m on MEDIUM. Shattered Mesa's rock/floor and Stormfall's
   block and ground tiers scale their authored switch distances with the tier (`VoxelQuality.far`),
   HIGH unchanged. Frozen Peaks' mountain switch stays at 240 m on every tier: its far tier casts no
   shadow, and pulling it in took the mountain's shadow off the valley floor (caught by the stills).
6. WEB also starts props at their second LOD tier.

Tried and reverted (each caught by the benchmark or the stills): a 150 m sun on MEDIUM (islands
lost their shadows on the cloud sea in the overviews), blocks for short-range scatter (dense tufts drawn a block radius further cost
more triangles than the draws they saved), and 64 m terrain chunks on HIGH/MEDIUM. Frozen Peaks sets its mountain LOD per
chunk after building, so bigger chunks dropped a shadow-casting mountain chunk early and the valley
lost a big shadow (caught by the stills). HIGH/MEDIUM keep the authored 32 m chunks.

## Before / after

The MEDIUM rows are from a second run after MEDIUM got HIGH's sun back; the other rows from the
first. lavapipe counts, p95 over 24 samples of each zone's fly-through path, four voxel Kaels in frame, 480x270 (counts don't depend on resolution). "Before" is the code as it came from the zone branches (every tier drew the same then). Raw results: `bench/*.json`.

| Zone | Tier | Visible tris p95 | Draws p95 | Shadow tris p95 | Shadow draws p95 |
|---|---|---|---|---|---|
| heartbloom | before (any tier) | 2.14M | 440 | 1.42M | 229 |
| heartbloom | high | 1.01M | 316 | 882k | 200 |
| heartbloom | medium | 917k | 277 | 816k | 192 |
| heartbloom | low | 896k | 191 | 796k | 139 |
| heartbloom | web | 877k | 146 | 466k | 66 |
| frozen_peaks | before (any tier) | 2.07M | 381 | 1.34M | 175 |
| frozen_peaks | high | 1.68M | 313 | 1.06M | 158 |
| frozen_peaks | medium | 1.68M | 311 | 1.05M | 158 |
| frozen_peaks | low | 1.67M | 232 | 978k | 104 |
| frozen_peaks | web | 1.69M | 196 | 754k | 80 |
| verdant_falls | before (any tier) | 3.70M | 1029 | 3.05M | 144 |
| verdant_falls | high | 1.15M | 703 | 569k | 113 |
| verdant_falls | medium | 1.08M | 659 | 512k | 111 |
| verdant_falls | low | 1.02M | 380 | 355k | 74 |
| verdant_falls | web | 892k | 280 | 355k | 85 |
| shattered_mesa | before (any tier) | 1.80M | 457 | 2.51M | 205 |
| shattered_mesa | high | 1.00M | 319 | 1.09M | 174 |
| shattered_mesa | medium | 875k | 314 | 921k | 146 |
| shattered_mesa | low | 746k | 311 | 509k | 77 |
| shattered_mesa | web | 623k | 306 | 351k | 78 |
| ember_rift | before (any tier) | 1.62M | 808 | 1.50M | 322 |
| ember_rift | high | 1.11M | 700 | 872k | 318 |
| ember_rift | medium | 1.10M | 699 | 841k | 309 |
| ember_rift | low | 1.09M | 366 | 766k | 115 |
| ember_rift | web | 1.10M | 209 | 636k | 78 |
| skyhold_ruins | before (any tier) | 2.13M | 541 | 2.66M | 236 |
| skyhold_ruins | high | 1.21M | 383 | 849k | 217 |
| skyhold_ruins | medium | 1.00M | 384 | 825k | 282 |
| skyhold_ruins | low | 927k | 223 | 682k | 122 |
| skyhold_ruins | web | 898k | 177 | 342k | 61 |
| stormfall_city | before (any tier) | 380k | 600 | 471k | 104 |
| stormfall_city | high | 383k | 472 | 471k | 104 |
| stormfall_city | medium | 354k | 472 | 373k | 88 |
| stormfall_city | low | 340k | 472 | 325k | 74 |
| stormfall_city | web | 340k | 472 | 262k | 65 |

## Visual proof

The same 21 hero stills (three per zone, day, 1920x1080, lavapipe, MSAA 4x), rendered from the original code and from this branch, compared per pixel. SSIM is on luma over 8 px windows. Rain (Stormfall) and other particles differ from run to run.

**HIGH** (the default on the GTX 1650; must be unchanged):

| Zone | Shot | SSIM | Mean diff (/255) | Pixels > 8/255 | Pixels > 24/255 |
|---|---|---|---|---|---|
| ember_rift | kael_floor_day | 0.9901 | 0.07 | 0.24% | 0.049% |
| ember_rift | overview_day | 0.9989 | 0.05 | 0.18% | 0.032% |
| ember_rift | shrine_day | 0.9898 | 0.16 | 0.72% | 0.103% |
| frozen_peaks | gameplay_day | 0.9883 | 0.16 | 0.41% | 0.130% |
| frozen_peaks | overview_day | 0.9975 | 0.04 | 0.14% | 0.034% |
| frozen_peaks | valley_crown_day | 0.9785 | 0.18 | 0.57% | 0.197% |
| heartbloom | arch_day | 0.9928 | 0.17 | 0.74% | 0.188% |
| heartbloom | kael_scale_day | 0.9931 | 0.17 | 0.64% | 0.205% |
| heartbloom | overview_day | 0.9935 | 0.68 | 1.56% | 0.030% |
| shattered_mesa | overview_day | 0.9997 | 0.02 | 0.07% | 0.004% |
| shattered_mesa | red_arch_day | 0.9975 | 0.15 | 0.30% | 0.071% |
| shattered_mesa | spawn_gameplay_day | 0.9998 | 0.02 | 0.09% | 0.025% |
| skyhold_ruins | crown_gate_day | 0.9977 | 0.13 | 0.53% | 0.119% |
| skyhold_ruins | kael_scale_day | 0.9985 | 0.07 | 0.23% | 0.047% |
| skyhold_ruins | overview_day | 0.9882 | 0.77 | 2.08% | 0.030% |
| stormfall_city | kael_gameplay_day | 0.9607 | 0.52 | 2.62% | 0.153% |
| stormfall_city | overview_day | 0.9845 | 0.24 | 0.93% | 0.001% |
| stormfall_city | street_key_day | 0.9655 | 0.44 | 1.88% | 0.212% |
| verdant_falls | falls_key_day | 0.9919 | 0.10 | 0.24% | 0.110% |
| verdant_falls | grove_day | 0.9939 | 0.22 | 1.20% | 0.204% |
| verdant_falls | overview_day | 0.9959 | 0.10 | 0.45% | 0.052% |

**MEDIUM** (unchanged at gameplay distance; far LOD and far shadows may differ):

| Zone | Shot | SSIM | Mean diff (/255) | Pixels > 8/255 | Pixels > 24/255 |
|---|---|---|---|---|---|
| ember_rift | kael_floor_day | 0.9798 | 0.31 | 1.18% | 0.456% |
| ember_rift | overview_day | 0.9921 | 0.24 | 0.84% | 0.403% |
| ember_rift | shrine_day | 0.9794 | 0.38 | 1.73% | 0.373% |
| frozen_peaks | gameplay_day | 0.9428 | 1.70 | 5.41% | 2.919% |
| frozen_peaks | overview_day | 0.9976 | 0.04 | 0.14% | 0.034% |
| frozen_peaks | valley_crown_day | 0.9055 | 3.01 | 9.97% | 4.155% |
| heartbloom | arch_day | 0.9880 | 0.26 | 1.12% | 0.344% |
| heartbloom | kael_scale_day | 0.9856 | 0.37 | 1.41% | 0.603% |
| heartbloom | overview_day | 0.9938 | 0.61 | 1.15% | 0.036% |
| shattered_mesa | overview_day | 0.9383 | 1.48 | 5.77% | 3.434% |
| shattered_mesa | red_arch_day | 0.9783 | 0.64 | 2.49% | 0.824% |
| shattered_mesa | spawn_gameplay_day | 0.9990 | 0.05 | 0.14% | 0.064% |
| skyhold_ruins | crown_gate_day | 0.9908 | 0.33 | 1.11% | 0.489% |
| skyhold_ruins | kael_scale_day | 0.9925 | 0.23 | 0.73% | 0.175% |
| skyhold_ruins | overview_day | 0.9528 | 1.94 | 8.37% | 0.748% |
| stormfall_city | kael_gameplay_day | 0.9566 | 0.60 | 2.90% | 0.242% |
| stormfall_city | overview_day | 0.9852 | 0.23 | 0.87% | 0.001% |
| stormfall_city | street_key_day | 0.9572 | 0.66 | 2.74% | 0.608% |
| verdant_falls | falls_key_day | 0.9918 | 0.10 | 0.25% | 0.112% |
| verdant_falls | grove_day | 0.9198 | 3.55 | 10.95% | 6.088% |
| verdant_falls | overview_day | 0.9959 | 0.10 | 0.45% | 0.053% |

On HIGH every shot is within 0.8/255 mean difference; what's left is MSAA blending along internal
voxel-cell edges of merged faces (sub-pixel), shadow-filter noise and the rain. On MEDIUM the
differences are LOD switches that now happen at 0.8x distance: a few big spires at 56-70 m in
Frozen Peaks' valley shots, canopies at 44-55 m in Verdant's grove, far rock in Shattered Mesa's
overview and far islands in Skyhold's overview. Nothing at gameplay distance changes.

Previews (before | after | difference x4, three shots per zone) are in this folder:
`<zone>_before_after_high.jpg` and `<zone>_before_after_medium.jpg`.

## Benchmark

`tools/bench/zone_bench.gd` builds each zone at each tier, flies the zone's fly-through path
(`flight()`, 48 samples by default) with four voxel Kaels standing in for the fighters, and prints
visible and shadow triangles, draw calls and CPU/GPU render ms (avg, p95, max). `--breakdown` lists
the node groups that draw at the worst sample.

On the owner's PC (Windows, GTX 1650):

```sh
D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe --path . --fullscreen --resolution 1920x1080 --disable-vsync -s res://tools/bench/zone_bench.gd -- --tiers=high,medium,low,web --json=zone_bench.json
```

It exits 1 if any zone misses the medium budget (p95 <= 300k visible triangles and <= 250 draws),
which it will today (see the open points). The first run voxelises and merges every prop into
`user://voxel_prop_cache/` (a few minutes per zone); only the GPU/CPU ms of a run with a warm cache
mean anything, and the build time isn't part of them anyway. `--zones=heartbloom` limits the run.

## Verification

Official Godot 4.7.2 linux x86_64 (`Godot_v4.7.2-stable_linux.x86_64.zip`, SHA-512 `9aa00f7a...4c65`
matches `SHA512-SUMS.txt`). In a fresh checkout of `1b42538d` (the last code change; `.godot` removed):
`godot --headless --path . --import` (exit 0), then the full GUT run: **1588 tests, 1582 passing,
0 failing, 11 risky/pending** (the skipped live-service tests), exit 0, 402 s.

## Not done / open

- **Medium misses the 300k-triangle target in every zone** (Stormfall is closest at 354k; see the
  table). After the
  merge, what's left is mostly terrain with no LOD of its own (Heartbloom's island undersides,
  Skyhold's islands, Shattered Mesa's T2 rock, Frozen Peaks' foothills and mountains) and the big
  canopies and puff clouds. Getting to 300k means coarser terrain within view, which the owner would
  see; I stopped at "invisible at gameplay distance". Next levers, in order: a kit-level far tier
  for any heightfield (the Skyhold island pattern), Heartbloom's puff clouds at T3 x 2 past 150 m,
  Verdant canopy impostors past 120 m.
- **Draws**: Medium meets 250 in no zone (Heartbloom 277 is closest). The sources: Verdant's grove
  scatter on 16 m tiles, Ember's 32 m terrain chunks (LOW's 64 m chunks halve its draws), Stormfall's
  ground tiles, Skyhold's 34 islands x chunks. Bigger chunks are the obvious lever, but zones that
  set chunk ranges after `build()` (Frozen Peaks) depend on the chunk size; each zone needs its own
  check before raising it.
- **GPU ms are not measured**: run the benchmark on the GTX 1650 (command above) and paste the
  output here. Lavapipe ms in the JSON are meaningless.
- **Web**: the WEB tier is measured with Forward+ counts; a real web export (Compatibility renderer)
  hasn't been run with the voxel zones. WEB is still over its 500k / 120 target in most zones.
- Terrain occluders are opt-in until the Frozen Peaks / Ember Rift hang is understood (try it on
  the real GPU first: it may be a lavapipe-only deadlock). Occlusion culling helps only the main
  pass and needs a few frames to warm up after a camera cut.
- The benchmark's `--breakdown` ignores `visibility_parent` and occlusion, so it over-counts; the
  totals come from the renderer and are exact.
